local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.CombatProvider = Goals.CombatProvider or {}
local CombatProvider = Goals.CombatProvider

local function safeCopy(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

local function defaultSettings(settings)
    settings.combatWhtmScope = settings.combatWhtmScope or "player"
    settings.combatWhtmDisplayStyle = settings.combatWhtmDisplayStyle or "table"
    settings.combatWhtmTimestampFormat = settings.combatWhtmTimestampFormat or "24h"
    if settings.combatWhtmMaxRows == nil then
        settings.combatWhtmMaxRows = 600
    end
    if settings.combatWhtmRetainFullHistory == nil then
        settings.combatWhtmRetainFullHistory = false
    end
    if settings.combatWhtmHideMinimapIcon == nil then
        settings.combatWhtmHideMinimapIcon = false
    end
    if settings.combatWhtmBossOnly == nil then
        settings.combatWhtmBossOnly = false
    end
    if settings.combatWhtmPaused == nil then
        settings.combatWhtmPaused = false
    end
    if settings.combatWhtmDirections == nil then
        settings.combatWhtmDirections = {
            incoming = true,
            outgoing = false,
            internal = false,
        }
    end
    if settings.combatWhtmGroups == nil then
        settings.combatWhtmGroups = {
            damage = true,
            heal = true,
            aura = true,
            miss = true,
            death = true,
            control = true,
            resource = true,
        }
    end
    if settings.combatWhtmAuraStates == nil then
        settings.combatWhtmAuraStates = {
            gained = true,
            lost = true,
            other = true,
        }
    end
end

function CombatProvider:Init()
    Goals.DamageTracker = self -- keep GUI call-sites stable while using new provider.
    self.listenerKey = "GoalsCombatProvider"
    self.events = self.events or {}
    self.rosterNameMap = self.rosterNameMap or {}
    self.api = _G.WHTM_API
    self.available = self.api and self.api.IsAvailable and self.api.IsAvailable() or false

    if Goals and Goals.db and Goals.db.settings then
        defaultSettings(Goals.db.settings)
    end
    self:SyncSettingsToWHTM()
    self:RegisterListener()
    self:RefreshEvents()
end

function CombatProvider:IsEnabled()
    local s = self:GetSettings()
    return not s.combatWhtmPaused
end

function CombatProvider:RefreshRoster()
    self.rosterNameMap = self.rosterNameMap or {}
end

function CombatProvider:AddBreakpoint(name, status)
    self.events = self.events or {}
    table.insert(self.events, 1, {
        timestamp = time(),
        eventGroup = "control",
        sourceName = name or "Encounter",
        destName = status or "BREAK",
        spellName = "Breakpoint",
        eventText = status or "BREAK",
    })
end

function CombatProvider:RegisterListener()
    if not (self.api and self.api.RegisterListener) then
        return
    end
    self.api.RegisterListener(self.listenerKey, function(eventType)
        if eventType == "events_updated"
            or eventType == "events_cleared"
            or eventType == "settings_updated"
            or eventType == "mode_changed"
            or eventType == "capture_state_changed" then
            self:RefreshEvents()
            if Goals and Goals.UI and Goals.UI.UpdateDamageTrackerList then
                Goals.UI:UpdateDamageTrackerList()
            end
        end
    end)
end

function CombatProvider:IsAvailable()
    self.api = _G.WHTM_API
    self.available = self.api and self.api.IsAvailable and self.api.IsAvailable() or false
    return self.available
end

function CombatProvider:RefreshEvents()
    if not self:IsAvailable() then
        self.events = {}
        return
    end
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local cap = nil
    if not (settings and settings.combatWhtmRetainFullHistory) then
        cap = tonumber(settings and settings.combatWhtmMaxRows) or 600
    end
    self.events = self.api.GetEvents(cap, { includeRaw = false }) or {}
end

function CombatProvider:GetEvents()
    return self.events or {}
end

function CombatProvider:GetSettings()
    local settings = Goals and Goals.db and Goals.db.settings or {}
    defaultSettings(settings)
    return settings
end

function CombatProvider:SyncSettingsToWHTM()
    if not self:IsAvailable() then
        return false
    end
    local s = self:GetSettings()
    local filters = {}
    filters.incoming = s.combatWhtmDirections.incoming and true or false
    filters.outgoing = s.combatWhtmDirections.outgoing and true or false
    filters.internal = s.combatWhtmDirections.internal and true or false
    filters.boss_only = s.combatWhtmBossOnly and true or false
    filters.damage = s.combatWhtmGroups.damage and true or false
    filters.heal = s.combatWhtmGroups.heal and true or false
    filters.aura = s.combatWhtmGroups.aura and true or false
    filters.miss = s.combatWhtmGroups.miss and true or false
    filters.death = s.combatWhtmGroups.death and true or false
    filters.control = s.combatWhtmGroups.control and true or false
    filters.resource = s.combatWhtmGroups.resource and true or false
    filters.aura_gained = s.combatWhtmAuraStates.gained and true or false
    filters.aura_lost = s.combatWhtmAuraStates.lost and true or false
    filters.aura_other = s.combatWhtmAuraStates.other and true or false

    self.api.UpdateSettings({
        mode = s.combatWhtmDisplayStyle == "chat" and "chat" or "table",
        captureScope = s.combatWhtmScope,
        timestampFormat = s.combatWhtmTimestampFormat,
        maxRows = s.combatWhtmRetainFullHistory and nil or s.combatWhtmMaxRows,
        retainFullHistory = s.combatWhtmRetainFullHistory and true or false,
        minimapHide = s.combatWhtmHideMinimapIcon and true or false,
        paused = s.combatWhtmPaused,
        filters = filters,
    })
    return true
end

function CombatProvider:SetPaused(paused)
    local s = self:GetSettings()
    s.combatWhtmPaused = paused and true or false
    self:SyncSettingsToWHTM()
end

function CombatProvider:SetEnabled(enabled)
    self:SetPaused(not enabled)
end

function CombatProvider:ClearLog()
    if self:IsAvailable() and self.api.ClearEvents then
        self.api.ClearEvents()
    end
end

function CombatProvider:RebuildPeriodicCombines()
end

function CombatProvider:AddEntry(entry)
    local e = safeCopy(entry or {})
    e.timestamp = e.timestamp or time()
    e.sourceName = e.sourceName or e.source or "Unknown"
    e.destName = e.destName or e.player or "Unknown"
    e.spellName = e.spellName or e.spell or "Unknown"
    e.eventGroup = e.eventGroup or "control"
    e.direction = e.direction or "incoming"
    self.events = self.events or {}
    table.insert(self.events, 1, e)
end

function CombatProvider:GetFilteredEntries()
    local s = self:GetSettings()
    local all = self.events or {}
    local out = {}
    for i = 1, #all do
        local event = all[i]
        local directionEnabled = s.combatWhtmDirections[event.direction or "incoming"]
        local groupEnabled = s.combatWhtmGroups[event.eventGroup or "control"]
        local auraOk = true
        local bossOk = true
        if event.eventGroup == "aura" then
            local auraState = event.auraState or "other"
            auraOk = s.combatWhtmAuraStates[auraState] and true or false
        end
        if s.combatWhtmBossOnly then
            bossOk = (event.sourceTier == "boss" or event.destTier == "boss")
        end
        if directionEnabled and groupEnabled and auraOk and bossOk then
            out[#out + 1] = event
        end
    end
    return out
end

function CombatProvider:BuildShareLine(entry)
    if self:IsAvailable() and self.api.BuildShareLine then
        local text = self.api.BuildShareLine(entry)
        if text and text ~= "" then
            return text
        end
    end
    local src = entry and entry.sourceName or "?"
    local dst = entry and entry.destName or "?"
    local spell = entry and (entry.spellName or entry.subevent) or "event"
    local amount = entry and (entry.effectiveAmount or entry.amount) or "-"
    return ("%s -> %s | %s | %s"):format(src, dst, spell, tostring(amount))
end
