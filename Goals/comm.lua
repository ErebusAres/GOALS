-- Goals: comm.lua
-- Addon message sync for points, settings, and loot assignments.
-- Usage: Goals.Comm:SendBossKill("Boss", names)

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.Comm = Goals.Comm or {}
local Comm = Goals.Comm

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
        self:HandleChunk(base, tonumber(index), tonumber(total), payload, sender)
        return
    end
    self:HandleMessage(msgType, payload, sender, channel)
end

function Comm:HandleChunk(base, index, total, payload, sender)
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
    self:HandleMessage(base, combined, sender, nil)
end

function Comm:HandleMessage(msgType, payload, sender, channel)
    if msgType == "VERSION" then
        if Goals.HandleRemoteVersion then
            Goals:HandleRemoteVersion(payload, sender)
        end
        return
    end
    if msgType == "SYNC_REQUEST" then
        if Goals:IsSyncMaster() then
            self:SendSync(sender)
        end
        return
    end
    if msgType == "SYNC_POINTS" then
        self:ApplyPoints(payload)
        return
    end
    if msgType == "SYNC_SETTINGS" then
        self:ApplySettings(payload)
        return
    end
    if msgType == "SYNC_WISHLIST" then
        if Goals.ApplyWishlistSync then
            Goals:ApplyWishlistSync(payload)
        end
        return
    end
    if msgType == "WISHLIST_SYNC_REQUEST" then
        if Goals:IsSyncMaster() then
            self:SendWishlistSync(sender)
        end
        return
    end
    if msgType == "BOSSKILL" then
        local encounter, list = payload:match("^(.-)|(.*)$")
        local names = split(list or "", ",")
        Goals:ApplyBossKillFromSync(encounter or "Boss", names)
        return
    end
    if msgType == "ADJUST" then
        local name, delta, reason = payload:match("^(.-)|(-?%d+)|?(.*)$")
        Goals:AdjustPoints(name, tonumber(delta) or 0, reason or "Sync adjustment", true, true)
        return
    end
    if msgType == "SETPOINTS" then
        local name, points, reason = payload:match("^(.-)|(-?%d+)|?(.*)$")
        Goals:SetPoints(name, tonumber(points) or 0, reason or "Sync set", true, false, true)
        return
    end
    if msgType == "LOOTRESET" then
        local name, itemLink = payload:match("^(.-)|(.+)$")
        Goals:ApplyLootReset(name, itemLink)
        return
    end
    if msgType == "LOOT" then
        local name, itemLink = payload:match("^(.-)|(.+)$")
        Goals:ApplyLootAssignment(name, itemLink)
        return
    end
    if msgType == "LOOTFOUND" then
        local id, ts, itemLink = payload:match("^(%d+)|(%d+)|(.+)$")
        Goals:ApplyLootFound(tonumber(id) or 0, tonumber(ts) or 0, itemLink, sender)
        return
    end
    if msgType == "SETTING" then
        local key, value = payload:match("^(.-)|(.+)$")
        self:ApplySetting(key, value)
        return
    end
end

function Comm:RequestSync()
    self:Send("SYNC_REQUEST", Goals.version)
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

function Comm:SendSync(target)
    local channel = target and "WHISPER" or nil
    self:Send("SYNC_POINTS", self:SerializePoints(), channel, target)
    self:Send("SYNC_SETTINGS", self:SerializeSettings(), channel, target)
    if Goals.SerializeAllWishlists then
        self:Send("SYNC_WISHLIST", Goals:SerializeAllWishlists(), channel, target)
    end
end

function Comm:BroadcastFullSync()
    self:SendSync(nil)
end

function Comm:SendWishlistSync(target)
    if not Goals.SerializeAllWishlists then
        return
    end
    local channel = target and "WHISPER" or nil
    self:Send("SYNC_WISHLIST", Goals:SerializeAllWishlists(), channel, target)
end

function Comm:RequestWishlistSync()
    self:Send("WISHLIST_SYNC_REQUEST", Goals.version)
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
    for name, data in pairs(Goals.db.players) do
        local class = data.class or ""
        local points = data.points or 0
        table.insert(parts, name .. "," .. points .. "," .. class)
    end
    return table.concat(parts, ";")
end

function Comm:ApplyPoints(payload)
    local players = Goals.db.players or {}
    for entry in string.gmatch(payload or "", "([^;]+)") do
        local name, points, class = entry:match("([^,]+),([^,]+),?(.*)")
        if name and points then
            local normalized = Goals:NormalizeName(name)
            if normalized ~= "" and normalized ~= "Unknown" then
                players[normalized] = { points = tonumber(points) or 0, class = class ~= "" and class or "UNKNOWN" }
            end
        end
    end
    Goals.db.players = players
    Goals:NotifyDataChanged()
end

function Comm:SerializeSettings()
    local settings = Goals.db.settings
    local parts = {
        "combineBossHistory=" .. (settings.combineBossHistory and "1" or "0"),
        "disenchanter=" .. (settings.disenchanter or ""),
        "debug=" .. (settings.debug and "1" or "0"),
        "resetMounts=" .. (settings.resetMounts and "1" or "0"),
        "resetPets=" .. (settings.resetPets and "1" or "0"),
        "resetRecipes=" .. (settings.resetRecipes and "1" or "0"),
        "resetQuestItems=" .. (settings.resetQuestItems and "1" or "0"),
        "resetTokens=" .. (settings.resetTokens and "1" or "0"),
        "resetMinQuality=" .. tostring(settings.resetMinQuality or 4),
    }
    return table.concat(parts, ";")
end

function Comm:ApplySettings(payload)
    for pair in string.gmatch(payload or "", "([^;]+)") do
        local key, value = pair:match("([^=]+)=(.*)")
        if key then
            self:ApplySetting(key, value)
        end
    end
    Goals:NotifyDataChanged()
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
    if key == "resetMinQuality" then
        Goals.db.settings.resetMinQuality = tonumber(value) or 4
        return
    end
end
