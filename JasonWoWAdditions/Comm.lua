JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions

function JWA:CanClaimBankedXP()
    local status = self.state.status
    return status and status.xpEnabled and status.bankClaimEnabled and status.bankedXP > 0
        and (not status.hardEnforce or status.playerLevel < status.levelCap)
end

function JWA:RequestBankedXPClaim()
    if not self:CanClaimBankedXP() then
        return
    end

    SendChatMessage(".progress xp claim", "SAY")
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestXPRateChange(rate)
    rate = tonumber(rate)
    if not rate then
        return
    end

    rate = math.floor(rate)

    local status = self.state.status
    if status and (rate < status.minRate or rate > status.maxRate) then
        return
    end

    self.state.pendingRateChange = rate
    SendChatMessage(string.format(".progress xp rate %d", rate), "SAY")

    -- The server replies with a plain chat confirmation/rejection message (not the addon
    -- protocol), so pull fresh authoritative state shortly after instead of assuming success.
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestAltPartyAdd(charName, controlled)
    if not charName or charName == "" then
        return
    end

    if controlled then
        InviteUnit(charName)
    else
        SendChatMessage(string.format(".altparty %s", charName), "SAY")
    end
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestAltPartyOff()
    SendChatMessage(".altparty off", "SAY")
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestToggleTakeover()
    SendChatMessage(".afk", "SAY")
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestBotXPRateChange(botName, rate)
    rate = tonumber(rate)
    if not rate or not botName or botName == "" then
        return
    end

    rate = math.floor(rate)

    local status = self.state.status
    if status and (rate < status.minRate or rate > status.maxRate) then
        return
    end

    SendChatMessage(string.format(".progress xp rate %d %s", rate, botName), "SAY")
    self:ScheduleStatusRefresh(0.75)
end

function JWA:RequestToggleTracking(resourceKey)
    if not resourceKey or resourceKey == "" then
        return
    end

    SendChatMessage(string.format(".restrack toggle %s", resourceKey), "SAY")
end

function JWA:RequestCompleteObjective(objectiveId)
    if not objectiveId or objectiveId == "" then
        return
    end

    SendChatMessage(string.format(".progress complete %s", objectiveId), "SAY")
    self:ScheduleStatusRefresh(0.5)
end

local delayFrame = CreateFrame("Frame")
local pendingDelay = nil

delayFrame:SetScript("OnUpdate", function(self, elapsed)
    if not pendingDelay then
        return
    end

    pendingDelay.remaining = pendingDelay.remaining - elapsed
    if pendingDelay.remaining <= 0 then
        local callback = pendingDelay.callback
        pendingDelay = nil
        callback()
    end
end)

function JWA:ScheduleStatusRefresh(delaySeconds)
    pendingDelay = { remaining = delaySeconds, callback = function() JWA:RequestStatus(true) end }
end
