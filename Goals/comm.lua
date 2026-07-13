-- Goals: comm.lua
-- Addon message sync for points, settings, and loot assignments.
-- Usage: Goals.Comm:SendBossKill("Boss", names)

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.Comm = Goals.Comm or {}
local Comm = Goals.Comm
local hasProfileStopComm = type(debugprofilestop) == "function"

Comm.prefix = "GOALS"
Comm.pending = {}

local function split(str, delim)
    local parts = {}
    if not str or str == "" then
        return parts
    end
    for match in string.gmatch(str, "([^" .. delim .. "]+)") do
        table.insert(parts, match)
    end
    return parts
end

local function isLocalOnly()
    return Goals.db and Goals.db.settings and Goals.db.settings.localOnly
end

function Comm:Init()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.prefix)
    end
end

function Comm:GetChannel()
    if Goals:IsInRaid() then
        return "RAID"
    end
    if Goals:IsInParty() then
        return "PARTY"
    end
    return nil
end

function Comm:Send(msgType, payload, channel, target)
    if Goals.db and Goals.db.settings and Goals.db.settings.localOnly then
        return
    end
    local chan = channel or self:GetChannel()
    if not chan then
        return
    end
    local message = msgType
    if payload and payload ~= "" then
        message = msgType .. "|" .. payload
    end
    if #message > 230 then
        self:SendChunked(msgType, payload, chan, target)
        return
    end
    SendAddonMessage(self.prefix, message, chan, target)
end

function Comm:SendChunked(msgType, payload, channel, target)
    local chunkSize = 220
    local total = math.ceil(#payload / chunkSize)
    for i = 1, total do
        local chunk = payload:sub((i - 1) * chunkSize + 1, i * chunkSize)
        local header = string.format("%s#%d/%d", msgType, i, total)
        SendAddonMessage(self.prefix, header .. "|" .. chunk, channel, target)
    end
end

function Comm:OnMessage(prefix, message, channel, sender)
    local ui = Goals and Goals.UI or nil
    local traceEnabled = hasProfileStopComm and ui and ui.IsCpuDebugTracingEnabled and ui:IsCpuDebugTracingEnabled()
    local t0 = traceEnabled and debugprofilestop() or 0

    if prefix ~= self.prefix then
        return
    end
    if Goals.db and Goals.db.settings and Goals.db.settings.localOnly then
        return
    end
    if sender and Goals:NormalizeName(sender) == Goals:GetPlayerName() then
        return
    end
    local msgType, payload = message:match("^([^|]+)|?(.*)$")
    if not msgType then
        return
    end
    local base, index, total = msgType:match("^(.-)#(%d+)/(%d+)$")
    if base then
        self:HandleChunk(base, tonumber(index), tonumber(total), payload, sender, channel)
        if traceEnabled and ui and ui.RecordCpuSpikeDetail then
            ui:RecordCpuSpikeDetail("Comm.OnMessage", debugprofilestop() - t0, string.format("chunk type=%s sender=%s", tostring(base), tostring(sender or "-")))
        end
        return
    end
    self:HandleMessage(msgType, payload, sender, channel)
    if traceEnabled and ui and ui.RecordCpuSpikeDetail then
        ui:RecordCpuSpikeDetail("Comm.OnMessage", debugprofilestop() - t0, string.format("type=%s sender=%s", tostring(msgType), tostring(sender or "-")))
    end
end

function Comm:HandleChunk(base, index, total, payload, sender, channel)
    self.pending[base] = self.pending[base] or {}
    local entry = self.pending[base][sender] or { parts = {}, total = total }
    entry.parts[index] = payload
    entry.total = total
    self.pending[base][sender] = entry
    for i = 1, entry.total do
        if not entry.parts[i] then
            return
        end
    end
    local combined = table.concat(entry.parts, "")
    self.pending[base][sender] = nil
    self:HandleMessage(base, combined, sender, channel)
end

function Comm:HandleMessage(msgType, payload, sender, channel)
    local ui = Goals and Goals.UI or nil
    local traceEnabled = hasProfileStopComm and ui and ui.IsCpuDebugTracingEnabled and ui:IsCpuDebugTracingEnabled()
    local t0 = traceEnabled and debugprofilestop() or 0
    local function traceDone(detail)
        if traceEnabled and ui and ui.RecordCpuSpikeDetail then
            ui:RecordCpuSpikeDetail("Comm.HandleMessage", debugprofilestop() - t0, string.format("type=%s %s", tostring(msgType), tostring(detail or "")))
        end
    end

    if msgType == "VERSION" then
        if Goals.HandleRemoteVersion then
            Goals:HandleRemoteVersion(payload, sender)
        end
        traceDone("version")
        return
    end
    if msgType == "SYNC_REQUEST" then
        if Goals.History and Goals.History.AddSyncRequest then
            Goals.History:AddSyncRequest(false, channel, sender)
        end
        if Goals:IsSyncMaster() then
            self:SendSync(sender, "REQUEST")
        end
        traceDone("sync-request")
        return
    end
    if msgType == "SYNC_POINTS" then
        Goals.lastSyncReceivedAt = time()
        if Goals.History and Goals.History.AddSyncReceived then
            Goals.History:AddSyncReceived("POINTS", sender, channel)
        end
        self:ApplyPoints(payload)
        traceDone("sync-points")
        return
    end
    if msgType == "SYNC_SETTINGS" then
        Goals.lastSyncReceivedAt = time()
        if Goals.History and Goals.History.AddSyncReceived then
            Goals.History:AddSyncReceived("SETTINGS", sender, channel)
        end
        self:ApplySettings(payload)
        traceDone("sync-settings")
        return
    end
    if msgType == "BOSSKILL" then
        Goals.lastSyncReceivedAt = time()
        local encounter, list = payload:match("^(.-)|(.*)$")
        local names = split(list or "", ",")
        Goals:ApplyBossKillFromSync(encounter or "Boss", names)
        traceDone("bosskill")
        return
    end
    if msgType == "WISHLIST_BUILD" then
        if Goals.HandleIncomingBuild then
            Goals:HandleIncomingBuild(payload, sender)
        end
        traceDone("wishlist-build")
        return
    end
    if msgType == "ADJUST" then
        Goals.lastSyncReceivedAt = time()
        local name, delta, reason = payload:match("^(.-)|(-?%d+)|?(.*)$")
        Goals:AdjustPoints(name, tonumber(delta) or 0, reason or "Sync adjustment", true, true)
        traceDone("adjust")
        return
    end
    if msgType == "SETPOINTS" then
        Goals.lastSyncReceivedAt = time()
        local name, points, reason = payload:match("^(.-)|(-?%d+)|?(.*)$")
        Goals:SetPoints(name, tonumber(points) or 0, reason or "Sync set", true, false, true)
        traceDone("setpoints")
        return
    end
    if msgType == "LOOTRESET" then
        Goals.lastSyncReceivedAt = time()
        local name, itemLink = payload:match("^(.-)|(.+)$")
        Goals:ApplyLootReset(name, itemLink)
        traceDone("lootreset")
        return
    end
    if msgType == "LOOT" then
        Goals.lastSyncReceivedAt = time()
        local name, itemLink = payload:match("^(.-)|(.+)$")
        Goals:ApplyLootAssignment(name, itemLink)
        traceDone("loot")
        return
    end
    if msgType == "LOOTFOUND" then
        Goals.lastSyncReceivedAt = time()
        local id, ts, itemLink = payload:match("^(%d+)|(%d+)|(.+)$")
        Goals:ApplyLootFound(tonumber(id) or 0, tonumber(ts) or 0, itemLink, sender)
        traceDone("lootfound")
        return
    end
    if msgType == "SETTING" then
        Goals.lastSyncReceivedAt = time()
        local key, value = payload:match("^(.-)|(.+)$")
        self:ApplySetting(key, value)
        traceDone("setting")
        return
    end
    traceDone("unknown")
end

function Comm:RequestSync(source)
    local channel = self:GetChannel()
    if not channel then
        return
    end
    self:Send("SYNC_REQUEST", Goals.version, channel)
    if not isLocalOnly() and Goals.History and Goals.History.AddSyncRequest then
        Goals.History:AddSyncRequest(true, channel, nil, source)
    end
end

function Comm:SendVersion(target)
    local major = Goals.GetUpdateMajorVersion and Goals:GetUpdateMajorVersion() or 0
    local version = Goals.GetInstalledUpdateVersion and Goals:GetInstalledUpdateVersion() or 0
    if not version or version <= 0 then
        return
    end
    local channel = target and "WHISPER" or nil
    local payload = string.format("%d.%d", major, version)
    self:Send("VERSION", payload, channel, target)
end

function Comm:BroadcastVersion()
    self:SendVersion(nil)
end

function Comm:SendSync(target, source)
    local channel = target and "WHISPER" or self:GetChannel()
    if not channel then
        return
    end
    self:Send("SYNC_POINTS", self:SerializePoints(), channel, target)
    self:Send("SYNC_SETTINGS", self:SerializeSettings(), channel, target)
    if Goals and Goals.MarkSyncSent then
        Goals:MarkSyncSent()
    end
    if not isLocalOnly() and Goals.History and Goals.History.AddSyncSent then
        Goals.History:AddSyncSent("FULL", target, channel, source)
    end
end

function Comm:SendPointsSync(target, source)
    local channel = target and "WHISPER" or self:GetChannel()
    if not channel then
        return
    end
    self:Send("SYNC_POINTS", self:SerializePoints(), channel, target)
    if Goals and Goals.MarkSyncSent then
        Goals:MarkSyncSent()
    end
    if not isLocalOnly() and Goals.History and Goals.History.AddSyncSent then
        Goals.History:AddSyncSent("POINTS", target, channel, source)
    end
end

function Comm:BroadcastFullSync(source)
    self:SendSync(nil, source)
end

function Comm:SendWishlistBuild(target, payload)
    if not target or target == "" then
        return false
    end
    if not payload or payload == "" then
        return false
    end
    local ok = pcall(function()
        self:Send("WISHLIST_BUILD", payload, "WHISPER", target)
    end)
    return ok
end

function Comm:SendBossKill(encounterName, names)
    local payload = encounterName .. "|" .. table.concat(names, ",")
    self:Send("BOSSKILL", payload)
end

function Comm:SendAdjustment(name, delta, reason)
    local payload = string.format("%s|%d|%s", name, delta or 0, reason or "")
    self:Send("ADJUST", payload)
end

function Comm:SendSetPoints(name, points, reason)
    local payload = string.format("%s|%d|%s", name, points or 0, reason or "")
    self:Send("SETPOINTS", payload)
end

function Comm:SendLootReset(name, itemLink)
    local payload = string.format("%s|%s", name, itemLink)
    self:Send("LOOTRESET", payload)
end

function Comm:SendLootAssignment(name, itemLink)
    local payload = string.format("%s|%s", name, itemLink)
    self:Send("LOOT", payload)
end

function Comm:SendLootFound(id, ts, itemLink)
    if not id or not ts or not itemLink then
        return
    end
    local payload = string.format("%d|%d|%s", id, ts, itemLink)
    self:Send("LOOTFOUND", payload)
end

function Comm:SendSetting(key, value)
    local payload = string.format("%s|%s", key, tostring(value))
    self:Send("SETTING", payload)
end

function Comm:SerializePoints()
    local parts = {}
    local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
    for name, data in pairs(players) do
        local class = data.class or ""
        local points = data.points or 0
        table.insert(parts, name .. "," .. points .. "," .. class)
    end
    return table.concat(parts, ";")
end

function Comm:ApplyPoints(payload)
    local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
    local changed = false
    for entry in string.gmatch(payload or "", "([^;]+)") do
        local name, points, class = entry:match("([^,]+),([^,]+),?(.*)")
        if name and points then
            local normalized = Goals:NormalizeName(name)
            if normalized ~= "" and normalized ~= "Unknown" then
                local newPoints = tonumber(points) or 0
                local newClass = class ~= "" and class or "UNKNOWN"
                local existing = players[normalized]
                if not existing or (existing.points or 0) ~= newPoints or (existing.class or "UNKNOWN") ~= newClass then
                    players[normalized] = { points = newPoints, class = newClass }
                    changed = true
                end
            end
        end
    end
    Goals.lastSyncReceivedAt = time()
    if changed then
        Goals:NotifyDataChanged()
    end
end

function Comm:SerializeSettings()
    local settings = Goals.db.settings
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or settings
    local parts = {
        "combineBossHistory=" .. (settings.combineBossHistory and "1" or "0"),
        "disenchanter=" .. (settings.disenchanter or ""),
        "debug=" .. (settings.debug and "1" or "0"),
        "disablePointGain=" .. (overviewSettings.disablePointGain and "1" or "0"),
        "resetMounts=" .. (settings.resetMounts and "1" or "0"),
        "resetPets=" .. (settings.resetPets and "1" or "0"),
        "resetRecipes=" .. (settings.resetRecipes and "1" or "0"),
        "resetQuestItems=" .. (settings.resetQuestItems and "1" or "0"),
        "resetTokens=" .. (settings.resetTokens and "1" or "0"),
        "resetBags=" .. (settings.resetBags and "1" or "0"),
        "resetRequiresLootWindow=" .. (settings.resetRequiresLootWindow and "1" or "0"),
        "resetMinQuality=" .. tostring(settings.resetMinQuality or 4),
    }
    return table.concat(parts, ";")
end

function Comm:ApplySettings(payload)
    local before = self:SerializeSettings()
    for pair in string.gmatch(payload or "", "([^;]+)") do
        local key, value = pair:match("([^=]+)=(.*)")
        if key then
            self:ApplySetting(key, value)
        end
    end
    local after = self:SerializeSettings()
    if before ~= after then
        Goals:NotifyDataChanged()
    end
end

function Comm:ApplySetting(key, value)
    if key == "combineBossHistory" then
        Goals.db.settings.combineBossHistory = value == "1" or value == "true"
        return
    end
    if key == "disenchanter" then
        Goals.db.settings.disenchanter = value or ""
        return
    end
    if key == "debug" then
        Goals.db.settings.debug = value == "1" or value == "true"
        return
    end
    if key == "disablePointGain" then
        local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
        overviewSettings.disablePointGain = value == "1" or value == "true"
        return
    end
    if key == "resetMounts" then
        Goals.db.settings.resetMounts = value == "1" or value == "true"
        return
    end
    if key == "resetPets" then
        Goals.db.settings.resetPets = value == "1" or value == "true"
        return
    end
    if key == "resetRecipes" then
        Goals.db.settings.resetRecipes = value == "1" or value == "true"
        return
    end
    if key == "resetQuestItems" then
        Goals.db.settings.resetQuestItems = value == "1" or value == "true"
        return
    end
    if key == "resetTokens" then
        Goals.db.settings.resetTokens = value == "1" or value == "true"
        return
    end
    if key == "resetBags" then
        Goals.db.settings.resetBags = value == "1" or value == "true"
        return
    end
    if key == "resetRequiresLootWindow" then
        Goals.db.settings.resetRequiresLootWindow = value == "1" or value == "true"
        return
    end
    if key == "resetMinQuality" then
        Goals.db.settings.resetMinQuality = tonumber(value) or 4
        return
    end
end
