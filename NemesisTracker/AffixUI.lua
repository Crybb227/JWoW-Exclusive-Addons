NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.AffixUI = NT.AffixUI or {}
local AUI = NT.AffixUI

AUI.definitions = {
    { key = "Vampiric", bit = 1, auraSpell = 71432, icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02", description = "Heals for 50% of damage dealt." },
    { key = "Swift", bit = 2, auraSpell = 54842, icon = "Interface\\Icons\\Ability_Rogue_Sprint", description = "+50% run speed and 30% shorter attack time." },
    { key = "Juggernaut", bit = 4, auraSpell = 43827, icon = "Interface\\Icons\\Ability_Warrior_ShieldMastery", description = "Immune to most crowd control and knockback effects.", longDescription = "Immune to snares, roots, fear, stun, sleep, charm, sap, polymorph, disorient, freeze, horror, banish, and knockback." },
    { key = "Savage", bit = 8, auraSpell = 41033, icon = "Interface\\Icons\\Ability_Druid_Rake", description = "+25% damage dealt." },
    { key = "Spellward", bit = 16, auraSpell = 37658, icon = "Interface\\Icons\\Spell_Holy_SpellWarding", description = "Takes 30% less spell damage." },
    { key = "Enraged", bit = 32, auraSpell = 8599, icon = "Interface\\Icons\\Ability_Warrior_InnerRage", description = "At 30% health or lower, deals 50% more damage.", configurable = true },
    { key = "Regenerating", bit = 64, auraSpell = 67713, icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater", description = "Restores 3% max health every 5 seconds while injured.", configurable = true },
}

AUI.byName = {}
AUI.byAuraSpell = {}
for _, definition in ipairs(AUI.definitions) do
    AUI.byName[string.lower(definition.key)] = definition
    if definition.auraSpell and definition.auraSpell > 0 then
        AUI.byAuraSpell[definition.auraSpell] = definition
    end
end

local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local POWER_ICON = "Interface\\Icons\\Achievement_Boss_LichKing"
local NAMEPLATE_SCAN_INTERVAL = 0.25

local RANK_STYLES = {
    [1] = { r = 0.25, g = 1.00, b = 0.25, label = "Marked", tooltip = "Low threat Nemesis. Still stronger than a normal creature.", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
    [2] = { r = 0.25, g = 0.65, b = 1.00, label = "Hunted", tooltip = "Moderate threat Nemesis. Better rewards and a nastier kit.", icon = "Interface\\Icons\\Ability_Rogue_FindWeakness" },
    [3] = { r = 1.00, g = 0.82, b = 0.10, label = "Dangerous", tooltip = "High threat Nemesis. Usually carries two affixes.", icon = "Interface\\Icons\\Ability_Warrior_Challange" },
    [4] = { r = 1.00, g = 0.50, b = 0.10, label = "Deadly", tooltip = "Very high threat Nemesis. Treat it like a mini-boss.", icon = "Interface\\Icons\\INV_Helmet_98" },
    [5] = { r = 0.85, g = 0.20, b = 1.00, label = "Legendary", tooltip = "Extreme threat Nemesis. Maximum reward, maximum pain.", icon = "Interface\\Icons\\Achievement_Boss_LichKing" },
}

local function trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function hasBit(mask, bitValue)
    mask = tonumber(mask) or 0
    bitValue = tonumber(bitValue) or 0
    if bitValue <= 0 then
        return false
    end
    return math.floor(mask / bitValue) % 2 >= 1
end

local function copyDefinition(definition)
    local result = {}
    for key, value in pairs(definition or {}) do
        result[key] = value
    end
    return result
end

local function colorize(text, r, g, b)
    local cr = math.floor((r or 1) * 255)
    local cg = math.floor((g or 1) * 255)
    local cb = math.floor((b or 1) * 255)
    return string.format("|cff%02x%02x%02x%s|r", cr, cg, cb, text or "")
end

local function getRankStyle(rank)
    rank = tonumber(rank) or 1
    if rank < 1 then rank = 1 end
    if rank > 5 then rank = 5 end
    return RANK_STYLES[rank] or RANK_STYLES[1]
end

function AUI:GetRankStyle(rank)
    return getRankStyle(rank)
end

local function applyBorderColor(texture, style)
    if texture and texture.SetVertexColor and style then
        texture:SetVertexColor(style.r or 1, style.g or 1, style.b or 1)
    end
end

local function applyBackdropColor(frame, style)
    if frame and frame.SetBackdropColor and style then
        frame:SetBackdropColor((style.r or 1) * 0.20, (style.g or 1) * 0.20, (style.b or 1) * 0.20, 0.75)
        frame:SetBackdropBorderColor(style.r or 1, style.g or 1, style.b or 1, 0.90)
    end
end

local function countTableEntries(tbl)
    local count = 0
    for _ in ipairs(tbl or {}) do
        count = count + 1
    end
    return count
end

function AUI:WithServerMetadata(definition)
    if not definition then
        return nil
    end

    local meta = nil
    if NT.affixServerMeta and tonumber(definition.bit) and tonumber(definition.bit) > 0 then
        meta = NT.affixServerMeta[tonumber(definition.bit)]
    end
    if not meta and NT.affixServerMetaByName and definition.key then
        meta = NT.affixServerMetaByName[string.lower(definition.key)]
    end
    if not meta then
        return definition
    end

    local merged = copyDefinition(definition)
    if meta.key and meta.key ~= "" then merged.key = meta.key end
    if meta.description and meta.description ~= "" then merged.description = meta.description end
    if meta.longDescription and meta.longDescription ~= "" then merged.longDescription = meta.longDescription end
    if meta.auraSpell and meta.auraSpell > 0 then merged.auraSpell = meta.auraSpell end
    merged.serverProvided = true
    return merged
end

function AUI:GetLocalDefinitionForServerMeta(meta)
    if not meta then
        return nil
    end

    local bitValue = tonumber(meta.bit) or 0
    if bitValue > 0 then
        for _, definition in ipairs(self.definitions or {}) do
            if tonumber(definition.bit) == bitValue then
                return definition
            end
        end
    end

    if meta.key and self.byName then
        return self.byName[string.lower(meta.key)]
    end

    return nil
end

function AUI:GetAffixesForUnit(unit)
    local result = {}
    if not unit or not UnitExists or not UnitExists(unit) or not UnitAura then
        return result
    end

    local seen = {}
    for index = 1, 40 do
        local name, _, icon, _, _, _, _, _, _, _, spellId = UnitAura(unit, index, "HELPFUL")
        if not name then
            break
        end

        local definition = nil
        local matchedByAuraSpell = false
        spellId = tonumber(spellId) or 0
        if spellId > 0 and NT.affixServerMetaByAura then
            definition = NT.affixServerMetaByAura[spellId]
            matchedByAuraSpell = definition ~= nil
        end
        if not definition and spellId > 0 and self.byAuraSpell then
            definition = self.byAuraSpell[spellId]
            matchedByAuraSpell = definition ~= nil
        end
        if not definition and NT.affixServerMetaByName then
            definition = NT.affixServerMetaByName[string.lower(name)]
        end

        if definition and not seen[definition.bit or definition.key or name] then
            local copy = self:WithServerMetadata(definition) or definition
            if not matchedByAuraSpell and icon and icon ~= "" then
                copy.icon = icon
            end
            table.insert(result, copy)
            seen[definition.bit or definition.key or name] = true
        end
    end

    return result
end

function AUI:BuildNemesisFromUnitAuras(unit)
    local affixes = self:GetAffixesForUnit(unit)
    if #affixes == 0 then
        return nil
    end

    local affixMask = 0
    local names = {}
    for _, definition in ipairs(affixes) do
        affixMask = affixMask + (tonumber(definition.bit) or 0)
        table.insert(names, definition.key or "Affix")
    end

    return {
        name = UnitName and UnitName(unit) or "Nemesis",
        level = UnitLevel and UnitLevel(unit) or 0,
        rank = nil,
        rankKnown = false,
        rankTier = "",
        affixMask = affixMask,
        affixText = table.concat(names, ", "),
        threatClass = "none",
        rewardClass = "none",
        lastSeenAt = NT.GetNow and NT:GetNow() or 0,
        liveAuraMatch = true,
    }
end

function AUI:GetAffixes(nemesis)
    local result = {}
    if not nemesis then
        return result
    end

    local seen = {}
    local mask = tonumber(nemesis.affixMask) or 0
    if mask > 0 then
        for _, definition in ipairs(self.definitions) do
            if hasBit(mask, definition.bit) then
                table.insert(result, self:WithServerMetadata(definition))
                seen[string.lower(definition.key)] = true
            end
        end
    end

    local text = tostring(nemesis.affixText or "")
    if text ~= "" and string.lower(text) ~= "none" then
        for token in string.gmatch(text, "[^,]+") do
            local name = trim(token)
            local lowerName = string.lower(name)
            if name ~= "" and not seen[lowerName] then
                local definition = self.byName[lowerName]
                if definition then
                    table.insert(result, self:WithServerMetadata(definition))
                else
                    local serverMeta = NT.affixServerMetaByName and NT.affixServerMetaByName[lowerName] or nil
                    if serverMeta then
                        table.insert(result, {
                            key = serverMeta.key or name,
                            bit = serverMeta.bit or 0,
                            icon = UNKNOWN_ICON,
                            description = serverMeta.description or "Nemesis affix.",
                            longDescription = serverMeta.longDescription or serverMeta.description or "Nemesis affix.",
                            serverProvided = true,
                        })
                    else
                        table.insert(result, {
                            key = name,
                            bit = 0,
                            icon = UNKNOWN_ICON,
                            description = "Nemesis affix. Effect details are not known by this addon version.",
                        })
                    end
                end
                seen[lowerName] = true
            end
        end
    end

    return result
end

function AUI:GetNemesisBySpawnId(spawnId)
    spawnId = tonumber(spawnId)
    if not spawnId or not NT.data or not NT.data.nemeses then
        return nil
    end
    return NT.data.nemeses[spawnId]
end

function AUI:AddAffixTooltip(tooltip, definition, includeConfigNote)
    if not tooltip or not definition then
        return
    end
    tooltip:AddLine(definition.key or "Nemesis Affix", 1.0, 0.82, 0.0)
    tooltip:AddLine(definition.longDescription or definition.description or "", 0.92, 0.92, 0.92, true)
    if includeConfigNote and definition.configurable and not definition.serverProvided then
        tooltip:AddLine("Server values may be changed in mod_nemesis_system.conf.", 0.65, 0.8, 1.0, true)
    end
end

function AUI:GetAffixByAuraSpell(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then
        return nil
    end

    local serverMeta = nil
    if NT.affixServerMetaByAura then
        serverMeta = NT.affixServerMetaByAura[spellId]
    end

    local definition = nil
    if serverMeta then
        definition = self:GetLocalDefinitionForServerMeta(serverMeta)
        if definition then
            return self:WithServerMetadata(definition)
        end

        return serverMeta
    end

    if not definition and self.byAuraSpell then
        definition = self.byAuraSpell[spellId]
    end
    if not definition then
        return nil
    end

    return self:WithServerMetadata(definition)
end

local setMarkerAuraButtonIcon

local function installMarkerAuraTooltipHooks()
    if AUI.markerAuraTooltipHooksInstalled or not GameTooltip or not hooksecurefunc then
        return
    end
    AUI.markerAuraTooltipHooksInstalled = true

    local function rewriteTooltipForAura(tooltip, unit, index, filter)
        if not tooltip or not unit or not index or not UnitAura then
            return
        end

        local _, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, index, filter or "HELPFUL")
        local definition = AUI:GetAffixByAuraSpell(spellId)
        if not definition then
            return
        end

        tooltip.NemesisTrackerAuraTooltip = true
        tooltip.NemesisTrackerTooltipUnit = nil

        if tooltip.ClearLines then
            tooltip:ClearLines()
        end

        if tooltip.SetText then
            tooltip:SetText("Nemesis Affix: " .. tostring(definition.key or "Affix"), 1.0, 0.82, 0.0)
        else
            tooltip:AddLine("Nemesis Affix: " .. tostring(definition.key or "Affix"), 1.0, 0.82, 0.0)
        end
        tooltip:AddLine(tostring(definition.longDescription or definition.description or "Nemesis affix."), 0.92, 0.92, 0.92, true)
        tooltip:AddLine("Marker aura used by Nemesis Tracker.", 0.65, 0.8, 1.0, true)
        tooltip:Show()
    end

    if GameTooltip.SetUnitAura then
        hooksecurefunc(GameTooltip, "SetUnitAura", rewriteTooltipForAura)
    end
    if GameTooltip.SetUnitBuff then
        hooksecurefunc(GameTooltip, "SetUnitBuff", function(tooltip, unit, index, filter)
            rewriteTooltipForAura(tooltip, unit, index, filter or "HELPFUL")
        end)
    end
end

local function getAuraButtonIcon(button)
    if not button then
        return nil
    end

    if button.icon and button.icon.SetTexture then
        return button.icon
    end
    if button.Icon and button.Icon.SetTexture then
        return button.Icon
    end
    if button.texture and button.texture.SetTexture then
        return button.texture
    end

    local buttonName = button.GetName and button:GetName() or nil
    if buttonName then
        local icon = _G[buttonName .. "Icon"] or _G[buttonName .. "Texture"]
        if icon and icon.SetTexture then
            return icon
        end
    end

    if button.GetRegions then
        local regions = { button:GetRegions() }
        for _, region in ipairs(regions) do
            if region.SetTexture and region.GetTexture then
                return region
            end
        end
    end

    return nil
end

setMarkerAuraButtonIcon = function(button, texturePath)
    if not button or not texturePath or texturePath == "" then
        return
    end

    local icon = getAuraButtonIcon(button)
    if not button.ntAffixIconOverlay then
        button.ntAffixIconOverlay = button:CreateTexture(nil, "OVERLAY")
        if icon then
            button.ntAffixIconOverlay:SetAllPoints(icon)
        else
            button.ntAffixIconOverlay:SetAllPoints(button)
        end
    elseif icon and button.ntAffixIconOverlay.ClearAllPoints then
        button.ntAffixIconOverlay:ClearAllPoints()
        button.ntAffixIconOverlay:SetAllPoints(icon)
    end

    button.ntAffixIconOverlay:SetTexture(texturePath)
    button.ntAffixIconOverlay:Show()

    if button.ntAffixIconOverlayFrame then
        button.ntAffixIconOverlayFrame:Hide()
    end
end

local function clearMarkerAuraButtonIcon(button)
    if button and button.ntAffixIconOverlay then
        button.ntAffixIconOverlay:Hide()
    end
    if button and button.ntAffixIconOverlayFrame then
        button.ntAffixIconOverlayFrame:Hide()
    end
end

local function getOrCreateFrameAuraOverlay(frameName, index)
    if not frameName or not index or not UIParent then
        return nil
    end

    AUI.markerAuraFallbackFrames = AUI.markerAuraFallbackFrames or {}
    AUI.markerAuraFallbackFrames[frameName] = AUI.markerAuraFallbackFrames[frameName] or {}

    local frame = AUI.markerAuraFallbackFrames[frameName][index]
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(10000)
        frame:SetWidth(18)
        frame:SetHeight(18)
        frame.icon = frame:CreateTexture(nil, "OVERLAY")
        frame.icon:SetAllPoints(frame)
        AUI.markerAuraFallbackFrames[frameName][index] = frame
    end

    return frame
end

local function setFrameAuraFallbackIcon(frameName, index, texturePath)
    local frame = getOrCreateFrameAuraOverlay(frameName, index)
    local parent = frameName and _G[frameName] or nil
    if not frame or not parent or not texturePath or texturePath == "" then
        if frame then
            frame:Hide()
        end
        return
    end

    frame:ClearAllPoints()
    if frameName == "FocusFrame" then
        frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5 + ((index - 1) * 18), 28)
    else
        frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 5 + ((index - 1) * 18), 28)
    end
    frame.icon:SetTexture(texturePath)
    frame:Show()
end

local function clearFrameAuraFallbackIcon(frameName, index)
    local frame = AUI.markerAuraFallbackFrames
        and AUI.markerAuraFallbackFrames[frameName]
        and AUI.markerAuraFallbackFrames[frameName][index]
    if frame then
        frame:Hide()
    end
end

local function updateMarkerAuraIconsForUnit(unit, frameName)
    if not unit or not frameName then
        return
    end

    if not unit or not UnitExists or not UnitExists(unit) or not UnitAura then
        return
    end

    local maxBuffs = MAX_TARGET_BUFFS or 32
    for index = 1, maxBuffs do
        local button = _G[frameName .. "Buff" .. index]
        local _, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, index, "HELPFUL")
        if not spellId then
            if button then
                clearMarkerAuraButtonIcon(button)
            end
            clearFrameAuraFallbackIcon(frameName, index)
            break
        end

        local definition = AUI:GetAffixByAuraSpell(spellId)
        if definition and definition.icon and definition.icon ~= "" then
            if button then
                setMarkerAuraButtonIcon(button, definition.icon)
            end
            clearFrameAuraFallbackIcon(frameName, index)
        else
            if button then
                clearMarkerAuraButtonIcon(button)
            end
            clearFrameAuraFallbackIcon(frameName, index)
        end
    end
end

local function updateMarkerAuraIconsForFrame(frame, fallbackUnit, fallbackFrameName)
    if not frame or not frame.GetName then
        updateMarkerAuraIconsForUnit(fallbackUnit, fallbackFrameName)
        return
    end

    updateMarkerAuraIconsForUnit(frame.unit or fallbackUnit, frame:GetName() or fallbackFrameName)
end

function AUI:RefreshMarkerAuraIcons()
    updateMarkerAuraIconsForFrame(TargetFrame, "target", "TargetFrame")
    updateMarkerAuraIconsForFrame(FocusFrame, "focus", "FocusFrame")
end

local function installMarkerAuraIconHooks()
    if AUI.markerAuraIconHooksInstalled or not hooksecurefunc then
        return
    end
    AUI.markerAuraIconHooksInstalled = true

    if type(TargetFrame_UpdateAuras) == "function" then
        hooksecurefunc("TargetFrame_UpdateAuras", function(frame)
            updateMarkerAuraIconsForFrame(frame or TargetFrame, "target", "TargetFrame")
        end)
    end

    if type(FocusFrame_UpdateAuras) == "function" then
        hooksecurefunc("FocusFrame_UpdateAuras", function(frame)
            updateMarkerAuraIconsForFrame(frame or FocusFrame, "focus", "FocusFrame")
        end)
    end

    local frame = CreateFrame and CreateFrame("Frame")
    if frame and frame.RegisterEvent then
        local elapsedSinceRefresh = 0
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("UNIT_AURA")
        frame:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_TARGET_CHANGED" or unit == "target" or unit == "focus" then
                AUI:RefreshMarkerAuraIcons()
            end
        end)
        frame:SetScript("OnUpdate", function(_, elapsed)
            elapsedSinceRefresh = elapsedSinceRefresh + (elapsed or 0)
            if elapsedSinceRefresh < 0.05 then
                return
            end
            elapsedSinceRefresh = 0
            AUI:RefreshMarkerAuraIcons()
        end)
    end
end

function AUI:AddPowerTooltip(tooltip, nemesis)
    if not tooltip or not nemesis then
        return
    end

    local rank = tonumber(nemesis.rank)
    local rankKnown = nemesis.rankKnown ~= false and rank ~= nil
    rank = rank or 1
    local style = getRankStyle(rank)
    local affixes = self:GetAffixes(nemesis)

    if rankKnown then
        tooltip:AddLine(string.format("Nemesis Rank %d - %s", rank, nemesis.rankTier or style.label), style.r, style.g, style.b)
        tooltip:AddLine(style.tooltip or "Dangerous Nemesis creature.", 0.92, 0.92, 0.92, true)
    else
        tooltip:AddLine("Nemesis", 1.0, 0.82, 0.0)
        tooltip:AddLine("Rank unknown until the server snapshot arrives.", 0.92, 0.92, 0.92, true)
    end
    if #affixes == 0 then
        tooltip:AddLine("Affixes: None", 0.75, 0.75, 0.75)
    else
        tooltip:AddLine(string.format("Affixes: %d", #affixes), 1.0, 0.82, 0.0)
        for _, definition in ipairs(affixes) do
            local icon = definition.icon or UNKNOWN_ICON
            tooltip:AddLine(
                string.format("|T%s:16:16:0:0|t |cffffffff%s|r", icon, definition.key or "Affix"),
                1.0, 0.82, 0.0
            )
            tooltip:AddLine(
                "  " .. tostring(definition.longDescription or definition.description or "Effect unknown."),
                0.92, 0.92, 0.92, true
            )
        end
    end
    if nemesis.threatClass and nemesis.threatClass ~= "" then
        tooltip:AddLine("Threat: " .. tostring(nemesis.threatClass), 1.0, 0.82, 0.0)
    end
    if nemesis.rewardClass and nemesis.rewardClass ~= "" then
        tooltip:AddLine("Reward: " .. tostring(nemesis.rewardClass), 1.0, 0.82, 0.0)
    end
    if nemesis.zoneName and nemesis.zoneName ~= "" then
        tooltip:AddLine("Zone: " .. tostring(nemesis.zoneName), 0.92, 0.92, 0.92)
    end
end

function AUI:AddNemesisTooltipLines(tooltip, nemesis)
    if not tooltip or not nemesis then
        return
    end

    local affixes = self:GetAffixes(nemesis)
    local rank = tonumber(nemesis.rank)
    local rankKnown = nemesis.rankKnown ~= false and rank ~= nil
    rank = rank or 1
    local style = getRankStyle(rank)

    tooltip:AddLine(" ")
    if rankKnown then
        tooltip:AddLine(
            string.format("NEMESIS - Rank %d%s",
                rank,
                (nemesis.rankTier and nemesis.rankTier ~= "") and (" - " .. nemesis.rankTier) or ""),
            style.r, style.g, style.b
        )
    else
        tooltip:AddLine("NEMESIS", 1.0, 0.82, 0.0)
    end

    -- Only show fields actually supplied by the Nemesis server/tracker.
    if nemesis.threatClass and nemesis.threatClass ~= "" and nemesis.threatClass ~= "none" then
        tooltip:AddLine("Threat: " .. tostring(nemesis.threatClass), 1.0, 0.82, 0.0)
    end
    if nemesis.rewardClass and nemesis.rewardClass ~= "" and nemesis.rewardClass ~= "none" then
        tooltip:AddLine("Reward: " .. tostring(nemesis.rewardClass), 1.0, 0.82, 0.0)
    end

    if #affixes == 0 then
        tooltip:AddLine("Affixes: None", 0.75, 0.75, 0.75)
        return
    end

    tooltip:AddLine("Affix Effects", 1.0, 0.82, 0.0)
    for _, definition in ipairs(affixes) do
        local icon = definition.icon or UNKNOWN_ICON
        tooltip:AddLine(
            string.format("|T%s:16:16:0:0|t |cffffffff%s|r",
                icon,
                definition.key or "Affix"),
            1.0, 0.82, 0.0
        )
        tooltip:AddLine(
            "  " .. tostring(definition.longDescription or definition.description or "Effect unknown."),
            0.92, 0.92, 0.92, true
        )
    end
end

function AUI:AddMapStyleNemesisTooltipLines(tooltip, nemesis)
    if not tooltip or not nemesis then
        return
    end

    local affixes = self:GetAffixes(nemesis)
    local rank = tonumber(nemesis.rank)
    local rankKnown = nemesis.rankKnown ~= false and rank ~= nil

    if rankKnown then
        local style = getRankStyle(rank)
        tooltip:AddLine(string.format("Nemesis Rank %d - %s", rank, nemesis.rankTier or style.label), 1.0, 0.82, 0.0)
    else
        tooltip:AddLine("Nemesis", 1.0, 0.82, 0.0)
    end

    if #affixes == 0 then
        tooltip:AddLine("Affixes: None", 0.75, 0.75, 0.75)
        return
    end

    tooltip:AddLine("Affix Effects", 1.0, 0.82, 0.0)
    for _, definition in ipairs(affixes) do
        local icon = definition.icon or UNKNOWN_ICON
        tooltip:AddLine(
            string.format("|T%s:16:16:0:0|t |cffffffff%s|r",
                icon,
                definition.key or "Affix"),
            1.0, 0.82, 0.0
        )
        tooltip:AddLine(
            "  " .. tostring(definition.longDescription or definition.description or "Effect unknown."),
            0.92, 0.92, 0.92, true
        )
    end
end

local function createIconButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(size)
    button:SetHeight(size)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon:SetTexture(UNKNOWN_ICON)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints(button)
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button:SetScript("OnEnter", function(self)
        if not self.affixDefinition then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        AUI:AddAffixTooltip(GameTooltip, self.affixDefinition, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    return button
end

local function createPowerButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(size)
    button:SetHeight(size)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon:SetTexture(POWER_ICON)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints(button)
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button.rankText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.rankText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.rankText:SetText("1")

    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.glow:SetWidth(size * 1.7)
    button.glow:SetHeight(size * 1.7)
    button.glow:Hide()

    button:SetScript("OnEnter", function(self)
        if not self.nemesis then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        AUI:AddPowerTooltip(GameTooltip, self.nemesis)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    return button
end

function AUI:UpdatePowerButton(button, nemesis)
    if not button or not nemesis then
        if button then button:Hide() end
        return
    end

    local rank = tonumber(nemesis.rank)
    local rankKnown = nemesis.rankKnown ~= false and rank ~= nil
    rank = rank or 1
    local style = getRankStyle(rank)
    button.nemesis = nemesis
    button.icon:SetTexture(style.icon or POWER_ICON)
    button.rankText:SetText(rankKnown and tostring(rank) or "?")
    button.rankText:SetTextColor(style.r, style.g, style.b)
    applyBorderColor(button.border, style)
    if button.glow then
        button.glow:SetVertexColor(style.r, style.g, style.b)
        if rank >= 4 then button.glow:Show() else button.glow:Hide() end
    end
    button:Show()
end

function AUI:CreateTrackerPanel()
    local UI = NT.UI
    if not UI or not UI.frame or not UI.detailHeader or not UI.detailText or self.trackerLabel then
        return
    end

    self.trackerLabel = UI.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.trackerLabel:SetPoint("TOPLEFT", UI.detailHeader, "BOTTOMLEFT", 0, -6)
    self.trackerLabel:SetText("Nemesis Affixes")

    self.trackerNone = UI.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.trackerNone:SetPoint("LEFT", self.trackerLabel, "RIGHT", 8, 0)
    self.trackerNone:SetText("None")

    self.trackerPower = createPowerButton(UI.frame, 30)
    self.trackerPower:SetPoint("TOPLEFT", self.trackerLabel, "BOTTOMLEFT", 0, -4)

    self.trackerIcons = {}
    for index = 1, 7 do
        local icon = createIconButton(UI.frame, 28)
        if index == 1 then
            icon:SetPoint("LEFT", self.trackerPower, "RIGHT", 4, 0)
        else
            icon:SetPoint("LEFT", self.trackerIcons[index - 1], "RIGHT", 3, 0)
        end
        self.trackerIcons[index] = icon
    end

    UI.detailText:ClearAllPoints()
    UI.detailText:SetPoint("TOPLEFT", UI.detailHeader, "BOTTOMLEFT", 0, -56)
    UI.detailText:SetPoint("BOTTOMRIGHT", UI.frame, "BOTTOMRIGHT", -16, 14)
    UI.detailText:SetJustifyH("LEFT")
    UI.detailText:SetJustifyV("TOP")
end

function AUI:RefreshTrackerAffixes(nemesis)
    if not self.trackerLabel then self:CreateTrackerPanel() end
    if not self.trackerLabel then return end

    local affixes = self:GetAffixes(nemesis)
    self.trackerLabel:Show()

    if nemesis then
        self:UpdatePowerButton(self.trackerPower, nemesis)
    elseif self.trackerPower then
        self.trackerPower:Hide()
    end

    if self.trackerNone then
        if #affixes == 0 then
            self.trackerNone:SetText(nemesis and "None" or "No nemesis selected")
            self.trackerNone:Show()
        else
            self.trackerNone:Hide()
        end
    end

    for index, button in ipairs(self.trackerIcons or {}) do
        local definition = affixes[index]
        if definition then
            button.affixDefinition = definition
            button.icon:SetTexture(definition.icon or UNKNOWN_ICON)
            button:Show()
        else
            button.affixDefinition = nil
            button:Hide()
        end
    end
end

function AUI:InstallUIWrappers()
    local UI = NT.UI
    if not UI or self.uiWrapped then return end
    self.uiWrapped = true

    if type(UI.Create) == "function" then
        local originalCreate = UI.Create
        UI.Create = function(self, ...)
            local result = originalCreate(self, ...)
            AUI:CreateTrackerPanel()
            AUI:RefreshTrackerAffixes(NT:GetSelectedNemesis())
            return result
        end
    end

    if type(UI.RefreshDetails) == "function" then
        local originalRefreshDetails = UI.RefreshDetails
        UI.RefreshDetails = function(self, ...)
            local result = originalRefreshDetails(self, ...)
            AUI:RefreshTrackerAffixes(NT:GetSelectedNemesis())
            return result
        end
    end
end

function AUI:Initialize()
    self:InstallUIWrappers()
    installMarkerAuraTooltipHooks()
end

AUI:Initialize()
