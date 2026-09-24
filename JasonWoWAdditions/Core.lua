JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions

JWA.ADDON_PREFIX = "JWACampaign"
JWA.COMMAND_PREFIX = ".progress addon status"
JWA.TRACKING_ADDON_PREFIX = "JWAResTrack"
JWA.TRACKING_COMMAND_PREFIX = ".restrack status"

JWA.state = {
    connectionState = "idle",     -- idle | requesting | live | stale
    lastRequestAt = 0,
    lastResponseAt = 0,
    chunks = {},
    status = nil,                 -- parsed V2:STATUS fields, see Protocol.lua
    nodes = {},                   -- nodeId -> parsed V2:NODE fields
    nodeOrder = {},
    objectives = {},               -- objectiveId -> parsed V2:OBJECTIVE fields
    objectiveOrder = {},
    bots = {},                     -- botGuid -> parsed V2:BOT fields (altparty bots)
    botOrder = {},
    pendingRateChange = nil,
    lastError = nil,
}

local DEFAULTS = {
    window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    lastTab = "overview",
    showOnStartup = false,
    uiScale = 1.0,
    tinyMode = false,
}

local eventFrame = CreateFrame("Frame")
JWA.eventFrame = eventFrame

local REQUEST_THROTTLE_SECONDS = 5

function JWA:GetNow()
    return GetTime and GetTime() or time()
end

function JWA:InitializeDatabase()
    JasonWoWAdditionsDB = JasonWoWAdditionsDB or {}
    for key, value in pairs(DEFAULTS) do
        if JasonWoWAdditionsDB[key] == nil then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do
                    copy[k] = v
                end
                JasonWoWAdditionsDB[key] = copy
            else
                JasonWoWAdditionsDB[key] = value
            end
        end
    end

    self.db = JasonWoWAdditionsDB
end

function JWA:RequestStatus(force)
    local now = self:GetNow()
    if not force and (now - (self.state.lastRequestAt or 0)) < REQUEST_THROTTLE_SECONDS then
        return
    end

    self.state.lastRequestAt = now
    self.state.connectionState = "requesting"
    self.state.lastError = nil

    if self.UI then
        self.UI:RefreshStatus()
    end

    SendChatMessage(self.COMMAND_PREFIX, "SAY")
end

function JWA:RequestTrackingStatus()
    SendChatMessage(self.TRACKING_COMMAND_PREFIX, "SAY")
end

function JWA:ToggleWindow()
    if not self.UI or not self.UI.frame then
        return
    end

    if self.UI.frame:IsShown() then
        self.UI.frame:Hide()
    else
        self.UI.frame:Show()
        self:RequestStatus(false)
        self.UI:RefreshAll()
    end
end

function JWA:ToggleTinyMode()
    if not self.UI or not self.UI.frame then
        return
    end

    self.db.tinyMode = not self.db.tinyMode
    if not self.UI.frame:IsShown() then
        self.UI.frame:Show()
        self:RequestStatus(false)
    end
    self.UI:ApplyTinyMode()
end

function JWA:SlashCommand(input)
    input = string.lower(input or "")

    if input == "refresh" then
        self:RequestStatus(true)
        return
    end

    if input == "tiny" then
        self:ToggleTinyMode()
        return
    end

    self:ToggleWindow()
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= "JasonWoWAdditions" then
            return
        end

        JWA:InitializeDatabase()

        if JWA.UI then
            JWA.UI:Create()
        end

        SLASH_JASONWOWADDITIONS1 = "/prog"
        SlashCmdList["JASONWOWADDITIONS"] = function(msg) JWA:SlashCommand(msg) end

        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(JWA.ADDON_PREFIX)
            RegisterAddonMessagePrefix(JWA.TRACKING_ADDON_PREFIX)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        JWA.state.chunks = {}
        JWA:RequestStatus(true)
        JWA:RequestTrackingStatus()
        if JWA.db and JWA.db.showOnStartup and JWA.UI and JWA.UI.frame and not JWA.UI.frame:IsShown() then
            JWA.UI.frame:Show()
            JWA.UI:RefreshAll()
        end
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        JWA:RequestStatus(true)
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == JWA.ADDON_PREFIX then
            if channel ~= "WHISPER" or not sender or sender:match("^[^-]+") ~= UnitName("player") then return end
            JWA:ParseServerPayload(message)
        elseif prefix == JWA.TRACKING_ADDON_PREFIX then
            JWA:ParseTrackingPayload(message)
        end
        return
    end
end)
