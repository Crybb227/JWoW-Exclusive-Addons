JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions

local ERA_NAMES = {
    [0] = "Classic",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
}

function JWA:EraName(era)
    return ERA_NAMES[era] or "Unknown Era"
end

function JWA:HasData()
    return self.state.status ~= nil
end

function JWA:GetOrderedNodes()
    local ordered = {}
    for _, id in ipairs(self.state.nodeOrder) do
        local node = self.state.nodes[id]
        if node then
            table.insert(ordered, node)
        end
    end
    return ordered
end

function JWA:GetOrderedObjectives()
    local ordered = {}
    for _, id in ipairs(self.state.objectiveOrder) do
        local objective = self.state.objectives[id]
        if objective then
            table.insert(ordered, objective)
        end
    end
    return ordered
end

-- Builds a single checklist-ready item list combining server-configured achievement
-- nodes and manually-checked objectives, since both render identically in the UI.
-- Objectives sharing a non-empty "group" are alternatives to each other; the group's
-- satisfaction state (already resolved server-side into item.complete) is shown on
-- every member, with a note on which specific ones this character has done.
function JWA:GetChecklistItems()
    local items = {}
    if self.state.status and self.state.status.levelCap >= 60 and self.state.vanillaOrder
        and #self.state.vanillaOrder > 0 then
        for _, id in ipairs(self.state.vanillaOrder) do
            table.insert(items, self.state.vanilla[id])
        end
        return items
    end

    for _, node in ipairs(self:GetOrderedNodes()) do
        table.insert(items, {
            id = node.id, category = node.category, label = node.label,
            complete = node.complete, group = "", individuallyComplete = node.complete,
            kind = "node",
        })
    end

    for _, objective in ipairs(self:GetOrderedObjectives()) do
        table.insert(items, {
            id = objective.id, category = objective.category, label = objective.label,
            complete = objective.complete, group = objective.group,
            individuallyComplete = objective.individuallyComplete, kind = "objective",
        })
    end

    return items
end

function JWA:GetNodesByCategory()
    local byCategory = {}
    local order = {}

    for _, item in ipairs(self:GetChecklistItems()) do
        local category = item.category or "other"
        if not byCategory[category] then
            byCategory[category] = {}
            table.insert(order, category)
        end
        table.insert(byCategory[category], item)
    end

    return byCategory, order
end

local CATEGORY_LABELS = {
    dungeon = "Dungeons",
    dungeons = "Dungeons",
    raid = "Raids",
    raids = "Raids",
    pvp = "PvP",
    other = "Other",
}

function JWA:CategoryDisplayName(category)
    local lowered = string.lower(category or "other")
    return CATEGORY_LABELS[lowered] or (category ~= "" and category or "Other")
end

-- Nodes whose CatchupCeiling/LevelCap exceed the realm's current level cap are the
-- requirements gating the *next* phase; everything else is "your progress" for the
-- currently active phase/cap.
function JWA:GetNextPhaseNodes()
    local status = self.state.status
    if not status then
        return {}
    end

    local nextPhaseNodes = {}
    for _, node in ipairs(self:GetOrderedNodes()) do
        if node.levelCap > status.levelCap or node.catchupCeiling > status.catchupCeiling then
            table.insert(nextPhaseNodes, node)
        end
    end

    return nextPhaseNodes
end

function JWA:GetCurrentPhaseNodes()
    local status = self.state.status
    if not status then
        return {}
    end

    local currentNodes = {}
    for _, node in ipairs(self:GetOrderedNodes()) do
        if node.levelCap <= status.levelCap and node.catchupCeiling <= status.catchupCeiling then
            table.insert(currentNodes, node)
        end
    end

    return currentNodes
end

function JWA:GetNextPhaseLevelCap()
    local highest = nil
    for _, node in ipairs(self:GetNextPhaseNodes()) do
        if node.levelCap > 0 and (not highest or node.levelCap > highest) then
            highest = node.levelCap
        end
    end

    local status = self.state.status
    if not highest and status and status.nextMilestone and status.nextMilestone > status.levelCap then
        highest = status.nextMilestone
    end

    return highest
end

-- Objectives are manually-checked (no unlock levelCap/catchupCeiling to compare against),
-- so unlike achievement nodes every incomplete objective simply counts toward "what's left".
function JWA:GetIncompleteObjectives()
    local incomplete = {}
    for _, objective in ipairs(self:GetOrderedObjectives()) do
        if not objective.complete then
            table.insert(incomplete, objective)
        end
    end
    return incomplete
end

-- Collapses ungrouped objectives (each its own requirement) and grouped objectives
-- (alternatives; the whole group is one requirement) into a single ordered list of
-- { label, complete, required, memberLabels } entries, one per requirement "slot".
function JWA:GetObjectiveRequirementSlots()
    local slots = {}
    local groupIndex = {}

    for _, objective in ipairs(self:GetOrderedObjectives()) do
        if objective.group == "" then
            table.insert(slots, {
                label = objective.label, complete = objective.complete,
                required = 1, memberLabels = { objective.label },
            })
        else
            local slot = groupIndex[objective.group]
            if not slot then
                slot = { label = nil, complete = objective.complete, required = objective.groupRequired, memberLabels = {} }
                groupIndex[objective.group] = slot
                table.insert(slots, slot)
            end
            table.insert(slot.memberLabels, objective.label)
        end
    end

    for _, slot in ipairs(slots) do
        if not slot.label then
            slot.label = string.format("Complete any %d of: %s", slot.required, table.concat(slot.memberLabels, ", "))
        end
    end

    return slots
end

function JWA:IsPlayerCapped()
    local status = self.state.status
    if not status then
        return false
    end

    return status.playerLevel >= status.levelCap
end

function JWA:GetXPRateKind(rate)
    if rate == 1 then
        return "normal"
    end

    return "catchup"
end

function JWA:GetVanillaSummary()
    if self.state.status and self.state.status.levelCap >= 60 then return self.state.vanillaSummary end
end
