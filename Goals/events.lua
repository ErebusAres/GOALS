-- Goals: events.lua
-- Event handlers for boss encounters, loot, and sync.
-- Boss tracking recommendation:
--   Prefer encounter events and boss combat log signals (UNIT_DIED/BOSS_KILL) plus group combat state.
--   Do NOT use badge tracking; badges can drop without a boss kill.

local addonName = ...
local Goals = _G.Goals

Goals.Events = Goals.Events or {}
local Events = Goals.Events

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
    self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:RegisterEvent("RAID_ROSTER_UPDATE")
    self.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self.frame:RegisterEvent("PARTY_LEADER_CHANGED")
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("BOSS_KILL")
    self:BuildBossLookup()
end

function Events:BuildBossLookup()
    self.bossToEncounter = {}
    self.encounterBosses = {}
    if type(_G.bossEncounters) ~= "table" then
        return
    end
    for encounterName, data in pairs(_G.bossEncounters) do
        local set = {}
        self:CollectBossNames(data, set)
        self.encounterBosses[encounterName] = set
        for bossName in pairs(set) do
            self.bossToEncounter[bossName] = encounterName
        end
    end
end

function Events:CollectBossNames(data, set)
    if type(data) == "string" then
        set[data] = true
        return
    end
    if type(data) == "table" then
        for _, entry in pairs(data) do
            self:CollectBossNames(entry, set)
        end
    end
end

function Events:OnEvent(event, ...)
    if event == "CHAT_MSG_LOOT" then
        self:HandleLootMessage(...)
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        Goals:ProcessPendingLoot()
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:HandleCombatLog(...)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:HandleCombatEnd()
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
            self:MarkBossDead(bossName)
        end
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        self:ResetEncounter()
        return
    end
end

function Events:HandleGroupUpdate()
    Goals:EnsureGroupMembers()
    local wasMaster = Goals.sync.isMaster
    Goals:UpdateSyncStatus()
    if Goals:IsSyncMaster() and not wasMaster then
        Goals.Comm:BroadcastFullSync()
    elseif not Goals:IsSyncMaster() then
        Goals.sync.lastRequest = Goals.sync.lastRequest or 0
        if (GetTime() - Goals.sync.lastRequest) > 5 then
            Goals.sync.lastRequest = GetTime()
            Goals.Comm:RequestSync()
        end
    end
    if Goals.UI then
        Goals.UI:Refresh()
    end
end

function Events:HandleLootMessage(message)
    if not Goals:IsSyncMaster() and not (Goals.Dev and Goals.Dev.enabled) then
        return
    end
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return
    end
    local playerName = message:match("^(.+) receives loot")
    if playerName == "You" or (not playerName and message:find("^You receive loot")) then
        playerName = Goals:GetPlayerName()
    end
    if not playerName then
        return
    end
    Goals:HandleLoot(Goals:NormalizeName(playerName), itemLink)
end

function Events:HandleCombatLog(...)
    local eventType = select(2, ...)
    local sourceName = select(5, ...)
    local destName = select(9, ...)
    if sourceName and self.bossToEncounter[sourceName] then
        self:StartEncounter(self.bossToEncounter[sourceName], sourceName)
    end
    if destName and self.bossToEncounter[destName] then
        self:StartEncounter(self.bossToEncounter[destName], destName)
    end
    if eventType == "UNIT_DIED" and destName and self.bossToEncounter[destName] then
        self:MarkBossDead(destName)
    end
end

function Events:StartEncounter(encounterName, bossName)
    if Goals.encounter.active and Goals.encounter.name == encounterName then
        return
    end
    Goals.encounter.active = true
    Goals.encounter.name = encounterName
    Goals.encounter.remaining = {}
    local bosses = self.encounterBosses[encounterName]
    if bosses then
        for name in pairs(bosses) do
            Goals.encounter.remaining[name] = true
        end
    elseif bossName then
        Goals.encounter.remaining[bossName] = true
    end
    Goals.encounter.startTime = time()
    Goals.encounter.lastBoss = bossName
    Goals:Debug("Encounter started: " .. encounterName)
end

function Events:MarkBossDead(bossName)
    local encounterName = self.bossToEncounter[bossName]
    if not encounterName then
        return
    end
    if not Goals.encounter.active then
        self:StartEncounter(encounterName, bossName)
    end
    if Goals.encounter.name ~= encounterName then
        return
    end
    if Goals.encounter.remaining then
        Goals.encounter.remaining[bossName] = nil
        if not next(Goals.encounter.remaining) then
            self:FinishEncounter(true)
        end
    end
end

function Events:HandleCombatEnd()
    if not Goals.encounter.active then
        return
    end
    Goals:Delay(5, function()
        if Goals.encounter.active and not Goals:IsGroupInCombat() then
            self:FinishEncounter(false)
        end
    end)
end

function Events:FinishEncounter(success)
    local encounterName = Goals.encounter.name or "Encounter"
    Goals.encounter.active = false
    Goals.encounter.name = nil
    Goals.encounter.remaining = nil
    Goals.encounter.startTime = 0
    if success then
        if Goals:IsSyncMaster() or (Goals.Dev and Goals.Dev.enabled) then
            Goals:AwardBossKill(encounterName)
        end
        return
    end
    if Goals:IsSyncMaster() or (Goals.Dev and Goals.Dev.enabled) then
        Goals.History:AddWipe(encounterName)
        Goals:NotifyDataChanged()
    end
end

function Events:ResetEncounter()
    Goals.encounter.active = false
    Goals.encounter.name = nil
    Goals.encounter.remaining = nil
    Goals.encounter.startTime = 0
end
