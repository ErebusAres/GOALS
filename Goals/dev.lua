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
    Goals:AwardBossKill("Dev Boss", { { name = Goals:GetPlayerName(), class = select(2, UnitClass("player")) } }, true)
    Goals.History:AddEntry("DEV", "Dev: simulated boss kill", {})
    Goals:NotifyDataChanged()
end

function Dev:SimulateWipe()
    if not self.enabled then
        return
    end
    Goals.History:AddWipe("Dev Boss")
    Goals:NotifyDataChanged()
end

function Dev:SimulateLoot()
    if not self.enabled then
        return
    end
    local exampleItem = "|cffa335ee|Hitem:40395::::::::80:::::::::|h[Torch of Holy Fire]|h|r"
    Goals:HandleLoot(Goals:GetPlayerName(), exampleItem, true)
end

function Dev:ToggleDebug()
    if not self.enabled then
        return
    end
    Goals.db.settings.debug = not Goals.db.settings.debug
    Goals:NotifyDataChanged()
end
