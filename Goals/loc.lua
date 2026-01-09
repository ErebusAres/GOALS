-- Goals: loc.lua
-- Localization strings and UI text.
-- Usage: local L = Goals.L; frame.Title:SetText(L.TITLE)

local addonName = ...
local Goals = _G.Goals

Goals.L = {
    TITLE = "Goals",
    TAB_OVERVIEW = "Overview",
    TAB_LOOT = "Loot",
    TAB_HISTORY = "History",
    TAB_SETTINGS = "Settings",
    TAB_DEV = "Dev",
    LABEL_POINTS = "Points",
    LABEL_SYNC = "Sync",
    LABEL_DISENCHANTER = "Disenchanter",
    LABEL_LAST_LOOT = "Last Loot",
    LABEL_HISTORY = "History",
    LABEL_MANUAL = "Manual Adjust",
    LABEL_PLAYER = "Player",
    LABEL_AMOUNT = "Amount",
    LABEL_REASON = "Reason",
    BUTTON_ADD = "Add",
    BUTTON_SET = "Set",
    BUTTON_RESET = "Reset",
    BUTTON_APPLY = "Apply",
    BUTTON_OPEN = "Open Goals",
    CHECK_COMBINE_HISTORY = "Combine boss history entries",
    CHECK_MINIMAP = "Show minimap button",
    CHECK_DEBUG = "Enable debug log",
    SETTINGS_DISENCHANTER = "Set Disenchanter",
    DEV_SIM_KILL = "Simulate Boss Kill",
    DEV_SIM_WIPE = "Simulate Wipe",
    DEV_SIM_LOOT = "Simulate Loot",
    DEV_TOGGLE_DEBUG = "Toggle Debug",
}
