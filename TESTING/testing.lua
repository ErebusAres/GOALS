-- local f = CreateFrame("Frame")
-- f:RegisterEvent("PLAYER_ENTER_COMBAT")
-- f:RegisterEvent("PLAYER_LEAVE_COMBAT")
-- f:SetScript("OnEvent", function(self, event, ...)
--   if event == "PLAYER_ENTER_COMBAT" then
--     print("You're in combat!")
--   elseif event == "PLAYER_LEAVE_COMBAT" then
--     print("You're no longer in combat!")
--   end
-- end)

local function OnEvent(self, event, ...)
    local _, subevent, _, sourceName, _, _, destName, _, prefixParam1, prefixParam2, _, suffixParam1, suffixParam2 = ...
    if subevent == "UNIT_DIED" then
       print("["..sourceName.."] killed ["..destName.."]")
    end
 end
  
 local f = CreateFrame("Frame")
 f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 f:SetScript("OnEvent", OnEvent)


 --

 local function OnEvent(self, event, ...)
    local _, subevent, _, sourceName, _, _, destName, _ = ...
  
    if (subevent == "UNIT_DIED") then
       print("Killed: ["..destName.."]")
    end
 end
  
 local f = CreateFrame("Frame")
 f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 f:SetScript("OnEvent", OnEvent)