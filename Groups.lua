local addonName, Ploty = ...

local COMM_PREFIX = Ploty.COMM_PREFIX
local MAX_GROUPS = 8
local MAX_GROUP_NAME_BYTES = 32
local MAX_GROUP_ID_BYTES = 30

local GROUP_COLORS = {
    { key = "RED", label = "Rot", r = 0.92, g = 0.24, b = 0.24, hex = "ff3d3d" },
    { key = "BLUE", label = "Blau", r = 0.28, g = 0.56, b = 1.00, hex = "478fff" },
    { key = "GREEN", label = "Grün", r = 0.28, g = 0.86, b = 0.40, hex = "47db66" },
    { key = "YELLOW", label = "Gelb", r = 1.00, g = 0.82, b = 0.22, hex = "ffd138" },
    { key = "ORANGE", label = "Orange", r = 1.00, g = 0.52, b = 0.20, hex = "ff8533" },
    { key = "PURPLE", label = "Lila", r = 0.72, g = 0.42, b = 0.96, hex = "b76bf5" },
    { key = "CYAN", label = "Türkis", r = 0.20, g = 0.84, b = 0.86, hex = "33d6db" },
    { key = "WHITE", label = "Weiß", r = 0.92, g = 0.92, b = 0.96, hex = "ebebf5" },
}

local COLOR_BY_KEY = {}
for index, definition in ipairs(GROUP_COLORS) do
    definition.index = index
    COLOR_BY_KEY[definition.key] = definition
end

Ploty.EMOTE_GROUP_COLORS = GROUP_COLORS
Ploty.MAX_EMOTE_GROUPS = MAX_GROUPS

local sanitizeField = Ploty.SanitizeField
local sendAddonMessage = Ploty.SendAddonMessage
local function playerKey(name)
    return Ploty:PlayerKey(name)
end
local function samePlayerName(first, second)
    return Ploty:SamePlayerName(first, second)
end

local function syncOrderAfterEdit(self)
    if self.IsPlotActive and not self:IsPlotActive() then
        return false
    end
    if self.SendEmoteOrder then
        return self:SendEmoteOrder(true, "order")
    end
    return false
end

local originalInitializeDatabase = Ploty.InitializeDatabase
function Ploty:InitializeDatabase()
    originalInitializeDatabase(self)

    if type(self.db.emoteGroups) ~= "table" then
        self.db.emoteGroups = {}
    end
    if type(self.db.participantGroups) ~= "table" then
        self.db.participantGroups = {}
    end

    local normalized = {}
    local seenIds = {}
    local highestId = 0
    for _, rawGroup in ipairs(self.db.emoteGroups) do
        if #normalized >= MAX_GROUPS then
            break
        end
        if type(rawGroup) == "table" then
            local id = sanitizeField(rawGroup.id, MAX_GROUP_ID_BYTES)
            local name = sanitizeField(rawGroup.name, MAX_GROUP_NAME_BYTES)
            local colorKey = tostring(rawGroup.colorKey or "RED"):upper()
            if id ~= "" and name ~= "" and not seenIds[id] and COLOR_BY_KEY[colorKey] then
                normalized[#normalized + 1] = { id = id, name = name, colorKey = colorKey }
                seenIds[id] = true
                highestId = math.max(highestId, tonumber(id:match("^g(%d+)$")) or 0)
            end
        end
    end
    self.db.emoteGroups = normalized
    self.db.nextEmoteGroupId = math.max(math.floor(tonumber(self.db.nextEmoteGroupId) or 1), highestId + 1)

    for key, groupId in pairs(self.db.participantGroups) do
        groupId = sanitizeField(groupId, MAX_GROUP_ID_BYTES)
        if not seenIds[groupId] then
            self.db.participantGroups[key] = nil
        else
            self.db.participantGroups[key] = groupId
        end
    end

    self.incomingEmoteGroups = {}
    self:RegroupEmoteOrder(false, false)
end

function Ploty:GetEmoteGroupColor(colorKey)
    return COLOR_BY_KEY[tostring(colorKey or ""):upper()] or COLOR_BY_KEY.RED
end

function Ploty:GetEmoteGroupById(groupId)
    groupId = tostring(groupId or "")
    for _, group in ipairs(self.db.emoteGroups or {}) do
        if tostring(group.id) == groupId then
            return group
        end
    end
    return nil
end

function Ploty:GetParticipantEmoteGroup(name)
    local groupId = self.db.participantGroups[playerKey(name)]
    return groupId and self:GetEmoteGroupById(groupId) or nil
end

function Ploty:GetEmoteGroupMemberCount(groupId)
    local count = 0
    for _, name in ipairs(self.db.emoteOrder or {}) do
        if tostring(self.db.participantGroups[playerKey(name)] or "") == tostring(groupId or "") then
            count = count + 1
        end
    end
    return count
end

function Ploty:GetParticipantEmoteGroupId(name)
    local groupId = self.db.participantGroups[playerKey(name)]
    return groupId and self:GetEmoteGroupById(groupId) and groupId or nil
end

-- Baut die tatsächliche Zugfolge aus zwei Ebenen auf: zuerst die Gruppen in
-- der Reihenfolge der Gruppenverwaltung, darin die bisherige Reihenfolge ihrer
-- Mitglieder. Personen ohne Gruppe bilden bewusst den letzten Block.
function Ploty:RegroupEmoteOrder(markEdited, refresh)
    local order = self.db.emoteOrder or {}
    if #order < 2 then
        return false
    end

    local previousCurrentName = self:GetCurrentEmoteParticipant()
    local buckets = {}
    for _, group in ipairs(self.db.emoteGroups or {}) do
        buckets[group.id] = {}
    end
    local ungrouped = {}

    for _, name in ipairs(order) do
        local groupId = self:GetParticipantEmoteGroupId(name)
        local bucket = groupId and buckets[groupId] or ungrouped
        bucket[#bucket + 1] = name
    end

    local regrouped = {}
    for _, group in ipairs(self.db.emoteGroups or {}) do
        for _, name in ipairs(buckets[group.id] or {}) do
            regrouped[#regrouped + 1] = name
        end
    end
    for _, name in ipairs(ungrouped) do
        regrouped[#regrouped + 1] = name
    end

    local changed = #regrouped ~= #order
    if not changed then
        for index, name in ipairs(regrouped) do
            if not samePlayerName(name, order[index]) then
                changed = true
                break
            end
        end
    end
    if not changed then
        return false
    end

    self.db.emoteOrder = regrouped
    self:RestoreCurrentEmoteParticipant(previousCurrentName)
    if markEdited then
        self:MarkEmoteOrderLocallyEdited()
    end
    if refresh then
        self:RefreshEmoteGroupUI()
        self:RefreshEmoteTurnState()
    end
    return true
end

function Ploty:GetEmoteGroupPosition(groupId)
    for index, group in ipairs(self.db.emoteGroups or {}) do
        if tostring(group.id) == tostring(groupId or "") then
            return index
        end
    end
    return nil
end

function Ploty:MoveEmoteGroup(groupId, direction)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann die Gruppenreihenfolge ändern.")
        return false
    end

    local index = self:GetEmoteGroupPosition(groupId)
    direction = direction and direction < 0 and -1 or 1
    local targetIndex = index and index + direction or nil
    if not index or targetIndex < 1 or targetIndex > #(self.db.emoteGroups or {}) then
        return false
    end

    local groups = self.db.emoteGroups
    groups[index], groups[targetIndex] = groups[targetIndex], groups[index]
    self:RegroupEmoteOrder(false, false)
    self:MarkEmoteOrderLocallyEdited()
    self:RefreshEmoteGroupUI()
    self:RefreshEmoteTurnState()
    syncOrderAfterEdit(self)
    return true
end

function Ploty:GetEmoteParticipantGroupPosition(index)
    local order = self.db.emoteOrder or {}
    local name = order[index]
    if not name then
        return nil, 0
    end

    local groupId = self:GetParticipantEmoteGroupId(name) or false
    local memberIndices = {}
    local memberPosition
    for candidateIndex, candidateName in ipairs(order) do
        local candidateGroupId = self:GetParticipantEmoteGroupId(candidateName) or false
        if candidateGroupId == groupId then
            memberIndices[#memberIndices + 1] = candidateIndex
            if candidateIndex == index then
                memberPosition = #memberIndices
            end
        end
    end
    return memberPosition, #memberIndices, memberIndices
end

function Ploty:CanMoveEmoteParticipantWithinGroup(index, direction)
    local position, count = self:GetEmoteParticipantGroupPosition(index)
    direction = direction and direction < 0 and -1 or 1
    return position ~= nil and position + direction >= 1 and position + direction <= count
end

function Ploty:RefreshEmoteGroupUI()
    if self.RefreshEmoteGroupManager then
        self:RefreshEmoteGroupManager()
    end
    if self.RefreshEmoteOrder then
        self:RefreshEmoteOrder()
    end
    if self.UpdateEmoteSyncStatus then
        self:UpdateEmoteSyncStatus()
    end
    if self.RefreshPlotOverview then
        self:RefreshPlotOverview()
    end
end

function Ploty:AddOrUpdateEmoteGroup(groupId, name, colorKey)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann Gruppen bearbeiten.")
        return false
    end

    name = sanitizeField(name, MAX_GROUP_NAME_BYTES)
    colorKey = tostring(colorKey or "RED"):upper()
    if name == "" then
        self:Print("Bitte gib der Gruppe einen Namen.")
        return false
    end
    if not COLOR_BY_KEY[colorKey] then
        colorKey = "RED"
    end

    for _, existing in ipairs(self.db.emoteGroups) do
        if tostring(existing.id) ~= tostring(groupId or "") and tostring(existing.name):lower() == name:lower() then
            self:Print("Eine Gruppe mit diesem Namen existiert bereits.")
            return false
        end
    end

    local group = groupId and self:GetEmoteGroupById(groupId) or nil
    if group then
        group.name = name
        group.colorKey = colorKey
    else
        if #self.db.emoteGroups >= MAX_GROUPS then
            self:Print("Es sind höchstens " .. MAX_GROUPS .. " Gruppen möglich.")
            return false
        end
        local nextId = math.max(1, math.floor(tonumber(self.db.nextEmoteGroupId) or 1))
        group = { id = "g" .. nextId, name = name, colorKey = colorKey }
        self.db.nextEmoteGroupId = nextId + 1
        self.db.emoteGroups[#self.db.emoteGroups + 1] = group
    end

    self:MarkEmoteOrderLocallyEdited()
    self:RefreshEmoteGroupUI()
    syncOrderAfterEdit(self)
    return true
end

function Ploty:DeleteEmoteGroup(groupId)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann Gruppen löschen.")
        return false
    end

    local removed = false
    for index = #self.db.emoteGroups, 1, -1 do
        if tostring(self.db.emoteGroups[index].id) == tostring(groupId or "") then
            table.remove(self.db.emoteGroups, index)
            removed = true
            break
        end
    end
    if not removed then
        return false
    end

    for key, assignedId in pairs(self.db.participantGroups) do
        if tostring(assignedId) == tostring(groupId) then
            self.db.participantGroups[key] = nil
        end
    end
    self:RegroupEmoteOrder(false, false)
    self:MarkEmoteOrderLocallyEdited()
    self:RefreshEmoteGroupUI()
    self:RefreshEmoteTurnState()
    syncOrderAfterEdit(self)
    return true
end

function Ploty:SetParticipantEmoteGroup(name, groupId)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann Teilnehmer Gruppen zuweisen.")
        return false
    end

    local participantExists = false
    for _, participantName in ipairs(self.db.emoteOrder or {}) do
        if samePlayerName(participantName, name) then
            name = participantName
            participantExists = true
            break
        end
    end
    if not participantExists then
        return false
    end

    if groupId ~= nil and not self:GetEmoteGroupById(groupId) then
        return false
    end
    self.db.participantGroups[playerKey(name)] = groupId or nil
    self:RegroupEmoteOrder(false, false)
    self:MarkEmoteOrderLocallyEdited()
    self:RefreshEmoteGroupUI()
    self:RefreshEmoteTurnState()
    syncOrderAfterEdit(self)
    return true
end

function Ploty:CycleParticipantEmoteGroup(name, direction)
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann Teilnehmer Gruppen zuweisen.")
        return false
    end

    local options = { false }
    for _, group in ipairs(self.db.emoteGroups or {}) do
        options[#options + 1] = group.id
    end
    if #options == 1 then
        self:Print("Lege zuerst über 'Gruppen' eine Gruppe an.")
        return false
    end

    local currentId = self.db.participantGroups[playerKey(name)] or false
    local currentIndex = 1
    for index, value in ipairs(options) do
        if value == currentId then
            currentIndex = index
            break
        end
    end
    direction = direction and direction < 0 and -1 or 1
    local nextId = options[((currentIndex - 1 + direction) % #options) + 1]
    return self:SetParticipantEmoteGroup(name, nextId or nil)
end

function Ploty:CleanupEmoteGroupAssignments()
    local valid = {}
    for _, name in ipairs(self.db.emoteOrder or {}) do
        valid[playerKey(name)] = true
    end
    for key in pairs(self.db.participantGroups or {}) do
        if not valid[key] then
            self.db.participantGroups[key] = nil
        end
    end
end

local originalAddEmoteParticipant = Ploty.AddEmoteParticipant
function Ploty:AddEmoteParticipant(name)
    local added = originalAddEmoteParticipant(self, name)
    if added then
        syncOrderAfterEdit(self)
    end
    return added
end

local originalMoveEmoteParticipant = Ploty.MoveEmoteParticipant
function Ploty:MoveEmoteParticipant(index, direction)
    if #(self.db.emoteGroups or {}) == 0 then
        local before = table.concat(self.db.emoteOrder or {}, "\030")
        local result = originalMoveEmoteParticipant(self, index, direction)
        if table.concat(self.db.emoteOrder or {}, "\030") ~= before then
            syncOrderAfterEdit(self)
            return true
        end
        return result
    end
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Gruppenleitung kann die offizielle Reihenfolge bearbeiten.")
        return false
    end

    direction = direction and direction < 0 and -1 or 1
    local position, count, memberIndices = self:GetEmoteParticipantGroupPosition(index)
    local targetPosition = position and position + direction or nil
    if not position or targetPosition < 1 or targetPosition > count then
        return false
    end

    local targetIndex = memberIndices[targetPosition]
    local previousCurrentName = self:GetCurrentEmoteParticipant()
    self.db.emoteOrder[index], self.db.emoteOrder[targetIndex] =
        self.db.emoteOrder[targetIndex], self.db.emoteOrder[index]
    self:RestoreCurrentEmoteParticipant(previousCurrentName)
    self:MarkEmoteOrderLocallyEdited()
    self:RefreshEmoteTurnState()
    syncOrderAfterEdit(self)
    return true
end

local originalRemoveEmoteParticipant = Ploty.RemoveEmoteParticipant
function Ploty:RemoveEmoteParticipant(index)
    local name = self.db.emoteOrder and self.db.emoteOrder[index]
    local canEdit = self:CanEditOfficialOrder()
    originalRemoveEmoteParticipant(self, index)
    if canEdit and name then
        self.db.participantGroups[playerKey(name)] = nil
        self:RefreshEmoteGroupUI()
        syncOrderAfterEdit(self)
        return true
    end
    return false
end

local originalClearEmoteOrder = Ploty.ClearEmoteOrder
function Ploty:ClearEmoteOrder()
    local canEdit = self:CanEditOfficialOrder()
    originalClearEmoteOrder(self)
    if canEdit then
        wipe(self.db.participantGroups)
        self:MarkEmoteOrderLocallyEdited()
        self:RefreshEmoteGroupUI()
        syncOrderAfterEdit(self)
        return true
    end
    return false
end

local originalImportGroupToEmoteOrder = Ploty.ImportGroupToEmoteOrder
function Ploty:ImportGroupToEmoteOrder()
    local canEdit = self:CanEditOfficialOrder()
    local inGroup = IsInGroup()
    originalImportGroupToEmoteOrder(self)
    if canEdit and inGroup then
        self:CleanupEmoteGroupAssignments()
        self:RegroupEmoteOrder(false, true)
        self:MarkEmoteOrderLocallyEdited()
        self:RefreshEmoteGroupUI()
        syncOrderAfterEdit(self)
        return true
    end
    return false
end

local originalApplySyncedEmoteOrder = Ploty.ApplySyncedEmoteOrder
function Ploty:ApplySyncedEmoteOrder(order, sender, currentIndex)
    originalApplySyncedEmoteOrder(self, order, sender, currentIndex)
    if sender and not samePlayerName(sender, Ploty.GetUnitFullName("player")) then
        wipe(self.db.participantGroups)
        if self.RefreshEmoteOrder then
            self:RefreshEmoteOrder()
        end
    end
end

local originalCleanupParticipantData = Ploty.CleanupParticipantData
function Ploty:CleanupParticipantData()
    local changed = originalCleanupParticipantData(self)
    self:CleanupEmoteGroupAssignments()
    return changed
end

function Ploty:BroadcastEmoteGroups(target)
    if self.IsPlotActive and not self:IsPlotActive() then
        return false
    end
    if not self:CanSyncEmoteOrder() then
        return false
    end
    local channel = target and "WHISPER" or self:GetGroupCommunicationChannel()
    if not channel then
        return false
    end

    local revision = tostring(time()) .. tostring(math.random(1000, 9999))
    sendAddonMessage("GROUPRESET|" .. revision, channel, target)
    for _, group in ipairs(self.db.emoteGroups or {}) do
        sendAddonMessage(table.concat({
            "GROUPDEF",
            revision,
            sanitizeField(group.id, MAX_GROUP_ID_BYTES),
            self:GetEmoteGroupColor(group.colorKey).key,
            sanitizeField(group.name, MAX_GROUP_NAME_BYTES),
        }, "|"), channel, target)
    end
    for _, name in ipairs(self.db.emoteOrder or {}) do
        local groupId = self.db.participantGroups[playerKey(name)]
        if groupId and self:GetEmoteGroupById(groupId) then
            sendAddonMessage(table.concat({
                "GROUPMEM",
                revision,
                sanitizeField(name, 80),
                sanitizeField(groupId, MAX_GROUP_ID_BYTES),
            }, "|"), channel, target)
        end
    end
    sendAddonMessage("GROUPDONE|" .. revision, channel, target)
    return true
end

local originalBroadcastEnhancedState = Ploty.BroadcastEnhancedState
function Ploty:BroadcastEnhancedState(target, skipPlotState)
    originalBroadcastEnhancedState(self, target, skipPlotState)
    self:BroadcastEmoteGroups(target)
end

function Ploty:HandleEmoteGroupMessage(message, sender)
    if self.IsPlotActive and not self:IsPlotActive() then
        return true
    end
    if samePlayerName(sender, Ploty.GetUnitFullName("player")) then
        return true
    end
    if not self:IsAuthorizedOrderSender(sender) then
        return true
    end

    local command = message:match("^([^|]+)")
    if command == "GROUPRESET" then
        local revision = message:match("^GROUPRESET|([^|]+)$")
        if revision and #revision <= 40 then
            self.incomingEmoteGroups[playerKey(sender)] = {
                revision = revision,
                definitions = {},
                definitionOrder = {},
                assignments = {},
                assignmentCount = 0,
            }
        end
        return true
    end

    local revision = message:match("^[^|]+|([^|]+)")
    local transfer = revision and self.incomingEmoteGroups[playerKey(sender)] or nil
    if not transfer or transfer.revision ~= revision then
        return true
    end

    if command == "GROUPDEF" then
        local _, groupId, colorKey, name = message:match("^GROUPDEF|([^|]+)|([^|]+)|([^|]+)|(.*)$")
        groupId = sanitizeField(groupId, MAX_GROUP_ID_BYTES)
        name = sanitizeField(name, MAX_GROUP_NAME_BYTES)
        colorKey = tostring(colorKey or ""):upper()
        if groupId ~= "" and name ~= "" and COLOR_BY_KEY[colorKey]
            and not transfer.definitions[groupId]
            and #transfer.definitionOrder < MAX_GROUPS
        then
            transfer.definitions[groupId] = { id = groupId, name = name, colorKey = colorKey }
            transfer.definitionOrder[#transfer.definitionOrder + 1] = groupId
        end
        return true
    elseif command == "GROUPMEM" then
        local _, name, groupId = message:match("^GROUPMEM|([^|]+)|([^|]+)|([^|]+)$")
        name = sanitizeField(name, 80)
        groupId = sanitizeField(groupId, MAX_GROUP_ID_BYTES)
        local key = playerKey(name)
        if name ~= "" and groupId ~= "" and (transfer.assignments[key] or transfer.assignmentCount < 80) then
            if not transfer.assignments[key] then
                transfer.assignmentCount = transfer.assignmentCount + 1
            end
            transfer.assignments[key] = groupId
        end
        return true
    elseif command == "GROUPDONE" then
        local groups = {}
        local validIds = {}
        local highestId = 0
        for _, groupId in ipairs(transfer.definitionOrder) do
            local group = transfer.definitions[groupId]
            groups[#groups + 1] = group
            validIds[groupId] = true
            highestId = math.max(highestId, tonumber(groupId:match("^g(%d+)$")) or 0)
        end
        local validParticipants = {}
        for _, name in ipairs(self.db.emoteOrder or {}) do
            validParticipants[playerKey(name)] = true
        end
        local assignments = {}
        for key, groupId in pairs(transfer.assignments) do
            if validIds[groupId] and validParticipants[key] then
                assignments[key] = groupId
            end
        end
        self.db.emoteGroups = groups
        self.db.participantGroups = assignments
        self.db.nextEmoteGroupId = math.max(highestId + 1, 1)
        self.incomingEmoteGroups[playerKey(sender)] = nil
        self:RegroupEmoteOrder(false, false)
        self:RefreshEmoteGroupUI()
        self:RefreshEmoteTurnState()
        return true
    end
    return false
end

local originalHandleAddonMessage = Ploty.HandleAddonMessage
function Ploty:HandleAddonMessage(prefix, message, channel, sender)
    if prefix == COMM_PREFIX and type(message) == "string" and sender then
        local command = message:match("^([^|]+)")
        if command == "GROUPRESET" or command == "GROUPDEF" or command == "GROUPMEM" or command == "GROUPDONE" then
            self:HandleEmoteGroupMessage(message, sender)
            return
        end
    end
    originalHandleAddonMessage(self, prefix, message, channel, sender)
end
