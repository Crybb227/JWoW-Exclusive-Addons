NemesisTracker = NemesisTracker or {}
local NT = NemesisTracker

function NT:RequestSync()
    self:RefreshFromSources()
end

function NT:ToggleWindow()
    if not self.UI or not self.UI.frame then
        return
    end

    if self.UI.frame:IsShown() then
        self.UI.frame:Hide()
    else
        self.UI.frame:Show()
        self.UI:RefreshAll()
    end
end

function NT:InitializeDatabase()
    local defaults = {
        profile = {
            window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 980, height = 640 },
            compactList = false,
            syncScope = "GUILD",
            publicChannelName = "NemesisTracker",
            fadeAfterSeconds = 600,
            staleAfterSeconds = 1800,
            hideAfterSeconds = 7200,
            autoBootstrap = true,
            autoPeerSync = true,
            reportSightingsToServer = true,
            peerSyncMaxEntries = 100,
            reportThrottleSeconds = 20,
            debug = false,
            unitQueryThrottleSeconds = 1,
            unitSnapshotTtlSeconds = 15,
            cache = { nemeses = {} },
        },
    }

    self.database = LibStub("AceDB-3.0"):New("NemesisTrackerDB", defaults, true)
    self.db = self.database.profile
    self.db.cache = self.db.cache or {}
    self.db.cache.nemeses = self.db.cache.nemeses or {}
    self.data.nemeses = self.db.cache.nemeses
    self.data.unitSnapshots = self.data.unitSnapshots or {}
    self.data.unitGuidByToken = self.data.unitGuidByToken or {}
    self.data.pendingUnitQueries = self.data.pendingUnitQueries or {}
    self.data.lastQueryByRuntimeGuid = self.data.lastQueryByRuntimeGuid or {}
end

function NT:ToggleCompactList()
    self.db.compactList = not self.db.compactList
    self.data.page = 1
    self:SortNemeses()
    if self.UI then
        self.UI:RefreshAll()
    end
end

function NT:SlashCommand(input)
    input = string.lower(input or "")
    if input == "debug" then
        self.db.debug = not self.db.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[NemesisTracker]|r debug " .. (self.db.debug and "ON" or "OFF"))
        return
    end
    if input == "dump" or input == "debug dump" then
        self:DumpUnitSnapshots()
        return
    end
    if input == "sync" or input == "refresh" then
        self:RefreshFromSources()
        return
    end
    if input == "peer" then
        self:RequestPeerSync()
        return
    end

    self:ToggleWindow()
end

function NT:RefreshVisibleUI()
    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:RefreshStatus()
        self.UI:RefreshList()
        self.UI:RefreshDetails()
        self.UI:RefreshMap()
    end
end

function NT:RefreshFromSources()
    self:RequestBootstrap()
    self:RequestPeerSync()
    self:TrackKnownUnit("target", true)
    self:TrackKnownUnit("mouseover", true)
end

function NT:DebugLog(message)
    if self.db and self.db.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[NemesisTracker]|r " .. tostring(message or ""))
    end
end

local function parseCreatureRuntimeLow(runtimeGuid)
    runtimeGuid = tostring(runtimeGuid or "")
    runtimeGuid = string.gsub(runtimeGuid, "^0[xX]", "")
    if string.len(runtimeGuid) < 6 then
        return nil
    end
    return tonumber(string.sub(runtimeGuid, -6), 16)
end

function NT:ExpireUnitSnapshots()
    local ttl = (self.db and self.db.unitSnapshotTtlSeconds) or 15
    local now = self:GetNow()
    for guid, snapshot in pairs(self.data.unitSnapshots or {}) do
        if (tonumber(snapshot.receivedAt) or 0) + ttl < now then
            self.data.unitSnapshots[guid] = nil
        end
    end
end

function NT:GetUnitSnapshot(unit)
    if not unit or not UnitGUID or not UnitExists or not UnitExists(unit) then
        return nil
    end

    self:ExpireUnitSnapshots()
    local runtimeGuid = UnitGUID(unit)
    if not runtimeGuid then
        return nil
    end

    local snapshot = self.data.unitSnapshots and self.data.unitSnapshots[runtimeGuid] or nil
    if snapshot and snapshot.isNemesis then
        return snapshot
    end
    return nil
end

function NT:RefreshLiveDisplays()
    if self.UI and self.UI.RefreshAll then
        self.UI:RefreshAll()
    end
    if self.AffixUI and self.AffixUI.RefreshMarkerAuraIcons then
        self.AffixUI:RefreshMarkerAuraIcons()
    end
    if self.NameplateAffixes and self.NameplateAffixes.RefreshConfig then
        self.NameplateAffixes:RefreshConfig()
    end
end

function NT:TrackKnownUnit(unit, force)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitGUID then
        return
    end

    local runtimeGuid = UnitGUID(unit)
    if not runtimeGuid then
        return
    end

    self.data.unitGuidByToken[unit] = runtimeGuid

    local runtimeLow = parseCreatureRuntimeLow(runtimeGuid)
    if not runtimeLow or runtimeLow <= 0 then
        self:DebugLog("unable to parse runtime guid for " .. tostring(unit) .. ": " .. tostring(runtimeGuid))
        return
    end

    local now = self:GetNow()
    local throttle = (self.db and self.db.unitQueryThrottleSeconds) or 1
    local lastQueryAt = self.data.lastQueryByRuntimeGuid[runtimeGuid] or 0
    if not force and lastQueryAt + throttle > now then
        return
    end

    local existing = self.data.unitSnapshots[runtimeGuid]
    local ttl = (self.db and self.db.unitSnapshotTtlSeconds) or 15
    if not force and existing and (existing.receivedAt or 0) + ttl > now then
        return
    end

    self.data.nextUnitRequestId = (self.data.nextUnitRequestId or 0) + 1
    local requestId = tostring(self.data.nextUnitRequestId)
    self.data.pendingUnitQueries[requestId] = {
        unit = unit,
        runtimeGuid = runtimeGuid,
        sentAt = now,
    }
    self.data.lastQueryByRuntimeGuid[runtimeGuid] = now
    self:DebugLog("query #" .. requestId .. " sent for " .. tostring(runtimeGuid))
    self:SendServerCommand(string.format(".nemesis addon query %s %s %d", requestId, runtimeGuid, runtimeLow))
end

function NT:DumpUnitSnapshots()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[NemesisTracker]|r unit snapshot cache")
    self:ExpireUnitSnapshots()
    for guid, snapshot in pairs(self.data.unitSnapshots or {}) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  %s nemesis=%s spawn=%s rank=%s affixes=%s",
            tostring(guid),
            snapshot.isNemesis and "YES" or "NO",
            tostring(snapshot.spawnId or 0),
            snapshot.rank and tostring(snapshot.rank) or "unknown",
            tostring(snapshot.affixText or "")))
    end
end

function NT:OnInitialize()
    self:InitializeDatabase()
    self:SortNemeses()
    if self.data.ordered[1] then
        self.data.selectedSpawnId = self.data.ordered[1].spawnId
    end

    if self.UI then
        self.UI:Create()
        self.UI:RefreshAll()
    end

    self:RegisterChatCommand("nemesistracker", "SlashCommand")
    self:RegisterChatCommand("ntrack", "SlashCommand")

    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.prefix)
        RegisterAddonMessagePrefix(self.peerPrefix)
    end

    self:RegisterComm(self.peerPrefix, "OnPeerCommReceived")
end

function NT:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self.refreshTimer = self:ScheduleRepeatingTimer("RefreshVisibleUI", 1)
end

function NT:OnDisable()
    if self.refreshTimer then
        self:CancelTimer(self.refreshTimer)
        self.refreshTimer = nil
    end
end

function NT:PLAYER_ENTERING_WORLD()
    self:ScheduleTimer(function()
        if self.db.autoBootstrap then
            self:RequestBootstrap()
        end
        if self.db.autoPeerSync then
            self:RequestPeerSync()
        end
        self:TrackKnownUnit("target", true)
        self:TrackKnownUnit("mouseover", true)
    end, 2)
end

function NT:PLAYER_TARGET_CHANGED()
    self:DebugLog("target changed")
    self:TrackKnownUnit("target")
    self:RefreshLiveDisplays()
end

function NT:UPDATE_MOUSEOVER_UNIT()
    self:DebugLog("mouseover changed")
    self:TrackKnownUnit("mouseover")
    self:RefreshLiveDisplays()
end

function NT:CHAT_MSG_SYSTEM(_, message)
    self:HandleSystemMessage(message)
end

function NT:CHAT_MSG_ADDON(_, prefix, message)
    if prefix == self.prefix then
        self:ParseServerPayload(message)
    end
end
