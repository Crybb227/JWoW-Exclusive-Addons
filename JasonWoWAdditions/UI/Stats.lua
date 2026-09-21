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

-- A small stat tile: big number on top, label underneath. Used for both the Nemesis
-- lifetime stats and the campaign summary numbers so the Stats tab reads as one grid
-- instead of two differently-styled sections.
local statTileCount = 0

local function CreateStatTile(parent, width)
    statTileCount = statTileCount + 1
    local tile = UI.CreateInsetPanel(parent, width, 52)

    local value = tile:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    value:SetPoint("TOP", tile, "TOP", 0, -8)
    value:SetWidth(width - 8)
    value:SetJustifyH("CENTER")
    UI.SetColor(value, UI.COLOR_WHITE)

    local label = tile:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOP", value, "BOTTOM", 0, -4)
    label:SetWidth(width - 8)
    label:SetJustifyH("CENTER")
    UI.SetColor(label, UI.COLOR_GREY)

    tile.value = value
    tile.label = label
    return tile
end

function UI:CreateStatsPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 440)
    panel:Hide()

    local y = 0

    local campaignHeading = CreateSectionHeading(panel, "CAMPAIGN")
    campaignHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 20

    local CAMPAIGN_KEYS = { "objectivesDone", "objectivesTotal", "warEffortPct", "levelCap" }
    local CAMPAIGN_LABELS = {
        objectivesDone = "Objectives Done",
        objectivesTotal = "Objectives Total",
        warEffortPct = "War Effort",
        levelCap = "Level Cap",
    }

    local tileGap = 8
    local tileWidth = (PANEL_WIDTH - (tileGap * (#CAMPAIGN_KEYS - 1))) / #CAMPAIGN_KEYS

    self.statsCampaignTiles = {}
    local previousTile
    for _, key in ipairs(CAMPAIGN_KEYS) do
        local tile = CreateStatTile(panel, tileWidth)
        if previousTile then
            tile:SetPoint("TOPLEFT", previousTile, "TOPRIGHT", tileGap, 0)
        else
            tile:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        end
        tile.label:SetText(CAMPAIGN_LABELS[key])
        self.statsCampaignTiles[key] = tile
        previousTile = tile
    end
    y = y - 60

    local nemesisHeading = CreateSectionHeading(panel, "NEMESIS (LIFETIME)")
    nemesisHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 20

    local NEMESIS_KEYS = { "totalKills", "revengeKills", "bountyKills", "highestRank", "bountyTokensEarned" }
    local NEMESIS_LABELS = {
        totalKills = "Total Kills",
        revengeKills = "Revenge Kills",
        bountyKills = "Bounty Kills",
        highestRank = "Highest Rank",
        bountyTokensEarned = "Bounty Tokens",
    }

    local nemesisTileWidth = (PANEL_WIDTH - (tileGap * (#NEMESIS_KEYS - 1))) / #NEMESIS_KEYS
    self.statsNemesisTiles = {}
    previousTile = nil
    for _, key in ipairs(NEMESIS_KEYS) do
        local tile = CreateStatTile(panel, nemesisTileWidth)
        if previousTile then
            tile:SetPoint("TOPLEFT", previousTile, "TOPRIGHT", tileGap, 0)
        else
            tile:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        end
        tile.label:SetText(NEMESIS_LABELS[key])
        self.statsNemesisTiles[key] = tile
        previousTile = tile
    end
    y = y - 60

    local lastKillHeading = CreateSectionHeading(panel, "LAST KILL")
    lastKillHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    y = y - 18

    local lastKillText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lastKillText:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
    lastKillText:SetWidth(PANEL_WIDTH - 8)
    lastKillText:SetJustifyH("LEFT")
    self.statsLastKillText = lastKillText

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
    hint:SetWidth(PANEL_WIDTH)
    hint:SetJustifyH("LEFT")
    hint:SetText("Nemesis stats refresh when you open the Nemesis tab or click \"Load Affixes\" there.")
    UI.SetColor(hint, UI.COLOR_GREY)

    return panel
end

function UI:RefreshStats()
    if not self.statsCampaignTiles then
        return
    end

    local vanilla = JWA:GetVanillaSummary()
    local status = JWA.state.status
    local tiles = self.statsCampaignTiles

    if vanilla then
        tiles.objectivesDone.value:SetText(tostring(vanilla.done))
        tiles.objectivesTotal.value:SetText(tostring(vanilla.total))
        tiles.warEffortPct.value:SetText(string.format("%d%%", vanilla.war or 0))
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
        tiles.objectivesDone.value:SetText(tostring(completed))
        tiles.objectivesTotal.value:SetText(tostring(total))
        tiles.warEffortPct.value:SetText("--")
    end

    tiles.levelCap.value:SetText(status and tostring(status.levelCap) or "--")

    local stats = JWA.nemesisStats
    for key, tile in pairs(self.statsNemesisTiles) do
        tile.value:SetText(stats and JWA:FormatNumber(stats[key] or 0) or "--")
    end

    if stats and stats.lastKillAt and stats.lastKillAt > 0 then
        self.statsLastKillText:SetText(date("%Y-%m-%d %H:%M:%S", stats.lastKillAt))
        UI.SetColor(self.statsLastKillText, UI.COLOR_WHITE)
    else
        self.statsLastKillText:SetText("No Nemesis kill data loaded yet.")
        UI.SetColor(self.statsLastKillText, UI.COLOR_GREY)
    end
end
