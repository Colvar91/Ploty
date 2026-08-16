local addonName, Ploty = ...

Ploty.name = addonName
-- Ploty enthält Leitungs- und Teilnehmeroberfläche in einem Addon.
-- Der Modus wird anhand der aktuellen Gruppenrechte automatisch gewählt.
Ploty.isParticipantBuild = true
Ploty.prefix = "|cffb58cffPloty:|r "

local COMM_PREFIX = Ploty.COMM_PREFIX
local ENTRY_SEPARATOR = string.char(31)
local MAX_CHUNK_PAYLOAD = 180
local MAX_ORDER_ENTRIES = 80
local MAX_EMOTE_CHARACTERS = 1020
local MAX_EMOTE_BLOCKS = 4
local MAX_CHAT_MESSAGE_BYTES = 255
local MAX_ROLL_VALUE = 1000000

local VALID_EMOTE_CHANNELS = {
    SAY = true,
    YELL = true,
    PARTY = true,
    RAID = true,
}

local EMOTE_CHANNEL_LABELS = {
    SAY = "Say",
    YELL = "Yell",
    PARTY = "Gruppe",
    RAID = "Raid",
}

local defaults = {
    dbVersion = Ploty.DB_VERSION,
    settings = {
        minimapAngle = 225,
        rollMinimum = 1,
        rollMaximum = 20,
        notifications = true,
        writingCheckEnabled = false,
    },
    positions = {
        main = nil,
    },
    lastRoll = nil,
    participantRolls = {},
    emoteOrder = {},
    currentEmoteIndex = 1,
    orderSender = nil,
    orderUpdatedAt = nil,
    emoteText = {
        draft = "",
        clearAfterSend = true,
        allowLongText = false,
        channel = "SAY",
        lastSentAt = nil,
        lastSentText = "",
        lastSentChannel = "SAY",
    },
}

local function copyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            copyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local trim = Ploty.Trim
local shortName = Ploty.ShortName
local function samePlayerName(first, second)
    return Ploty:SamePlayerName(first, second)
end
local function playerKey(name)
    return Ploty:PlayerKey(name)
end
local copyArray = Ploty.CopyArray

local function prepareEmoteText(value)
    value = tostring(value or "")
    value = value:gsub("[\r\n]+", " ")
    value = value:gsub("%s+", " ")
    return trim(value)
end

local function parseSlashEmoteCommand(value)
    local command, payload = prepareEmoteText(value):match("^/(%S+)%s*(.*)$")
    command = command and command:lower() or nil
    if command == "me" or command == "e" or command == "em" or command == "emote" then
        return command, payload or ""
    end
    return nil, nil
end

function Ploty:IsSlashEmoteCommand(value)
    return parseSlashEmoteCommand(value) ~= nil
end

function Ploty:GetSlashEmotePayload(value)
    local _, payload = parseSlashEmoteCommand(value)
    return payload
end

function Ploty:IsSlashEmoteAllowed(value, channel)
    channel = channel or self:GetEmoteChannel()
    return channel == "SAY" or not self:IsSlashEmoteCommand(value)
end

local function escapePreviewText(value)
    return tostring(value or ""):gsub("|", "||")
end

local function buildInlineRpOverlay(value, misspellings)
    value = tostring(value or "")
    if value == "" then
        return ""
    end

    local parts = {}
    local position = 1
    local valueLength = #value
    misspellings = misspellings or {}

    local function appendWithSpelling(segmentStart, segmentEnd, color)
        if not segmentStart or not segmentEnd or segmentStart > segmentEnd then
            return
        end

        local cursor = segmentStart
        for _, issue in ipairs(misspellings) do
            local issueStart = issue.startPosition
            local issueEnd = issue.endPosition
            if issueStart and issueEnd and issueEnd >= segmentStart and issueStart <= segmentEnd then
                local redStart = math.max(cursor, issueStart)
                local redEnd = math.min(segmentEnd, issueEnd)
                if redStart > cursor then
                    parts[#parts + 1] = color .. escapePreviewText(value:sub(cursor, redStart - 1)) .. "|r"
                end
                if redEnd >= redStart then
                    parts[#parts + 1] = "|cffff5555" .. escapePreviewText(value:sub(redStart, redEnd)) .. "|r"
                    cursor = redEnd + 1
                end
            end
        end

        if cursor <= segmentEnd then
            parts[#parts + 1] = color .. escapePreviewText(value:sub(cursor, segmentEnd)) .. "|r"
        end
    end

    -- Normaler Text bleibt im eigentlichen EditBox-Text weiß sichtbar.
    -- Im darüberliegenden FontString wird er transparent dargestellt,
    -- damit nur Emote-Bereiche und Rechtschreibfehler überlagert werden.
    local function appendTransparent(segmentStart, segmentEnd)
        appendWithSpelling(segmentStart, segmentEnd, "|c00ffffff")
    end

    local function appendOrange(segmentStart, segmentEnd)
        appendWithSpelling(segmentStart, segmentEnd, "|cffff9a3c")
    end

    -- Ein benutzerdefiniertes WoW-Emote (/me, /e oder /emote) erscheint als
    -- orange Erzählung. Wörtliche Rede bleibt zur besseren Lesbarkeit weiß.
    -- Die transparenten Segmente lassen dafür den weißen EditBox-Text sichtbar.
    if parseSlashEmoteCommand(value) then
        local quoteTokens = { '"', "„", "“", "”" }
        local insideQuote = false

        local function findNextQuote(startPosition)
            local foundPosition
            local foundToken
            for _, token in ipairs(quoteTokens) do
                local candidate = value:find(token, startPosition, true)
                if candidate and (not foundPosition or candidate < foundPosition) then
                    foundPosition = candidate
                    foundToken = token
                end
            end
            return foundPosition, foundToken
        end

        while position <= valueLength do
            local quotePosition, quoteToken = findNextQuote(position)
            if not quotePosition then
                if insideQuote then
                    appendTransparent(position, valueLength)
                else
                    appendOrange(position, valueLength)
                end
                break
            end

            if insideQuote then
                appendTransparent(position, quotePosition - 1)
            else
                appendOrange(position, quotePosition - 1)
            end
            appendTransparent(quotePosition, quotePosition + #quoteToken - 1)
            insideQuote = not insideQuote
            position = quotePosition + #quoteToken
        end

        return table.concat(parts)
    end

    while position <= valueLength do
        local starOpening = value:find("*", position, true)
        local starClosing = starOpening and value:find("*", starOpening + 1, true) or nil
        local angleOpening = value:find("<", position, true)
        local angleClosing = angleOpening and value:find(">", angleOpening + 1, true) or nil

        local openingPosition
        local closingPosition

        if starClosing and angleClosing then
            if starOpening < angleOpening then
                openingPosition = starOpening
                closingPosition = starClosing
            else
                openingPosition = angleOpening
                closingPosition = angleClosing
            end
        elseif starClosing then
            openingPosition = starOpening
            closingPosition = starClosing
        elseif angleClosing then
            openingPosition = angleOpening
            closingPosition = angleClosing
        else
            appendTransparent(position, valueLength)
            break
        end

        appendTransparent(position, openingPosition - 1)
        appendOrange(openingPosition, closingPosition)
        position = closingPosition + 1
    end

    return table.concat(parts)
end

local function utf8CharacterCount(value)
    value = tostring(value or "")
    local count = 0
    for index = 1, #value do
        local byte = value:byte(index)
        if byte < 128 or byte >= 192 then
            count = count + 1
        end
    end
    return count
end

local function truncateUtf8Characters(value, maximumCharacters)
    value = tostring(value or "")
    maximumCharacters = tonumber(maximumCharacters) or 0

    if maximumCharacters <= 0 or value == "" then
        return "", value ~= ""
    end

    local characterCount = 0
    local lastValidByte = 0

    for index = 1, #value do
        local byte = value:byte(index)
        if byte < 128 or byte >= 192 then
            characterCount = characterCount + 1
            if characterCount > maximumCharacters then
                return value:sub(1, lastValidByte), true
            end
        end
        lastValidByte = index
    end

    return value, false
end

local function splitChatMessage(value, maximumBytes)
    local chunks = {}
    local remaining = trim(value)

    while remaining ~= "" do
        if #remaining <= maximumBytes then
            chunks[#chunks + 1] = remaining
            break
        end

        local cut = maximumBytes
        while cut > 0 do
            local nextByte = remaining:byte(cut + 1)
            if not nextByte or nextByte < 128 or nextByte >= 192 then
                break
            end
            cut = cut - 1
        end

        if cut <= 0 then
            return nil
        end

        local candidate = remaining:sub(1, cut)
        local whitespace = candidate:match("^.*()%s")
        if whitespace and whitespace >= math.floor(maximumBytes * 0.55) then
            cut = whitespace - 1
        end

        local chunk = trim(remaining:sub(1, cut))
        if chunk == "" then
            return nil
        end

        chunks[#chunks + 1] = chunk
        remaining = trim(remaining:sub(cut + 1))
    end

    return chunks
end

local function escapePatternCharacter(character)
    if character:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        return "%" .. character
    end
    return character
end

local function buildFormatPattern(formatString)
    formatString = formatString or "%s rolls %d (%d-%d)"
    formatString = formatString:gsub("%%(%d+)%$s", "%%s")
    formatString = formatString:gsub("%%(%d+)%$d", "%%d")

    local output = { "^" }
    local index = 1

    while index <= #formatString do
        local character = formatString:sub(index, index)
        if character == "%" then
            local token = formatString:sub(index + 1, index + 1)
            if token == "s" then
                output[#output + 1] = "(.+)"
                index = index + 2
            elseif token == "d" then
                output[#output + 1] = "(%d+)"
                index = index + 2
            elseif token == "%" then
                output[#output + 1] = "%%"
                index = index + 2
            else
                output[#output + 1] = "%%"
                index = index + 1
            end
        else
            output[#output + 1] = escapePatternCharacter(character)
            index = index + 1
        end
    end

    output[#output + 1] = "$"
    return table.concat(output)
end

local function registerCommunicationPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    elseif RegisterAddonMessagePrefix then
        return RegisterAddonMessagePrefix(COMM_PREFIX)
    end
    return false
end

local sendAddonMessage = Ploty.SendAddonMessage

function Ploty:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.prefix .. tostring(message))
end

function Ploty:InitializeDatabase()
    if type(PlotyDB) ~= "table" then
        PlotyDB = {}
    end

    copyDefaults(defaults, PlotyDB)

    -- Alte Schnellknopf-Daten aus 0.2 werden nicht mehr benötigt.
    if PlotyDB.settings then
        PlotyDB.settings.quickRollVisible = nil
    end
    if PlotyDB.positions then
        PlotyDB.positions.quickRoll = nil
    end

    local rollMinimum = math.floor(tonumber(PlotyDB.settings.rollMinimum) or 1)
    local rollMaximum = math.floor(tonumber(PlotyDB.settings.rollMaximum) or 20)
    if rollMinimum < 1 or rollMaximum < rollMinimum or rollMaximum > MAX_ROLL_VALUE then
        rollMinimum = 1
        rollMaximum = 20
    end
    PlotyDB.settings.rollMinimum = rollMinimum
    PlotyDB.settings.rollMaximum = rollMaximum

    if not VALID_EMOTE_CHANNELS[PlotyDB.emoteText.channel] then
        PlotyDB.emoteText.channel = "SAY"
    end

    if type(PlotyDB.participantRolls) ~= "table" then
        PlotyDB.participantRolls = {}
    end

    local orderCount = type(PlotyDB.emoteOrder) == "table" and #PlotyDB.emoteOrder or 0
    local currentEmoteIndex = math.floor(tonumber(PlotyDB.currentEmoteIndex) or 1)
    if orderCount == 0 then
        currentEmoteIndex = 1
    elseif currentEmoteIndex < 1 or currentEmoteIndex > orderCount then
        currentEmoteIndex = 1
    end
    PlotyDB.currentEmoteIndex = currentEmoteIndex

    if not PlotyDB.emoteText.allowLongText then
        local limitedDraft = truncateUtf8Characters(PlotyDB.emoteText.draft or "", MAX_EMOTE_CHARACTERS)
        PlotyDB.emoteText.draft = limitedDraft
    end

    PlotyDB.dbVersion = Ploty.DB_VERSION
    self.db = PlotyDB
    self.rollPattern = buildFormatPattern(RANDOM_ROLL_RESULT)
    self.incomingOrders = {}
end

function Ploty:InitializeCommunication()
    local registered = registerCommunicationPrefix()
    if not registered then
        self:Print("Addon-Kommunikation konnte nicht registriert werden.")
    end
end

function Ploty:GetRollOutcome(result, minimum, maximum)
    result = tonumber(result)
    minimum = tonumber(minimum)
    maximum = tonumber(maximum)

    if not result or not minimum or not maximum then
        return "–", "|cff888888"
    end

    if minimum == maximum then
        return "Treffer", "|cff55ff55"
    elseif result == minimum then
        return "Kritischer Fehlschlag", "|cffff3333"
    elseif result == maximum then
        return "Kritischer Treffer", "|cffffd200"
    end

    local hitThreshold = math.ceil((minimum + maximum) / 2)
    if result < hitThreshold then
        return "Fehlschlag", "|cffff8844"
    end

    return "Treffer", "|cff55ff55"
end

function Ploty:GetCurrentRollParticipants()
    local participants = {}
    local seen = {}

    local function addUnit(unit)
        if not UnitExists(unit) then
            return
        end

        local fullName = Ploty.GetUnitFullName(unit)
        local name = shortName(fullName)
        local key = playerKey(fullName)
        if name ~= "" and key ~= "" and not seen[key] then
            seen[key] = true
            participants[#participants + 1] = {
                name = name,
                fullName = fullName or name,
                key = key,
                unit = unit,
            }
        end
    end

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            addUnit("raid" .. index)
        end
    elseif IsInGroup() then
        addUnit("player")
        local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or math.max(0, GetNumGroupMembers() - 1)
        for index = 1, count do
            addUnit("party" .. index)
        end
    else
        addUnit("player")
    end

    local shortNameCounts = {}
    for _, participant in ipairs(participants) do
        local key = participant.name:lower()
        shortNameCounts[key] = (shortNameCounts[key] or 0) + 1
    end
    for _, participant in ipairs(participants) do
        if shortNameCounts[participant.name:lower()] > 1 then
            participant.name = participant.fullName
        end
    end

    return participants
end

function Ploty:IsCurrentRollParticipant(name)
    local wantedKey = playerKey(name)
    if wantedKey == "" then
        return false
    end

    for _, participant in ipairs(self:GetCurrentRollParticipants()) do
        if participant.key == wantedKey then
            return true
        end
    end

    return false
end

function Ploty:ClearParticipantRolls()
    self.db.participantRolls = {}
    self.db.lastRoll = nil

    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
    if self.RefreshLastRoll then
        self:RefreshLastRoll()
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
end

function Ploty:GetRollRange()
    local minimum = 1
    local maximum = 20

    if self.db and self.db.settings then
        minimum = math.floor(tonumber(self.db.settings.rollMinimum) or minimum)
        maximum = math.floor(tonumber(self.db.settings.rollMaximum) or maximum)
    end

    return minimum, maximum
end

function Ploty:SetRollRange(minimum, maximum)
    minimum = tonumber(minimum)
    maximum = tonumber(maximum)

    if not minimum or not maximum then
        self:Print("Bitte trage zwei gültige Zahlen für den Würfelbereich ein.")
        return false
    end

    minimum = math.floor(minimum)
    maximum = math.floor(maximum)

    if minimum < 1 or maximum < 1 then
        self:Print("Die Würfelwerte müssen mindestens 1 betragen.")
        return false
    end

    if minimum > maximum then
        self:Print("Der erste Würfelwert darf nicht größer als der zweite sein.")
        return false
    end

    if maximum > MAX_ROLL_VALUE then
        self:Print("Der höchste erlaubte Würfelwert ist " .. MAX_ROLL_VALUE .. ".")
        return false
    end

    self.db.settings.rollMinimum = minimum
    self.db.settings.rollMaximum = maximum

    if self.RefreshRollRange then
        self:RefreshRollRange()
    end
    return true
end

function Ploty:DoRoll()
    local round = self.db and self.db.rollRound
    local playerName = Ploty.GetUnitFullName("player")
    if not round or not round.active or not round.requestPending or
        (self.IsRollRequestTarget and not self:IsRollRequestTarget(playerName)) then
        self:Print("Du kannst erst würfeln, wenn die Plotleitung dich dazu auffordert.")
        return false
    end

    local minimum = math.floor(tonumber(round.minimum) or 1)
    local maximum = math.floor(tonumber(round.maximum) or 20)
    round.requestPending = false
    if self.SetRollRequestUnread then
        self:SetRollRequestUnread(false)
    end
    if self.RefreshRollRound then
        self:RefreshRollRound()
    end
    RandomRoll(minimum, maximum)
    return true
end

-- Kompatibilitätsname für ältere Aufrufe und den Minimap-Button.
function Ploty:DoD20Roll()
    return self:DoRoll()
end

function Ploty:GetPreparedEmoteText()
    if not self.db or not self.db.emoteText then
        return ""
    end
    return prepareEmoteText(self.db.emoteText.draft)
end

function Ploty:GetInlineRpOverlay(misspellings)
    if not self.db or not self.db.emoteText then
        return buildInlineRpOverlay("", {})
    end
    local draft = self.db.emoteText.draft or ""
    if misspellings == nil then
        misspellings = self.GetMisspelledWordRanges and self:GetMisspelledWordRanges(draft) or {}
    end
    return buildInlineRpOverlay(draft, misspellings)
end

function Ploty:GetEmoteTextInfo()
    local draft = ""
    if self.db and self.db.emoteText then
        draft = tostring(self.db.emoteText.draft or "")
    end

    local message = prepareEmoteText(draft)
    local chunks = splitChatMessage(message, MAX_CHAT_MESSAGE_BYTES) or {}
    return message, utf8CharacterCount(draft), chunks
end

function Ploty:SetEmoteDraft(value)
    if not self.db or not self.db.emoteText then
        return "", 0, false
    end

    -- Manuelle Zeilenumbrüche sind im RP-Textwerkzeug nicht vorgesehen.
    -- Das mehrzeilige EditBox bleibt nur für den automatischen Wortumbruch aktiv.
    value = tostring(value or ""):gsub("[\r\n]+", " ")

    if self:IsLongEmoteTextEnabled() then
        self.db.emoteText.draft = value
        return value, utf8CharacterCount(value), false
    end

    local limitedValue, wasTruncated = truncateUtf8Characters(value, MAX_EMOTE_CHARACTERS)
    self.db.emoteText.draft = limitedValue

    return limitedValue, utf8CharacterCount(limitedValue), wasTruncated
end

function Ploty:GetEmoteLimits()
    return MAX_EMOTE_CHARACTERS, MAX_EMOTE_BLOCKS
end

function Ploty:IsLongEmoteTextEnabled()
    return self.longTextApproved and true or false
end

function Ploty:SetAllowLongEmoteText(enabled)
    if not self.db or not self.db.emoteText then
        return
    end

    -- Die Freigabe gilt nur für den aktuellen Zug und wird deshalb nicht in den
    -- SavedVariables gespeichert. Der alte Schalter bleibt dauerhaft deaktiviert.
    self.db.emoteText.allowLongText = false
    self.longTextApproved = enabled and true or false

    if self.RefreshEmoteTextDraft then
        self:RefreshEmoteTextDraft()
    end
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
end

function Ploty:ClearEmoteDraft()
    if not self.db or not self.db.emoteText then
        return
    end

    self.db.emoteText.draft = ""
    if self.RefreshEmoteTextDraft then
        self:RefreshEmoteTextDraft()
    end
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
end

function Ploty:SetClearEmoteAfterSend(enabled)
    if not self.db or not self.db.emoteText then
        return
    end

    self.db.emoteText.clearAfterSend = enabled and true or false
end

function Ploty:GetEmoteChannel()
    if not self.db or not self.db.emoteText then
        return "SAY"
    end

    local channel = self.db.emoteText.channel
    if not VALID_EMOTE_CHANNELS[channel] then
        channel = "SAY"
        self.db.emoteText.channel = channel
    end
    return channel
end

function Ploty:GetEmoteChannelLabel(channel)
    channel = channel or self:GetEmoteChannel()
    return EMOTE_CHANNEL_LABELS[channel] or channel
end

function Ploty:SetEmoteChannel(channel)
    if not self.db or not self.db.emoteText or not VALID_EMOTE_CHANNELS[channel] then
        return false
    end

    if channel ~= "SAY" and self:IsSlashEmoteCommand(self.db.emoteText.draft or "") then
        self:Print("/me kann nur mit dem Kanal Say verwendet werden. Der Kanal wurde nicht geändert.")
        if self.RefreshEmoteChannelChecks then
            self:RefreshEmoteChannelChecks()
        end
        if self.UpdateEmoteTextState then
            self:UpdateEmoteTextState()
        end
        return false
    end

    self.db.emoteText.channel = channel

    if self.RefreshEmoteChannelChecks then
        self:RefreshEmoteChannelChecks()
    end
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    return true
end

function Ploty:IsEmoteChannelAvailable(channel)
    channel = channel or self:GetEmoteChannel()

    if channel == "RAID" then
        return IsInRaid()
    elseif channel == "PARTY" then
        return IsInGroup()
    end

    return true
end

function Ploty:GetResolvedEmoteChannel(channel)
    channel = channel or self:GetEmoteChannel()

    if channel == "PARTY" and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    return channel
end

function Ploty:SendEmoteText()
    if self.IsPlotActive and not self:IsPlotActive() then
        self:Print("Starte zuerst den Plot über die Übersicht.")
        return false
    end
    if not self:IsPlayerCurrentEmoter(Ploty.GetUnitFullName("player")) then
        self:Print("Du kannst dein Emote erst senden, wenn du an der Reihe bist.")
        return false
    end

    local message, characterCount, chunks = self:GetEmoteTextInfo()
    if message == "" then
        self:Print("Bitte schreibe zuerst einen RP-Text.")
        return false
    end

    local slashEmotePayload = self:GetSlashEmotePayload(message)
    if slashEmotePayload ~= nil and slashEmotePayload == "" then
        self:Print("Bitte schreibe hinter /me auch den eigentlichen Emote-Text.")
        return false
    end

    local allowLongText = self:IsLongEmoteTextEnabled()

    if not allowLongText and characterCount > MAX_EMOTE_CHARACTERS then
        self:Print("Der RP-Text ist zu lang. Erlaubt sind höchstens " .. MAX_EMOTE_CHARACTERS .. " Zeichen.")
        return false
    end

    if #chunks == 0 or (not allowLongText and #chunks > MAX_EMOTE_BLOCKS) then
        self:Print("Der RP-Text benötigt mehr als " .. MAX_EMOTE_BLOCKS .. " Chatblöcke. Bitte frage die Plotleitung nach einer Freigabe oder kürze ihn etwas.")
        return false
    end

    local selectedChannel = self:GetEmoteChannel()
    if not self:IsSlashEmoteAllowed(message, selectedChannel) then
        self:Print("/me kann nur mit dem Kanal Say verwendet werden. Entferne den Befehl oder wähle Say.")
        return false
    end
    if not self:IsEmoteChannelAvailable(selectedChannel) then
        if selectedChannel == "RAID" then
            self:Print("Für den Versand an Raid musst du dich in einem Schlachtzug befinden.")
        else
            self:Print("Für den Versand an Gruppe musst du dich in einer Gruppe befinden.")
        end
        return false
    end

    if type(SendChatMessage) ~= "function" then
        self:Print("Der RP-Text konnte nicht gesendet werden.")
        return false
    end

    -- SendChatMessage ist in diesem Client nur zuverlässig, solange der Aufruf
    -- unmittelbar aus dem bewussten Buttonklick des Spielers erfolgt. Frühere
    -- Versionen verschickten Folgeblöcke über C_Timer.After; diese Aufrufe liefen
    -- außerhalb des Hardware-Ereignisses und konnten von WoW blockiert werden.
    --
    -- Der Text wird deshalb genau einmal übergeben. Bei einem Slash-Emote geschieht
    -- das ohne Befehlspräfix über EMOTE, bei den übrigen Kanälen unverändert. Das
    -- installierte Addon UnlimitedChatMessage kann den Aufruf bei Bedarf in zulässige
    -- Chatnachrichten zerlegen. Ploty startet keine zeitversetzten Aufrufe mehr.
    if slashEmotePayload ~= nil then
        -- Slashbefehle werden nur im normalen WoW-Chatfeld ausgewertet. Addons
        -- müssen benutzerdefinierte Emotes ohne Befehlspräfix als EMOTE senden.
        SendChatMessage(slashEmotePayload, "EMOTE")
    else
        SendChatMessage(message, self:GetResolvedEmoteChannel(selectedChannel))
    end

    -- Nur das zuletzt tatsächlich versendete Emote wird für den Wiederholen-Button
    -- behalten. Eine Textbibliothek oder ein Verlauf wird nicht mehr geführt.
    self.db.emoteText.lastSentText = message
    self.db.emoteText.lastSentChannel = selectedChannel

    -- Ist der Spieler aktuell an der Reihe, springt die synchronisierte
    -- Emote-Reihenfolge nach dem bewussten Absenden zum nächsten Teilnehmer.
    self:AdvanceEmoteTurnForSender(Ploty.GetUnitFullName("player"), true)

    self.db.emoteText.lastSentAt = date("%H:%M:%S")
    self.db.emoteText.lastSentBlocks = #chunks

    if self.db.emoteText.clearAfterSend then
        self.db.emoteText.draft = ""
        if self.RefreshEmoteTextDraft then
            self:RefreshEmoteTextDraft()
        end
    end

    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    return true
end

function Ploty:ResendLastEmote()
    if not self.db or not self.db.emoteText then
        return false
    end

    if self.IsPlotActive and not self:IsPlotActive() then
        self:Print("Starte zuerst den Plot über die Übersicht.")
        return false
    end
    if not self:IsPlayerCurrentEmoter(Ploty.GetUnitFullName("player")) then
        self:Print("Du kannst ein Emote erst senden, wenn du an der Reihe bist.")
        return false
    end

    local message = prepareEmoteText(self.db.emoteText.lastSentText or "")
    if message == "" then
        self:Print("Es gibt noch kein letztes Emote zum erneuten Senden.")
        return false
    end

    local slashEmotePayload = self:GetSlashEmotePayload(message)
    if slashEmotePayload ~= nil and slashEmotePayload == "" then
        self:Print("Das letzte Emote enthält keinen Text hinter /me.")
        return false
    end

    if utf8CharacterCount(message) > MAX_EMOTE_CHARACTERS and not self:IsLongEmoteTextEnabled() then
        self:Print("Das letzte Emote ist länger als " .. MAX_EMOTE_CHARACTERS .. " Zeichen. Bitte frage die Plotleitung erneut nach einer Freigabe.")
        return false
    end

    local selectedChannel = self:GetEmoteChannel()
    if not self:IsSlashEmoteAllowed(message, selectedChannel) then
        self:Print("/me kann nur mit dem Kanal Say verwendet werden. Entferne den Befehl oder wähle Say.")
        return false
    end
    if not self:IsEmoteChannelAvailable(selectedChannel) then
        if selectedChannel == "RAID" then
            self:Print("Für den Versand an Raid musst du dich in einem Schlachtzug befinden.")
        else
            self:Print("Für den Versand an Gruppe musst du dich in einer Gruppe befinden.")
        end
        return false
    end

    if type(SendChatMessage) ~= "function" then
        self:Print("Das letzte Emote konnte nicht gesendet werden.")
        return false
    end

    -- Auch beim Wiederholen genau ein bewusster SendChatMessage-Aufruf. Das
    -- installierte Unlimited Chat Message übernimmt bei Bedarf die Aufteilung.
    if slashEmotePayload ~= nil then
        SendChatMessage(slashEmotePayload, "EMOTE")
    else
        SendChatMessage(message, self:GetResolvedEmoteChannel(selectedChannel))
    end
    self:AdvanceEmoteTurnForSender(Ploty.GetUnitFullName("player"), true)

    self.db.emoteText.lastSentAt = date("%H:%M:%S")
    self.db.emoteText.lastSentBlocks = #(splitChatMessage(message, MAX_CHAT_MESSAGE_BYTES) or {})
    self.db.emoteText.lastSentChannel = selectedChannel

    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    return true
end

function Ploty:HandleSystemMessage(message)
    if not self.rollPattern or not message then
        return
    end

    local roller, result, minimum, maximum = message:match(self.rollPattern)
    if not roller then
        return
    end

    result = tonumber(result)
    minimum = tonumber(minimum)
    maximum = tonumber(maximum)
    -- Den Realmzusatz behalten. Zwei gleichnamige Gruppenmitglieder auf
    -- unterschiedlichen Realms dürfen nicht denselben Würfeleintrag teilen.
    roller = self:ResolveGroupPlayerName(roller)

    if not result or not minimum or not maximum or not self:IsCurrentRollParticipant(roller) then
        return
    end
    -- Seit 0.22 werden nur noch Würfe der gezielt aufgeforderten Personen
    -- erfasst. Normale /roll-Nachrichten anderer Gruppenmitglieder bleiben aus
    -- der Ploty-Übersicht heraus.
    if self.IsRollRequestTarget and not self:IsRollRequestTarget(roller) then
        return
    end

    local round = self.db and self.db.rollRound
    if not round or not round.active then
        return
    end
    if minimum ~= math.floor(tonumber(round.minimum) or 0) or
        maximum ~= math.floor(tonumber(round.maximum) or 0)
    then
        return
    end

    local rollerKey = playerKey(roller)
    local existingRoll = self.db.participantRolls[rollerKey]
    if existingRoll and tostring(existingRoll.roundId or "") == tostring(round.id or "") then
        return
    end

    local rollData = {
        name = roller,
        result = result,
        minimum = minimum,
        maximum = maximum,
        time = date("%H:%M:%S"),
        receivedAt = GetTime and GetTime() or 0,
        roundId = round.id,
    }

    self.db.participantRolls[rollerKey] = rollData

    local playerName = Ploty.GetUnitFullName("player")
    if samePlayerName(roller, playerName) then
        self.db.lastRoll = {
            result = result,
            minimum = minimum,
            maximum = maximum,
            time = rollData.time,
        }

        if self.RefreshLastRoll then
            self:RefreshLastRoll()
        end
    end

    if self.RefreshParticipantRolls then
        self:RefreshParticipantRolls()
    end
end

function Ploty:HasLeaderPrivileges()
    if not IsInGroup() then
        return false
    end

    if IsInRaid() then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end

    return UnitIsGroupLeader("player")
end

function Ploty:UpdateAccessMode(refreshUI)
    local participantMode = not self:HasLeaderPrivileges()
    local changed = self.isParticipantBuild ~= participantMode
    self.isParticipantBuild = participantMode
    self.displayName = "Ploty"

    if self.mainFrame and (changed or refreshUI) and self.ApplyAccessModeToUI then
        self:ApplyAccessModeToUI()
    end

    return changed
end

function Ploty:HasWorldMarkerPermission()
    return self:HasLeaderPrivileges()
end

function Ploty:CanSyncEmoteOrder()
    return self:HasLeaderPrivileges()
end

function Ploty:GetGroupCommunicationChannel()
    if not IsInGroup() then
        return nil
    end

    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    end

    return "PARTY"
end

function Ploty:IsSenderInGroup(sender)
    if not sender or not IsInGroup() then
        return false
    end
    return self:FindGroupUnit(sender) ~= nil
end

function Ploty:IsAuthorizedOrderSender(sender)
    if not self:IsSenderInGroup(sender) then
        return false
    end

    local unit = self:FindGroupUnit(sender)
    if not unit then
        return false
    end
    if IsInRaid() then
        return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
    end
    return UnitIsGroupLeader(unit)
end

function Ploty:NormalizeEmoteTurnIndex()
    local order = self.db and self.db.emoteOrder or {}
    local count = #order
    local index = math.floor(tonumber(self.db and self.db.currentEmoteIndex) or 1)

    if count == 0 then
        index = 1
    elseif index < 1 or index > count then
        index = 1
    end

    if self.db then
        self.db.currentEmoteIndex = index
    end
    return index
end

function Ploty:GetCurrentEmoteParticipant()
    local order = self.db and self.db.emoteOrder or {}
    if #order == 0 then
        return nil, 1
    end

    local index = self:NormalizeEmoteTurnIndex()
    return order[index], index
end

function Ploty:FindEmoteParticipantIndex(name)
    if not name then
        return nil
    end

    for index, participantName in ipairs(self.db.emoteOrder or {}) do
        if samePlayerName(participantName, name) then
            return index
        end
    end
    return nil
end

function Ploty:RestoreCurrentEmoteParticipant(previousName)
    local order = self.db.emoteOrder or {}
    if #order == 0 then
        self.db.currentEmoteIndex = 1
    else
        local restoredIndex = previousName and self:FindEmoteParticipantIndex(previousName) or nil
        self.db.currentEmoteIndex = restoredIndex or math.min(self:NormalizeEmoteTurnIndex(), #order)
    end
end

function Ploty:GetEmoteTurnDisplayText()
    local order = self.db and self.db.emoteOrder or {}
    if #order == 0 then
        return "|cff888888Keine Emote-Reihenfolge festgelegt.|r"
    end

    local currentIndex = self:NormalizeEmoteTurnIndex()
    local parts = {}

    for index, participantName in ipairs(order) do
        local displayName = shortName(participantName)

        if index == currentIndex then
            parts[#parts + 1] = "|cff55ff55[" .. displayName .. "]|r"
        else
            local group = self.GetParticipantEmoteGroup and self:GetParticipantEmoteGroup(participantName) or nil
            local color = group and self.GetEmoteGroupColor and self:GetEmoteGroupColor(group.colorKey) or nil
            parts[#parts + 1] = "|cff" .. (color and color.hex or "ffffff") .. displayName .. "|r"
        end
    end

    return table.concat(parts, " |cff777777-|r ")
end

function Ploty:RefreshEmoteTurnState()
    if self.RefreshEmoteTurnBar then
        self:RefreshEmoteTurnBar()
    end
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.RefreshPlotOverview then
        self:RefreshPlotOverview()
    end
end

function Ploty:SetCurrentEmoteIndex(index)
    local order = self.db.emoteOrder or {}
    local count = #order
    index = math.floor(tonumber(index) or 1)

    if count == 0 then
        index = 1
    elseif index < 1 or index > count then
        return false
    end

    self.db.currentEmoteIndex = index
    self:RefreshEmoteTurnState()
    return true
end

function Ploty:AdvanceEmoteTurnForSender(sender, broadcast)
    local order = self.db.emoteOrder or {}
    local count = #order
    if count == 0 or not sender then
        return false
    end

    local currentName, currentIndex = self:GetCurrentEmoteParticipant()
    if not currentName or not samePlayerName(currentName, sender) then
        return false
    end

    local nextIndex = currentIndex + 1
    if nextIndex > count then
        nextIndex = 1
    end

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

function Ploty:HandleEmoteTurnMessage(sender, indexText)
    if self.IsPlotActive and not self:IsPlotActive() then
        return
    end
    local order = self.db.emoteOrder or {}
    local count = #order
    local requestedIndex = math.floor(tonumber(indexText) or 0)
    if count == 0 or requestedIndex < 1 or requestedIndex > count then
        return
    end

    local currentName, currentIndex = self:GetCurrentEmoteParticipant()
    if not currentName or not samePlayerName(currentName, sender) then
        return
    end

    local expectedIndex = currentIndex + 1
    if expectedIndex > count then
        expectedIndex = 1
    end
    if requestedIndex ~= expectedIndex then
        return
    end

    self.db.currentEmoteIndex = requestedIndex
    self:RefreshEmoteTurnState()
    if self.NotifyIfPlayerTurn then
        self:NotifyIfPlayerTurn("turn")
    end
end

function Ploty:MarkEmoteOrderLocallyEdited()
    self.db.orderSender = nil
    self.db.orderUpdatedAt = nil
    if self.SetEmoteOrderUnread then
        self:SetEmoteOrderUnread(false)
    end
end

function Ploty:AddEmoteParticipant(name)
    name = Ploty.SanitizeField(name, 80)
    if name == "" then
        self:Print("Bitte gib einen Spielernamen ein.")
        return false
    end

    for _, existingName in ipairs(self.db.emoteOrder) do
        if samePlayerName(existingName, name) then
            self:Print(name .. " steht bereits in der Emote-Reihenfolge.")
            return false
        end
    end

    table.insert(self.db.emoteOrder, name)
    self:MarkEmoteOrderLocallyEdited()
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
    return true
end

function Ploty:RemoveEmoteParticipant(index)
    if index < 1 or index > #self.db.emoteOrder then
        return
    end

    local previousCurrentName = self:GetCurrentEmoteParticipant()
    table.remove(self.db.emoteOrder, index)
    self:RestoreCurrentEmoteParticipant(previousCurrentName)
    self:MarkEmoteOrderLocallyEdited()
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
end

function Ploty:MoveEmoteParticipant(index, direction)
    local previousCurrentName = self:GetCurrentEmoteParticipant()
    local targetIndex = index + direction
    if index < 1 or index > #self.db.emoteOrder then
        return
    end
    if targetIndex < 1 or targetIndex > #self.db.emoteOrder then
        return
    end

    self.db.emoteOrder[index], self.db.emoteOrder[targetIndex] =
        self.db.emoteOrder[targetIndex], self.db.emoteOrder[index]
    self:RestoreCurrentEmoteParticipant(previousCurrentName)

    self:MarkEmoteOrderLocallyEdited()
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
end

function Ploty:ClearEmoteOrder()
    wipe(self.db.emoteOrder)
    self.db.currentEmoteIndex = 1
    self.db.orderSender = nil
    self.db.orderUpdatedAt = nil

    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
end

function Ploty:ImportGroupToEmoteOrder()
    if not IsInGroup() then
        self:Print("Du befindest dich in keiner Gruppe.")
        return
    end

    wipe(self.db.emoteOrder)
    self.db.currentEmoteIndex = 1

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local name = Ploty.GetUnitFullName("raid" .. index)
            if name then
                table.insert(self.db.emoteOrder, name)
            end
        end
    else
        local playerName = Ploty.GetUnitFullName("player")
        if playerName then
            table.insert(self.db.emoteOrder, playerName)
        end

        for index = 1, GetNumSubgroupMembers() do
            local name = Ploty.GetUnitFullName("party" .. index)
            if name then
                table.insert(self.db.emoteOrder, name)
            end
        end
    end

    self.db.orderSender = nil
    self.db.orderUpdatedAt = nil

    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end

    self:Print(#self.db.emoteOrder .. " Gruppenmitglieder übernommen.")
end

function Ploty:BuildOrderChunks(order)
    local chunks = {}
    local current = ""

    for _, rawName in ipairs(order or {}) do
        local name = Ploty.SanitizeField(rawName, 80):gsub(ENTRY_SEPARATOR, "")
        if name ~= "" then
            local candidate
            if current == "" then
                candidate = name
            else
                candidate = current .. ENTRY_SEPARATOR .. name
            end

            if #candidate > MAX_CHUNK_PAYLOAD and current ~= "" then
                table.insert(chunks, current)
                current = name
            else
                current = candidate
            end
        end
    end

    if current ~= "" then
        table.insert(chunks, current)
    end

    return chunks
end

function Ploty:ApplySyncedEmoteOrder(order, sender, currentIndex)
    wipe(self.db.emoteOrder)

    for index, name in ipairs(order or {}) do
        if index > MAX_ORDER_ENTRIES then
            break
        end
        table.insert(self.db.emoteOrder, name)
    end

    local orderCount = #self.db.emoteOrder
    currentIndex = math.floor(tonumber(currentIndex) or self.db.currentEmoteIndex or 1)
    if orderCount == 0 or currentIndex < 1 or currentIndex > orderCount then
        currentIndex = 1
    end
    self.db.currentEmoteIndex = currentIndex

    self.db.orderSender = sender or Ploty.GetUnitFullName("player")
    self.db.orderUpdatedAt = date("%d.%m.%Y %H:%M:%S")

    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
    if self.RefreshEmoteTurnBar then
        self:RefreshEmoteTurnBar()
    end
    if self.RefreshPlotOverview then
        self:RefreshPlotOverview()
    end
end

function Ploty:SendEmoteOrder(silent, target)
    if self.IsPlotActive and not self:IsPlotActive() then
        if not silent then
            self:Print("Die Reihenfolge wird erst nach dem Start des Plots übertragen.")
        end
        return false
    end
    if not self:CanSyncEmoteOrder() then
        if not silent then
            self:Print("Nur Gruppenleitung beziehungsweise Schlachtzugsleitung oder Assistenz darf die Reihenfolge synchronisieren.")
        end
        return false
    end

    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        if not silent then
            self:Print("Du befindest dich in keiner Gruppe.")
        end
        return false
    end

    local chunks = self:BuildOrderChunks(self.db.emoteOrder)
    if #chunks == 0 then
        -- Auch eine geleerte Reihenfolge ist ein verbindlicher Zustand und muss
        -- bei allen Clients eine möglicherweise noch gespeicherte Liste ersetzen.
        chunks[1] = ""
    end

    local transferId = tostring(time()) .. tostring(math.random(1000, 9999))
    for index, payload in ipairs(chunks) do
        local message = table.concat({
            "ORDER",
            transferId,
            tostring(index),
            tostring(#chunks),
            tostring(self:NormalizeEmoteTurnIndex()),
            payload,
        }, "|")
        sendAddonMessage(message, channel, target)
    end

    self:ApplySyncedEmoteOrder(copyArray(self.db.emoteOrder), Ploty.GetUnitFullName("player"), self:NormalizeEmoteTurnIndex())
    self:SetEmoteOrderUnread(false)

    if not silent then
        self:Print("Emote-Reihenfolge und Gruppen an alle Ploty-Clients gesendet.")
    end
    return true
end

function Ploty:RequestEmoteOrder(silent)
    if self.IsPlotActive and not self:IsPlotActive() then
        if not silent then
            self:Print("Es ist derzeit kein Plot aktiv.")
        end
        return false
    end
    local channel = self:GetGroupCommunicationChannel()
    if not channel then
        self:Print("Du befindest dich in keiner Gruppe.")
        return false
    end

    sendAddonMessage("REQUEST", channel)
    if not silent then
        self:Print("Aktuelle Emote-Reihenfolge angefordert.")
    end
    return true
end

function Ploty:ShouldAnswerOrderRequest()
    if self.IsPlotActive and not self:IsPlotActive() then
        return false
    end
    if not self:CanSyncEmoteOrder() then
        return false
    end

    if not self.db.orderSender then
        return UnitIsGroupLeader("player")
    end

    return samePlayerName(self.db.orderSender, Ploty.GetUnitFullName("player"))
end

function Ploty:HandleOrderChunk(sender, transferId, sequenceText, totalText, turnIndexText, payload)
    if self.IsPlotActive and not self:IsPlotActive() then
        return
    end
    if not self:IsAuthorizedOrderSender(sender) then
        return
    end

    transferId = tostring(transferId or "")
    payload = tostring(payload or "")
    if transferId == "" or #transferId > 40 or #payload > MAX_CHUNK_PAYLOAD then
        return
    end

    local sequence = tonumber(sequenceText)
    local total = tonumber(totalText)
    local turnIndex = math.floor(tonumber(turnIndexText) or 1)
    if not sequence or not total or sequence < 1 or total < 1 or sequence > total or total > 20 then
        return
    end

    local key = sender .. "\030" .. transferId
    local transfer = self.incomingOrders[key]
    if not transfer then
        transfer = {
            sender = sender,
            total = total,
            turnIndex = turnIndex,
            parts = {},
            received = 0,
            startedAt = GetTime(),
        }
        self.incomingOrders[key] = transfer
    end

    if transfer.total ~= total or transfer.turnIndex ~= turnIndex then
        self.incomingOrders[key] = nil
        return
    end

    if not transfer.parts[sequence] then
            transfer.parts[sequence] = payload
        transfer.received = transfer.received + 1
    end

    if transfer.received < total then
        return
    end

    local combinedParts = {}
    for index = 1, total do
        if transfer.parts[index] == nil then
            return
        end
        combinedParts[index] = transfer.parts[index]
    end

    self.incomingOrders[key] = nil

    local combined = table.concat(combinedParts, ENTRY_SEPARATOR)
    local order = {}
    for name in combined:gmatch("([^" .. ENTRY_SEPARATOR .. "]+)") do
        name = Ploty.SanitizeField(name, 80):gsub(ENTRY_SEPARATOR, "")
        if name ~= "" then
            table.insert(order, name)
            if #order >= MAX_ORDER_ENTRIES then
                break
            end
        end
    end

    -- Mehrere identische Antworten konnten bislang bei HELLO/REQUEST direkt
    -- hintereinander eintreffen. Identische Reihenfolge und Zugposition werden
    -- deshalb nur einmal verarbeitet und gemeldet.
    local signature = tostring(sender):lower() .. "|" .. tostring(transfer.turnIndex) .. "|" .. table.concat(order, ENTRY_SEPARATOR)
    if self.lastReceivedOrderSignature == signature then
        return
    end
    self.lastReceivedOrderSignature = signature

    local playerName = Ploty.GetUnitFullName("player")
    local wasPlayerTurn = self:IsPlayerCurrentEmoter(playerName)
    self:ApplySyncedEmoteOrder(order, sender, transfer.turnIndex)

    if not self.emotePage or not self.emotePage:IsShown() then
        self:SetEmoteOrderUnread(true)
    else
        self:SetEmoteOrderUnread(false)
    end

    -- Automatische Kleinständerungen sollen weder den Chat noch den Tonkanal
    -- fluten. Ein Hinweis erfolgt nur, wenn der Spieler dadurch neu am Zug ist.
    if not wasPlayerTurn and self.NotifyIfPlayerTurn then
        self:NotifyIfPlayerTurn("order")
    end
end

function Ploty:CleanupIncomingOrders()
    if not self.incomingOrders then
        return
    end

    local now = GetTime()
    for key, transfer in pairs(self.incomingOrders) do
        if now - (transfer.startedAt or now) > 30 then
            self.incomingOrders[key] = nil
        end
    end
end

function Ploty:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX or type(message) ~= "string" or not sender then
        return
    end

    if samePlayerName(sender, Ploty.GetUnitFullName("player")) then
        return
    end

    if not self:IsSenderInGroup(sender) then
        return
    end

    if message == "REQUEST" then
        if self:ShouldAnswerOrderRequest() then
            C_Timer.After(0.3, function()
                Ploty:SendEmoteOrder(true)
            end)
        end
        return
    end

    local turnIndex = message:match("^TURN|(%d+)$")
    if turnIndex then
        self:HandleEmoteTurnMessage(sender, turnIndex)
        return
    end

    local command, transferId, sequence, total, orderTurnIndex, payload =
        message:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
    if command == "ORDER" then
        self:HandleOrderChunk(sender, transferId, sequence, total, orderTurnIndex, payload)
        return
    end

    -- Kompatibilität zu älteren Ploty-Versionen ohne synchronisierten Zugindex.
    command, transferId, sequence, total, payload = message:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
    if command == "ORDER" then
        self:HandleOrderChunk(sender, transferId, sequence, total, "1", payload)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            Ploty:InitializeDatabase()
            Ploty:InitializeCommunication()
        end
    elseif event == "PLAYER_LOGIN" then
        Ploty:UpdateAccessMode(false)
        Ploty:InitializeUI()
        Ploty:InitializeMinimapButton()
        Ploty:Print("geladen. Aktueller Modus: " .. (Ploty.isParticipantBuild and "Teilnehmer" or "Plotleitung") .. ". Öffnen mit /ploty oder dem Minimap-Button.")
    elseif event == "CHAT_MSG_SYSTEM" then
        Ploty:HandleSystemMessage(...)
    elseif event == "CHAT_MSG_ADDON" then
        Ploty:HandleAddonMessage(...)
        Ploty:CleanupIncomingOrders()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Ploty:UpdateAccessMode(true)
        if Ploty.UpdateGroupStatus then
            Ploty:UpdateGroupStatus()
        end
        if Ploty.UpdateEmoteSyncStatus then
            Ploty:UpdateEmoteSyncStatus()
        end
        if Ploty.UpdateEmoteTextState then
            Ploty:UpdateEmoteTextState()
        end
        if Ploty.RefreshParticipantRolls then
            Ploty:RefreshParticipantRolls()
        end
    end
end)

SLASH_PLOTY1 = "/ploty"
SLASH_PLOTY2 = "/plotty"
SLASH_PLOTY3 = "/plot"
SLASH_PLOTY4 = "/rpp"
SLASH_PLOTY5 = "/rpplot"

SlashCmdList.PLOTY = function(input)
    input = trim(input):lower()

    if input == "roll" or input == "w20" then
        Ploty:DoD20Roll()
    elseif input == "resetpos" then
        Ploty:ResetPositions()
        Ploty:Print("Fensterposition wurde zurückgesetzt.")
    elseif input == "emotes" or input == "order" then
        Ploty:ShowTab(3)
        if not Ploty.mainFrame:IsShown() then
            Ploty.mainFrame:Show()
        end
    elseif input == "text" or input == "emote" or input == "write" then
        Ploty:ShowTab(4)
        if not Ploty.mainFrame:IsShown() then
            Ploty.mainFrame:Show()
        end
    elseif input == "dice" or input == "rolls" or input == "wuerfel" then
        Ploty:ShowTab(5)
        if not Ploty.mainFrame:IsShown() then
            Ploty.mainFrame:Show()
        end
    elseif input == "sync" or input == "send" then
        Ploty:SendEmoteOrder(false)
    elseif input == "request" then
        Ploty:RequestEmoteOrder()
    elseif input == "help" then
        Ploty:Print("/ploty – Fenster öffnen oder schließen")
        Ploty:Print("/ploty roll – mit dem gespeicherten Bereich würfeln")
        Ploty:Print("/ploty emotes – Emote-Reihenfolge öffnen")
        Ploty:Print("/ploty text – RP-Textwerkzeug öffnen")
        Ploty:Print("/ploty rolls – Würfelübersicht öffnen")
        Ploty:Print("/ploty sync – Reihenfolge an Ploty-Clients senden")
        Ploty:Print("/ploty request – aktuelle Reihenfolge anfordern")
        Ploty:Print("/ploty resetpos – Fensterposition zurücksetzen")
    else
        Ploty:ToggleUI()
    end
end
