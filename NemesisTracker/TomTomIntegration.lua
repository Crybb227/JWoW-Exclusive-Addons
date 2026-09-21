NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.TomTomIntegration = NT.TomTomIntegration or {}
local TTI = NT.TomTomIntegration

local function chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00NemesisTracker:|r " .. tostring(message))
    end
end

TTI.Chat = chat

local function normalizeZoneName(value)
    value = string.lower(tostring(value or ""))
    value = string.gsub(value, "&", "and")
    value = string.gsub(value, "[^%w]", "")
    return value
end

local function sameZoneName(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    return normalizeZoneName(a) == normalizeZoneName(b)
end

function TTI:IsAvailable()
    return type(TomTom) == "table" and
        (type(TomTom.AddZWaypoint) == "function" or type(TomTom.AddWaypointToCurrentZone) == "function")
end

function TTI:ResolveZone(zoneName)
    if not zoneName or zoneName == "" or zoneName == "Unknown" then
        return nil, nil
    end
    if type(GetMapContinents) ~= "function" or type(GetMapZones) ~= "function" then
        return nil, nil
    end

    local continents = { GetMapContinents() }
    for continentIndex = 1, #continents do
        local zones = { GetMapZones(continentIndex) }
        for zoneIndex = 1, #zones do
            if sameZoneName(zones[zoneIndex], zoneName) then
                return continentIndex, zoneIndex
            end
        end
    end

    return nil, nil
end

function TTI:ClearWaypoint()
    if not self.activeWaypoint then
        return
    end

    if type(TomTom) == "table" and type(TomTom.RemoveWaypoint) == "function" then
        pcall(TomTom.RemoveWaypoint, TomTom, self.activeWaypoint)
    end

    self.activeWaypoint = nil
end

function TTI:GetMapCoordinates(nemesis)
    if not nemesis then
        return nil, nil
    end

    local x = tonumber(nemesis.mapX)
    local y = tonumber(nemesis.mapY)
    if not x or not y then
        return nil, nil
    end

    -- NemesisTracker stores normalized zone coordinates (0.0-1.0).
    -- TomTom's Wrath AddZWaypoint API expects percentages (0-100).
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil
    end

    return x * 100, y * 100
end

function TTI:GetTitle(nemesis)
    local name = nemesis and nemesis.name or "Nemesis"
    local rank = nemesis and tonumber(nemesis.rank) or 1
    local affixes = nemesis and nemesis.affixText or nil

    local title = string.format("Nemesis: %s (Rank %d)", name, rank or 1)
    if affixes and affixes ~= "" and affixes ~= "None" then
        title = title .. " - " .. affixes
    end
    return title
end

function TTI:PrintFallback(nemesis, reason)
    local name = nemesis and nemesis.name or "Nemesis"
    local zone = nemesis and nemesis.zoneName or "Unknown"
    local mapX, mapY = self:GetMapCoordinates(nemesis)

    if reason then
        chat(reason)
    end

    if mapX and mapY then
        chat(string.format("%s - %s at %.1f, %.1f", name, zone, mapX, mapY))
        chat(string.format("TomTom command: /way %s %.1f %.1f %s", zone, mapX, mapY, name))
        return
    end

    chat(string.format(
        "%s - %s world coordinates: %.1f, %.1f, %.1f",
        name,
        zone,
        nemesis and nemesis.x or 0,
        nemesis and nemesis.y or 0,
        nemesis and nemesis.z or 0
    ))
end

-- Direct path used by clickable Nemesis chat coordinates. This lets a chat link
-- retain a valid TomTom target even if the Nemesis is killed/removed afterwards.
function TTI:SetResolvedWaypoint(continent, zone, x, y, title, announcement)
    continent = tonumber(continent)
    zone = tonumber(zone)
    x = tonumber(x)
    y = tonumber(y)

    if not continent or continent < 1 or not zone or zone < 1 or
        not x or x < 0 or x > 100 or not y or y < 0 or y > 100 then
        return false
    end

    if not self:IsAvailable() or type(TomTom.AddZWaypoint) ~= "function" then
        chat("TomTom is not installed or is not loaded.")
        return false
    end

    self:ClearWaypoint()

    local ok, uid = pcall(
        TomTom.AddZWaypoint,
        TomTom,
        continent,
        zone,
        x,
        y,
        title or "Nemesis location",
        false, -- persistent
        true,  -- minimap
        true,  -- world map
        nil,   -- callbacks
        true,  -- silent
        true   -- crazy arrow
    )

    if ok and uid then
        self.activeWaypoint = uid
        if announcement ~= false then
            chat(string.format("TomTom waypoint set: %.1f, %.1f", x, y))
        end
        return true
    end

    return false
end

function TTI:SetWaypoint(nemesis)
    if not nemesis then
        return false
    end

    local x, y = self:GetMapCoordinates(nemesis)
    if not x or not y then
        self:PrintFallback(nemesis, "This nemesis does not have usable normalized map coordinates yet.")
        return false
    end

    if not self:IsAvailable() then
        self:PrintFallback(nemesis, "TomTom is not installed or is not loaded.")
        return false
    end

    local title = self:GetTitle(nemesis)
    local continent, zone = self:ResolveZone(nemesis.zoneName)

    if continent and zone and type(TomTom.AddZWaypoint) == "function" then
        local added = self:SetResolvedWaypoint(continent, zone, x, y, title, false)
        if added then
            chat(string.format(
                "TomTom waypoint set: %s - %s %.1f, %.1f",
                nemesis.name or "Nemesis",
                nemesis.zoneName or "Unknown",
                x,
                y
            ))
            return true
        end
    end

    -- Fallback for TomTom-compatible shims or versions where only the current-zone helper is available.
    local currentZone = type(GetRealZoneText) == "function" and GetRealZoneText() or nil
    if sameZoneName(currentZone, nemesis.zoneName) and type(TomTom.AddWaypointToCurrentZone) == "function" then
        self:ClearWaypoint()
        local ok, uid = pcall(TomTom.AddWaypointToCurrentZone, TomTom, x, y, title)
        if ok and uid then
            self.activeWaypoint = uid
            chat(string.format("TomTom waypoint set: %s %.1f, %.1f", nemesis.name or "Nemesis", x, y))
            return true
        end
    end

    self:PrintFallback(nemesis, "TomTom is loaded, but NemesisTracker could not resolve that zone for navigation.")
    return false
end

function NT:SetNemesisWaypoint(nemesis)
    return TTI:SetWaypoint(nemesis or self:GetSelectedNemesis())
end
