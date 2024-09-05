SLASH_FRAMESTK1 = "/fs"
    SlashCmdList.FRAMESTK = function()
        LoadAddOn('Blizzard_DebugTools')
        FrameStackTooltip_Toggle()
    end

local function OnEvent(self, event, ...)
    local _, subevent, _, sourceName, _, _, destName, _, prefixParam1, prefixParam2, _, suffixParam1, suffixParam2 = ...
  
    if (subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE") and suffixParam2 > 0 then
       print("["..sourceName.."] killed ["..destName.."] with "..suffixParam1.." "..GetSpellLink(prefixParam1))
    elseif subevent == "SWING_DAMAGE" and prefixParam2 > 0 then
       print("["..sourceName.."] killed ["..destName.."] with "..prefixParam1.." Melee")
    end
 end
  
 local f = CreateFrame("Frame")
 f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 f:SetScript("OnEvent", OnEvent)