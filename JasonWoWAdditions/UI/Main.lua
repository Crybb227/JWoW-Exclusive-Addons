JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local WINDOW_WIDTH = 620
local WINDOW_HEIGHT = 580

local COLOR_GOLD = { 1, 0.82, 0 }
local COLOR_GREEN = { 0.1, 0.9, 0.1 }
local COLOR_GREY = { 0.6, 0.6, 0.6 }
local COLOR_RED = { 0.9, 0.2, 0.2 }
local COLOR_WHITE = { 0.9, 0.9, 0.9 }

UI.COLOR_GOLD = COLOR_GOLD
UI.COLOR_GREEN = COLOR_GREEN
UI.COLOR_GREY = COLOR_GREY
UI.COLOR_RED = COLOR_RED
UI.COLOR_WHITE = COLOR_WHITE

-- Shared bar palette: each entry is { r, g, b } used as the StatusBar fill color.
-- Picked to read clearly against the dark inset backdrop in both bar and text form.
UI.BAR_COLOR_CAMPAIGN = { 0.98, 0.82, 0.15 }
UI.BAR_COLOR_WAR_EFFORT = { 0.35, 0.70, 0.95 }
UI.BAR_COLOR_XP = { 0.55, 0.85, 0.30 }
UI.BAR_COLOR_LEVEL = { 0.75, 0.55, 0.95 }
UI.BAR_COLOR_NEUTRAL = { 0.5, 0.5, 0.5 }

local function SetColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end
UI.SetColor = SetColor

function UI.CreateInsetPanel(parent, width, height)
    local inset = CreateFrame("Frame", nil, parent)
    inset:SetWidth(width)
    inset:SetHeight(height)
    inset:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    inset:SetBackdropColor(1, 1, 1, 1)
    inset:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
    return inset
end

-- A labeled StatusBar: title + percent on top, fill beneath, optional caption under that.
-- Used everywhere a "fancy bar" is wanted (Overview at-a-glance, Campaign chapter progress).
local fancyBarCount = 0

function UI:CreateFancyBar(parent, width, color)
    fancyBarCount = fancyBarCount + 1
    local name = "JasonWoWAdditionsFancyBar" .. fancyBarCount

    local container = CreateFrame("Frame", name, parent)
    container:SetSize(width, 40)

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    label:SetJustifyH("LEFT")

    local percentText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    percentText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -1)
    percentText:SetJustifyH("RIGHT")

    local track = CreateFrame("StatusBar", name .. "Bar", container)
    track:SetSize(width, 14)
    track:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    track:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    track:SetMinMaxValues(0, 1)
    track:SetValue(0)
    local c = color or UI.BAR_COLOR_NEUTRAL
    track:SetStatusBarColor(c[1], c[2], c[3])

    local trackBackground = track:CreateTexture(nil, "BACKGROUND")
    trackBackground:SetAllPoints(track)
    trackBackground:SetTexture(0.08, 0.08, 0.08, 0.9)

    track:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    track:SetBackdropBorderColor(0, 0, 0, 0.8)

    local barText = track:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER", track, "CENTER", 0, 0)

    local caption = container:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    caption:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -32)
    caption:SetJustifyH("LEFT")
    caption:SetWidth(width)

    container.label = label
    container.percentText = percentText
    container.track = track
    container.barText = barText
    container.caption = caption

    -- fraction in [0, 1]; barLabel overrides the centered "NN%" text (e.g. "180 / 500").
    function container:SetProgress(fraction, barLabel)
        fraction = math.max(0, math.min(1, fraction or 0))
        self.track:SetValue(fraction)
        self.percentText:SetText(string.format("%d%%", math.floor(fraction * 100 + 0.5)))
        self.barText:SetText(barLabel or string.format("%d%%", math.floor(fraction * 100 + 0.5)))
    end

    function container:SetBarColor(newColor)
        self.track:SetStatusBarColor(newColor[1], newColor[2], newColor[3])
    end

    return container
end

function UI:SavePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint()
    JWA.db.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

function UI:RestorePosition()
    local window = JWA.db and JWA.db.window
    if not window then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(window.point or "CENTER", UIParent, window.relativePoint or "CENTER",
        window.x or 0, window.y or 0)
end

-- Flat "pill" tab button (own backdrop, no Blizzard tab-template notches) so a row of
-- five tabs stays clean and legible instead of the stock overlapping tab-corner look.
local tabButtonCount = 0

function UI:CreateTabButton(label, onClick)
    tabButtonCount = tabButtonCount + 1
    local button = CreateFrame("Button", "JasonWoWAdditionsTab" .. tabButtonCount, self.frame)
    button:SetHeight(22)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(label)
    button.text = text

    local textWidth = text:GetStringWidth()
    button:SetWidth(textWidth + 22)

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            self:SetBackdropColor(1, 1, 1, 0.08)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end)

    function button:SetSelected(selected)
        self.selected = selected
        if selected then
            self:SetBackdropColor(1, 0.82, 0, 0.18)
            self:SetBackdropBorderColor(1, 0.82, 0, 0.6)
            SetColor(self.text, COLOR_GOLD)
        else
            self:SetBackdropColor(0, 0, 0, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
            SetColor(self.text, COLOR_WHITE)
        end
    end

    button:SetScript("OnClick", onClick)
    button:SetSelected(false)
    return button
end

-- Ordered tab definitions: key -> { label, panelField }. Adding a tab here plus a
-- Create<Name>Panel/Refresh<Name> pair in its own UI/<Name>.lua file is enough to wire it in.
UI.TAB_DEFS = {
    { key = "overview", label = "Overview", panelField = "overviewPanel" },
    { key = "campaign", label = "Campaign", panelField = "campaignPanel" },
    { key = "bots", label = "Bots", panelField = "botsPanel" },
    { key = "nemesis", label = "Nemesis", panelField = "nemesisPanel" },
    { key = "tracking", label = "Tracking", panelField = "trackingPanel" },
    { key = "stats", label = "Stats", panelField = "statsPanel" },
}

function UI:SelectTab(tabKey)
    local found = false
    for _, def in ipairs(UI.TAB_DEFS) do
        if def.key == tabKey then
            found = true
            break
        end
    end
    if not found then
        tabKey = "overview"
    end

    JWA.db.lastTab = tabKey

    for _, def in ipairs(UI.TAB_DEFS) do
        local panel = self[def.panelField]
        local button = self.tabButtons[def.key]
        if def.key == tabKey then
            if panel then panel:Show() end
            if button then button:SetSelected(true) end
        else
            if panel then panel:Hide() end
            if button then button:SetSelected(false) end
        end
    end
end

function UI:InstallWindowMouseHandlers(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function(self)
        self.jwaDragged = false
    end)
    frame:SetScript("OnDragStart", function(self)
        self.jwaDragged = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if self.jwaDragged then return end
        if JWA.db.tinyMode then
            if button == "RightButton" then JWA:ToggleTinyMode()
            elseif button == "LeftButton" then JWA:RequestToggleTakeover() end
        end
    end)
end

function UI:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "JasonWoWAdditionsFrame", UIParent)
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:Hide()
    tinsert(UISpecialFrames, "JasonWoWAdditionsFrame")

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    self:InstallWindowMouseHandlers(frame)
    frame:SetScript("OnEnter", function(self)
        if not JWA.db.tinyMode then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("JasonWoWAdditions")
        GameTooltip:AddLine("Left-click to toggle AFK takeover; drag to move", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click to expand the window", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.frame = frame
    UI:RestorePosition()
    frame:SetScale(JWA.db.uiScale or 1.0)

    -- Title bar
    local titleBackground = frame:CreateTexture(nil, "ARTWORK")
    titleBackground:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBackground:SetSize(320, 64)
    titleBackground:SetPoint("TOP", frame, "TOP", 0, 12)
    self.titleBackground = titleBackground

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -3)
    title:SetText("Campaign Progression")
    SetColor(title, COLOR_GOLD)
    self.title = title

    local titleHitArea = CreateFrame("Frame", nil, frame)
    titleHitArea:SetSize(320, 28)
    titleHitArea:SetPoint("TOP", frame, "TOP", 0, 8)
    titleHitArea:EnableMouse(true)
    titleHitArea:RegisterForDrag("LeftButton")
    titleHitArea:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleHitArea:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        UI:SavePosition()
    end)
    titleHitArea:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then JWA:ToggleTinyMode() end
    end)
    self.titleHitArea = titleHitArea

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    self.closeButton = closeButton

    -- Header: phase / cap / character
    local phaseText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    phaseText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -46)
    self.phaseText = phaseText

    local capText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    capText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -46)
    self.capText = capText

    local charText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    charText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -64)
    self.charText = charText

    local cappedText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cappedText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -64)
    self.cappedText = cappedText

    -- Tabs: one flat pill button per entry in UI.TAB_DEFS, laid out left to right.
    self.tabButtons = {}
    local previousTab
    for _, def in ipairs(UI.TAB_DEFS) do
        local tabKey = def.key
        local button = self:CreateTabButton(def.label, function() UI:SelectTab(tabKey) end)
        if previousTab then
            button:SetPoint("LEFT", previousTab, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -78)
        end
        self.tabButtons[tabKey] = button
        previousTab = button
    end
    local contentAnchorTop = self.tabButtons.overview

    -- Refresh + status line
    local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshButton:SetSize(90, 22)
    refreshButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 16)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        JWA:RequestStatus(true)
        JWA:RequestTrackingStatus()
    end)
    self.refreshButton = refreshButton

    local tinyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tinyButton:SetSize(50, 22)
    tinyButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    tinyButton:SetText("Tiny")
    tinyButton:SetScript("OnClick", function() JWA:ToggleTinyMode() end)
    self.tinyButton = tinyButton

    local statusLine = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusLine:SetPoint("RIGHT", refreshButton, "LEFT", -10, 0)
    statusLine:SetWidth(300)
    statusLine:SetJustifyH("RIGHT")
    self.statusLine = statusLine

    -- Content panels (built by Overview.lua / Campaign.lua / Bots.lua / Nemesis.lua / Tracking.lua / Stats.lua)
    self.overviewPanel = self:CreateOverviewPanel(frame, contentAnchorTop)
    self.campaignPanel = self:CreateCampaignPanel(frame, contentAnchorTop)
    self.botsPanel = self:CreateBotsPanel(frame, contentAnchorTop)
    self.nemesisPanel = self:CreateNemesisPanel(frame, contentAnchorTop)
    self.trackingPanel = self:CreateTrackingPanel(frame, contentAnchorTop)
    self.statsPanel = self:CreateStatsPanel(frame, contentAnchorTop)

    self:CreateTinyBar(frame)

    self:SelectTab(JWA.db.lastTab or "overview")
    self:ApplyTinyMode()

    self:RefreshAll()
end

-- Tiny mode: collapses the SAME window (not a separate frame) to a single-line bar showing
-- just AFK-autopilot state, altparty bot count, and the player's own XP rate - the fields a
-- player wants to glance at without the full window open. Matches the tiny-mode convention
-- already used by this account's DungeonClear addon (one frame, single toggle button,
-- right-click-anywhere-on-the-bar to expand, auto-width, position/mode saved to SavedVariables)
-- rather than inventing a second frame/pattern.
local TINY_HEIGHT = 26

function UI:CreateTinyBar(frame)
    local dot = frame:CreateTexture(nil, "OVERLAY")
    dot:SetSize(14, 14)
    dot:SetPoint("LEFT", frame, "LEFT", 10, 0)
    dot:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
    dot:Hide()
    self.tinyIndicator = dot

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    text:Hide()
    self.tinyText = text
end

function UI:RefreshTinyBar()
    if not self.tinyText then
        return
    end

    local status = JWA.state.status
    local active = JWA:IsTakeoverActive()
    local botCount = JWA:GetInGroupBotCount()

    if active then
        self.tinyIndicator:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
    else
        self.tinyIndicator:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
    end

    local afkPart = active and "|cff20e020AFK|r" or "|cff999999AFK off|r"
    if JWA.db.tinyShowActivity and active then
        afkPart = afkPart .. " " .. JWA:GetTakeoverActivity()
    end
    local botsPart = string.format("|cffffd100%d bot%s|r", botCount, botCount == 1 and "" or "s")
    local ratePart = status and string.format("|cff40c0ff%dx|r", status.catchupRate) or "|cff999999--|r"

    self.tinyText:SetText(afkPart .. "  |cff808080|| |r" .. botsPart .. "  |cff808080|| |r" .. ratePart)

    local width = 10 + 14 + 6 + self.tinyText:GetStringWidth() + 14
    self.frame:SetWidth(math.max(150, width))
end

function UI:ApplyTinyMode()
    if not self.frame then
        return
    end

    local tiny = JWA.db.tinyMode

    if tiny then
        self.title:Hide()
        self.titleHitArea:Hide()
        self.titleBackground:Hide()
        self.closeButton:Hide()
        self.phaseText:Hide()
        self.capText:Hide()
        self.charText:Hide()
        self.cappedText:Hide()
        for _, button in pairs(self.tabButtons) do button:Hide() end
        for _, def in ipairs(UI.TAB_DEFS) do
            local panel = self[def.panelField]
            if panel then panel:Hide() end
        end
        self.refreshButton:Hide()
        self.tinyButton:Hide()
        self.statusLine:Hide()

        self.tinyIndicator:Show()
        self.tinyText:Show()

        self.frame:SetHeight(TINY_HEIGHT)
        self:RefreshTinyBar()
    else
        self.tinyIndicator:Hide()
        self.tinyText:Hide()

        self.title:Show()
        self.titleHitArea:Show()
        self.titleBackground:Show()
        self.closeButton:Show()
        self.phaseText:Show()
        self.capText:Show()
        self.charText:Show()
        self.cappedText:Show()
        for _, button in pairs(self.tabButtons) do button:Show() end
        self.refreshButton:Show()
        self.tinyButton:Show()
        self.statusLine:Show()

        self.frame:SetHeight(WINDOW_HEIGHT)
        self.frame:SetWidth(WINDOW_WIDTH)
        self:SelectTab(JWA.db.lastTab or "overview")
    end
end

function UI:RefreshStatus()
    if not self.frame then
        return
    end

    local state = JWA.state
    local now = JWA:GetNow()

    if state.connectionState == "requesting" then
        self.statusLine:SetText("Requesting progression data...")
    elseif state.lastError then
        self.statusLine:SetText("|cffff4040" .. state.lastError .. "|r")
    elseif state.status then
        local age = math.max(0, math.floor(now - (state.lastResponseAt or now)))
        self.statusLine:SetText(string.format("Last updated %ds ago", age))
    else
        self.statusLine:SetText("Progression data unavailable. Click Refresh to try again.")
    end
end

function UI:RefreshAll()
    if not self.frame then
        return
    end

    self:RefreshHeader()
    self:RefreshOverview()
    self:RefreshCampaign()
    self:RefreshBots()
    self:RefreshNemesis()
    self:RefreshTracking()
    self:RefreshStats()
    self:RefreshStatus()

    if JWA.db.tinyMode then
        self:RefreshTinyBar()
    end
end
