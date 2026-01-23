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
    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, arg12, arg13, _, arg15 =
        getCombatLogArgs(...)
    if not (subevent and DAMAGE_EVENTS[subevent]) then
        return
    end
    if not destGUID then
        return
    end
    if not (self.rosterGuids and self.rosterGuids[destGUID]) then
        return
    end

    local amount
    local spellName
    if subevent == "SWING_DAMAGE" then
        amount = arg12
        spellName = "Melee"
    else
        spellName = arg13
        amount = arg15
    end
    amount = tonumber(amount or 0) or 0
    if amount <= 0 then
        return
    end

    local playerName = self.rosterGuids[destGUID] or normalizeName(destName)
    local source = sourceName or "Unknown"
    self:AddEntry({
        ts = timestamp,
        player = playerName ~= "" and playerName or "Unknown",
        amount = amount,
        spell = spellName or "Unknown",
        source = source,
    })
end

