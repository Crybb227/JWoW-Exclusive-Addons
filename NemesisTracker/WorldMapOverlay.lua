NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.WorldMapOverlay = NT.WorldMapOverlay or {}
local Overlay = NT.WorldMapOverlay

local PLUGIN_NAME = "NemesisTracker"
local EMPTY = {}

-- WotLK HandyNotes uses the classic raid-target texture cleanly on the world map.
-- Rank 5 gets a skull, while lower ranks use progressively more conspicuous shapes.
local RAID_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RANK_ICONS = {
    [1] = { icon = RAID_TEXTURE, tCoordLeft = 0.25, tCoordRight = 0.50, tCoordTop = 0.00, tCoordBottom = 0.25 }, -- circle
    [2] = { icon = RAID_TEXTURE, tCoordLeft = 0.75, tCoordRight = 1.00, tCoordTop = 0.00, tCoordBottom = 0.25 }, -- triangle
    [3] = { icon = RAID_TEXTURE, tCoordLeft = 0.50, tCoordRight = 0.75, tCoordTop = 0.00, tCoordBottom = 0.25 }, -- diamond
    [4] = { icon = RAID_TEXTURE, tCoordLeft = 0.50, tCoordRight = 0.75, tCoordTop = 0.25, tCoordBottom = 0.50 }, -- cross
    [5] = { icon = RAID_TEXTURE, tCoordLeft = 0.75, tCoordRight = 1.00, tCoordTop = 0.25, tCoordBottom = 0.50 }, -- skull
}

local function chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00NemesisTracker:|r " .. tostring(message))
    end
end

local function getHandyNotes()
    if type(HandyNotes) == "table" and type(HandyNotes.RegisterPluginDB) == "function" then
        return HandyNotes
    end

    if type(LibStub) == "function" then
        local AceAddon = LibStub("AceAddon-3.0", true)
        if AceAddon and type(AceAddon.GetAddon) == "function" then
            local addon = AceAddon:GetAddon("HandyNotes", true)
            if addon and type(addon.RegisterPluginDB) == "function" then
                return addon
            end
        end
    end

    return nil
end

local function normalizeMapFile(value)
    return string.lower(string.gsub(tostring(value or ""), "[^A-Za-z0-9]", ""))
end

local function makeCoord(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end

    local xi = math.floor((x * 10000) + 0.5)
    local yi = math.floor((y * 10000) + 0.5)

    if xi < 0 then xi = 0 elseif xi > 10000 then xi = 10000 end
    if yi < 0 then yi = 0 elseif yi > 10000 then yi = 10000 end

    return (xi * 10000) + yi
end

local function rankIcon(rank)
    rank = tonumber(rank) or 1
    if rank < 1 then rank = 1 end
    if rank > 5 then rank = 5 end
    return RANK_ICONS[rank] or RANK_ICONS[1]
end

local function nemesisMapFile(nemesis)
    if not nemesis or not NT.MapData or type(NT.MapData.GetZone) ~= "function" then
        return nil
    end

    local zone = NT.MapData:GetZone(nemesis.zoneId, nemesis.zoneName)
    return zone and zone.file or nil
end

local function sortCluster(cluster)
    table.sort(cluster, function(a, b)
        if (tonumber(a.rank) or 1) ~= (tonumber(b.rank) or 1) then
            return (tonumber(a.rank) or 1) > (tonumber(b.rank) or 1)
        end
        if (tonumber(a.lastSeenAt) or 0) ~= (tonumber(b.lastSeenAt) or 0) then
            return (tonumber(a.lastSeenAt) or 0) > (tonumber(b.lastSeenAt) or 0)
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
end

function Overlay:IsHandyNotesAvailable()
    return getHandyNotes() ~= nil
end

function Overlay:IsEnabled()
    return NT.db and NT.db.worldMapOverlay == true
end

function Overlay:NotifyUpdate()
    local hn = getHandyNotes()
    if not hn or not self.registered then
        return
    end

    if type(NT.SendMessage) == "function" then
        NT:SendMessage("HandyNotes_NotifyUpdate", PLUGIN_NAME)
    elseif type(hn.UpdateWorldMapPlugin) == "function" then
        pcall(hn.UpdateWorldMapPlugin, hn, PLUGIN_NAME)
    end
end

function Overlay:SetEnabled(enabled, quiet)
    if not NT.db then
        return false
    end

    enabled = enabled == true
    if enabled and not self:IsHandyNotesAvailable() then
        NT.db.worldMapOverlay = false
        if not quiet then
            chat("HandyNotes is required for the normal world-map overlay.")
        end
        return false
    end

    NT.db.worldMapOverlay = enabled
    self:NotifyUpdate()

    if not quiet then
        chat("World map Nemesis overlay " .. (enabled and "|cff00ff00ON|r" or "|cffff5555OFF|r") .. ".")
    end

    return enabled
end

function Overlay:Toggle()
    return self:SetEnabled(not self:IsEnabled(), false)
end

function Overlay:GetNodesForMap(mapFile)
    local nodes = {}
    local wantedMap = normalizeMapFile(mapFile)

    if not self:IsEnabled() or wantedMap == "" or not NT.data or not NT.data.nemeses then
        return nodes
    end

    for _, nemesis in pairs(NT.data.nemeses) do
        local hidden = type(NT.ShouldHideNemesis) == "function" and NT:ShouldHideNemesis(nemesis)
        local file = nemesisMapFile(nemesis)
        local coord = makeCoord(nemesis.mapX, nemesis.mapY)

        if not hidden and file and coord and normalizeMapFile(file) == wantedMap then
            local node = nodes[coord]
            if not node then
                node = {
                    nemeses = {},
                    highestRank = 1,
                    alpha = 1.0,
                }
                nodes[coord] = node
            end

            table.insert(node.nemeses, nemesis)
            node.highestRank = math.max(node.highestRank or 1, tonumber(nemesis.rank) or 1)

            local visibility = 1.0
            if type(NT.GetVisibilityAlpha) == "function" then
                visibility = NT:GetVisibilityAlpha(nemesis) or 1.0
            end
            node.alpha = math.max(node.alpha or 0, visibility)
        end
    end

    for _, node in pairs(nodes) do
        sortCluster(node.nemeses)
    end

    return nodes
end

local Handler = {}

local function iter(nodes, previous)
    if not nodes then
        return nil
    end

    local coord, node = next(nodes, previous)
    if not coord or not node then
        return nil
    end

    local scale = NT.db and tonumber(NT.db.worldMapIconScale) or 1.15
    local alpha = NT.db and tonumber(NT.db.worldMapIconAlpha) or 1.0
    alpha = alpha * (node.alpha or 1.0)

    return coord, nil, rankIcon(node.highestRank), scale, alpha
end

function Handler:GetNodes(mapFile, minimap)
    -- Requested feature is the normal world map, not the minimap.
    if minimap or not Overlay:IsEnabled() then
        return next, EMPTY, nil
    end

    local nodes = Overlay:GetNodesForMap(mapFile)
    Overlay.nodeLookup = Overlay.nodeLookup or {}
    Overlay.nodeLookup[normalizeMapFile(mapFile)] = nodes

    return iter, nodes, nil
end

local function getNode(mapFile, coord)
    local key = normalizeMapFile(mapFile)
    return Overlay.nodeLookup and Overlay.nodeLookup[key] and Overlay.nodeLookup[key][coord] or nil
end

local function addAffixEffects(tooltip, nemesis, compact)
    if not tooltip or not nemesis then
        return
    end

    local affixes = nil
    if NT.AffixUI and type(NT.AffixUI.GetAffixes) == "function" then
        affixes = NT.AffixUI:GetAffixes(nemesis)
    end

    if not affixes or #affixes == 0 then
        tooltip:AddLine("Affixes: " .. tostring(nemesis.affixText or "None"), 0.92, 0.92, 0.92, true)
        return
    end

    tooltip:AddLine("Affix Effects", 1.0, 0.82, 0.0)

    for _, definition in ipairs(affixes) do
        local icon = definition.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        local effect = definition.longDescription or definition.description or "Effect unknown."

        if compact then
            tooltip:AddLine(
                string.format("|T%s:14:14:0:0|t |cffffffff%s|r - %s",
                    icon,
                    definition.key or "Affix",
                    effect),
                0.92, 0.92, 0.92, true
            )
        else
            tooltip:AddLine(
                string.format("|T%s:16:16:0:0|t |cffffffff%s|r",
                    icon,
                    definition.key or "Affix"),
                1.0, 0.82, 0.0
            )
            tooltip:AddLine("  " .. tostring(effect), 0.92, 0.92, 0.92, true)
        end
    end
end

function Handler:OnEnter(mapFile, coord)
    local node = getNode(mapFile, coord)
    if not node or not node.nemeses or #node.nemeses == 0 then
        return
    end

    local tooltip = GameTooltip
    if self.GetParent and self:GetParent() == WorldMapButton and WorldMapTooltip then
        tooltip = WorldMapTooltip
        tooltip:SetOwner(self, "ANCHOR_NONE")
        tooltip:SetPoint("BOTTOMRIGHT", WorldMapButton)
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    if #node.nemeses == 1 then
        local n = node.nemeses[1]
        tooltip:SetText(n.name or "Nemesis", 1.0, 0.25, 0.25)
        tooltip:AddLine(string.format("Level %d", tonumber(n.level) or 0), 0.92, 0.92, 0.92)
        tooltip:AddLine(string.format("Nemesis Rank %d - %s", tonumber(n.rank) or 1, n.rankTier or "Marked"), 1.0, 0.82, 0.0)
        addAffixEffects(tooltip, n, false)
        if n.mapX and n.mapY then
            tooltip:AddLine(string.format("Last seen: %.1f, %.1f", n.mapX * 100, n.mapY * 100), 0.65, 0.80, 1.0)
        end
        if NT.UI and type(NT.UI.FormatLastSeen) == "function" then
            tooltip:AddLine("Seen " .. NT.UI:FormatLastSeen(n.lastSeenAt), 0.75, 0.75, 0.75)
        end
    else
        tooltip:SetText(string.format("%d Nemeses at this location", #node.nemeses), 1.0, 0.25, 0.25)
        for index, n in ipairs(node.nemeses) do
            if index > 6 then
                tooltip:AddLine(string.format("...and %d more", #node.nemeses - 6), 0.75, 0.75, 0.75)
                break
            end
            tooltip:AddLine(string.format("Lv%d R%d %s", tonumber(n.level) or 0, tonumber(n.rank) or 1, n.name or "Nemesis"), 1.0, 0.82, 0.0)
            addAffixEffects(tooltip, n, true)
        end
    end

    if NT.TomTomIntegration and NT.TomTomIntegration:IsAvailable() then
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: Set TomTom waypoint", 0.25, 1.0, 0.25)
    end
    tooltip:AddLine("Right-click: Open in /nt", 0.25, 1.0, 0.25)
    tooltip:Show()
end

function Handler:OnLeave()
    if WorldMapTooltip then
        WorldMapTooltip:Hide()
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Handler:OnClick(button, down, mapFile, coord)
    if down then
        return
    end

    local node = getNode(mapFile, coord)
    local nemesis = node and node.nemeses and node.nemeses[1] or nil
    if not nemesis then
        return
    end

    if button == "LeftButton" then
        if type(NT.SetNemesisWaypoint) == "function" then
            NT:SetNemesisWaypoint(nemesis)
        else
            NT:SelectNemesis(nemesis.spawnId)
        end
        return
    end

    if button == "RightButton" then
        if type(NT.SelectNemesis) == "function" then
            NT:SelectNemesis(nemesis.spawnId)
        end
        if NT.UI and NT.UI.frame and not NT.UI.frame:IsShown() then
            NT.UI.frame:Show()
            if type(NT.UI.RefreshAll) == "function" then
                NT.UI:RefreshAll()
            end
        end
    end
end

local function buildOptions()
    return {
        type = "group",
        name = "NemesisTracker",
        desc = "Nemesis locations on the normal world map.",
        get = function(info)
            return NT.db and NT.db[info.arg]
        end,
        set = function(info, value)
            if not NT.db then
                return
            end

            if info.arg == "worldMapOverlay" then
                Overlay:SetEnabled(value == true, true)
            else
                NT.db[info.arg] = value
            end
            Overlay:NotifyUpdate()
        end,
        args = {
            description = {
                type = "description",
                name = "Show tracked Nemesis last-seen locations on the normal Blizzard world map.",
                order = 0,
            },
            worldMapOverlay = {
                type = "toggle",
                name = "Show Nemesis markers",
                desc = "Overlay tracked Nemesis locations on the normal world map.",
                arg = "worldMapOverlay",
                order = 10,
            },
            worldMapIconScale = {
                type = "range",
                name = "Marker Scale",
                desc = "Size of Nemesis world-map markers.",
                min = 0.50,
                max = 2.00,
                step = 0.05,
                arg = "worldMapIconScale",
                order = 20,
            },
            worldMapIconAlpha = {
                type = "range",
                name = "Marker Alpha",
                desc = "Transparency of Nemesis world-map markers.",
                min = 0.20,
                max = 1.00,
                step = 0.05,
                arg = "worldMapIconAlpha",
                order = 30,
            },
        },
    }
end

function Overlay:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    if NT.db then
        if NT.db.worldMapOverlay == nil then NT.db.worldMapOverlay = false end
        if NT.db.worldMapIconScale == nil then NT.db.worldMapIconScale = 1.15 end
        if NT.db.worldMapIconAlpha == nil then NT.db.worldMapIconAlpha = 1.00 end
    end

    local hn = getHandyNotes()
    if not hn then
        self.registered = false
        return
    end

    local ok = pcall(hn.RegisterPluginDB, hn, PLUGIN_NAME, Handler, buildOptions())
    self.registered = ok == true
    self.handyNotes = hn
end

-- Add /nt as the short alias while preserving /ntrack and /nemesistracker.
local originalOnInitialize = NT.OnInitialize
if type(originalOnInitialize) == "function" and not NT._ntAliasWrapped then
    NT._ntAliasWrapped = true
    NT.OnInitialize = function(self, ...)
        local result = originalOnInitialize(self, ...)
        self:RegisterChatCommand("nt", "SlashCommand")
        Overlay:Initialize()
        return result
    end
end

-- Extend the existing slash-command surface without replacing its established behavior.
local originalSlashCommand = NT.SlashCommand
if type(originalSlashCommand) == "function" and not NT._worldMapSlashWrapped then
    NT._worldMapSlashWrapped = true

    NT.SlashCommand = function(self, input)
        input = string.lower(tostring(input or ""))
        input = string.gsub(input, "^%s+", "")
        input = string.gsub(input, "%s+$", "")

        local command, argument = string.match(input, "^(%S+)%s*(.*)$")
        if command == "map" or command == "worldmap" then
            if argument == "on" or argument == "1" or argument == "true" then
                Overlay:SetEnabled(true, false)
            elseif argument == "off" or argument == "0" or argument == "false" then
                Overlay:SetEnabled(false, false)
            elseif argument == "status" then
                chat("World map overlay is " .. (Overlay:IsEnabled() and "ON" or "OFF") ..
                    (Overlay:IsHandyNotesAvailable() and "." or " (HandyNotes not loaded)."))
            else
                Overlay:Toggle()
            end
            return
        end

        if command == "help" then
            chat("/nt - open/close NemesisTracker")
            chat("/nt sync - refresh from server and peers")
            chat("/nt peer - peer-only sync")
            chat("/nt map - toggle normal world-map markers")
            chat("/nt map on|off|status")
            return
        end

        return originalSlashCommand(self, input)
    end
end

-- Refresh HandyNotes whenever the underlying sorted Nemesis data changes.
local originalSortNemeses = NT.SortNemeses
if type(originalSortNemeses) == "function" and not NT._worldMapSortWrapped then
    NT._worldMapSortWrapped = true
    NT.SortNemeses = function(self, ...)
        local result = originalSortNemeses(self, ...)
        Overlay:NotifyUpdate()
        return result
    end
end
