JasonWoWAdditions = JasonWoWAdditions or {}
local JWA = JasonWoWAdditions

-- Server protocol (see modules/mod-campaign-progression, SendAddonStatus):
--   Envelope: "JWACampaign\t<payload>"
--   V2:CHUNK:<id>:<part>:<total>:<data>                       -- reassembled before dispatch
--   V2:STATUS:era:chapter:phase:levelCap:hardEnforce:catchupCeiling:highestHumanLevel:
--       revision:xpEnabled:playerLevel:personalCatchupCeiling:catchupEligible:catchupRate:
--       minRate:maxRate:rateCmdEnabled:bankedXP:bankClaimEnabled:goldRate:nextMilestone:
--       takeoverActive:altPartyCount
--   V2:NODE:id:category:label:complete:achievementId:catchupCeiling:levelCap
--   V2:OBJECTIVE:id:category:label:group:individuallyComplete:groupComplete:groupRequired
--   V2:BOT:guid:name:level:inGroup:catchupRate:controlled:online -- account alts
--   V2:TAKEOVER:activity:target
--   V2:END

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

        if startIndex > string.len(message) + 1 then
            table.insert(result, "")
            break
        end
    end

    return result
end

local function joinFields(fields, startIndex, delimiter)
    if not fields or not startIndex or startIndex > #fields then
        return ""
    end

    return table.concat(fields, delimiter or ":", startIndex)
end

JWA.SplitFields = splitPreserveEmpty
JWA.JoinFields = joinFields

local function toBool(value)
    return tostring(value) == "1"
end

function JWA:ParseStatusFields(fields)
    -- fields[1]="V2" fields[2]="STATUS", data starts at fields[3]
    local i = 3
    local status = {
        era = tonumber(fields[i]) or 0,
        chapter = fields[i + 1] or "",
        phase = tonumber(fields[i + 2]) or 1,
        levelCap = tonumber(fields[i + 3]) or 0,
        hardEnforce = toBool(fields[i + 4]),
        catchupCeiling = tonumber(fields[i + 5]) or 0,
        highestHumanLevel = tonumber(fields[i + 6]) or 0,
        revision = tonumber(fields[i + 7]) or 0,
        xpEnabled = toBool(fields[i + 8]),
        playerLevel = tonumber(fields[i + 9]) or 0,
        personalCatchupCeiling = tonumber(fields[i + 10]) or 0,
        catchupEligible = toBool(fields[i + 11]),
        catchupRate = tonumber(fields[i + 12]) or 1,
        minRate = tonumber(fields[i + 13]) or 1,
        maxRate = tonumber(fields[i + 14]) or 1,
        rateCmdEnabled = toBool(fields[i + 15]),
        bankedXP = tonumber(fields[i + 16]) or 0,
        bankClaimEnabled = toBool(fields[i + 17]),
        goldRate = tonumber(fields[i + 18]) or 1,
        nextMilestone = tonumber(fields[i + 19]) or 0,
        takeoverActive = toBool(fields[i + 20]),
        altPartyCount = tonumber(fields[i + 21]) or 0,
    }

    return status
end

function JWA:ParseNodeFields(fields)
    -- fields[1]="V2" fields[2]="NODE", data starts at fields[3]
    local i = 3
    return {
        id = fields[i] or "",
        category = fields[i + 1] or "other",
        label = fields[i + 2] or (fields[i] or "?"),
        complete = toBool(fields[i + 3]),
        achievementId = tonumber(fields[i + 4]) or 0,
        catchupCeiling = tonumber(fields[i + 5]) or 0,
        levelCap = tonumber(fields[i + 6]) or 0,
    }
end

function JWA:ParseBotFields(fields)
    -- fields[1]="V2" fields[2]="BOT", data starts at fields[3]
    local i = 3
    return {
        guid = fields[i] or "",
        name = fields[i + 1] or "?",
        level = tonumber(fields[i + 2]) or 0,
        inGroup = toBool(fields[i + 3]),
        catchupRate = tonumber(fields[i + 4]) or 1,
        controlled = fields[i + 5] == nil or toBool(fields[i + 5]),
        online = fields[i + 6] == nil or toBool(fields[i + 6]),
    }
end

function JWA:ParseObjectiveFields(fields)
    -- fields[1]="V2" fields[2]="OBJECTIVE", data starts at fields[3]
    local i = 3
    return {
        id = fields[i] or "",
        category = fields[i + 1] or "other",
        label = fields[i + 2] or (fields[i] or "?"),
        group = fields[i + 3] or "",
        individuallyComplete = toBool(fields[i + 4]),
        complete = toBool(fields[i + 5]),
        groupRequired = tonumber(fields[i + 6]) or 1,
    }
end

local function reassembleChunk(chunkStore, message, dispatch)
    local fields = splitPreserveEmpty(message, ":")
    if fields[1] ~= "V2" or fields[2] ~= "CHUNK" then
        return
    end

    local chunkId = fields[3]
    local part = tonumber(fields[4]) or 0
    local total = tonumber(fields[5]) or 0
    local payload = joinFields(fields, 6, ":")

    if not chunkId or chunkId == "" or #chunkId > 64 or part <= 0 or total <= 0
        or part > total or total > 32 or part % 1 ~= 0 or total % 1 ~= 0 or #payload > 220 then
        return
    end

    local now = JWA:GetNow()
    local pending = 0
    for id, chunk in pairs(chunkStore) do
        if now - chunk.createdAt >= 30 then
            chunkStore[id] = nil
        else
            pending = pending + 1
        end
    end
    if not chunkStore[chunkId] then
        if pending >= 64 then return end
        chunkStore[chunkId] = { total = total, parts = {}, createdAt = now }
    end

    local chunkState = chunkStore[chunkId]
    if chunkState.total ~= total then
        chunkStore[chunkId] = nil
        return
    end
    chunkState.parts[part] = payload

    local count = 0
    for _ in pairs(chunkState.parts) do
        count = count + 1
    end

    if count < chunkState.total then
        return
    end

    local rebuilt = ""
    for index = 1, chunkState.total do
        rebuilt = rebuilt .. (chunkState.parts[index] or "")
    end

    chunkStore[chunkId] = nil
    dispatch(rebuilt)
end

function JWA:HandleChunk(message)
    reassembleChunk(self.state.chunks, message, function(rebuilt) self:ParseServerPayload(rebuilt) end)
end

function JWA:ParseServerPayload(payload)
    if not payload or payload == "" then
        return
    end

    local fields = splitPreserveEmpty(payload, ":")
    if fields[1] ~= "V2" then
        return
    end

    local opcode = fields[2]
    if not opcode then
        return
    end

    if opcode == "CHUNK" then
        self:HandleChunk(payload)
        return
    end

    if opcode == "STATUS" then
        self.state.chunks = {} -- Previous partial rows cannot enter this snapshot.
        self.state.takeover = nil
        self.state.status = self:ParseStatusFields(fields)
        self.state.connectionState = "live"
        self.state.lastResponseAt = self:GetNow()
        self.state.vanillaSummary = nil
        self.state.sands = nil
        self.state.vanilla = {}
        self.state.vanillaOrder = {}
        self.state.nodes = {}
        self.state.nodeOrder = {}
        self.state.objectives = {}
        self.state.objectiveOrder = {}
        self.state.bots = {}
        self.state.botOrder = {}
        if self.UI then
            self.UI:RefreshAll()
        end
        return
    end

    -- Additive opcode: existing V2 STATUS/VANILLA/SUMMARY field counts are unchanged.
    if opcode == "SANDS" then
        if #fields ~= 13 then return end
        local values = {}
        for i = 3, 13 do
            local value = tonumber(fields[i])
            if not value or value < 0 or value % 1 ~= 0 then return end
            values[i - 2] = value
        end
        if values[1] > 1 or values[3] < 1 or values[3] > 1000000 or values[2] > values[3]
            or values[4] > 21600 or values[5] > 1 or values[6] > 1 or values[8] ~= 5
            or values[7] > values[8] or values[9] > 1 or values[10] > 2 or values[11] > 1 then return end
        self.state.sands = {
            supplies = values[1] == 1, ready = values[2], target = values[3], seconds = values[4],
            open = values[5] == 1, prepared = values[6] == 1, defense = values[7], defenseTarget = values[8],
            gong = values[9] == 1, claim = values[10], replay = values[11] == 1,
        }
        return
    end

    if opcode == "VANILLA_SUMMARY" then
        local done, total, percent, war = tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5]), tonumber(fields[6])
        if #fields ~= 8 or not done or not total or done < 0 or done > total or total < 1
            or not percent or percent < 0 or percent > 100 or not war or war < 0 or war > 100 then return end
        self.state.vanillaSummary = { done = done, total = total, percent = percent, war = war,
            currentObjective = fields[7], nextUnlock = fields[8] }
        return
    end

    if opcode == "VANILLA" then
        if #fields ~= 13 or not fields[3]:match("^v60_[a-z_]+$") then return end
        local current, required, personal = tonumber(fields[6]), tonumber(fields[7]), tonumber(fields[11])
        local states = { Complete = true, ["In Progress"] = true, Available = true, Locked = true }
        if not current or not required or required < 1 or required > 1000000
            or current < 0 or current > required or current % 1 ~= 0 or required % 1 ~= 0
            or not personal or personal < 0 or not states[fields[8]] then return end
        self.state.vanilla = self.state.vanilla or {}
        self.state.vanillaOrder = self.state.vanillaOrder or {}
        local id = fields[3]
        if not self.state.vanilla[id] then table.insert(self.state.vanillaOrder, id) end
        self.state.vanilla[id] = {
            id = id, category = fields[4], label = fields[5], current = current, required = required,
            state = fields[8], optional = fields[9] == "1", scope = fields[10], personal = personal,
            reason = fields[12], acceptedItems = fields[13], complete = current >= required,
            individuallyComplete = current >= required, group = "", kind = "vanilla",
        }
        return -- Refresh once at END, not for every campaign row.
    end

    if opcode == "NODE" then
        local node = self:ParseNodeFields(fields)
        if node.id ~= "" and not self.state.nodes[node.id] then
            table.insert(self.state.nodeOrder, node.id)
        end
        if node.id ~= "" then
            self.state.nodes[node.id] = node
        end
        if self.UI then
            self.UI:RefreshAll()
        end
        return
    end

    if opcode == "TAKEOVER" then
        self.state.takeover = { activity = fields[3] or "", target = fields[4] or "" }
        return
    end

    if opcode == "BOT" then
        local bot = self:ParseBotFields(fields)
        if bot.guid ~= "" and not self.state.bots[bot.guid] then
            table.insert(self.state.botOrder, bot.guid)
        end
        if bot.guid ~= "" then
            self.state.bots[bot.guid] = bot
        end
        if self.UI then
            self.UI:RefreshAll()
        end
        return
    end

    if opcode == "OBJECTIVE" then
        local objective = self:ParseObjectiveFields(fields)
        if objective.id ~= "" and not self.state.objectives[objective.id] then
            table.insert(self.state.objectiveOrder, objective.id)
        end
        if objective.id ~= "" then
            self.state.objectives[objective.id] = objective
        end
        if self.UI then
            self.UI:RefreshAll()
        end
        return
    end

    if opcode == "END" then
        self.state.connectionState = "live"
        self.state.lastResponseAt = self:GetNow()
        if self.UI then
            self.UI:RefreshAll()
        end
        return
    end
end

-- Resource Tracking protocol (see modules/mod-resource-tracking, SendResourceTrackingStatus):
--   Envelope: "JWAResTrack\t<payload>"
--   V2:CHUNK:<id>:<part>:<total>:<data>
--   V2:TYPES:<key>:<label>:<spellId>|<key>:<label>:<spellId>|...
--   V2:STATE:<key1>:<key2>:...
--   V2:END

local trackingChunks = {}

function JWA:ParseTrackingPayload(payload)
    if not payload or payload == "" then
        return
    end

    local fields = splitPreserveEmpty(payload, ":")
    if fields[1] ~= "V2" then
        return
    end

    local opcode = fields[2]
    if not opcode then
        return
    end

    if opcode == "CHUNK" then
        reassembleChunk(trackingChunks, payload, function(rebuilt) self:ParseTrackingPayload(rebuilt) end)
        return
    end

    if opcode == "TYPES" then
        local rest = joinFields(fields, 3, ":")
        self.tracking.types = {}
        self.tracking.typeOrder = {}

        if rest ~= "" then
            for _, entry in ipairs({ strsplit("|", rest) }) do
                local entryFields = splitPreserveEmpty(entry, ":")
                local key = entryFields[1]
                local label = entryFields[2]
                local spellId = tonumber(entryFields[3])

                if key and key ~= "" then
                    self.tracking.types[key] = { key = key, label = label or key, spellId = spellId or 0 }
                    table.insert(self.tracking.typeOrder, key)
                end
            end
        end

        if self.UI then
            self.UI:RefreshTracking()
        end
        return
    end

    if opcode == "STATE" then
        local tracked = {}
        for index = 3, #fields do
            if fields[index] ~= "" then
                tracked[fields[index]] = true
            end
        end
        self.tracking.tracked = tracked

        if self.UI then
            self.UI:RefreshTracking()
        end
        return
    end

    if opcode == "END" then
        if self.UI then
            self.UI:RefreshTracking()
        end
        return
    end
end

