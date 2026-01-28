-- Goals: damageTracker.lua
-- Combat log damage tracking (optional).

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.DamageTracker = Goals.DamageTracker or {}
local DamageTracker = Goals.DamageTracker

local MAX_LOG_ENTRIES = 300
local DAMAGE_EVENTS = {
    SPELL_DAMAGE = true,
    RANGE_DAMAGE = true,
    SWING_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
}
local PERIODIC_DAMAGE_EVENTS = {
    SPELL_PERIODIC_DAMAGE = true,
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
local bit_band = bit and bit.band or nil

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
    return (Goals.L and Goals.L.DAMAGE_TRACKER_ALL) or "All Members"
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
    else
        Goals.state.damageLog = Goals.state.damageLog or {}
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
    self.startTs = self.startTs or time()
    self:RefreshRoster()
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
    if Goals.db then
        Goals.db.combatLog = Goals.state.damageLog
    end
    self.startTs = time()
    self.activeCombines = {}
    self.castStarts = {}
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
    if not entry or entry.kind ~= "DAMAGE" then
        return false
    end
    if not entry.periodic then
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
        combine.lastTs = now
        target.combineStartTs = combine.startTs or target.combineStartTs or target.ts or now
        target.combineLastTs = combine.lastTs
        target.ts = now
        local duration = math.floor((combine.lastTs - (target.combineStartTs or combine.lastTs)) + 0.5)
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
    self.activeCombines[key] = {
        entry = entry,
        startTs = startTs,
        lastTs = now,
        castStart = castStart,
    }
    return false
end

function DamageTracker:GetRosterNames()
    if not self.rosterNames or #self.rosterNames == 0 then
        self:RefreshRoster()
    end
    return self.rosterNames or {}
end

function DamageTracker:GetFilteredEntries(filter)
    local log = Goals.state.damageLog or {}
    local allLabel = getAllLabel()
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local showHealing = settings and settings.combatLogShowHealing
    local showDamageDealt = settings and settings.combatLogShowDamageDealt
    local showDamageReceived = settings and settings.combatLogShowDamageReceived
    if showHealing == nil and settings then
        if settings.combatLogHealing ~= nil then
            showHealing = settings.combatLogHealing and true or false
        else
            showHealing = true
        end
        settings.combatLogShowHealing = showHealing
    end
    if showDamageDealt == nil and settings then
        if settings.combatLogTrackOutgoing ~= nil then
            showDamageDealt = settings.combatLogTrackOutgoing and true or false
        else
            showDamageDealt = true
        end
        settings.combatLogShowDamageDealt = showDamageDealt
    end
    if showDamageReceived == nil and settings then
        showDamageReceived = true
        settings.combatLogShowDamageReceived = showDamageReceived
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
    local useBigFilter = threshold > 0
    local stats = nil
    if useBigFilter then
        stats = self:BuildEncounterStats(log)
    end
    local isAllView = not filter or filter == "" or filter == allLabel
    local rosterMap = self.rosterNameMap or {}
    local function isRosterName(name)
        if not name or name == "" then
            return false
        end
        return rosterMap[normalizeName(name)] and true or false
    end
    local function isSelfHeal(entry)
        if not entry or entry.kind ~= "HEAL" then
            return false
        end
        local source = entry.source or ""
        local target = entry.player or ""
        if source == "" or target == "" then
            return false
        end
        return normalizeName(source) == normalizeName(target)
    end
    local function shouldIncludeAll(entry)
        if not entry then
            return false
        end
        if entry.kind == "HEAL" or entry.kind == "HEAL_OUT" or entry.kind == "RES" then
            if not showHealing then
                return false
            end
        elseif entry.kind == "DAMAGE_OUT" then
            if not showDamageDealt then
                return false
            end
        elseif entry.kind == "DAMAGE" or entry.kind == "DEATH" then
            if not showDamageReceived then
                return false
            end
        end
        if entry.kind == "HEAL" then
            if isRosterName(entry.source) and not isSelfHeal(entry) then
                return false
            end
        end
        return true
    end
    local function filterAllList(entries)
        local list = {}
        for _, entry in ipairs(entries or {}) do
            if shouldIncludeAll(entry) then
                table.insert(list, entry)
            end
        end
        return list
    end

    if isAllView then
        if not useBigFilter then
            local list = filterAllList(log)
            if not self:IsCombineAllEnabled() then
                return list
            end
            return self:BuildCombinedList(list)
        end
        local list = {}
        for _, entry in ipairs(log) do
            if shouldIncludeAll(entry) then
                if entry.kind == "BREAK" or entry.kind == "DEATH" or entry.kind == "RES" then
                    table.insert(list, entry)
                elseif entry.kind == "HEAL" or entry.kind == "HEAL_OUT" then
                    if self:IsBigEntry(entry, stats, "HEAL", threshold) then
                        table.insert(list, entry)
                    end
                else
                    if self:IsBigEntry(entry, stats, "DAMAGE", threshold) then
                        table.insert(list, entry)
                    end
                end
            end
        end
        if not self:IsCombineAllEnabled() then
            return list
        end
        return self:BuildCombinedList(list)
    end
    local function entryMatchesFilter(entry, filterName)
        if not entry or not filterName or filterName == "" then
            return false
        end
        local targetName = nil
        local sourceName = nil
        if entry.kind == "DAMAGE" then
            sourceName = entry.source
            targetName = entry.player
        elseif entry.kind == "DAMAGE_OUT" then
            sourceName = entry.player
            targetName = entry.source
        elseif entry.kind == "HEAL" then
            sourceName = entry.source
            targetName = entry.player
        elseif entry.kind == "HEAL_OUT" then
            sourceName = entry.player
            targetName = entry.source
        elseif entry.kind == "RES" then
            sourceName = entry.source
            targetName = entry.player
        elseif entry.kind == "DEATH" then
            targetName = entry.player
        else
            targetName = entry.player
        end
        local normalizedFilter = normalizeName(filterName)
        if sourceName and normalizeName(sourceName) == normalizedFilter then
            return true
        end
        if targetName and normalizeName(targetName) == normalizedFilter then
            return true
        end
        return false
    end

    local list = {}
    for _, entry in ipairs(log) do
        if entry.kind == "BREAK" then
            table.insert(list, entry)
        elseif entryMatchesFilter(entry, filter) then
            if not useBigFilter then
                if entry.kind == "HEAL" or entry.kind == "HEAL_OUT" or entry.kind == "RES" then
                    if showHealing then
                        table.insert(list, entry)
                    end
                elseif entry.kind == "DAMAGE_OUT" then
                    if showDamageDealt then
                        table.insert(list, entry)
                    end
                elseif entry.kind == "DAMAGE" or entry.kind == "DEATH" then
                    if showDamageReceived then
                        table.insert(list, entry)
                    end
                else
                    table.insert(list, entry)
                end
            elseif entry.kind == "HEAL" or entry.kind == "HEAL_OUT" then
                if showHealing and self:IsBigEntry(entry, stats, "HEAL", threshold) then
                    table.insert(list, entry)
                end
            elseif entry.kind == "DEATH" or entry.kind == "RES" then
                if entry.kind == "RES" then
                    if showHealing then
                        table.insert(list, entry)
                    end
                else
                    if showDamageReceived then
                        table.insert(list, entry)
                    end
                end
            else
                if entry.kind == "DAMAGE_OUT" then
                    if showDamageDealt and self:IsBigEntry(entry, stats, "DAMAGE", threshold) then
                        table.insert(list, entry)
                    end
                else
                    if showDamageReceived and self:IsBigEntry(entry, stats, "DAMAGE", threshold) then
                        table.insert(list, entry)
                    end
                end
            end
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
        if not entry or entry.kind == "BREAK" or entry.kind == "DEATH" or entry.kind == "RES" then
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
    for i = #log, 1, -1 do
        local entry = log[i]
        if entry.kind == "BREAK" then
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
                elseif (entry.kind == "HEAL" or entry.kind == "HEAL_OUT") and amount > 0 then
                    stats[activeId].healTotal = stats[activeId].healTotal + amount
                    stats[activeId].healCount = stats[activeId].healCount + 1
                    if amount > (stats[activeId].maxHeal or 0) then
                        stats[activeId].maxHeal = amount
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
        local spellId = tonumber(arg12) or nil
        local spellName = arg13
        if spellId or spellName then
            self.castStarts = self.castStarts or {}
            local key = string.format("%s|%s", tostring(sourceGUID or sourceName or "unknown"), tostring(spellId or spellName))
            self.castStarts[key] = timestamp or time()
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
    if not isRosterDest and not isRosterSource then
        debug.lastSkip = "Not roster dest"
        return
    end
    if not subevent then
        debug.lastSkip = "No subevent"
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
        local castStart = nil
        if PERIODIC_DAMAGE_EVENTS[subevent] then
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
                periodic = PERIODIC_DAMAGE_EVENTS[subevent] and true or false,
                castStart = castStart,
                sourceFlags = sourceFlags,
                sourceKind = sourceKind,
            })
        elseif isRosterSource then
            local srcName = (sourceGUID and self.rosterGuids[sourceGUID]) or (isRosterSource and normalizedSource) or normalizeName(sourceName)
            if (not srcName or srcName == "") and Goals and Goals.GetPlayerName and sourceGUID == playerGuid then
                srcName = Goals:GetPlayerName()
            end
            if not srcName or srcName == "" then
                debug.lastSkip = "No player name"
                return
            end
            local targetName = destName or "Unknown"
            local targetKind = classifySource(targetName, destFlags)
            self:AddEntry({
                ts = timestamp,
                player = srcName,
                amount = amount,
                spell = spellName or "Unknown",
                spellId = spellId,
                source = targetName,
                kind = "DAMAGE_OUT",
                periodic = PERIODIC_DAMAGE_EVENTS[subevent] and true or false,
                castStart = castStart,
                sourceFlags = destFlags,
                sourceKind = targetKind,
            })
        end
        debug.lastAdded = true
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
        local added = false
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
                kind = "HEAL",
                periodic = PERIODIC_HEAL_EVENTS[subevent] and true or false,
                sourceFlags = sourceFlags,
                sourceKind = sourceKind,
                overheal = overheal,
            })
            added = true
        end
        if isRosterSource and (sourceGUID ~= destGUID) then
            local srcName = (sourceGUID and self.rosterGuids[sourceGUID]) or (isRosterSource and normalizedSource) or normalizeName(sourceName)
            if (not srcName or srcName == "") and Goals and Goals.GetPlayerName and sourceGUID == playerGuid then
                srcName = Goals:GetPlayerName()
            end
            if not srcName or srcName == "" then
                debug.lastSkip = "No player name"
                return
            end
            local targetName = destName or "Unknown"
            local targetKind = classifySource(targetName, destFlags)
            self:AddEntry({
                ts = timestamp,
                player = srcName,
                amount = amount,
                spell = spellName or "Unknown",
                spellId = spellId,
                source = targetName,
                kind = "HEAL_OUT",
                periodic = PERIODIC_HEAL_EVENTS[subevent] and true or false,
                sourceFlags = destFlags,
                sourceKind = targetKind,
                overheal = overheal,
            })
            added = true
        end
        if not added then
            debug.lastSkip = "Not roster dest"
            return
        end
        debug.lastAdded = true
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
