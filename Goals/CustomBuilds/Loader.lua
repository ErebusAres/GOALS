-- Goals: CustomBuilds/Loader.lua
-- Smart loader for user-created build files.
-- Loads Builds01.lua through Builds10.lua if they exist.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.CustomBuildFiles = Goals.CustomBuildFiles or {}
function Goals:RegisterCustomBuildFile(builds)
    if type(builds) ~= "table" then
        return
    end
    table.insert(Goals.CustomBuildFiles, builds)
end

Goals.IconTextures = Goals.IconTextures or {}
Goals.IconTextures["custom-classic"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-classic.tga"
Goals.IconTextures["custom-tbc"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-tbc.tga"
Goals.IconTextures["custom-wotlk"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-wotlk.tga"

local function loadBuildFile(index)
    local filename = string.format("Interface\\AddOns\\%s\\CustomBuilds\\Builds%02d.lua", addonName, index)
    if not loadfile then
        return
    end
    local func = loadfile(filename)
    if not func then
        return
    end
    if setfenv then
        setfenv(func, _G)
    end
    local ok, result = pcall(func)
    if ok and type(result) == "table" and Goals and Goals.RegisterCustomBuildFile then
        Goals:RegisterCustomBuildFile(result)
    end
end

for i = 1, 10 do
    loadBuildFile(i)
end
