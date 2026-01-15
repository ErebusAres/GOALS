-- Goals: armorTokens.lua
-- Mapping of tier items to their armor token turn-ins.
-- Populate this table with: [tierItemId] = tokenItemId

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.ArmorTokenMap = Goals.ArmorTokenMap or {
    -- Example:
    -- [30166] = 30242, -- Cataclysm Headguard -> Token Item ID

    -- The Burning Crusade
        -- Shaman Phase 1
        [29012] = 29024, -- Malefic Mask -> Shaman Phase 1
        [29013] = 29025, -- Malefic Hood -> Shaman Phase 1
        [29014] = 29026, -- Malefic Coif -> Shaman Phase 1
        -- Phase 2 [30242] Helm of the Vanquished Campion (Paladin, Rogue, Shaman)
        [30166] = 30242, -- Cataclysm Headguard -> Shaman Phase 2
        -- Phase 2 [30236] Chestguard of the Vanquished Champion (Paladin, Rogue, Shaman)
        [30164] = 30236, -- Cataclysm Chestguard -> Shaman Phase 2
        [30169] = 30236, -- Cataclysm Chestpiece -> Shaman Phase 2
        [30185] = 30236, -- Cataclysm Tunic -> Shaman Phase 2
}
