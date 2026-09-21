JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions
JWA.UI = JWA.UI or {}
local UI = JWA.UI

local PANEL_WIDTH = 572
local NEMESIS_ADDON_PREFIX = "Nemesis"
local NEMESIS_BOOTSTRAP_COMMAND = ".nemesis addon bootstrap"

-- Affix catalog + lifetime stats state, populated from the Nemesis system's own
-- V2:AFFIX_META/V2:STATS broadcasts (a separate wire connection from the campaign
-- progression one: same envelope/CHAT_MSG_ADDON mechanism, different addon prefix).
JWA.nemesisAffixes = {}
JWA.nemesisAffixOrder = {}
JWA.nemesisAffixRequestedAt = 0
JWA.nemesisStats = nil

local function SplitFields(message)
    return JWA.SplitFields(message, ":")
end

local function ParseAffixMeta(fields)
    -- fields[1]="V2" fields[2]="AFFIX_META", data starts at fields[3]
    local i = 3
    return {
        bit = tonumber(fields[i]) or 0,
        name = fields[i + 1] or "Unknown",
        shortDescription = fields[i + 2] or "",
        longDescription = fields[i + 3] or "",
        auraSpell = tonumber(fields[i + 4]) or 0,
    }
end

local function ParseStatsFields(fields)
    -- fields[1]="V2" fields[2]="STATS", data starts at fields[3]
    local i = 3
    return {
        totalKills = tonumber(fields[i]) or 0,
        revengeKills = tonumber(fields[i + 1]) or 0,
        bountyKills = tonumber(fields[i + 2]) or 0,
        highestRank = tonumber(fields[i + 3]) or 0,
        bountyTokensEarned = tonumber(fields[i + 4]) or 0,
        lastKillAt = tonumber(fields[i + 5]) or 0,
    }
end

function JWA:HandleNemesisAddonMessage(message)
    if not message or message == "" then
        return
    end

    local fields = SplitFields(message)
    if fields[1] ~= "V2" then
        return
    end

    local opcode = fields[2]
    if opcode == "AFFIX_CATALOG_BEGIN" then
        self.nemesisAffixes = {}
        self.nemesisAffixOrder = {}
        return
    end

    if opcode == "AFFIX_META" then
        local affix = ParseAffixMeta(fields)
        if not self.nemesisAffixes[affix.bit] then
            table.insert(self.nemesisAffixOrder, affix.bit)
        end
        self.nemesisAffixes[affix.bit] = affix
        if self.UI then
            self.UI:RefreshNemesis()
        end
        return
    end

    if opcode == "AFFIX_CATALOG_END" then
        if self.UI then
            self.UI:RefreshNemesis()
        end
        return
    end

    if opcode == "STATS" then
        self.nemesisStats = ParseStatsFields(fields)
        if self.UI then
            self.UI:RefreshNemesis()
        end
        return
    end
end

function JWA:RequestNemesisAffixCatalog()
    self.nemesisAffixRequestedAt = self:GetNow()
    SendChatMessage(NEMESIS_BOOTSTRAP_COMMAND, "SAY")
end

local nemesisEventFrame = CreateFrame("Frame")
nemesisEventFrame:RegisterEvent("PLAYER_LOGIN")
nemesisEventFrame:RegisterEvent("CHAT_MSG_ADDON")
nemesisEventFrame:SetScript("OnEvent", function(_, event, prefix, message)
    if event == "PLAYER_LOGIN" then
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(NEMESIS_ADDON_PREFIX)
        end
        return
    end

    if event == "CHAT_MSG_ADDON" and prefix == NEMESIS_ADDON_PREFIX then
        JWA:HandleNemesisAddonMessage(message)
    end
end)

function UI:CreateNemesisPanel(frame, anchorAbove)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -12)
    panel:SetSize(PANEL_WIDTH, 420)
    panel:Hide()

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    heading:SetText("NEMESIS AFFIXES")
    UI.SetColor(heading, UI.COLOR_GOLD)

    local refreshButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshButton:SetSize(110, 20)
    refreshButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 2)
    refreshButton:SetText("Load Affixes")
    refreshButton:SetScript("OnClick", function() JWA:RequestNemesisAffixCatalog() end)
    self.nemesisRefreshButton = refreshButton

    local statsPanel = UI.CreateInsetPanel(panel, PANEL_WIDTH, 54)
    statsPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
    self.nemesisStatsPanel = statsPanel

    local STAT_COLUMN_KEYS = { "totalKills", "revengeKills", "bountyKills", "highestRank", "bountyTokensEarned" }
    local STAT_COLUMN_LABELS = {
        totalKills = "Total Kills",
        revengeKills = "Revenge Kills",
        bountyKills = "Bounty Kills",
        highestRank = "Highest Rank",
        bountyTokensEarned = "Bounty Tokens",
    }

    self.nemesisStatValues = {}
    local columnWidth = (PANEL_WIDTH - 20) / #STAT_COLUMN_KEYS
    for index, key in ipairs(STAT_COLUMN_KEYS) do
        local columnX = 10 + ((index - 1) * columnWidth)

        local label = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", columnX, -8)
        label:SetWidth(columnWidth - 6)
        label:SetJustifyH("LEFT")
        label:SetText(STAT_COLUMN_LABELS[key])
        UI.SetColor(label, UI.COLOR_GREY)

        local value = statsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        value:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", columnX, -24)
        value:SetWidth(columnWidth - 6)
        value:SetJustifyH("LEFT")
        UI.SetColor(value, UI.COLOR_WHITE)
        self.nemesisStatValues[key] = value
    end

    local scrollFrame = CreateFrame("ScrollFrame", "JasonWoWAdditionsNemesisScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -88)
    scrollFrame:SetSize(PANEL_WIDTH - 24, 310)

    local scrollContent = CreateFrame("Frame", "JasonWoWAdditionsNemesisScrollContent", scrollFrame)
    scrollContent:SetSize(PANEL_WIDTH - 24, 310)
    scrollFrame:SetScrollChild(scrollContent)

    self.nemesisScroll = scrollFrame
    self.nemesisContent = scrollContent
    self.nemesisRows = {}

    return panel
end

local AFFIX_ICON_SIZE = 32
local AFFIX_ROW_HEIGHT = 40
local nemesisRowCount = 0

local function CreateAffixRow(parent, index)
    nemesisRowCount = nemesisRowCount + 1
    local row = CreateFrame("Frame", "JasonWoWAdditionsAffixRow" .. nemesisRowCount, parent)
    row:SetSize(PANEL_WIDTH - 24, AFFIX_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -((index - 1) * AFFIX_ROW_HEIGHT))

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(AFFIX_ICON_SIZE, AFFIX_ICON_SIZE)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local textLeft = AFFIX_ICON_SIZE + 8

    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local descText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -16)
    descText:SetWidth(PANEL_WIDTH - 24 - textLeft)
    descText:SetJustifyH("LEFT")
    row.descText = descText

    return row
end

local DEFAULT_AFFIX_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local AFFIX_ICONS = {
    Vampiric = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
    Swift = "Interface\\Icons\\Ability_Rogue_Sprint",
    Juggernaut = "Interface\\Icons\\Ability_Warrior_ShieldMastery",
    Savage = "Interface\\Icons\\Ability_Druid_Rake",
    Spellward = "Interface\\Icons\\Spell_Holy_SpellWarding",
    Enraged = "Interface\\Icons\\Ability_Warrior_InnerRage",
    Regenerating = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
}

local function GetAffixIconTexture(affix)
    if AFFIX_ICONS[affix.name] then
        return AFFIX_ICONS[affix.name]
    end

    local auraSpell = affix.auraSpell
    if auraSpell and auraSpell > 0 then
        local texture = GetSpellTexture(auraSpell)
        if texture then
            return texture
        end
    end
    return DEFAULT_AFFIX_ICON
end

function UI:RefreshNemesisStats()
    if not self.nemesisStatValues then
        return
    end

    local stats = JWA.nemesisStats
    for key, valueText in pairs(self.nemesisStatValues) do
        if stats then
            valueText:SetText(JWA:FormatNumber(stats[key] or 0))
        else
            valueText:SetText("--")
        end
    end
end

function UI:RefreshNemesis()
    if not self.nemesisContent then
        return
    end

    self:RefreshNemesisStats()

    local order = JWA.nemesisAffixOrder
    local rowIndex = 0

    local function EnsureRow()
        rowIndex = rowIndex + 1
        local row = self.nemesisRows[rowIndex]
        if not row then
            row = CreateAffixRow(self.nemesisContent, rowIndex)
            self.nemesisRows[rowIndex] = row
        else
            row:SetPoint("TOPLEFT", self.nemesisContent, "TOPLEFT", 4, -((rowIndex - 1) * AFFIX_ROW_HEIGHT))
        end
        row:Show()
        return row
    end

    if #order == 0 then
        local row = EnsureRow()
        row.icon:SetTexture(DEFAULT_AFFIX_ICON)
        row.nameText:SetText("No affix data loaded yet.")
        UI.SetColor(row.nameText, UI.COLOR_GREY)
        row.descText:SetText("Click \"Load Affixes\" to request the realm's current affix catalog.")
        UI.SetColor(row.descText, UI.COLOR_GREY)
    else
        for _, bit in ipairs(order) do
            local affix = JWA.nemesisAffixes[bit]
            if affix then
                local row = EnsureRow()
                row.icon:SetTexture(GetAffixIconTexture(affix))
                row.nameText:SetText(affix.name)
                UI.SetColor(row.nameText, UI.COLOR_GOLD)
                row.descText:SetText(affix.shortDescription ~= "" and affix.shortDescription or affix.longDescription)
                UI.SetColor(row.descText, UI.COLOR_WHITE)
            end
        end
    end

    for index = rowIndex + 1, #self.nemesisRows do
        self.nemesisRows[index]:Hide()
    end

    self.nemesisContent:SetHeight(math.max(1, rowIndex * AFFIX_ROW_HEIGHT))
end
