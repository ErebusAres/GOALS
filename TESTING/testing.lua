SLASH_FRAMESTK1 = "/fs"
    SlashCmdList.FRAMESTK = function()
        LoadAddOn('Blizzard_DebugTools')
        FrameStackTooltip_Toggle()
    end

local function OnEvent(self, event, ...)
    local _, subevent, _, sourceName, _, _, destName, _, prefixParam1, prefixParam2, _, suffixParam1, suffixParam2 = ...
  
    if subevent == "UNIT_DIED" then
       print("["..sourceName.."] killed ["..destName.."]")
    end
 end
  
 local f = CreateFrame("Frame")
 f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 f:SetScript("OnEvent", OnEvent)