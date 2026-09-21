JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572
local ROW_HEIGHT = 20

local function CreateSectionHeading(parent, text)
    local heading = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText(text)
    UI.SetColor(heading, UI.COLOR_GOLD)
    return heading
end

-- A ScrollFrame wrapping a tall content frame, used for the requirement checklist since
-- the number of campaign nodes is server-configured and can exceed the visible area.
local scrollingListCount = 0

local function CreateScrollingList(parent, width, height)
    scrollingListCount = scrollingListCount + 1
    local name = "JasonWoWAdditionsCampaignScrollFrame" .. scrollingListCount

    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width - 24, height)

    local content = CreateFrame("Frame", name .. "Content", scrollFrame)
    content:SetSize(width - 24, height)
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

-- Roadmap milestones the client knows about regardless of what the server has configured
-- for the *current* chapter's node/objective list. Level caps 20/40/60 and the vanilla
-- campaign's Level 65/BC reward are referenced elsewhere in this addon and the server's
-- own conf.dist (StartingLevelCap, era 0/1/2); 70 and 80 are BC's and WotLK's level caps.
-- This is deliberately a client-side constant, not server-driven: it exists to show the
-- whole arc at a glance, not to gate anything.
local ROADMAP_MILESTONES = {
    { levelCap = 20, era = 0, label = "Lvl 20" },
    { levelCap = 40, era = 0, label = "Lvl 40" },
    { levelCap = 60, era = 0, label = "Lvl 60" },
    { levelCap = 65, era = 1, label = "Lvl 65 / BC" },
    { levelCap = 70, era = 1, label = "Lvl 70" },
    { levelCap = 80, era = 2, label = "Lvl 80 / WotLK" },
}

local ROADMAP_NODE_SIZE = 14
local roadmapNodeCount = 0

local function CreateRoadmapNode(parent)
    roadmapNodeCount = roadmapNodeCount + 1
    local node = CreateFrame("Frame", "JasonWoWAdditionsRoadmapNode" .. roadmapNodeCount, parent)
    node:SetSize(ROADMAP_NODE_SIZE, ROADMAP_NODE_SIZE)

    node:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 6,
    })

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    label:SetPoint("TOP", node, "BOTTOM", 0, -4)
    label:SetJustifyH("CENTER")
    label:SetWidth(90)
    node.captionText = label

    node:EnableMouse(true)
    node:SetScript("OnEnter", function(self)
        if not self.tooltipTitle then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.tooltipTitle)
        if self.tooltipState then
            GameTooltip:AddLine(self.tooltipState, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    node:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return node
end

-- One connective bar segment strung between two roadmap nodes; filled fraction shows how
-- much of that leg is complete instead of only "reached" / "not reached".
local roadmapSegmentCount = 0

local function CreateRoadmapSegment(parent)
    roadmapSegmentCount = roadmapSegmentCount + 1
    local segment = CreateFrame("StatusBar", "JasonWoWAdditionsRoadmapSegment" .. roadmapSegmentCount, parent)
    segment:SetHeight(4)
    segment:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)

    local background = segment:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(segment)
    background:SetTexture(0.2, 0.2, 0.2, 0.9)

    return segment
end

function UI:CreateRoadmap(parent, width)
    local roadmap = CreateFrame("Frame", nil, parent)
    roadmap:SetSize(width, 40)

    local nodes = {}
    local segments = {}
    local count = #ROADMAP_MILESTONES
    local usableWidth = width - ROADMAP_NODE_SIZE

    for index, milestone in ipairs(ROADMAP_MILESTONES) do
        local node = CreateRoadmapNode(roadmap)
        local xOffset = (count > 1) and (usableWidth * (index - 1) / (count - 1)) or 0
        node:SetPoint("TOPLEFT", roadmap, "TOPLEFT", xOffset, 0)
        node.captionText:SetText(milestone.label)
        nodes[index] = node

        if index > 1 then
            local segment = CreateRoadmapSegment(roadmap)
            segment:SetPoint("LEFT", nodes[index - 1], "RIGHT", 0, 0)
            segment:SetPoint("RIGHT", node, "LEFT", 0, 0)
            segments[index - 1] = segment
        end
    end

    roadmap.nodes = nodes
    roadmap.segments = segments
    return roadmap
end

-- Colors a roadmap node/segment for done (gold, filled), current (blue outline, partial
-- fill from the chapter's own completion %), or locked (grey, empty) state.
function UI:RefreshRoadmap(roadmap, currentLevelCap, currentEra, currentFraction)
    if not roadmap then
        return
    end

    for index, milestone in ipairs(ROADMAP_MILESTONES) do
        local node = roadmap.nodes[index]
        local isDone = currentLevelCap > milestone.levelCap
            or (currentLevelCap == milestone.levelCap and currentEra > milestone.era)
        local isCurrent = currentLevelCap == milestone.levelCap and currentEra == milestone.era

        if isDone then
            node:SetBackdropColor(UI.BAR_COLOR_CAMPAIGN[1], UI.BAR_COLOR_CAMPAIGN[2], UI.BAR_COLOR_CAMPAIGN[3], 1)
            node:SetBackdropBorderColor(0, 0, 0, 0.8)
            UI.SetColor(node.captionText, UI.COLOR_GOLD)
            node.tooltipTitle = milestone.label
            node.tooltipState = "Complete"
        elseif isCurrent then
            node:SetBackdropColor(UI.BAR_COLOR_WAR_EFFORT[1], UI.BAR_COLOR_WAR_EFFORT[2], UI.BAR_COLOR_WAR_EFFORT[3], 1)
            node:SetBackdropBorderColor(1, 1, 1, 1)
            UI.SetColor(node.captionText, UI.COLOR_WHITE)
            node.tooltipTitle = milestone.label
            node.tooltipState = string.format("In progress (%d%%)", math.floor((currentFraction or 0) * 100 + 0.5))
        else
            node:SetBackdropColor(0.25, 0.25, 0.25, 1)
            node:SetBackdropBorderColor(0, 0, 0, 0.8)
            UI.SetColor(node.captionText, UI.COLOR_GREY)
            node.tooltipTitle = milestone.label
            node.tooltipState = "Locked"
        end
    end

    for index, segment in pairs(roadmap.segments) do
        local leftMilestone = ROADMAP_MILESTONES[index]
        local rightMilestone = ROADMAP_MILESTONES[index + 1]
        local leftDone = currentLevelCap > leftMilestone.levelCap
            or (currentLevelCap == leftMilestone.levelCap and currentEra > leftMilestone.era)
        local isCurrentLeg = currentLevelCap == leftMilestone.levelCap and currentEra == leftMilestone.era

        if leftDone then
            segment:SetStatusBarColor(UI.BAR_COLOR_CAMPAIGN[1], UI.BAR_COLOR_CAMPAIGN[2], UI.BAR_COLOR_CAMPAIGN[3])
            segment:SetValue(1)
        elseif isCurrentLeg then
            segment:SetStatusBarColor(UI.BAR_COLOR_WAR_EFFORT[1], UI.BAR_COLOR_WAR_EFFORT[2], UI.BAR_COLOR_WAR_EFFORT[3])
            segment:SetValue(currentFraction or 0)
        else
            segment:SetStatusBarColor(0.3, 0.3, 0.3)
            segment:SetValue(0)
        end
    end
end

function UI:CreateCampaignPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 420)
    panel:Hide()

    local heading = CreateSectionHeading(panel, "CAMPAIGN PROGRESS")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    -- Mini roadmap: the whole Classic -> BC -> WotLK arc at a glance, current stop highlighted.
    local roadmap = self:CreateRoadmap(panel, PANEL_WIDTH - 8)
    roadmap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -20)
    self.campaignRoadmap = roadmap

    -- Chapter completion + War Effort bars up top: the two numbers players ask about most.
    local barWidth = PANEL_WIDTH
    local chapterBar = self:CreateFancyBar(panel, barWidth, UI.BAR_COLOR_CAMPAIGN)
    chapterBar:SetPoint("TOPLEFT", roadmap, "BOTTOMLEFT", -4, -6)
    chapterBar.label:SetText("Chapter Completion")
    self.campaignChapterBar = chapterBar

    local warEffortBar = self:CreateFancyBar(panel, barWidth, UI.BAR_COLOR_WAR_EFFORT)
    warEffortBar:SetPoint("TOPLEFT", chapterBar, "BOTTOMLEFT", 0, -6)
    warEffortBar.label:SetText("War Effort")
    self.campaignWarEffortBar = warEffortBar

    local checklistHeading = CreateSectionHeading(panel, "REQUIREMENT CHECKLIST")
    checklistHeading:SetPoint("TOPLEFT", warEffortBar, "BOTTOMLEFT", 0, -10)

    local scrollFrame, scrollContent = CreateScrollingList(panel, PANEL_WIDTH, 230)
    scrollFrame:SetPoint("TOPLEFT", checklistHeading, "BOTTOMLEFT", 0, -6)
    self.campaignChecklistScroll = scrollFrame
    self.campaignChecklistContent = scrollContent
    self.campaignChecklistRows = {}

    return panel
end

local checklistRowCount = 0

local function CreateChecklistRow(parent, index)
    checklistRowCount = checklistRowCount + 1
    local row = CreateFrame("Frame", "JasonWoWAdditionsCampaignChecklistRow" .. checklistRowCount, parent)
    row:SetSize(PANEL_WIDTH - 24, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -((index - 1) * ROW_HEIGHT))

    local completeButton = CreateFrame("Button", row:GetName() .. "CompleteButton", row, "UIPanelButtonTemplate")
    completeButton:SetSize(70, 14)
    completeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    completeButton:SetText("Complete")
    local buttonFontString = completeButton:GetFontString()
    if buttonFontString then
        buttonFontString:SetFontObject("GameFontHighlightSmall")
    end
    completeButton:Hide()
    row.completeButton = completeButton

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", 0, 0)
    text:SetPoint("RIGHT", completeButton, "LEFT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text

    return row
end

local function StateGlyph(complete)
    if complete then
        return "|cff20e020\226\156\147|r"  -- green check
    end
    return "|cff999999\226\151\139|r"      -- grey circle
end

-- For a grouped (alternative) objective that is satisfied but not individually done by
-- this character, name whichever sibling(s) in the group they actually completed.
local function GroupSatisfiedViaText(item)
    if item.group == "" or not item.complete or item.individuallyComplete then
        return nil
    end

    local satisfiedVia = {}
    for _, sibling in ipairs(JWA:GetOrderedObjectives()) do
        if sibling.group == item.group and sibling.individuallyComplete then
            table.insert(satisfiedVia, sibling.label)
        end
    end

    if #satisfiedVia == 0 then
        return nil
    end

    return "Satisfied via " .. table.concat(satisfiedVia, ", ")
end

function UI:RefreshCampaignBars()
    if not self.campaignChapterBar then
        return
    end

    local status = JWA.state.status
    local chapterFraction = 0

    local vanilla = JWA:GetVanillaSummary()
    if vanilla and vanilla.total and vanilla.total > 0 then
        chapterFraction = vanilla.done / vanilla.total
        self.campaignChapterBar:SetProgress(chapterFraction,
            string.format("%d%% (%d/%d)", vanilla.percent, vanilla.done, vanilla.total))
        self.campaignWarEffortBar:SetProgress((vanilla.war or 0) / 100,
            string.format("%d%%", vanilla.war or 0))
        self.campaignWarEffortBar:Show()
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
            chapterFraction = completed / total
            self.campaignChapterBar:SetProgress(chapterFraction, string.format("%d / %d", completed, total))
        else
            self.campaignChapterBar:SetProgress(0, "No objectives configured")
        end

        -- No vanilla War Effort data before Level 60; hide rather than show a misleading 0%.
        self.campaignWarEffortBar:Hide()
    end

    if status then
        self:RefreshRoadmap(self.campaignRoadmap, status.levelCap, status.era, chapterFraction)
    end
end

function UI:RefreshCampaign()
    if not self.campaignChecklistContent then
        return
    end

    self:RefreshCampaignBars()

    local byCategory, categoryOrder = JWA:GetNodesByCategory()
    local rowIndex = 0

    local function EnsureRow()
        rowIndex = rowIndex + 1
        local row = self.campaignChecklistRows[rowIndex]
        if not row then
            row = CreateChecklistRow(self.campaignChecklistContent, rowIndex)
            self.campaignChecklistRows[rowIndex] = row
        else
            row:SetPoint("TOPLEFT", self.campaignChecklistContent, "TOPLEFT", 4, -((rowIndex - 1) * ROW_HEIGHT))
        end
        row.completeButton:Hide()
        row.completeButton:SetText("Complete")
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        row.completeButton:SetScript("OnClick", nil)
        row:Show()
        return row
    end

    if not JWA:HasData() then
        local row = EnsureRow()
        row.text:SetText("Progression data unavailable. Click Refresh to try again.")
        UI.SetColor(row.text, UI.COLOR_GREY)
    elseif #categoryOrder == 0 then
        local row = EnsureRow()
        row.text:SetText("No campaign objectives are currently configured.")
        UI.SetColor(row.text, UI.COLOR_GREY)
    else
        for _, category in ipairs(categoryOrder) do
            local headerRow = EnsureRow()
            headerRow.text:SetText(JWA:CategoryDisplayName(category))
            UI.SetColor(headerRow.text, UI.COLOR_GOLD)

            for _, item in ipairs(byCategory[category]) do
                local row = EnsureRow()
                local glyph = StateGlyph(item.complete)
                local satisfiedViaText = GroupSatisfiedViaText(item)

                if satisfiedViaText then
                    row.text:SetText(string.format("  %s %s (%s)", glyph, item.label, satisfiedViaText))
                else
                    row.text:SetText(string.format("  %s %s", glyph, item.label))
                end

                if item.complete then
                    UI.SetColor(row.text, UI.COLOR_GREEN)
                else
                    UI.SetColor(row.text, UI.COLOR_GREY)
                end

                if item.kind == "vanilla" then
                    local prefix = item.optional and "Bonus / " or ""
                    row.text:SetText(string.format("  %s%s - %s (%d/%d, %d%%)", prefix,
                        item.label, item.state, item.current, item.required,
                        math.floor(100 * item.current / item.required)))
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", function()
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(item.label)
                        GameTooltip:AddLine(item.scope .. " - " .. item.state, 1, 1, 1)
                        if item.scope ~= "Realm" then
                            GameTooltip:AddLine(string.format("Your character: %d/%d (realm needs one human)",
                                item.personal, item.required), 1, 1, 1, true)
                        end
                        if item.reason ~= "" then GameTooltip:AddLine(item.reason, 1, 0.7, 0, true) end
                        if item.acceptedItems ~= "" then
                            GameTooltip:AddLine("Accepted item IDs: " .. item.acceptedItems, 1, 1, 1, true)
                            GameTooltip:AddLine("Donate consumes up to 20 accepted items from your bags.", 1, 1, 1, true)
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    if not item.complete and item.acceptedItems ~= "" then
                        row.completeButton:SetText("Donate")
                        row.completeButton:SetScript("OnClick", function()
                            for itemId in item.acceptedItems:gmatch("%d+") do
                                local count = math.min(20, GetItemCount(tonumber(itemId)), item.required - item.current)
                                if count > 0 then
                                    SendChatMessage(string.format(".progress donate %d %d", tonumber(itemId), count), "SAY")
                                    JWA:ScheduleStatusRefresh(0.5)
                                    return
                                end
                            end
                            DEFAULT_CHAT_FRAME:AddMessage("No accepted supplies in your bags.")
                        end)
                        row.completeButton:Show()
                    elseif item.id == "v60_aq_open" and item.state == "Available" then
                        row.completeButton:SetText("Gong")
                        row.completeButton:SetScript("OnClick", function()
                            SendChatMessage(".progress gong", "SAY")
                            JWA:ScheduleStatusRefresh(0.5)
                        end)
                        row.completeButton:Show()
                    end
                end

                if item.kind == "objective" and not item.individuallyComplete then
                    local objectiveId = item.id
                    row.completeButton:SetScript("OnClick", function()
                        JWA:RequestCompleteObjective(objectiveId)
                    end)
                    row.completeButton:Show()
                end
            end
        end
    end

    for index = rowIndex + 1, #self.campaignChecklistRows do
        self.campaignChecklistRows[index]:Hide()
        self.campaignChecklistRows[index].completeButton:Hide()
    end

    self.campaignChecklistContent:SetHeight(math.max(1, rowIndex * ROW_HEIGHT))
end
