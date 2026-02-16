-- Goals: wishlistBuildCustom.lua
-- User-maintained wishlist build data.
-- This file is safe to edit and is loaded alongside wishlistBuildData.lua.
--
-- Purpose
-- - Store your custom builds without touching auto-generated data.
-- - Keep examples and a guide in one place.
-- - Add your own source tags and icons (custom-classic/tbc/wotlk).
--
-- How to use
-- 1) Copy one of the EXAMPLE builds below.
-- 2) Change id/name/class/spec/tier/level.
-- 3) Fill itemsBySlot with itemId/enchantId/gemIds.
-- 4) Keep sources and tags consistent so icons show in the UI.
--
-- Notes
-- - itemId must be > 0 to import into the wishlist.
-- - Use itemsBySlot (preferred) or items (list form). Avoid both.
-- - tags are optional strings used for filtering (example: "custom", "bis", "progression").
-- - level is used for build filtering; if omitted, the tier's min/max levels are used.
-- - sources are used for the source icons in the build list. For custom icons, use:
--     "custom-classic", "custom-tbc", or "custom-wotlk"
-- - When you add the TGA files in Goals/Icons/, the UI will show them automatically.
-- - Set disabled = true to keep a build out of the searchable build list.
--
-- Paths for icons (to be added later):
--   Goals/Icons/custom-classic.tga
--   Goals/Icons/custom-tbc.tga
--   Goals/Icons/custom-wotlk.tga
--
-- Slot keys (itemsBySlot):
--   HEAD, NECK, SHOULDER, BACK, CHEST, WRIST, HANDS, WAIST, LEGS, FEET,
--   RING1, RING2, TRINKET1, TRINKET2, MAINHAND, OFFHAND, RELIC
--
-- Class names (class):
--   DEATHKNIGHT, DRUID, HUNTER, MAGE, PALADIN, PRIEST, ROGUE, SHAMAN, WARLOCK, WARRIOR
--
-- Spec names (spec) commonly used:
--   DEATHKNIGHT: Blood, Frost, Unholy (also Blood (DPS) used in some builds)
--   DRUID: Balance, Feral, Restoration
--   HUNTER: Beast Mastery, Marksmanship, Survival
--   MAGE: Arcane, Fire, Frost
--   PALADIN: Holy, Protection, Retribution
--   PRIEST: Discipline, Holy, Shadow
--   ROGUE: Assassination, Combat, Subtlety
--   SHAMAN: Elemental, Enhancement, Restoration
--   WARLOCK: Affliction, Demonology, Destruction
--   WARRIOR: Arms, Fury, Protection
--
-- Tier labels (tier):
--   CLASSIC_PRE, CLASSIC_T1, CLASSIC_T2, CLASSIC_T25, CLASSIC_T3,
--   TBC_PRE, TBC_T4, TBC_T5, TBC_T6,
--   WOTLK_PRE, WOTLK_T7, WOTLK_T8, WOTLK_T9, WOTLK_T10

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.IconTextures = Goals.IconTextures or {}
Goals.IconTextures["custom-classic"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-classic.tga"
Goals.IconTextures["custom-tbc"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-tbc.tga"
Goals.IconTextures["custom-wotlk"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\custom-wotlk.tga"

Goals.WishlistBuildCustomData = {
    builds = {
        -- CUSTOM TEST: shows all three custom source icons at once.
        -- Remove or set disabled = true once you have verified the icons in-game.
        {
            id = "CUSTOM_ICON_PREVIEW",
            name = "Custom Icon Preview",
            class = "MAGE",
            spec = "Arcane",
            tier = "WOTLK_T10",
            level = 80,
            tags = {"custom"},
            sources = {"custom-classic", "custom-tbc", "custom-wotlk"},
            disabled = true, -- Remove this line to enable this build.
            itemsBySlot = {
                HEAD = { itemId = 40416, enchantId = 50368, gemIds = {41285}, notes = "Icon preview build 30123", source = "custom" },
            },
            notes = "Preview build to verify custom source icons render in-game.",
        },
        -- EXAMPLE 1: WotLK template (replace item IDs)
        {
            id = "CUSTOM_WOTLK_TEMPLATE",
            name = "Custom Template (WotLK)",
            class = "MAGE",
            spec = "Arcane",
            tier = "WOTLK_T10",
            level = 80,
            tags = {"custom", "bis"},
            sources = {"custom-wotlk"},
            disabled = true, -- Remove this line to enable this build.
            itemsBySlot = {
                HEAD = { itemId = 40416, enchantId = 50368, gemIds = {41285}, notes = "Replace with your item", source = "custom" },
                MAINHAND = { itemId = 40402, enchantId = 62948, gemIds = {}, notes = "Replace with your item", source = "custom" },
            },
            notes = "Example only. Replace items, enchants, and gems.",
        },

        -- EXAMPLE 2: TBC template (replace item IDs)
        {
            id = "CUSTOM_TBC_TEMPLATE",
            name = "Custom Template (TBC)",
            class = "WARLOCK",
            spec = "Destruction",
            tier = "TBC_T6",
            level = 70,
            tags = {"custom"},
            sources = {"custom-tbc"},
            disabled = true, -- Remove this line to enable this build.
            itemsBySlot = {
                HEAD = { itemId = 0, enchantId = 0, gemIds = {}, notes = "Set itemId", source = "custom" },
            },
            notes = "Example only. Set itemId/enchant/gems.",
        },

        -- EXAMPLE 3: Classic template (replace item IDs)
        {
            id = "CUSTOM_CLASSIC_TEMPLATE",
            name = "Custom Template (Classic)",
            class = "WARRIOR",
            spec = "Fury",
            tier = "CLASSIC_T3",
            level = 60,
            tags = {"custom"},
            sources = {"custom-classic"},
            disabled = true, -- Remove this line to enable this build.
            itemsBySlot = {
                HEAD = { itemId = 0, enchantId = 0, gemIds = {}, notes = "Set itemId", source = "custom" },
            },
            notes = "Example only. Set itemId/enchant/gems.",
        },
    },
}
