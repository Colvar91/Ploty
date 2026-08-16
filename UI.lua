local addonName, Ploty = ...

local RAID_MARKER_NAMES = {
    "Stern", "Kreis", "Diamant", "Dreieck",
    "Mond", "Quadrat", "Kreuz", "Totenkopf",
}

-- Weltmarkierungen in Shadowlands 9.2.7: 1 Quadrat, 2 Dreieck,
-- 3 Diamant, 4 Kreuz, 5 Stern, 6 Kreis, 7 Halbmond, 8 Totenkopf.
-- Die Icon-Textur verwendet dagegen die normale Zielmarker-Reihenfolge.
local WORLD_MARKERS = {
    { marker = 5, icon = 1, name = "Gelber Stern" },
    { marker = 6, icon = 2, name = "Oranger Kreis" },
    { marker = 3, icon = 3, name = "Lila Diamant" },
    { marker = 2, icon = 4, name = "Grünes Dreieck" },
    { marker = 7, icon = 5, name = "Heller Halbmond" },
    { marker = 1, icon = 6, name = "Blaues Quadrat" },
    { marker = 4, icon = 7, name = "Rotes Kreuz" },
    { marker = 8, icon = 8, name = "Weißer Totenkopf" },
}
Ploty.WORLD_MARKERS = WORLD_MARKERS

local MARKER_BUTTON_SIZE = 44
local MARKER_BUTTON_STEP = 64
local MARKER_BUTTON_LEFT = 18
local MARKER_BUTTON_TOP = -40

local UI_STYLE = {
    windowWidth = 880,
    windowHeight = 660,
    minimumWidth = 840,
    minimumHeight = 640,
    navigationWidth = 140,
    contentLeft = 166,
    contentRight = 14,
    accent = { 0.71, 0.42, 0.95 },
    accentStrong = { 0.82, 0.58, 1.00 },
    panel = { 0.030, 0.030, 0.045, 0.94 },
    panelRaised = { 0.055, 0.050, 0.075, 0.97 },
    panelBorder = { 0.24, 0.20, 0.32, 0.95 },
    navigation = { 0.022, 0.022, 0.034, 0.98 },
    navigationIdle = { 0.050, 0.047, 0.068, 0.92 },
    navigationHover = { 0.105, 0.080, 0.135, 0.96 },
    navigationActive = { 0.145, 0.090, 0.190, 0.98 },
}
Ploty.UI_STYLE = UI_STYLE

local ROLL_COLUMNS = {
    number = { x = 2, width = 22, title = "Nr." },
    name = { x = 26, width = 110, title = "Name" },
    result = { x = 138, width = 74, title = "Wurf" },
    range = { x = 214, width = 55, title = "Bereich" },
    outcome = { x = 271, width = 105, title = "Bewertung" },
    target = { x = 378, width = 90, title = "Ziel" },
    time = { x = 470, width = 66, title = "Zeit" },
    action = { x = 540, width = 78, title = "Auswahl" },
}
Ploty.ROLL_COLUMNS = ROLL_COLUMNS

local shortName = Ploty.ShortName
local function samePlayerName(first, second)
    return Ploty:SamePlayerName(first, second)
end

local function saveFramePosition(frame, key)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    Ploty.db.positions[key] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
    Ploty.db.settings.windowWidth = frame:GetWidth()
    Ploty.db.settings.windowHeight = frame:GetHeight()
end

local function restoreFramePosition(frame, key)
    frame:ClearAllPoints()
    local position = Ploty.db.positions[key]
    if position and position.point then
        frame:SetPoint(
            position.point,
            UIParent,
            position.relativePoint or position.point,
            position.x or 0,
            position.y or 0
        )
    else
        frame:SetPoint("CENTER")
    end
end

local function createPanel(parent, title)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(UI_STYLE.panel))
    panel:SetBackdropBorderColor(unpack(UI_STYLE.panelBorder))

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 0.58)
    accent:SetPoint("TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", 0, 1)
    accent:SetWidth(2)
    panel.accent = accent

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetText(title or "")
    heading:SetTextColor(0.92, 0.81, 1.00, 1)
    panel.heading = heading
    return panel
end

local function createButton(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 100, height or 28)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.085, 0.070, 0.105, 0.98)
    button:SetBackdropBorderColor(0.36, 0.27, 0.45, 1)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    button:SetText(text or "")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.58, 0.34, 0.78, 0.18)

    local pushed = button:CreateTexture(nil, "ARTWORK")
    pushed:SetAllPoints()
    pushed:SetColorTexture(0.38, 0.20, 0.52, 0.22)
    button:SetPushedTexture(pushed)

    button:SetScript("OnDisable", function(self)
        if self.plotyComposerAction then
            self:SetBackdropColor(0.050, 0.047, 0.065, 0.96)
            self:SetBackdropBorderColor(0.22, 0.19, 0.28, 0.95)
        else
            self:SetBackdropColor(0.045, 0.043, 0.052, 0.92)
            self:SetBackdropBorderColor(0.16, 0.15, 0.18, 0.9)
        end
    end)
    button:SetScript("OnEnable", function(self)
        if self.plotyPrimaryAction then
            self:SetBackdropColor(0.16, 0.065, 0.22, 0.98)
            self:SetBackdropBorderColor(0.72, 0.44, 0.94, 1)
        else
            self:SetBackdropColor(0.085, 0.070, 0.105, 0.98)
            self:SetBackdropBorderColor(0.36, 0.27, 0.45, 1)
        end
    end)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

local function applyInputStyle(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.032, 0.050, 0.98)
    frame:SetBackdropBorderColor(0.27, 0.22, 0.36, 1)
end

local function createEditBox(parent, width, height)
    local editBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    editBox:SetSize(width, height or 28)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextInsets(9, 9, 0, 0)
    editBox:SetTextColor(0.96, 0.94, 1.00, 1)
    applyInputStyle(editBox)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropColor(0.055, 0.045, 0.075, 1)
        self:SetBackdropBorderColor(0.72, 0.44, 0.94, 1)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        applyInputStyle(self)
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return editBox
end

local function createCheck(parent, labelText, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    if onClick then
        check:SetScript("OnClick", onClick)
    end

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(labelText)
    check.label = label
    return check
end

local function createScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(100, 100)
    scroll:SetScrollChild(content)
    return scroll, content
end

local function updateScrollBarVisibility(scroll, content)
    if not scroll or not content or not scroll.ScrollBar then
        return
    end
    local contentHeight = tonumber(content:GetHeight()) or 0
    local viewportHeight = tonumber(scroll:GetHeight()) or 0
    scroll.ScrollBar:SetShown(contentHeight > viewportHeight + 1)
end

local function createNavigationButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(38)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(unpack(UI_STYLE.navigationIdle))
    button:SetBackdropBorderColor(0.15, 0.13, 0.20, 0.95)

    local accent = button:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(unpack(UI_STYLE.accentStrong))
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:Hide()
    button.activeAccent = accent

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 14, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    button.textLabel = label
    button.navigationLabel = text or ""

    button:SetScript("OnEnter", function(self)
        if not self.isNavigationActive then
            self:SetBackdropColor(unpack(UI_STYLE.navigationHover))
            self:SetBackdropBorderColor(0.34, 0.25, 0.43, 1)
        end
    end)
    button:SetScript("OnLeave", function()
        if Ploty and Ploty.UpdateNavigationState then
            Ploty:UpdateNavigationState()
        end
    end)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

-- Nachfolgende Module verwenden dieselben Fabriken. Damit bleiben Rahmen,
-- Schaltflächen und Eingabefelder in allen Reitern optisch identisch.
Ploty.CreatePanel = createPanel
Ploty.CreateButton = createButton
Ploty.CreateEditBox = createEditBox
Ploty.CreateCheck = createCheck
Ploty.CreateScrollArea = createScrollArea
Ploty.CreateNavigationButton = createNavigationButton
Ploty.UpdateScrollBarVisibility = updateScrollBarVisibility

function Ploty:GetNavigationItems()
    return {
        { index = 1, button = self.overviewTab },
        { index = 2, button = self.toolsTab },
        { index = 3, button = self.emoteTab },
        { index = 4, button = self.emoteTextTab },
        { index = 5, button = self.rollTab },
    }
end

function Ploty:GetPagePresentation(index)
    local definitions = {
        { title = "Übersicht" },
        { title = "Markierungen" },
        { title = "Reihenfolge" },
        { title = "Emote-Schreiber" },
        { title = "Würfelübersicht" },
    }
    return definitions[index] or definitions[1]
end

function Ploty:SetNavigationButtonText(button, text)
    if not button then
        return
    end
    button.navigationLabel = tostring(text or "")
    if button.textLabel then
        button.textLabel:SetText(button.navigationLabel)
    else
        button:SetText(button.navigationLabel)
    end
end

function Ploty:UpdateNavigationState(activeIndex)
    activeIndex = activeIndex or self.activeTab
    for _, item in ipairs(self:GetNavigationItems()) do
        local button = item.button
        if button then
            local active = item.index == activeIndex
            button.isNavigationActive = active
            if active then
                button:SetBackdropColor(unpack(UI_STYLE.navigationActive))
                button:SetBackdropBorderColor(0.48, 0.30, 0.61, 1)
                if button.activeAccent then button.activeAccent:Show() end
                if button.textLabel then button.textLabel:SetTextColor(1.00, 0.88, 1.00, 1) end
            else
                button:SetBackdropColor(unpack(UI_STYLE.navigationIdle))
                button:SetBackdropBorderColor(0.15, 0.13, 0.20, 0.95)
                if button.activeAccent then button.activeAccent:Hide() end
                if button.textLabel then button.textLabel:SetTextColor(0.83, 0.81, 0.88, 1) end
            end
        end
    end
end

function Ploty:LayoutNavigation()
    if not self.navigationPanel then
        return
    end

    local verticalOffset = 106
    for _, item in ipairs(self:GetNavigationItems()) do
        local button = item.button
        if button then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 10, -verticalOffset)
            button:SetPoint("TOPRIGHT", -10, -verticalOffset)
            button:SetHeight(38)
            if self.isParticipantBuild and item.index == 2 then
                button:Hide()
            else
                button:Show()
                verticalOffset = verticalOffset + 44
            end
        end
    end
    self:UpdateNavigationState()
end

function Ploty:UpdatePageHeader(index)
    local definition = self:GetPagePresentation(index or self.activeTab or 1)
    if self.pageTitle then
        self.pageTitle:SetText(definition.title)
    end
    if self.emoteGroupManagerButton then
        self.emoteGroupManagerButton:SetShown(index == 3 and self:CanEditOfficialOrder())
    end
    if index ~= 3 and self.emoteGroupManagerFrame then
        self.emoteGroupManagerFrame:Hide()
    end
    if self.roleBadge then
        if self.isParticipantBuild then
            self.roleBadge:SetText("TEILNEHMER")
            self.roleBadge:SetTextColor(0.62, 0.78, 1.00, 1)
        else
            self.roleBadge:SetText("PLOTLEITUNG")
            self.roleBadge:SetTextColor(0.91, 0.70, 1.00, 1)
        end
    end
    self:UpdateNavigationState(index)
end

function Ploty:LayoutMainContent(index)
    index = index or self.activeTab or 1
    local showsTurnPanel = index == 4
    if self.globalTurnPanel then
        self.globalTurnPanel:SetShown(showsTurnPanel)
    end
    if self.pageContainer then
        self.pageContainer:ClearAllPoints()
        local topOffset = -92
        if showsTurnPanel then
            topOffset = self.isParticipantBuild and -144 or -176
        end
        self.pageContainer:SetPoint("TOPLEFT", UI_STYLE.contentLeft, topOffset)
        self.pageContainer:SetPoint("BOTTOMRIGHT", -UI_STYLE.contentRight, 16)
    end
    self:UpdatePageHeader(index)
end

local function createMarkerButton(parent, markerIndex, leftMacro, rightMacro, tooltipTitle, tooltipLeft, tooltipRight)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(MARKER_BUTTON_SIZE, MARKER_BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", leftMacro)
    button:SetAttribute("type2", "macro")
    button:SetAttribute("macrotext2", rightMacro)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.33, 0.28, 0.42, 0.9)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.12, 0.11, 0.16, 0.98)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. markerIndex)
    icon:SetPoint("TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", -5, 5)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltipTitle)
        GameTooltip:AddLine(tooltipLeft, 1, 1, 1)
        GameTooltip:AddLine(tooltipRight, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function createWorldMarkerButton(parent, definition)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(MARKER_BUTTON_SIZE, MARKER_BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button:SetAttribute("type1", "worldmarker")
    button:SetAttribute("action1", "set")
    button:SetAttribute("marker1", definition.marker)

    button:SetAttribute("type2", "worldmarker")
    button:SetAttribute("action2", "clear")
    button:SetAttribute("marker2", definition.marker)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.33, 0.28, 0.42, 0.9)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 2, -2)
    background:SetPoint("BOTTOMRIGHT", -2, 2)
    background:SetColorTexture(0.12, 0.11, 0.16, 0.98)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. definition.icon)
    icon:SetPoint("TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", -5, 5)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(definition.name .. " als Weltmarkierung")
        GameTooltip:AddLine("Linksklick: Platzierung aktivieren", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: diese Weltmarkierung entfernen", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function createSecureMacroButton(parent, text, width, height, macroText)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(width, height)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", macroText)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.32, 0.27, 0.40, 1)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(0.12, 0.11, 0.16, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)
    return button
end

local function createClearAllWorldMarkersButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(width, height)
    button:RegisterForClicks("LeftButtonUp")

    -- Shadowlands 9.2.7 supports the protected "worldmarker" secure action.
    -- With action="clear" and no marker attribute, ClearRaidMarker(nil) clears
    -- every active world marker from the hardware click itself.
    button:SetAttribute("type1", "worldmarker")
    button:SetAttribute("action1", "clear")

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.32, 0.27, 0.40, 1)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(0.12, 0.11, 0.16, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)
    return button
end

local MULTILINE_EDITOR_RIGHT_GUTTER = 18

local function createMultilineEditor(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "BackdropTemplate")
    local editBox = CreateFrame("EditBox", nil, scroll)
    applyInputStyle(scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextInsets(8, 8, 8, 8)
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scroll:SetScrollChild(editBox)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = tonumber(self:GetVerticalScroll()) or 0
        local maximum = tonumber(self:GetVerticalScrollRange()) or 0
        local target = current - (tonumber(delta) or 0) * 36
        self:SetVerticalScroll(math.max(0, math.min(maximum, target)))
    end)
    scroll:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            editBox:SetFocus()
            editBox:SetCursorPosition(#(editBox:GetText() or ""))
        end
    end)
    editBox:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self:SetFocus()
        end
    end)
    editBox:SetScript("OnEditFocusGained", function()
        scroll:SetBackdropColor(0.055, 0.045, 0.075, 1)
        scroll:SetBackdropBorderColor(0.72, 0.44, 0.94, 1)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        applyInputStyle(scroll)
    end)
    scroll:SetScript("OnSizeChanged", function(self, width)
        -- Die Breite direkt am ScrollFrame aktualisieren. Beim Größenereignis
        -- des Hauptfensters konnte GetWidth() hier noch den vorherigen Wert
        -- liefern und der Text dadurch rechts über den Rahmen hinausragen.
        width = tonumber(width) or self:GetWidth()
        editBox:SetWidth(math.max(100, width - MULTILINE_EDITOR_RIGHT_GUTTER))
    end)

    return scroll, editBox
end

function Ploty:CreateGlobalTurnPanel(parent)
    local panel = createPanel(parent, "")
    panel.heading:Hide()
    panel:SetPoint("TOPLEFT", UI_STYLE.contentLeft, -90)
    panel:SetPoint("TOPRIGHT", -UI_STYLE.contentRight, -90)
    panel:SetHeight(76)

    local activeName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeName:SetPoint("TOP", 0, -6)
    activeName:SetSize(220, 24)
    activeName:SetFontObject("GameFontNormalLarge")
    activeName:SetJustifyH("CENTER")
    activeName:Hide()
    self.globalActiveName = activeName

    local previousName = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previousName:SetPoint("RIGHT", activeName, "LEFT", -12, 0)
    previousName:SetSize(190, 20)
    previousName:SetJustifyH("RIGHT")
    previousName:Hide()
    self.globalPreviousName = previousName

    local nextName = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nextName:SetPoint("LEFT", activeName, "RIGHT", 12, 0)
    nextName:SetSize(190, 20)
    nextName:SetJustifyH("LEFT")
    nextName:Hide()
    self.globalNextName = nextName

    local summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", 12, -11)
    summary:SetPoint("TOPRIGHT", -12, -11)
    summary:SetHeight(22)
    summary:SetJustifyH("CENTER")
    summary:SetJustifyV("TOP")
    summary:SetWordWrap(true)
    self.globalTurnSummary = summary

    local backButton = createButton(panel, "Zurück", 82, 26, function()
        Ploty:MoveOfficialEmoteTurn(-1)
    end)
    backButton:SetPoint("BOTTOMLEFT", 12, 9)
    self.turnBackButton = backButton

    local nextButton = createButton(panel, "Weiter", 82, 26, function()
        Ploty:MoveOfficialEmoteTurn(1)
    end)
    nextButton:SetPoint("LEFT", backButton, "RIGHT", 7, 0)
    self.turnNextButton = nextButton

    local pauseButton = createButton(panel, "Pause", 95, 26, function()
        Ploty:ToggleEmotePause()
    end)
    pauseButton:SetPoint("LEFT", nextButton, "RIGHT", 7, 0)
    self.turnPauseButton = pauseButton

    local typing = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typing:SetPoint("BOTTOMRIGHT", -12, 14)
    typing:SetWidth(280)
    typing:SetJustifyH("RIGHT")
    self.globalTypingLabel = typing

    if self.isParticipantBuild then
        backButton:Hide()
        nextButton:Hide()
        pauseButton:Hide()
        panel:SetHeight(44)
        typing:ClearAllPoints()
        typing:SetPoint("BOTTOMRIGHT", -12, 7)
    end

    self.globalTurnPanel = panel
end

function Ploty:EnsureLongTextRequestDialog()
    if self.longTextRequestDialog then
        return self.longTextRequestDialog
    end

    local frame = CreateFrame("Frame", "PlotyLongTextRequestDialog", UIParent, "BackdropTemplate")
    frame:SetSize(390, 150)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.025, 0.04, 0.98)
    frame:SetBackdropBorderColor(unpack(UI_STYLE.accentStrong))

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Langtext-Anfrage")
    title:SetTextColor(0.92, 0.81, 1.00, 1)

    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", 18, -47)
    message:SetPoint("TOPRIGHT", -18, -47)
    message:SetHeight(38)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetWordWrap(true)
    frame.message = message

    local approveButton = createButton(frame, "Freigeben", 115, 28, function()
        Ploty:AnswerLongTextRequest(true)
    end)
    approveButton:SetPoint("BOTTOMRIGHT", -139, 16)

    local denyButton = createButton(frame, "Ablehnen", 115, 28, function()
        Ploty:AnswerLongTextRequest(false)
    end)
    denyButton:SetPoint("BOTTOMRIGHT", -18, 16)

    frame:Hide()
    self.longTextRequestDialog = frame
    return frame
end

function Ploty:ShowLongTextRequestDialog(sender)
    local frame = self:EnsureLongTextRequestDialog()
    frame.message:SetText("|cffffffff" .. shortName(sender) .. "|r möchte für den aktuellen Emote-Zug mehr als 1020 Zeichen senden.")
    frame:Show()
    frame:Raise()
end

function Ploty:HideLongTextRequestDialog()
    if self.longTextRequestDialog then
        self.longTextRequestDialog:Hide()
    end
end

function Ploty:CreateEmoteGroupManager()
    if self.emoteGroupManagerFrame then
        return self.emoteGroupManagerFrame
    end

    local frame = CreateFrame("Frame", "PlotyEmoteGroupManager", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 390)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("Gruppen")

    local editorPanel = createPanel(frame, "Gruppe anlegen oder bearbeiten")
    editorPanel:SetPoint("TOPLEFT", 12, -34)
    editorPanel:SetPoint("TOPRIGHT", -12, -34)
    editorPanel:SetHeight(104)

    local nameLabel = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", 12, -38)
    nameLabel:SetText("Name")

    local nameBox = createEditBox(editorPanel, 180, 28)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameBox:SetMaxLetters(32)
    self.emoteGroupNameBox = nameBox

    local colorButton = createButton(editorPanel, "Rot", 92, 28)
    colorButton:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
    colorButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.emoteGroupColorButton = colorButton

    local saveButton = createButton(editorPanel, "Gruppe anlegen", 140, 28, function()
        local editor = Ploty.emoteGroupEditor
        if Ploty:AddOrUpdateEmoteGroup(editor.id, Ploty.emoteGroupNameBox:GetText(), editor.colorKey) then
            Ploty:ResetEmoteGroupEditor()
        end
    end)
    saveButton:SetPoint("LEFT", colorButton, "RIGHT", 10, 0)
    self.emoteGroupSaveButton = saveButton

    local cancelButton = createButton(editorPanel, "Abbrechen", 90, 24, function()
        Ploty:ResetEmoteGroupEditor()
    end)
    cancelButton:SetPoint("BOTTOMRIGHT", -12, 9)
    self.emoteGroupCancelButton = cancelButton

    local hint = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 13)
    hint:SetPoint("RIGHT", cancelButton, "LEFT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Farbe: Linksklick vorwärts, Rechtsklick zurück.")

    local listPanel = createPanel(frame, "Gruppenreihenfolge · oben beginnt")
    listPanel:SetPoint("TOPLEFT", editorPanel, "BOTTOMLEFT", 0, -10)
    listPanel:SetPoint("BOTTOMRIGHT", -12, 48)

    local scroll, content = createScrollArea(listPanel)
    scroll:SetPoint("TOPLEFT", 10, -34)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    self.emoteGroupScroll = scroll
    self.emoteGroupContent = content
    self.emoteGroupRows = {}

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 18, 18)
    footer:SetWidth(370)
    footer:SetJustifyH("LEFT")
    footer:SetText("Zugfolge: Gruppe 1 komplett, dann Gruppe 2. Ohne Gruppe zuletzt.")

    local closeButton = createButton(frame, "Schließen", 100, 26, function()
        frame:Hide()
    end)
    closeButton:SetPoint("BOTTOMRIGHT", -16, 12)

    self.emoteGroupEditor = { id = nil, colorKey = "RED" }

    colorButton:SetScript("OnClick", function(_, mouseButton)
        local direction = mouseButton == "RightButton" and -1 or 1
        local currentIndex = 1
        for index, definition in ipairs(Ploty.EMOTE_GROUP_COLORS or {}) do
            if definition.key == Ploty.emoteGroupEditor.colorKey then
                currentIndex = index
                break
            end
        end
        local colors = Ploty.EMOTE_GROUP_COLORS or {}
        if #colors > 0 then
            Ploty.emoteGroupEditor.colorKey = colors[((currentIndex - 1 + direction) % #colors) + 1].key
            Ploty:RefreshEmoteGroupEditor()
        end
    end)

    frame:Hide()
    self.emoteGroupManagerFrame = frame
    self:ResetEmoteGroupEditor()
    return frame
end

function Ploty:RefreshEmoteGroupEditor()
    if not self.emoteGroupEditor or not self.emoteGroupColorButton then
        return
    end
    local color = self:GetEmoteGroupColor(self.emoteGroupEditor.colorKey)
    self.emoteGroupColorButton:SetText(color.label)
    self.emoteGroupColorButton:SetBackdropColor(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.98)
    self.emoteGroupColorButton:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    self.emoteGroupSaveButton:SetText(self.emoteGroupEditor.id and "Änderungen speichern" or "Gruppe anlegen")
end

function Ploty:ResetEmoteGroupEditor()
    if not self.emoteGroupEditor then
        return
    end
    self.emoteGroupEditor.id = nil
    self.emoteGroupEditor.colorKey = "RED"
    self.emoteGroupNameBox:SetText("")
    self:RefreshEmoteGroupEditor()
end

function Ploty:EditEmoteGroup(groupId)
    local group = self:GetEmoteGroupById(groupId)
    if not group then
        return
    end
    self.emoteGroupEditor.id = group.id
    self.emoteGroupEditor.colorKey = group.colorKey
    self.emoteGroupNameBox:SetText(group.name)
    self:RefreshEmoteGroupEditor()
    self.emoteGroupNameBox:SetFocus()
end

function Ploty:RefreshEmoteGroupManager()
    if not self.emoteGroupContent then
        return
    end

    local groups = self.db.emoteGroups or {}
    local rowHeight = 31
    self.emoteGroupContent:SetWidth(math.max(430, self.emoteGroupScroll:GetWidth() - 4))
    for index, group in ipairs(groups) do
        local row = self.emoteGroupRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.emoteGroupContent)
            row:SetHeight(rowHeight)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row.swatch = row:CreateTexture(nil, "ARTWORK")
            row.swatch:SetPoint("LEFT", 6, 0)
            row.swatch:SetSize(16, 16)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", 30, 0)
            row.name:SetWidth(112)
            row.name:SetJustifyH("LEFT")
            row.members = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.members:SetPoint("LEFT", 146, 0)
            row.members:SetWidth(58)
            row.members:SetJustifyH("LEFT")
            row.up = createButton(row, "Hoch", 42, 23, function()
                Ploty:MoveEmoteGroup(row.groupId, -1)
            end)
            row.up:SetPoint("RIGHT", -164, 0)
            row.down = createButton(row, "Runter", 48, 23, function()
                Ploty:MoveEmoteGroup(row.groupId, 1)
            end)
            row.down:SetPoint("RIGHT", -111, 0)
            row.edit = createButton(row, "Bearb.", 68, 23, function()
                Ploty:EditEmoteGroup(row.groupId)
            end)
            row.edit:SetPoint("RIGHT", -38, 0)
            row.delete = createButton(row, "X", 28, 23, function()
                Ploty:DeleteEmoteGroup(row.groupId)
                Ploty:ResetEmoteGroupEditor()
            end)
            row.delete:SetPoint("RIGHT", -5, 0)
            self.emoteGroupRows[index] = row
        end

        local color = self:GetEmoteGroupColor(group.colorKey)
        row.groupId = group.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
        row:SetPoint("RIGHT", 0, 0)
        row.background:SetColorTexture(index % 2 == 0 and 0.10 or 0.055, index % 2 == 0 and 0.09 or 0.05, index % 2 == 0 and 0.13 or 0.075, 0.65)
        row.swatch:SetColorTexture(color.r, color.g, color.b, 1)
        row.name:SetText(group.name)
        row.name:SetTextColor(color.r, color.g, color.b, 1)
        local memberCount = self:GetEmoteGroupMemberCount(group.id)
        row.members:SetText(memberCount .. (memberCount == 1 and " Person" or " Personen"))
        if index == 1 then
            row.up:Disable()
        else
            row.up:Enable()
        end
        if index == #groups then
            row.down:Disable()
        else
            row.down:Enable()
        end
        row:Show()
    end
    for index = #groups + 1, #self.emoteGroupRows do
        self.emoteGroupRows[index]:Hide()
    end
    self.emoteGroupContent:SetHeight(math.max(110, #groups * rowHeight))
    updateScrollBarVisibility(self.emoteGroupScroll, self.emoteGroupContent)
end

function Ploty:OpenEmoteGroupManager()
    if not self:CanEditOfficialOrder() then
        self:Print("Nur die Plotleitung kann Gruppen bearbeiten.")
        return false
    end
    local frame = self:CreateEmoteGroupManager()
    self:RefreshEmoteGroupManager()
    frame:Show()
    frame:Raise()
    return true
end

function Ploty:CreateOverviewPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local statusPanel = createPanel(page, "Plotstatus")
    statusPanel:SetPoint("TOPLEFT", 0, 0)
    statusPanel:SetPoint("TOPRIGHT", 0, 0)
    statusPanel:SetHeight(154)

    local status = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    status:SetPoint("TOPLEFT", 14, -42)
    self.plotOverviewStatus = status

    local detail = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    detail:SetWidth(430)
    detail:SetJustifyH("LEFT")
    self.plotOverviewDetail = detail

    local action = createButton(statusPanel, "Plot starten", 145, 32, function()
        Ploty:TogglePlot()
    end)
    action:SetPoint("TOPRIGHT", -14, -42)
    self.plotToggleButton = action

    local guidance = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guidance:SetPoint("BOTTOMLEFT", 14, 14)
    guidance:SetPoint("BOTTOMRIGHT", -14, 14)
    guidance:SetJustifyH("LEFT")
    self.plotOverviewGuidance = guidance

    local summaryPanel = createPanel(page, "Aktueller Stand")
    summaryPanel:SetPoint("TOPLEFT", statusPanel, "BOTTOMLEFT", 0, -12)
    summaryPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    local summary = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", 16, -42)
    summary:SetPoint("TOPRIGHT", -16, -42)
    summary:SetJustifyH("LEFT")
    summary:SetJustifyV("TOP")
    summary:SetSpacing(8)
    self.plotOverviewSummary = summary

    local orderButton = createButton(summaryPanel, "Reihenfolge öffnen", 150, 30, function()
        Ploty:ShowTab(3)
    end)
    orderButton:SetPoint("BOTTOMLEFT", 16, 16)

    local emoteButton = createButton(summaryPanel, "Emote-Schreiber", 145, 30, function()
        Ploty:ShowTab(4)
    end)
    emoteButton:SetPoint("LEFT", orderButton, "RIGHT", 10, 0)

    local rollButton = createButton(summaryPanel, "Würfelübersicht", 145, 30, function()
        Ploty:ShowTab(5)
    end)
    rollButton:SetPoint("LEFT", emoteButton, "RIGHT", 10, 0)

    self.overviewPage = page
end

function Ploty:RefreshPlotOverview()
    if not self.plotOverviewStatus then
        return
    end

    local active = self:IsPlotActive()
    local order = self.db.emoteOrder or {}
    local groupCount = #(self.db.emoteGroups or {})
    local presentCount = 0
    local absentCount = 0
    for _, name in ipairs(order) do
        if self:GetParticipantStatus(name) == "ABSENT" then
            absentCount = absentCount + 1
        else
            presentCount = presentCount + 1
        end
    end

    if active then
        self.plotOverviewStatus:SetText("PLOT LÄUFT")
        self.plotOverviewStatus:SetTextColor(0.35, 1.00, 0.45, 1)
        self.plotOverviewDetail:SetText("Gestartet um " .. date("%H:%M:%S", self.plotStartedAt or time()))
        self.plotOverviewGuidance:SetText("Änderungen an Reihenfolge, Gruppen und Zugstatus werden automatisch übertragen.")
    else
        self.plotOverviewStatus:SetText("PLOT NICHT GESTARTET")
        self.plotOverviewStatus:SetTextColor(1.00, 0.72, 0.22, 1)
        self.plotOverviewDetail:SetText("Die Reihenfolge kann vorbereitet werden, bleibt aber vollständig lokal.")
        self.plotOverviewGuidance:SetText("Erst „Plot starten“ aktiviert Synchronisierung, Emote-Züge und Würfelaufforderungen.")
    end

    local currentName = active and self:GetCurrentEmoteParticipant() or nil
    self.plotOverviewSummary:SetText(table.concat({
        "|cffc8bfd8Teilnehmer:|r  " .. #order,
        "|cffc8bfd8Anwesend:|r  |cff55ff55" .. presentCount .. "|r    |cffc8bfd8Abwesend:|r  |cffff5555" .. absentCount .. "|r",
        "|cffc8bfd8Gruppen:|r  " .. groupCount,
        "|cffc8bfd8Aktueller Emoter:|r  " .. (currentName and shortName(currentName) or "–"),
    }, "\n"))

    if self:CanSyncEmoteOrder() then
        self.plotToggleButton:Show()
        self.plotToggleButton:SetText(active and "Plot beenden" or "Plot starten")
        if active or #order > 0 then
            self.plotToggleButton:Enable()
        else
            self.plotToggleButton:Disable()
        end
        if active then
            self.plotToggleButton:SetBackdropColor(0.18, 0.045, 0.045, 0.98)
            self.plotToggleButton:SetBackdropBorderColor(0.85, 0.24, 0.22, 1)
        else
            self.plotToggleButton:SetBackdropColor(0.045, 0.16, 0.065, 0.98)
            self.plotToggleButton:SetBackdropBorderColor(0.25, 0.85, 0.35, 1)
        end
    else
        self.plotToggleButton:Hide()
    end
end

function Ploty:CreateToolsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local targetPanel = createPanel(page, "Zielmarkierungen")
    targetPanel:SetPoint("TOPLEFT", 0, 0)
    targetPanel:SetPoint("TOPRIGHT", 0, 0)
    targetPanel:SetHeight(118)

    self.targetMarkerButtons = {}
    for index = 1, 8 do
        local toggleMacro = "/run local m=GetRaidTargetIndex(\"target\");SetRaidTarget(\"target\",m==" ..
            index .. " and 0 or " .. index .. ")"
        local button = createMarkerButton(
            targetPanel,
            index,
            toggleMacro,
            "/tm 0",
            RAID_MARKER_NAMES[index] .. " auf aktuelles Ziel",
            "Linksklick: setzen · erneut klicken: entfernen",
            "Rechtsklick: Markierung entfernen"
        )
        button:SetPoint("TOPLEFT", MARKER_BUTTON_LEFT + ((index - 1) * MARKER_BUTTON_STEP), MARKER_BUTTON_TOP)
        self.targetMarkerButtons[index] = button
    end

    local targetHint = targetPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetHint:SetPoint("BOTTOMLEFT", 14, 10)
    targetHint:SetText("Die Zielmarke wird auf dein aktuell ausgewähltes Ziel gesetzt.")

    local worldPanel = createPanel(page, "Weltmarkierungen")
    worldPanel:SetPoint("TOPLEFT", targetPanel, "BOTTOMLEFT", 0, -12)
    worldPanel:SetPoint("TOPRIGHT", targetPanel, "BOTTOMRIGHT", 0, -12)
    worldPanel:SetHeight(158)

    self.worldMarkerButtons = {}
    for index, definition in ipairs(WORLD_MARKERS) do
        local button = createWorldMarkerButton(worldPanel, definition)
        button:SetPoint("TOPLEFT", MARKER_BUTTON_LEFT + ((index - 1) * MARKER_BUTTON_STEP), MARKER_BUTTON_TOP)
        self.worldMarkerButtons[index] = button
    end

    local clearButton = createClearAllWorldMarkersButton(worldPanel, "Alle Weltmarken löschen", 175, 28)
    clearButton:SetPoint("BOTTOMLEFT", 14, 14)

    -- Auf der Markierungsseite wird bewusst kein Emote-Rundenstatus angezeigt.
    self.groupStatusLabel = nil

    self.toolsPage = page
end

function Ploty:CreateEmotePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local groupManagerButton = createButton(self.contentHeader or page, "Gruppen", 100, 28, function()
        Ploty:OpenEmoteGroupManager()
    end)
    if self.contentHeader then
        groupManagerButton:SetPoint("TOPRIGHT", -8, -8)
    else
        groupManagerButton:SetPoint("TOPRIGHT", -10, -7)
    end
    groupManagerButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Gruppen verwalten")
        GameTooltip:AddLine("Eigene Gruppennamen und Farben anlegen. Die Zuweisung erfolgt in der Teilnehmerliste.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    groupManagerButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    groupManagerButton:Hide()
    self.emoteGroupManagerButton = groupManagerButton

    local entryPanel = createPanel(page, "Reihenfolge bearbeiten")
    entryPanel:SetPoint("TOPLEFT", 0, 0)
    entryPanel:SetPoint("TOPRIGHT", 0, 0)
    entryPanel:SetHeight(86)
    self.emoteEntryPanel = entryPanel

    local nameBox = createEditBox(entryPanel, 235, 28)
    nameBox:SetPoint("TOPLEFT", 12, -38)
    nameBox:SetScript("OnEnterPressed", function(self)
        if Ploty:AddEmoteParticipant(self:GetText()) then
            self:SetText("")
        end
        self:ClearFocus()
    end)
    self.emoteNameBox = nameBox

    local addButton = createButton(entryPanel, "Hinzufügen", 100, 28, function()
        if Ploty:AddEmoteParticipant(nameBox:GetText()) then
            nameBox:SetText("")
        end
    end)
    addButton:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    self.addEmoteButton = addButton

    local importButton = createButton(entryPanel, "Mitglieder übernehmen", 145, 28, function()
        Ploty:ImportGroupToEmoteOrder()
    end)
    importButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    self.importEmoteButton = importButton

    local clearButton = createButton(entryPanel, "Liste leeren", 105, 28, function()
        Ploty:ClearEmoteOrder()
    end)
    clearButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)
    self.clearEmoteButton = clearButton

    local listPanel = createPanel(page, "Gruppen- und Teilnehmerreihenfolge")
    listPanel:SetPoint("TOPLEFT", entryPanel, "BOTTOMLEFT", 0, -10)
    listPanel:SetPoint("TOPRIGHT", entryPanel, "BOTTOMRIGHT", 0, -10)
    listPanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 158)
    self.emoteOrderPanel = listPanel

    local source = listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    source:SetPoint("TOPRIGHT", -12, -12)
    source:SetWidth(330)
    source:SetJustifyH("RIGHT")
    self.emoteOrderSourceLabel = source

    local scroll, content = createScrollArea(listPanel)
    scroll:SetPoint("TOPLEFT", 10, -34)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    self.emoteListScroll = scroll
    self.emoteListContent = content
    self.emoteRows = {}
    self.emoteGroupHeaders = {}

    local syncPanel = createPanel(page, "Automatische Synchronisierung")
    syncPanel:SetPoint("BOTTOMLEFT", 0, 0)
    syncPanel:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -5, 0)
    syncPanel:SetHeight(148)
    self.emoteSyncPanel = syncPanel

    local syncButton = createButton(syncPanel, "Erneut senden", 145, 28, function()
        Ploty:SendEmoteOrder(false)
    end)
    syncButton:SetPoint("TOPLEFT", 12, -36)
    self.syncEmoteButton = syncButton

    local requestButton = createButton(syncPanel, "Anfordern", 100, 28, function()
        Ploty:RequestEmoteOrder()
    end)
    requestButton:SetPoint("LEFT", syncButton, "RIGHT", 8, 0)
    self.requestEmoteButton = requestButton

    local compactCheck = createCheck(syncPanel, "Nur vorherigen, aktiven und nächsten Namen oben anzeigen", function(self)
        Ploty:SetCompactTurnBar(self:GetChecked())
    end)
    compactCheck:SetPoint("TOPLEFT", 9, -76)
    self.compactTurnCheck = compactCheck

    local syncStatus = syncPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncStatus:SetPoint("BOTTOMLEFT", 12, 10)
    syncStatus:SetPoint("BOTTOMRIGHT", -12, 10)
    syncStatus:SetJustifyH("LEFT")
    syncStatus:SetWordWrap(true)
    self.emoteSyncStatus = syncStatus

    local clientPanel = createPanel(page, "Ploty-Clients")
    clientPanel:SetPoint("BOTTOMLEFT", page, "BOTTOM", 5, 0)
    clientPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    clientPanel:SetHeight(148)
    self.clientPanel = clientPanel

    local clientScroll, clientContent = createScrollArea(clientPanel)
    clientScroll:SetPoint("TOPLEFT", 10, -34)
    clientScroll:SetPoint("BOTTOMRIGHT", -28, 28)
    self.clientVersionScroll = clientScroll
    self.clientVersionContent = clientContent
    self.clientVersionRows = {}

    local clientWarning = clientPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clientWarning:SetPoint("BOTTOMLEFT", 12, 8)
    clientWarning:SetPoint("BOTTOMRIGHT", -12, 8)
    clientWarning:SetJustifyH("LEFT")
    self.clientVersionWarning = clientWarning

    if self.isParticipantBuild then
        entryPanel:Hide()
        listPanel:ClearAllPoints()
        listPanel:SetPoint("TOPLEFT", 0, 0)
        listPanel:SetPoint("TOPRIGHT", 0, 0)
        listPanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 158)

        syncButton:Hide()
        requestButton:ClearAllPoints()
        requestButton:SetPoint("TOPLEFT", 12, -36)
        syncPanel.heading:SetText("Aktuellen Stand")
    end

    self.emotePage = page
end

function Ploty:CreateEmoteTextPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    -- Der Schreiber braucht keinen zusätzlichen Abschnittsrahmen: Das
    -- eigentliche Textfeld besitzt bereits einen klaren eigenen Rahmen.
    local editorPanel = CreateFrame("Frame", nil, page)
    editorPanel:SetPoint("TOPLEFT", 0, 0)
    editorPanel:SetPoint("TOPRIGHT", 0, 0)
    editorPanel:SetPoint("BOTTOM", page, "BOTTOM", 0, 80)
    self.emoteEditorPanel = editorPanel

    local scroll, editBox = createMultilineEditor(editorPanel)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 38)
    editBox:SetWidth(700)
    editBox:SetHeight(330)
    self.emoteTextScroll = scroll
    self.emoteTextBox = editBox

    local overlay = editBox:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    if overlay.SetDrawLayer then
        overlay:SetDrawLayer("ARTWORK", 7)
    end
    overlay:SetPoint("TOPLEFT", 8, -8)
    overlay:SetPoint("TOPRIGHT", -8, -8)
    overlay:SetJustifyH("LEFT")
    overlay:SetJustifyV("TOP")
    overlay:SetWordWrap(true)
    self.emoteInlineColorText = overlay

    if editBox.SetMaxLetters then
        editBox:SetMaxLetters(Ploty:IsLongEmoteTextEnabled() and 0 or 1020)
    end

    editBox:SetScript("OnEnterPressed", function(self)
        self.plotyEnterCursor = self:GetCursorPosition()
        self:SetFocus()
    end)
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "ENTER" or key == "NUMPADENTER" then
            self.plotyEnterCursor = self:GetCursorPosition()
        end
    end)
    editBox:SetScript("OnTextChanged", function(self)
        if Ploty.isRefreshingEmoteDraft then
            return
        end

        local currentText = self:GetText() or ""
        local cursorPosition = self:GetCursorPosition()
        local limitedText, _, wasTruncated = Ploty:SetEmoteDraft(currentText)

        if wasTruncated or currentText ~= limitedText then
            Ploty.isRefreshingEmoteDraft = true
            self:SetText(limitedText)
            local restoredCursor = self.plotyEnterCursor or cursorPosition
            restoredCursor = math.max(0, math.min(#limitedText, restoredCursor))
            self:SetCursorPosition(restoredCursor)
            self.plotyEnterCursor = nil
            Ploty.isRefreshingEmoteDraft = false
        end

        Ploty:NotifyTypingActivity(limitedText ~= "")
        Ploty:UpdateEmoteTextState()

        if self.GetStringHeight then
            local height = self:GetStringHeight()
            if height then
                self:SetHeight(math.max(330, height + 24))
            end
        end
    end)

    local longRequestButton = createButton(editorPanel, "Mehr Text anfragen", 145, 25, function()
        Ploty:RequestLongEmoteText()
    end)
    longRequestButton:SetPoint("BOTTOMLEFT", 0, 7)
    self.longTextRequestButton = longRequestButton

    local longStatus = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    longStatus:SetPoint("LEFT", longRequestButton, "RIGHT", 10, 0)
    longStatus:SetJustifyH("LEFT")
    self.longTextApprovalLabel = longStatus

    local counter = editorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counter:SetPoint("BOTTOMRIGHT", 0, 12)
    counter:SetWidth(190)
    counter:SetJustifyH("RIGHT")
    longStatus:SetPoint("RIGHT", counter, "LEFT", -12, 0)
    self.emoteTextCounter = counter

    local actionPanel = CreateFrame("Frame", nil, page)
    actionPanel:SetPoint("BOTTOMLEFT", 0, 0)
    actionPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    actionPanel:SetHeight(70)
    self.emoteActionPanel = actionPanel

    local sendButton = createButton(actionPanel, "Emote senden", 170, 30, function()
        Ploty:SendEmoteText()
    end)
    sendButton.plotyComposerAction = true
    sendButton.plotyPrimaryAction = true
    sendButton:SetPoint("TOPLEFT", 0, 0)
    self.sendEmoteTextButton = sendButton

    local passButton = createButton(actionPanel, "Passen", 100, 30, function()
        Ploty:PassCurrentEmoteTurn()
    end)
    passButton.plotyComposerAction = true
    passButton:SetPoint("LEFT", sendButton, "RIGHT", 8, 0)
    passButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Emote-Zug passen")
        GameTooltip:AddLine("Beendet deinen aktuellen Zug ohne ein Emote zu senden.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    passButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.passEmoteTurnButton = passButton

    local clearButton = createButton(actionPanel, "Text leeren", 120, 30, function()
        Ploty:ClearEmoteDraft()
        Ploty:NotifyTypingActivity(false)
    end)
    clearButton.plotyComposerAction = true
    clearButton:SetPoint("LEFT", passButton, "RIGHT", 8, 0)
    self.clearEmoteTextButton = clearButton

    local resendButton = createButton(actionPanel, "Letztes wiederholen", 155, 30, function()
        Ploty:ResendLastEmote()
    end)
    resendButton.plotyComposerAction = true
    resendButton:SetPoint("TOPLEFT", clearButton, "TOPRIGHT", 8, 0)
    resendButton:SetPoint("TOPRIGHT", actionPanel, "TOPRIGHT", 0, 0)
    self.resendLastEmoteButton = resendButton

    local clearCheck = createCheck(actionPanel, "Nach Versand leeren", function(self)
        Ploty:SetClearEmoteAfterSend(self:GetChecked())
    end)
    clearCheck:SetPoint("BOTTOMLEFT", -3, 1)
    self.clearEmoteAfterSendCheck = clearCheck

    self.emoteChannelChecks = {}
    local channelOptions = {
        { key = "RAID", label = "Raid" },
        { key = "PARTY", label = "Gruppe" },
        { key = "YELL", label = "Yell" },
        { key = "SAY", label = "Say" },
    }

    local previous = clearCheck.label
    for _, option in ipairs(channelOptions) do
        local check = createCheck(actionPanel, option.label, function()
            Ploty:SetEmoteChannel(option.key)
        end)
        check:SetPoint("LEFT", previous, "RIGHT", 24, 0)
        self.emoteChannelChecks[option.key] = check
        previous = check.label
    end

    local writingCheck = createCheck(actionPanel, "Schreibprüfung aus", function(self)
        Ploty:SetWritingCheckEnabled(self:GetChecked())
    end)
    writingCheck:SetPoint("LEFT", previous, "RIGHT", 24, 0)
    writingCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Lokale Schreibprüfung")
        if not Ploty:IsWritingCheckEnabled() then
            GameTooltip:AddLine("Prüft Wörter sowie Groß- und Kleinschreibung und markiert Fehler direkt im Text rot.", 1, 1, 1, true)
        elseif #(Ploty.currentWritingIssues or {}) == 0 then
            GameTooltip:AddLine("Keine Rechtschreib- oder Groß-/Kleinschreibungsfehler gefunden.", 0.45, 1, 0.55, true)
        else
            for _, issue in ipairs(Ploty.currentWritingIssues) do
                GameTooltip:AddLine("• " .. issue.message, 1, 0.78, 0.35, true)
            end
            GameTooltip:AddLine("Rot markierte Wörter werden nicht automatisch verändert und blockieren den Versand nicht.", 0.75, 0.75, 0.75, true)
        end
        GameTooltip:Show()
    end)
    writingCheck:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.writingCheckCheck = writingCheck

    self.emoteTextPage = page
end

function Ploty:CreateRollPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    local setupPanel = createPanel(page, "Würfelprobe")
    setupPanel:SetPoint("TOPLEFT", 0, 0)
    setupPanel:SetPoint("TOPRIGHT", 0, 0)
    setupPanel:SetHeight(150)
    self.rollSetupPanel = setupPanel

    local titleLabel = setupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleLabel:SetPoint("TOPLEFT", 12, -38)
    titleLabel:SetText("Titel")

    local titleBox = createEditBox(setupPanel, 230, 28)
    titleBox:SetPoint("LEFT", titleLabel, "RIGHT", 8, 0)
    titleBox:SetMaxLetters(80)
    self.rollTitleBox = titleBox

    local targetLabel = setupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetLabel:SetPoint("LEFT", titleBox, "RIGHT", 16, 0)
    targetLabel:SetText("Ziel")

    local targetBox = createEditBox(setupPanel, 58, 28)
    targetBox:SetPoint("LEFT", targetLabel, "RIGHT", 7, 0)
    targetBox:SetNumeric(true)
    targetBox:SetMaxLetters(7)
    self.rollTargetBox = targetBox

    local fromLabel = setupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fromLabel:SetPoint("TOPLEFT", 12, -78)
    fromLabel:SetText("Von")

    local minimumBox = createEditBox(setupPanel, 62, 28)
    minimumBox:SetPoint("LEFT", fromLabel, "RIGHT", 8, 0)
    minimumBox:SetNumeric(true)
    minimumBox:SetMaxLetters(7)
    self.rollMinimumBox = minimumBox

    local toLabel = setupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toLabel:SetPoint("LEFT", minimumBox, "RIGHT", 10, 0)
    toLabel:SetText("bis")

    local maximumBox = createEditBox(setupPanel, 62, 28)
    maximumBox:SetPoint("LEFT", toLabel, "RIGHT", 8, 0)
    maximumBox:SetNumeric(true)
    maximumBox:SetMaxLetters(7)
    self.rollMaximumBox = maximumBox

    local startButton = createButton(setupPanel, "Auswahl auffordern", 145, 30, function()
        Ploty:StartRollRequest(
            titleBox:GetText(),
            targetBox:GetText(),
            minimumBox:GetText(),
            maximumBox:GetText()
        )
    end)
    startButton:SetPoint("LEFT", maximumBox, "RIGHT", 14, 0)
    self.startRollRoundButton = startButton

    local callButton = createButton(setupPanel, "Auswahl leeren", 125, 30, function()
        Ploty:ClearRollSelection(false)
    end)
    callButton:SetPoint("LEFT", startButton, "RIGHT", 8, 0)
    self.rollCallButton = callButton

    local rollNowButton = createButton(setupPanel, "Jetzt würfeln", 115, 30, function()
        Ploty:DoRequestedRoll()
    end)
    rollNowButton:SetPoint("LEFT", callButton, "RIGHT", 8, 0)
    self.rollNowButton = rollNowButton

    local roundStatus = setupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roundStatus:SetPoint("BOTTOMLEFT", 12, 11)
    roundStatus:SetPoint("BOTTOMRIGHT", -12, 11)
    roundStatus:SetJustifyH("LEFT")
    self.rollRoundStatus = roundStatus

    local overviewPanel = createPanel(page, "Spielerauswahl und Würfe")
    overviewPanel:SetPoint("TOPLEFT", setupPanel, "BOTTOMLEFT", 0, -10)
    overviewPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    self.rollOverviewPanel = overviewPanel

    local sortCheck = createCheck(overviewPanel, "Nach Ergebnis sortieren", function(self)
        Ploty:SetSortRolls(self:GetChecked())
    end)
    sortCheck:SetPoint("TOPLEFT", 9, -31)
    self.sortRollsCheck = sortCheck

    local clearButton = createButton(overviewPanel, "Würfel leeren", 105, 25, function()
        Ploty:ClearParticipantRolls()
    end)
    clearButton:SetPoint("TOPRIGHT", -12, -31)

    local lastOutcome = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lastOutcome:SetPoint("TOP", 0, -15)
    lastOutcome:SetText("")
    self.rollOutcomeLabel = lastOutcome

    local lastRoll = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lastRoll:SetPoint("TOP", lastOutcome, "BOTTOM", 0, -3)
    self.lastRollLabel = lastRoll

    local header = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header:SetText("")
    header:Hide()
    self.rollOverviewHeader = header

    self.rollColumnHeaders = {}
    local columnOrder = { "number", "name", "result", "range", "outcome", "target", "time", "action" }
    for _, key in ipairs(columnOrder) do
        local definition = ROLL_COLUMNS[key]
        local label = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 10 + definition.x, -64)
        label:SetWidth(definition.width)
        label:SetJustifyH("LEFT")
        label:SetText(definition.title)
        label:SetTextColor(0.70, 0.68, 0.75, 1)
        self.rollColumnHeaders[key] = label
    end
    self.rollActionHeader = self.rollColumnHeaders.action

    local scroll, content = createScrollArea(overviewPanel)
    scroll:SetPoint("TOPLEFT", 10, -82)
    scroll:SetPoint("BOTTOMRIGHT", -28, 48)
    self.rollListScroll = scroll
    self.rollListContent = content
    self.rollRows = {}

    local overviewStatus = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overviewStatus:SetPoint("BOTTOMLEFT", 12, 26)
    self.rollOverviewStatus = overviewStatus

    local missing = overviewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    missing:SetPoint("BOTTOMLEFT", 12, 8)
    missing:SetPoint("BOTTOMRIGHT", -12, 8)
    missing:SetJustifyH("LEFT")
    missing:SetWordWrap(false)
    self.missingRollLabel = missing

    self.rollLeaderControls = {
        titleLabel, titleBox, targetLabel, targetBox,
        fromLabel, minimumBox, toLabel, maximumBox,
        startButton, callButton, clearButton,
    }
    self.clearRollsButton = clearButton

    if self.isParticipantBuild then
        titleLabel:Hide()
        titleBox:Hide()
        targetLabel:Hide()
        targetBox:Hide()
        fromLabel:Hide()
        minimumBox:Hide()
        toLabel:Hide()
        maximumBox:Hide()
        startButton:Hide()
        callButton:Hide()
        clearButton:Hide()

        setupPanel:SetHeight(92)
        rollNowButton:ClearAllPoints()
        rollNowButton:SetPoint("TOPLEFT", 12, -38)
        roundStatus:ClearAllPoints()
        roundStatus:SetPoint("LEFT", rollNowButton, "RIGHT", 14, 0)
        roundStatus:SetPoint("RIGHT", -12, 0)
        overviewPanel:ClearAllPoints()
        overviewPanel:SetPoint("TOPLEFT", setupPanel, "BOTTOMLEFT", 0, -10)
        overviewPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    self.rollPage = page
end

function Ploty:ShowTab(index)
    if not self.mainFrame then
        return
    end

    if self.isParticipantBuild and index == 2 then
        index = 1
    end

    self.activeTab = index

    self:LayoutMainContent(index)
    local pages = { self.overviewPage, self.toolsPage, self.emotePage, self.emoteTextPage, self.rollPage }

    for pageIndex, page in ipairs(pages) do
        if pageIndex == index then
            page:Show()
        else
            page:Hide()
        end
    end

    if index == 1 then
        self:RefreshPlotOverview()
    elseif index == 3 then
        self:SetEmoteOrderUnread(false)
        self:RefreshEmoteOrder()
        self:RefreshClientVersions()
    elseif index == 4 then
        -- Reihenfolge und aktiven Zug beim Öffnen des Schreibers immer direkt
        -- aus dem aktuellen Datenbankstand darstellen.
        self:RefreshEmoteOrder()
        self:RefreshGlobalTurnBar()
        self:RefreshEmoteTextDraft()
        self:UpdateEmoteTextState()
    elseif index == 5 then
        self:SetRollRequestUnread(false)
        self:RefreshRollRound()
        self:RefreshParticipantRolls()
    end

    self:RefreshGlobalTurnBar()
end

function Ploty:ApplyAccessModeToUI()
    if not self.mainFrame then
        return
    end

    local participantMode = self.isParticipantBuild and true or false
    self:LayoutNavigation()
    if participantMode and self.emoteGroupManagerFrame then
        self.emoteGroupManagerFrame:Hide()
    end

    if self.globalTurnPanel then
        if participantMode then
            if self.turnBackButton then self.turnBackButton:Hide() end
            if self.turnNextButton then self.turnNextButton:Hide() end
            if self.turnPauseButton then self.turnPauseButton:Hide() end
            self.globalTurnPanel:SetHeight(44)
            if self.globalTypingLabel then
                self.globalTypingLabel:ClearAllPoints()
                self.globalTypingLabel:SetPoint("BOTTOMRIGHT", -12, 7)
            end
        else
            if self.turnBackButton then self.turnBackButton:Show() end
            if self.turnNextButton then self.turnNextButton:Show() end
            if self.turnPauseButton then self.turnPauseButton:Show() end
            self.globalTurnPanel:SetHeight(76)
            if self.globalTypingLabel then
                self.globalTypingLabel:ClearAllPoints()
                self.globalTypingLabel:SetPoint("BOTTOMRIGHT", -12, 14)
            end
        end
    end

    if self.emoteEntryPanel and self.emoteOrderPanel and self.emoteSyncPanel then
        self.emoteOrderPanel:ClearAllPoints()
        if participantMode then
            self.emoteEntryPanel:Hide()
            self.emoteOrderPanel:SetPoint("TOPLEFT", 0, 0)
            self.emoteOrderPanel:SetPoint("TOPRIGHT", 0, 0)
            self.emoteOrderPanel:SetPoint("BOTTOM", self.emotePage, "BOTTOM", 0, 158)
            if self.syncEmoteButton then self.syncEmoteButton:Hide() end
            if self.requestEmoteButton then
                self.requestEmoteButton:ClearAllPoints()
                self.requestEmoteButton:SetPoint("TOPLEFT", 12, -36)
            end
            if self.emoteSyncPanel.heading then
                self.emoteSyncPanel.heading:SetText("Aktuellen Stand")
            end
        else
            self.emoteEntryPanel:Show()
            self.emoteOrderPanel:SetPoint("TOPLEFT", self.emoteEntryPanel, "BOTTOMLEFT", 0, -10)
            self.emoteOrderPanel:SetPoint("TOPRIGHT", self.emoteEntryPanel, "BOTTOMRIGHT", 0, -10)
            self.emoteOrderPanel:SetPoint("BOTTOM", self.emotePage, "BOTTOM", 0, 158)
            if self.syncEmoteButton then self.syncEmoteButton:Show() end
            if self.requestEmoteButton and self.syncEmoteButton then
                self.requestEmoteButton:ClearAllPoints()
                self.requestEmoteButton:SetPoint("LEFT", self.syncEmoteButton, "RIGHT", 8, 0)
            end
            if self.emoteSyncPanel.heading then
                self.emoteSyncPanel.heading:SetText("Automatische Synchronisierung")
            end
        end
    end

    if self.rollSetupPanel and self.rollOverviewPanel then
        for _, control in ipairs(self.rollLeaderControls or {}) do
            if participantMode then
                control:Hide()
            else
                control:Show()
            end
        end

        if participantMode then
            self.rollSetupPanel:SetHeight(92)
            if self.rollActionHeader then self.rollActionHeader:Hide() end
            if self.rollNowButton then
                self.rollNowButton:ClearAllPoints()
                self.rollNowButton:SetPoint("TOPLEFT", 12, -38)
            end
            if self.rollRoundStatus then
                self.rollRoundStatus:ClearAllPoints()
                self.rollRoundStatus:SetPoint("LEFT", self.rollNowButton, "RIGHT", 14, 0)
                self.rollRoundStatus:SetPoint("RIGHT", -12, 0)
            end
        else
            self.rollSetupPanel:SetHeight(150)
            if self.rollActionHeader then self.rollActionHeader:Show() end
            if self.rollNowButton and self.rollCallButton then
                self.rollNowButton:ClearAllPoints()
                self.rollNowButton:SetPoint("LEFT", self.rollCallButton, "RIGHT", 8, 0)
            end
            if self.rollRoundStatus then
                self.rollRoundStatus:ClearAllPoints()
                self.rollRoundStatus:SetPoint("BOTTOMLEFT", 12, 11)
                self.rollRoundStatus:SetPoint("BOTTOMRIGHT", -12, 11)
            end
        end
        self.rollOverviewPanel:ClearAllPoints()
        self.rollOverviewPanel:SetPoint("TOPLEFT", self.rollSetupPanel, "BOTTOMLEFT", 0, -10)
        self.rollOverviewPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    if participantMode and self.activeTab == 2 then
        self.activeTab = 1
    end

    self:UpdatePageHeader(self.activeTab or 1)

    if self.activeTab then
        self:ShowTab(self.activeTab)
    end
    self:RefreshEmoteOrder()
    self:UpdateEmoteSyncStatus()
    self:RefreshRollRound()
    self:RefreshParticipantRolls()
    self:RefreshGlobalTurnBar()
    self:RefreshPlotOverview()
end

function Ploty:CreateMainFrame()
    if self.mainFrame then
        return
    end

    local frame = CreateFrame("Frame", "PlotyMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(
        math.max(UI_STYLE.minimumWidth, tonumber(self.db.settings.windowWidth) or UI_STYLE.windowWidth),
        math.max(UI_STYLE.minimumHeight, tonumber(self.db.settings.windowHeight) or UI_STYLE.windowHeight)
    )
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("DIALOG")
    -- Die Marke steht bereits deutlich in der Navigation; der kleine native
    -- Rahmentitel würde sie nur ein zweites Mal wiederholen.
    frame.TitleText:SetText("")

    if frame.SetMinResize then
        frame:SetMinResize(UI_STYLE.minimumWidth, UI_STYLE.minimumHeight)
    end
    if frame.SetMaxResize then
        frame:SetMaxResize(1100, 840)
    end

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveFramePosition(self, "main")
    end)
    frame:SetScript("OnSizeChanged", function(self)
        Ploty.db.settings.windowWidth = self:GetWidth()
        Ploty.db.settings.windowHeight = self:GetHeight()
        if Ploty.emoteListContent and Ploty.emoteListScroll then
            Ploty.emoteListContent:SetWidth(math.max(100, Ploty.emoteListScroll:GetWidth() - 4))
        end
        if Ploty.rollListContent and Ploty.rollListScroll then
            Ploty.rollListContent:SetWidth(math.max(100, Ploty.rollListScroll:GetWidth() - 4))
        end
    end)
    frame:SetScript("OnShow", function()
        -- Vor jedem Öffnen die aktuelle Gruppenrolle prüfen. Dadurch wechselt
        -- die Oberfläche auch nach einer Beförderung oder Herabstufung korrekt.
        Ploty:UpdateAccessMode(true)

        -- Nur die sichtbaren Inhalte aktualisieren. Ein kompletter Roster-Neuaufbau
        -- beim Öffnen konnte den angezeigten Zustand und damit den Eindruck des
        -- Interfaces verändern.
        Ploty:ShowTab(Ploty.activeTab or 1)
        Ploty:RefreshGlobalTurnBar()

        -- HELLO löst bei der Plotleitung genau eine Zustandssynchronisierung aus.
        -- Ein zusätzliches REQUEST führte zuvor nach Reload zu doppelten Meldungen.
        if IsInGroup() and (#(Ploty.db.emoteOrder or {}) == 0 or not Ploty.db.orderSender) then
            if Ploty.SendHello then
                Ploty:SendHello()
            end
        end
    end)

    restoreFramePosition(frame, "main")

    local navigation = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    navigation:SetPoint("TOPLEFT", 12, -34)
    navigation:SetPoint("BOTTOMLEFT", 12, 12)
    navigation:SetWidth(UI_STYLE.navigationWidth)
    navigation:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    navigation:SetBackdropColor(unpack(UI_STYLE.navigation))
    navigation:SetBackdropBorderColor(0.16, 0.14, 0.21, 1)
    self.navigationPanel = navigation

    local brand = navigation:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    brand:SetPoint("TOPLEFT", 14, -14)
    brand:SetText("PLOTY")
    brand:SetTextColor(unpack(UI_STYLE.accentStrong))

    local version = navigation:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("TOPRIGHT", -12, -18)
    version:SetText("v" .. tostring(self.version or ""))

    local roleBadge = navigation:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleBadge:SetPoint("TOPLEFT", 14, -43)
    roleBadge:SetPoint("TOPRIGHT", -12, -43)
    roleBadge:SetJustifyH("LEFT")
    self.roleBadge = roleBadge

    local navigationRule = navigation:CreateTexture(nil, "ARTWORK")
    navigationRule:SetColorTexture(0.24, 0.20, 0.32, 0.9)
    navigationRule:SetPoint("TOPLEFT", 10, -76)
    navigationRule:SetPoint("TOPRIGHT", -10, -76)
    navigationRule:SetHeight(1)

    local contentHeader = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentHeader:SetPoint("TOPLEFT", UI_STYLE.contentLeft, -36)
    contentHeader:SetPoint("TOPRIGHT", -UI_STYLE.contentRight, -36)
    contentHeader:SetHeight(44)
    contentHeader:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    contentHeader:SetBackdropColor(unpack(UI_STYLE.panelRaised))
    contentHeader:SetBackdropBorderColor(unpack(UI_STYLE.panelBorder))
    self.contentHeader = contentHeader

    local pageTitle = contentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageTitle:SetPoint("LEFT", 14, 0)
    pageTitle:SetTextColor(1.00, 0.86, 1.00, 1)
    self.pageTitle = pageTitle

    self.mainFrame = frame

    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(18, 18)
    resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeButton:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        saveFramePosition(frame, "main")
    end)

    local overviewTab = createNavigationButton(navigation, "Übersicht", function()
        Ploty:ShowTab(1)
    end)
    self.overviewTab = overviewTab

    local toolsTab = createNavigationButton(navigation, "Markierungen", function()
        Ploty:ShowTab(2)
    end)
    self.toolsTab = toolsTab

    local emoteTab = createNavigationButton(navigation, "Reihenfolge", function()
        Ploty:ShowTab(3)
    end)
    self.emoteTab = emoteTab

    local textTab = createNavigationButton(navigation, "Emotes", function()
        Ploty:ShowTab(4)
    end)
    self.emoteTextTab = textTab

    local rollTab = createNavigationButton(navigation, "Würfel", function()
        Ploty:ShowTab(5)
    end)
    self.rollTab = rollTab

    self:LayoutNavigation()
    self:CreateGlobalTurnPanel(frame)

    local pageContainer = CreateFrame("Frame", nil, frame)
    pageContainer:SetPoint("TOPLEFT", UI_STYLE.contentLeft, -92)
    pageContainer:SetPoint("BOTTOMRIGHT", -UI_STYLE.contentRight, 16)
    self.pageContainer = pageContainer

    self:CreateOverviewPage(pageContainer)
    self:CreateToolsPage(pageContainer)
    self:CreateEmotePage(pageContainer)
    self:CreateEmoteTextPage(pageContainer)
    self:CreateRollPage(pageContainer)
    self:ApplyAccessModeToUI()

    self:ShowTab(1)
    frame:Hide()
end

function Ploty:RefreshGlobalTurnBar()
    if not self.globalTurnSummary then
        return
    end

    local order = self.db.emoteOrder or {}
    local plotActive = self:IsPlotActive()
    local showLargeActiveName = plotActive and self.db.settings.compactTurnBar and #order > 0
    if not plotActive then
        self.globalTurnSummary:SetText("|cffffcc66Plot noch nicht gestartet|r")
        self.globalTurnSummary:Show()
        self.globalActiveName:SetText("")
        self.globalActiveName:Hide()
        self.globalPreviousName:Hide()
        self.globalNextName:Hide()
    elseif showLargeActiveName then
        local previousName, currentName, nextName = self:GetTurnContext()
        local function setInactiveName(label, name)
            if not label then
                return
            end
            local group = name and self.GetParticipantEmoteGroup and self:GetParticipantEmoteGroup(name) or nil
            local color = group and self.GetEmoteGroupColor and self:GetEmoteGroupColor(group.colorKey) or nil
            label:SetText(shortName(name or ""))
            if color then
                label:SetTextColor(color.r, color.g, color.b, 1)
            else
                label:SetTextColor(0.80, 0.80, 0.80, 1)
            end
        end

        self.globalTurnSummary:SetText("")
        self.globalTurnSummary:Hide()
        self.globalActiveName:SetText("[" .. shortName(currentName) .. "]")
        self.globalActiveName:SetTextColor(0.34, 1.00, 0.42, 1)
        self.globalActiveName:Show()

        setInactiveName(self.globalPreviousName, previousName)
        self.globalPreviousName:SetShown(#order > 1)
        setInactiveName(self.globalNextName, nextName)
        self.globalNextName:SetShown(#order > 2)
    else
        self.globalTurnSummary:SetText(self:GetGlobalTurnDisplayText())
        self.globalTurnSummary:Show()
        if self.globalActiveName then
            self.globalActiveName:SetText("")
            self.globalActiveName:Hide()
        end
        if self.globalPreviousName then
            self.globalPreviousName:Hide()
        end
        if self.globalNextName then
            self.globalNextName:Hide()
        end
    end

    local canControl = plotActive and self:CanEditOfficialOrder() and #order > 0
    local buttons = { self.turnBackButton, self.turnNextButton, self.turnPauseButton }
    for _, button in ipairs(buttons) do
        if button then
            if canControl then
                button:Enable()
            else
                button:Disable()
            end
        end
    end

    if self.turnPauseButton then
        self.turnPauseButton:SetText(self.db.emotePaused and "Fortsetzen" or "Pause")
    end

    if self.globalTypingLabel then
        local currentName = plotActive and self:GetCurrentEmoteParticipant() or nil
        if currentName and self.db.typingStates[self:PlayerKey(currentName)] then
            self.globalTypingLabel:SetText("|cffff9a3c" .. shortName(currentName) .. " schreibt ...|r")
        elseif self.db.emotePaused then
            self.globalTypingLabel:SetText("|cffffcc66Reihenfolge pausiert|r")
        else
            self.globalTypingLabel:SetText("")
        end
    end
end

function Ploty:RefreshEmoteTurnBar()
    self:RefreshGlobalTurnBar()
end

function Ploty:RefreshRollRange()
    if not self.rollMinimumBox or not self.rollMaximumBox then
        return
    end
    local minimum, maximum = self:GetRollRange()
    if not self.rollMinimumBox:HasFocus() then
        self.rollMinimumBox:SetText(tostring(minimum))
    end
    if not self.rollMaximumBox:HasFocus() then
        self.rollMaximumBox:SetText(tostring(maximum))
    end
end

function Ploty:RefreshLastRoll()
    if not self.lastRollLabel then
        return
    end

    local lastRoll = self.db.lastRoll
    if lastRoll and lastRoll.result then
        local outcome, color = self:GetRollOutcome(lastRoll.result, lastRoll.minimum, lastRoll.maximum)
        self.rollOutcomeLabel:SetText("Eigener Wurf: " .. color .. outcome .. "|r")
        self.lastRollLabel:SetText(
            "Letzter Wurf: " .. tostring(lastRoll.result) ..
            " |cff888888(" .. tostring(lastRoll.minimum) .. "-" .. tostring(lastRoll.maximum) .. ")|r"
        )
    else
        self.rollOutcomeLabel:SetText("")
        self.lastRollLabel:SetText("Letzter Wurf: -")
    end
end

function Ploty:RefreshRollRound()
    if not self.rollRoundStatus then
        return
    end

    local round = self:GetRollRound()
    local selectionCount = self:GetRollSelectionCount()
    local plotActive = self:IsPlotActive()
    if not plotActive then
        self.rollRoundStatus:SetText("|cffffcc66Plot noch nicht gestartet.|r")
    elseif round and round.active then
        if self.rollTitleBox and not self.rollTitleBox:HasFocus() then
            self.rollTitleBox:SetText(round.title or "Würfelprobe")
        end
        if self.rollTargetBox and not self.rollTargetBox:HasFocus() then
            self.rollTargetBox:SetText(round.target and tostring(round.target) or "")
        end

        local targetText = round.target and (" · Ziel " .. round.target) or ""
        local baseText = "|cffffffff" .. tostring(round.title or "Würfelprobe") .. "|r · " ..
            tostring(round.minimum) .. "-" .. tostring(round.maximum) .. targetText
        if self:CanControlRollRequest() then
            local rolledCount, targetCount = self:GetRollRequestProgress()
            local progressColor = targetCount > 0 and rolledCount == targetCount and "|cff55ff55" or "|cffffd200"
            self.rollRoundStatus:SetText(
                baseText .. " " .. progressColor .. "· " .. rolledCount .. "/" .. targetCount .. " gewürfelt|r"
            )
        elseif round.requestPending then
            self.rollRoundStatus:SetText(baseText .. " |cffffd200· Du sollst würfeln!|r")
        elseif self:IsRollRequestTarget(Ploty.GetUnitFullName("player")) then
            self.rollRoundStatus:SetText(baseText .. " |cff55ff55· Dein Wurf wurde erfasst|r")
        else
            self.rollRoundStatus:SetText("|cff888888Keine offene Würfelaufforderung für dich.|r")
        end
    else
        if self:CanControlRollRequest() then
            self.rollRoundStatus:SetText(selectionCount .. " ausgewählt · Wähle Spieler unten aus und sende die Aufforderung.")
        else
            self.rollRoundStatus:SetText("Keine offene Würfelaufforderung für dich.")
        end
    end

    if self.startRollRoundButton then
        if plotActive and self:CanControlRollRequest() and selectionCount > 0 then
            self.startRollRoundButton:Enable()
        else
            self.startRollRoundButton:Disable()
        end
    end
    if self.rollCallButton then
        if self:CanControlRollRequest() and selectionCount > 0 then
            self.rollCallButton:Enable()
        else
            self.rollCallButton:Disable()
        end
    end
    if self.rollNowButton then
        if plotActive and round and round.active and round.requestPending then
            self.rollNowButton:Enable()
            self.rollNowButton:SetText("Jetzt würfeln!")
        else
            self.rollNowButton:Disable()
            self.rollNowButton:SetText("Bitte warten")
        end
    end
    if self.sortRollsCheck then
        self.sortRollsCheck:SetChecked(self.db.settings.sortRolls and true or false)
    end
end

function Ploty:RefreshParticipantRolls()
    if not self.rollListContent or not self.rollRows then
        return
    end

    local participants = self:GetSortedRollParticipants()
    local rolledCount = 0
    local targetCount = 0
    local missingNames = {}
    local rowHeight = 30
    local contentWidth = math.max(620, self.rollListScroll:GetWidth() - 4)
    self.rollListContent:SetWidth(contentWidth)

    for index, participant in ipairs(participants) do
        local row = self.rollRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.rollListContent)
            row:SetHeight(rowHeight)
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()

            local function textAt(x, width, font)
                local label = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
                label:SetPoint("LEFT", x, 0)
                label:SetWidth(width)
                label:SetJustifyH("LEFT")
                return label
            end

            row.number = textAt(ROLL_COLUMNS.number.x, ROLL_COLUMNS.number.width)
            row.name = textAt(ROLL_COLUMNS.name.x, ROLL_COLUMNS.name.width, "GameFontHighlight")
            row.result = textAt(ROLL_COLUMNS.result.x, ROLL_COLUMNS.result.width, "GameFontHighlight")
            row.range = textAt(ROLL_COLUMNS.range.x, ROLL_COLUMNS.range.width)
            row.outcome = textAt(ROLL_COLUMNS.outcome.x, ROLL_COLUMNS.outcome.width)
            row.target = textAt(ROLL_COLUMNS.target.x, ROLL_COLUMNS.target.width)
            row.time = textAt(ROLL_COLUMNS.time.x, ROLL_COLUMNS.time.width)
            row.request = createButton(row, "Auswählen", ROLL_COLUMNS.action.width, 22, function()
                Ploty:ToggleRollParticipantSelection(row.participantName)
            end)
            row.request:SetPoint("LEFT", ROLL_COLUMNS.action.x, 0)
            self.rollRows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
        row:SetPoint("RIGHT", 0, 0)

        row.number:SetText(index .. ".")
        row.name:SetText(participant.name)
        row.participantName = participant.fullName or participant.name
        local isSelected = self:IsRollParticipantSelected(row.participantName)
        local isTarget = self:IsRollRequestTarget(row.participantName)
        if isTarget then
            row.background:SetColorTexture(0.16, 0.10, 0.22, 0.82)
            targetCount = targetCount + 1
        elseif isSelected then
            row.background:SetColorTexture(0.11, 0.08, 0.15, 0.74)
        else
            row.background:SetColorTexture(
                index % 2 == 0 and 0.10 or 0.055,
                index % 2 == 0 and 0.09 or 0.05,
                index % 2 == 0 and 0.13 or 0.075,
                0.65
            )
        end

        if self.isParticipantBuild then
            row.request:Hide()
        else
            row.request:Show()
            row.request:SetText(isSelected and "Gewählt" or "Auswählen")
            local canSelect = self:CanControlRollRequest()
            if canSelect then
                row.request:Enable()
            else
                row.request:Disable()
            end

            -- Die Auswahl muss nicht nur über den Text erkennbar sein. Da ein
            -- bereits aktivierter Button beim Abwählen kein OnEnable auslöst,
            -- werden beide Zustände bei jeder Aktualisierung explizit gesetzt.
            if isSelected then
                row.request:SetBackdropColor(0.035, 0.16, 0.065, 0.98)
                row.request:SetBackdropBorderColor(0.25, 0.85, 0.35, 1)
            elseif canSelect then
                row.request:SetBackdropColor(0.085, 0.070, 0.105, 0.98)
                row.request:SetBackdropBorderColor(0.36, 0.27, 0.45, 1)
            else
                row.request:SetBackdropColor(0.045, 0.043, 0.052, 0.92)
                row.request:SetBackdropBorderColor(0.16, 0.15, 0.18, 0.9)
            end
        end

        local roll = isTarget and self.db.participantRolls[participant.key] or nil
        if roll and tostring(roll.roundId or "") == tostring(self.db.rollRound.id or "") then
            rolledCount = rolledCount + 1
            local outcome, color = self:GetRollOutcome(roll.result, roll.minimum, roll.maximum)
            local targetOutcome, targetColor = self:GetRollTargetOutcome(roll.result)
            row.result:SetText(tostring(roll.result))
            row.range:SetText(tostring(roll.minimum) .. "-" .. tostring(roll.maximum))
            row.outcome:SetText(color .. outcome .. "|r")
            row.target:SetText(targetOutcome and (targetColor .. targetOutcome .. "|r") or "-")
            row.time:SetText(roll.time or "")
        elseif isTarget then
            missingNames[#missingNames + 1] = participant.name
            row.result:SetText("-")
            row.range:SetText("-")
            row.outcome:SetText("|cffffd200Wartet auf Wurf|r")
            row.target:SetText("-")
            row.time:SetText("")
        elseif isSelected then
            row.result:SetText("-")
            row.range:SetText("-")
            row.outcome:SetText("|cffb58cffFür nächste Probe|r")
            row.target:SetText("-")
            row.time:SetText("")
        else
            row.result:SetText("-")
            row.range:SetText("-")
            row.outcome:SetText("|cff777777Nicht ausgewählt|r")
            row.target:SetText("-")
            row.time:SetText("")
        end
        row:Show()
    end

    for index = #participants + 1, #self.rollRows do
        self.rollRows[index]:Hide()
    end

    self.rollListContent:SetHeight(math.max(180, #participants * rowHeight))
    updateScrollBarVisibility(self.rollListScroll, self.rollListContent)
    if targetCount == 0 then
        local selectionCount = self:GetRollSelectionCount()
        self.rollOverviewStatus:SetText(selectionCount .. " Spieler ausgewählt")
        self.missingRollLabel:SetText("Wähle die Personen aus, die für die nächste Probe würfeln sollen.")
    elseif #missingNames > 0 then
        self.rollOverviewStatus:SetText("Auswahl: " .. rolledCount .. "/" .. targetCount .. " gewürfelt")
        self.missingRollLabel:SetText("Fehlt: " .. table.concat(missingNames, ", "))
    else
        self.rollOverviewStatus:SetText("Auswahl: " .. targetCount .. "/" .. targetCount .. " gewürfelt")
        self.missingRollLabel:SetText("|cff55ff55Alle ausgewählten Spieler haben gewürfelt.|r")
    end

    self:RefreshLastRoll()
end

function Ploty:UpdateGroupStatus()
    self:UpdateAccessMode(false)

    if self.groupStatusLabel then
        if not IsInGroup() then
            self.groupStatusLabel:SetText("|cffffcc66Weltmarken benötigen normalerweise eine Gruppe.|r")
        elseif self:HasWorldMarkerPermission() then
            self.groupStatusLabel:SetText("|cff55ff55Du besitzt die nötigen Gruppenrechte.|r")
        else
            self.groupStatusLabel:SetText("|cffffcc66Nur Leitung oder Assistenz darf Weltmarken setzen.|r")
        end
    end

    self:HandleGroupRosterChanged()
    self:RefreshGlobalTurnBar()
    self:RefreshRollRound()
end

function Ploty:SetEmoteOrderUnread(unread)
    self.hasUnreadEmoteOrder = unread and true or false
    if self.emoteTab then
        self:SetNavigationButtonText(self.emoteTab, self.hasUnreadEmoteOrder and "Reihenfolge  •" or "Reihenfolge")
    end
end

function Ploty:SetRollRequestUnread(unread)
    self.hasUnreadRollRequest = unread and true or false
    if self.rollTab then
        self:SetNavigationButtonText(self.rollTab, self.hasUnreadRollRequest and "Würfel  •" or "Würfel")
    end
end

function Ploty:UpdateEmoteSyncStatus()
    if self.emoteOrderSourceLabel then
        if not self:IsPlotActive() then
            self.emoteOrderSourceLabel:SetText("Vorbereitet · Plot noch nicht gestartet")
        elseif self.db.orderSender and self.db.orderUpdatedAt then
            if samePlayerName(self.db.orderSender, Ploty.GetUnitFullName("player")) and self:CanSyncEmoteOrder() then
                self.emoteOrderSourceLabel:SetText("Automatisch synchronisiert · " .. tostring(self.db.orderUpdatedAt))
            else
                self.emoteOrderSourceLabel:SetText(
                    "Von " .. shortName(self.db.orderSender) .. " · " .. tostring(self.db.orderUpdatedAt)
                )
            end
        else
            self.emoteOrderSourceLabel:SetText("Lokal bearbeitet")
        end
    end

    local canEdit = self:CanEditOfficialOrder()
    local editControls = {
        self.emoteNameBox,
        self.addEmoteButton,
        self.importEmoteButton,
        self.clearEmoteButton,
    }
    for _, control in ipairs(editControls) do
        if control then
            if canEdit then
                control:Enable()
            else
                control:Disable()
            end
        end
    end

    if self.syncEmoteButton then
        if self:IsPlotActive() and self:CanSyncEmoteOrder() and IsInGroup() then
            self.syncEmoteButton:Enable()
        else
            self.syncEmoteButton:Disable()
        end
    end
    if self.requestEmoteButton then
        if self:IsPlotActive() and IsInGroup() then
            self.requestEmoteButton:Enable()
        else
            self.requestEmoteButton:Disable()
        end
    end
    if self.compactTurnCheck then
        self.compactTurnCheck:SetChecked(self.db.settings.compactTurnBar and true or false)
    end

    if self.emoteSyncStatus then
        if not self:IsPlotActive() then
            self.emoteSyncStatus:SetText("|cffffcc66Die Reihenfolge ist vorbereitet und wird erst mit „Plot starten“ übertragen.|r")
        elseif self.isParticipantBuild then
            self.emoteSyncStatus:SetText("Die offizielle Reihenfolge wird von der Plotleitung empfangen. Deinen eigenen Status kannst du in der Liste ändern.")
        elseif not IsInGroup() then
            self.emoteSyncStatus:SetText("Lokale Bearbeitung. In einer Gruppe darf nur die Leitung die offizielle Reihenfolge ändern.")
        elseif self:CanSyncEmoteOrder() then
            self.emoteSyncStatus:SetText("|cff55ff55Du steuerst die offizielle Reihenfolge und synchronisierst sie mit den Ploty-Clients.|r")
        else
            self.emoteSyncStatus:SetText("|cffffcc66Nur Leitung oder Assistenz darf die offizielle Reihenfolge ändern.|r")
        end
    end
end

function Ploty:RefreshEmoteOrder()
    if not self.emoteListContent then
        return
    end

    local order = self.db.emoteOrder or {}
    local rowHeight = 31
    local groupHeaderHeight = 24
    local groupHeaderGap = 5
    local canEdit = self:CanEditOfficialOrder()
    local contentWidth = math.max(620, self.emoteListScroll:GetWidth() - 4)
    local currentIndex = self:NormalizeEmoteTurnIndex()
    local showGroupHeaders = #(self.db.emoteGroups or {}) > 0
    local groupPositions = {}
    local blockCounts = {}
    for groupIndex, group in ipairs(self.db.emoteGroups or {}) do
        groupPositions[group.id] = groupIndex
    end
    for _, name in ipairs(order) do
        local group = self:GetParticipantEmoteGroup(name)
        local blockKey = group and group.id or "__UNGROUPED__"
        blockCounts[blockKey] = (blockCounts[blockKey] or 0) + 1
    end
    local contentHeight = 0
    local headerCount = 0
    local previousBlockKey
    self.emoteListContent:SetWidth(contentWidth)

    for index, name in ipairs(order) do
        local isActive = index == currentIndex
        local group = self:GetParticipantEmoteGroup(name)
        local groupKey = group and group.id or "__UNGROUPED__"
        if showGroupHeaders and groupKey ~= previousBlockKey then
            headerCount = headerCount + 1
            if headerCount > 1 then
                contentHeight = contentHeight + groupHeaderGap
            end

            local header = self.emoteGroupHeaders[headerCount]
            if not header then
                header = CreateFrame("Frame", nil, self.emoteListContent, "BackdropTemplate")
                header:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                header.label:SetPoint("LEFT", 10, 0)
                header.label:SetJustifyH("LEFT")
                header.members = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                header.members:SetPoint("RIGHT", -10, 0)
                header.members:SetJustifyH("RIGHT")
                self.emoteGroupHeaders[headerCount] = header
            end

            local headerColor = group and self:GetEmoteGroupColor(group.colorKey) or nil
            local red = headerColor and headerColor.r or 0.62
            local green = headerColor and headerColor.g or 0.62
            local blue = headerColor and headerColor.b or 0.68
            header:SetHeight(groupHeaderHeight)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, -contentHeight)
            header:SetPoint("RIGHT", 0, 0)
            header.label:SetWidth(math.max(200, contentWidth - 150))
            header.members:SetWidth(110)
            header:SetBackdropColor(red * 0.16, green * 0.16, blue * 0.16, 0.96)
            header:SetBackdropBorderColor(red, green, blue, 0.82)
            if group then
                header.label:SetText("GRUPPE " .. tostring(groupPositions[group.id] or headerCount) .. " · " .. group.name)
            else
                header.label:SetText("OHNE GRUPPE")
            end
            header.label:SetTextColor(red, green, blue, 1)
            local memberCount = blockCounts[groupKey] or 0
            header.members:SetText(memberCount .. (memberCount == 1 and " Person" or " Personen"))
            header:Show()
            contentHeight = contentHeight + groupHeaderHeight
            previousBlockKey = groupKey
        end

        local row = self.emoteRows[index]
        if not row then
            row = CreateFrame("Frame", nil, self.emoteListContent, "BackdropTemplate")
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })

            row.number = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.number:SetPoint("LEFT", 6, 0)
            row.number:SetWidth(28)
            row.number:SetJustifyH("LEFT")

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", 34, 0)
            row.name:SetWidth(130)
            row.name:SetJustifyH("LEFT")

            row.status = createButton(row, "Anwesend", 72, 23, function()
                Ploty:CycleParticipantStatus(row.nameValue)
            end)
            row.status:SetPoint("LEFT", 168, 0)

            row.group = createButton(row, "Keine Gruppe", 78, 23, function(_, mouseButton)
                Ploty:CycleParticipantEmoteGroup(row.nameValue, mouseButton == "RightButton" and -1 or 1)
            end)
            row.group:SetPoint("LEFT", 246, 0)
            row.group:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.group:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                local group = Ploty:GetParticipantEmoteGroup(row.nameValue)
                    GameTooltip:AddLine(group and group.name or "Keine Gruppe")
                if Ploty:CanEditOfficialOrder() then
                    GameTooltip:AddLine("Linksklick: nächste · Rechtsklick: vorherige", 0.75, 0.75, 0.82, true)
                end
                GameTooltip:Show()
            end)
            row.group:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            row.active = createButton(row, "Aktiv", 54, 23, function()
                Ploty:SetOfficialEmoteIndex(row.index, true)
            end)
            row.active:SetPoint("RIGHT", -236, 0)

            row.up = createButton(row, "Hoch", 48, 23, function()
                Ploty:MoveEmoteParticipant(row.index, -1)
            end)
            row.up:SetPoint("RIGHT", -184, 0)

            row.down = createButton(row, "Runter", 58, 23, function()
                Ploty:MoveEmoteParticipant(row.index, 1)
            end)
            row.down:SetPoint("RIGHT", -122, 0)

            row.remove = createButton(row, "Entfernen", 75, 23, function()
                Ploty:RemoveEmoteParticipant(row.index)
            end)
            row.remove:SetPoint("RIGHT", -42, 0)

            self.emoteRows[index] = row
        end

        row.index = index
        row.nameValue = name
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -contentHeight)
        row:SetPoint("RIGHT", 0, 0)
        contentHeight = contentHeight + rowHeight
        row.number:SetText(index .. ".")
        row.name:SetText(name)
        row.name:SetFontObject("GameFontHighlight")

        local status = self:GetParticipantStatus(name)
        row.status:SetText(self:GetStatusColor(status) .. self:GetStatusLabel(status) .. "|r")
        local groupColor = group and self:GetEmoteGroupColor(group.colorKey) or nil
        row.group:SetText(group and group.name or "Keine Gruppe")
        if groupColor then
            row.group:SetBackdropColor(groupColor.r * 0.24, groupColor.g * 0.24, groupColor.b * 0.24, 0.96)
            row.group:SetBackdropBorderColor(groupColor.r, groupColor.g, groupColor.b, 0.95)
        else
            row.group:SetBackdropColor(0.055, 0.052, 0.065, 0.96)
            row.group:SetBackdropBorderColor(0.22, 0.20, 0.28, 0.95)
        end
        local groupFont = row.group:GetFontString()
        if groupFont then
            if groupColor then
                groupFont:SetTextColor(groupColor.r, groupColor.g, groupColor.b, 1)
            else
                groupFont:SetTextColor(0.72, 0.70, 0.76, 1)
            end
        end

        if isActive then
            row:SetBackdropColor(0.18, 0.125, 0.025, 0.92)
            row:SetBackdropBorderColor(1.00, 0.72, 0.16, 0.95)
            row.name:SetTextColor(1.00, 0.82, 0.25, 1)
        else
            row:SetBackdropColor(0.08, 0.08, 0.11, 0.88)
            row:SetBackdropBorderColor(0.22, 0.20, 0.28, 0.95)
            if groupColor then
                row.name:SetTextColor(groupColor.r, groupColor.g, groupColor.b, 1)
            else
                row.name:SetTextColor(1, 1, 1, 1)
            end
        end

        if canEdit or samePlayerName(name, Ploty.GetUnitFullName("player")) then
            row.status:Enable()
        else
            row.status:Disable()
        end
        if status == "ABSENT" then
            row.status:SetBackdropColor(0.20, 0.035, 0.035, 0.96)
            row.status:SetBackdropBorderColor(0.95, 0.24, 0.22, 0.95)
        else
            row.status:SetBackdropColor(0.035, 0.16, 0.065, 0.96)
            row.status:SetBackdropBorderColor(0.25, 0.85, 0.35, 0.95)
        end
        local controls = { row.active, row.up, row.down, row.remove }
        for _, control in ipairs(controls) do
            if self.isParticipantBuild then
                control:Hide()
            else
                control:Show()
                if canEdit then
                    control:Enable()
                else
                    control:Disable()
                end
            end
        end
        row.status:ClearAllPoints()
        row.group:ClearAllPoints()
        row.group:EnableMouse(canEdit)
        if self.isParticipantBuild then
            row.name:SetWidth(math.max(250, contentWidth - 235))
            row.group:SetWidth(110)
            row.group:SetPoint("RIGHT", -86, 0)
            row.status:SetPoint("RIGHT", -10, 0)
        else
            row.name:SetWidth(130)
            row.group:SetWidth(78)
            row.status:SetPoint("LEFT", 168, 0)
            row.group:SetPoint("LEFT", 246, 0)
        end
        if self.CanMoveEmoteParticipantWithinGroup and not self:CanMoveEmoteParticipantWithinGroup(index, -1) then
            row.up:Disable()
        end
        if self.CanMoveEmoteParticipantWithinGroup and not self:CanMoveEmoteParticipantWithinGroup(index, 1) then
            row.down:Disable()
        end
        if isActive then
            row.active:Disable()
        end
        row:Show()
    end

    for index = #order + 1, #self.emoteRows do
        self.emoteRows[index]:Hide()
    end
    for index = headerCount + 1, #(self.emoteGroupHeaders or {}) do
        self.emoteGroupHeaders[index]:Hide()
    end

    self.emoteListContent:SetHeight(math.max(150, contentHeight))
    updateScrollBarVisibility(self.emoteListScroll, self.emoteListContent)

    if #order == 0 then
        if not self.emptyEmoteLabel then
            local label = self.emoteListContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", 12, -12)
            label:SetText("Noch keine Teilnehmer eingetragen.")
            self.emptyEmoteLabel = label
        end
        self.emptyEmoteLabel:Show()
    elseif self.emptyEmoteLabel then
        self.emptyEmoteLabel:Hide()
    end

    self:UpdateEmoteSyncStatus()
    self:RefreshGlobalTurnBar()
end

function Ploty:RefreshClientVersions()
    if not self.clientVersionContent then
        return
    end

    local rows = self:GetClientVersionRows()
    local rowHeight = 22
    local width = math.max(220, self.clientVersionScroll:GetWidth() - 4)
    self.clientVersionContent:SetWidth(width)

    for index, data in ipairs(rows) do
        local row = self.clientVersionRows[index]
        if not row then
            row = self.clientVersionContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetJustifyH("LEFT")
            self.clientVersionRows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -((index - 1) * rowHeight))
        row:SetWidth(width - 4)

        if not data.version then
            row:SetText(data.name .. "  |cff888888kein Ploty erkannt|r")
        elseif data.outdated then
            row:SetText(data.name .. "  |cffff6666v" .. data.version .. " veraltet|r")
        else
            row:SetText(data.name .. "  |cff55ff55v" .. data.version .. "|r")
        end
        row:Show()
    end

    for index = #rows + 1, #self.clientVersionRows do
        self.clientVersionRows[index]:Hide()
    end
    self.clientVersionContent:SetHeight(math.max(70, #rows * rowHeight))
    updateScrollBarVisibility(self.clientVersionScroll, self.clientVersionContent)

    if self.clientVersionWarning then
        if self:HasOutdatedClients() then
            self.clientVersionWarning:SetText("|cffff6666Mindestens ein Client verwendet eine ältere Ploty-Version.|r")
        else
            self.clientVersionWarning:SetText("Versionserkennung aktualisiert sich beim Gruppenbeitritt.")
        end
    end
end

function Ploty:RefreshEmoteChannelChecks()
    if not self.emoteChannelChecks then
        return
    end
    local selected = self:GetEmoteChannel()
    for channel, check in pairs(self.emoteChannelChecks) do
        check:SetChecked(channel == selected)
        if channel == "RAID" and not IsInRaid() then
            check:Disable()
        elseif channel == "PARTY" and not IsInGroup() then
            check:Disable()
        else
            check:Enable()
        end
    end
end

function Ploty:RefreshWritingCheck(currentIssues)
    if not self.writingCheckCheck then
        return
    end

    local enabled = self:IsWritingCheckEnabled()
    local issues = enabled and (currentIssues or self:GetCurrentWritingIssues()) or {}
    self.currentWritingIssues = issues
    self.writingCheckCheck:SetChecked(enabled)

    if not enabled then
        self.writingCheckCheck.label:SetText("Schreibprüfung aus")
        self.writingCheckCheck.label:SetTextColor(0.72, 0.70, 0.76, 1)
    elseif #issues == 0 then
        self.writingCheckCheck.label:SetText("Text geprüft")
        self.writingCheckCheck.label:SetTextColor(0.42, 1.00, 0.52, 1)
    else
        self.writingCheckCheck.label:SetText(#issues .. " Schreibfehler")
        self.writingCheckCheck.label:SetTextColor(1.00, 0.38, 0.38, 1)
    end
end

function Ploty:RefreshEmoteTextDraft()
    if not self.emoteTextBox or not self.db.emoteText then
        return
    end

    local allowLong = self:IsLongEmoteTextEnabled()
    if self.emoteTextBox.SetMaxLetters then
        self.emoteTextBox:SetMaxLetters(allowLong and 0 or 1020)
    end

    local draft = self:SetEmoteDraft(self.db.emoteText.draft or "")
    if self.emoteTextBox:GetText() ~= draft then
        self.isRefreshingEmoteDraft = true
        self.emoteTextBox:SetText(draft)
        self.emoteTextBox:SetCursorPosition(#draft)
        self.isRefreshingEmoteDraft = false
    end

    self.clearEmoteAfterSendCheck:SetChecked(self.db.emoteText.clearAfterSend and true or false)
    self:RefreshEmoteChannelChecks()
    self:RefreshWritingCheck()
end

function Ploty:UpdateEmoteTextState()
    if not self.db.emoteText or not self.emoteTextCounter then
        return
    end

    local message, characterCount, chunks = self:GetEmoteTextInfo()
    local maximumCharacters, maximumBlocks = self:GetEmoteLimits()
    local allowLong = self:IsLongEmoteTextEnabled()
    local blockCount = #chunks
    local selectedChannel = self:GetEmoteChannel()
    local channelAvailable = self:IsEmoteChannelAvailable(selectedChannel)
    local slashAllowed = self:IsSlashEmoteAllowed(message, selectedChannel)
    local slashPayload = self:GetSlashEmotePayload(message)
    local hasSendableText = characterCount > 0 and (slashPayload == nil or slashPayload ~= "")
    local isCurrent = self:IsPlayerCurrentEmoter(Ploty.GetUnitFullName("player"))
    local valid = isCurrent and hasSendableText and blockCount > 0 and channelAvailable and slashAllowed and
        (allowLong or (characterCount <= maximumCharacters and blockCount <= maximumBlocks))

    self:RefreshEmoteChannelChecks()
    local writingIssues = self:IsWritingCheckEnabled() and self:GetCurrentWritingIssues() or {}
    self.emoteInlineColorText:SetText(self:GetInlineRpOverlay(writingIssues))
    self:RefreshWritingCheck(writingIssues)

    if self.longTextRequestButton then
        if allowLong then
            self.longTextRequestButton:SetText("Mehr Text freigegeben")
            self.longTextRequestButton:Disable()
            self.longTextApprovalLabel:SetText("|cff55ff55Gilt nur für diesen Zug.|r")
        elseif self.longTextRequestPending then
            self.longTextRequestButton:SetText("Freigabe angefragt")
            self.longTextRequestButton:Disable()
            self.longTextApprovalLabel:SetText("|cffffcc66Wartet auf die Plotleitung.|r")
        elseif not isCurrent then
            self.longTextRequestButton:SetText("Mehr Text anfragen")
            self.longTextRequestButton:Disable()
            self.longTextApprovalLabel:SetText("Nur während deines Emote-Zugs verfügbar.")
        elseif self:HasLeaderPrivileges() then
            self.longTextRequestButton:SetText("Mehr Text freigeben")
            self.longTextRequestButton:Enable()
            self.longTextApprovalLabel:SetText("Freigabe gilt nur für diesen Zug.")
        else
            self.longTextRequestButton:SetText("Mehr Text anfragen")
            self.longTextRequestButton:Enable()
            self.longTextApprovalLabel:SetText("Mehr als 1020 Zeichen benötigen eine Freigabe.")
        end
        if not slashAllowed then
            self.longTextApprovalLabel:SetText("|cffff5555/me ist nur mit Say möglich. Wähle Say oder entferne /me.|r")
        elseif not self:IsPlotActive() then
            self.longTextApprovalLabel:SetText("Starte zuerst den Plot über die Übersicht.")
        end
    end

    if allowLong then
        self.emoteTextCounter:SetText(characterCount .. " Zeichen · " .. blockCount .. " Blöcke")
    else
        local text = characterCount .. "/" .. maximumCharacters .. " Zeichen · " .. blockCount .. "/" .. maximumBlocks .. " Blöcke"
        if characterCount >= maximumCharacters or blockCount > maximumBlocks then
            self.emoteTextCounter:SetText("|cffff5555" .. text .. "|r")
        else
            self.emoteTextCounter:SetText(text)
        end
    end

    if valid then
        self.sendEmoteTextButton:Enable()
    else
        self.sendEmoteTextButton:Disable()
    end
    if self.passEmoteTurnButton then
        if isCurrent then
            self.passEmoteTurnButton:Enable()
        else
            self.passEmoteTurnButton:Disable()
        end
    end
    if (self.db.emoteText.draft or "") ~= "" then
        self.clearEmoteTextButton:Enable()
    else
        self.clearEmoteTextButton:Disable()
    end

    if self.resendLastEmoteButton then
        if isCurrent and tostring(self.db.emoteText.lastSentText or "") ~= "" and channelAvailable and
            self:IsSlashEmoteAllowed(self.db.emoteText.lastSentText, selectedChannel)
        then
            self.resendLastEmoteButton:Enable()
        else
            self.resendLastEmoteButton:Disable()
        end
    end
end

function Ploty:InitializeUI()
    self:UpdateAccessMode(false)
    self:CreateMainFrame()
    self:ApplyAccessModeToUI()
    self:RefreshRollRange()
    self:RefreshLastRoll()
    self:RefreshRollRound()
    self:RefreshParticipantRolls()
    self:UpdateGroupStatus()
    self:RefreshEmoteOrder()
    self:UpdateEmoteSyncStatus()
    self:RefreshGlobalTurnBar()
    self:RefreshEmoteTextDraft()
    self:UpdateEmoteTextState()
    self:RefreshClientVersions()
    self:RefreshPlotOverview()
end

function Ploty:ToggleUI()
    if not self.mainFrame then
        self:InitializeUI()
    end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
    end
end

function Ploty:ResetPositions()
    self.db.positions.main = nil
    self.db.settings.minimapAngle = 225
    self.db.settings.windowWidth = UI_STYLE.windowWidth
    self.db.settings.windowHeight = UI_STYLE.windowHeight
    self.db.settings.uiLayoutVersion = 2

    if self.mainFrame then
        self.mainFrame:SetSize(UI_STYLE.windowWidth, UI_STYLE.windowHeight)
        restoreFramePosition(self.mainFrame, "main")
    end
    if self.UpdateMinimapButtonPosition then
        self:UpdateMinimapButtonPosition()
    end
end
