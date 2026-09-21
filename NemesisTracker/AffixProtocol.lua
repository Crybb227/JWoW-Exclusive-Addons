NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

NT.affixServerMeta = NT.affixServerMeta or {}
NT.affixServerMetaByName = NT.affixServerMetaByName or {}
NT.affixServerMetaByAura = NT.affixServerMetaByAura or {}

local function splitPreserveEmpty(message, delimiter)
    local result = {}
    if message == nil then
        return result
    end

    local startIndex = 1
    while true do
        local delimiterIndex = string.find(message, delimiter, startIndex, true)
        if not delimiterIndex then
            table.insert(result, string.sub(message, startIndex))
            break
        end

        table.insert(result, string.sub(message, startIndex, delimiterIndex - 1))
        startIndex = delimiterIndex + string.len(delimiter)
    end

    return result
end

local function refreshAffixUI()
    if NT.UI and NT.UI.RefreshDetails then
        NT.UI:RefreshDetails()
    end
    if NT.AffixUI and NT.AffixUI.RefreshMarkerAuraIcons then
        NT.AffixUI:RefreshMarkerAuraIcons()
    end
    if NT.NameplateAffixes and NT.NameplateAffixes.RefreshConfig then
        NT.NameplateAffixes:RefreshConfig()
    end
    if NT.TrackKnownUnit then
        NT:TrackKnownUnit("target", true)
        NT:TrackKnownUnit("mouseover", true)
    end
end

local function handleUnitSnapshot(self, fields)
    local requestId = fields[3]
    local runtimeGuid = fields[4]
    if not requestId or not runtimeGuid or runtimeGuid == "" then
        return true
    end

    self.data.unitSnapshots = self.data.unitSnapshots or {}
    self.data.pendingUnitQueries = self.data.pendingUnitQueries or {}

    local pending = self.data.pendingUnitQueries[requestId]
    if pending and pending.runtimeGuid and pending.runtimeGuid ~= runtimeGuid then
        self:DebugLog("ignored stale snapshot #" .. tostring(requestId))
        self.data.pendingUnitQueries[requestId] = nil
        return true
    end

    local isNemesis = tonumber(fields[6]) == 1
    local snapshot = {
        requestId = requestId,
        runtimeGuid = runtimeGuid,
        runtimeLow = tonumber(fields[5]) or 0,
        isNemesis = isNemesis,
        spawnId = tonumber(fields[7]) or 0,
        creatureEntry = tonumber(fields[8]) or 0,
        name = fields[9] or "Unknown",
        level = tonumber(fields[10]) or 0,
        rank = isNemesis and tonumber(fields[11]) or nil,
        rankKnown = isNemesis and tonumber(fields[11]) ~= nil or false,
        rankTier = fields[12] or "",
        affixMask = tonumber(fields[13]) or 0,
        affixText = fields[14] or "",
        targetGuid = tonumber(fields[15]) or 0,
        targetName = fields[16] or "",
        relation = fields[17] or "public",
        rewardClass = fields[18] or "none",
        threatClass = fields[19] or "low",
        lastSeenAt = tonumber(fields[20]) or (self.GetNow and self:GetNow() or 0),
        receivedAt = self.GetNow and self:GetNow() or time(),
        lastSeenSource = "server-unit",
    }

    self.data.unitSnapshots[runtimeGuid] = snapshot
    self.data.pendingUnitQueries[requestId] = nil
    self:DebugLog("snapshot #" .. tostring(requestId) .. " received rank=" .. tostring(snapshot.rank or "unknown") .. " affixes=" .. tostring(snapshot.affixText or ""))

    if isNemesis and snapshot.spawnId and snapshot.spawnId > 0 and self.data and self.data.nemeses then
        local existing = self.data.nemeses[snapshot.spawnId] or {}
        for key, value in pairs(snapshot) do
            existing[key] = value
        end
        existing.zoneKey = self.GetZoneKey and self:GetZoneKey(existing.zoneId, existing.zoneName) or existing.zoneKey
        self.data.nemeses[snapshot.spawnId] = existing
        if self.SortNemeses then
            self:SortNemeses()
        end
    end

    if self.RefreshLiveDisplays then
        self:RefreshLiveDisplays()
    else
        refreshAffixUI()
    end
    return true
end

local originalParseServerPayload = NT.ParseServerPayload
if type(originalParseServerPayload) == "function" and not NT._affixProtocolWrapped then
    NT._affixProtocolWrapped = true

    NT.ParseServerPayload = function(self, payload)
        if payload and payload ~= "" then
            local fields = splitPreserveEmpty(payload, ":")
            if fields[1] == "V3" and fields[2] == "UNIT_SNAPSHOT" then
                if handleUnitSnapshot(self, fields) then
                    return
                end
            end

            if fields[1] == "V2" then
                local opcode = fields[2]

                if opcode == "AFFIX_CATALOG_BEGIN" then
                    self.affixServerMeta = {}
                    self.affixServerMetaByName = {}
                    self.affixServerMetaByAura = {}
                    self.affixCatalogExpected = tonumber(fields[3]) or 0
                    self.affixCatalogReceived = 0
                    return
                end

                if opcode == "AFFIX_META" then
                    local bitValue = tonumber(fields[3]) or 0
                    local name = fields[4] or ""
                    local shortDescription = fields[5] or ""
                    local longDescription = fields[6] or ""
                    local auraSpell = tonumber(fields[7]) or 0

                    if name ~= "" then
                        local meta = {
                            bit = bitValue,
                            key = name,
                            auraSpell = auraSpell,
                            description = shortDescription,
                            longDescription = longDescription ~= "" and longDescription or shortDescription,
                            serverProvided = true,
                        }
                        if bitValue > 0 then
                            self.affixServerMeta[bitValue] = meta
                        end
                        self.affixServerMetaByName[string.lower(name)] = meta
                        if auraSpell > 0 then
                            self.affixServerMetaByAura[auraSpell] = meta
                        end
                        self.affixCatalogReceived = (self.affixCatalogReceived or 0) + 1
                    end
                    return
                end

                if opcode == "AFFIX_CATALOG_END" then
                    refreshAffixUI()
                    return
                end

                if opcode == "FINAL_LOCATION" then
                    local snapshot = {
                        spawnId = tonumber(fields[3]) or 0,
                        creatureEntry = tonumber(fields[4]) or 0,
                        name = fields[5] or "Nemesis",
                        mapId = tonumber(fields[6]) or 0,
                        zoneId = tonumber(fields[7]) or 0,
                        zoneName = fields[8] or "Unknown",
                        x = tonumber(fields[9]) or 0,
                        y = tonumber(fields[10]) or 0,
                        z = tonumber(fields[11]) or 0,
                        mapX = tonumber(fields[12]),
                        mapY = tonumber(fields[13]),
                        level = tonumber(fields[14]) or 0,
                        rank = tonumber(fields[15]) or 1,
                        rankTier = fields[16] or "Marked",
                        affixMask = tonumber(fields[17]) or 0,
                        affixText = fields[18] or "None",
                        targetGuid = tonumber(fields[19]) or 0,
                        targetName = fields[20] or "",
                        relation = fields[21] or "public",
                        rewardClass = fields[22] or "none",
                        threatClass = fields[23] or "low",
                        lastSeenAt = tonumber(fields[24]) or 0,
                        finalLocation = true,
                    }

                    if NT.ChatLinks and type(NT.ChatLinks.Remember) == "function" then
                        NT.ChatLinks:Remember(snapshot)
                    end
                    return
                end
            end
        end

        return originalParseServerPayload(self, payload)
    end
end
