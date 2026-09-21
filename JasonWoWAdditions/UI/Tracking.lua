JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572
local ROW_HEIGHT = 24

JWA.tracking = JWA.tracking or {
    types = {},      -- key -> { key, label, spellId }
    typeOrder = {},
    tracked = {},    -- key -> true
}

local function CreateCheckboxRow(parent, index)
    local row = CreateFrame("CheckButton", "JasonWoWAdditionsTrackingRow" .. index, parent,
        "InterfaceOptionsCheckButtonTemplate")
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -((index - 1) * ROW_HEIGHT))
    row:SetScript("OnClick", function(button)
        local key = button.resourceKey
        if key then
            JWA:RequestToggleTracking(key)
        end
    end)
    return row
end

function UI:CreateTrackingPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 420)
    panel:Hide()

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    heading:SetText("RESOURCE TRACKING")
    UI.SetColor(heading, UI.COLOR_GOLD)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    note:SetWidth(PANEL_WIDTH)
    note:SetJustifyH("LEFT")
    note:SetHeight(28)
    note:SetText("Check any resources you want to track on the minimap at the same time.")
    UI.SetColor(note, UI.COLOR_GREY)

    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 4, -10)
    list:SetSize(PANEL_WIDTH - 8, 200)
    self.trackingList = list
    self.trackingRows = {}

    return panel
end

function UI:RefreshTracking()
    if not self.trackingList then
        return
    end

    local rowIndex = 0

    for _, key in ipairs(JWA.tracking.typeOrder) do
        rowIndex = rowIndex + 1
        local resource = JWA.tracking.types[key]

        local row = self.trackingRows[rowIndex]
        if not row then
            row = CreateCheckboxRow(self.trackingList, rowIndex)
            self.trackingRows[rowIndex] = row
        end

        row.resourceKey = key
        getglobal(row:GetName() .. "Text"):SetText(resource.label)
        row:SetChecked(JWA.tracking.tracked[key] and true or false)
        row:Show()
    end

    for index = rowIndex + 1, #self.trackingRows do
        self.trackingRows[index]:Hide()
    end

    if rowIndex == 0 then
        if not self.trackingEmptyText then
            local emptyText = self.trackingList:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            emptyText:SetPoint("TOPLEFT", self.trackingList, "TOPLEFT", 0, 0)
            UI.SetColor(emptyText, UI.COLOR_GREY)
            self.trackingEmptyText = emptyText
        end
        self.trackingEmptyText:SetText("Tracking data unavailable. Click Refresh to try again.")
        self.trackingEmptyText:Show()
    elseif self.trackingEmptyText then
        self.trackingEmptyText:Hide()
    end
end
