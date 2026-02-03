-- Goals: CustomBuilds/ExampleBuilds.lua
-- Reference-only examples. This file is NOT loaded into the build list.
-- Copy any build below into Builds01.lua (or Builds02.lua ... Builds10.lua).
--
-- Quick start
-- 1) Create Goals/CustomBuilds/Builds01.lua (or Builds02.lua ... Builds10.lua).
-- 2) Paste your build blocks inside a returned list, separated by commas.
-- 3) Save and reload the UI.
--
-- Example file structure (Builds01.lua):
-- return {
--     { ... },
--     { ... },
-- }
--
-- Notes
-- - itemId must be > 0 to import into the wishlist.
-- - Use itemsBySlot (preferred) or items (list form). Avoid both.
-- - tags are optional strings used for filtering (example: "custom", "bis", "progression").
-- - level is used for build filtering; if omitted, the tier's min/max levels are used.
-- - sources are used for the source icons in the build list. For custom icons, use:
--     "custom-classic", "custom-tbc", or "custom-wotlk"
-- - Set disabled = true to keep a build out of the searchable build list.
-- - use `/reload` to reload the UI and see your changes.
--
-- Paths for icons:
--   Goals/Icons/custom-classic.tga
--   Goals/Icons/custom-tbc.tga
--   Goals/Icons/custom-wotlk.tga
--
-- Want your build included in the main addon?
-- - Open a new GitHub issue with the label: add my build
-- - Include your build data with accurate sources (links or addon name).
-- - You may credit yourself in name/notes, but keep it clean:
--   no foul language, slurs, or hateful content in names/ids/notes.
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
--
-- Two-build example (copy into Builds01.lua):

return {
    {
        id = "CUSTOM_WOTLK_SAMPLE",
        name = "Sample Build",
        class = "MAGE",
        spec = "Arcane",
        tier = "WOTLK_T10",
        level = 80,
        tags = {"custom", "bis"},
        sources = {"custom-wotlk"},
        itemsBySlot = {
            HEAD = { itemId = 40416, enchantId = 50368, gemIds = {41285}, notes = "", source = "custom" },
            MAINHAND = { itemId = 40402, enchantId = 62948, gemIds = {}, notes = "", source = "custom" },
        },
        notes = "Sample build for reference only.",
    },
    {
        id = "CUSTOM_WOTLK_SAMPLE_2",
        name = "Sample Build 2",
        class = "MAGE",
        spec = "Frost",
        tier = "WOTLK_T10",
        level = 80,
        tags = {"custom"},
        sources = {"custom-wotlk"},
        itemsBySlot = {
            HEAD = { itemId = 40416, enchantId = 50368, gemIds = {41285}, notes = "", source = "custom" },
            MAINHAND = { itemId = 40402, enchantId = 62948, gemIds = {}, notes = "", source = "custom" },
        },
        notes = "Second sample build for reference only.",
    },
}
