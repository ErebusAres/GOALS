-- Create a table to store boss kill data
local bossKills = {}

-- Function to handle boss kill event
local function OnBossKill(self, event, encounterID, encounterName, difficultyID, groupSize, success)
    -- Check if the boss was killed successfully
    if success then
        -- If this boss has not been killed before, initialize its count
        if not bossKills[encounterName] then
            bossKills[encounterName] = { count = 0, players = {} }
        end
        
        -- Increment the boss kill count
        bossKills[encounterName].count = bossKills[encounterName].count + 1
        
        -- Get the list of players in the raid or group
        local numGroupMembers = GetNumGroupMembers()
        bossKills[encounterName].players = {} -- Reset the player list
        
        for i = 1, numGroupMembers do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(bossKills[encounterName].players, name)
            end
        end
        
        -- Update the UI with the new data
        MyBossTracker_UpdateUI()

        -- Print a message to the chat to confirm the boss kill has been recorded
        print("Boss killed: " .. encounterName .. ". Kill count: " .. bossKills[encounterName].count)
        print("Participants: " .. table.concat(bossKills[encounterName].players, ", "))
    end
end

-- Register the event handler to listen for the ENCOUNTER_END event
local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", OnBossKill)

-- Function to update the UI
function MyBossTracker_UpdateUI()
    -- Clear the existing list
    MyBossTrackerFrameScrollChildText:SetText("")

    -- Iterate over the bossKills table and display each boss and its count
    for bossName, data in pairs(bossKills) do
        local players = table.concat(data.players, ", ")
        local info = string.format("%s: %d kills - Participants: %s\n", bossName, data.count, players)
        MyBossTrackerFrameScrollChildText:SetText(MyBossTrackerFrameScrollChildText:GetText() .. info)
    end
end