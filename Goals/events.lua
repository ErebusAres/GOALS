-- Goals: events.lua
-- Event handlers for boss encounters, loot, and sync.
-- Boss tracking recommendation:
--   Prefer encounter events and boss combat log signals (UNIT_DIED/BOSS_KILL) plus group combat state.
--   Do NOT use badge tracking; badges can drop without a boss kill.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.Events = Goals.Events or {}
local Events = Goals.Events

local function isRedusRealm()
    local realm = GetRealmName and GetRealmName() or ""
    if realm == "" then
        return false
    end
    return string.lower(realm) == "redus"
end

local function normalizeBossName(name)
    if not name then
        return ""
    end
    local text = tostring(name)
    return text:lower():gsub("[^%w]", "")
end

local function trimText(value)
    if not value then
        return ""
    end
    return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local bossIgnoreList = {
    infinitetimereaver = true,
}

local function getUnitNameIfExists(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return nil
    end
    local name = UnitName(unit)
    if name and name ~= "" then
        return name
    end
    return nil
end

local lootPatterns = nil
local function buildLootPatterns()
    if lootPatterns then
        return
    end
    local function toPattern(fmt)
        if not fmt or fmt == "" then
            return nil
        end
        local pattern = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        pattern = pattern:gsub("%%d", "(%%d+)")
        pattern = pattern:gsub("%%s", "(.+)")
        return "^" .. pattern .. "$"
    end
    lootPatterns = {
        { pattern = toPattern(LOOT_ITEM_SELF), selfLoot = true },
        { pattern = toPattern(LOOT_ITEM_SELF_MULTIPLE), selfLoot = true },
        { pattern = toPattern(LOOT_ITEM_PUSHED_SELF), selfLoot = true },
        { pattern = toPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE), selfLoot = true },
        { pattern = toPattern(LOOT_ITEM), selfLoot = false },
        { pattern = toPattern(LOOT_ITEM_MULTIPLE), selfLoot = false },
        { pattern = toPattern(LOOT_ITEM_PUSHED), selfLoot = false },
        { pattern = toPattern(LOOT_ITEM_PUSHED_MULTIPLE), selfLoot = false },
    }
end

local function matchLootSender(message)
    buildLootPatterns()
    if not lootPatterns then
        return nil
    end
    for _, entry in ipairs(lootPatterns) do
        if entry.pattern then
            local a = message:match(entry.pattern)
            if a then
                if entry.selfLoot then
                    return Goals:GetPlayerName()
                end
                return a
            end
        end
    end
    return nil
end

function Events:Init()
    if self.frame then
        return
    end
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.frame:RegisterEvent("CHAT_MSG_LOOT")
    self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self.frame:RegisterEvent("LOOT_OPENED")
    self.frame:RegisterEvent("LOOT_SLOT_CLEARED")
    self.frame:RegisterEvent("LOOT_CLOSED")
    self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self.frame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("RAID_ROSTER_UPDATE")
    self.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self.frame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("BOSS_KILL")
    self.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if not self.watchFrame then
        self.watchFrame = CreateFrame("Frame")
        self.watchElapsed = 0
        self.watchFrame:SetScript("OnUpdate", function(_, elapsed)
            self.watchElapsed = (self.watchElapsed or 0) + (elapsed or 0)
            if self.watchElapsed < 1 then
                return
            end
            self.watchElapsed = 0
            self:WatchEncounterProgress()
        end)
    end
    self:BuildBossLookup()
    self:InitDBMCallbacks()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        Goals:Debug("Events initialized.")
    end
end

function Events:InitDBMCallbacks()
    if self.dbmHooked then
        return
    end
    if not DBM or not DBM.RegisterCallback then
        return
    end
    self.dbmHooked = true
    DBM:RegisterCallback("DBM_Pull", function(_, mod, delay, synced, startHp)
        self:HandleDBMPull(mod, delay, synced, startHp)
    end)
    DBM:RegisterCallback("DBM_Kill", function(_, mod)
        self:HandleDBMEnd(mod, true)
    end)
    DBM:RegisterCallback("DBM_Wipe", function(_, mod)
        self:HandleDBMEnd(mod, false)
    end)
end

function Events:GetDBMEncounterName(mod)
    if not mod then
        return nil
    end
    if mod.localization and mod.localization.general and mod.localization.general.name then
        return mod.localization.general.name
    end
    if mod.combatInfo and mod.combatInfo.name then
        return mod.combatInfo.name
    end
    if mod.name then
        return mod.name
    end
    if mod.id then
        return mod.id
    end
    return nil
end

function Events:HandleDBMPull(mod)
    if not (Goals and Goals.db and Goals.db.settings and Goals.db.settings.dbmIntegration) then
        return
    end
    local encounterName = self:GetDBMEncounterName(mod)
    if not encounterName then
        return
    end
    self:StartEncounter(encounterName)
end

function Events:HandleDBMEnd(mod, success)
    if not (Goals and Goals.db and Goals.db.settings and Goals.db.settings.dbmIntegration) then
        return
    end
    local encounterName = self:GetDBMEncounterName(mod)
    if not encounterName then
        return
    end
    if Goals.encounter.name ~= encounterName then
        Goals.encounter.name = encounterName
    end
    self:FinishEncounter(success)
end

function Events:BuildBossLookup()
    self.bossToEncounter = {}
    self.bossToEncounterNormalized = {}
    self.encounterBosses = {}
    self.encounterBossRequiredCounts = {}
    self.encounterFinalBosses = {}
    if type(_G.bossEncounters) ~= "table" then
        return
    end
    local redusRealm = isRedusRealm()
    for encounterName, data in pairs(_G.bossEncounters) do
        local set = {}
        local meta = { finalBosses = {}, requiredCounts = {} }
        if encounterName == "Chess Event" and not redusRealm then
            set["King Llane"] = true
            set["Warchief Blackhand"] = true
            meta.requiredCounts["King Llane"] = 1
            meta.requiredCounts["Warchief Blackhand"] = 1
        else
            self:CollectBossNames(data, set, meta)
        end
        if next(meta.finalBosses) then
            self.encounterFinalBosses[encounterName] = meta.finalBosses
        end
        if next(meta.requiredCounts) then
            self.encounterBossRequiredCounts[encounterName] = meta.requiredCounts
        end
        self.encounterBosses[encounterName] = set
        for bossName in pairs(set) do
            self.bossToEncounter[bossName] = encounterName
            local normalized = normalizeBossName(bossName)
            if normalized ~= "" and not self.bossToEncounterNormalized[normalized] then
                self.bossToEncounterNormalized[normalized] = {
                    encounter = encounterName,
                    boss = bossName,
                }
            end
        end
    end
    local allowTestBoss = Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss
    if not allowTestBoss then
        self.bossToEncounter["Garryowen Boar"] = nil
        self.encounterBosses["Garryowen Boar"] = nil
    end
end

function Events:CollectBossNames(data, set, meta)
    if type(data) == "string" then
        local name = data
        local finalName = data:match("^%[%*%]%s*(.+)$")
        if finalName then
            name = trimText(finalName)
            if meta and meta.finalBosses and name ~= "" then
                meta.finalBosses[name] = true
            end
        else
            local starName = data:match("^%*(.+)$")
            if starName then
                name = trimText(starName)
                if meta and meta.finalBosses and name ~= "" then
                    meta.finalBosses[name] = true
                end
            end
        end
        if name ~= "" then
            set[name] = true
            if meta and meta.requiredCounts then
                meta.requiredCounts[name] = (meta.requiredCounts[name] or 0) + 1
            end
        end
        return
    end
    if type(data) == "table" then
        if type(data.name) == "string" and data.name ~= "" then
            local name = trimText(data.name)
            if name ~= "" then
                set[name] = true
                if meta and meta.requiredCounts then
                    local count = math.floor(tonumber(data.count) or 1)
                    if count < 1 then
                        count = 1
                    end
                    meta.requiredCounts[name] = (meta.requiredCounts[name] or 0) + count
                end
                if data.final and meta and meta.finalBosses then
                    meta.finalBosses[name] = true
                end
            end
            return
        end
        for _, entry in pairs(data) do
            self:CollectBossNames(entry, set, meta)
        end
    end
end

function Events:TouchEncounterActivity(encounterName)
    if not (Goals and Goals.encounter and Goals.encounter.active) then
        return
    end
    if Goals.encounter.name ~= encounterName then
        return
    end
    local now = time()
    Goals.encounter.lastBossActivityTs = now
    Goals.encounter.lastBossUnitSeen = now
end

function Events:WatchEncounterProgress()
    if not (Goals and Goals.encounter and Goals.encounter.active) then
        return
    end
    local rule = Goals.encounter.rule
    if not rule or rule.type ~= "multi_kill" then
        return
    end
    local kills = Goals.encounter.kills
    if type(kills) ~= "table" then
        return
    end
    local hasProgress = false
    for _, count in pairs(kills) do
        if (tonumber(count) or 0) > 0 then
            hasProgress = true
            break
        end
    end
    if not hasProgress then
        return
    end
    local now = time()
    local lastActivity = Goals.encounter.lastBossActivityTs or Goals.encounter.startTime or now
    local lastSeen = Goals.encounter.lastBossUnitSeen or 0
    local resetAfter = tonumber(rule.attemptResetAfter) or 75
    if resetAfter <= 0 then
        return
    end
    if (now - lastActivity) < resetAfter then
        return
    end
    if lastSeen > 0 and (now - lastSeen) < resetAfter then
        return
    end
    Goals.encounter.kills = {}
    Goals.encounter.lastBossKillTs = nil
    Goals:Debug(string.format("Rule multi_kill progress reset after %ds inactivity: %s", resetAfter, Goals.encounter.name or "Encounter"))
end

function Events:GetEncounterRule(encounterName)
    if encounterName == "Chess Event" and isRedusRealm() then
        -- Redus uses a gauntlet-style chess event; keep default kill-through behavior
        -- (all configured pieces) but add grace to avoid false wipe during wave gaps.
        return {
            wipeGrace = 180,
        }
    end
    local explicit = _G.encounterRules and _G.encounterRules[encounterName] or nil
    if explicit then
        return explicit
    end
    local finalBosses = self.encounterFinalBosses and self.encounterFinalBosses[encounterName] or nil
    if not finalBosses or not next(finalBosses) then
        return nil
    end
    local list = {}
    for bossName in pairs(finalBosses) do
        table.insert(list, bossName)
    end
    table.sort(list)
    if #list == 1 then
        return {
            type = "final_boss_kill",
            finalBoss = list[1],
        }
    end
    return {
        type = "final_boss_kill",
        finalBosses = list,
    }
end

function Events:OnEvent(event, ...)
    if Goals and Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss then
        if not self.debugEventLogged then
            self.debugEventLogged = true
            Goals:Debug("Events active: " .. tostring(event))
        end
    end
    if event == "CHAT_MSG_LOOT" then
        self:HandleLootMessage(...)
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        Goals:ProcessPendingLoot()
        Goals:ProcessPendingWishlistInfo()
        return
    end
    if event == "LOOT_OPENED" then
        Goals:UpdateLootSlots(true)
        return
    end
    if event == "LOOT_SLOT_CLEARED" then
        Goals:UpdateLootSlots(false)
        return
    end
    if event == "LOOT_CLOSED" then
        Goals:ClearFoundLoot()
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:HandleCombatLog(...)
        return
    end
    if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        self:HandleHostileDeath(...)
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        self:HandleCombatStart()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:HandleCombatEnd()
        self:HandleCombatExit()
        return
    end
    if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "PARTY_LEADER_CHANGED" then
        self:HandleGroupUpdate()
        return
    end
    if event == "CHAT_MSG_ADDON" then
        Goals.Comm:OnMessage(...)
        return
    end
    if event == "BOSS_KILL" then
        local _, bossName = ...
        if bossName then
            self:MarkBossDead(bossName, true)
        end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        self:HandleUnitSpellcastSucceeded(...)
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" then
        self:ResetEncounter()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        self:ResetEncounter()
        self:HandleGroupUpdate()
        return
    end
end

function Events:HandleUnitSpellcastSucceeded(unit, spellName, _, _, spellId)
    if not (Goals and Goals.encounter and Goals.encounter.active) then
        return
    end
    local unitName = getUnitNameIfExists(unit)
    local encounterName, canonicalBoss = nil, nil
    if unitName then
        encounterName, canonicalBoss = self:GetEncounterForBossName(unitName)
    end
    if encounterName and encounterName == Goals.encounter.name then
        self:TouchEncounterActivity(encounterName)
    end
    local rule = Goals.encounter.rule
    if not rule or rule.type ~= "spellcast_success" then
        return
    end
    local requireCaster = rule.requireEncounterBossCaster ~= false
    if requireCaster then
        if not encounterName or encounterName ~= Goals.encounter.name then
            return
        end
        if type(rule.allowedCasters) == "table" and #rule.allowedCasters > 0 then
            local normalizedCaster = normalizeBossName(canonicalBoss or unitName)
            local allowed = false
            for _, allowedName in ipairs(rule.allowedCasters) do
                if normalizedCaster == normalizeBossName(allowedName) then
                    allowed = true
                    break
                end
            end
            if not allowed then
                return
            end
        end
    end
    local id = tonumber(spellId) or 0
    local match = false
    if rule.spellId and id > 0 then
        match = id == tonumber(rule.spellId)
    elseif rule.spellId and spellName and GetSpellInfo then
        local expectedName = GetSpellInfo(tonumber(rule.spellId) or 0)
        if expectedName and expectedName ~= "" then
            match = tostring(spellName) == tostring(expectedName)
        end
    elseif type(rule.spellIds) == "table" and id > 0 then
        for _, candidate in ipairs(rule.spellIds) do
            if id == tonumber(candidate) then
                match = true
                break
            end
        end
    elseif type(rule.spellIds) == "table" and spellName and GetSpellInfo then
        for _, candidate in ipairs(rule.spellIds) do
            local expectedName = GetSpellInfo(tonumber(candidate) or 0)
            if expectedName and expectedName ~= "" and tostring(spellName) == tostring(expectedName) then
                match = true
                break
            end
        end
    elseif rule.spellName and spellName then
        match = tostring(spellName) == tostring(rule.spellName)
    end
    if not match then
        return
    end
    Goals.encounter.lastBossKillTs = time()
    Goals:Debug(string.format("Rule spellcast_success complete: %s (%s)", Goals.encounter.name or "Encounter", tostring(id)))
    self:FinishEncounter(true)
end

function Events:CheckBossUnits(includeTargetFocus)
    local units = { "boss1", "boss2", "boss3", "boss4" }
    if includeTargetFocus then
        units[5] = "target"
        units[6] = "focus"
    end
    for _, unit in ipairs(units) do
        local name = getUnitNameIfExists(unit)
        if name then
            local encounterName, bossName = self:GetEncounterForBossName(name)
            if encounterName then
                Goals.encounter.lastBossUnitSeen = time()
                if Goals.encounter.active and Goals.encounter.name == encounterName then
                    Goals.encounter.lastBossActivityTs = time()
                end
                return encounterName, bossName
            end
        end
    end
    return nil
end

function Events:HandleGroupUpdate()
    Goals:EnsureGroupMembers()
    -- Auto-load seen players removed (account-bound overview).
    if Goals.DamageTracker and Goals.DamageTracker.HandleGroupUpdate then
        Goals.DamageTracker:HandleGroupUpdate()
    end
    if Goals:CanSync() and Goals.Comm and Goals.Comm.BroadcastVersion then
        Goals.Comm:BroadcastVersion()
    end
    local wasMaster = Goals.sync.isMaster
    Goals:UpdateSyncStatus()
    if Goals:CanSync() and Goals:IsSyncMaster() and not wasMaster then
        Goals.Comm:BroadcastFullSync("AUTO")
    elseif Goals:CanSync() and not Goals:IsSyncMaster() then
        Goals.sync.lastRequest = Goals.sync.lastRequest or 0
        if (GetTime() - Goals.sync.lastRequest) > 5 then
            Goals.sync.lastRequest = GetTime()
            Goals.Comm:RequestSync("AUTO")
        end
    end
    if Goals.UI then
        Goals.UI:Refresh()
    end
end

function Events:HandleLootMessage(message)
    local canAssign = Goals:IsSyncMaster() or (Goals.Dev and Goals.Dev.enabled)
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return
    end
    local playerName = matchLootSender(message)
    if not playerName then
        playerName = message:match("^(.+) receives loot")
        if playerName == "You" or (not playerName and message:find("^You receive loot")) then
            playerName = Goals:GetPlayerName()
        end
    end
    if not playerName then
        return
    end
    if Goals.HandleWishlistLoot then
        Goals:HandleWishlistLoot(itemLink)
    end
    if not canAssign then
        return
    end
    Goals:HandleLootAssignment(Goals:NormalizeName(playerName), itemLink, false, true)
end

function Events:HandleCombatLog(...)
    local args = nil
    if CombatLogGetCurrentEventInfo then
        args = { CombatLogGetCurrentEventInfo() }
    end
    if not args or #args == 0 then
        args = { ... }
    end
    if not args or #args == 0 then
        return
    end
    local eventType = args[2]
    local sourceName = args[5]
    local destName = args[9]
    if type(sourceName) ~= "string" and type(args[4]) == "string" then
        sourceName = args[4]
        destName = args[7]
    end
    if Goals.DamageTracker and Goals.DamageTracker.HandleCombatLog then
        Goals.DamageTracker:HandleCombatLog(unpack(args))
    end
    if Goals and Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss then
        if not self.debugCombatLogged then
            self.debugCombatLogged = true
            Goals:Debug("Combat log active: " .. tostring(eventType) .. " src=" .. tostring(sourceName) .. " dest=" .. tostring(destName))
        end
    end
    if Goals and Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss then
        if (eventType == "UNIT_DIED" or eventType == "PARTY_KILL") and destName then
            Goals:Debug("Combat log: " .. eventType .. " " .. tostring(destName))
        end
    end
    local inCombat = Goals:IsGroupInCombat()
    if inCombat and sourceName then
        local encounterName, canonicalBoss = self:GetEncounterForBossName(sourceName)
        if encounterName then
            self:StartEncounter(encounterName, canonicalBoss)
            self:TouchEncounterActivity(encounterName)
        end
    end
    if inCombat and destName then
        local encounterName, canonicalBoss = self:GetEncounterForBossName(destName)
        if encounterName then
            self:StartEncounter(encounterName, canonicalBoss)
            self:TouchEncounterActivity(encounterName)
        end
    end
    if (eventType == "UNIT_DIED" or eventType == "PARTY_KILL") and destName then
        if Goals.Dev and Goals.Dev.enabled and Goals.db.settings.devTestBoss then
            if normalizeBossName(destName) == normalizeBossName("Garryowen Boar") then
                Goals:AwardBossKill("Garryowen Boar")
                return
            end
        else
            local encounterName = self:GetEncounterForBossName(destName)
            if encounterName then
                self:MarkBossDead(destName, false)
            end
        end
    end
    local encounterName = self:CheckBossUnits(false)
    if encounterName then
        self:StartEncounter(encounterName)
    end
end

function Events:HandleHostileDeath(message)
    if not message or message == "" then
        return
    end
    if Goals and Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss then
        if not self.debugHostileLogged then
            self.debugHostileLogged = true
            Goals:Debug("Hostile death msg: " .. tostring(message))
        end
    end
    local name = message:match("^(.+) dies%.$") or message:match("^You have slain (.+)!$")
    if not name then
        return
    end
    if Goals and Goals.Dev and Goals.Dev.enabled and Goals.db and Goals.db.settings and Goals.db.settings.devTestBoss then
        Goals:Debug("Hostile death: " .. tostring(name))
        if normalizeBossName(name) == normalizeBossName("Garryowen Boar") then
            Goals:AwardBossKill("Garryowen Boar")
            return
        end
    end
    local encounterName = self:GetEncounterForBossName(name)
    if encounterName then
        self:MarkBossDead(name, false)
    end
end

function Events:GetEncounterForBossName(bossName)
    if not bossName then
        return nil
    end
    local normalized = normalizeBossName(bossName)
    if bossIgnoreList[normalized] then
        return nil
    end
    local encounterName = self.bossToEncounter and self.bossToEncounter[bossName] or nil
    if encounterName then
        return encounterName, bossName
    end
    local info = self.bossToEncounterNormalized and self.bossToEncounterNormalized[normalized] or nil
    if info then
        return info.encounter, info.boss
    end
    return nil
end

function Events:StartEncounter(encounterName, bossName)
    if Goals.encounter.active and Goals.encounter.name == encounterName then
        return
    end
    if Goals.encounter.lastCompletedName == encounterName then
        local lastTs = Goals.encounter.lastCompletedTs or 0
        if (time() - lastTs) < 30 then
            return
        end
    end
    Goals.encounter.active = true
    Goals.encounter.name = encounterName
    Goals.encounter.remaining = {}
    Goals.encounter.kills = {}
    Goals.encounter.deathTimes = {}
    Goals.encounter.deathEventTs = {}
    Goals.encounter.alive = {}
    Goals.encounter.cycles = 0
    Goals.encounter.rule = self:GetEncounterRule(encounterName)
    if Goals.encounter.rule and Goals.encounter.rule.type then
        Goals:Debug("Encounter rule: " .. encounterName .. " (" .. Goals.encounter.rule.type .. ")")
    end
    local bosses = self.encounterBosses[encounterName]
    local requiredCounts = self.encounterBossRequiredCounts and self.encounterBossRequiredCounts[encounterName] or nil
    if bosses then
        for name in pairs(bosses) do
            local count = requiredCounts and tonumber(requiredCounts[name]) or 1
            count = math.floor(count or 1)
            if count < 1 then
                count = 1
            end
            Goals.encounter.remaining[name] = count
            Goals.encounter.alive[name] = true
        end
    elseif bossName then
        Goals.encounter.remaining[bossName] = 1
        Goals.encounter.alive[bossName] = true
    end
    Goals.encounter.startTime = time()
    Goals.encounter.lastBossActivityTs = Goals.encounter.startTime
    Goals.encounter.lastBoss = bossName
    Goals:Debug("Encounter started: " .. encounterName)
    if Goals.History and Goals.History.AddEncounterStart then
        Goals.History:AddEncounterStart(encounterName)
    end
    if Goals.AnnounceEncounterStart then
        Goals:AnnounceEncounterStart(encounterName)
    end
    if Goals.DamageTracker and Goals.DamageTracker.AddBreakpoint then
        Goals.DamageTracker:AddBreakpoint(encounterName, "START")
    end
end

function Events:MarkBossDead(bossName, allowOutOfCombat)
    local encounterName, canonicalBoss = self:GetEncounterForBossName(bossName)
    if not encounterName then
        return
    end
    if not Goals.encounter.active and Goals.encounter.lastCompletedName == encounterName then
        local lastTs = Goals.encounter.lastCompletedTs or 0
        if (time() - lastTs) < 30 then
            return
        end
    end
    if not Goals.encounter.active and not allowOutOfCombat and not Goals:IsGroupInCombat() then
        return
    end
    if not Goals.encounter.active then
        self:StartEncounter(encounterName, canonicalBoss or bossName)
    end
    if Goals.encounter.name ~= encounterName then
        return
    end
    Goals.encounter.lastBossActivityTs = time()
    local rule = Goals.encounter.rule
    local bossKey = canonicalBoss or bossName
    local now = time()
    Goals.encounter.deathEventTs = Goals.encounter.deathEventTs or {}
    local lastDeathTs = Goals.encounter.deathEventTs[bossKey] or 0
    if (now - lastDeathTs) < 2 then
        return
    end
    Goals.encounter.deathEventTs[bossKey] = now
    if rule then
        if rule.type == "multi_kill" then
            Goals.encounter.kills[bossKey] = (Goals.encounter.kills[bossKey] or 0) + 1
            local required = rule.requiredKills or 1
            Goals:Debug(string.format("Rule multi_kill: %s %d/%d", bossKey, Goals.encounter.kills[bossKey], required))
            if Goals.encounter.kills[bossKey] >= required then
                Goals.encounter.lastBossKillTs = time()
                Goals:Debug("Rule multi_kill complete: " .. encounterName)
                self:FinishEncounter(true)
            end
            return
        elseif rule.type == "pair_revive" then
            if Goals.encounter.alive and Goals.encounter.alive[bossKey] == false then
                return
            end
            if Goals.encounter.alive then
                Goals.encounter.alive[bossKey] = false
            end
            local bosses = rule.bosses or {}
            local minFightTime = tonumber(rule.minFightTime) or 0
            if minFightTime > 0 and Goals.encounter.startTime and (now - Goals.encounter.startTime) < minFightTime then
                Goals.encounter.deathTimes[bossKey] = now
                return
            end
            local other
            for _, name in ipairs(bosses) do
                if name ~= bossKey then
                    other = name
                    break
                end
            end
            Goals.encounter.deathTimes[bossKey] = now
            local otherTime = other and Goals.encounter.deathTimes[other] or nil
            local window = rule.reviveWindow or 10
            Goals:Debug(string.format("Rule pair_revive: %s dead, window %ds", bossKey, window))
            if otherTime and (now - otherTime) <= window then
                Goals.encounter.cycles = (Goals.encounter.cycles or 0) + 1
                Goals.encounter.deathTimes[bossKey] = nil
                Goals.encounter.deathTimes[other] = nil
                local required = rule.requiredKills or 1
                Goals:Debug(string.format("Rule pair_revive cycle %d/%d", Goals.encounter.cycles, required))
                if Goals.encounter.cycles >= required then
                    Goals.encounter.lastBossKillTs = now
                    Goals:Debug("Rule pair_revive complete: " .. encounterName)
                    self:FinishEncounter(true)
                elseif Goals.encounter.alive then
                    for _, name in ipairs(bosses) do
                        Goals.encounter.alive[name] = true
                    end
                end
            end
            return
        elseif rule.type == "multi_death_window" then
            if Goals.encounter.alive and Goals.encounter.alive[bossKey] == false then
                return
            end
            if Goals.encounter.alive then
                Goals.encounter.alive[bossKey] = false
            end
            local now = time()
            local bosses = rule.bosses or {}
            Goals.encounter.deathTimes[bossKey] = now
            local minTime
            local maxTime
            for _, name in ipairs(bosses) do
                local ts = Goals.encounter.deathTimes[name]
                if not ts then
                    return
                end
                minTime = minTime and math.min(minTime, ts) or ts
                maxTime = maxTime and math.max(maxTime, ts) or ts
            end
            local window = rule.reviveWindow or 10
            Goals:Debug(string.format("Rule multi_death_window: all deaths seen, window %ds", window))
            if minTime and maxTime and (maxTime - minTime) <= window then
                Goals.encounter.cycles = (Goals.encounter.cycles or 0) + 1
                for _, name in ipairs(bosses) do
                    Goals.encounter.deathTimes[name] = nil
                end
                local required = rule.requiredKills or 1
                Goals:Debug(string.format("Rule multi_death_window cycle %d/%d", Goals.encounter.cycles, required))
                if Goals.encounter.cycles >= required then
                    Goals.encounter.lastBossKillTs = now
                    Goals:Debug("Rule multi_death_window complete: " .. encounterName)
                    self:FinishEncounter(true)
                elseif Goals.encounter.alive then
                    for _, name in ipairs(bosses) do
                        Goals.encounter.alive[name] = true
                    end
                end
            end
            return
        elseif rule.type == "final_boss_kill" then
            local normalizedBossKey = normalizeBossName(bossKey)
            local isFinal = false
            if rule.finalBoss then
                isFinal = normalizedBossKey == normalizeBossName(rule.finalBoss)
            elseif type(rule.finalBosses) == "table" then
                for _, name in ipairs(rule.finalBosses) do
                    if normalizedBossKey == normalizeBossName(name) then
                        isFinal = true
                        break
                    end
                end
            end
            Goals:Debug(string.format("Rule final_boss_kill: %s (final=%s)", bossKey, tostring(isFinal)))
            if isFinal then
                Goals.encounter.lastBossKillTs = time()
                Goals:Debug("Rule final_boss_kill complete: " .. encounterName)
                self:FinishEncounter(true)
            end
            return
        elseif rule.type == "any_boss_kill" then
            local bosses = rule.bosses or {}
            local normalizedBossKey = normalizeBossName(bossKey)
            local isMatch = false
            if #bosses == 0 then
                isMatch = true
            else
                for _, name in ipairs(bosses) do
                    if normalizedBossKey == normalizeBossName(name) then
                        isMatch = true
                        break
                    end
                end
            end
            Goals:Debug(string.format("Rule any_boss_kill: %s (match=%s)", bossKey, tostring(isMatch)))
            if isMatch then
                Goals.encounter.lastBossKillTs = time()
                local confirmDelay = tonumber(rule.confirmNoBossSeenFor) or 0
                if confirmDelay > 0 then
                    local token = tostring(Goals.encounter.lastBossKillTs) .. ":" .. tostring(bossKey)
                    Goals.encounter.pendingRuleConfirm = token
                    local maxChecks = 3
                    local function confirmAnyBossKill(checkIndex)
                        if not (Goals and Goals.encounter and Goals.encounter.active) then
                            return
                        end
                        if Goals.encounter.name ~= encounterName then
                            return
                        end
                        if Goals.encounter.pendingRuleConfirm ~= token then
                            return
                        end
                        if self:CheckBossUnits(true) then
                            if checkIndex < maxChecks then
                                Goals:Delay(2, function()
                                    confirmAnyBossKill(checkIndex + 1)
                                end)
                            else
                                Goals.encounter.pendingRuleConfirm = nil
                            end
                            return
                        end
                        local lastSeen = Goals.encounter.lastBossUnitSeen or 0
                        if lastSeen > 0 and (time() - lastSeen) < confirmDelay then
                            if checkIndex < maxChecks then
                                Goals:Delay(2, function()
                                    confirmAnyBossKill(checkIndex + 1)
                                end)
                            else
                                Goals.encounter.pendingRuleConfirm = nil
                            end
                            return
                        end
                        Goals.encounter.pendingRuleConfirm = nil
                        Goals:Debug("Rule any_boss_kill complete (confirmed): " .. encounterName)
                        self:FinishEncounter(true)
                    end
                    Goals:Delay(confirmDelay, function()
                        confirmAnyBossKill(1)
                    end)
                else
                    Goals:Debug("Rule any_boss_kill complete: " .. encounterName)
                    self:FinishEncounter(true)
                end
            end
            return
        end
    end
    if Goals.encounter.remaining then
        local remainingCount = tonumber(Goals.encounter.remaining[bossKey]) or 0
        if remainingCount > 1 then
            Goals.encounter.remaining[bossKey] = remainingCount - 1
        else
            Goals.encounter.remaining[bossKey] = nil
        end
        if not next(Goals.encounter.remaining) then
            Goals.encounter.lastBossKillTs = time()
            self:FinishEncounter(true)
        end
    end
end

function Events:HandleCombatEnd()
    if not Goals.encounter.active then
        return
    end
    Goals:Delay(5, function()
        local lastKill = Goals.encounter.lastBossKillTs or 0
        if lastKill > 0 and (time() - lastKill) < 20 then
            return
        end
        if self:CheckBossUnits(true) then
            return
        end
        local lastBossUnit = Goals.encounter.lastBossUnitSeen or 0
        if lastBossUnit > 0 and (time() - lastBossUnit) < 8 then
            return
        end
        local rule = Goals.encounter.rule
        local wipeGrace = rule and tonumber(rule.wipeGrace) or 0
        if wipeGrace and wipeGrace > 0 then
            local lastActivity = Goals.encounter.lastBossActivityTs or Goals.encounter.startTime or 0
            if lastActivity > 0 and (time() - lastActivity) < wipeGrace then
                return
            end
        end
        if Goals.encounter.active and not Goals:IsGroupInCombat() then
            self:FinishEncounter(false)
        end
    end)
end

function Events:HandleCombatStart()
    local encounterName = self:CheckBossUnits(false)
    if encounterName then
        self:StartEncounter(encounterName)
    end
    if not Goals or not Goals.db or not Goals.db.settings then
        return
    end
    if Goals.Dev and Goals.Dev.enabled then
        return
    end
    if not Goals.db.settings.autoMinimizeCombat then
        return
    end
    if not Goals.UI or not Goals.UI.frame or not Goals.UI.frame:IsShown() then
        return
    end
    Goals.state = Goals.state or {}
    if Goals.state.autoMinimizedThisCombat then
        return
    end
    Goals.state.autoMinimizedThisCombat = true
    Goals.UI:Minimize()

    if Goals.UI and Goals.UI.miniTracker and Goals.UI.miniTracker:IsShown() then
        Goals.state.autoMinimizedMini = true
        Goals.UI:ShowMiniTracker(false)
    end
end

function Events:HandleCombatExit()
    Goals.state = Goals.state or {}
    Goals.state.autoMinimizedThisCombat = false
    if Goals.state.autoMinimizedMini then
        Goals.state.autoMinimizedMini = false
        if Goals.UI then
            Goals.UI:ShowMiniTracker(true)
        end
    end
    if Goals.UI and Goals.UI.UpdateMiniTracker then
        Goals.UI:UpdateMiniTracker()
    end
end

function Events:FinishEncounter(success)
    local encounterName = Goals.encounter.name or "Encounter"
    if success and Goals.encounter.lastCompletedName == encounterName then
        local lastTs = Goals.encounter.lastCompletedTs or 0
        if (time() - lastTs) < 30 then
            return
        end
    end
    if not success and Goals.encounter.lastWipeName == encounterName then
        local lastTs = Goals.encounter.lastWipeTs or 0
        if (time() - lastTs) < 30 then
            return
        end
    end
    if Goals.DamageTracker and Goals.DamageTracker.AddBreakpoint then
        Goals.DamageTracker:AddBreakpoint(encounterName, success and "SUCCESS" or "FAIL")
    end
    Goals.encounter.active = false
    Goals.encounter.name = nil
    Goals.encounter.remaining = nil
    Goals.encounter.startTime = 0
    Goals.encounter.lastBossActivityTs = nil
    Goals.encounter.lastBossUnitSeen = nil
    Goals.encounter.lastBossKillTs = nil
    Goals.encounter.lastBoss = nil
    Goals.encounter.kills = nil
    Goals.encounter.deathTimes = nil
    Goals.encounter.deathEventTs = nil
    Goals.encounter.alive = nil
    Goals.encounter.cycles = 0
    Goals.encounter.rule = nil
    Goals.encounter.pendingRuleConfirm = nil
    if success then
        if Goals:IsSyncMaster() or (Goals.Dev and Goals.Dev.enabled) then
            Goals:AwardBossKill(encounterName)
        end
        Goals.encounter.lastCompletedName = encounterName
        Goals.encounter.lastCompletedTs = time()
        return
    end
    if Goals.AnnounceWipe then
        Goals:AnnounceWipe(encounterName)
    end
    if Goals.History then
        Goals.History:AddWipe(encounterName)
    end
    Goals:NotifyDataChanged()
    Goals.encounter.lastWipeName = encounterName
    Goals.encounter.lastWipeTs = time()
end

function Events:ResetEncounter()
    Goals.encounter.active = false
    Goals.encounter.name = nil
    Goals.encounter.remaining = nil
    Goals.encounter.startTime = 0
    Goals.encounter.lastBossActivityTs = nil
    Goals.encounter.lastBossUnitSeen = nil
    Goals.encounter.lastBossKillTs = nil
    Goals.encounter.lastBoss = nil
    Goals.encounter.kills = nil
    Goals.encounter.deathTimes = nil
    Goals.encounter.deathEventTs = nil
    Goals.encounter.alive = nil
    Goals.encounter.cycles = 0
    Goals.encounter.rule = nil
    Goals.encounter.pendingRuleConfirm = nil
end
