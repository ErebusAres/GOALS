-- Quick Reloading and Debugging Commands
SLASH_RELOADUI1 = "/rl" -- For quicker reloading of ui
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = "/fs" -- for quicker access to frame stack
SlashCmdList.FRAMESTK = function ()
    LoadAddon('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end
--[[Above is the code to reload the UI and access the frame stack quickly.]]
--[[Below is the code to handle boss kill event and combat log event.]]

-- Define a table with the creature names
local bossCreatures = {
   ["Garryowen Boar"] = true,
   ["CreatureName2"] = true,
   ["CreatureName3"] = true,
   -- Add more creature names as needed
}

local function OnEvent(self, event, ...)
   local _, subevent, _, _, _, _, destName, _ = ...
   if (subevent == "UNIT_DIED") then
       if bossCreatures[destName] then
           print("Killed: ["..destName.."], a boss unit.")
       else
           print("Killed: ["..destName.."], not on the boss list.")
       end
   end
end

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", OnEvent)