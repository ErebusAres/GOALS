SLASH_FRAMESTK1 = "/fs"
    SlashCmdList.FRAMESTK = function()
        LoadAddOn('Blizzard_DebugTools')
        FrameStackTooltip_Toggle()
    end

local f = CreateFrame("Frame")

f:RegisterEvent("PLAYER_ENTER_COMBAT")
f:RegisterEvent("PLAYER_LEAVE_COMBAT")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTER_COMBAT" then
        print("You're in combat!")
    elseif event == "PLAYER_LEAVE_COMBAT" then
        print("You're no longer in combat!")
    end
end)