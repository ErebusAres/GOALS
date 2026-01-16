-- Goals: gemsAndEnchants.lua
-- Optional search lists for gems and enchantments used by the wishlist socket picker.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.GemSearchList = Goals.GemSearchList or {
    -- Add gem item IDs here.
    -- Example: 40008, -- Rigid Autumn's Glow
}

Goals.EnchantSearchList = Goals.EnchantSearchList or {
    -- Add enchant entries here.
    -- Example: { id = 3232, name = "Enchant Boots - Icewalker", icon = "Interface\\Icons\\Spell_Frost_Wisp" },
}
