JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572
local ROW_HEIGHT = 24

local function CreateSectionHeading(parent, text)
    local heading = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText(text)
    UI.SetColor(heading, UI.COLOR_GOLD)
    return heading
end

local function CreateScrollingList(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width - 24, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 24, height)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

local botRowCount = 0

local function CreateBotRow(parent)
    botRowCount = botRowCount + 1
    local row = CreateFrame("Frame", "JasonWoWAdditionsBotRow" .. botRowCount, parent)
    row:SetSize(PANEL_WIDTH - 24, ROW_HEIGHT)

    local rateMinus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    rateMinus:SetSize(20, 18)
    rateMinus:SetText("-")
    rateMinus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.rateMinus = rateMinus

    local rateValue = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rateValue:SetPoint("RIGHT", rateMinus, "LEFT", -4, 0)
    rateValue:SetWidth(34)
    rateValue:SetJustifyH("CENTER")
    row.rateValue = rateValue

    local ratePlus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    ratePlus:SetSize(20, 18)
    ratePlus:SetText("+")
    ratePlus:SetPoint("RIGHT", rateValue, "LEFT", -4, 0)
    row.ratePlus = ratePlus

    local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeButton:SetSize(60, 18)
    removeButton:SetText("Remove")
    removeButton:SetPoint("RIGHT", ratePlus, "LEFT", -10, 0)
    row.removeButton = removeButton

    local status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("RIGHT", removeButton, "LEFT", -10, 0)
    status:SetWidth(70)
    status:SetJustifyH("RIGHT")
    row.status = status

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", 0, 0)
    text:SetPoint("RIGHT", status, "LEFT", -8, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    return row
end

function UI:CreateBotsPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 420)
    panel:Hide()

    -- Takeover / AFK autopilot toggle
    local takeoverHeading = CreateSectionHeading(panel, "AFK AUTOPILOT")
    takeoverHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    local takeoverInset = UI.CreateInsetPanel(panel, PANEL_WIDTH, 44)
    takeoverInset:SetPoint("TOPLEFT", takeoverHeading, "BOTTOMLEFT", 0, -6)

    local takeoverStatus = takeoverInset:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    takeoverStatus:SetPoint("LEFT", takeoverInset, "LEFT", 10, 0)
    self.takeoverStatusText = takeoverStatus

    local takeoverButton = CreateFrame("Button", nil, takeoverInset, "UIPanelButtonTemplate")
    takeoverButton:SetSize(110, 22)
    takeoverButton:SetPoint("RIGHT", takeoverInset, "RIGHT", -10, 0)
    takeoverButton:SetScript("OnClick", function()
        JWA:RequestToggleTakeover()
    end)
    self.takeoverButton = takeoverButton

    -- Altparty bots
    local altPartyHeading = CreateSectionHeading(panel, "ALTPARTY BOTS")
    altPartyHeading:SetPoint("TOPLEFT", takeoverInset, "BOTTOMLEFT", 0, -14)

    local addNameBox = CreateFrame("EditBox", "JasonWoWAdditionsAltPartyNameBox", panel, "InputBoxTemplate")
    addNameBox:SetSize(140, 20)
    addNameBox:SetPoint("TOPRIGHT", altPartyHeading, "TOPRIGHT", -84, 4)
    addNameBox:SetAutoFocus(false)
    addNameBox:SetMaxLetters(24)
    self.altPartyNameBox = addNameBox

    local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addButton:SetSize(60, 20)
    addButton:SetPoint("LEFT", addNameBox, "RIGHT", 6, 0)
    addButton:SetText("Add")
    local function SubmitAdd()
        local name = addNameBox:GetText()
        if name and name ~= "" then
            JWA:RequestAltPartyAdd(name)
            addNameBox:SetText("")
            addNameBox:ClearFocus()
        end
    end
    addButton:SetScript("OnClick", SubmitAdd)
    addNameBox:SetScript("OnEnterPressed", SubmitAdd)
    addNameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local offButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    offButton:SetSize(50, 20)
    offButton:SetPoint("LEFT", addButton, "RIGHT", 6, 0)
    offButton:SetText("Off")
    offButton:SetScript("OnClick", function()
        JWA:RequestAltPartyOff()
    end)

    local scrollFrame, scrollContent = CreateScrollingList(panel, PANEL_WIDTH, 250)
    scrollFrame:SetPoint("TOPLEFT", altPartyHeading, "BOTTOMLEFT", 0, -30)
    self.botsScroll = scrollFrame
    self.botsContent = scrollContent
    self.botsRows = {}

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(PANEL_WIDTH)
    hint:SetJustifyH("LEFT")
    hint:SetText("Type a same-account character's name and click Add to bring it along as a bot. " ..
        "\"Off\" logs out every altparty bot. Each bot's rate is its own campaign catch-up multiplier.")
    UI.SetColor(hint, UI.COLOR_GREY)

    return panel
end

function UI:RefreshBots()
    if not self.takeoverStatusText then
        return
    end

    local status = JWA.state.status
    local active = JWA:IsTakeoverActive()

    if active then
        self.takeoverStatusText:SetText("AFK autopilot is |cff20e020ACTIVE|r - the bot AI is playing your character.")
        self.takeoverButton:SetText("Cancel Takeover")
    else
        self.takeoverStatusText:SetText("AFK autopilot is |cff999999off|r.")
        self.takeoverButton:SetText("Enable Takeover")
    end

    local rowIndex = 0
    local function EnsureRow()
        rowIndex = rowIndex + 1
        local row = self.botsRows[rowIndex]
        if not row then
            row = CreateBotRow(self.botsContent)
            self.botsRows[rowIndex] = row
        end
        row:SetPoint("TOPLEFT", self.botsContent, "TOPLEFT", 4, -((rowIndex - 1) * ROW_HEIGHT))
        row:Show()
        return row
    end

    local bots = JWA:GetOrderedBots()
    if #bots == 0 then
        local row = EnsureRow()
        row.text:SetText("No altparty bots. Add one above.")
        UI.SetColor(row.text, UI.COLOR_GREY)
        row.status:SetText("")
        row.removeButton:Hide()
        row.rateMinus:Hide()
        row.ratePlus:Hide()
        row.rateValue:SetText("")
    else
        for _, bot in ipairs(bots) do
            local row = EnsureRow()
            row.text:SetText(string.format("%s (level %d)", bot.name, bot.level))
            UI.SetColor(row.text, bot.inGroup and UI.COLOR_WHITE or UI.COLOR_GREY)

            row.status:SetText(bot.inGroup and "|cff20e020in group|r" or "|cff999999not in group|r")

            row.removeButton:Show()
            -- Removing a single altparty bot isn't exposed server-side (.altparty off logs
            -- out all of them) - Remove logs the whole altparty out, same as the header Off
            -- button. Kept as its own per-row button since that's the natural place a
            -- player looks for it.
            row.removeButton:SetScript("OnClick", function()
                JWA:RequestAltPartyOff()
            end)

            row.rateMinus:Show()
            row.ratePlus:Show()
            row.rateValue:SetText(string.format("%dx", bot.catchupRate))
            row.rateMinus:SetScript("OnClick", function()
                JWA:RequestBotXPRateChange(bot.name, bot.catchupRate - 1)
            end)
            row.ratePlus:SetScript("OnClick", function()
                JWA:RequestBotXPRateChange(bot.name, bot.catchupRate + 1)
            end)
            if status then
                if bot.catchupRate > status.minRate then row.rateMinus:Enable() else row.rateMinus:Disable() end
                if bot.catchupRate < status.maxRate then row.ratePlus:Enable() else row.ratePlus:Disable() end
            end
        end
    end

    for index = rowIndex + 1, #self.botsRows do
        self.botsRows[index]:Hide()
    end

    self.botsContent:SetHeight(math.max(1, rowIndex * ROW_HEIGHT))
end
