-- Goals: dev.lua
-- Developer override tools and simulation helpers.
-- Usage: if Goals.Dev.enabled then show Dev tab.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.Dev = Goals.Dev or {}
local Dev = Goals.Dev

function Dev:Init()
    if Goals and Goals.db and Goals.db.settings then
        self.enabled = Goals.db.settings.devMode == true
    else
        self.enabled = false
    end
end

function Dev:SetEnabled(enabled, silent)
    if not Goals or not Goals.db or not Goals.db.settings then
        return
    end
    self.enabled = enabled and true or false
    Goals.db.settings.devMode = self.enabled
    Goals:NotifyDataChanged()
    if Goals.UI then
        Goals.UI:Refresh()
    end
    if self.enabled and Goals.UI and Goals.UI.frame and not Goals.UI.devTab then
        Goals:Print("Dev tab will appear after /reload or UI restart.")
        Goals:Print("Reminder: type /reload to show the Dev tab now.")
    end
    if not silent then
        Goals:Print(self.enabled and "Dev mode enabled." or "Dev mode disabled.")
    end
end

function Dev:SimulateBossKill()
    if not self.enabled then
        return
    end
    Goals:AwardBossKill("Dev Boss", Goals:GetGroupMembers(), true)
    Goals.History:AddEntry("DEV", "Dev: simulated boss kill", {})
    Goals:NotifyDataChanged()
end

function Dev:SimulateWipe()
    if not self.enabled then
        return
    end
    Goals.History:AddWipe("Dev Boss")
    Goals.History:AddEntry("DEV", "Dev: simulated wipe", {})
    Goals:NotifyDataChanged()
end

function Dev:SimulateLoot()
    if not self.enabled then
        return
    end
    local exampleItem = "|cffa335ee|Hitem:40395::::::::80:::::::::|h[Torch of Holy Fire]|h|r"
    local itemName = GetItemInfo(exampleItem)
    Goals.state.lootFound = Goals.state.lootFound or {}
    table.insert(Goals.state.lootFound, 1, {
        slot = 0,
        link = exampleItem,
        ts = time(),
        assignedTo = nil,
    })
    Goals:RecordLootFound(exampleItem)
    if not itemName then
        Goals:Delay(0.5, function()
            Goals:ProcessPendingLoot()
        end)
    end
    Goals.History:AddEntry("DEV", "Dev: simulated loot", {})
    Goals:NotifyDataChanged()
end

function Dev:ToggleDebug()
    if not self.enabled then
        return
    end
    Goals.db.settings.debug = not Goals.db.settings.debug
    Goals:NotifyDataChanged()
end

local function ensureCombatTrackerEnabled(requireHealing)
    if not (Goals and Goals.DamageTracker and Goals.DamageTracker.AddEntry) then
        if Goals and Goals.Print then
            Goals:Print("Combat tracker module missing. Update the addon and /reload.")
        end
        return false
    end
    local enabled = Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatLogTracking
    if not enabled and Goals and Goals.DamageTracker and Goals.DamageTracker.IsEnabled then
        enabled = Goals.DamageTracker:IsEnabled()
    end
    if enabled and Goals and Goals.DamageTracker and Goals.DamageTracker.RefreshRoster then
        Goals.DamageTracker:RefreshRoster()
    end
    if not enabled then
        if Goals and Goals.Print then
            Goals:Print("Enable Combat Log Tracking first.")
        end
        return false
    end
    if requireHealing and not (Goals.DamageTracker.IsHealingEnabled and Goals.DamageTracker:IsHealingEnabled()) then
        if Goals and Goals.Print then
            Goals:Print("Enable Healing Tracking first.")
        end
        return false
    end
    return true
end

function Dev:SimulateSelfDamage(amount, spellName, sourceName)
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(false) then
        return
    end
    local value = tonumber(amount) or 1000
    if value < 1 then
        value = 1
    end
    local player = Goals:GetPlayerName() or "Player"
    Goals.DamageTracker:AddEntry({
        ts = time(),
        player = player,
        amount = value,
        spell = spellName or "Dev Attack",
        source = sourceName or "Dev Dummy",
        kind = "DAMAGE",
    })
end

function Dev:SimulateSelfHeal(amount, spellName, sourceName)
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(true) then
        return
    end
    local value = tonumber(amount) or 1000
    if value < 1 then
        value = 1
    end
    local player = Goals:GetPlayerName() or "Player"
    Goals.DamageTracker:AddEntry({
        ts = time(),
        player = player,
        amount = value,
        spell = spellName or "Dev Heal",
        source = sourceName or "Dev Healer",
        kind = "HEAL",
    })
end

function Dev:SimulateSelfDeath()
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(false) then
        return
    end
    local player = Goals:GetPlayerName() or "Player"
    Goals.DamageTracker:AddEntry({
        ts = time(),
        player = player,
        kind = "DEATH",
    })
end

function Dev:SimulateSelfResurrect(spellName, sourceName)
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(false) then
        return
    end
    local player = Goals:GetPlayerName() or "Player"
    Goals.DamageTracker:AddEntry({
        ts = time(),
        player = player,
        spell = spellName or "Dev Resurrection",
        source = sourceName or "Dev Healer",
        kind = "RES",
    })
end

function Dev:SimulateEncounterStart(encounterName)
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(false) then
        return
    end
    local name = encounterName or "Dev Encounter"
    if Goals and Goals.DamageTracker and Goals.DamageTracker.AddBreakpoint then
        Goals.DamageTracker:AddBreakpoint(name, "START")
    end
end

function Dev:SimulateEncounterEnd(success, encounterName)
    if not self.enabled then
        return
    end
    if not ensureCombatTrackerEnabled(false) then
        return
    end
    local name = encounterName or "Dev Encounter"
    local status = success and "SUCCESS" or "FAIL"
    if Goals and Goals.DamageTracker and Goals.DamageTracker.AddBreakpoint then
        Goals.DamageTracker:AddBreakpoint(name, status)
    end
end
