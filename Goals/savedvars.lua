-- Goals: savedvars.lua
-- SavedVariables initialization and defaults.
-- Usage: Goals:InitDB() on PLAYER_LOGIN.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.defaults = {
    version = 1,
    players = {},
    history = {},
    debugLog = {},
    tables = {},
    activeTableName = "",
    settings = {
        combineBossHistory = true,
        disenchanter = "",
        debug = false,
        devTestBoss = false,
        resetMounts = false,
        resetPets = false,
        resetRecipes = false,
        resetQuestItems = false,
        resetTokens = true,
        resetMinQuality = 4,
        showPresentOnly = false,
        sortMode = "POINTS",
        lootHistoryMinQuality = 4,
        lootHistoryHiddenBefore = 0,
        localOnly = false,
        tableAutoLoadSeen = true,
        tableCombined = false,
        sudoDev = false,
        updateSeenVersion = 1,
        updateAvailableVersion = 0,
        updateHasBeenSeen = false,
        autoMinimizeCombat = true,
        minimap = {
            hide = false,
            angle = 220,
        },
        floatingButton = {
            x = 0,
            y = 0,
            show = false,
        },
        miniTracker = {
            show = false,
            minimized = false,
            x = 0,
            y = 0,
            hasPosition = false,
            buttonX = 0,
            buttonY = 0,
        },
    },
}

function Goals:CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            self:CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Goals:InitDB()
    if type(GoalsDB) ~= "table" then
        GoalsDB = {}
    end
    self:CopyDefaults(GoalsDB, self.defaults)
    if GoalsDB.settings and GoalsDB.settings.resetMountPet ~= nil then
        if GoalsDB.settings.resetMounts == nil then
            GoalsDB.settings.resetMounts = GoalsDB.settings.resetMountPet and true or false
        end
        if GoalsDB.settings.resetPets == nil then
            GoalsDB.settings.resetPets = GoalsDB.settings.resetMountPet and true or false
        end
        GoalsDB.settings.resetMountPet = nil
    end
    if GoalsDB.settings and GoalsDB.settings.resetTokens == nil then
        GoalsDB.settings.resetTokens = true
    end
    if GoalsDB.settings and GoalsDB.settings.lootHistoryEpicOnly ~= nil then
        if GoalsDB.settings.lootHistoryMinQuality == nil then
            GoalsDB.settings.lootHistoryMinQuality = GoalsDB.settings.lootHistoryEpicOnly and 4 or 0
        end
        GoalsDB.settings.lootHistoryEpicOnly = nil
    end
    if GoalsDB.players then
        GoalsDB.players["Unknown"] = nil
        GoalsDB.players["unknown"] = nil
    end
    self.db = GoalsDB
end
