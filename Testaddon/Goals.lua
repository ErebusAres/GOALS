-- SavedVariables to persist data between sessions
GoalsDB = GoalsDB or {}
GoalsLootHistory = GoalsLootHistory or {}

-- Test function to add fake data to Boss Kills tab
function Goals_AddTestBossKillsData()
    GoalsDB["FakeBoss"] = {
        ["PlayerOne"] = 5,
        ["PlayerTwo"] = 3,
        ["PlayerThree"] = 8
    }
    Goals_UpdateBossKillsUI()
end

-- Test function to add fake data to Loot History tab
function Goals_AddTestLootHistoryData()
    table.insert(GoalsLootHistory, 1, {player = "PlayerOne", item = "[Test Sword of Testing]"})
    table.insert(GoalsLootHistory, 1, {player = "PlayerTwo", item = "[Test Shield of Testing]"})
    table.insert(GoalsLootHistory, 1, {player = "PlayerThree", item = "[Test Helm of Testing]"})
    if #GoalsLootHistory > 10 then
        table.remove(GoalsLootHistory, 11)
    end
    Goals_UpdateLootHistoryUI()
end

-- Function to update the Boss Kills UI
function Goals_UpdateBossKillsUI()
    local content = "Player Name | Kills\n"
    for playerName, kills in pairs(GoalsDB["FakeBoss"]) do
        content = content .. playerName .. " | " .. kills .. "\n"
    end
    GoalsBossKillsScrollChildText:SetText(content)
end

-- Function to update the Loot History UI
function Goals_UpdateLootHistoryUI()
    local content = ""
    for _, entry in ipairs(GoalsLootHistory) do
        content = content .. entry.player .. " obtained " .. entry.item .. "\n"
    end
    GoalsHistoryScrollChildText:SetText(content)
end