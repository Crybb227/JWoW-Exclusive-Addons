JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572
local ROW_HEIGHT = 34

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(parent, text, x, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetPoint("LEFT", parent, "LEFT", x, 0)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function CreateBotRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_WIDTH - 26, ROW_HEIGHT)
    row.text = Label(row, "", 8, -5, 170)
    row.status = Label(row, "", 184, -10, 92)
    row.rateValue = Label(row, "", 284, -10, 38)
    row.ratePlus = Button(row, "+", 324, 24)
    row.rateMinus = Button(row, "-", 352, 24)
    row.addButton = Button(row, "Add to group", 392, 138)
    return row
end

function UI:CreateBotsPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 420)
    panel:Hide()

    local takeoverInset = UI.CreateInsetPanel(panel, PANEL_WIDTH, 76)
    takeoverInset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    self.takeoverStatusText = Label(takeoverInset, "Takeover", 10, -10, 390)
    self.takeoverActivityText = Label(takeoverInset, "", 10, -32, 390)
    self.takeoverButton = Button(takeoverInset, "Enable Takeover", 430, 132, function()
        JWA:RequestToggleTakeover()
    end)

    local toolbar = CreateFrame("Frame", nil, panel)
    toolbar:SetSize(PANEL_WIDTH, 28)
    toolbar:SetPoint("TOPLEFT", takeoverInset, "BOTTOMLEFT", 0, -10)
    Label(toolbar, "AVAILABLE ACCOUNT ALTS", 8, -7, 350)
    Button(toolbar, "Dismiss all bots", 430, 132, function() JWA:RequestAltPartyOff() end)

    local headers = CreateFrame("Frame", nil, panel)
    headers:SetSize(PANEL_WIDTH, 22)
    headers:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    Label(headers, "Character / level", 8, 0, 170)
    Label(headers, "Status", 184, 0, 92)
    Label(headers, "XP rate", 284, 0, 92)
    Label(headers, "Group", 392, 0, 138)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetSize(PANEL_WIDTH - 26, 238)
    scroll:SetPoint("TOPLEFT", headers, "BOTTOMLEFT", 0, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_WIDTH - 26, 238)
    scroll:SetScrollChild(content)
    self.botsScroll, self.botsContent, self.botsRows = scroll, content, {}

    local hint = Label(panel, "XP rate is the saved campaign catch-up multiplier; eligibility and caps still apply. " ..
        "Add to group summons an offline alt. Dismiss all bots logs out your entire altparty.", 0, -390, PANEL_WIDTH)
    UI.SetColor(hint, UI.COLOR_GREY)
    return panel
end

function UI:RefreshBots()
    if not self.takeoverStatusText then return end
    local status = JWA.state.status
    local active = JWA:IsTakeoverActive()
    self.takeoverStatusText:SetText(active and "Takeover: |cff20e020ACTIVE|r" or "Takeover: off")
    self.takeoverActivityText:SetText(JWA:GetTakeoverActivity())
    self.takeoverButton:SetText(active and "Cancel Takeover" or "Enable Takeover")
    if status then self.takeoverButton:Enable() else self.takeoverButton:Disable() end

    local bots = JWA:GetOrderedBots()
    for index = 1, math.max(1, #bots) do
        local row = self.botsRows[index]
        if not row then
            row = CreateBotRow(self.botsContent)
            self.botsRows[index] = row
        end
        row:SetPoint("TOPLEFT", self.botsContent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
        row:Show()
        local bot = bots[index]
        if not bot then
            row.text:SetText(status and "No account alts received." or "Loading account alts...")
            row.status:SetText("")
            row.rateValue:SetText("")
            row.ratePlus:Hide()
            row.rateMinus:Hide()
            row.addButton:Hide()
        else
            row.text:SetText(string.format("%s\n|cff999999Level %d|r", bot.name, bot.level))
            row.status:SetText(bot.inGroup and "|cff20e020In group|r"
                or bot.controlled and "Summoned" or bot.online and "Online" or "Available")
            row.rateValue:SetText(string.format("%dx", bot.catchupRate))
            row.ratePlus:Show()
            row.rateMinus:Show()
            row.addButton:Show()
            row.addButton:SetText(bot.inGroup and "In group" or "Add to group")
            row.addButton:SetScript("OnClick", function() JWA:RequestAltPartyAdd(bot.name, bot.controlled) end)
            if bot.inGroup or (bot.online and not bot.controlled) then
                row.addButton:Disable()
            else
                row.addButton:Enable()
            end
            row.ratePlus:SetScript("OnClick", function()
                JWA:RequestBotXPRateChange(bot.name, bot.catchupRate + 1)
            end)
            row.rateMinus:SetScript("OnClick", function()
                JWA:RequestBotXPRateChange(bot.name, bot.catchupRate - 1)
            end)
            local editable = status and status.rateCmdEnabled and (not bot.online or bot.controlled)
            if editable and bot.catchupRate < status.maxRate then row.ratePlus:Enable()
            else row.ratePlus:Disable() end
            if editable and bot.catchupRate > status.minRate then row.rateMinus:Enable()
            else row.rateMinus:Disable() end
        end
    end
    for index = math.max(1, #bots) + 1, #self.botsRows do self.botsRows[index]:Hide() end
    self.botsContent:SetHeight(math.max(1, #bots) * ROW_HEIGHT)
end
