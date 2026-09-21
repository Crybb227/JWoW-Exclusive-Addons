NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.NameplateAffixes = NT.NameplateAffixes or {}
local NPA = NT.NameplateAffixes

local SCAN_INTERVAL = 0.20
local ICON_SPACING = 2
local MAX_AFFIX_ICONS = 6
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function getIconSize()
    if NT.db and tonumber(NT.db.nameplateIconSize) then
        local size = tonumber(NT.db.nameplateIconSize)
        if size < 14 then size = 14 end
        if size > 26 then size = 26 end
        return size
    end
    return 18
end

local function nameplatesEnabled()
    return not NT.db or NT.db.nameplateAffixes ~= false
end

local function nameplateTooltipsEnabled()
    return not NT.db or NT.db.nameplateTooltips ~= false
end

local function nameplateNameFallbackEnabled()
    return NT.db and NT.db.nameplateNameFallback == true
end

local function nameplateUniqueNameFallbackEnabled()
    return NT.db and NT.db.nameplateUniqueNameFallback == true
end

local function liveAuraMatchingEnabled()
    return not NT.db or NT.db.liveAuraMatching ~= false
end

local function trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function normalizeName(name)
    name = trim(name)
    if name == "" then
        return nil
    end
    return string.lower(name)
end

local function normalizeZoneName(name)
    name = normalizeName(name)
    if not name or name == "unknown" then
        return nil
    end
    return name
end

local function getCurrentZoneName()
    if GetRealZoneText then
        local zone = normalizeZoneName(GetRealZoneText())
        if zone then
            return zone
        end
    end
    if GetZoneText then
        return normalizeZoneName(GetZoneText())
    end
    return nil
end

local function getRankStyle(rank)
    if NT.AffixUI and type(NT.AffixUI.GetRankStyle) == "function" then
        return NT.AffixUI:GetRankStyle(rank)
    end

    rank = tonumber(rank) or 1
    if rank >= 5 then
        return { r = 0.85, g = 0.20, b = 1.00, icon = "Interface\\Icons\\Achievement_Boss_LichKing" }
    elseif rank == 4 then
        return { r = 1.00, g = 0.50, b = 0.10, icon = "Interface\\Icons\\INV_Helmet_98" }
    elseif rank == 3 then
        return { r = 1.00, g = 0.82, b = 0.10, icon = "Interface\\Icons\\Ability_Warrior_Challange" }
    elseif rank == 2 then
        return { r = 0.25, g = 0.65, b = 1.00, icon = "Interface\\Icons\\Ability_Rogue_FindWeakness" }
    end
    return { r = 0.25, g = 1.00, b = 0.25, icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" }
end

local function shouldInclude(nemesis, currentZoneName)
    if not nemesis then
        return false
    end
    if NT.ShouldHideNemesis and NT:ShouldHideNemesis(nemesis) then
        return false
    end
    if nemesis.isAlive == false then
        return false
    end
    local nemesisZoneName = normalizeZoneName(nemesis.zoneName)
    if currentZoneName and nemesisZoneName and nemesisZoneName ~= currentZoneName then
        return false
    end
    return normalizeName(nemesis.name) ~= nil
end

local function getMatchScore(nemesis, currentZoneName)
    local score = tonumber(nemesis.lastSeenAt) or 0
    local nemesisZoneName = normalizeZoneName(nemesis.zoneName)
    if currentZoneName and nemesisZoneName == currentZoneName then
        score = score + 1000000000
    end
    if (tonumber(nemesis.affixMask) or 0) > 0 then
        score = score + 1000
    end
    return score
end

function NPA:RebuildNameIndex()
    self.nameIndex = {}
    if not NT.data or not NT.data.nemeses then
        return
    end

    local currentZoneName = getCurrentZoneName()
    for _, nemesis in pairs(NT.data.nemeses) do
        if shouldInclude(nemesis, currentZoneName) then
            local key = normalizeName(nemesis.name)
            local existing = self.nameIndex[key]
            local score = getMatchScore(nemesis, currentZoneName)
            if not existing or score > existing.score then
                self.nameIndex[key] = { nemesis = nemesis, score = score }
            end
        end
    end
end

function NPA:GetNemesisForName(name)
    if not self.nameIndex then
        self:RebuildNameIndex()
    end

    local entry = self.nameIndex and self.nameIndex[normalizeName(name) or ""]
    if not entry then
        return nil
    end
    return entry.nemesis
end

local function findPlateName(frame)
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
            local text = trim(region:GetText())
            if text ~= "" then
                return text
            end
        end
    end
    return nil
end

local function looksLikeNameplate(frame)
    if not frame or not frame.GetChildren or not frame.GetRegions or not frame.IsShown or not frame:IsShown() then
        return false
    end

    local hasStatusBar = false
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            hasStatusBar = true
            break
        end
    end

    return hasStatusBar and findPlateName(frame) ~= nil
end

local function createIcon(parent)
    local size = getIconSize()
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:SetTexture(UNKNOWN_ICON)

    local border = parent:CreateTexture(nil, "OVERLAY")
    border:SetWidth(size + 4)
    border:SetHeight(size + 4)
    border:SetPoint("CENTER", icon, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetVertexColor(1.0, 0.82, 0.0)

    return { icon = icon, border = border }
end

function NPA:CreateOverlay(plate)
    local size = getIconSize()
    local overlay = CreateFrame("Frame", nil, plate)
    overlay:SetWidth((size + ICON_SPACING) * (MAX_AFFIX_ICONS + 1))
    overlay:SetHeight(size + 6)
    overlay:SetPoint("BOTTOM", plate, "TOP", 0, 5)
    overlay:SetFrameLevel((plate:GetFrameLevel() or 0) + 10)
    overlay:EnableMouse(nameplateTooltipsEnabled())
    overlay:SetScript("OnEnter", function(self)
        if not nameplateTooltipsEnabled() or not self.nemesis then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.nemesis.name or "Nemesis", 1.0, 0.25, 0.25)
        GameTooltip:AddLine(string.format("Level %d", tonumber(self.nemesis.level) or 0), 0.92, 0.92, 0.92)
        if NT.AffixUI and type(NT.AffixUI.AddMapStyleNemesisTooltipLines) == "function" then
            NT.AffixUI:AddMapStyleNemesisTooltipLines(GameTooltip, self.nemesis)
        elseif NT.AffixUI and type(NT.AffixUI.AddPowerTooltip) == "function" then
            NT.AffixUI:AddPowerTooltip(GameTooltip, self.nemesis)
        else
            GameTooltip:AddLine(string.format("Rank %d", tonumber(self.nemesis.rank) or 1), 1.0, 0.82, 0.0)
            if self.nemesis.affixText and self.nemesis.affixText ~= "" then
                GameTooltip:AddLine("Affixes: " .. tostring(self.nemesis.affixText), 0.92, 0.92, 0.92, true)
            end
        end
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    overlay.backdrop = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.backdrop:SetPoint("TOPLEFT", overlay, "TOPLEFT", -3, 3)
    overlay.backdrop:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 3, -3)
    overlay.backdrop:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    overlay.backdrop:SetVertexColor(0, 0, 0, 0.55)

    overlay.icons = {}
    for index = 1, MAX_AFFIX_ICONS + 1 do
        local pair = createIcon(overlay)
        if index == 1 then
            pair.icon:SetPoint("LEFT", overlay, "LEFT", 1, 0)
        else
            pair.icon:SetPoint("LEFT", overlay.icons[index - 1].icon, "RIGHT", ICON_SPACING, 0)
        end
        overlay.icons[index] = pair
    end

    overlay:Hide()
    plate.NemesisTrackerNameplateOverlay = overlay
    return overlay
end

function NPA:UpdateOverlay(plate, nemesis)
    local overlay = plate.NemesisTrackerNameplateOverlay or self:CreateOverlay(plate)
    if not nameplatesEnabled() then
        overlay:Hide()
        return
    end
    if not nemesis or not NT.AffixUI or type(NT.AffixUI.GetAffixes) ~= "function" then
        overlay:Hide()
        return
    end

    local size = getIconSize()
    local affixes = NT.AffixUI:GetAffixes(nemesis)
    local rankKnown = nemesis.rankKnown ~= false and tonumber(nemesis.rank) ~= nil
    local style = getRankStyle(nemesis.rank)
    local shown = 0
    overlay.nemesis = nemesis
    overlay:EnableMouse(nameplateTooltipsEnabled())

    if rankKnown then
        shown = shown + 1
        overlay.icons[shown].icon:SetTexture(style.icon or UNKNOWN_ICON)
        overlay.icons[shown].border:SetVertexColor(style.r or 1, style.g or 1, style.b or 1)
    end

    for _, definition in ipairs(affixes) do
        if shown >= MAX_AFFIX_ICONS + 1 then
            break
        end
        shown = shown + 1
        overlay.icons[shown].icon:SetTexture(definition.icon or UNKNOWN_ICON)
        overlay.icons[shown].border:SetVertexColor(1.0, 0.82, 0.0)
    end

    if shown <= 1 and (tonumber(nemesis.affixMask) or 0) <= 0 then
        overlay:Hide()
        return
    end

    local width = shown * size + math.max(shown - 1, 0) * ICON_SPACING + 2
    overlay:SetHeight(size + 6)
    overlay:SetWidth(width)
    for index, pair in ipairs(overlay.icons) do
        pair.icon:SetWidth(size)
        pair.icon:SetHeight(size)
        pair.border:SetWidth(size + 4)
        pair.border:SetHeight(size + 4)
        if index <= shown then
            pair.icon:Show()
            pair.border:Show()
        else
            pair.icon:Hide()
            pair.border:Hide()
        end
    end
    overlay:Show()
end

function NPA:GetNemesisForExactUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return nil
    end

    if NT.GetUnitSnapshot then
        local snapshot = NT:GetUnitSnapshot(unit)
        if snapshot then
            return snapshot
        end
    end

    if liveAuraMatchingEnabled() and NT.AffixUI and type(NT.AffixUI.BuildNemesisFromUnitAuras) == "function" then
        local auraNemesis = NT.AffixUI:BuildNemesisFromUnitAuras(unit)
        if shouldInclude(auraNemesis, getCurrentZoneName()) then
            return auraNemesis
        end
    end

    return nil
end

function NPA:BuildExactUnitIndex()
    local index = {}
    local units = { "target", "mouseover", "focus", "targettarget" }
    for _, unit in ipairs(units) do
        local nemesis = self:GetNemesisForExactUnit(unit)
        if nemesis and UnitName then
            local key = normalizeName(UnitName(unit))
            if key then
                index[key] = index[key] or {}
                table.insert(index[key], {
                    unit = unit,
                    nemesis = nemesis,
                })
            end
        end
    end
    return index
end

local function countVisiblePlateNames(frames)
    local counts = {}
    for _, frame in ipairs(frames) do
        if looksLikeNameplate(frame) then
            local key = normalizeName(findPlateName(frame))
            if key then
                counts[key] = (counts[key] or 0) + 1
            end
        end
    end
    return counts
end

local function getExactPlateMatch(plate, nameKey, visibleNameCounts, exactUnitIndex)
    local candidates = exactUnitIndex and exactUnitIndex[nameKey]
    if not candidates or #candidates == 0 then
        return nil
    end

    if (visibleNameCounts[nameKey] or 0) == 1 and #candidates == 1 then
        return candidates[1].nemesis
    end
    return nil
end

function NPA:Scan()
    if not WorldFrame or not WorldFrame.GetChildren then
        return
    end

    if not nameplatesEnabled() then
        self:HideAll()
        return
    end

    local frames = { WorldFrame:GetChildren() }
    local visibleNameCounts = countVisiblePlateNames(frames)
    local exactUnitIndex = self:BuildExactUnitIndex()

    self:RebuildNameIndex()

    for _, frame in ipairs(frames) do
        if looksLikeNameplate(frame) then
            local nameKey = normalizeName(findPlateName(frame))
            local nemesis = getExactPlateMatch(frame, nameKey, visibleNameCounts, exactUnitIndex)
            if not nemesis and nameplateUniqueNameFallbackEnabled() and nameKey and
                (visibleNameCounts[nameKey] or 0) == 1 then
                nemesis = self:GetNemesisForName(nameKey)
            end
            if not nemesis and nameplateNameFallbackEnabled() then
                nemesis = self:GetNemesisForName(nameKey)
            end
            self:UpdateOverlay(frame, nemesis)
        elseif frame and frame.NemesisTrackerNameplateOverlay then
            frame.NemesisTrackerNameplateOverlay:Hide()
        end
    end
end

function NPA:HideAll()
    if not WorldFrame or not WorldFrame.GetChildren then
        return
    end

    local frames = { WorldFrame:GetChildren() }
    for _, frame in ipairs(frames) do
        if frame and frame.NemesisTrackerNameplateOverlay then
            frame.NemesisTrackerNameplateOverlay:Hide()
        end
    end
end

function NPA:RefreshConfig()
    self.nameIndex = nil
    if nameplatesEnabled() then
        self:Scan()
    else
        self:HideAll()
    end
end

function NPA:InstallDataWrappers()
    if self.dataWrapped then
        return
    end
    self.dataWrapped = true

    if type(NT.UpsertNemesisFromFields) == "function" then
        local originalUpsert = NT.UpsertNemesisFromFields
        NT.UpsertNemesisFromFields = function(self, ...)
            local result = originalUpsert(self, ...)
            NPA.nameIndex = nil
            return result
        end
    end

    if type(NT.RemoveNemesis) == "function" then
        local originalRemove = NT.RemoveNemesis
        NT.RemoveNemesis = function(self, ...)
            local result = originalRemove(self, ...)
            NPA.nameIndex = nil
            return result
        end
    end
end

function NPA:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:InstallDataWrappers()

    self.frame = self.frame or CreateFrame("Frame", "NemesisTrackerNameplateAffixesFrame", UIParent)
    self.frame.elapsed = 0
    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
        if frame.elapsed < SCAN_INTERVAL then
            return
        end
        frame.elapsed = 0
        NPA:Scan()
    end)
end

NPA:Initialize()
