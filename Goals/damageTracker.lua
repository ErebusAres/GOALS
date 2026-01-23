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

function DamageTracker:IsEnabled()
    return true
end

function DamageTracker:IsHealingEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogHealing and true or false
end

function DamageTracker:Init()
    Goals.state = Goals.state or {}
    Goals.state.damageLog = Goals.state.damageLog or {}
    self.rosterGuids = self.rosterGuids or {}
    self.rosterNames = self.rosterNames or {}
    if Goals.db and Goals.db.settings then
        Goals.db.settings.combatLogTracking = true
    end
    self:ClearLog()
    self:RefreshRoster()
end

function DamageTracker:SetEnabled(enabled)
    if not (Goals.db and Goals.db.settings) then
        return
    end
    Goals.db.settings.combatLogTracking = true
    self:ClearLog()
    self:RefreshRoster()
    if Goals.UI and Goals.UI.UpdateDamageTabVisibility then
        Goals.UI:UpdateDamageTabVisibility()
    end
    if Goals.UI and Goals.UI.UpdateDamageTrackerList then
        Goals.UI:UpdateDamageTrackerList()
    end
end

function DamageTracker:ClearLog()
    Goals.state.damageLog = {}
    self.startTs = time()
    self.activeCombines = {}
    self.castStarts = {}
end

function DamageTracker:AddEntry(entry)
    if type(entry) ~= "table" then
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
    local showBig = Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatLogShowBig
    local includeHeal = Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatLogBigIncludeHealing
    local stats = nil
    if showBig then
        stats = self:BuildEncounterStats(log)
    end
    if not filter or filter == "" or filter == allLabel then
        if not showBig then
            return log
        end
        local list = {}
        for _, entry in ipairs(log) do
            if entry.kind == "BREAK" or entry.kind == "DEATH" or entry.kind == "RES" then
                table.insert(list, entry)
            elseif entry.kind == "HEAL" then
                if includeHeal and self:IsBigEntry(entry, stats, "HEAL") then
                    table.insert(list, entry)
                end
            else
                if self:IsBigEntry(entry, stats, "DAMAGE") then
                    table.insert(list, entry)
                end
            end
        end
        return list
    end
    local list = {}
    for _, entry in ipairs(log) do
        if entry.kind == "BREAK" then
            table.insert(list, entry)
        elseif entry.player == filter then
            if not showBig then
                table.insert(list, entry)
            elseif entry.kind == "HEAL" then
                if includeHeal and self:IsBigEntry(entry, stats, "HEAL") then
                    table.insert(list, entry)
                end
            elseif entry.kind == "DEATH" or entry.kind == "RES" then
                table.insert(list, entry)
            else
                if self:IsBigEntry(entry, stats, "DAMAGE") then
                    table.insert(list, entry)
                end
            end
        end
    end
    return list
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
                stats[activeId] = { dmgTotal = 0, dmgCount = 0, healTotal = 0, healCount = 0 }
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
                elseif entry.kind == "HEAL" and amount > 0 then
                    stats[activeId].healTotal = stats[activeId].healTotal + amount
                    stats[activeId].healCount = stats[activeId].healCount + 1
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

function DamageTracker:IsBigEntry(entry, stats, kind)
    if not entry or not stats then
        return false
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
        return amount > (stat.avgHeal or 0)
    end
    return amount > (stat.avgDamage or 0)
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
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, _, _, arg12, arg13, _, arg15 =
        getCombatLogArgs(...)
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
    if not destGUID then
        return
    end
    if not (self.rosterGuids and self.rosterGuids[destGUID]) then
        return
    end
    if not subevent then
        return
    end

    local playerName = self.rosterGuids[destGUID] or normalizeName(destName)
    local sourceKind = classifySource(sourceName, sourceFlags)
    local amount
    local spellName
    if DAMAGE_EVENTS[subevent] then
        local spellId = nil
        if subevent == "SWING_DAMAGE" then
            amount = arg12
            spellName = "Melee"
        else
            spellId = tonumber(arg12) or nil
            spellName = arg13
            amount = arg15
        end
        amount = tonumber(amount or 0) or 0
        if amount <= 0 then
            return
        end
        local source = sourceName or "Unknown"
        local castStart = nil
        if PERIODIC_DAMAGE_EVENTS[subevent] then
            self.castStarts = self.castStarts or {}
            local key = string.format("%s|%s", tostring(sourceGUID or sourceName or "unknown"), tostring(spellId or spellName or ""))
            castStart = self.castStarts[key]
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
        return
    end

    if HEAL_EVENTS[subevent] then
        if not self:IsHealingEnabled() then
            return
        end
        local spellId = tonumber(arg12) or nil
        spellName = arg13
        amount = arg15
        amount = tonumber(amount or 0) or 0
        if amount <= 0 then
            return
        end
        local source = sourceName or "Unknown"
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
        })
        return
    end

    if DEATH_EVENTS[subevent] then
        self:AddEntry({
            ts = timestamp,
            player = playerName ~= "" and playerName or "Unknown",
            kind = "DEATH",
        })
        return
    end

    if subevent == "SPELL_RESURRECT" then
        local spellId = tonumber(arg12) or nil
        spellName = arg13
        self:AddEntry({
            ts = timestamp,
            player = playerName ~= "" and playerName or "Unknown",
            spell = spellName or "Unknown",
            spellId = spellId,
            source = sourceName or "Unknown",
            kind = "RES",
            sourceFlags = sourceFlags,
            sourceKind = sourceKind,
        })
        return
    end
end
