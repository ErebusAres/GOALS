SLASH_FRAMESTK1 = "/fs"
    SlashCmdList.FRAMESTK = function()
        LoadAddOn('Blizzard_DebugTools')
        FrameStackTooltip_Toggle()
    end
-- Define a table with creature names
local creatureNames = {
    "Creature1",
    "Creature2",
    "Creature3",
    -- Add more creature names as needed
}

-- Function to check if a name exists in the table
local function isCreatureInList(name)
    for _, creatureName in ipairs(creatureNames) do
        if destName == creatureName then
            return true
        end
    end
    return false
end

-- Function to handle the COMBAT_LOG_EVENT_UNFILTERED event
local function OnEvent(self, event, ...)
    local _, subevent, _, sourceName, _, _, destName, _, _, _, _, _, _ = ...

    if subevent == "UNIT_DIED" then
        if isCreatureInList(destName) then -- Call the function to check if the name exists in the table
            print("["..sourceName.."] killed ["..destName.."]")
        end
    end
end

-- Create a frame and register the event
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", OnEvent)