-- Goals: damageTracker.lua
-- Combat log damage tracking (optional).

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.DamageTracker = Goals.DamageTracker or {}
local DamageTracker = Goals.DamageTracker

local MAX_LOG_ENTRIES = 300
local THREAT_EVENT_WINDOW = 8
local THREAT_TARGET_HINT_WINDOW = 6
local DAMAGE_EVENTS = {
    SPELL_DAMAGE = true,
    RANGE_DAMAGE = true,
    SWING_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
}
local PERIODIC_DAMAGE_EVENTS = {
    SPELL_PERIODIC_DAMAGE = true,
}
local AURA_APPLY_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true,
}
local AURA_REMOVE_EVENTS = {
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_BROKEN = true,
    SPELL_AURA_BROKEN_SPELL = true,
}
local HEAL_EVENTS = {
    SPELL_HEAL = true,
    SPELL_PERIODIC_HEAL = true,
}
local PERIODIC_HEAL_EVENTS = {
    SPELL_PERIODIC_HEAL = true,
}
local DEATH_EVENTS = {
    UNIT_DIED = true,
    UNIT_DESTROYED = true,
    UNIT_DISSIPATES = true,
}
local PERIODIC_AURA_TTL = 120
local PERIODIC_AURA_DIRECT_WINDOW = 1.0
local PERIODIC_INCLUDE_DIRECT_WINDOW = 2.0
local bit_band = bit and bit.band or nil
local THREAT_DROP_SPELLS = {
    [66] = true,
    [586] = true, -- Fade
    [1038] = true,
    [1966] = true, -- Feint
    [1856] = true,
    [5384] = true,
    [29858] = true,
    [55342] = true, -- Mirror Image
}
local THREAT_RESET_SPELLS = {
    [18670] = true,
    [23339] = true,
}
local THREAT_INCREASE_SPELLS = {
    [355] = true, -- Taunt
    [1161] = true, -- Challenging Shout
    [694] = true, -- Mocking Blow
    [20736] = true, -- Distracting Shot
    [31789] = true, -- Righteous Defense
    [62124] = true, -- Hand of Reckoning
    [5209] = true, -- Challenging Roar
    [6795] = true, -- Growl
    [49576] = true, -- Death Grip
    [56222] = true, -- Dark Command
}
local THREAT_TRANSFER_SPELLS = {
    [34477] = true, -- Misdirection
    [57934] = true, -- Tricks of the Trade
}
local THREAT_PASSIVE_AURAS = {
    [71] = true, -- Defensive Stance
    [25780] = true, -- Righteous Fury
    [5487] = true, -- Bear Form
    [9634] = true, -- Dire Bear Form
    [48263] = true, -- Frost Presence
}

local function cloneEntry(entry)
    if type(entry) ~= "table" then
        return entry
    end
    local copy = {}
    for key, value in pairs(entry) do
        copy[key] = value
    end
    return copy
end

local function looksLikeGuid(value)
    return type(value) == "string" and value:match("^0x") ~= nil
end

local function detectCombatLogLayout(args)
    if not args then
        return nil
    end
    local count = #args
    for i = 1, count - 6 do
        if looksLikeGuid(args[i]) then
            local name = args[i + 1]
            local flags = args[i + 2]
            if (type(name) == "string" or name == nil) and type(flags) == "number" then
                if looksLikeGuid(args[i + 4]) then
                    return {
                        sourceGUID = i,
                        sourceName = i + 1,
                        sourceFlags = i + 2,
                        destGUID = i + 4,
                        destName = i + 5,
                        destFlags = i + 6,
                        spellBase = i + 8,
                        timestamp = i - 2,
                        subevent = i - 1,
                        hasRaidFlags = true,
                    }
                elseif looksLikeGuid(args[i + 3]) then
                    return {
                        sourceGUID = i,
                        sourceName = i + 1,
                        sourceFlags = i + 2,
                        destGUID = i + 3,
                        destName = i + 4,
                        destFlags = i + 5,
                        spellBase = i + 6,
                        timestamp = i - 2,
                        subevent = i - 1,
                        hasRaidFlags = false,
                    }
                end
            end
        end
    end
    return nil
end

local function parseSpellPayload(args, base, shift)
    local idx11 = 11 + base + shift
    local idx12 = 12 + base + shift
    local idx13 = 13 + base + shift
    local idx14 = 14 + base + shift
    local idx15 = 15 + base + shift
    local idx16 = 16 + base + shift

    if type(args[idx13]) == "string" then
        return tonumber(args[idx12]) or nil, args[idx13], args[idx15]
    end
    if type(args[idx12]) == "string" then
        return tonumber(args[idx11]) or nil, args[idx12], args[idx14]
    end
    if type(args[idx14]) == "string" then
        return tonumber(args[idx13]) or nil, args[idx14], args[idx16]
    end
    return tonumber(args[idx12]) or nil, args[idx13], args[idx15]
end

local function parseHealOverheal(args, spellBase)
    if not spellBase then
        return nil
    end
    return tonumber(args[spellBase + 4])
end

local function parseAuraPayload(args, spellBase)
    if not spellBase then
        return nil, nil
    end
    local spellId = tonumber(args[spellBase]) or nil
    local auraType = nil
    for i = 0, 6 do
        local value = args[spellBase + i]
        if value == "BUFF" or value == "DEBUFF" then
            auraType = value
            break
        end
    end
    return spellId, auraType
end

local function hasFlag(flags, mask)
    if not (flags and mask and bit_band) then
        return false
    end
    return bit_band(flags, mask) ~= 0
end

local function classifySource(name, flags)
    if not name or name == "" then
        return "unknown"
    end
    if Goals and Goals.Events and Goals.Events.GetEncounterForBossName then
        local encounter = Goals.Events:GetEncounterForBossName(name)
        if encounter then
            return "boss"
        end
    end
    if flags then
        if hasFlag(flags, COMBATLOG_OBJECT_TYPE_PLAYER) then
            return "player"
        end
        local isNpc = hasFlag(flags, COMBATLOG_OBJECT_CONTROL_NPC) or hasFlag(flags, COMBATLOG_OBJECT_TYPE_NPC)
        if isNpc then
            if hasFlag(flags, COMBATLOG_OBJECT_SPECIAL) then
                return "elite"
            end
            return "trash"
        end
    end
    return "unknown"
end

local function getAllLabel()
    return (Goals.L and Goals.L.DAMAGE_TRACKER_SHOW_ALL) or "Show all"
end

local function getBossLabel()
    return (Goals.L and Goals.L.DAMAGE_TRACKER_SHOW_BOSS) or "Show boss encounters"
end

local function getTrashLabel()
    return (Goals.L and Goals.L.DAMAGE_TRACKER_SHOW_TRASH) or "Show trash"
end

local function isHostileKind(kind)
    return kind == "boss" or kind == "elite" or kind == "trash"
end

local function normalizeSpellText(name)
    if not name then
        return ""
    end
    return tostring(name):lower()
end

local function isThreatDropSpell(spellId, spellName)
    if spellId and THREAT_DROP_SPELLS[tonumber(spellId) or -1] then
        return true
    end
    local n = normalizeSpellText(spellName)
    if n == "" then
        return false
    end
    if n:find("threat", 1, true) or n:find("aggro", 1, true) then
        return true
    end
    if n:find("salvation", 1, true) or n:find("soulshatter", 1, true) then
        return true
    end
    if n:find("vanish", 1, true) or n:find("feign death", 1, true) then
        return true
    end
    if n:find("fade", 1, true) or n:find("feint", 1, true) then
        return true
    end
    if n:find("invisibility", 1, true) then
        return true
    end
    if n:find("cower", 1, true) or n:find("wind shear", 1, true) then
        return true
    end
    if n:find("mirror image", 1, true) then
        return true
    end
    return false
end

local function isThreatResetSpell(spellId, spellName)
    if spellId and THREAT_RESET_SPELLS[tonumber(spellId) or -1] then
        return true
    end
    local n = normalizeSpellText(spellName)
    if n == "" then
        return false
    end
    if n:find("knock away", 1, true) or n:find("wing buffet", 1, true) then
        return true
    end
    if n:find("threat", 1, true) or n:find("aggro", 1, true) then
        return true
    end
    return false
end

local function getThreatAbilityDirection(spellId, spellName)
    local id = tonumber(spellId) or 0
    if id > 0 then
        if THREAT_INCREASE_SPELLS[id] then
            return "increase"
        end
        if THREAT_TRANSFER_SPELLS[id] then
            return "transfer"
        end
        if THREAT_DROP_SPELLS[id] then
            return "decrease"
        end
    end
    local n = normalizeSpellText(spellName)
    if n == "" then
        return nil
    end
    if n:find("taunt", 1, true) or n:find("mocking", 1, true) or n:find("growl", 1, true) or n:find("reckoning", 1, true) then
        return "increase"
    end
    if n:find("distracting shot", 1, true) then
        return "increase"
    end
    if n:find("searing pain", 1, true) then
        return "increase"
    end
    if n:find("misdirection", 1, true) or n:find("tricks of the trade", 1, true) then
        return "transfer"
    end
    if isThreatDropSpell(spellId, spellName) then
        return "decrease"
    end
    return nil
end

local function isPassiveThreatAura(spellId, spellName)
    if spellId and THREAT_PASSIVE_AURAS[tonumber(spellId) or -1] then
        return true
    end
    local n = normalizeSpellText(spellName)
    if n == "" then
        return false
    end
    if n:find("righteous fury", 1, true) or n:find("defensive stance", 1, true) then
        return true
    end
    if n:find("bear form", 1, true) or n:find("frost presence", 1, true) then
        return true
    end
    return false
end

local function getCombatLogArgs(...)
    if select("#", ...) > 0 then
        return ...
    end
    if CombatLogGetCurrentEventInfo then
        return CombatLogGetCurrentEventInfo()
    end
    return ...
end

local function normalizeName(name)
    if Goals and Goals.NormalizeName then
        return Goals:NormalizeName(name or "")
    end
    return name or ""
end

local function findUnitByGuid(guid)
    if not guid or not UnitGUID then
        return nil
    end
    if UnitGUID("player") == guid then
        return "player"
    end
    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    elseif Goals and Goals.IsInParty and Goals:IsInParty() then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if UnitGUID(unit) == guid then
                return unit
            end
        end
    end
    return nil
end

function DamageTracker:IsEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogTracking and true or false
end

function DamageTracker:IsHealingEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogHealing and true or false
end

function DamageTracker:IsOutgoingEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogTrackOutgoing and true or false
end

function DamageTracker:IsCombineAllEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogCombineAll and true or false
end

function DamageTracker:Init()
    Goals.state = Goals.state or {}
    if Goals.db then
        Goals.db.combatLog = Goals.db.combatLog or {}
        Goals.state.damageLog = Goals.db.combatLog
        Goals.db.combatLogRaw = Goals.db.combatLogRaw or Goals.db.combatLog or {}
        Goals.state.damageLogRaw = Goals.db.combatLogRaw
    else
        Goals.state.damageLog = Goals.state.damageLog or {}
        Goals.state.damageLogRaw = Goals.state.damageLogRaw or Goals.state.damageLog or {}
    end
    self.rosterGuids = self.rosterGuids or {}
    self.rosterNames = self.rosterNames or {}
    if Goals.db and Goals.db.settings then
        if Goals.db.settings.combatLogTracking == nil then
            Goals.db.settings.combatLogTracking = false
        end
    end
    self.activeCombines = self.activeCombines or {}
    self.castStarts = self.castStarts or {}
    self.lastHostileTargetBySource = self.lastHostileTargetBySource or {}
    self.lastHostileTargetSinceBySource = self.lastHostileTargetSinceBySource or {}
    self.recentThreatDropByTarget = self.recentThreatDropByTarget or {}
    self.recentThreatResetBySource = self.recentThreatResetBySource or {}
    self.startTs = self.startTs or time()
    self:RefreshRoster()
    self:RebuildPeriodicCombines()
end

function DamageTracker:SetEnabled(enabled)
    if not (Goals.db and Goals.db.settings) then
        return
    end
    Goals.db.settings.combatLogTracking = enabled and true or false
    if enabled then
        self:RefreshRoster()
    end
    if Goals.UI and Goals.UI.UpdateDamageTabVisibility then
        Goals.UI:UpdateDamageTabVisibility()
    end
    if Goals.UI and Goals.UI.UpdateDamageTrackerList then
        Goals.UI:UpdateDamageTrackerList()
    end
end

function DamageTracker:ClearLog()
    Goals.state.damageLog = {}
    Goals.state.damageLogRaw = {}
    if Goals.db then
        Goals.db.combatLog = Goals.state.damageLog
        Goals.db.combatLogRaw = Goals.state.damageLogRaw
    end
    self.startTs = time()
    self.activeCombines = {}
    self.castStarts = {}
    self.lastHostileTargetBySource = {}
    self.lastHostileTargetSinceBySource = {}
    self.recentThreatDropByTarget = {}
    self.recentThreatResetBySource = {}
end

function DamageTracker:TryCombineAll(entry)
    if not self:IsCombineAllEnabled() then
        return false
    end
    if not entry or not entry.kind or not entry.player then
        return false
    end
    if entry.kind ~= "DAMAGE" and entry.kind ~= "HEAL" and entry.kind ~= "DAMAGE_OUT" and entry.kind ~= "HEAL_OUT" then
        return false
    end
    local log = Goals.state.damageLog or {}
    local top = log[1]
    if top and top.kind == entry.kind and top.player == entry.player then
        top.amount = (tonumber(top.amount) or 0) + (tonumber(entry.amount) or 0)
        if entry.overheal then
            top.overheal = (tonumber(top.overheal) or 0) + (tonumber(entry.overheal) or 0)
        end
        top.ts = entry.ts or time()
        top.combineCount = (top.combineCount or 1) + 1
        top.spell = "Combined"
        top.source = "Multiple"
        return true
    end
    return false
end

function DamageTracker:AddEntry(entry)
    if type(entry) ~= "table" then
        return
    end
    local raw = Goals.state.damageLogRaw or {}
    table.insert(raw, 1, cloneEntry(entry))
    if #raw > MAX_LOG_ENTRIES then
        table.remove(raw)
    end
    Goals.state.damageLogRaw = raw
    if Goals.db then
        Goals.db.combatLogRaw = raw
    end
    if self:TryCombineAll(entry) then
        if Goals.UI and Goals.UI.currentTab == (Goals.UI.damageTabId or 0) and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
        return
    end
    if self:TryCombinePeriodic(entry) then
        if Goals.UI and Goals.UI.currentTab == (Goals.UI.damageTabId or 0) and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
        return
    end
    local log = Goals.state.damageLog or {}
    table.insert(log, 1, entry)
    if #log > MAX_LOG_ENTRIES then
        table.remove(log)
    end
    Goals.state.damageLog = log
    if Goals.db then
        Goals.db.combatLog = log
    end
    if Goals.UI and Goals.UI.currentTab == (Goals.UI.damageTabId or 0) and Goals.UI.UpdateDamageTrackerList then
        Goals.UI:UpdateDamageTrackerList()
    end
end

function DamageTracker:GetCombineGap()
    local gap = Goals and Goals.db and Goals.db.settings and tonumber(Goals.db.settings.combatLogCombineGap) or 6
    if gap < 1 then
        gap = 1
    end
    if gap > 60 then
        gap = 60
    end
    return gap
end

function DamageTracker:ShouldCombinePeriodic(entry)
    if not entry then
        return false
    end
    if entry.kind ~= "DAMAGE" and entry.kind ~= "DAMAGE_OUT" and entry.kind ~= "HEAL" and entry.kind ~= "HEAL_OUT" then
        return false
    end
    if not entry.periodic and not entry.combineDirect then
        return false
    end
    return Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatLogCombinePeriodic == true
end

function DamageTracker:TouchCombinedEntry(log, entry)
    if not log or not entry then
        return
    end
    for i = 1, #log do
        if log[i] == entry then
            table.remove(log, i)
            table.insert(log, 1, entry)
            return
        end
    end
end

function DamageTracker:TryCombinePeriodic(entry)
    if not self:ShouldCombinePeriodic(entry) then
        return false
    end
    self.activeCombines = self.activeCombines or {}
    local key = string.format("%s|%s|%s|%s",
        entry.kind or "DAMAGE",
        entry.player or "",
        tostring(entry.spellId or entry.spell or ""),
        entry.source or "")
    local combine = self.activeCombines[key]
    local now = entry.ts or time()
    local castStart = entry.castStart
    local gap = self:GetCombineGap()
    if combine and combine.entry then
        if castStart and combine.castStart and castStart ~= combine.castStart then
            combine = nil
        else
            local lastTs = combine.lastTs or combine.entry.ts or now
            if (not castStart) and (now - lastTs) > gap then
                combine = nil
            end
        end
    end
    if combine and combine.entry then
        local target = combine.entry
        target.amount = (tonumber(target.amount) or 0) + (tonumber(entry.amount) or 0)
        if entry.overheal then
            target.overheal = (tonumber(target.overheal) or 0) + (tonumber(entry.overheal) or 0)
        end
        target.combineCount = (tonumber(target.combineCount) or 0) + 1
        combine.lastTs = now
        target.combineStartTs = combine.startTs or target.combineStartTs or target.ts or now
        target.combineLastTs = combine.lastTs
        target.ts = now
        local startTs = target.combineStartTs or combine.lastTs
        local duration = math.floor((combine.lastTs - startTs) + 0.5)
        if target.combineCount and target.combineCount > 1 then
            local interval = (combine.lastTs - startTs) / (target.combineCount - 1)
            duration = math.floor((combine.lastTs - startTs + interval) + 0.5)
        end
        if duration < 1 then
            duration = 1
        end
        target.spellDuration = duration
        self:TouchCombinedEntry(Goals.state.damageLog, target)
        return true
    end
    local startTs = castStart or now
    entry.castStart = castStart
    entry.combineStartTs = startTs
    entry.combineLastTs = now
    entry.spellDuration = 1
    entry.combineCount = 1
    self.activeCombines[key] = {
        entry = entry,
        startTs = startTs,
        lastTs = now,
        castStart = castStart,
    }
    return false
end

function DamageTracker:RebuildPeriodicCombines()
    if not Goals or not Goals.state or not Goals.state.damageLogRaw then
        return
    end
    local log = Goals.state.damageLogRaw
    self.activeCombines = {}
    local rebuilt = {}
    Goals.state.damageLog = rebuilt
    local combinePeriodic = Goals.db and Goals.db.settings and Goals.db.settings.combatLogCombinePeriodic == true
    local combineAll = self:IsCombineAllEnabled()
    for i = #log, 1, -1 do
        local entry = log[i]
        local work = cloneEntry(entry)
        if entry then
            if work.kind == "BREAK" or work.kind == "DEATH" or work.kind == "RES" then
                table.insert(rebuilt, 1, work)
            else
                work.combineStartTs = nil
                work.combineLastTs = nil
                work.spellDuration = nil
                work.combineCount = nil
                if combineAll and self:TryCombineAll(work) then
                    -- combined into existing entry
                elseif combinePeriodic and self:ShouldCombinePeriodic(work) then
                    if not self:TryCombinePeriodic(work) then
                        table.insert(rebuilt, 1, work)
                    end
                else
                    table.insert(rebuilt, 1, work)
                end
            end
        end
    end
    if Goals.db then
        Goals.db.combatLog = rebuilt
    end
end

function DamageTracker:GetRosterNames()
    if not self.rosterNames or #self.rosterNames == 0 then
        self:RefreshRoster()
    end
    return self.rosterNames or {}
end

function DamageTracker:GetFilteredEntries(filter, opts)
    local log = Goals.state.damageLog or {}
    local allLabel = getAllLabel()
    local bossLabel = getBossLabel()
    local trashLabel = getTrashLabel()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local options = opts or {}
    local showThreat = true
    if settings and settings.combatLogShowThreat ~= nil then
        showThreat = settings.combatLogShowThreat and true or false
    end
    local showThreatAbilities = true
    if settings and settings.combatLogShowThreatAbilities ~= nil then
        showThreatAbilities = settings.combatLogShowThreatAbilities and true or false
    end
    local showBossHealing = true
    if settings and settings.combatLogShowBossHealing ~= nil then
        showBossHealing = settings.combatLogShowBossHealing and true or false
    end
    local threshold = settings and tonumber(settings.combatLogBigThreshold) or nil
    if threshold == nil and settings then
        local oldDamage = tonumber(settings.combatLogBigDamageThreshold)
        local oldHeal = tonumber(settings.combatLogBigHealingThreshold)
        if oldDamage or oldHeal then
            threshold = math.max(oldDamage or 0, oldHeal or 0)
        end
    end
    if threshold == nil then
        threshold = (settings and settings.combatLogShowBig) and 50 or 0
        if settings then
            settings.combatLogBigThreshold = threshold
        end
    end
    if threshold < 0 then
        threshold = 0
    elseif threshold > 100 then
        threshold = 100
    end
    local useBigFilter = threshold > 0 and not options.ignoreBigFilter
    local stats = nil
    if useBigFilter then
        stats = self:BuildEncounterStats(log)
    end
    local mode = "all"
    if filter == bossLabel then
        mode = "boss"
    elseif filter == trashLabel then
        mode = "trash"
    elseif not filter or filter == "" or filter == allLabel then
        mode = "all"
    end

    local function matchesScope(entry)
        if mode == "all" then
            return true
        end
        local kind = entry and (entry.hostileKind or entry.sourceKind) or nil
        if not kind then
            return mode == "all"
        end
        if mode == "boss" then
            return kind == "boss"
        end
        return kind == "trash" or kind == "elite"
    end

    local list = {}
    for _, entry in ipairs(log) do
        local kind = entry and entry.kind or nil
        if kind == "BREAK" then
            table.insert(list, entry)
        elseif kind == "THREAT" then
            if showThreat and matchesScope(entry) then
                table.insert(list, entry)
            end
        elseif kind == "THREAT_ABILITY" then
            if showThreatAbilities and matchesScope(entry) then
                table.insert(list, entry)
            end
        elseif kind == "INTERRUPT" then
            if matchesScope(entry) then
                table.insert(list, entry)
            end
        elseif kind == "DAMAGE" then
            if matchesScope(entry) then
                if not useBigFilter or self:IsBigEntry(entry, stats, "DAMAGE", threshold) then
                    table.insert(list, entry)
                end
            end
        elseif kind == "BOSS_HEAL" then
            if showBossHealing and matchesScope(entry) then
                if not useBigFilter or self:IsBigEntry(entry, stats, "HEAL", threshold) then
                    table.insert(list, entry)
                end
            end
        elseif kind == "DEATH" then
            table.insert(list, entry)
        elseif kind == "RES" and mode == "all" then
            table.insert(list, entry)
        end
    end
    if not self:IsCombineAllEnabled() then
        return list
    end
    return self:BuildCombinedList(list)
end

function DamageTracker:BuildCombinedList(entries)
    if not entries or #entries == 0 then
        return entries or {}
    end
    local combined = {}
    local map = {}
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if not entry or entry.kind == "BREAK" or entry.kind == "DEATH" or entry.kind == "RES" or entry.kind == "THREAT" or entry.kind == "THREAT_ABILITY" or entry.kind == "INTERRUPT" then
            table.insert(combined, entry)
        else
            local key = string.format("%s|%s", entry.kind or "DAMAGE", entry.player or "Unknown")
            local agg = map[key]
            if not agg then
                agg = {
                    kind = entry.kind,
                    player = entry.player,
                    amount = 0,
                    overheal = 0,
                    ts = entry.ts,
                    spell = "Combined",
                    source = "Multiple",
                    sourceKind = entry.sourceKind,
                    combineCount = 0,
                }
                map[key] = agg
                table.insert(combined, agg)
            end
            agg.amount = (tonumber(agg.amount) or 0) + (tonumber(entry.amount) or 0)
            if entry.overheal then
                agg.overheal = (tonumber(agg.overheal) or 0) + (tonumber(entry.overheal) or 0)
            end
            agg.combineCount = (agg.combineCount or 0) + 1
            if entry.ts and (not agg.ts or entry.ts > agg.ts) then
                agg.ts = entry.ts
            end
        end
    end
    table.sort(combined, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)
    return combined
end

function DamageTracker:BuildEncounterStats(log)
    local stats = {}
    local encounterId = 0
    local activeId = nil
    local sawBreak = false
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.kind == "BREAK" then
            sawBreak = true
            if entry.status == "START" then
                encounterId = encounterId + 1
                activeId = encounterId
                stats[activeId] = {
                    dmgTotal = 0,
                    dmgCount = 0,
                    healTotal = 0,
                    healCount = 0,
                    maxDamage = 0,
                    maxHeal = 0,
                }
                entry.encounterId = activeId
            elseif entry.status == "SUCCESS" or entry.status == "FAIL" then
                entry.encounterId = activeId
                activeId = nil
            else
                entry.encounterId = activeId
            end
        else
            entry.encounterId = activeId
            if activeId and entry.amount then
                local amount = tonumber(entry.amount) or 0
                if entry.kind == "DAMAGE" and amount > 0 then
                    stats[activeId].dmgTotal = stats[activeId].dmgTotal + amount
                    stats[activeId].dmgCount = stats[activeId].dmgCount + 1
                    if amount > (stats[activeId].maxDamage or 0) then
                        stats[activeId].maxDamage = amount
                    end
                elseif entry.kind == "BOSS_HEAL" and amount > 0 then
                    stats[activeId].healTotal = stats[activeId].healTotal + amount
                    stats[activeId].healCount = stats[activeId].healCount + 1
                    if amount > (stats[activeId].maxHeal or 0) then
                        stats[activeId].maxHeal = amount
                    end
                end
            end
        end
    end
    if not sawBreak then
        stats[1] = {
            dmgTotal = 0,
            dmgCount = 0,
            healTotal = 0,
            healCount = 0,
            maxDamage = 0,
            maxHeal = 0,
        }
        for i = #log, 1, -1 do
            local entry = log[i]
            if entry.kind ~= "BREAK" then
                entry.encounterId = 1
                if entry.amount then
                    local amount = tonumber(entry.amount) or 0
                    if entry.kind == "DAMAGE" and amount > 0 then
                        stats[1].dmgTotal = stats[1].dmgTotal + amount
                        stats[1].dmgCount = stats[1].dmgCount + 1
                        if amount > (stats[1].maxDamage or 0) then
                            stats[1].maxDamage = amount
                        end
                    elseif entry.kind == "BOSS_HEAL" and amount > 0 then
                        stats[1].healTotal = stats[1].healTotal + amount
                        stats[1].healCount = stats[1].healCount + 1
                        if amount > (stats[1].maxHeal or 0) then
                            stats[1].maxHeal = amount
                        end
                    end
                end
            end
        end
    end
    for _, stat in pairs(stats) do
        stat.avgDamage = (stat.dmgCount > 0) and (stat.dmgTotal / stat.dmgCount) or 0
        stat.avgHeal = (stat.healCount > 0) and (stat.healTotal / stat.healCount) or 0
    end
    return stats
end

function DamageTracker:IsBigEntry(entry, stats, kind, thresholdPercent)
    if not entry or not stats then
        return false
    end
    local threshold = tonumber(thresholdPercent) or 0
    if threshold <= 0 then
        return true
    end
    local encounterId = entry.encounterId
    if not encounterId then
        return true
    end
    local stat = stats[encounterId]
    if not stat then
        return true
    end
    local amount = tonumber(entry.amount) or 0
    if kind == "HEAL" then
        local maxAmount = tonumber(stat.maxHeal) or 0
        if maxAmount <= 0 then
            return true
        end
        return amount >= (maxAmount * (threshold / 100))
    end
    local maxAmount = tonumber(stat.maxDamage) or 0
    if maxAmount <= 0 then
        return true
    end
    return amount >= (maxAmount * (threshold / 100))
end

function DamageTracker:AddBreakpoint(encounterName, status)
    if not self:IsEnabled() then
        return
    end
    local name = encounterName or "Encounter"
    local state = status or "START"
    local label
    if state == "START" then
        label = string.format("%s started", name)
    elseif state == "SUCCESS" then
        label = string.format("%s completed successfully", name)
    elseif state == "FAIL" then
        local groupLabel = (Goals and Goals.IsInRaid and Goals:IsInRaid()) and "Raid" or "Party"
        label = string.format("%s failed: %s wiped", name, groupLabel)
    else
        label = string.format("%s updated", name)
    end
    self:AddEntry({
        ts = time(),
        kind = "BREAK",
        encounter = name,
        status = state,
        label = label,
    })
end

function DamageTracker:RefreshRoster()
    local guidMap = {}
    local names = {}
    local nameMap = {}

    local function addUnit(unit)
        if not UnitExists or not UnitExists(unit) then
            return
        end
        local name = UnitName(unit)
        local guid = UnitGUID(unit)
        if name and guid then
            local normalized = normalizeName(name)
            guidMap[guid] = normalized
            table.insert(names, normalized)
            nameMap[normalized] = true
        end
    end

    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            addUnit("raid" .. i)
        end
    elseif Goals and Goals.IsInParty and Goals:IsInParty() then
        addUnit("player")
        for i = 1, GetNumPartyMembers() do
            addUnit("party" .. i)
        end
    else
        addUnit("player")
    end

    table.sort(names)
    self.rosterGuids = guidMap
    self.rosterNames = names
    self.rosterNameMap = nameMap

    if Goals.UI and Goals.UI.RefreshDamageTrackerDropdown then
        Goals.UI:RefreshDamageTrackerDropdown()
    end
end

function DamageTracker:HandleGroupUpdate()
    if not self:IsEnabled() then
        return
    end
    self:RefreshRoster()
end

function DamageTracker:TrackPeriodicAura(subevent, sourceKey, destKey, spellId, auraType, timestamp)
    if not (subevent and sourceKey and destKey and spellId and auraType) then
        return
    end
    if auraType ~= "DEBUFF" and auraType ~= "BUFF" then
        return
    end
    self.periodicAuras = self.periodicAuras or {}
    local key = string.format("%s|%s|%s", tostring(sourceKey), tostring(destKey), tostring(spellId))
    if AURA_APPLY_EVENTS[subevent] then
        self.periodicAuras[key] = {
            ts = timestamp or time(),
            event = subevent,
            auraType = auraType,
        }
    elseif AURA_REMOVE_EVENTS[subevent] then
        self.periodicAuras[key] = nil
    end
end

function DamageTracker:IsPeriodicAuraActive(sourceKey, destKey, spellId, wantAuraType, timestamp)
    if not (sourceKey and destKey and spellId) then
        return false
    end
    local key = string.format("%s|%s|%s", tostring(sourceKey), tostring(destKey), tostring(spellId))
    local aura = self.periodicAuras and self.periodicAuras[key]
    if not aura then
        return false
    end
    if wantAuraType and aura.auraType and aura.auraType ~= wantAuraType then
        return false
    end
    local now = timestamp or time()
    if aura.ts and (now - aura.ts) > PERIODIC_AURA_TTL then
        self.periodicAuras[key] = nil
        return false
    end
    if aura.event == "SPELL_AURA_APPLIED" and aura.ts and (now - aura.ts) <= PERIODIC_AURA_DIRECT_WINDOW then
        return false
    end
    return true
end

function DamageTracker:HasPeriodicAura(sourceKey, destKey, spellId, wantAuraType, timestamp)
    if not (sourceKey and destKey and spellId) then
        return false
    end
    local key = string.format("%s|%s|%s", tostring(sourceKey), tostring(destKey), tostring(spellId))
    local aura = self.periodicAuras and self.periodicAuras[key]
    if not aura then
        return false
    end
    if wantAuraType and aura.auraType and aura.auraType ~= wantAuraType then
        return false
    end
    local now = timestamp or time()
    if aura.ts and (now - aura.ts) > PERIODIC_AURA_TTL then
        self.periodicAuras[key] = nil
        return false
    end
    if aura.event == "SPELL_AURA_APPLIED" and aura.ts and (now - aura.ts) > PERIODIC_INCLUDE_DIRECT_WINDOW then
        return false
    end
    return true
end

function DamageTracker:IsPeriodicDamage(subevent, sourceKey, destKey, spellId, timestamp)
    if PERIODIC_DAMAGE_EVENTS[subevent] then
        return true
    end
    return self:IsPeriodicAuraActive(sourceKey, destKey, spellId, "DEBUFF", timestamp)
end

function DamageTracker:IsPeriodicHeal(subevent, sourceKey, destKey, spellId, timestamp)
    if PERIODIC_HEAL_EVENTS[subevent] then
        return true
    end
    return self:IsPeriodicAuraActive(sourceKey, destKey, spellId, "BUFF", timestamp)
end

function DamageTracker:HandleCombatLog(...)
    if not self:IsEnabled() then
        return
    end
    local args = { ... }
    if not args[2] and CombatLogGetCurrentEventInfo then
        args = { CombatLogGetCurrentEventInfo() }
    end
    local layout = detectCombatLogLayout(args)
    local timestamp = args[1]
    local subevent = args[2]
    local sourceGUID = nil
    local sourceName = nil
    local sourceFlags = nil
    local destGUID = nil
    local destName = nil
    local destFlags = nil
    local spellBase = nil

    if layout then
        if layout.timestamp and layout.timestamp >= 1 then
            timestamp = args[layout.timestamp]
        end
        if layout.subevent and layout.subevent >= 1 then
            subevent = args[layout.subevent]
        end
        sourceGUID = args[layout.sourceGUID]
        sourceName = args[layout.sourceName]
        sourceFlags = args[layout.sourceFlags]
        destGUID = args[layout.destGUID]
        destName = args[layout.destName]
        destFlags = args[layout.destFlags]
        spellBase = layout.spellBase
    else
        local base = 0
        if type(args[1]) == "string" and (args[1] == "COMBAT_LOG_EVENT" or args[1] == "COMBAT_LOG_EVENT_UNFILTERED") then
            base = 2
        end
        timestamp = args[1 + base]
        subevent = args[2 + base]
        sourceGUID = args[4 + base]
        sourceName = args[5 + base]
        sourceFlags = args[6 + base]
        destGUID = args[8 + base]
        destName = args[9 + base]
        spellBase = 12 + base
    end

    Goals.state = Goals.state or {}
    Goals.state.combatLogDebug = Goals.state.combatLogDebug or {}
    local debug = Goals.state.combatLogDebug
    debug.count = (debug.count or 0) + 1
    debug.lastEvent = subevent or ""
    debug.lastSource = sourceName or ""
    debug.lastDest = destName or ""
    debug.lastTs = timestamp or time()
    debug.lastAdded = false
    debug.lastSkip = nil
    if subevent == "SPELL_CAST_SUCCESS" then
        local spellId, spellName = nil, nil
        if spellBase and type(args[spellBase + 1]) == "string" then
            spellId = tonumber(args[spellBase]) or nil
            spellName = args[spellBase + 1]
        else
            spellId, spellName = parseSpellPayload(args, 0, 0)
        end
        if spellId or spellName then
            self.castStarts = self.castStarts or {}
            local key = string.format("%s|%s", tostring(sourceGUID or sourceName or "unknown"), tostring(spellId or spellName))
            self.castStarts[key] = timestamp or time()
            local sourceKind = classifySource(sourceName, sourceFlags)
            if isHostileKind(sourceKind) and isThreatResetSpell(spellId, spellName) then
                self.recentThreatResetBySource = self.recentThreatResetBySource or {}
                self.recentThreatResetBySource[tostring(sourceGUID or sourceName or "unknown")] = {
                    ts = timestamp or time(),
                    spell = spellName or "Threat Reset",
                }
            end
            if not (self.rosterGuids and next(self.rosterGuids)) then
                self:RefreshRoster()
            end
            local normalizedSource = normalizeName(sourceName)
            local isRosterSource = (sourceGUID and self.rosterGuids and self.rosterGuids[sourceGUID])
                or (normalizedSource ~= "" and self.rosterNameMap and self.rosterNameMap[normalizedSource])
            if isRosterSource then
                local direction = getThreatAbilityDirection(spellId, spellName)
                if direction then
                    local srcName = (sourceGUID and self.rosterGuids and self.rosterGuids[sourceGUID]) or normalizedSource or normalizeName(sourceName)
                    local targetKind = classifySource(destName, destFlags)
                    local directionText = "Threat"
                    if direction == "increase" then
                        directionText = "Threat+"
                    elseif direction == "decrease" then
                        directionText = "Threat-"
                    elseif direction == "transfer" then
                        directionText = "Threat->"
                    end
                    self:AddEntry({
                        ts = timestamp,
                        player = srcName ~= "" and srcName or "Unknown",
                        source = destName or "Unknown",
                        kind = "THREAT_ABILITY",
                        spell = spellName or "Unknown",
                        spellId = spellId,
                        threatDir = direction,
                        reason = directionText,
                        sourceKind = "player",
                        hostileKind = isHostileKind(targetKind) and targetKind or nil,
                    })
                    debug.lastAdded = true
                end
            end
        end
        return
    end
    local playerGuid = UnitGUID and UnitGUID("player") or nil
    local normalizedDest = normalizeName(destName)
    local normalizedSource = normalizeName(sourceName)
    if not (self.rosterGuids and next(self.rosterGuids)) then
        self:RefreshRoster()
    end
    local rosterMap = self.rosterNameMap or {}
    local isRosterDest = (destGUID and (destGUID == playerGuid or (self.rosterGuids and self.rosterGuids[destGUID])))
        or (normalizedDest ~= "" and rosterMap[normalizedDest])
    local isRosterSource = (sourceGUID and (sourceGUID == playerGuid or (self.rosterGuids and self.rosterGuids[sourceGUID])))
        or (normalizedSource ~= "" and rosterMap[normalizedSource])
    local sourceKindPre = classifySource(sourceName, sourceFlags)
    local allowHostileHealOnly = HEAL_EVENTS[subevent] and isHostileKind(sourceKindPre)
    if not isRosterDest and not isRosterSource and not allowHostileHealOnly then
        debug.lastSkip = "Not roster dest"
        return
    end
    if not subevent then
        debug.lastSkip = "No subevent"
        return
    end

    if AURA_APPLY_EVENTS[subevent] or AURA_REMOVE_EVENTS[subevent] then
        local spellId, auraType = parseAuraPayload(args, spellBase)
        local auraName = args[(spellBase or 0) + 1]
        if isRosterDest and (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REMOVED") and isPassiveThreatAura(spellId, auraName) then
            local actorName = (destGUID and self.rosterGuids and self.rosterGuids[destGUID]) or normalizedDest or (destName or "Unknown")
            local isApplied = subevent == "SPELL_AURA_APPLIED"
            self:AddEntry({
                ts = timestamp,
                player = actorName ~= "" and actorName or "Unknown",
                source = "Self",
                kind = "THREAT_ABILITY",
                spell = auraName or "Passive threat stance",
                spellId = spellId,
                threatDir = isApplied and "increase" or "decrease",
                reason = isApplied and "Threat+ (Passive)" or "Threat- (Passive Off)",
                sourceKind = "player",
                hostileKind = nil,
            })
            debug.lastAdded = true
        end
        if AURA_APPLY_EVENTS[subevent] and isRosterDest and isThreatDropSpell(spellId, args[(spellBase or 0) + 1]) then
            self.recentThreatDropByTarget = self.recentThreatDropByTarget or {}
            local key = normalizeName(destName)
            if key ~= "" then
                self.recentThreatDropByTarget[key] = {
                    ts = timestamp or time(),
                    spell = args[(spellBase or 0) + 1] or "Threat Drop",
                }
            end
        end
        self:TrackPeriodicAura(
            subevent,
            sourceGUID or sourceName or "unknown",
            destGUID or destName or "unknown",
            spellId,
            auraType,
            timestamp
        )
        debug.lastSkip = "Aura event"
        return
    end

    if subevent == "SPELL_INTERRUPT" then
        local sourceKind = classifySource(sourceName, sourceFlags)
        local targetKind = classifySource(destName, destFlags)
        local actorName = sourceName or "Unknown"
        if sourceGUID and self.rosterGuids and self.rosterGuids[sourceGUID] then
            actorName = self.rosterGuids[sourceGUID]
        elseif normalizeName(actorName) == normalizeName(Goals and Goals.GetPlayerName and Goals:GetPlayerName() or "") then
            actorName = Goals:GetPlayerName()
        end
        local targetName = destName or "Unknown"
        local interruptSpellName = nil
        local canceledSpellName = nil
        if spellBase and type(args[spellBase + 1]) == "string" then
            interruptSpellName = args[spellBase + 1]
            if type(args[spellBase + 5]) == "string" then
                canceledSpellName = args[spellBase + 5]
            elseif type(args[spellBase + 4]) == "string" then
                canceledSpellName = args[spellBase + 4]
            end
        else
            local _, name = parseSpellPayload(args, 0, 0)
            interruptSpellName = name
            if type(args[16]) == "string" then
                canceledSpellName = args[16]
            elseif type(args[15]) == "string" then
                canceledSpellName = args[15]
            end
        end
        local hostileKind = nil
        if isHostileKind(targetKind) then
            hostileKind = targetKind
        elseif isHostileKind(sourceKind) then
            hostileKind = sourceKind
        end
        if hostileKind then
            local reason = canceledSpellName and ("Interrupted " .. canceledSpellName) or "Interrupted cast"
            self:AddEntry({
                ts = timestamp,
                player = actorName,
                source = targetName,
                kind = "INTERRUPT",
                spell = interruptSpellName or "Interrupt",
                interruptedSpell = canceledSpellName,
                reason = reason,
                sourceKind = sourceKind,
                actorKind = sourceKind,
                targetKind = targetKind,
                hostileKind = hostileKind,
            })
            debug.lastAdded = true
        else
            debug.lastSkip = "Interrupt without hostile target"
        end
        return
    end

    local playerName = (destGUID and self.rosterGuids[destGUID]) or (isRosterDest and normalizedDest) or normalizeName(destName)
    local sourceKind = classifySource(sourceName, sourceFlags)
    local amount
    local spellName
    if DAMAGE_EVENTS[subevent] then
        local spellId = nil
        if subevent == "SWING_DAMAGE" then
            amount = spellBase and tonumber(args[spellBase]) or nil
            if not amount then
                amount = tonumber(args[spellBase and (spellBase + 1) or 0]) or tonumber(args[spellBase and (spellBase + 2) or 0])
            end
            spellName = "Melee"
        else
            if spellBase then
                if type(args[spellBase + 1]) == "string" then
                    spellId = tonumber(args[spellBase]) or nil
                    spellName = args[spellBase + 1]
                    amount = args[spellBase + 3]
                else
                    local id, name, amt = parseSpellPayload(args, 0, 0)
                    spellId, spellName, amount = id, name, amt
                end
            else
                spellId, spellName, amount = parseSpellPayload(args, 0, 0)
            end
        end
        amount = tonumber(amount or 0) or 0
        if amount <= 0 then
            debug.lastSkip = "Zero damage"
            return
        end
        local source = sourceName or "Unknown"
        local periodic = self:IsPeriodicDamage(
            subevent,
            sourceGUID or sourceName or "unknown",
            destGUID or destName or "unknown",
            spellId,
            timestamp
        )
        local combineDirect = false
        if not periodic and spellId then
            combineDirect = self:HasPeriodicAura(
                sourceGUID or sourceName or "unknown",
                destGUID or destName or "unknown",
                spellId,
                "DEBUFF",
                timestamp
            )
        end
        local castStart = nil
        if periodic then
            self.castStarts = self.castStarts or {}
            local key = string.format("%s|%s", tostring(sourceGUID or sourceName or "unknown"), tostring(spellId or spellName or ""))
            castStart = self.castStarts[key]
        end
        if isRosterDest then
            if (not playerName or playerName == "") and Goals and Goals.GetPlayerName and destGUID == playerGuid then
                playerName = Goals:GetPlayerName()
            end
            if not playerName or playerName == "" then
                debug.lastSkip = "No player name"
                return
            end
            self:AddEntry({
                ts = timestamp,
                player = playerName ~= "" and playerName or "Unknown",
                amount = amount,
                spell = spellName or "Unknown",
                spellId = spellId,
                source = source,
                kind = "DAMAGE",
                periodic = periodic,
                combineDirect = combineDirect,
                castStart = castStart,
                sourceFlags = sourceFlags,
                sourceKind = sourceKind,
            })
            if isHostileKind(sourceKind) then
                self.lastHostileTargetBySource = self.lastHostileTargetBySource or {}
                self.lastHostileTargetSinceBySource = self.lastHostileTargetSinceBySource or {}
                local sourceKey = tostring(sourceGUID or sourceName or "unknown")
                local previousTarget = self.lastHostileTargetBySource[sourceKey]
                local currentTarget = playerName
                local previousSince = self.lastHostileTargetSinceBySource[sourceKey] or (timestamp or time())
                if previousTarget and previousTarget ~= "" and currentTarget and currentTarget ~= "" and normalizeName(previousTarget) ~= normalizeName(currentTarget) then
                    local nowTs = timestamp or time()
                    local heldFor = math.floor(math.max(0, nowTs - previousSince) + 0.5)
                    local reason = "Aggro changed due to higher threat."
                    local newDrop = self.recentThreatDropByTarget and self.recentThreatDropByTarget[normalizeName(currentTarget)] or nil
                    if newDrop and (nowTs - (newDrop.ts or 0)) <= THREAT_TARGET_HINT_WINDOW then
                        reason = string.format("New target dropped threat: %s.", newDrop.spell or "Unknown")
                    else
                        local prevDrop = self.recentThreatDropByTarget and self.recentThreatDropByTarget[normalizeName(previousTarget)] or nil
                        if prevDrop and (nowTs - (prevDrop.ts or 0)) <= THREAT_TARGET_HINT_WINDOW then
                            reason = string.format("Previous target dropped threat: %s.", prevDrop.spell or "Unknown")
                        else
                            local reset = self.recentThreatResetBySource and self.recentThreatResetBySource[sourceKey] or nil
                            if reset and (nowTs - (reset.ts or 0)) <= THREAT_EVENT_WINDOW then
                                reason = string.format("Boss cast threat reset: %s.", reset.spell or "Unknown")
                            end
                        end
                    end
                    reason = string.format("%s Previous target held aggro for %ds.", reason, heldFor)
                    self:AddEntry({
                        ts = timestamp,
                        player = currentTarget,
                        source = sourceName or "Unknown",
                        kind = "THREAT",
                        spell = "Threat Change",
                        reason = reason,
                        holdDuration = heldFor,
                        previousTarget = previousTarget,
                        sourceKind = sourceKind,
                        hostileKind = sourceKind,
                    })
                end
                self.lastHostileTargetBySource[sourceKey] = currentTarget
                self.lastHostileTargetSinceBySource[sourceKey] = timestamp or time()
            end
        end
        if isRosterDest then
            debug.lastAdded = true
        else
            debug.lastSkip = "Ignore outgoing damage"
        end
        return
    end

    if HEAL_EVENTS[subevent] then
        local spellId
        if spellBase then
            if type(args[spellBase + 1]) == "string" then
                spellId = tonumber(args[spellBase]) or nil
                spellName = args[spellBase + 1]
                amount = args[spellBase + 3]
            else
                local id, name, amt = parseSpellPayload(args, 0, 0)
                spellId, spellName, amount = id, name, amt
            end
        else
            spellId, spellName, amount = parseSpellPayload(args, 0, 0)
        end
        amount = tonumber(amount or 0) or 0
        local overheal = parseHealOverheal(args, spellBase)
        if overheal and overheal > 0 then
            local effective = amount - overheal
            if effective < 0 then
                effective = 0
            end
            amount = effective
        end
        if amount <= 0 and not (overheal and overheal > 0) then
            debug.lastSkip = "Zero heal"
            return
        end
        local source = sourceName or "Unknown"
        local sourceKind = classifySource(sourceName, sourceFlags)
        local targetKind = classifySource(destName, destFlags)
        if isHostileKind(sourceKind) then
            local targetName = destName or "Unknown"
            self:AddEntry({
                ts = timestamp,
                player = targetName,
                amount = amount,
                spell = spellName or "Unknown",
                spellId = spellId,
                source = source,
                kind = "BOSS_HEAL",
                sourceFlags = sourceFlags,
                sourceKind = sourceKind,
                hostileKind = sourceKind,
                targetKind = targetKind,
                overheal = overheal,
            })
            debug.lastAdded = true
            return
        end
        debug.lastSkip = "Ignore non-hostile heal"
        return
    end

    if DEATH_EVENTS[subevent] then
        if not isRosterDest then
            debug.lastSkip = "Not roster dest"
            return
        end
        if (not playerName or playerName == "") and Goals and Goals.GetPlayerName and destGUID == playerGuid then
            playerName = Goals:GetPlayerName()
        end
        if not playerName or playerName == "" then
            debug.lastSkip = "No player name"
            return
        end
        self:AddEntry({
            ts = timestamp,
            player = playerName ~= "" and playerName or "Unknown",
            kind = "DEATH",
        })
        debug.lastAdded = true
        return
    end

    if subevent == "SPELL_RESURRECT" then
        if not isRosterDest then
            debug.lastSkip = "Not roster dest"
            return
        end
        if (not playerName or playerName == "") and Goals and Goals.GetPlayerName and destGUID == playerGuid then
            playerName = Goals:GetPlayerName()
        end
        if not playerName or playerName == "" then
            debug.lastSkip = "No player name"
            return
        end
        local spellId = nil
        if spellBase and type(args[spellBase + 1]) == "string" then
            spellId = tonumber(args[spellBase]) or nil
            spellName = args[spellBase + 1]
        else
            local id, name = parseSpellPayload(args, 0, 0)
            spellId = id
            spellName = name
        end
        local reviveAmount = nil
        local revivePercent = nil
        local unit = findUnitByGuid(destGUID)
        if unit and UnitHealth and UnitHealthMax then
            local health = UnitHealth(unit) or 0
            local maxHealth = UnitHealthMax(unit) or 0
            reviveAmount = health
            if maxHealth > 0 then
                revivePercent = math.floor((health / maxHealth) * 100 + 0.5)
            end
        end
        self:AddEntry({
            ts = timestamp,
            player = playerName ~= "" and playerName or "Unknown",
            spell = spellName or "Unknown",
            spellId = spellId,
            source = sourceName or "Unknown",
            kind = "RES",
            amount = reviveAmount,
            revivePercent = revivePercent,
            sourceFlags = sourceFlags,
            sourceKind = sourceKind,
        })
        debug.lastAdded = true
        return
    end
end
