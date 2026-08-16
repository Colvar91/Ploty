local addonName, Ploty = ...

local MAX_ISSUES = 12

-- Bekannte Vertipper erhalten zusätzlich zum Wörterbuchtreffer einen konkreten
-- Korrekturvorschlag. Alle übrigen Wörter prüft GermanDictionary.lua.
local COMMON_CORRECTIONS = {
    halo = "Hallo",
    warscheinlich = "wahrscheinlich",
    warhscheinlich = "wahrscheinlich",
    ["nähmlich"] = "nämlich",
    garnicht = "gar nicht",
    bischen = "bisschen",
    standart = "Standard",
    rythmus = "Rhythmus",
    agressiv = "aggressiv",
    wiederspiegeln = "widerspiegeln",
    wiederrum = "wiederum",
    vorraus = "voraus",
    desweiteren = "des Weiteren",
    packet = "Paket",
    ["entgültig"] = "endgültig",
    ["hälst"] = "hältst",
    tollerant = "tolerant",
    addresse = "Adresse",
    gramatik = "Grammatik",
    einzigste = "einzige",
    einzigster = "einziger",
}

local function lowerGerman(value)
    return tostring(value or ""):lower()
        :gsub("Ä", "ä")
        :gsub("Ö", "ö")
        :gsub("Ü", "ü")
        :gsub("ẞ", "ß")
end

local function getContentStart(value)
    if not Ploty:IsSlashEmoteCommand(value) then
        return 1
    end

    local _, commandEnd = value:find("^%s*/%S+%s*")
    return commandEnd and commandEnd + 1 or 1
end

local function readCodepoint(value, position)
    local first = value:byte(position)
    if not first then
        return nil, 0
    elseif first < 0x80 then
        return first, 1
    elseif first < 0xE0 then
        local second = value:byte(position + 1)
        return second and ((first - 0xC0) * 0x40 + second - 0x80) or first, second and 2 or 1
    elseif first < 0xF0 then
        local second, third = value:byte(position + 1), value:byte(position + 2)
        return second and third and ((first - 0xE0) * 0x1000 + (second - 0x80) * 0x40 + third - 0x80) or first,
            second and third and 3 or 1
    end

    local second, third, fourth = value:byte(position + 1), value:byte(position + 2), value:byte(position + 3)
    return second and third and fourth and
            ((first - 0xF0) * 0x40000 + (second - 0x80) * 0x1000 + (third - 0x80) * 0x40 + fourth - 0x80) or first,
        second and third and fourth and 4 or 1
end

local function isWordCodepoint(codepoint)
    if not codepoint then
        return false
    end
    if codepoint >= 48 and codepoint <= 57 then
        return true
    end
    if (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122) then
        return true
    end
    -- Lateinische Buchstaben mit Akzenten sowie lateinische Erweiterungen.
    return codepoint >= 0x00C0 and codepoint <= 0x02AF and codepoint ~= 0x00D7 and codepoint ~= 0x00F7
end

local function isAutomaticProperName(normalized)
    if not Ploty.db then
        return false
    end

    for _, fullName in ipairs(Ploty.db.emoteOrder or {}) do
        local shortName = tostring(fullName or ""):match("^([^-]+)") or ""
        if lowerGerman(shortName) == normalized then
            return true
        end
    end

    for _, group in ipairs(Ploty.db.emoteGroups or {}) do
        for namePart in tostring(group.name or ""):gmatch("[%a\128-\255]+") do
            if lowerGerman(namePart) == normalized then
                return true
            end
        end
    end

    return false
end

local function upperGerman(value)
    return tostring(value or ""):upper()
        :gsub("ä", "Ä")
        :gsub("ö", "Ö")
        :gsub("ü", "Ü")
        :gsub("ß", "ẞ")
end

local function getInitialCharacter(word)
    local _, byteLength = readCodepoint(word, 1)
    return word:sub(1, math.max(1, byteLength)), math.max(1, byteLength)
end

local function hasUpperInitial(word)
    local first = getInitialCharacter(word)
    return first == upperGerman(first) and first ~= lowerGerman(first)
end

local function changeInitialCase(word, makeUpper)
    local first, byteLength = getInitialCharacter(word)
    local replacement = makeUpper and upperGerman(first) or lowerGerman(first)
    return replacement .. word:sub(byteLength + 1)
end

local function shouldIgnoreWord(normalized)
    return normalized:find("%d") ~= nil or #normalized <= 1 or isAutomaticProperName(normalized)
end

local function findMisspellings(value)
    value = tostring(value or "")
    local issues = {}
    local position = getContentStart(value)
    local wordStart
    local wordStartsSentence = false
    local slashEmote = Ploty:IsSlashEmoteCommand(value)
    local sentenceStart = not slashEmote
    local insideQuote = false

    local function addIssue(kind, word, wordEnd, suggestion, message)
        issues[#issues + 1] = {
            kind = kind,
            message = message,
            original = word,
            suggestion = suggestion,
            startPosition = wordStart,
            endPosition = wordEnd,
        }
    end

    local function finishWord(wordEnd)
        if not wordStart or wordEnd < wordStart then
            wordStart = nil
            return
        end

        local word = value:sub(wordStart, wordEnd)
        local normalized = lowerGerman(word)
        local ignored = shouldIgnoreWord(normalized)
        local suggestion = COMMON_CORRECTIONS[normalized]
        local known = ignored or (Ploty.GermanDictionaryContains and Ploty:GermanDictionaryContains(word))

        if #issues < MAX_ISSUES and suggestion then
            addIssue("spelling", word, wordEnd, suggestion, "„" .. word .. "“ → „" .. suggestion .. "“")
        elseif #issues < MAX_ISSUES and not known then
            addIssue("spelling", word, wordEnd, nil, "„" .. word .. "“ ist nicht im Wörterbuch.")
        elseif #issues < MAX_ISSUES and not ignored then
            local initialUpper = hasUpperInitial(word)
            local requiredCase = Ploty.GetGermanDictionaryRequiredCase and
                Ploty:GetGermanDictionaryRequiredCase(word) or nil
            local caseSuggestion

            if wordStartsSentence and not initialUpper then
                caseSuggestion = changeInitialCase(word, true)
            elseif not wordStartsSentence and requiredCase == "upper" and not initialUpper then
                caseSuggestion = changeInitialCase(word, true)
            elseif not wordStartsSentence and requiredCase == "lower" and initialUpper then
                caseSuggestion = changeInitialCase(word, false)
            end

            if caseSuggestion and caseSuggestion ~= word then
                addIssue("capitalization", word, wordEnd, caseSuggestion,
                    "„" .. word .. "“ → „" .. caseSuggestion .. "“ (Groß-/Kleinschreibung)")
            end
        end
        wordStart = nil
        wordStartsSentence = false
        sentenceStart = false
    end

    while position <= #value and #issues < MAX_ISSUES do
        local codepoint, byteLength = readCodepoint(value, position)
        if isWordCodepoint(codepoint) then
            if not wordStart then
                wordStart = position
                wordStartsSentence = sentenceStart
            end
        else
            finishWord(position - 1)
            if codepoint == 46 or codepoint == 33 or codepoint == 63 then
                sentenceStart = true
            elseif codepoint == 34 or codepoint == 0x201E or codepoint == 0x201C or codepoint == 0x201D then
                if insideQuote then
                    insideQuote = false
                else
                    insideQuote = true
                    sentenceStart = true
                end
            end
        end
        position = position + byteLength
    end
    finishWord(#value)

    return issues
end

function Ploty:IsWritingCheckEnabled()
    return self.db and self.db.settings and self.db.settings.writingCheckEnabled and true or false
end

function Ploty:SetWritingCheckEnabled(enabled)
    if not self.db or not self.db.settings then
        return false
    end
    self.db.settings.writingCheckEnabled = enabled and true or false
    if self.UpdateEmoteTextState then
        self:UpdateEmoteTextState()
    end
    return true
end

function Ploty:AnalyzeWriting(value)
    return findMisspellings(value)
end

function Ploty:GetCurrentWritingIssues()
    if not self:IsWritingCheckEnabled() then
        return {}
    end
    return findMisspellings(self.db and self.db.emoteText and self.db.emoteText.draft or "")
end

function Ploty:GetMisspelledWordRanges(value)
    if not self:IsWritingCheckEnabled() then
        return {}
    end
    return findMisspellings(value)
end
