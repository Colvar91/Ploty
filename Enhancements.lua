local addonName, Ploty = ...

local COMM_PREFIX = Ploty.COMM_PREFIX
local MAX_ROLL_VALUE = 1000000

local VALID_STATUSES = {
    READY = true,
    ABSENT = true,
}

local STATUS_ORDER = { "READY", "ABSENT" }
local STATUS_LABELS = {
    READY = "Anwesend",
    ABSENT = "Abwesend",
}

local STATUS_COLORS = {
    READY = "|cff55ff55",
    ABSENT = "|cffff5555",
}

local trim = Ploty.Trim
local shortName = Ploty.ShortName
local function playerKey(name)
    return Ploty:PlayerKey(name)
end
local function samePlayerName(first, second)
    return Ploty:SamePlayerName(first, second)
end
local sanitizeField = Ploty.SanitizeField
local sendAddonMessage = Ploty.SendAddonMessage
local ensureTable = Ploty.EnsureTable

local function versionParts(version)
    local parts = {}
    for value in tostring(version or "0"):gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(value) or 0
    end
    return parts
end

local function compareVersions(first, second)
    local a = versionParts(first)
    local b = versionParts(second)
    local count = math.max(#a, #b)
    for index = 1, count do
        local av = a[index] or 0
        local bv = b[index] or 0
        if av < bv then
            return -1
        elseif av > bv then
            return 1
        end
    end
    return 0
end

local function clearGroupBoundSavedState(self)
    if not self.db then
        return false
    end

    local hadOrder = #(self.db.emoteOrder or {}) > 0
    wipe(self.db.emoteOrder or {})
    wipe(self.db.participantGroups or {})
    wipe(self.db.typingStates or {})
    wipe(self.db.participantRolls or {})
    wipe(self.db.rollSelection or {})

    local rollRound = self.db.rollRound
    if type(rollRound) == "table" then
        rollRound.id = ""
        rollRound.active = false
        rollRound.requestPending = false
        rollRound.sender = nil
        rollRound.startedAt = nil
        rollRound.target = nil
        wipe(rollRound.targets or {})
    end

    self.db.currentEmoteIndex = 1
    self.db.orderSender = nil
    self.db.orderUpdatedAt = nil
    self.db.orderWasGroupBound = false
    self.db.emotePaused = false
    return hadOrder
end

local originalInitializeDatabase = Ploty.InitializeDatabase
function Ploty:InitializeDatabase()
    originalInitializeDatabase(self)

    self.db.settings = self.db.settings or {}
    if self.db.settings.compactTurnBar == nil then
        self.db.settings.compactTurnBar = true
    end
    if self.db.settings.sortRolls == nil then
        self.db.settings.sortRolls = true
    end
    if self.db.settings.notifications == nil then
        self.db.settings.notifications = true
    end
    -- 0.19.0 führte die Seitenleiste mit einem für kleine UI-Skalierungen zu
    -- großen Mindestfenster ein. Einmalig auf das kompaktere Raster migrieren;
    -- danach bleiben manuelle Größenänderungen des Spielers erhalten.
    if (tonumber(self.db.settings.uiLayoutVersion) or 0) < 2 then
        self.db.settings.windowWidth = 880
        self.db.settings.windowHeight = 660
        self.db.settings.uiLayoutVersion = 2
    else
        self.db.settings.windowWidth = tonumber(self.db.settings.windowWidth) or 880
        self.db.settings.windowHeight = tonumber(self.db.settings.windowHeight) or 660
    end

    self.db.emotePaused = self.db.emotePaused and true or false
    ensureTable(self.db, "participantStates")
    ensureTable(self.db, "typingStates")
    -- Schreibstatus ist flüchtiger Sitzungszustand und darf nach einem Reload
    -- nicht als veraltetes "schreibt" sichtbar bleiben.
    self.db.typingStates = {}
    ensureTable(self.db, "peerVersions")

    -- Seit 0.21.1 gibt es nur noch "Anwesend" und "Abwesend". Alte
    -- Zwischenzustände werden beim Laden auf einen der beiden Werte gehoben.
    for key, status in pairs(self.db.participantStates) do
        if status == "SKIPPED" then
            self.db.participantStates[key] = "ABSENT"
        elseif not VALID_STATUSES[status] then
            self.db.participantStates[key] = "READY"
        end
    end

    local emoteText = ensureTable(self.db, "emoteText")
    -- Diese Bibliotheken wurden in 0.14 entfernt; alte SavedVariables nicht
    -- bei jedem Login erneut als leere Tabellen mitschleppen.
    emoteText.history = nil
    emoteText.savedDrafts = nil
    emoteText.templates = nil
    emoteText.lastSentText = tostring(emoteText.lastSentText or "")
    emoteText.lastSentChannel = tostring(emoteText.lastSentChannel or "SAY")
    emoteText.allowLongText = false

    local rollRound = ensureTable(self.db, "rollRound")
    local hadTargetedRollData = type(rollRound.targets) == "table"
    rollRound.id = tostring(rollRound.id or "")
    rollRound.title = tostring(rollRound.title or "Würfelprobe")
    rollRound.minimum = math.floor(tonumber(rollRound.minimum) or tonumber(self.db.settings.rollMinimum) or 1)
    rollRound.maximum = math.floor(tonumber(rollRound.maximum) or tonumber(self.db.settings.rollMaximum) or 20)
    rollRound.target = tonumber(rollRound.target)
    rollRound.active = rollRound.active and true or false
    rollRound.requestPending = rollRound.requestPending and true or false
    ensureTable(rollRound, "targets")
    ensureTable(self.db, "rollSelection")
    -- Eine alte globale Würfelrunde besitzt noch keine Zielauswahl und darf
    -- nach dem Update nicht als offene Aufforderung für die ganze Gruppe
    -- weiterlaufen.
    if not hadTargetedRollData then
        rollRound.active = false
        rollRound.requestPending = false
    end

    self.typingActivityToken = 0
    self.longTextApproved = false
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self.longTextTurnKey = playerKey(self:GetCurrentEmoteParticipant())
    self.pendingLongTextRequest = nil
    self.incomingRollTargets = nil
    self.lastGroupSignature = nil
    self.lastHelloAt = 0
    self.groupMembershipToken = 0
    self.groupDeparturePending = false
    self.wasInWoWGroup = IsInGroup() and true or false

    -- Falls die Gruppe außerhalb der laufenden Sitzung aufgelöst wurde, darf
    -- eine zuvor gruppengebundene Reihenfolge beim nächsten Login nicht wieder
    -- als vermeintlich aktueller Stand erscheinen.
    if not self.wasInWoWGroup and self.db.orderWasGroupBound then
        clearGroupBoundSavedState(self)
    elseif self.wasInWoWGroup and #(self.db.emoteOrder or {}) > 0 then
        self.db.orderWasGroupBound = true
    end
    -- Der Plot-Zustand ist absichtlich flüchtig. Nach einem Reload der Leitung
    -- muss der Plot erneut bewusst über die Übersicht gestartet werden.
    self.plotActive = false
    self.plotStartedAt = nil
    self.plotLeader = nil
end

function Ploty:IsPlotActive()
    return self.plotActive and true or false
end

function Ploty:RefreshPlotStateUI()
    if self.RefreshPlotOverview then
        self:RefreshPlotOverview()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
end

function Ploty:ApplyPlotState(active, startedAt, sender)
    self.plotActive = active and true or false
    self.plotStartedAt = self.plotActive and math.floor(tonumber(startedAt) or time()) or nil
    self.plotLeader = self.plotActive and sender or nil

    if not self.plotActive then
        wipe(self.db.typingStates or {})
        if self.db.rollRound then
            self.db.rollRound.requestPending = false
        end
        self.longTextRequestPending = false
        self.longTextRequestToken = nil
        self:SetAllowLongEmoteText(false)
    end
    self:RefreshPlotStateUI()
    return true
end

function Ploty:BroadcastPlotState(target)
    if not self:CanSyncEmoteOrder() then
        return false
    end
    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end
    return sendAddonMessage(
        "PLOTSTATE|" .. (self:IsPlotActive() and "1" or "0") .. "|" .. tostring(self.plotStartedAt or 0),
        channel,
        target
    )
end

-- Ein eigener Resetbefehl unterscheidet den Reload einer Leitung vom bewussten
-- Beenden über die Oberfläche. So können Teilnehmer keinen alten Laufzustand
-- behalten, während der Reload eines unbeteiligten Raid-Assistenten einen von
-- einer anderen Leitung gestarteten Plot nicht beendet.
function Ploty:BroadcastPlotReset(target)
    if not self:CanSyncEmoteOrder() then
        return false
    end
    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end
    return sendAddonMessage("PLOTRESET|0", channel, target)
end

function Ploty:CanApplyPlotReset(sender)
    if not self:IsAuthorizedOrderSender(sender) then
        return false
    end
    if not self:IsPlotActive() or samePlayerName(sender, self.plotLeader) then
        return true
    end
    local unit = self:FindGroupUnit(sender)
    return unit and UnitIsGroupLeader(unit) and true or false
end

function Ploty:CanApplyPlotState(sender, active)
    if not self:IsAuthorizedOrderSender(sender) then
        return false
    end
    if not active then
        return self:CanApplyPlotReset(sender)
    end
    if not self:IsPlotActive() or not self.plotLeader or samePlayerName(sender, self.plotLeader) then
        return true
    end

    -- Ein laufender Plot behält genau eine Quelle. Nur die tatsächliche
    -- Gruppen-/Raidleitung darf eine andere Assistenz als Quelle ablösen.
    local unit = self:FindGroupUnit(sender)
    return unit and UnitIsGroupLeader(unit) and true or false
end

function Ploty:IsLocalPlotAuthority()
    if not self:CanSyncEmoteOrder() then
        return false
    end

    local playerName = Ploty.GetUnitFullName("player")
    if self:IsPlotActive() and self.plotLeader and self:IsSenderInGroup(self.plotLeader) then
        return samePlayerName(self.plotLeader, playerName)
    end
    if self.db.orderSender and self:IsSenderInGroup(self.db.orderSender) then
        return samePlayerName(self.db.orderSender, playerName)
    end
    return UnitIsGroupLeader("player") and true or false
end

function Ploty:StartPlot()
    if not self:CanSyncEmoteOrder() then
        self:Print("Nur die Plotleitung kann den Plot starten.")
        return false
    end
    if #(self.db.emoteOrder or {}) == 0 then
        self:Print("Füge vor dem Start mindestens eine Person zur Reihenfolge hinzu.")
        return false
    end
    if self:IsPlotActive() then
        return true
    end

    self.plotActive = true
    self.plotStartedAt = time()
    self.plotLeader = Ploty.GetUnitFullName("player")
    self.db.emotePaused = false
    local currentIndex = self:NormalizeEmoteTurnIndex()
    if self:IsParticipantSkipped(self.db.emoteOrder[currentIndex]) then
        self.db.currentEmoteIndex = self:FindNextEligibleEmoteIndex(currentIndex, 1)
    end
    self:RefreshPlotStateUI()

    if not self:SendEmoteOrder(true) then
        self.plotActive = false
        self.plotStartedAt = nil
        self.plotLeader = nil
        self:RefreshPlotStateUI()
        return false
    end
    self:Print("Plot gestartet. Reihenfolge und Zugstatus wurden übertragen.")
    return true
end

function Ploty:StopPlot()
    if not self:CanSyncEmoteOrder() then
        self:Print("Nur die Plotleitung kann den Plot beenden.")
        return false
    end
    if not self:IsPlotActive() then
        return true
    end

    self.plotActive = false
    self.plotStartedAt = nil
    self.plotLeader = nil
    wipe(self.db.typingStates or {})
    if self.db.rollRound then
        self.db.rollRound.requestPending = false
    end
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self:SetAllowLongEmoteText(false)
    self:BroadcastPlotState()
    self:RefreshPlotStateUI()
    self:Print("Plot beendet. Die vorbereitete Reihenfolge bleibt erhalten.")
    return true
end

function Ploty:TogglePlot()
    if self:IsPlotActive() then
        return self:StopPlot()
    end
    return self:StartPlot()
end

function Ploty:CanEditOfficialOrder()
    return self:HasLeaderPrivileges()
end

function Ploty:GetStatusLabel(status)
    return STATUS_LABELS[status] or STATUS_LABELS.READY
end

function Ploty:GetStatusColor(status)
    return STATUS_COLORS[status] or STATUS_COLORS.READY
end

function Ploty:GetParticipantStatus(name)
    local key = playerKey(name)
    if key == "" then
        return "READY"
    end

    local status = self.db.participantStates[key]
    if not VALID_STATUSES[status] then
        status = "READY"
    end
    return status
end

function Ploty:IsParticipantSkipped(name)
    return self:GetParticipantStatus(name) == "ABSENT"
end

function Ploty:BroadcastParticipantStatus(name, status)
    if not self:IsPlotActive() then
        return false
    end
    local channel = self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end
    return sendAddonMessage("STATUS|" .. sanitizeField(name, 80) .. "|" .. tostring(status), channel)
end

function Ploty:SetParticipantStatus(name, status, broadcast)
    name = self:ResolveGroupPlayerName(name)
    status = tostring(status or "READY"):upper()
    if name == "" or not VALID_STATUSES[status] then
        return false
    end

    local playerName = Ploty.GetUnitFullName("player")
    if IsInGroup() and not samePlayerName(name, playerName) and not self:CanSyncEmoteOrder() then
        self:Print("Nur die Gruppenleitung kann den Status anderer Teilnehmer ändern.")
        return false
    end

    local key = playerKey(name)
    self.db.participantStates[key] = status
    if status == "ABSENT" then
        self.db.typingStates[key] = nil
    end

    if broadcast then
        self:BroadcastParticipantStatus(name, status)
    end

    local currentName = self:GetCurrentEmoteParticipant()
    if status == "ABSENT" and currentName and samePlayerName(name, currentName) and self:CanSyncEmoteOrder() then
        self:MoveOfficialEmoteTurn(1)
    end

    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
    if self.RefreshPlotOverview then
        self:RefreshPlotOverview()
    end
    return true
end

function Ploty:CycleParticipantStatus(name)
    local current = self.db.participantStates[playerKey(name)] or "READY"
    local nextStatus = STATUS_ORDER[1]
    for index, status in ipairs(STATUS_ORDER) do
        if status == current then
            nextStatus = STATUS_ORDER[(index % #STATUS_ORDER) + 1]
            break
        end
    end
    return self:SetParticipantStatus(name, nextStatus, true)
end

function Ploty:SetTypingState(isTyping, broadcast)
    local playerName = Ploty.GetUnitFullName("player")
    local key = playerKey(playerName)
    if key == "" then
        return
    end

    local currentName = self:GetCurrentEmoteParticipant()
    local mayShowTyping = self:IsPlotActive()
        and currentName
        and samePlayerName(currentName, playerName)
        and not self.db.emotePaused
    local value = isTyping and mayShowTyping and true or nil
    if self.db.typingStates[key] == value then
        return
    end

    self.db.typingStates[key] = value
    if broadcast then
        local channel = self:GetGroupCommunicationChannel()
        if channel then
            sendAddonMessage("TYPING|" .. (value and "1" or "0"), channel)
        end
    end

    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
end

function Ploty:NotifyTypingActivity(hasText)
    self.typingActivityToken = (self.typingActivityToken or 0) + 1
    local token = self.typingActivityToken

    local currentName = self:GetCurrentEmoteParticipant()
    local playerName = Ploty.GetUnitFullName("player")
    if not self:IsPlotActive() or not hasText or not currentName or not samePlayerName(currentName, playerName) or self.db.emotePaused then
        self:SetTypingState(false, true)
        return
    end

    self:SetTypingState(true, true)
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function()
            if Ploty.typingActivityToken == token then
                Ploty:SetTypingState(false, true)
            end
        end)
    end
end

function Ploty:IsPlayerCurrentEmoter(name)
    local currentName = self:GetCurrentEmoteParticipant()
    return self:IsPlotActive()
        and currentName
        and name
        and samePlayerName(currentName, name)
        and not self.db.emotePaused
        or false
end

function Ploty:RefreshLongTextTurnState()
    local currentKey = playerKey(self:GetCurrentEmoteParticipant())
    if self.longTextTurnKey == currentKey then
        return
    end

    self.longTextTurnKey = currentKey
    self.typingActivityToken = (self.typingActivityToken or 0) + 1
    self.db.typingStates = {}
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self.pendingLongTextRequest = nil
    self:SetAllowLongEmoteText(false)
    if self.HideLongTextRequestDialog then
        self:HideLongTextRequestDialog()
    end
end

local originalRefreshEmoteTurnState = Ploty.RefreshEmoteTurnState
function Ploty:RefreshEmoteTurnState()
    originalRefreshEmoteTurnState(self)
    self:RefreshLongTextTurnState()
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
end

function Ploty:RequestLongEmoteText()
    if not self:IsPlotActive() then
        self:Print("Der Plot wurde noch nicht gestartet.")
        return false
    end
    local playerName = Ploty.GetUnitFullName("player")
    if not self:IsPlayerCurrentEmoter(playerName) then
        self:Print("Eine Langtext-Freigabe kann nur die Person im aktuellen Emote-Zug anfragen.")
        return false
    end
    if self:IsLongEmoteTextEnabled() then
        self:Print("Längere Emotes sind für diesen Zug bereits freigegeben.")
        return true
    end
    if self.longTextRequestPending then
        self:Print("Die Anfrage wartet bereits auf eine Antwort der Plotleitung.")
        return false
    end

    -- Plotleitung und Assistenz dürfen ihren eigenen aktuellen Zug direkt
    -- freigeben; für Teilnehmer ist immer eine bestätigte Anfrage nötig.
    if self:HasLeaderPrivileges() then
        self:SetAllowLongEmoteText(true)
        self:Print("Längere Emotes sind für deinen aktuellen Zug freigegeben.")
        return true
    end

    local channel = self:GetGroupCommunicationChannel()
    if not channel then
        self:Print("Für eine Langtext-Anfrage musst du dich in einer Gruppe befinden.")
        return false
    end

    local token = tostring(time()) .. tostring(math.random(1000, 9999))
    if not sendAddonMessage("LONGREQ|" .. sanitizeField(token, 30), channel) then
        self:Print("Die Langtext-Anfrage konnte nicht gesendet werden.")
        return false
    end

    self.longTextRequestPending = true
    self.longTextRequestToken = token
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    self:Print("Langtext-Freigabe bei der Plotleitung angefragt.")
    return true
end

function Ploty:AnswerLongTextRequest(approved)
    local request = self.pendingLongTextRequest
    if not request or not self:HasLeaderPrivileges() then
        return false
    end
    if not self:IsPlayerCurrentEmoter(request.sender) then
        self.pendingLongTextRequest = nil
        if self.HideLongTextRequestDialog then
            self:HideLongTextRequestDialog()
        end
        self:Print("Die Langtext-Anfrage ist nicht mehr aktuell.")
        return false
    end

    local command = approved and "LONGALLOW" or "LONGDENY"
    local sent = sendAddonMessage(command .. "|" .. sanitizeField(request.token, 30), "WHISPER", request.sender)
    if sent then
        self:Print((approved and "Langtext freigegeben für " or "Langtext abgelehnt für ") .. shortName(request.sender) .. ".")
    else
        self:Print("Die Antwort auf die Langtext-Anfrage konnte nicht gesendet werden.")
    end
    self.pendingLongTextRequest = nil
    if self.HideLongTextRequestDialog then
        self:HideLongTextRequestDialog()
    end
    return sent and true or false
end

function Ploty:FindNextEligibleEmoteIndex(startIndex, direction)
    local order = self.db.emoteOrder or {}
    local count = #order
    if count == 0 then
        return 1
    end

    direction = direction and direction < 0 and -1 or 1
    local index = math.floor(tonumber(startIndex) or 1)

    for _ = 1, count do
        index = index + direction
        if index > count then
            index = 1
        elseif index < 1 then
            index = count
        end

        if not self:IsParticipantSkipped(order[index]) then
            return index
        end
    end

    return math.max(1, math.min(count, startIndex or 1))
end

function Ploty:BroadcastTurnControl()
    if not self:IsPlotActive() then
        return false
    end
    local channel = self:GetGroupCommunicationChannel()
    if channel then
        sendAddonMessage(
            "CONTROL|" .. tostring(self:NormalizeEmoteTurnIndex()) .. "|" .. (self.db.emotePaused and "1" or "0"),
            channel
        )
    end
end

function Ploty:SetOfficialEmoteIndex(index, broadcast)
    if IsInGroup() and not self:CanSyncEmoteOrder() then
        self:Print("Nur die Gruppenleitung kann den aktiven Teilnehmer festlegen.")
        return false
    end

    if not self:SetCurrentEmoteIndex(index) then
        return false
    end

    if broadcast then
        self:BroadcastTurnControl()
    end
    return true
end

function Ploty:MoveOfficialEmoteTurn(direction)
    if IsInGroup() and not self:CanSyncEmoteOrder() then
        self:Print("Nur die Gruppenleitung kann die Reihenfolge steuern.")
        return false
    end

    local currentIndex = self:NormalizeEmoteTurnIndex()
    local nextIndex = self:FindNextEligibleEmoteIndex(currentIndex, direction)
    self.db.currentEmoteIndex = nextIndex
    self:RefreshEmoteTurnState()
    self:BroadcastTurnControl()
    return true
end

function Ploty:SkipCurrentEmoteTurn()
    if IsInGroup() and not self:CanSyncEmoteOrder() then
        self:Print("Nur die Gruppenleitung kann Teilnehmer auf abwesend setzen.")
        return false
    end

    local currentName = self:GetCurrentEmoteParticipant()
    if not currentName then
        return false
    end

    -- SetParticipantStatus schaltet den aktuell aktiven Abwesenden bereits
    -- genau einmal weiter. Ein zweiter Move übersprang bisher die nächste Person.
    return self:SetParticipantStatus(currentName, "ABSENT", true)
end

function Ploty:SetEmotePaused(paused, broadcast)
    if IsInGroup() and not self:CanSyncEmoteOrder() then
        self:Print("Nur die Gruppenleitung kann die Reihenfolge pausieren.")
        return false
    end

    self.db.emotePaused = paused and true or false
    if broadcast then
        self:BroadcastTurnControl()
    end
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
    return true
end

function Ploty:ToggleEmotePause()
    return self:SetEmotePaused(not self.db.emotePaused, true)
end

-- Ersetzt die einfache 0.11-Fortschaltung: pausierte Runden bleiben stehen und
-- abwesende Teilnehmer werden automatisch ausgelassen.
function Ploty:AdvanceEmoteTurnForSender(sender, broadcast)
    local order = self.db.emoteOrder or {}
    if not self:IsPlotActive() or #order == 0 or not sender or self.db.emotePaused then
        return false
    end

    local currentName, currentIndex = self:GetCurrentEmoteParticipant()
    if not currentName or not samePlayerName(currentName, sender) then
        return false
    end

    local nextIndex = self:FindNextEligibleEmoteIndex(currentIndex, 1)
    self.db.currentEmoteIndex = nextIndex
    self:RefreshEmoteTurnState()

    if broadcast then
        local channel = self:GetGroupCommunicationChannel()
        if channel then
            sendAddonMessage("TURN|" .. tostring(nextIndex), channel)
        end
    end
    return true
end

function Ploty:PassCurrentEmoteTurn()
    if not self:IsPlotActive() then
        self:Print("Der Plot wurde noch nicht gestartet.")
        return false
    end
    local playerName = Ploty.GetUnitFullName("player")
    local currentName, currentIndex = self:GetCurrentEmoteParticipant()
    if not currentName or not self:IsPlayerCurrentEmoter(playerName) then
        self:Print("Du kannst nur während deines eigenen Emote-Zugs passen.")
        return false
    end

    local nextIndex = self:FindNextEligibleEmoteIndex(currentIndex, 1)
    if nextIndex == currentIndex then
        self:Print("Es gibt momentan keine andere anwesende Person in der Reihenfolge.")
        return false
    end

    self.typingActivityToken = (self.typingActivityToken or 0) + 1
    self:SetTypingState(false, true)
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self:SetAllowLongEmoteText(false)

    if not self:AdvanceEmoteTurnForSender(playerName, true) then
        return false
    end

    self:Print("Du hast deinen Emote-Zug gepasst.")
    return true
end

function Ploty:HandleEmoteTurnMessage(sender, indexText)
    local order = self.db.emoteOrder or {}
    local requestedIndex = math.floor(tonumber(indexText) or 0)
    if #order == 0 or requestedIndex < 1 or requestedIndex > #order or self.db.emotePaused then
        return
    end

    local currentName, currentIndex = self:GetCurrentEmoteParticipant()
    if not currentName or not samePlayerName(currentName, sender) then
        return
    end

    local expectedIndex = self:FindNextEligibleEmoteIndex(currentIndex, 1)
    if requestedIndex ~= expectedIndex then
        return
    end

    self.db.currentEmoteIndex = requestedIndex
    self:RefreshEmoteTurnState()
    self:NotifyIfPlayerTurn("turn")
end

function Ploty:GetTurnContext()
    local order = self.db.emoteOrder or {}
    if #order == 0 then
        return nil, nil, nil
    end

    local currentIndex = self:NormalizeEmoteTurnIndex()
    local previousIndex = self:FindNextEligibleEmoteIndex(currentIndex, -1)
    local nextIndex = self:FindNextEligibleEmoteIndex(currentIndex, 1)
    return order[previousIndex], order[currentIndex], order[nextIndex]
end

function Ploty:SetCompactTurnBar(enabled)
    self.db.settings.compactTurnBar = enabled and true or false
    if self.RefreshGlobalTurnBar then
        self:RefreshGlobalTurnBar()
    end
end

function Ploty:GetGlobalTurnDisplayText()
    local order = self.db.emoteOrder or {}
    if #order == 0 then
        return "|cff888888Keine Emote-Reihenfolge festgelegt.|r"
    end

    if not self.db.settings.compactTurnBar then
        return self:GetEmoteTurnDisplayText()
    end

    local previousName, currentName, nextName = self:GetTurnContext()
    local function display(name)
        if not name then
            return "–"
        end
        return shortName(name)
    end
    local function inactiveDisplay(name)
        local group = self.GetParticipantEmoteGroup and self:GetParticipantEmoteGroup(name) or nil
        local color = group and self.GetEmoteGroupColor and self:GetEmoteGroupColor(group.colorKey) or nil
        return "|cff" .. (color and color.hex or "cccccc") .. display(name) .. "|r"
    end

    local activeText = "|cff55ff55[" .. display(currentName) .. "]|r"
    if #order == 1 then
        return activeText
    elseif #order == 2 then
        return inactiveDisplay(previousName) .. "   " .. activeText
    end

    return table.concat({
        inactiveDisplay(previousName),
        activeText,
        inactiveDisplay(nextName),
    }, "   ")
end

function Ploty:GetActiveTurnDisplayName()
    local currentName = self:GetCurrentEmoteParticipant()
    if not currentName then
        return "Kein aktiver Teilnehmer"
    end
    return shortName(currentName)
end

local originalAddEmoteParticipant = Ploty.AddEmoteParticipant
function Ploty:AddEmoteParticipant(name)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end
    return originalAddEmoteParticipant(self, name)
end

local originalRemoveEmoteParticipant = Ploty.RemoveEmoteParticipant
function Ploty:RemoveEmoteParticipant(index)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end
    return originalRemoveEmoteParticipant(self, index)
end

local originalMoveEmoteParticipant = Ploty.MoveEmoteParticipant
function Ploty:MoveEmoteParticipant(index, direction)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end
    return originalMoveEmoteParticipant(self, index, direction)
end

local originalClearEmoteOrder = Ploty.ClearEmoteOrder
function Ploty:ClearEmoteOrder()
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end
    self.db.emotePaused = false
    return originalClearEmoteOrder(self)
end

local originalImportGroupToEmoteOrder = Ploty.ImportGroupToEmoteOrder
function Ploty:ImportGroupToEmoteOrder()
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end
    return originalImportGroupToEmoteOrder(self)
end

function Ploty:CanControlRollRequest()
    return self:HasLeaderPrivileges()
end

-- Kompatibilitätsname für bestehende interne Aufrufe.
function Ploty:CanControlRollRound()
    return self:CanControlRollRequest()
end

function Ploty:GetRollRequest()
    return self.db.rollRound
end

function Ploty:GetRollRound()
    return self:GetRollRequest()
end

function Ploty:IsRollParticipantSelected(name)
    return self.db.rollSelection[playerKey(name)] ~= nil
end

function Ploty:GetSelectedRollParticipants()
    local selected = {}
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        if self.db.rollSelection[participant.key] then
            selected[#selected + 1] = participant
        end
    end
    return selected
end

function Ploty:GetRollSelectionCount()
    return #self:GetSelectedRollParticipants()
end

function Ploty:SetRollParticipantSelected(name, selected)
    if not self:CanControlRollRequest() then
        self:Print("Nur die Gruppenleitung kann die Würfelauswahl ändern.")
        return false
    end

    local wanted = playerKey(name)
    local participant
    for _, candidate in ipairs(self:GetCurrentRollParticipants()) do
        if candidate.key == wanted then
            participant = candidate
            break
        end
    end
    if not participant then
        self:Print("Der ausgewählte Spieler ist nicht mehr in der Gruppe.")
        return false
    end

    if selected then
        self.db.rollSelection[participant.key] = participant.fullName or participant.name
    else
        self.db.rollSelection[participant.key] = nil
    end
    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    return true
end

function Ploty:ToggleRollParticipantSelection(name)
    return self:SetRollParticipantSelected(name, not self:IsRollParticipantSelected(name))
end

function Ploty:ClearRollSelection(silent)
    if not self:CanControlRollRequest() then
        if not silent then
            self:Print("Nur die Gruppenleitung kann die Würfelauswahl leeren.")
        end
        return false
    end
    wipe(self.db.rollSelection)
    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    return true
end

local originalClearParticipantRolls = Ploty.ClearParticipantRolls
function Ploty:ClearParticipantRolls(synchronize)
    synchronize = synchronize ~= false
    if synchronize and IsInGroup() and not self:CanControlRollRequest() then
        self:Print("Nur die Gruppenleitung kann die Würfel für alle leeren.")
        return false
    end

    originalClearParticipantRolls(self)

    if synchronize then
        local channel = self:GetGroupCommunicationChannel()
        if channel then
            local roundId = sanitizeField(self.db.rollRound and self.db.rollRound.id or "", 30)
            if roundId == "" then
                roundId = "0"
            end
            sendAddonMessage("ROLLCLEAR|" .. roundId, channel)
        end
    end
    return true
end

function Ploty:IsRollRequestTarget(name)
    local round = self.db.rollRound
    return round and round.active and type(round.targets) == "table" and round.targets[playerKey(name)] ~= nil
end

function Ploty:GetRollRequestTargets()
    local targets = {}
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        if self:IsRollRequestTarget(participant.fullName or participant.name) then
            targets[#targets + 1] = participant
        end
    end
    return targets
end

function Ploty:GetRollRequestProgress()
    local targets = self:GetRollRequestTargets()
    local rolled = 0
    for _, participant in ipairs(targets) do
        local roll = self.db.participantRolls[participant.key]
        if roll and tostring(roll.roundId or "") == tostring(self.db.rollRound.id or "") then
            rolled = rolled + 1
        end
    end
    return rolled, #targets
end

function Ploty:IsRollRequestComplete()
    local rolled, targetCount = self:GetRollRequestProgress()
    return targetCount > 0 and rolled == targetCount
end

function Ploty:GetRollTargetOutcome(result)
    local round = self.db.rollRound or {}
    local target = tonumber(round.target)
    if not target then
        return nil, nil
    end
    if tonumber(result) and tonumber(result) >= target then
        return "Ziel erreicht", "|cff55ff55"
    end
    return "Ziel verfehlt", "|cffff6666"
end

function Ploty:ApplyRollRound(round, sender, requestPending)
    local incomingId = tostring(round.id or "")
    local sameRound = incomingId ~= "" and tostring(self.db.rollRound.id or "") == incomingId

    self.db.rollRound.id = incomingId
    self.db.rollRound.title = sanitizeField(round.title or "Würfelprobe", 80)
    self.db.rollRound.minimum = math.floor(tonumber(round.minimum) or 1)
    self.db.rollRound.maximum = math.floor(tonumber(round.maximum) or 20)
    self.db.rollRound.target = tonumber(round.target)
    self.db.rollRound.active = true
    self.db.rollRound.sender = sender and shortName(sender) or shortName(Ploty.GetUnitFullName("player"))
    self.db.rollRound.startedAt = sameRound and self.db.rollRound.startedAt or date("%H:%M:%S")
    self.db.rollRound.requestPending = requestPending and true or (sameRound and self.db.rollRound.requestPending or false)
    if not sameRound then
        self.db.rollRound.targets = {}
    end
    if type(round.targets) == "table" then
        self.db.rollRound.targets = {}
        for key, name in pairs(round.targets) do
            local normalizedKey = playerKey(key)
            if normalizedKey ~= "" then
                self.db.rollRound.targets[normalizedKey] = tostring(name or key)
            end
        end
    end

    self.db.settings.rollMinimum = self.db.rollRound.minimum
    self.db.settings.rollMaximum = self.db.rollRound.maximum
    if not sameRound then
        self.db.participantRolls = {}
        self.db.lastRoll = nil
    end

    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    if self.RefreshRollRange then
        self:RefreshRollRange()
    end
    if self.RefreshLastRoll then
        self:RefreshLastRoll()
    end
    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
end

function Ploty:BroadcastRollRound(target)
    local round = self.db.rollRound
    if not round or not round.active then
        return false
    end

    local message = table.concat({
        "ROLLROUND",
        sanitizeField(round.id, 30),
        tostring(round.minimum or 1),
        tostring(round.maximum or 20),
        tostring(round.target or 0),
        sanitizeField(round.title or "Würfelprobe", 80),
    }, "|")

    if target then
        return sendAddonMessage(message, "WHISPER", target)
    end

    local channel = self:GetGroupCommunicationChannel()
    return channel and sendAddonMessage(message, channel) or false
end

function Ploty:BroadcastRollRequestTargets(target)
    local round = self.db.rollRound
    if not round or not round.active then
        return false
    end

    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end

    local id = sanitizeField(round.id, 30)
    sendAddonMessage("ROLLTARGETRESET|" .. id, channel, target)
    for _, participant in ipairs(self:GetRollRequestTargets()) do
        sendAddonMessage(
            "ROLLTARGET|" .. id .. "|" .. sanitizeField(participant.fullName or participant.name, 80),
            channel,
            target
        )
    end
    return sendAddonMessage("ROLLTARGETDONE|" .. id, channel, target)
end

function Ploty:StartRollRequest(title, target, minimum, maximum)
    if not self:IsPlotActive() then
        self:Print("Starte zuerst den Plot über die Übersicht.")
        return false
    end
    if not self:CanControlRollRequest() then
        self:Print("Nur die Gruppenleitung kann eine Würfelaufforderung senden.")
        return false
    end

    local selected = self:GetSelectedRollParticipants()
    if #selected == 0 then
        self:Print("Wähle zuerst mindestens einen Spieler aus.")
        return false
    end

    if not self:SetRollRange(minimum, maximum) then
        return false
    end

    local minValue, maxValue = self:GetRollRange()
    target = trim(target)
    if target == "" then
        target = nil
    else
        target = math.floor(tonumber(target) or -1)
        if target < minValue or target > maxValue then
            self:Print("Der Zielwert muss zwischen dem Mindestwert und dem Höchstwert liegen.")
            return false
        end
    end

    title = trim(title)
    if title == "" then
        title = "Würfelprobe"
    end

    -- Ergebnisse bleiben nach der Probe zur Auswertung sichtbar. Erst wenn
    -- eine neue, vollständig geprüfte Aufforderung beginnt, wird der alte
    -- Würfelstand ausdrücklich und für alle Ploty-Clients synchron geleert.
    if next(self.db.participantRolls or {}) ~= nil or self.db.lastRoll ~= nil then
        self:ClearParticipantRolls(true)
    end

    local round = {
        id = tostring(time()) .. tostring(math.random(1000, 9999)),
        title = sanitizeField(title, 80),
        minimum = minValue,
        maximum = maxValue,
        target = target,
        targets = {},
    }
    for _, participant in ipairs(selected) do
        round.targets[participant.key] = participant.fullName or participant.name
    end

    self:ApplyRollRound(round, Ploty.GetUnitFullName("player"), false)
    self:BroadcastRollRound()
    self:BroadcastRollRequestTargets()

    local playerName = Ploty.GetUnitFullName("player")
    for _, participant in ipairs(selected) do
        local targetName = participant.fullName or participant.name
        if samePlayerName(targetName, playerName) then
            self.db.rollRound.requestPending = true
        else
            sendAddonMessage("ROLLCALLONE|" .. sanitizeField(round.id, 30), "WHISPER", targetName)
        end
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    self:Print("Würfelaufforderung an " .. #selected .. " Spieler gesendet: " .. round.title)
    return true
end

-- Kompatibilitätsname; eine Auswahl ist trotzdem zwingend erforderlich.
function Ploty:StartRollRound(title, target, minimum, maximum)
    return self:StartRollRequest(title, target, minimum, maximum)
end

function Ploty:RequestAllParticipantsRoll(silent)
    if not silent then
        self:Print("'Alle würfeln lassen' wurde entfernt. Wähle die benötigten Spieler gezielt aus.")
    end
    return false
end

function Ploty:RequestParticipantRoll(name)
    if not self:IsPlotActive() then
        self:Print("Der Plot wurde noch nicht gestartet.")
        return false
    end
    local round = self.db.rollRound
    if not round or not round.active then
        self:Print("Sende zuerst eine Würfelaufforderung.")
        return false
    end
    if not self:CanControlRollRequest() then
        self:Print("Nur die Gruppenleitung kann Teilnehmer zum Würfeln auffordern.")
        return false
    end

    local wanted = playerKey(name)
    local target
    local displayName
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        if participant.key == wanted then
            target = participant.fullName or participant.name
            displayName = participant.name
            break
        end
    end

    if not target then
        self:Print("Der ausgewählte Spieler ist nicht mehr in der Gruppe.")
        return false
    end
    if not self:IsRollRequestTarget(target) then
        self:Print("Dieser Spieler gehört nicht zur aktuellen Würfelauswahl.")
        return false
    end

    if samePlayerName(target, Ploty.GetUnitFullName("player")) then
        self.db.rollRound.requestPending = true
        if self.RefreshRollRound then
            self:RefreshRollRound()
        end
        self:Print("Eigene Würfelaufforderung erneuert.")
        return true
    end

    if not sendAddonMessage("ROLLCALLONE|" .. sanitizeField(round.id, 30), "WHISPER", target) then
        self:Print("Die Würfelaufforderung konnte nicht gesendet werden.")
        return false
    end

    self:Print("Würfelaufforderung an " .. displayName .. " gesendet.")
    return true
end

function Ploty:DoRequestedRoll()
    if not self:IsPlotActive() then
        self:Print("Der Plot wurde noch nicht gestartet.")
        return false
    end
    local round = self.db.rollRound
    if round and round.active and round.requestPending then
        return self:DoRoll()
    end
    self:Print("Du kannst erst würfeln, wenn die Plotleitung dich dazu auffordert.")
    return false
end

function Ploty:SetSortRolls(enabled)
    self.db.settings.sortRolls = enabled and true or false
    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
end

function Ploty:GetSortedRollParticipants()
    local participants = self:GetCurrentRollParticipants()
    for index, participant in ipairs(participants) do
        participant.groupIndex = index
    end

    table.sort(participants, function(first, second)
        local function priority(participant)
            if self:IsRollRequestTarget(participant.fullName or participant.name) then
                return 1
            elseif self:IsRollParticipantSelected(participant.fullName or participant.name) then
                return 2
            end
            return 3
        end
        local firstPriority = priority(first)
        local secondPriority = priority(second)
        if firstPriority ~= secondPriority then
            return firstPriority < secondPriority
        end
        if not self.db.settings.sortRolls then
            return first.groupIndex < second.groupIndex
        end

        local firstRoll = self.db.participantRolls[playerKey(first.name)]
        local secondRoll = self.db.participantRolls[playerKey(second.name)]
        if firstRoll and secondRoll then
            if tonumber(firstRoll.result) == tonumber(secondRoll.result) then
                return first.name < second.name
            end
            return tonumber(firstRoll.result) > tonumber(secondRoll.result)
        elseif firstRoll then
            return true
        elseif secondRoll then
            return false
        end
        return first.name < second.name
    end)

    return participants
end

local originalHandleSystemMessage = Ploty.HandleSystemMessage
function Ploty:HandleSystemMessage(message)
    originalHandleSystemMessage(self, message)

    if not self.rollPattern or not message then
        return
    end
    local roller = message:match(self.rollPattern)
    if not roller then
        return
    end

    roller = self:ResolveGroupPlayerName(roller)
    local roll = self.db.participantRolls[playerKey(roller)]
    if roll and self.db.rollRound and self.db.rollRound.active then
        roll.roundId = self.db.rollRound.id
        if samePlayerName(roller, Ploty.GetUnitFullName("player")) then
            self.db.rollRound.requestPending = false
            if self.RefreshRollRound then
                self:RefreshRollRound()
            end
        end
    end
end

local originalSendEmoteText = Ploty.SendEmoteText
function Ploty:SendEmoteText()
    local success = originalSendEmoteText(self)
    if not success then
        return false
    end

    self.typingActivityToken = (self.typingActivityToken or 0) + 1
    self:SetTypingState(false, true)
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self:SetAllowLongEmoteText(false)
    return true
end

local originalResendLastEmote = Ploty.ResendLastEmote
function Ploty:ResendLastEmote()
    local success = originalResendLastEmote(self)
    if not success then
        return false
    end

    self.typingActivityToken = (self.typingActivityToken or 0) + 1
    self:SetTypingState(false, true)
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self:SetAllowLongEmoteText(false)
    return true
end

function Ploty:GetCurrentGroupKeys()
    local keys = {}
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        keys[participant.key] = true
    end
    return keys
end

function Ploty:ResetOrderAfterGroupDeparture()
    if not self.db then
        return false
    end

    local hadOrder = clearGroupBoundSavedState(self)

    self.incomingOrders = {}
    self.incomingEmoteGroups = {}
    self.lastReceivedOrderSignature = nil
    self.incomingRollTargets = nil
    self.groupDeparturePending = false
    self.longTextRequestPending = false
    self.longTextRequestToken = nil
    self.pendingLongTextRequest = nil
    self:SetAllowLongEmoteText(false)
    self.plotActive = false
    self.plotStartedAt = nil
    self.plotLeader = nil

    if self.SetEmoteOrderUnread then
        self:SetEmoteOrderUnread(false)
    end
    if self.SetRollRequestUnread then
        self:SetRollRequestUnread(false)
    end
    if self.RefreshEmoteGroupUI then
        self:RefreshEmoteGroupUI()
    elseif self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    self:RefreshPlotStateUI()
    return hadOrder
end

function Ploty:TrackGroupMembership()
    local inGroup = IsInGroup() and true or false
    local wasInGroup = self.wasInWoWGroup and true or false

    if inGroup then
        self.wasInWoWGroup = true
        self.groupDeparturePending = false
        self.groupMembershipToken = (self.groupMembershipToken or 0) + 1
        if #(self.db.emoteOrder or {}) > 0 then
            self.db.orderWasGroupBound = true
        end
        return false
    end

    self.wasInWoWGroup = false
    if not wasInGroup and not self.groupDeparturePending then
        return false
    end

    self.groupMembershipToken = (self.groupMembershipToken or 0) + 1
    local token = self.groupMembershipToken
    self.groupDeparturePending = true

    -- Ein kurzer Aufschub verhindert, dass ein vorübergehend unvollständiger
    -- Rosterzustand bei Ladebildschirmen die Reihenfolge löscht. Betritt der
    -- Spieler sofort wieder eine Gruppe, macht das nächste Ereignis den Token
    -- ungültig.
    C_Timer.After(0.25, function()
        if Ploty.groupMembershipToken ~= token then
            return
        end

        Ploty.groupDeparturePending = false
        if not IsInGroup() then
            Ploty:ResetOrderAfterGroupDeparture()
        end
    end)
    return true
end

function Ploty:CleanupParticipantData()
    local tables = {
        self.db.participantStates,
        self.db.typingStates,
        self.db.peerVersions,
        self.db.participantRolls,
        self.db.rollSelection,
        self.db.rollRound and self.db.rollRound.targets,
    }

    -- 0.18.0 speicherte nur Kurznamen. Sobald ein eindeutiger Realmname
    -- verfügbar ist, werden diese Schlüssel verlustfrei auf das neue Format
    -- gehoben, bevor veraltete Gruppendaten entfernt werden.
    for _, data in ipairs(tables) do
        self:MigratePlayerKeyedTable(data)
    end

    local valid = self:GetCurrentGroupKeys()

    for _, data in ipairs(tables) do
        for key in pairs(data or {}) do
            if not valid[key] then
                data[key] = nil
            end
        end
    end

    local orderChanged = false
    if IsInGroup() then
        local previousCurrentName = self:GetCurrentEmoteParticipant()
        for index = #(self.db.emoteOrder or {}), 1, -1 do
            if not valid[playerKey(self.db.emoteOrder[index])] then
                table.remove(self.db.emoteOrder, index)
                orderChanged = true
            end
        end
        if orderChanged then
            self:RestoreCurrentEmoteParticipant(previousCurrentName)
        end
    end

    return orderChanged
end

function Ploty:GetGroupSignature()
    local names = {}
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        names[#names + 1] = participant.key
    end
    table.sort(names)
    return table.concat(names, ",")
end

function Ploty:SendHello()
    local channel = self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end

    local now = GetTime and GetTime() or 0
    if now > 0 and now - (self.lastHelloAt or 0) < 2 then
        return false
    end
    self.lastHelloAt = now
    return sendAddonMessage("HELLO|" .. tostring(self.version), channel)
end

function Ploty:GetNotificationSound(reason)
    if reason == "rollcall" then
        return SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK) or 8959
    end
    return SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.RAID_WARNING) or 8960
end

function Ploty:NotifyUser(reason)
    if self.db and self.db.settings and self.db.settings.notifications == false then
        return false
    end

    reason = tostring(reason or "general")
    local notificationClass = reason == "rollcall" and "rollcall" or "general"
    local now = GetTime and GetTime() or 0
    self.lastNotificationTimes = type(self.lastNotificationTimes) == "table" and self.lastNotificationTimes or {}
    if now > 0 and now - (self.lastNotificationTimes[notificationClass] or 0) < 0.8 then
        return false
    end
    self.lastNotificationTimes[notificationClass] = now

    if type(PlaySound) == "function" then
        pcall(PlaySound, self:GetNotificationSound(reason), "Master")
    end
    if type(FlashClientIcon) == "function" then
        pcall(FlashClientIcon)
    end
    return true
end

function Ploty:NotifyIfPlayerTurn(reason)
    if not self:IsPlotActive() or self.db.emotePaused then
        return false
    end

    local currentName = self:GetCurrentEmoteParticipant()
    if not currentName or not samePlayerName(currentName, Ploty.GetUnitFullName("player")) then
        return false
    end

    -- Diese Funktion wird nur bei einer tatsächlich empfangenen Zugänderung
    -- aufgerufen. Der kurze NotifyUser-Cooldown unterdrückt Doppelpakete, ohne
    -- spätere Runden am selben Listenindex stumm zu schalten.
    return self:NotifyUser(reason or "turn")
end

function Ploty:BroadcastAllStatuses(target)
    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        return
    end

    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        local status = self.db.participantStates[participant.key]
        if status and VALID_STATUSES[status] then
            sendAddonMessage(
                "STATUS|" .. sanitizeField(participant.fullName or participant.name, 80) .. "|" .. status,
                channel,
                target
            )
        end
    end
end

function Ploty:BroadcastEnhancedState(target, skipPlotState)
    if not self:CanSyncEmoteOrder() then
        return
    end

    if not skipPlotState then
        self:BroadcastPlotState(target)
    end

    if target then
        self:BroadcastRollRound(target)
        self:BroadcastRollRequestTargets(target)
        local targetRoll = self.db.participantRolls[playerKey(target)]
        if self:IsRollRequestTarget(target) and
            (not targetRoll or tostring(targetRoll.roundId or "") ~= tostring(self.db.rollRound.id or "")) then
            sendAddonMessage("ROLLCALLONE|" .. sanitizeField(self.db.rollRound.id, 30), "WHISPER", target)
        end
        self:BroadcastAllStatuses(target)
        sendAddonMessage(
            "CONTROL|" .. tostring(self:NormalizeEmoteTurnIndex()) .. "|" .. (self.db.emotePaused and "1" or "0"),
            "WHISPER",
            target
        )
    else
        self:BroadcastRollRound()
        self:BroadcastRollRequestTargets()
        self:BroadcastAllStatuses()
        self:BroadcastTurnControl()
    end
end

function Ploty:HandleGroupRosterChanged()
    local departurePending = self:TrackGroupMembership()
    -- Während der kurzen Austrittsprüfung liefert WoW vorübergehend nur den
    -- Spieler selbst. Gruppengebundene Tabellen dürfen in diesem Zwischenstand
    -- nicht einzeln und damit unwiederbringlich ausgedünnt werden.
    if not IsInGroup() and (departurePending or self.groupDeparturePending) then
        if self.RefreshClientVersions then
            self:RefreshClientVersions()
        end
        return
    end

    local orderChanged = self:CleanupParticipantData()

    local signature = self:GetGroupSignature()
    if signature == self.lastGroupSignature then
        if self.RefreshClientVersions then
            self:RefreshClientVersions()
        end
        return
    end
    self.lastGroupSignature = signature

    if IsInGroup() then
        if #(self.db.emoteOrder or {}) > 0 then
            self.db.orderWasGroupBound = true
        end
        -- HELLO genügt für die automatische Zustandssynchronisierung. Das frühere
        -- zusätzliche REQUEST erzeugte nach Reload doppelte Reihenfolgen und Meldungen.
        self:SendHello()
        if self:CanSyncEmoteOrder() then
            if self:IsPlotActive() then
                if orderChanged and #(self.db.emoteOrder or {}) > 0 then
                    self:SendEmoteOrder(true)
                end
            else
                self:BroadcastPlotReset()
            end
        end
    end

    if self.RefreshClientVersions then
        self:RefreshClientVersions()
    end
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
end

function Ploty:GetClientVersionRows()
    local rows = {}
    local playerName = Ploty.GetUnitFullName("player")
    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        local version
        if samePlayerName(participant.name, playerName) then
            version = self.version
        else
            local peer = self.db.peerVersions[participant.key]
            version = peer and peer.version or nil
        end

        rows[#rows + 1] = {
            name = participant.name,
            version = version,
            outdated = version and compareVersions(version, self.version) < 0 or false,
        }
    end
    return rows
end

function Ploty:HasOutdatedClients()
    for _, row in ipairs(self:GetClientVersionRows()) do
        if row.outdated then
            return true
        end
    end
    return false
end

local originalSendEmoteOrder = Ploty.SendEmoteOrder
function Ploty:SendEmoteOrder(silent, syncMode, target)
    local fullState = syncMode ~= "order"
    -- Teilnehmer akzeptieren ORDER und die übrigen Laufzeitpakete nur bei
    -- aktivem Plot. Deshalb muss PLOTSTATE stets zuerst eintreffen.
    if fullState and self:IsPlotActive() and not self:BroadcastPlotState(target) then
        return false
    end

    local success = originalSendEmoteOrder(self, silent, target)
    if success then
        if syncMode == "order" then
            if self.BroadcastEmoteGroups then
                self:BroadcastEmoteGroups(target)
            end
        else
            self:BroadcastEnhancedState(target, true)
        end
    end
    return success
end

local originalHandleAddonMessage = Ploty.HandleAddonMessage
function Ploty:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX or type(message) ~= "string" or not sender then
        return
    end

    if samePlayerName(sender, Ploty.GetUnitFullName("player")) then
        return
    end

    local command = message:match("^([^|]+)")

    if command == "PLOTSTATE" then
        local activeText, startedAtText = message:match("^PLOTSTATE|([01])|(%d+)$")
        local active = activeText == "1"
        if activeText and startedAtText and self:CanApplyPlotState(sender, active) then
            self:ApplyPlotState(active, startedAtText, sender)
        end
        return
    elseif command == "PLOTRESET" then
        if message == "PLOTRESET|0" and self:CanApplyPlotReset(sender) then
            self:ApplyPlotState(false, 0, sender)
        end
        return
    elseif command == "HELLO" then
        if self:IsSenderInGroup(sender) and not samePlayerName(sender, Ploty.GetUnitFullName("player")) then
            local version = sanitizeField(message:match("^HELLO|(.+)$") or "?", 30)
            self.db.peerVersions[playerKey(sender)] = {
                version = version,
                seenAt = time(),
            }
            if self.RefreshClientVersions then
                self:RefreshClientVersions()
            end

            if self:IsLocalPlotAuthority() then
                if self:IsPlotActive() then
                    self:SendEmoteOrder(true, nil, sender)
                else
                    self:BroadcastPlotState(sender)
                end
            end
        end
        return
    end

    -- Solange die Leitung den Plot nicht gestartet hat, lösen verspätete oder
    -- gespeicherte Ablaufpakete weder Reihenfolge noch Würfel- oder Zugzustände aus.
    if not self:IsPlotActive() then
        return
    end

    if command == "STATUS" then
        local targetName, status = message:match("^STATUS|([^|]+)|([^|]+)$")
        if status == "SKIPPED" then
            status = "ABSENT"
        elseif status == "FINISHED" then
            status = "READY"
        end
        if targetName and VALID_STATUSES[status] and self:IsSenderInGroup(sender) then
            if samePlayerName(targetName, sender) or self:IsAuthorizedOrderSender(sender) then
                self.db.participantStates[playerKey(targetName)] = status
                if status == "ABSENT" then
                    self.db.typingStates[playerKey(targetName)] = nil
                end
                if self.RefreshEmoteOrder then
                    self:RefreshEmoteOrder()
                end
                if self.RefreshGlobalTurnBar then
                    self:RefreshGlobalTurnBar()
                end
                local currentName = self:GetCurrentEmoteParticipant()
                if status == "ABSENT" and currentName and samePlayerName(targetName, currentName) and self:CanSyncEmoteOrder() then
                    self:MoveOfficialEmoteTurn(1)
                end
            end
        end
        return
    elseif command == "TYPING" then
        local value = message:match("^TYPING|([01])$")
        if value and self:IsSenderInGroup(sender) then
            self.db.typingStates[playerKey(sender)] = value == "1" and self:IsPlayerCurrentEmoter(sender) and true or nil
            if self.RefreshEmoteOrder then
                self:RefreshEmoteOrder()
            end
            if self.RefreshGlobalTurnBar then
                self:RefreshGlobalTurnBar()
            end
        end
        return
    elseif command == "LONGREQ" then
        local token = message:match("^LONGREQ|([^|]+)$")
        if token and self:HasLeaderPrivileges() and self:IsSenderInGroup(sender) and self:IsPlayerCurrentEmoter(sender) then
            self.pendingLongTextRequest = {
                sender = sender,
                token = sanitizeField(token, 30),
            }
            self:Print(shortName(sender) .. " bittet um Freigabe für ein längeres Emote.")
            if self.ShowLongTextRequestDialog then
                self:ShowLongTextRequestDialog(sender)
            end
            self:NotifyUser("turn")
        end
        return
    elseif command == "LONGALLOW" or command == "LONGDENY" then
        local token = message:match("^[^|]+|([^|]+)$")
        if token
            and self:IsAuthorizedOrderSender(sender)
            and self.longTextRequestPending
            and tostring(self.longTextRequestToken or "") == tostring(token)
        then
            self.longTextRequestPending = false
            self.longTextRequestToken = nil
            if command == "LONGALLOW" and self:IsPlayerCurrentEmoter(Ploty.GetUnitFullName("player")) then
                self:SetAllowLongEmoteText(true)
                self:Print("Die Plotleitung hat längere Emotes für diesen Zug freigegeben.")
            else
                self:SetAllowLongEmoteText(false)
                self:Print("Die Plotleitung hat die Langtext-Anfrage abgelehnt.")
            end
            if self.UpdateEmoteTextState then
                self:UpdateEmoteTextState()
            end
        end
        return
    elseif command == "CONTROL" then
        local indexText, pausedText = message:match("^CONTROL|(%d+)|([01])$")
        if indexText and self:IsAuthorizedOrderSender(sender) then
            local index = math.floor(tonumber(indexText) or 0)
            if index >= 1 and index <= #(self.db.emoteOrder or {}) then
                self.db.currentEmoteIndex = index
                self.db.emotePaused = pausedText == "1"
                self:RefreshEmoteTurnState()
                if self.RefreshGlobalTurnBar then
                    self:RefreshGlobalTurnBar()
                end
                self:NotifyIfPlayerTurn("turn")
            end
        end
        return
    elseif command == "ROLLROUND" then
        local id, minimum, maximum, target, title = message:match("^ROLLROUND|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
        if id and self:IsAuthorizedOrderSender(sender) then
            minimum = math.floor(tonumber(minimum) or 1)
            maximum = math.floor(tonumber(maximum) or 20)
            target = tonumber(target)
            if target == 0 then
                target = nil
            end
            if minimum >= 1 and maximum >= minimum and maximum <= MAX_ROLL_VALUE then
                self:ApplyRollRound({
                    id = id,
                    title = title,
                    minimum = minimum,
                    maximum = maximum,
                    target = target,
                }, sender, false)
            end
        end
        return
    elseif command == "ROLLCLEAR" then
        local id = message:match("^ROLLCLEAR|([^|]+)$")
        if id and #id <= 30 and self:IsAuthorizedOrderSender(sender) then
            local currentId = tostring(self.db.rollRound and self.db.rollRound.id or "")
            if (id == "0" and currentId == "") or id == currentId then
                self:ClearParticipantRolls(false)
            end
        end
        return
    elseif command == "ROLLTARGETRESET" then
        local id = message:match("^ROLLTARGETRESET|([^|]+)$")
        if id and #id <= 30 and self:IsAuthorizedOrderSender(sender) and tostring(self.db.rollRound.id or "") == id then
            self.incomingRollTargets = { id = id, sender = sender, targets = {}, count = 0 }
        end
        return
    elseif command == "ROLLTARGET" then
        local id, targetName = message:match("^ROLLTARGET|([^|]+)|([^|]+)$")
        local transfer = self.incomingRollTargets
        if id and targetName and #id <= 30 and #targetName <= 80 and transfer and transfer.id == id and
            samePlayerName(sender, transfer.sender) and transfer.count < 40 and
            self:IsAuthorizedOrderSender(sender) and tostring(self.db.rollRound.id or "") == id then
            targetName = self:ResolveGroupPlayerName(targetName)
            if self:IsCurrentRollParticipant(targetName) then
                local targetKey = playerKey(targetName)
                if not transfer.targets[targetKey] then
                    transfer.targets[targetKey] = targetName
                    transfer.count = transfer.count + 1
                end
            end
        end
        return
    elseif command == "ROLLTARGETDONE" then
        local id = message:match("^ROLLTARGETDONE|([^|]+)$")
        local transfer = self.incomingRollTargets
        if id and #id <= 30 and transfer and transfer.id == id and samePlayerName(sender, transfer.sender) and
            self:IsAuthorizedOrderSender(sender) and
            tostring(self.db.rollRound.id or "") == id then
            self.db.rollRound.targets = transfer.targets
            self.incomingRollTargets = nil
            local playerName = Ploty.GetUnitFullName("player")
            local playerRoll = self.db.participantRolls[playerKey(playerName)]
            local alreadyRolled = playerRoll and
                tostring(playerRoll.roundId or "") == tostring(self.db.rollRound.id or "")
            local wasPending = self.db.rollRound.requestPending and true or false
            self.db.rollRound.requestPending = transfer.targets[playerKey(playerName)] ~= nil and not alreadyRolled
            if self.SetRollRequestUnread then
                self:SetRollRequestUnread(self.db.rollRound.requestPending and (not self.rollPage or not self.rollPage:IsShown()))
            end
            if self.RefreshParticipantRolls then
                self:RefreshParticipantRolls()
            end
            if self.RefreshRollRound then
                self:RefreshRollRound()
            end
            if self.db.rollRound.requestPending and not wasPending then
                self:NotifyUser("rollcall")
            end
        end
        return
    elseif command == "ROLLCALL" or command == "ROLLCALLONE" then
        local id = message:match("^[^|]+|(.+)$")
        if id and self:IsAuthorizedOrderSender(sender) and self.db.rollRound.id == id then
            local wasPending = self.db.rollRound.requestPending and true or false
            local playerName = Ploty.GetUnitFullName("player")
            local playerRoll = self.db.participantRolls[playerKey(playerName)]
            local alreadyRolled = playerRoll and
                tostring(playerRoll.roundId or "") == tostring(self.db.rollRound.id or "")
            self.db.rollRound.targets[playerKey(playerName)] = playerName
            self.db.rollRound.requestPending = not alreadyRolled
            if self.SetRollRequestUnread then
                self:SetRollRequestUnread(self.db.rollRound.requestPending and (not self.rollPage or not self.rollPage:IsShown()))
            end
            if self.RefreshRollRound then
                self:RefreshRollRound()
            end
            if self.RefreshParticipantRolls then
                self:RefreshParticipantRolls()
            end
            if self.db.rollRound.requestPending and (not wasPending or command == "ROLLCALLONE") then
                self:NotifyUser("rollcall")
            end
        end
        return
    end

    -- REQUEST wird bereits vollständig im Kern verarbeitet. SendEmoteOrder
    -- überträgt über den Wrapper auch Status, Zug und Würfelprobe genau einmal.
    originalHandleAddonMessage(self, prefix, message, channel, sender)
end
