NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker
local TTI = NT.TomTomIntegration

NT.ChatLinks = NT.ChatLinks or {}
local CL = NT.ChatLinks

CL.maxRecentLocations = 200
CL.recentLocations = CL.recentLocations or {}

local COORD_PATTERN = "%(([-%d%.]+),%s*([-%d%.]+),%s*([-%d%.]+)%)"
local LINK_TYPE = "nemesiscoord"

local function copyNemesis(nemesis)
    if not nemesis then
        return nil
    end

    return {
        spawnId = tonumber(nemesis.spawnId) or 0,
        name = nemesis.name or "Nemesis",
        rank = tonumber(nemesis.rank) or 1,
        affixText = nemesis.affixText or "None",
        mapId = tonumber(nemesis.mapId) or 0,
        zoneId = tonumber(nemesis.zoneId) or 0,
        zoneName = nemesis.zoneName or "Unknown",
        x = tonumber(nemesis.x) or 0,
        y = tonumber(nemesis.y) or 0,
        z = tonumber(nemesis.z) or 0,
        mapX = tonumber(nemesis.mapX),
        mapY = tonumber(nemesis.mapY),
    }
end

function CL:Remember(nemesis)
    local snapshot = copyNemesis(nemesis)
    if not snapshot then
        return
    end

    table.insert(self.recentLocations, snapshot)
    while #self.recentLocations > self.maxRecentLocations do
        table.remove(self.recentLocations, 1)
    end
end

local function coordinateDistanceSquared(nemesis, x, y, z)
    if not nemesis then
        return math.huge
    end

    local dx = (tonumber(nemesis.x) or 0) - x
    local dy = (tonumber(nemesis.y) or 0) - y
    local dz = (tonumber(nemesis.z) or 0) - z
    return (dx * dx) + (dy * dy) + (dz * dz)
end

function CL:FindByWorldCoordinates(x, y, z, spawnId)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    spawnId = tonumber(spawnId)
    if not x or not y or not z then
        return nil
    end

    if spawnId and spawnId > 0 then
        if NT.data and NT.data.nemeses and NT.data.nemeses[spawnId] then
            return NT.data.nemeses[spawnId]
        end
        for index = #self.recentLocations, 1, -1 do
            local candidate = self.recentLocations[index]
            if tonumber(candidate.spawnId) == spawnId then
                return candidate
            end
        end
    end

    local best = nil
    local bestDistance = math.huge

    if NT.data and NT.data.nemeses then
        for _, candidate in pairs(NT.data.nemeses) do
            local distance = coordinateDistanceSquared(candidate, x, y, z)
            if distance < bestDistance then
                best = candidate
                bestDistance = distance
            end
        end
    end

    for index = #self.recentLocations, 1, -1 do
        local candidate = self.recentLocations[index]
        local distance = coordinateDistanceSquared(candidate, x, y, z)
        if distance < bestDistance then
            best = candidate
            bestDistance = distance
        end
    end

    -- Announcement coordinates and tracker coordinates are normally identical to
    -- one decimal place. Allow a small tolerance for server-side rounding.
    if best and bestDistance <= 100 then -- within 10 yards in 3D
        return best
    end

    return nil
end

function CL:BuildLink(xText, yText, zText)
    local x = tonumber(xText)
    local y = tonumber(yText)
    local z = tonumber(zText)
    if not x or not y or not z then
        return string.format("(%s, %s, %s)", xText, yText, zText)
    end

    local nemesis = self:FindByWorldCoordinates(x, y, z)
    local continent, zone, mapX, mapY, spawnId = 0, 0, 0, 0, 0

    if nemesis and TTI then
        spawnId = tonumber(nemesis.spawnId) or 0
        mapX, mapY = TTI:GetMapCoordinates(nemesis)
        continent, zone = TTI:ResolveZone(nemesis.zoneName)
        continent = tonumber(continent) or 0
        zone = tonumber(zone) or 0
        mapX = tonumber(mapX) or 0
        mapY = tonumber(mapY) or 0
    end

    local payload = string.format(
        "%s:%d:%d:%.4f:%.4f:%.3f:%.3f:%.3f:%d",
        LINK_TYPE,
        continent,
        zone,
        mapX,
        mapY,
        x,
        y,
        z,
        spawnId
    )

    -- Cyan makes the otherwise-yellow server announcement visibly clickable.
    local display = string.format("(%s, %s, %s)", xText, yText, zText)
    return "|cff00ccff|H" .. payload .. "|h" .. display .. "|h|r"
end

function CL:MakeCoordinatesClickable(message)
    if type(message) ~= "string" or message == "" then
        return message
    end

    -- Only touch Nemesis announcements and never process a link twice.
    if not string.find(message, "[Nemesis]", 1, true) or string.find(message, "|H" .. LINK_TYPE .. ":", 1, true) then
        return message
    end

    local changed = string.gsub(message, COORD_PATTERN, function(x, y, z)
        return CL:BuildLink(x, y, z)
    end)

    return changed
end

function CL:HandleLink(link)
    if type(link) ~= "string" then
        return false
    end

    local c, z, mapX, mapY, worldX, worldY, worldZ, spawnId = string.match(
        link,
        "^" .. LINK_TYPE .. ":([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)$"
    )

    if not c then
        return false
    end

    c = tonumber(c) or 0
    z = tonumber(z) or 0
    mapX = tonumber(mapX) or 0
    mapY = tonumber(mapY) or 0
    worldX = tonumber(worldX)
    worldY = tonumber(worldY)
    worldZ = tonumber(worldZ)
    spawnId = tonumber(spawnId) or 0

    -- Best case: the chat link captured a fully resolved TomTom location when
    -- the announcement was printed. This remains valid after the Nemesis dies.
    if TTI and c > 0 and z > 0 and mapX >= 0 and mapY >= 0 then
        local nemesis = self:FindByWorldCoordinates(worldX, worldY, worldZ, spawnId)
        local title = nemesis and TTI:GetTitle(nemesis) or "Nemesis location"
        if TTI:SetResolvedWaypoint(c, z, mapX, mapY, title) then
            return true
        end
    end

    -- Otherwise resolve the raw world coordinates against the live tracker or
    -- our session cache. The cache is populated before a killed Nemesis is removed.
    local nemesis = self:FindByWorldCoordinates(worldX, worldY, worldZ, spawnId)
    if nemesis and NT.SetNemesisWaypoint then
        return NT:SetNemesisWaypoint(nemesis)
    end

    if TTI and TTI.Chat then
        TTI.Chat(string.format(
            "I can see the world coordinates (%.1f, %.1f, %.1f), but I do not have that Nemesis' final zone/map position cached. If it was already claimed, a sync cannot restore it after the server deletes the Nemesis. Final-location server support fixes future claims.",
            worldX or 0,
            worldY or 0,
            worldZ or 0
        ))
    end

    return true
end

-- Cache location snapshots as server/peer updates arrive and immediately before
-- RemoveNemesis deletes a claimed/killed target from the live tracker.
if type(NT.UpsertNemesisFromFields) == "function" and not CL.upsertWrapped then
    CL.upsertWrapped = true
    local originalUpsert = NT.UpsertNemesisFromFields
    NT.UpsertNemesisFromFields = function(self, ...)
        local nemesis = originalUpsert(self, ...)
        if nemesis then
            CL:Remember(nemesis)
        end
        return nemesis
    end
end

if type(NT.RemoveNemesis) == "function" and not CL.removeWrapped then
    CL.removeWrapped = true
    local originalRemove = NT.RemoveNemesis
    NT.RemoveNemesis = function(self, spawnId, reason)
        if self.data and self.data.nemeses and self.data.nemeses[spawnId] then
            CL:Remember(self.data.nemeses[spawnId])
        end
        return originalRemove(self, spawnId, reason)
    end
end

local function nemesisSystemMessageFilter(chatFrame, event, message, ...)
    if type(message) ~= "string" then
        return false
    end

    local changed = CL:MakeCoordinatesClickable(message)
    if changed ~= message then
        return false, changed, ...
    end

    return false
end

if type(ChatFrame_AddMessageEventFilter) == "function" then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", nemesisSystemMessageFilter)
end

-- WotLK 3.3.5a routes chat hyperlink clicks through the global SetItemRef().
-- Blizzard's default SetItemRef tries to pass unknown link types to
-- ItemRefTooltip:SetHyperlink(), which throws "Unknown link type" before a
-- post-hook can run. Intercept our custom link BEFORE Blizzard handles it.
if type(SetItemRef) == "function" and not CL.setItemRefWrapped then
    CL.setItemRefWrapped = true
    local originalSetItemRef = SetItemRef

    SetItemRef = function(link, text, button, chatFrame)
        if type(link) == "string" and
            string.sub(link, 1, string.len(LINK_TYPE) + 1) == LINK_TYPE .. ":" then
            CL:HandleLink(link)
            return
        end

        return originalSetItemRef(link, text, button, chatFrame)
    end
end
