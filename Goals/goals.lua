-- Reference to the SavedVariables table
GoalsDB = GoalsDB or {}
GoalsLootHistory = GoalsLootHistory or {}

-- Function to handle boss kill event
local function OnBossKill(encounterName)
    -- If this boss has not been killed before, initialize its count
    if not GoalsDB[encounterName] then
        GoalsDB[encounterName] = { count = 0, players = {} }
    end
    
    -- Increment the boss kill count
    GoalsDB[encounterName].count = GoalsDB[encounterName].count + 1
    
    -- Get the list of players in the raid or group
    local numGroupMembers = GetNumRaidMembers() -- Use GetNumRaidMembers for 3.3.5a
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

-- Function to handle combat log event
local function OnCombatLogEvent(self, event, ...)
    local timestamp, subEvent, _, _, _, _, _, destGUID, destName, destFlags, _, spellID, spellName = ...
    
    if subEvent == "UNIT_DIED" then
        local isBoss = UnitClassification(destName) == "worldboss"
        if isBoss then
            OnBossKill(destName)
        end
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
-- Function to update the loot history UI
function Goals_UpdateLootHistoryUI()
    -- Ensure GoalsLootScrollChildText is initialized
    if not GoalsLootScrollChildText then
        print("Error: GoalsLootScrollChildText is not initialized.")
        return
    end
    -- Clear the existing list
    GoalsLootScrollChildText:SetText("")
    -- Iterate over the GoalsLootHistory table and display the last 10 items
    for _, entry in ipairs(GoalsLootHistory) do
        local info = string.format("%s received %s from %s\n", entry.player, entry.item, entry.boss)
        GoalsLootScrollChildText:SetText(GoalsLootScrollChildText:GetText() .. info)
    end
    -- Display "NO INFORMATION YET" if GoalsLootHistory is empty
    if GoalsLootScrollChildText:GetText() == "" then
        GoalsLootScrollChildText:SetText("NO INFORMATION YET")
    end
end

-- Function to handle button click
function GoalsMainTab_OnClick()
    -- Ensure GoalsFrameMainContent is initialized
    if not GoalsFrameMainContent then
        print("Error: GoalsFrameMainContent is not initialized.")
        return
    end
    -- Your existing code to handle the button click
    GoalsFrameMainContent:SetText("Button clicked!")
end

-- Initialize the UI when the addon is loaded
local function OnAddonLoaded(self, event, name)
    if name == "Goals" then
        Goals_UpdateUI()
        Goals_UpdateLootHistoryUI()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(self, event, ...)
    elseif event == "CHAT_MSG_LOOT" then
        OnLootReceived(self, event, ...)
    end
end)
        -- Update the UI to reflect the reset
        Goals_UpdateUI()        -- Function to update the loot history UI
        function Goals_UpdateLootHistoryUI()
            -- Ensure GoalsLootScrollChildText is initialized
            if not GoalsLootScrollChildText then
                print("Error: GoalsLootScrollChildText is not initialized.")
                return
            end
            -- Clear the existing list
            GoalsLootScrollChildText:SetText("")
            -- Iterate over the GoalsLootHistory table and display the last 10 items
            for _, entry in ipairs(GoalsLootHistory) do
                local info = string.format("%s received %s from %s\n", entry.player, entry.item, entry.boss)
                GoalsLootScrollChildText:SetText(GoalsLootScrollChildText:GetText() .. info)
            end
            -- Display "NO INFORMATION YET" if GoalsLootHistory is empty
            if GoalsLootScrollChildText:GetText() == "" then
                GoalsLootScrollChildText:SetText("NO INFORMATION YET")
            end
        end
        
        -- Function to handle button click
        function GoalsMainTab_OnClick()
            -- Ensure GoalsFrameMainContent is initialized
            if not GoalsFrameMainContent then
                print("Error: GoalsFrameMainContent is not initialized.")
                return
            end
            -- Your existing code to handle the button click
            GoalsFrameMainContent:SetText("Button clicked!")
        end
        
        -- Initialize the UI when the addon is loaded
        local function OnAddonLoaded(self, event, name)
            if name == "Goals" then
                Goals_UpdateUI()
                Goals_UpdateLootHistoryUI()
                GoalsMainTab_OnClick() -- Call the new function
            end
        end
        
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, event, ...)
            if event == "ADDON_LOADED" then
                OnAddonLoaded(self, event, ...)
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                OnCombatLogEvent(self, event, ...)
            elseif event == "CHAT_MSG_LOOT" then
                OnLootReceived(self, event, ...)
            end
        end)
        Goals_UpdateLootHistoryUI()
    end
end

-- Register the event handler to listen for the COMBAT_LOG_EVENT_UNFILTERED and CHAT_MSG_LOOT events
local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(self, event, ...)
    elseif event == "CHAT_MSG_LOOT" then
        OnLootReceived(self, event, ...)
    end
end)

-- Function to update the main UI
function Goals_UpdateUI()
    -- Ensure GoalsFrameScrollChildText is initialized
    if not GoalsFrameScrollChildText then
        print("Error: GoalsFrameScrollChildText is not initialized.")
        return
    end

    -- Clear the existing list
    GoalsFrameScrollChildText:SetText("")

    -- Iterate over the GoalsDB table and display each boss and its count
    for bossName, data in pairs(GoalsDB) do
        local playerInfo = ""
        for playerName, count in pairs(data.players) do
            playerInfo = playerInfo .. playerName .. ": " .. count .. " kills, "
        end
        local info = string.format("%s: %d kills - Participants: %s\n", bossName, data.count, playerInfo)
        GoalsFrameScrollChildText:SetText(GoalsFrameScrollChildText:GetText() .. info)
    end

    -- Display "NO INFORMATION YET" if GoalsDB is empty
    if GoalsFrameScrollChildText:GetText() == "" then
        GoalsFrameScrollChildText:SetText("NO INFORMATION YET")
    end
end

-- Function to update the loot history UI
function Goals_UpdateLootHistoryUI()
    -- Ensure GoalsLootScrollChildText is initialized
    if not GoalsLootScrollChildText then
        print("Error: GoalsLootScrollChildText is not initialized.")
        return
    end

    -- Clear the existing list
    GoalsLootScrollChildText:SetText("")

    -- Iterate over the GoalsLootHistory table and display the last 10 items
    for _, entry in ipairs(GoalsLootHistory) do
        local info = string.format("%s received %s from %s\n", entry.player, entry.item, entry.boss)
        GoalsLootScrollChildText:SetText(GoalsLootScrollChildText:GetText() .. info)
    end

    -- Display "NO INFORMATION YET" if GoalsLootHistory is empty
    if GoalsLootScrollChildText:GetText() == "" then
        GoalsLootScrollChildText:SetText("NO INFORMATION YET")
    end
end

-- Initialize the UI when the addon is loaded
local function OnAddonLoaded(self, event, name)
    if name == "Goals" then
        Goals_UpdateUI()
        Goals_UpdateLootHistoryUI()
    end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(self, event, ...)
    elseif event == "CHAT_MSG_LOOT" then
        OnLootReceived(self, event, ...)
    end
end)
