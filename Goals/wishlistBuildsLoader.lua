-- Goals: wishlist builds loader
-- Initializes shared build metadata and icon mappings.
local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

-- Icons
local function makeTextureTag(texture, size, coords, texSize)
    if not texture or texture == "" then
        return ""
    end
    local iconSize = size or 16
    if coords then
        local texW = texSize or 256
        local left = coords[1] * texW
        local right = coords[2] * texW
        local top = coords[3] * texW
        local bottom = coords[4] * texW
        return string.format("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t", texture, iconSize, iconSize, texW, texW, left, right, top, bottom)
    end
    return string.format("|T%s:%d:%d|t", texture, iconSize, iconSize)
end

local function classIconTag(class, size)
    local classButtons = _G.CLASS_BUTTONS
    if classButtons and classButtons[class] then
        return makeTextureTag("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", size, classButtons[class], 256)
    end
    local classIconNames = {
        WARRIOR = "Warrior",
        PALADIN = "Paladin",
        HUNTER = "Hunter",
        ROGUE = "Rogue",
        PRIEST = "Priest",
        DEATHKNIGHT = "DeathKnight",
        SHAMAN = "Shaman",
        MAGE = "Mage",
        WARLOCK = "Warlock",
        DRUID = "Druid",
    }
    local iconName = classIconNames[class]
    if iconName then
        return makeTextureTag("Interface\\Icons\\ClassIcon_" .. iconName, size)
    end
    return makeTextureTag("Interface\\Icons\\INV_Misc_QuestionMark", size)
end

local SPEC_ICON_TEXTURES = {
    WARLOCK_AFFLICTION = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    WARLOCK_DEMONOLOGY = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    WARLOCK_DESTRUCTION = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    DRUID_BALANCE = "Interface\\Icons\\Spell_Nature_StarFall",
    DRUID_FERAL = "Interface\\Icons\\Ability_Druid_CatForm",
    DRUID_RESTORATION = "Interface\\Icons\\Spell_Nature_HealingTouch",
    HUNTER_BEASTMASTERY = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    HUNTER_MARKSMANSHIP = "Interface\\Icons\\Ability_Marksmanship",
    HUNTER_SURVIVAL = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
    MAGE_ARCANE = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    MAGE_FIRE = "Interface\\Icons\\Spell_Fire_FireBolt02",
    MAGE_FROST = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    PALADIN_HOLY = "Interface\\Icons\\Spell_Holy_HolyBolt",
    PALADIN_PROTECTION = "Interface\\Icons\\Spell_Holy_DevotionAura",
    PALADIN_RETRIBUTION = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    PRIEST_DISCIPLINE = "Interface\\Icons\\Spell_Holy_WordFortitude",
    PRIEST_HOLY = "Interface\\Icons\\Spell_Holy_HolyBolt",
    PRIEST_SHADOW = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    ROGUE_ASSASSINATION = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    ROGUE_COMBAT = "Interface\\Icons\\Ability_BackStab",
    ROGUE_SUBTLETY = "Interface\\Icons\\Ability_Stealth",
    SHAMAN_ELEMENTAL = "Interface\\Icons\\Spell_Nature_Lightning",
    SHAMAN_ENHANCEMENT = "Interface\\Icons\\Spell_Nature_LightningShield",
    SHAMAN_RESTORATION = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    WARRIOR_ARMS = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    WARRIOR_FURY = "Interface\\Icons\\Ability_Warrior_InnerRage",
    WARRIOR_PROTECTION = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    DEATHKNIGHT_BLOOD = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    DEATHKNIGHT_FROST = "Interface\\Icons\\Spell_Deathknight_FrostPresence",
    DEATHKNIGHT_UNHOLY = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
}

local function specIconTagSpell(specKey, size)
    local texture = SPEC_ICON_TEXTURES[specKey]
    if texture then
        return makeTextureTag(texture, size)
    end
    return ""
end

Goals.IconTextures = Goals.IconTextures or {}
Goals.IconTextures.wowhead = "Interface\\AddOns\\" .. addonName .. "\\Icons\\wowhead-rocket_icon.tga"
Goals.IconTextures.loonbis = "Interface\\AddOns\\" .. addonName .. "\\Icons\\loonbestinslot_icon.tga"
Goals.IconTextures.bistooltip = "Interface\\Icons\\INV_Weapon_Glaive_01"
Goals.IconTextures["wowtbc-gg-classic"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\wowtbc-gg-classic.tga"
Goals.IconTextures["wowtbc-gg-tbc"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\wowtbc-gg-tbc.tga"
Goals.IconTextures["wowtbc-gg-wotlk"] = "Interface\\AddOns\\" .. addonName .. "\\Icons\\wowtbc-gg-wotlk.tga"
Goals.IconTextures.classSprite = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
Goals.IconTextures.spec = SPEC_ICON_TEXTURES

local ICONS = {
    WOWHEAD = makeTextureTag("Interface\\AddOns\\" .. addonName .. "\\Icons\\wowhead-rocket_icon.tga", 16),
    LOONBIS = makeTextureTag("Interface\\AddOns\\" .. addonName .. "\\Icons\\loonbestinslot_icon.tga", 16),
    CLASS = {
        WARRIOR = classIconTag("WARRIOR", 16),
        PALADIN = classIconTag("PALADIN", 16),
        HUNTER = classIconTag("HUNTER", 16),
        ROGUE = classIconTag("ROGUE", 16),
        PRIEST = classIconTag("PRIEST", 16),
        DEATHKNIGHT = classIconTag("DEATHKNIGHT", 16),
        SHAMAN = classIconTag("SHAMAN", 16),
        MAGE = classIconTag("MAGE", 16),
        WARLOCK = classIconTag("WARLOCK", 16),
        DRUID = classIconTag("DRUID", 16),
    },
    SPEC = {
        WARLOCK_AFFLICTION = specIconTagSpell("WARLOCK_AFFLICTION", 16),
        WARLOCK_DEMONOLOGY = specIconTagSpell("WARLOCK_DEMONOLOGY", 16),
        WARLOCK_DESTRUCTION = specIconTagSpell("WARLOCK_DESTRUCTION", 16),
        DRUID_BALANCE = specIconTagSpell("DRUID_BALANCE", 16),
        DRUID_FERAL = specIconTagSpell("DRUID_FERAL", 16),
        DRUID_RESTORATION = specIconTagSpell("DRUID_RESTORATION", 16),
        HUNTER_BEASTMASTERY = specIconTagSpell("HUNTER_BEASTMASTERY", 16),
        HUNTER_MARKSMANSHIP = specIconTagSpell("HUNTER_MARKSMANSHIP", 16),
        HUNTER_SURVIVAL = specIconTagSpell("HUNTER_SURVIVAL", 16),
        MAGE_ARCANE = specIconTagSpell("MAGE_ARCANE", 16),
        MAGE_FIRE = specIconTagSpell("MAGE_FIRE", 16),
        MAGE_FROST = specIconTagSpell("MAGE_FROST", 16),
        PALADIN_HOLY = specIconTagSpell("PALADIN_HOLY", 16),
        PALADIN_PROTECTION = specIconTagSpell("PALADIN_PROTECTION", 16),
        PALADIN_RETRIBUTION = specIconTagSpell("PALADIN_RETRIBUTION", 16),
        PRIEST_DISCIPLINE = specIconTagSpell("PRIEST_DISCIPLINE", 16),
        PRIEST_HOLY = specIconTagSpell("PRIEST_HOLY", 16),
        PRIEST_SHADOW = specIconTagSpell("PRIEST_SHADOW", 16),
        ROGUE_ASSASSINATION = specIconTagSpell("ROGUE_ASSASSINATION", 16),
        ROGUE_COMBAT = specIconTagSpell("ROGUE_COMBAT", 16),
        ROGUE_SUBTLETY = specIconTagSpell("ROGUE_SUBTLETY", 16),
        SHAMAN_ELEMENTAL = specIconTagSpell("SHAMAN_ELEMENTAL", 16),
        SHAMAN_ENHANCEMENT = specIconTagSpell("SHAMAN_ENHANCEMENT", 16),
        SHAMAN_RESTORATION = specIconTagSpell("SHAMAN_RESTORATION", 16),
        WARRIOR_ARMS = specIconTagSpell("WARRIOR_ARMS", 16),
        WARRIOR_FURY = specIconTagSpell("WARRIOR_FURY", 16),
        WARRIOR_PROTECTION = specIconTagSpell("WARRIOR_PROTECTION", 16),
        DEATHKNIGHT_BLOOD = specIconTagSpell("DEATHKNIGHT_BLOOD", 16),
        DEATHKNIGHT_FROST = specIconTagSpell("DEATHKNIGHT_FROST", 16),
        DEATHKNIGHT_UNHOLY = specIconTagSpell("DEATHKNIGHT_UNHOLY", 16),
    },
    WARLOCK = classIconTag("WARLOCK", 16),
    DESTRUCTION = specIconTagSpell("WARLOCK_DESTRUCTION", 16),
}

Goals.WishlistBuildData = Goals.WishlistBuildData or {
    builds = {}
}
