-- Reference to the SavedVariables table
GoalsDB = GoalsDB or {}

-- Function to handle boss kill event
local function OnBossKill(self, event, encounterID, encounterName, difficultyID, groupSize, success)
    -- Check if the boss was killed successfully
    if success then
        -- If this boss has not been killed before, initialize its count
        if not GoalsDB[encounterName] then
            GoalsDB[encounterName] = { count = 0, players = {} }
        end
        
        -- Increment the boss kill count
        GoalsDB[encounterName].count = GoalsDB[encounterName].count + 1
        
        -- Get the list of players in the raid or group
        local numGroupMembers = GetNumGroupMembers()
        GoalsDB[encounterName].players = {} -- Reset the player list
        
        for i = 1, numGroupMembers do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(GoalsDB[encounterName].players, name)
            end
        end
        
        -- Update the UI with the new data
        Goals_UpdateUI()

        -- Print a message to the chat to confirm the boss kill has been recorded
        print("Boss killed: " .. encounterName .. ". Kill count: " .. GoalsDB[encounterName].count)
        print("Participants: " .. table.concat(GoalsDB[encounterName].players, ", "))
    end
end

-- Register the event handler to listen for the ENCOUNTER_END event
local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", OnBossKill)

-- Function to update the UI
function Goals_UpdateUI()
    -- Clear the existing list
    GoalsFrameScrollChildText:SetText("")

    -- Iterate over the GoalsDB table and display each boss and its count
    for bossName, data in pairs(GoalsDB) do
        local players = table.concat(data.players, ", ")
        local info = string.format("%s: %d kills - Participants: %s\n", bossName, data.count, players)
        GoalsFrameScrollChildText:SetText(GoalsFrameScrollChildText:GetText() .. info)
    end
end

-- Initialize the UI when the addon is loaded
local function OnAddonLoaded(self, event, name)
    if name == "Goals" then
        Goals_UpdateUI()
    end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "ENCOUNTER_END" then
        OnBossKill(self, event, ...)
    end
end)