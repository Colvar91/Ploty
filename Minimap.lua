local addonName, Ploty = ...

local function getMinimapAngle()
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local minimapX, minimapY = Minimap:GetCenter()

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    return math.deg(math.atan2(cursorY - minimapY, cursorX - minimapX))
end

function Ploty:UpdateMinimapButtonPosition()
    if not self.minimapButton then
        return
    end

    local angle = math.rad(self.db.settings.minimapAngle or 225)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Ploty:InitializeMinimapButton()
    if self.minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "PlotyMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Dice_02")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Ploty:DoD20Roll()
        else
            Ploty:ToggleUI()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            Ploty.db.settings.minimapAngle = getMinimapAngle()
            Ploty:UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(Ploty.displayName or "Ploty")
        GameTooltip:AddLine("Linksklick: Werkzeugfenster", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: nach Aufforderung würfeln", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: Position ändern", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end
