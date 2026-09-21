JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572

local function CreateSectionHeading(parent, text)
    local heading = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText(text)
    UI.SetColor(heading, UI.COLOR_GOLD)
    return heading
end

local function CreateInsetPanel(parent, height)
    return UI.CreateInsetPanel(parent, PANEL_WIDTH, height)
end

function UI:CreateOverviewPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 440)

    local y = 0

    -- Progression phase blurb (below the header, above sections)
    local phaseSummary = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    phaseSummary:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    phaseSummary:SetWidth(PANEL_WIDTH)
    phaseSummary:SetJustifyH("LEFT")
    phaseSummary:SetHeight(28)
    self.phaseSummary = phaseSummary
    y = y - 30

    -- AT A GLANCE: fancy bars for the handful of numbers that matter most, so the
    -- window's first tab reads in a couple seconds instead of requiring scrolling text.
    local glanceHeading = CreateSectionHeading(panel, "AT A GLANCE")
    glanceHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 18

    local glanceInset = CreateInsetPanel(panel, 118)
    glanceInset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 126

    local barWidth = PANEL_WIDTH - 20
    local levelBar = self:CreateFancyBar(glanceInset, barWidth, UI.BAR_COLOR_LEVEL)
    levelBar:SetPoint("TOPLEFT", glanceInset, "TOPLEFT", 10, -8)
    levelBar.label:SetText("Level Progress")
    self.overviewLevelBar = levelBar

    local campaignBar = self:CreateFancyBar(glanceInset, barWidth, UI.BAR_COLOR_CAMPAIGN)
    campaignBar:SetPoint("TOPLEFT", levelBar, "BOTTOMLEFT", 0, -10)
    campaignBar.label:SetText("Campaign Progress")
    self.overviewCampaignBar = campaignBar

    -- Next Objectives
    local nextHeading = CreateSectionHeading(panel, "NEXT OBJECTIVES")
    nextHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 18

    local nextObjectivesText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nextObjectivesText:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
    nextObjectivesText:SetWidth(PANEL_WIDTH - 8)
    nextObjectivesText:SetJustifyH("LEFT")
    nextObjectivesText:SetHeight(48)
    self.nextObjectivesText = nextObjectivesText
    y = y - 54

    -- XP & Catch-up
    local xpHeading = CreateSectionHeading(panel, "XP & CATCH-UP")
    xpHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 18

    local xpInset = CreateInsetPanel(panel, 74)
    xpInset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 80

    local rateLabel = xpInset:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rateLabel:SetPoint("TOPLEFT", xpInset, "TOPLEFT", 10, -8)
    self.rateLabel = rateLabel

    local rateMinus = CreateFrame("Button", nil, xpInset, "UIPanelButtonTemplate")
    rateMinus:SetSize(24, 20)
    rateMinus:SetText("-")
    rateMinus:SetPoint("TOPLEFT", xpInset, "TOPLEFT", 10, -26)
    rateMinus:SetScript("OnClick", function()
        local status = JWA.state.status
        if status then
            JWA:RequestXPRateChange(status.catchupRate - 1)
        end
    end)
    self.rateMinusButton = rateMinus

    local rateValue = xpInset:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    rateValue:SetPoint("LEFT", rateMinus, "RIGHT", 8, 0)
    rateValue:SetWidth(50)
    rateValue:SetJustifyH("CENTER")
    self.rateValue = rateValue

    local ratePlus = CreateFrame("Button", nil, xpInset, "UIPanelButtonTemplate")
    ratePlus:SetSize(24, 20)
    ratePlus:SetText("+")
    ratePlus:SetPoint("LEFT", rateValue, "RIGHT", 8, 0)
    ratePlus:SetScript("OnClick", function()
        local status = JWA.state.status
        if status then
            JWA:RequestXPRateChange(status.catchupRate + 1)
        end
    end)
    self.ratePlusButton = ratePlus

    local rateKindText = xpInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rateKindText:SetPoint("LEFT", ratePlus, "RIGHT", 12, 0)
    rateKindText:SetWidth(180)
    rateKindText:SetJustifyH("LEFT")
    self.rateKindText = rateKindText

    local bankedText = xpInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bankedText:SetPoint("TOPLEFT", rateMinus, "BOTTOMLEFT", 0, -8)
    bankedText:SetJustifyH("LEFT")
    self.bankedText = bankedText

    local claimButton = CreateFrame("Button", nil, xpInset, "UIPanelButtonTemplate")
    claimButton:SetSize(70, 20)
    claimButton:SetText("Claim")
    claimButton:SetPoint("LEFT", bankedText, "RIGHT", 12, 0)
    claimButton:Disable()
    claimButton:SetScript("OnClick", function(self)
        self:Disable()
        JWA:RequestBankedXPClaim()
    end)
    self.claimXPButton = claimButton

    local catchupText = xpInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    catchupText:SetPoint("TOPRIGHT", xpInset, "TOPRIGHT", -10, -8)
    catchupText:SetJustifyH("RIGHT")
    self.catchupText = catchupText

    -- Next Phase
    local nextPhaseHeading = CreateSectionHeading(panel, "NEXT PHASE")
    nextPhaseHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 18

    local nextPhaseText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nextPhaseText:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
    nextPhaseText:SetWidth(PANEL_WIDTH - 8)
    nextPhaseText:SetJustifyH("LEFT")
    nextPhaseText:SetHeight(32)
    self.nextPhaseText = nextPhaseText

    return panel
end

function UI:RefreshHeader()
    if not self.frame then
        return
    end

    local status = JWA.state.status
    local playerName = UnitName("player") or "?"
    local playerLevel = UnitLevel("player") or 0

    if not status then
        self.phaseText:SetText("Phase -- / Level --")
        self.capText:SetText("Level Cap: --")
        self.charText:SetText(string.format("Character: %s - Level %d", playerName, playerLevel))
        self.cappedText:SetText("")
        return
    end

    self.phaseText:SetText(string.format("Phase %d - Level %d", status.phase, status.levelCap))
    UI.SetColor(self.phaseText, UI.COLOR_WHITE)

    self.capText:SetText(string.format("Level Cap: %d", status.levelCap))
    UI.SetColor(self.capText, UI.COLOR_WHITE)

    self.charText:SetText(string.format("Character: %s - Level %d", playerName, status.playerLevel))

    if JWA:IsPlayerCapped() then
        self.cappedText:SetText("LEVEL CAP REACHED")
        UI.SetColor(self.cappedText, UI.COLOR_GREEN)
    else
        self.cappedText:SetText("")
    end
end

function UI:RefreshNextObjectives()
    if not self.nextObjectivesText then
        return
    end

    if not JWA:HasData() then
        self.nextObjectivesText:SetText("Progression data unavailable. Click Refresh to try again.")
        UI.SetColor(self.nextObjectivesText, UI.COLOR_GREY)
        return
    end

    local vanilla = JWA:GetVanillaSummary()
    if vanilla then
        self.nextObjectivesText:SetText(string.format("Vanilla Campaign: %d%% (%d/%d required)\nCurrent objective: %s\nNext unlock: %s\nWar Effort: %d%%\nFinal objective: Defeat Kel'Thuzad\nReward: Level 65 / Burning Crusade eligibility",
            vanilla.percent, vanilla.done, vanilla.total, vanilla.currentObjective, vanilla.nextUnlock, vanilla.war))
        UI.SetColor(self.nextObjectivesText, UI.COLOR_WHITE)
        return
    end
    local nextNodes = JWA:GetNextPhaseNodes()
    local remaining = {}
    local totalConfigured = #nextNodes

    for _, node in ipairs(nextNodes) do
        if not node.complete then
            table.insert(remaining, node.label)
        end
    end

    local objectiveSlots = JWA:GetObjectiveRequirementSlots()
    totalConfigured = totalConfigured + #objectiveSlots
    for _, slot in ipairs(objectiveSlots) do
        if not slot.complete then
            table.insert(remaining, slot.label)
        end
    end

    if #remaining == 0 then
        if totalConfigured > 0 then
            self.nextObjectivesText:SetText("All known objectives for the next phase are complete.")
            UI.SetColor(self.nextObjectivesText, UI.COLOR_GREEN)
        else
            self.nextObjectivesText:SetText("No further objectives are currently configured.")
            UI.SetColor(self.nextObjectivesText, UI.COLOR_GREY)
        end
        return
    end

    local lines = { string.format("%d requirement%s remaining:", #remaining, #remaining == 1 and "" or "s") }
    for i, label in ipairs(remaining) do
        table.insert(lines, string.format("%d. %s", i, label))
    end

    self.nextObjectivesText:SetText(table.concat(lines, "\n"))
    UI.SetColor(self.nextObjectivesText, UI.COLOR_WHITE)
end

function UI:RefreshXPPanel()
    local status = JWA.state.status
    if not status then
        self.rateLabel:SetText("XP Rate")
        self.rateValue:SetText("--")
        self.rateKindText:SetText("")
        self.bankedText:SetText("Banked XP: --")
        self.claimXPButton:Disable()
        self.catchupText:SetText("Catch-Up: --")
        self.rateMinusButton:Disable()
        self.ratePlusButton:Disable()
        return
    end

    self.rateLabel:SetText("XP Rate")
    self.rateValue:SetText(string.format("%dx", status.catchupRate))
    UI.SetColor(self.rateValue, UI.COLOR_WHITE)

    if JWA:GetXPRateKind(status.catchupRate) == "normal" then
        self.rateKindText:SetText("Normal experience rate")
        UI.SetColor(self.rateKindText, UI.COLOR_GREY)
    else
        self.rateKindText:SetText("Catch-up experience rate")
        UI.SetColor(self.rateKindText, UI.COLOR_GREEN)
    end

    local canChangeRate = status.rateCmdEnabled
    if canChangeRate and status.catchupRate > status.minRate then
        self.rateMinusButton:Enable()
    else
        self.rateMinusButton:Disable()
    end

    if canChangeRate and status.catchupRate < status.maxRate then
        self.ratePlusButton:Enable()
    else
        self.ratePlusButton:Disable()
    end

    self.bankedText:SetText(string.format("Banked XP: %s", JWA.FormatNumber and JWA:FormatNumber(status.bankedXP) or tostring(status.bankedXP)))

    if JWA:CanClaimBankedXP() then
        self.claimXPButton:Enable()
    else
        self.claimXPButton:Disable()
    end

    if status.catchupEligible then
        self.catchupText:SetText("Catch-Up: Active")
        UI.SetColor(self.catchupText, UI.COLOR_GREEN)
    else
        self.catchupText:SetText("Catch-Up: Not Needed")
        UI.SetColor(self.catchupText, UI.COLOR_GREY)
    end
end

function UI:RefreshNextPhase()
    local status = JWA.state.status
    if not status then
        self.nextPhaseText:SetText("Progression data unavailable. Click Refresh to try again.")
        UI.SetColor(self.nextPhaseText, UI.COLOR_GREY)
        return
    end

    local vanilla = JWA:GetVanillaSummary()
    if vanilla and status.levelCap == 60 then
        self.nextPhaseText:SetText(string.format("Level Cap 65 / Burning Crusade - %d/%d required objectives\n%s",
            vanilla.done, vanilla.total, vanilla.done == vanilla.total and "Eligible for the existing GM cap transition."
                or "Complete the Vanilla campaign to become eligible."))
        UI.SetColor(self.nextPhaseText, UI.COLOR_WHITE)
        return
    end
    local nextCap = JWA:GetNextPhaseLevelCap()
    local nextNodes = JWA:GetNextPhaseNodes()
    local objectiveSlots = JWA:GetObjectiveRequirementSlots()
    local totalRequirements = #nextNodes + #objectiveSlots
    local completed = 0

    for _, node in ipairs(nextNodes) do
        if node.complete then
            completed = completed + 1
        end
    end

    for _, slot in ipairs(objectiveSlots) do
        if slot.complete then
            completed = completed + 1
        end
    end

    local lines = {}
    if nextCap then
        table.insert(lines, string.format("Level Cap: %d", nextCap))
    else
        table.insert(lines, "Level Cap: not yet announced")
    end

    if totalRequirements > 0 then
        table.insert(lines, string.format("%d / %d requirements completed", completed, totalRequirements))
    end

    self.nextPhaseText:SetText(table.concat(lines, "\n"))
    UI.SetColor(self.nextPhaseText, UI.COLOR_WHITE)
end

function UI:RefreshOverview()
    if not self.frame then
        return
    end

    local status = JWA.state.status

    if status then
        if status.catchupCeiling > 0 and status.catchupCeiling > status.levelCap then
            self.phaseSummary:SetText(string.format(
                "%s. Catch-up XP is available through Level %d.", JWA:EraName(status.era), status.catchupCeiling))
        else
            local nextCap = JWA:GetNextPhaseLevelCap()
            if nextCap then
                self.phaseSummary:SetText(string.format(
                    "Complete the current campaign objectives to unlock Level %d progression.", nextCap))
            else
                self.phaseSummary:SetText(JWA:EraName(status.era) .. " - " .. status.chapter)
            end
        end
        UI.SetColor(self.phaseSummary, UI.COLOR_WHITE)
    else
        self.phaseSummary:SetText("Progression data unavailable. Click Refresh to try again.")
        UI.SetColor(self.phaseSummary, UI.COLOR_GREY)
    end

    local vanilla = JWA:GetVanillaSummary()
    if vanilla then
        self.phaseSummary:SetText(string.format("Vanilla Campaign - %d%% | Final reward: Level 65 / Burning Crusade", vanilla.percent))
    end
    self:RefreshOverviewGlance()
    self:RefreshNextObjectives()
    self:RefreshXPPanel()
    self:RefreshNextPhase()
end

function UI:RefreshOverviewGlance()
    if not self.overviewLevelBar then
        return
    end

    local status = JWA.state.status
    if not status then
        self.overviewLevelBar:SetProgress(0, "--")
        self.overviewCampaignBar:SetProgress(0, "--")
        return
    end

    local levelCap = math.max(1, status.levelCap or 1)
    local playerLevel = status.playerLevel or 0
    self.overviewLevelBar:SetProgress(playerLevel / levelCap,
        string.format("Level %d / %d", playerLevel, levelCap))

    local vanilla = JWA:GetVanillaSummary()
    if vanilla and vanilla.total and vanilla.total > 0 then
        self.overviewCampaignBar:SetProgress(vanilla.done / vanilla.total,
            string.format("%d%% (%d/%d)", vanilla.percent, vanilla.done, vanilla.total))
    else
        local nextNodes = JWA:GetNextPhaseNodes()
        local objectiveSlots = JWA:GetObjectiveRequirementSlots()
        local total = #nextNodes + #objectiveSlots
        local completed = 0
        for _, node in ipairs(nextNodes) do
            if node.complete then completed = completed + 1 end
        end
        for _, slot in ipairs(objectiveSlots) do
            if slot.complete then completed = completed + 1 end
        end
        if total > 0 then
            self.overviewCampaignBar:SetProgress(completed / total,
                string.format("%d / %d", completed, total))
        else
            self.overviewCampaignBar:SetProgress(0, "No objectives configured")
        end
    end
end

function JWA:FormatNumber(value)
    value = math.floor(tonumber(value) or 0)
    local formatted = tostring(value)
    local isNegative = false
    if string.sub(formatted, 1, 1) == "-" then
        isNegative = true
        formatted = string.sub(formatted, 2)
    end

    local result = ""
    local len = string.len(formatted)
    for i = 1, len do
        result = result .. string.sub(formatted, i, i)
        local remaining = len - i
        if remaining > 0 and remaining % 3 == 0 then
            result = result .. ","
        end
    end

    return (isNegative and "-" or "") .. result
end
