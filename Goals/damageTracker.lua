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
local HEAL_EVENTS = {
    SPELL_HEAL = true,
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
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogTracking and true or false
end

function DamageTracker:IsHealingEnabled()
    return Goals.db and Goals.db.settings and Goals.db.settings.combatLogHealing and true or false
end

function DamageTracker:Init()
    Goals.state = Goals.state or {}
    Goals.state.damageLog = Goals.state.damageLog or {}
    self.rosterGuids = self.rosterGuids or {}
    self.rosterNames = self.rosterNames or {}
    if self:IsEnabled() then
        self:ClearLog()
        self:RefreshRoster()
    end
end

function DamageTracker:SetEnabled(enabled)
    if not (Goals.db and Goals.db.settings) then
        return
    end
    Goals.db.settings.combatLogTracking = enabled and true or false
    if enabled then
        self:ClearLog()
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
    self.startTs = time()
end

function DamageTracker:AddEntry(entry)
    if type(entry) ~= "table" then
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

function DamageTracker:GetRosterNames()
    if not self.rosterNames or #self.rosterNames == 0 then
        self:RefreshRoster()
    end
    return self.rosterNames or {}
end

function DamageTracker:GetFilteredEntries(filter)
    local log = Goals.state.damageLog or {}
    local allLabel = getAllLabel()
    if not filter or filter == "" or filter == allLabel then
        return log
    end
    local list = {}
    for _, entry in ipairs(log) do
        if entry.player == filter then
            table.insert(list, entry)
        end
    end
    return list
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
        self:AddEntry({
            ts = timestamp,
            player = playerName ~= "" and playerName or "Unknown",
            amount = amount,
            spell = spellName or "Unknown",
            spellId = spellId,
            source = source,
            kind = "DAMAGE",
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
