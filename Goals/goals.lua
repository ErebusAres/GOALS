-- Quick Reloading and Debugging Commands
SLASH_RELOADUI1 = "/rl" -- For quicker reloading of ui
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = "/fs" -- for quicker access to frame stack
SlashCmdList.FRAMESTK = function ()
    LoadAddon('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end

----------------------------------------------------------------------------------------------------

-- Reference to the SavedVariables table
GoalsDB = GoalsDB or {}
GoalsLootHistory = GoalsLootHistory or {}

local function testPrint(frameName)
    local f = _G[frameName];
    print(frameName .. ": ");
    print(f); 
end


-- Function to handle boss kill event
local function OnBossKill(self, event, encounterID, encounterName, difficultyID, groupSize, success)
    if success then
        print("Getting past success....");
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
                GoalsDB[encounterName].players[name] = GoalsDB[encounterName].players[name] or 0
                GoalsDB[encounterName].players[name] = GoalsDB[encounterName].players[name] + 1
            end
        end
        
        -- Update the UI with the new data
        Goals_UpdateUI()

        -- Print a message to the chat to confirm the boss kill has been recorded
        print("Boss killed: " .. encounterName .. ". Kill count: " .. GoalsDB[encounterName].count)
        print("Participants: " .. table.concat(table.keys(GoalsDB[encounterName].players), ", "))
    end
end

-- Function to handle loot event
local function OnLootReceived(self, event, message)
    local playerName, itemLink = message:match("([^%s]+) receives loot: (.+)%.")

    -- Assuming we check item quality here or specific item IDs
    local itemName, itemLink, itemRarity, itemLevel, _, _, _, _, _, itemIcon, itemSellPrice = GetItemInfo(itemLink)

    if itemRarity >= 4 then  -- Assuming rarity 4 (Epic) or higher indicates a boss item
        -- Reset the player's count to 0
        for encounterName, data in pairs(GoalsDB) do
            if data.players[playerName] then
                data.players[playerName] = 0
                print(playerName .. "'s count for " .. encounterName .. " has been reset to 0.")
            end
        end
        
        -- Update Loot History
        table.insert(GoalsLootHistory, 1, {player = playerName, item = itemLink, boss = encounterName})
        if #GoalsLootHistory > 10 then
            table.remove(GoalsLootHistory, 11)
        end

        -- Update the UI to reflect the reset
        Goals_UpdateUI()
        Goals_UpdateLootHistoryUI()
    end
end



-- Function to update the main UI
function Goals_UpdateUI()
    -- Clear the existing list
    print("Updating UI...");
    --GoalsFrameScrollChildText:SetText("")
    print("Updating UI...");
    
    --local UIConfig = CreateFrame("Frame", "MUI_BuffFrame", UIParent, "");
    --UIConfig.SetSize(300, 360); --width, height
    --UIConfig:SetPoint("TOPLEFT", UIParent, "TOPLEFT");

    testPrint("GoalsFrame");
    testPrint("GoalsMainTab");
    testPrint("GoalsFrameMainContent");
    testPrint("GoalsFrameScroll");

    local num = GetNumRaidMembers();

    for i=1,num do 
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i);

        --f:SetText(f:GetText() .. name)
        print(name);
    end
     

    -- Iterate over the GoalsDB table and display each boss and its count
    for bossName, data in pairs(GoalsDB) do
        local playerInfo = ""
        for playerName, count in pairs(data.players) do
            playerInfo = playerInfo .. playerName .. ": " .. count .. " kills, "
        end
        local info = string.format("%s: %d kills - Participants: %s\n", bossName, data.count, playerInfo)
        
    end
end

-- Function to update the loot history UI
function Goals_UpdateLootHistoryUI()
    -- Clear the existing list
    GoalsLootScrollChildText:SetText("")

    -- Iterate over the GoalsLootHistory table and display the last 10 items
    for _, entry in ipairs(GoalsLootHistory) do
        local info = string.format("%s received %s from %s\n", entry.player, entry.item, entry.boss)
        GoalsLootScrollChildText:SetText(GoalsLootScrollChildText:GetText() .. info)
    end
end

-- Initialize the UI when the addon is loaded
local function OnAddonLoaded(self, event, name)
    if name == "Goals" then
        print("Goals is loaded");
        Goals_UpdateUI()
        --Goals_UpdateLootHistoryUI()
    end
end


-- Register the event handler to listen for the ENCOUNTER_END and CHAT_MSG_LOOT events
local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "ENCOUNTER_END" then
        print("BOSS DOWN!");
        OnBossKill(self, event, ...)
    elseif event == "CHAT_MSG_LOOT" then
        print("LOOT");
        OnLootReceived(self, event, ...)
    end
end)

print("Compiled!");