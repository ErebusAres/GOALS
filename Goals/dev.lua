-- Goals: dev.lua
-- Developer override tools and simulation helpers.
-- Usage: if Goals.Dev.enabled then show Dev tab.

local addonName = ...
local Goals = _G.Goals

Goals.Dev = Goals.Dev or {}
local Dev = Goals.Dev

Dev.overrideNames = {
    erebusares = true,
    locky = true,
    shamy = true,
}

function Dev:Init()
    local name = string.lower(UnitName("player") or "")
    self.enabled = self.overrideNames[name] or false
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
    Goals:AddFoundLoot(Goals:GetPlayerName(), exampleItem)
    Goals:HandleLootAssignment(Goals:GetPlayerName(), exampleItem, true, true)
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
