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
        resetRequiresLootWindow = false,
        showPresentOnly = false,
        disablePointGain = false,
        sortMode = "POINTS",
        lootHistoryMinQuality = 4,
        lootHistoryHiddenBefore = 0,
        historyLootMinQuality = 0,
        historyFilterPoints = true,
        historyFilterEncounter = true,
        historyFilterBuild = true,
        historyFilterWishlistStatus = true,
        historyFilterWishlistItems = true,
        historyFilterLoot = true,
        historyFiltersMigrated = false,
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
    if GoalsDB.settings and not GoalsDB.settings.historyFiltersMigrated then
        local settings = GoalsDB.settings
        local function hasValue(value)
            return value ~= nil
        end
        local hadOld = hasValue(settings.historyFilterPointsAssigned)
            or hasValue(settings.historyFilterPointsReset)
            or hasValue(settings.historyFilterBuildSent)
            or hasValue(settings.historyFilterBuildAccepted)
            or hasValue(settings.historyFilterWishlistFound)
            or hasValue(settings.historyFilterWishlistClaimed)
            or hasValue(settings.historyFilterWishlistAdded)
            or hasValue(settings.historyFilterWishlistRemoved)
            or hasValue(settings.historyFilterWishlistSocketed)
            or hasValue(settings.historyFilterWishlistEnchanted)
            or hasValue(settings.historyFilterLootAssigned)
            or hasValue(settings.historyFilterLootFound)
        if hadOld then
            if hasValue(settings.historyFilterPointsAssigned) or hasValue(settings.historyFilterPointsReset) then
                settings.historyFilterPoints = (settings.historyFilterPointsAssigned ~= false)
                    or (settings.historyFilterPointsReset ~= false)
            end
            if hasValue(settings.historyFilterBuildSent) or hasValue(settings.historyFilterBuildAccepted) then
                settings.historyFilterBuild = (settings.historyFilterBuildSent ~= false)
                    or (settings.historyFilterBuildAccepted ~= false)
            end
            if hasValue(settings.historyFilterWishlistFound) or hasValue(settings.historyFilterWishlistClaimed) then
                settings.historyFilterWishlistStatus = (settings.historyFilterWishlistFound ~= false)
                    or (settings.historyFilterWishlistClaimed ~= false)
            end
            if hasValue(settings.historyFilterWishlistAdded)
                or hasValue(settings.historyFilterWishlistRemoved)
                or hasValue(settings.historyFilterWishlistSocketed)
                or hasValue(settings.historyFilterWishlistEnchanted) then
                settings.historyFilterWishlistItems = (settings.historyFilterWishlistAdded ~= false)
                    or (settings.historyFilterWishlistRemoved ~= false)
                    or (settings.historyFilterWishlistSocketed ~= false)
                    or (settings.historyFilterWishlistEnchanted ~= false)
            end
            if hasValue(settings.historyFilterLootAssigned) or hasValue(settings.historyFilterLootFound) then
                settings.historyFilterLoot = (settings.historyFilterLootAssigned ~= false)
                    or (settings.historyFilterLootFound ~= false)
            end
        end
        settings.historyFiltersMigrated = true
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
