-- Goals: updates.lua
-- Update metadata for the Update tab.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.UpdateInfo = {
    major = 2,
    version = 14,
    url = "https://github.com/ErebusAres/GOALS/archive/refs/heads/main.zip",
}
