NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

local function liveAuraMatchingEnabled()
    return not NT.db or NT.db.liveAuraMatching ~= false
end

local function unitNameFallbackEnabled()
    return NT.db and NT.db.unitTooltipNameFallback == true
end

local function getNemesisForUnit(unit)
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
        if auraNemesis then
            return auraNemesis
        end
    end

    if unitNameFallbackEnabled() and NT.NameplateAffixes
        and type(NT.NameplateAffixes.GetNemesisForName) == "function" and UnitName then
        return NT.NameplateAffixes:GetNemesisForName(UnitName(unit))
    end

    return nil
end

local function anchorTooltip(tooltip)
    if tooltip and tooltip.ClearAllPoints and tooltip.SetPoint and UIParent then
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -90, 120)
    end
end

local function getBestTooltipUnit(tooltip)
    if tooltip and tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        if unit and UnitExists and UnitExists(unit) then
            tooltip.NemesisTrackerTooltipUnit = unit
            return unit
        end
    end

    if tooltip and tooltip.NemesisTrackerTooltipUnit and UnitExists and UnitExists(tooltip.NemesisTrackerTooltipUnit) then
        return tooltip.NemesisTrackerTooltipUnit
    end

    return nil
end

local function addFallbackTooltipLines(tooltip, nemesis)
    local rank = tonumber(nemesis.rank)

    tooltip:AddLine(" ")
    if rank then
        tooltip:AddLine(
            string.format("NEMESIS - Rank %d%s",
                rank,
                (nemesis.rankTier and nemesis.rankTier ~= "") and (" - " .. nemesis.rankTier) or ""),
            1.0, 0.25, 0.25
        )
    else
        tooltip:AddLine("NEMESIS", 1.0, 0.25, 0.25)
    end
    tooltip:AddLine(string.format("Relation: %s", nemesis.relation or "public"), 0.7, 0.9, 1.0)
    if nemesis.threatClass and nemesis.threatClass ~= "" and nemesis.threatClass ~= "none" then
        tooltip:AddLine("Threat: " .. tostring(nemesis.threatClass), 1.0, 0.82, 0.0)
    end
    if nemesis.rewardClass and nemesis.rewardClass ~= "" and nemesis.rewardClass ~= "none" then
        tooltip:AddLine("Reward: " .. tostring(nemesis.rewardClass), 1.0, 0.82, 0.0)
    end
    if nemesis.affixText and nemesis.affixText ~= "" then
        tooltip:AddLine("Affixes: " .. tostring(nemesis.affixText), 0.92, 0.92, 0.92, true)
    end
end

local function tooltipAlreadyHasNemesisLines(tooltip)
    if not tooltip or not tooltip.GetName or not tooltip.NumLines then
        return false
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return false
    end

    for index = 1, tooltip:NumLines() do
        local leftText = _G[tooltipName .. "TextLeft" .. index]
        local text = leftText and leftText.GetText and leftText:GetText() or nil
        if text and (string.find(text, "NEMESIS", 1, true)
            or string.find(text, "Nemesis Rank", 1, true)
            or text == "Nemesis"
            or text == "Affix Effects") then
            return true
        end
    end

    return false
end

function NT:AddNemesisUnitTooltip(tooltip, unit)
    if NT.db and NT.db.unitTooltips == false then
        return
    end
    if tooltip and tooltip.NemesisTrackerAuraTooltip then
        return
    end

    local nemesis = getNemesisForUnit(unit)
    if not tooltip or not nemesis then
        return
    end

    if tooltipAlreadyHasNemesisLines(tooltip) then
        return
    end

    if NT.AffixUI and type(NT.AffixUI.AddMapStyleNemesisTooltipLines) == "function" then
        NT.AffixUI:AddMapStyleNemesisTooltipLines(tooltip, nemesis)
    elseif NT.AffixUI and type(NT.AffixUI.AddNemesisTooltipLines) == "function" then
        NT.AffixUI:AddNemesisTooltipLines(tooltip, nemesis)
    else
        addFallbackTooltipLines(tooltip, nemesis)
    end

    anchorTooltip(tooltip)
    tooltip:Show()
end

local function onTooltipSetUnit(tooltip)
    if not tooltip then
        return
    end
    if tooltip.NemesisTrackerAuraTooltip then
        return
    end

    local unit = getBestTooltipUnit(tooltip)
    if unit then
        NT:AddNemesisUnitTooltip(tooltip, unit)
    end
end

if GameTooltip and not NT._nemesisUnitTooltipHooked then
    NT._nemesisUnitTooltipHooked = true
    GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self.NemesisTrackerTooltipUnit = nil
        self.NemesisTrackerAuraTooltip = nil
    end)
    GameTooltip:HookScript("OnHide", function(self)
        self.NemesisTrackerTooltipUnit = nil
        self.NemesisTrackerAuraTooltip = nil
    end)
end
