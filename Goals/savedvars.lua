-- Goals: savedvars.lua
-- SavedVariables initialization and defaults.
-- Usage: Goals:InitDB() on PLAYER_LOGIN.

local addonName = ...
local Goals = _G.Goals

Goals.defaults = {
    version = 1,
    players = {},
    history = {},
    settings = {
        combineBossHistory = true,
        disenchanter = "",
        debug = false,
        devTestBoss = false,
        showPresentOnly = false,
        sortMode = "POINTS",
        minimap = {
            hide = false,
            angle = 220,
        },
        floatingButton = {
            x = 0,
            y = 0,
            show = false,
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
    self.db = GoalsDB
end
