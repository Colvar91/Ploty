local addonName, Ploty = ...

Ploty.COMM_PREFIX = "PLOTTY04"
Ploty.DB_VERSION = 32
Ploty.MAX_ADDON_MESSAGE_BYTES = 255

local metadataVersion = type(GetAddOnMetadata) == "function" and GetAddOnMetadata(addonName, "Version") or nil
Ploty.version = metadataVersion or "0.26.9"
Ploty.displayName = "Ploty"

function Ploty.Trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$") or ""
end

function Ploty.ShortName(name)
    if not name then
        return ""
    end
    return tostring(name):match("^[^-]+") or tostring(name)
end

function Ploty.TruncateUtf8Bytes(value, maximumBytes)
    value = tostring(value or "")
    maximumBytes = math.max(0, math.floor(tonumber(maximumBytes) or 0))
    if #value <= maximumBytes then
        return value
    end

    local index = 1
    local lastCompleteByte = 0
    while index <= #value and index <= maximumBytes do
        local firstByte = value:byte(index)
        local characterBytes = 1
        if firstByte >= 240 and firstByte <= 247 then
            characterBytes = 4
        elseif firstByte >= 224 and firstByte <= 239 then
            characterBytes = 3
        elseif firstByte >= 192 and firstByte <= 223 then
            characterBytes = 2
        end

        if index + characterBytes - 1 > maximumBytes then
            break
        end
        lastCompleteByte = index + characterBytes - 1
        index = index + characterBytes
    end
    return value:sub(1, lastCompleteByte)
end

function Ploty.SanitizeField(value, maximumBytes)
    value = tostring(value or ""):gsub("|", "/"):gsub("[\r\n]+", " ")
    value = Ploty.Trim(value)
    if maximumBytes and #value > maximumBytes then
        value = Ploty.TruncateUtf8Bytes(value, maximumBytes)
    end
    return value
end

function Ploty.CopyArray(source)
    local result = {}
    for index, value in ipairs(source or {}) do
        result[index] = value
    end
    return result
end

function Ploty.EnsureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

function Ploty.CycleDefinition(definitions, currentKey, direction)
    if type(definitions) ~= "table" or #definitions == 0 then
        return nil
    end

    local currentIndex = 1
    for index, definition in ipairs(definitions) do
        if definition.key == currentKey then
            currentIndex = index
            break
        end
    end
    direction = direction or 1
    return definitions[((currentIndex - 1 + direction) % #definitions) + 1]
end

function Ploty.SendAddonMessage(message, channel, target)
    if type(message) ~= "string" or not channel or #message > Ploty.MAX_ADDON_MESSAGE_BYTES then
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Ploty.COMM_PREFIX, message, channel, target)
        return true
    elseif SendAddonMessage then
        SendAddonMessage(Ploty.COMM_PREFIX, message, channel, target)
        return true
    end
    return false
end

function Ploty.GetUnitFullName(unit)
    if type(GetUnitName) == "function" then
        local name = GetUnitName(unit, true)
        if name and name ~= "" then
            return name
        end
    end

    if type(UnitFullName) == "function" then
        local name, realm = UnitFullName(unit)
        if name and realm and realm ~= "" then
            return name .. "-" .. realm
        elseif name then
            return name
        end
    end
    return type(UnitName) == "function" and UnitName(unit) or nil
end

function Ploty:GetGroupUnits()
    local units = {}
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or math.max(0, GetNumGroupMembers() - 1)
        for index = 1, count do
            units[#units + 1] = "party" .. index
        end
    else
        units[#units + 1] = "player"
    end
    return units
end

function Ploty:ResolveGroupPlayerName(name)
    name = Ploty.Trim(name)
    if name == "" then
        return ""
    end

    local wanted = name:lower()
    local wantedShort = Ploty.ShortName(name):lower()
    local shortMatch
    local shortMatches = 0

    for _, unit in ipairs(self:GetGroupUnits()) do
        if not UnitExists or UnitExists(unit) then
            local fullName = Ploty.GetUnitFullName(unit)
            if fullName and fullName ~= "" then
                if fullName:lower() == wanted then
                    return fullName
                end
                if Ploty.ShortName(fullName):lower() == wantedShort then
                    shortMatch = fullName
                    shortMatches = shortMatches + 1
                end
            end
        end
    end

    if shortMatches == 1 then
        return shortMatch
    end
    return name
end

function Ploty:PlayerKey(name)
    return self:ResolveGroupPlayerName(name):lower()
end

function Ploty:SamePlayerName(first, second)
    local firstKey = self:PlayerKey(first)
    return firstKey ~= "" and firstKey == self:PlayerKey(second)
end

function Ploty:FindGroupUnit(name)
    local wanted = self:PlayerKey(name)
    if wanted == "" then
        return nil
    end

    for _, unit in ipairs(self:GetGroupUnits()) do
        if (not UnitExists or UnitExists(unit)) and self:PlayerKey(Ploty.GetUnitFullName(unit)) == wanted then
            return unit
        end
    end
    return nil
end

function Ploty:MigratePlayerKeyedTable(data)
    if type(data) ~= "table" then
        return
    end

    local migrations = {}
    for oldKey, value in pairs(data) do
        if type(oldKey) == "string" then
            local newKey = self:PlayerKey(oldKey)
            if newKey ~= "" and newKey ~= oldKey then
                migrations[#migrations + 1] = { oldKey = oldKey, newKey = newKey, value = value }
            end
        end
    end

    for _, migration in ipairs(migrations) do
        if data[migration.newKey] == nil then
            data[migration.newKey] = migration.value
        end
        data[migration.oldKey] = nil
    end
end
