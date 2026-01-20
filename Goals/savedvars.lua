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
    wishlists = {
        version = 1,
        activeId = 1,
        nextId = 1,
        lists = {},
    },
    settings = {
        combineBossHistory = true,
        disenchanter = "",
        debug = false,
        devTestBoss = false,
        devTestWishlistChat = true,
        devTestWishlistItems = 3,
        resetMounts = false,
        resetPets = false,
        resetRecipes = false,
        resetQuestItems = false,
        resetTokens = true,
        resetMinQuality = 4,
        showPresentOnly = false,
        disablePointGain = false,
        sortMode = "POINTS",
        lootHistoryMinQuality = 4,
        lootHistoryHiddenBefore = 0,
        historyLootMinQuality = 0,
        historyFilterPointsAssigned = true,
        historyFilterPointsReset = true,
        historyFilterBuildSent = true,
        historyFilterBuildAccepted = true,
        historyFilterWishlistFound = true,
        historyFilterWishlistClaimed = true,
        historyFilterWishlistAdded = true,
        historyFilterWishlistRemoved = true,
        historyFilterWishlistSocketed = true,
        historyFilterWishlistEnchanted = true,
        historyFilterLootAssigned = true,
        historyFilterLootFound = true,
        localOnly = false,
        dbmIntegration = true,
        wishlistDbmIntegration = true,
        tableAutoLoadSeen = true,
        tableCombined = false,
        sudoDev = false,
        updateSeenVersion = 1,
        updateSeenMajor = 2,
        updateAvailableVersion = 0,
        updateAvailableMajor = 0,
        updateHasBeenSeen = false,
        autoMinimizeCombat = true,
        wishlistAnnounce = true,
        wishlistAnnounceChannel = "AUTO",
        wishlistAnnounceTemplate = "%s is on my wishlist",
        wishlistPopupDisabled = false,
        wishlistPopupSound = true,
        atlasImportPrompted = false,
        atlasSelectedListKey = "",
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
    if GoalsDB.settings then
        if GoalsDB.settings.updateSeenMajor == nil then
            GoalsDB.settings.updateSeenMajor = 2
        end
        if GoalsDB.settings.updateAvailableMajor == nil then
            GoalsDB.settings.updateAvailableMajor = 0
        end
    end
    if GoalsDB.settings then
        local hasDbm = false
        if DBM and DBM.RegisterCallback then
            hasDbm = true
        elseif IsAddOnLoaded then
            hasDbm = IsAddOnLoaded("DBM-Core") or IsAddOnLoaded("DBM-GUI")
        end
        if not hasDbm then
            GoalsDB.settings.wishlistDbmIntegration = false
        end
    end
    if GoalsDB.players then
        GoalsDB.players["Unknown"] = nil
        GoalsDB.players["unknown"] = nil
    end
    self.db = GoalsDB
end
