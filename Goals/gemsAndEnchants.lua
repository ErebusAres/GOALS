-- Goals: gemsAndEnchants.lua
-- Optional search lists for gems and enchantments used by the wishlist socket picker.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.GemSearchList = Goals.GemSearchList or {
    774, -- Malachite
    818, -- Tigerseye
    1206, -- Moss Agate
    1210, -- Shadowgem
    1529, -- Jade
    1705, -- Lesser Moonstone
    3864, -- Citrine
    5498, -- Small Lustrous Pearl
    5500, -- Iridescent Pearl
    7909, -- Aquamarine
    7910, -- Star Ruby
    7971, -- Black Pearl
    11382, -- Blood of the Mountain
    12361, -- Blue Sapphire
    12363, -- Arcane Crystal
    12364, -- Huge Emerald
    12799, -- Large Opal
    12800, -- Azerothian Diamond
    13926, -- Golden Pearl
    19774, -- Souldarite
    21929, -- Flame Spessarite
    22459, -- Void Sphere
    22460, -- Prismatic Sphere
    23077, -- Blood Garnet
    23079, -- Deep Peridot
    23094, -- Teardrop Blood Garnet
    23095, -- Bold Blood Garnet
    23096, -- Runed Blood Garnet
    23097, -- Delicate Blood Garnet
    23098, -- Inscribed Flame Spessarite
    23099, -- Luminous Flame Spessarite
    23100, -- Glinting Flame Spessarite
    23101, -- Potent Flame Spessarite
    23103, -- Radiant Deep Peridot
    23104, -- Jagged Deep Peridot
    23105, -- Enduring Deep Peridot
    23106, -- Dazzling Deep Peridot
    23107, -- Shadow Draenite
    23108, -- Glowing Shadow Draenite
    23109, -- Royal Shadow Draenite
    23110, -- Shifting Shadow Draenite
    23111, -- Sovereign Shadow Draenite
    23112, -- Golden Draenite
    23113, -- Brilliant Golden Draenite
    23114, -- Gleaming Golden Draenite
    23115, -- Thick Golden Draenite
    23116, -- Rigid Golden Draenite
    23117, -- Azure Moonstone
    23118, -- Solid Azure Moonstone
    23119, -- Sparkling Azure Moonstone
    23120, -- Stormy Azure Moonstone
    23121, -- Lustrous Azure Moonstone
    23436, -- Living Ruby
    23437, -- Talasite
    23438, -- Star of Elune
    23439, -- Noble Topaz
    23440, -- Dawnstone
    23441, -- Nightseye
    24027, -- Bold Living Ruby
    24028, -- Delicate Living Ruby
    24029, -- Teardrop Living Ruby
    24030, -- Runed Living Ruby
    24031, -- Bright Living Ruby
    24032, -- Subtle Living Ruby
    24033, -- Solid Star of Elune
    24035, -- Sparkling Star of Elune
    24036, -- Flashing Living Ruby
    24037, -- Lustrous Star of Elune
    24039, -- Stormy Star of Elune
    24047, -- Brilliant Dawnstone
    24048, -- Smooth Dawnstone
    24050, -- Gleaming Dawnstone
    24051, -- Rigid Dawnstone
    24052, -- Thick Dawnstone
    24053, -- Mystic Dawnstone
    24054, -- Sovereign Nightseye
    24055, -- Shifting Nightseye
    24056, -- Glowing Nightseye
    24057, -- Royal Nightseye
    24058, -- Inscribed Noble Topaz
    24059, -- Potent Noble Topaz
    24060, -- Luminous Noble Topaz
    24061, -- Glinting Noble Topaz
    24062, -- Enduring Talasite
    24065, -- Dazzling Talasite
    24066, -- Radiant Talasite
    24067, -- Jagged Talasite
    24478, -- Jaggal Pearl
    24479, -- Shadow Pearl
    25867, -- Earthstorm Diamond
    25868, -- Skyfire Diamond
    25890, -- Destructive Skyfire Diamond
    25893, -- Mystical Skyfire Diamond
    25894, -- Swift Skyfire Diamond
    25895, -- Enigmatic Skyfire Diamond
    25896, -- Powerful Earthstorm Diamond
    25897, -- Bracing Earthstorm Diamond
    25898, -- Tenacious Earthstorm Diamond
    25899, -- Brutal Earthstorm Diamond
    25901, -- Insightful Earthstorm Diamond
    27679, -- Sublime Mystic Dawnstone
    27777, -- Stark Blood Garnet
    27785, -- Notched Deep Peridot
    27786, -- Barbed Deep Peridot
    27809, -- Barbed Deep Peridot
    27812, -- Stark Blood Garnet
    27820, -- Notched Deep Peridot
    28118, -- Runed Ornate Ruby
    28119, -- Smooth Ornate Dawnstone
    28120, -- Gleaming Ornate Dawnstone
    28123, -- Potent Ornate Topaz
    28290, -- Smooth Golden Draenite
    28360, -- Mighty Blood Garnet
    28361, -- Mighty Blood Garnet
    28362, -- Bold Ornate Ruby
    28363, -- Inscribed Ornate Topaz
    28458, -- Bold Tourmaline
    28459, -- Delicate Tourmaline
    28460, -- Teardrop Tourmaline
    28461, -- Runed Tourmaline
    28462, -- Bright Tourmaline
    28463, -- Solid Zircon
    28464, -- Sparkling Zircon
    28465, -- Lustrous Zircon
    28466, -- Brilliant Amber
    28467, -- Smooth Amber
    28468, -- Rigid Amber
    28469, -- Gleaming Amber
    28470, -- Thick Amber
    28556, -- Swift Windfire Diamond
    28557, -- Swift Starfire Diamond
    28595, -- Bright Blood Garnet
    30546, -- Sovereign Tanzanite
    30547, -- Luminous Fire Opal
    30548, -- Polished Chrysoprase
    30549, -- Shifting Tanzanite
    30550, -- Sundered Chrysoprase
    30551, -- Infused Fire Opal
    30552, -- Blessed Tanzanite
    30553, -- Pristine Fire Opal
    30554, -- Stalwart Fire Opal
    30555, -- Glowing Tanzanite
    30556, -- Glinting Fire Opal
    30558, -- Glimmering Fire Opal
    30559, -- Etched Fire Opal
    30560, -- Rune Covered Chrysoprase
    30563, -- Regal Tanzanite
    30564, -- Shining Fire Opal
    30565, -- Assassin's Fire Opal
    30566, -- Defender's Tanzanite
    30571, -- Don Rodrigo's Heart
    30572, -- Imperial Tanzanite
    30573, -- Mysterious Fire Opal
    30574, -- Brutal Tanzanite
    30575, -- Nimble Fire Opal
    30581, -- Durable Fire Opal
    30582, -- Deadly Fire Opal
    30583, -- Timeless Chrysoprase
    30584, -- Enscribed Fire Opal
    30585, -- Glistening Fire Opal
    30586, -- Seer's Chrysoprase
    30587, -- Champion's Fire Opal
    30588, -- Potent Fire Opal
    30589, -- Dazzling Chrysoprase
    30590, -- Enduring Chrysoprase
    30591, -- Empowered Fire Opal
    30592, -- Steady Chrysoprase
    30593, -- Iridescent Fire Opal
    30594, -- Effulgent Chrysoprase
    30598, -- Don Amancio's Heart
    30600, -- Fluorescent Tanzanite
    30601, -- Beaming Fire Opal
    30602, -- Jagged Chrysoprase
    30603, -- Royal Tanzanite
    30604, -- Resplendent Fire Opal
    30605, -- Vivid Chrysoprase
    30606, -- Lambent Chrysoprase
    30607, -- Splendid Fire Opal
    30608, -- Radiant Chrysoprase
    31116, -- Infused Amethyst
    31117, -- Soothing Amethyst
    31118, -- Pulsing Amethyst
    31860, -- Great Golden Draenite
    31861, -- Great Dawnstone
    31862, -- Balanced Shadow Draenite
    31863, -- Balanced Nightseye
    31864, -- Infused Shadow Draenite
    31865, -- Infused Nightseye
    31866, -- Veiled Flame Spessarite
    31867, -- Veiled Noble Topaz
    31868, -- Wicked Noble Topaz
    31869, -- Wicked Flame Spessarite
    32193, -- Bold Crimson Spinel
    32194, -- Delicate Crimson Spinel
    32195, -- Teardrop Crimson Spinel
    32196, -- Runed Crimson Spinel
    32197, -- Bright Crimson Spinel
    32198, -- Subtle Crimson Spinel
    32199, -- Flashing Crimson Spinel
    32200, -- Solid Empyrean Sapphire
    32201, -- Sparkling Empyrean Sapphire
    32202, -- Lustrous Empyrean Sapphire
    32203, -- Stormy Empyrean Sapphire
    32204, -- Brilliant Lionseye
    32205, -- Smooth Lionseye
    32206, -- Rigid Lionseye
    32207, -- Gleaming Lionseye
    32208, -- Thick Lionseye
    32209, -- Mystic Lionseye
    32210, -- Great Lionseye
    32211, -- Sovereign Shadowsong Amethyst
    32212, -- Shifting Shadowsong Amethyst
    32213, -- Balanced Shadowsong Amethyst
    32214, -- Infused Shadowsong Amethyst
    32215, -- Glowing Shadowsong Amethyst
    32216, -- Royal Shadowsong Amethyst
    32217, -- Inscribed Pyrestone
    32218, -- Potent Pyrestone
    32219, -- Luminous Pyrestone
    32220, -- Glinting Pyrestone
    32221, -- Veiled Pyrestone
    32222, -- Wicked Pyrestone
    32223, -- Enduring Seaspray Emerald
    32224, -- Radiant Seaspray Emerald
    32225, -- Dazzling Seaspray Emerald
    32226, -- Jagged Seaspray Emerald
    32227, -- Crimson Spinel
    32228, -- Empyrean Sapphire
    32229, -- Lionseye
    32230, -- Shadowsong Amethyst
    32231, -- Pyrestone
    32249, -- Seaspray Emerald
    32409, -- Relentless Earthstorm Diamond
    32410, -- Thundering Skyfire Diamond
    32634, -- Unstable Amethyst
    32635, -- Unstable Peridot
    32636, -- Unstable Sapphire
    32637, -- Unstable Citrine
    32638, -- Unstable Topaz
    32639, -- Unstable Talasite
    32640, -- Potent Unstable Diamond
    32641, -- Imbued Unstable Diamond
    32735, -- Radiant Spencerite
    32833, -- Purified Jaggal Pearl
    32836, -- Purified Shadow Pearl
    33060, -- Soulbound Test Gem
    33131, -- Crimson Sun
    33132, -- Delicate Fire Ruby
    33133, -- Don Julio's Heart
    33134, -- Kailee's Rose
    33135, -- Falling Star
    33137, -- Sparkling Falling Star
    33138, -- Mystic Bladestone
    33139, -- Brilliant Bladestone
    33140, -- Blood of Amber
    33141, -- Great Bladestone
    33142, -- Rigid Bladestone
    33143, -- Stone of Blades
    33144, -- Facet of Eternity
    33782, -- Steady Talasite
    34142, -- Infinite Sphere
    34143, -- Chromatic Sphere
    34220, -- Chaotic Skyfire Diamond
    34256, -- Charmed Amani Jewel
    34627, -- Heavy Tonk Armor
    34831, -- Eye of the Sea
    35315, -- Quick Dawnstone
    35316, -- Reckless Noble Topaz
    35318, -- Forceful Talasite
    35487, -- Bright Crimson Spinel
    35488, -- Runed Crimson Spinel
    35489, -- Teardrop Crimson Spinel
    35501, -- Eternal Earthstorm Diamond
    35503, -- Ember Skyfire Diamond
    35707, -- Regal Nightseye
    35758, -- Steady Seaspray Emerald
    35759, -- Forceful Seaspray Emerald
    35760, -- Reckless Pyrestone
    35761, -- Quick Lionseye
    36766, -- Bright Dragon's Eye
    36767, -- Solid Dragon's Eye
    36783, -- Northsea Pearl
    36784, -- Siren's Tear
    36917, -- Bloodstone
    36918, -- Scarlet Ruby
    36920, -- Sun Crystal
    36921, -- Autumn's Glow
    36923, -- Chalcedony
    36924, -- Sky Sapphire
    36926, -- Shadow Crystal
    36927, -- Twilight Opal
    36929, -- Huge Citrine
    36930, -- Monarch Topaz
    36932, -- Dark Jade
    36933, -- Forest Emerald
    37430, -- Solid Sky Sapphire (Unused)
    37503, -- Purified Shadowsong Amethyst
    38292, -- Test Living Ruby
    38498, -- QA Test Blank Purple Gem
    38538, -- Riding Crop
    38545, -- Bold Ornate Ruby
    38546, -- Gleaming Ornate Dawnstone
    38547, -- Inscribed Ornate Topaz
    38548, -- Potent Ornate Topaz
    38549, -- Runed Ornate Ruby
    38550, -- Smooth Ornate Dawnstone

}

Goals.EnchantSearchList = Goals.EnchantSearchList or {
    { id = 41, name = "Enchant Bracer - Minor Health", spellId = 7418 },
    { id = 41, name = "Enchant Chest - Minor Health", spellId = 7420 },
    { id = 44, name = "Enchant Chest - Minor Absorption", spellId = 7426 },
    { id = 924, name = "Enchant Bracer - Minor Deflection", spellId = 7428 },
    { id = 24, name = "Enchant Chest - Minor Mana", spellId = 7443 },
    { id = 65, name = "Enchant Cloak - Minor Resistance", spellId = 7454 },
    { id = 66, name = "Enchant Bracer - Minor Stamina", spellId = 7457 },
    { id = 241, name = "Enchant 2H Weapon - Minor Impact", spellId = 7745 },
    { id = 242, name = "Enchant Chest - Lesser Health", spellId = 7748 },
    { id = 243, name = "Enchant Bracer - Minor Spirit", spellId = 7766 },
    { id = 783, name = "Enchant Cloak - Minor Protection", spellId = 7771 },
    { id = 246, name = "Enchant Chest - Lesser Mana", spellId = 7776 },
    { id = 247, name = "Enchant Bracer - Minor Agility", spellId = 7779 },
    { id = 248, name = "Enchant Bracer - Minor Strength", spellId = 7782 },
    { id = 249, name = "Enchant Weapon - Minor Beastslayer", spellId = 7786 },
    { id = 250, name = "Enchant Weapon - Minor Striking", spellId = 7788 },
    { id = 723, name = "Enchant 2H Weapon - Lesser Intellect", spellId = 7793 },
    { id = 254, name = "Enchant Chest - Health", spellId = 7857 },
    { id = 255, name = "Enchant Bracer - Lesser Spirit", spellId = 7859 },
    { id = 256, name = "Enchant Cloak - Lesser Fire Resistance", spellId = 7861 },
    { id = 66, name = "Enchant Boots - Minor Stamina", spellId = 7863 },
    { id = 247, name = "Enchant Boots - Minor Agility", spellId = 7867 },
    { id = 66, name = "Enchant Shield - Minor Stamina", spellId = 13378 },
    { id = 255, name = "Enchant 2H Weapon - Lesser Spirit", spellId = 13380 },
    { id = 247, name = "Enchant Cloak - Minor Agility", spellId = 13419 },
    { id = 744, name = "Enchant Cloak - Lesser Protection", spellId = 13421 },
    { id = 848, name = "Enchant Shield - Lesser Protection", spellId = 13464 },
    { id = 255, name = "Enchant Shield - Lesser Spirit", spellId = 13485 },
    { id = 724, name = "Enchant Bracer - Lesser Stamina", spellId = 13501 },
    { id = 241, name = "Enchant Weapon - Lesser Striking", spellId = 13503 },
    { id = 804, name = "Enchant Cloak - Lesser Shadow Resistance", spellId = 13522 },
    { id = 943, name = "Enchant 2H Weapon - Lesser Impact", spellId = 13529 },
    { id = 823, name = "Enchant Bracer - Lesser Strength", spellId = 13536 },
    { id = 63, name = "Enchant Chest - Lesser Absorption", spellId = 13538 },
    { id = 843, name = "Enchant Chest - Mana", spellId = 13607 },
    { id = 844, name = "Enchant Gloves - Mining", spellId = 13612 },
    { id = 845, name = "Enchant Gloves - Herbalism", spellId = 13617 },
    { id = 2603, name = "Enchant Gloves - Fishing", spellId = 13620 },
    { id = 723, name = "Enchant Bracer - Lesser Intellect", spellId = 13622 },
    { id = 847, name = "Enchant Chest - Minor Stats", spellId = 13626 },
    { id = 724, name = "Enchant Shield - Lesser Stamina", spellId = 13631 },
    { id = 848, name = "Enchant Cloak - Defense", spellId = 13635 },
    { id = 849, name = "Enchant Boots - Lesser Agility", spellId = 13637 },
    { id = 850, name = "Enchant Chest - Greater Health", spellId = 13640 },
    { id = 851, name = "Enchant Bracer - Spirit", spellId = 13642 },
    { id = 724, name = "Enchant Boots - Lesser Stamina", spellId = 13644 },
    { id = 925, name = "Enchant Bracer - Lesser Deflection", spellId = 13646 },
    { id = 852, name = "Enchant Bracer - Stamina", spellId = 13648 },
    { id = 853, name = "Enchant Weapon - Lesser Beastslayer", spellId = 13653 },
    { id = 854, name = "Enchant Weapon - Lesser Elemental Slayer", spellId = 13655 },
    { id = 2463, name = "Enchant Cloak - Fire Resistance", spellId = 13657 },
    { id = 851, name = "Enchant Shield - Spirit", spellId = 13659 },
    { id = 856, name = "Enchant Bracer - Strength", spellId = 13661 },
    { id = 857, name = "Enchant Chest - Greater Mana", spellId = 13663 },
    { id = 255, name = "Enchant Boots - Lesser Spirit", spellId = 13687 },
    { id = 863, name = "Enchant Shield - Lesser Block", spellId = 13689 },
    { id = 943, name = "Enchant Weapon - Striking", spellId = 13693 },
    { id = 1897, name = "Enchant 2H Weapon - Impact", spellId = 13695 },
    { id = 865, name = "Enchant Gloves - Skinning", spellId = 13698 },
    { id = 866, name = "Enchant Chest - Lesser Stats", spellId = 13700 },
    { id = 884, name = "Enchant Cloak - Greater Defense", spellId = 13746 },
    { id = 903, name = "Enchant Cloak - Resistance", spellId = 13794 },
    { id = 904, name = "Enchant Gloves - Agility", spellId = 13815 },
    { id = 852, name = "Enchant Shield - Stamina", spellId = 13817 },
    { id = 905, name = "Enchant Bracer - Intellect", spellId = 13822 },
    { id = 852, name = "Enchant Boots - Stamina", spellId = 13836 },
    { id = 906, name = "Enchant Gloves - Advanced Mining", spellId = 13841 },
    { id = 907, name = "Enchant Bracer - Greater Spirit", spellId = 13846 },
    { id = 908, name = "Enchant Chest - Superior Health", spellId = 13858 },
    { id = 909, name = "Enchant Gloves - Advanced Herbalism", spellId = 13868 },
    { id = 849, name = "Enchant Cloak - Lesser Agility", spellId = 13882 },
    { id = 856, name = "Enchant Gloves - Strength", spellId = 13887 },
    { id = 911, name = "Enchant Boots - Minor Speed", spellId = 13890 },
    { id = 803, name = "Enchant Weapon - Fiery Weapon", spellId = 13898 },
    { id = 907, name = "Enchant Shield - Greater Spirit", spellId = 13905 },
    { id = 912, name = "Enchant Weapon - Demonslaying", spellId = 13915 },
    { id = 913, name = "Enchant Chest - Superior Mana", spellId = 13917 },
    { id = 923, name = "Enchant Bracer - Deflection", spellId = 13931 },
    { id = 926, name = "Enchant Shield - Frost Resistance", spellId = 13933 },
    { id = 904, name = "Enchant Boots - Agility", spellId = 13935 },
    { id = 963, name = "Enchant 2H Weapon - Greater Impact", spellId = 13937 },
    { id = 927, name = "Enchant Bracer - Greater Strength", spellId = 13939 },
    { id = 928, name = "Enchant Chest - Stats", spellId = 13941 },
    { id = 805, name = "Enchant Weapon - Greater Striking", spellId = 13943 },
    { id = 929, name = "Enchant Bracer - Greater Stamina", spellId = 13945 },
    { id = 930, name = "Enchant Gloves - Riding Skill", spellId = 13947 },
    { id = 931, name = "Enchant Gloves - Minor Haste", spellId = 13948 },
    { id = 1883, name = "Enchant Bracer - Greater Intellect", spellId = 20008 },
    { id = 1884, name = "Enchant Bracer - Superior Spirit", spellId = 20009 },
    { id = 1885, name = "Enchant Bracer - Superior Strength", spellId = 20010 },
    { id = 1886, name = "Enchant Bracer - Superior Stamina", spellId = 20011 },
    { id = 1887, name = "Enchant Gloves - Greater Agility", spellId = 20012 },
    { id = 927, name = "Enchant Gloves - Greater Strength", spellId = 20013 },
    { id = 1888, name = "Enchant Cloak - Greater Resistance", spellId = 20014 },
    { id = 1889, name = "Enchant Cloak - Superior Defense", spellId = 20015 },
    { id = 1890, name = "Enchant Shield - Vitality", spellId = 20016 },
    { id = 929, name = "Enchant Shield - Greater Stamina", spellId = 20017 },
    { id = 929, name = "Enchant Boots - Greater Stamina", spellId = 20020 },
    { id = 1887, name = "Enchant Boots - Greater Agility", spellId = 20023 },
    { id = 851, name = "Enchant Boots - Spirit", spellId = 20024 },
    { id = 1891, name = "Enchant Chest - Greater Stats", spellId = 20025 },
    { id = 1892, name = "Enchant Chest - Major Health", spellId = 20026 },
    { id = 1893, name = "Enchant Chest - Major Mana", spellId = 20028 },
    { id = 1894, name = "Enchant Weapon - Icy Chill", spellId = 20029 },
    { id = 1896, name = "Enchant 2H Weapon - Superior Impact", spellId = 20030 },
    { id = 1897, name = "Enchant Weapon - Superior Striking", spellId = 20031 },
    { id = 1898, name = "Enchant Weapon - Lifestealing", spellId = 20032 },
    { id = 1899, name = "Enchant Weapon - Unholy Weapon", spellId = 20033 },
    { id = 1900, name = "Enchant Weapon - Crusader", spellId = 20034 },
    { id = 1903, name = "Enchant 2H Weapon - Major Spirit", spellId = 20035 },
    { id = 1904, name = "Enchant 2H Weapon - Major Intellect", spellId = 20036 },
    { id = 2443, name = "Enchant Weapon - Winter's Might", spellId = 21931 },
    { id = 2504, name = "Enchant Weapon - Spellpower", spellId = 22749 },
    { id = 2505, name = "Enchant Weapon - Healing Power", spellId = 22750 },
    { id = 2563, name = "Enchant Weapon - Strength", spellId = 23799 },
    { id = 2564, name = "Enchant Weapon - Agility", spellId = 23800 },
    { id = 2565, name = "Enchant Bracer - Mana Regeneration", spellId = 23801 },
    { id = 2650, name = "Enchant Bracer - Healing Power", spellId = 23802 },
    { id = 2567, name = "Enchant Weapon - Mighty Spirit", spellId = 23803 },
    { id = 2568, name = "Enchant Weapon - Mighty Intellect", spellId = 23804 },
    { id = 2613, name = "Enchant Gloves - Threat", spellId = 25072 },
    { id = 2614, name = "Enchant Gloves - Shadow Power", spellId = 25073 },
    { id = 2615, name = "Enchant Gloves - Frost Power", spellId = 25074 },
    { id = 2616, name = "Enchant Gloves - Fire Power", spellId = 25078 },
    { id = 2617, name = "Enchant Gloves - Healing Power", spellId = 25079 },
    { id = 2564, name = "Enchant Gloves - Superior Agility", spellId = 25080 },
    { id = 2619, name = "Enchant Cloak - Greater Fire Resistance", spellId = 25081 },
    { id = 2620, name = "Enchant Cloak - Greater Nature Resistance", spellId = 25082 },
    { id = 910, name = "Enchant Cloak - Stealth", spellId = 25083 },
    { id = 2621, name = "Enchant Cloak - Subtlety", spellId = 25084 },
    { id = 2622, name = "Enchant Cloak - Dodge", spellId = 25086 },
    { id = 2646, name = "Enchant 2H Weapon - Agility", spellId = 27837 },
    { id = 2647, name = "Enchant Bracer - Brawn", spellId = 27899 },
    { id = 1891, name = "Enchant Bracer - Stats", spellId = 27905 },
    { id = 2648, name = "Enchant Bracer - Major Defense", spellId = 27906 },
    { id = 2650, name = "Enchant Bracer - Superior Healing", spellId = 27911 },
    { id = 2679, name = "Enchant Bracer - Restore Mana Prime", spellId = 27913 },
    { id = 2649, name = "Enchant Bracer - Fortitude", spellId = 27914 },
    { id = 2650, name = "Enchant Bracer - Spellpower", spellId = 27917 },
    { id = 2929, name = "Enchant Ring - Striking", spellId = 27920 },
    { id = 2928, name = "Enchant Ring - Spellpower", spellId = 27924 },
    { id = 2930, name = "Enchant Ring - Healing Power", spellId = 27926 },
    { id = 2931, name = "Enchant Ring - Stats", spellId = 27927 },
    { id = 2653, name = "Enchant Shield - Tough Shield", spellId = 27944 },
    { id = 2654, name = "Enchant Shield - Intellect", spellId = 27945 },
    { id = 2655, name = "Enchant Shield - Shield Block", spellId = 27946 },
    { id = 1888, name = "Enchant Shield - Resistance", spellId = 27947 },
    { id = 2656, name = "Enchant Boots - Vitality", spellId = 27948 },
    { id = 2649, name = "Enchant Boots - Fortitude", spellId = 27950 },
    { id = 2657, name = "Enchant Boots - Dexterity", spellId = 27951 },
    { id = 2658, name = "Enchant Boots - Surefooted", spellId = 27954 },
    { id = 2659, name = "Enchant Chest - Exceptional Health", spellId = 27957 },
    { id = 3233, name = "Enchant Chest - Exceptional Mana", spellId = 27958 },
    { id = 2661, name = "Enchant Chest - Exceptional Stats", spellId = 27960 },
    { id = 2662, name = "Enchant Cloak - Major Armor", spellId = 27961 },
    { id = 2664, name = "Enchant Cloak - Major Resistance", spellId = 27962 },
    { id = 1898, name = "Enchant Weapon - Major Spirit", spellId = 27964 },
    { id = 963, name = "Enchant Weapon - Major Striking", spellId = 27967 },
    { id = 2666, name = "Enchant Weapon - Major Intellect", spellId = 27968 },
    { id = 2667, name = "Enchant 2H Weapon - Savagery", spellId = 27971 },
    { id = 2668, name = "Enchant Weapon - Potency", spellId = 27972 },
    { id = 2669, name = "Enchant Weapon - Major Spellpower", spellId = 27975 },
    { id = 2670, name = "Enchant 2H Weapon - Major Agility", spellId = 27977 },
    { id = 2671, name = "Enchant Weapon - Sunfire", spellId = 27981 },
    { id = 2672, name = "Enchant Weapon - Soulfrost", spellId = 27982 },
    { id = 2673, name = "Enchant Weapon - Mongoose", spellId = 27984 },
    { id = 2674, name = "Enchant Weapon - Spellsurge", spellId = 28003 },
    { id = 2675, name = "Enchant Weapon - Battlemaster", spellId = 28004 },
    { id = 1144, name = "Enchant Chest - Major Spirit", spellId = 33990 },
    { id = 3150, name = "Enchant Chest - Restore Mana Prime", spellId = 33991 },
    { id = 2933, name = "Enchant Chest - Major Resilience", spellId = 33992 },
    { id = 2934, name = "Enchant Gloves - Blasting", spellId = 33993 },
    { id = 2935, name = "Enchant Gloves - Precise Strikes", spellId = 33994 },
    { id = 684, name = "Enchant Gloves - Major Strength", spellId = 33995 },
    { id = 1594, name = "Enchant Gloves - Assault", spellId = 33996 },
    { id = 2937, name = "Enchant Gloves - Major Spellpower", spellId = 33997 },
    { id = 2322, name = "Enchant Gloves - Major Healing", spellId = 33999 },
    { id = 369, name = "Enchant Bracer - Major Intellect", spellId = 34001 },
    { id = 1593, name = "Enchant Bracer - Assault", spellId = 34002 },
    { id = 2938, name = "Enchant Cloak - Spell Penetration", spellId = 34003 },
    { id = 368, name = "Enchant Cloak - Greater Agility", spellId = 34004 },
    { id = 1257, name = "Enchant Cloak - Greater Arcane Resistance", spellId = 34005 },
    { id = 1441, name = "Enchant Cloak - Greater Shadow Resistance", spellId = 34006 },
    { id = 2939, name = "Enchant Boots - Cat's Swiftness", spellId = 34007 },
    { id = 2940, name = "Enchant Boots - Boar's Speed", spellId = 34008 },
    { id = 1071, name = "Enchant Shield - Major Stamina", spellId = 34009 },
    { id = 3846, name = "Enchant Weapon - Major Healing", spellId = 34010 },
    { id = 3222, name = "Enchant Weapon - Greater Agility", spellId = 42620 },
    { id = 3225, name = "Enchant Weapon - Executioner", spellId = 42974 },
    { id = 3229, name = "Enchant Shield - Resilience", spellId = 44383 },
    { id = 3230, name = "Enchant Cloak - Superior Frost Resistance", spellId = 44483 },
    { id = 3231, name = "Enchant Gloves - Expertise", spellId = 44484 },
    { id = 3234, name = "Enchant Gloves - Precision", spellId = 44488 },
    { id = 1952, name = "Enchant Shield - Defense", spellId = 44489 },
    { id = 3236, name = "Enchant Chest - Mighty Health", spellId = 44492 },
    { id = 1400, name = "Enchant Cloak - Superior Nature Resistance", spellId = 44494 },
    { id = 983, name = "Enchant Cloak - Superior Agility", spellId = 44500 },
    { id = 3238, name = "Enchant Gloves - Gatherer", spellId = 44506 },
    { id = 1147, name = "Enchant Boots - Greater Spirit", spellId = 44508 },
    { id = 2381, name = "Enchant Chest - Greater Mana Restoration", spellId = 44509 },
    { id = 3844, name = "Enchant Weapon - Exceptional Spirit", spellId = 44510 },
    { id = 3829, name = "Enchant Gloves - Greater Assault", spellId = 44513 },
    { id = 3239, name = "Enchant Weapon - Icebreaker", spellId = 44524 },
    { id = 1075, name = "Enchant Boots - Greater Fortitude", spellId = 44528 },
    { id = 3222, name = "Enchant Gloves - Major Agility", spellId = 44529 },
    { id = 1119, name = "Enchant Bracers - Exceptional Intellect", spellId = 44555 },
    { id = 1354, name = "Enchant Cloak - Superior Fire Resistance", spellId = 44556 },
    { id = 3845, name = "Enchant Bracers - Greater Assault", spellId = 44575 },
    { id = 3241, name = "Enchant Weapon - Lifeward", spellId = 44576 },
    { id = 3243, name = "Enchant Cloak - Spell Piercing", spellId = 44582 },
    { id = 3244, name = "Enchant Boots - Greater Vitality", spellId = 44584 },
    { id = 3245, name = "Enchant Chest - Exceptional Resilience", spellId = 44588 },
    { id = 983, name = "Enchant Boots - Superior Agility", spellId = 44589 },
    { id = 1446, name = "Enchant Cloak - Superior Shadow Resistance", spellId = 44590 },
    { id = 1951, name = "Enchant Cloak - Titanweave", spellId = 44591 },
    { id = 3246, name = "Enchant Gloves - Exceptional Spellpower", spellId = 44592 },
    { id = 1147, name = "Enchant Bracers - Major Spirit", spellId = 44593 },
    { id = 3247, name = "Enchant 2H Weapon - Scourgebane", spellId = 44595 },
    { id = 1262, name = "Enchant Cloak - Superior Arcane Resistance", spellId = 44596 },
    { id = 3231, name = "Enchant Bracers - Expertise", spellId = 44598 },
    { id = 3249, name = "Enchant Gloves - Greater Blasting", spellId = 44612 },
    { id = 2661, name = "Enchant Bracers - Greater Stats", spellId = 44616 },
    { id = 3251, name = "Enchant Weapon - Giant Slayer", spellId = 44621 },
    { id = 3252, name = "Enchant Chest - Super Stats", spellId = 44623 },
    { id = 3253, name = "Enchant Gloves - Armsman", spellId = 44625 },
    { id = 3830, name = "Enchant Weapon - Exceptional Spellpower", spellId = 44629 },
    { id = 3828, name = "Enchant 2H Weapon - Greater Savagery", spellId = 44630 },
    { id = 3256, name = "Enchant Cloak - Shadow Armor", spellId = 44631 },
    { id = 1103, name = "Enchant Weapon - Exceptional Agility", spellId = 44633 },
    { id = 2326, name = "Enchant Bracers - Greater Spellpower", spellId = 44635 },
    { id = 3840, name = "Enchant Ring - Greater Spellpower", spellId = 44636 },
    { id = 3839, name = "Enchant Ring - Assault", spellId = 44645 },
    { id = 1951, name = "Enchant Chest - Defense", spellId = 46594 },
    { id = 2648, name = "Enchant Cloak - Steelweave", spellId = 47051 },
    { id = 3294, name = "Enchant Cloak - Mighty Armor", spellId = 47672 },
    { id = 1953, name = "Enchant Chest - Greater Defense", spellId = 47766 },
    { id = 3831, name = "Enchant Cloak - Greater Speed", spellId = 47898 },
    { id = 3296, name = "Enchant Cloak - Wisdom", spellId = 47899 },
    { id = 3297, name = "Enchant Chest - Super Health", spellId = 47900 },
    { id = 3232, name = "Enchant Boots - Tuskarr's Vitality", spellId = 47901 },
    { id = 3788, name = "Enchant Weapon - Accuracy", spellId = 59619 },
    { id = 3789, name = "Enchant Weapon - Berserking", spellId = 59621 },
    { id = 3790, name = "Enchant Weapon - Black Magic", spellId = 59625 },
    { id = 3791, name = "Enchant Ring - Stamina", spellId = 59636 },
    { id = 3824, name = "Enchant Boots - Assault", spellId = 60606 },
    { id = 3825, name = "Enchant Cloak - Speed", spellId = 60609 },
    { id = 1600, name = "Enchant Bracers - Striking", spellId = 60616 },
    { id = 1606, name = "Enchant Weapon - Greater Potency", spellId = 60621 },
    { id = 3826, name = "Enchant Boots - Icewalker", spellId = 60623 },
    { id = 1128, name = "Enchant Shield - Greater Intellect", spellId = 60653 },
    { id = 1099, name = "Enchant Cloak - Major Agility", spellId = 60663 },
    { id = 1603, name = "Enchant Gloves - Crusher", spellId = 60668 },
    { id = 3827, name = "Enchant 2H Weapon - Massacre", spellId = 60691 },
    { id = 3832, name = "Enchant Chest - Powerful Stats", spellId = 60692 },
    { id = 3833, name = "Enchant Weapon - Superior Potency", spellId = 60707 },
    { id = 3834, name = "Enchant Weapon - Mighty Spellpower", spellId = 60714 },
    { id = 1597, name = "Enchant Boots - Greater Assault", spellId = 60763 },
    { id = 2332, name = "Enchant Bracers - Superior Spellpower", spellId = 60767 },
    { id = 3850, name = "Enchant Bracers - Major Stamina", spellId = 62256 },
    { id = 3851, name = "Enchant Weapon - Titanguard", spellId = 62257 },
    { id = 3854, name = "Enchant Staff - Greater Spellpower", spellId = 62948 },
    { id = 3855, name = "Enchant Staff - Spellpower", spellId = 62959 },
    { id = 3858, name = "Enchant Boots - Lesser Accuracy", spellId = 63746 },
    { id = 846, name = "Enchant Gloves - Angler", spellId = 71692 },

    -- Head enchants (Arcanum)
    { id = 3006, name = "Arcanum of Arcane Warding", spellId = 35455, slot = "HEAD" },
    { id = 3819, name = "Arcanum of Blissful Mending", spellId = 59960, slot = "HEAD" },
    { id = 3820, name = "Arcanum of Burning Mysteries", spellId = 59970, slot = "HEAD" },
    { id = 3095, name = "Arcanum of Chromatic Warding", spellId = 37889, slot = "HEAD" },
    { id = 3796, name = "Arcanum of Dominance", spellId = 59778, slot = "HEAD" },
    { id = 3797, name = "Arcanum of Dominance", spellId = 59784, slot = "HEAD" },
    { id = 3003, name = "Arcanum of Ferocity", spellId = 35452, slot = "HEAD" },
    { id = 3007, name = "Arcanum of Fire Warding", spellId = 35456, slot = "HEAD" },
    { id = 2544, name = "Arcanum of Focus", spellId = 22844, slot = "HEAD" },
    { id = 3008, name = "Arcanum of Frost Warding", spellId = 35457, slot = "HEAD" },
    { id = 3005, name = "Arcanum of Nature Warding", spellId = 35454, slot = "HEAD" },
    { id = 3002, name = "Arcanum of Power", spellId = 35447, slot = "HEAD" },
    { id = 2545, name = "Arcanum of Protection", spellId = 22846, slot = "HEAD" },
    { id = 2543, name = "Arcanum of Rapidity", spellId = 22840, slot = "HEAD" },
    { id = 3001, name = "Arcanum of Renewal", spellId = 35445, slot = "HEAD" },
    { id = 3009, name = "Arcanum of Shadow Warding", spellId = 35458, slot = "HEAD" },
    { id = 3817, name = "Arcanum of Torment", spellId = 59954, slot = "HEAD" },
    { id = 3813, name = "Arcanum of Toxic Warding", spellId = 59945, slot = "HEAD" },
    { id = 3795, name = "Arcanum of Triumph", spellId = 59777, slot = "HEAD" },
    { id = 2999, name = "Arcanum of the Defender", spellId = 35443, slot = "HEAD" },
    { id = 3815, name = "Arcanum of the Eclipsed Moon", spellId = 59947, slot = "HEAD" },
    { id = 3816, name = "Arcanum of the Flame's Soul", spellId = 59948, slot = "HEAD" },
    { id = 3814, name = "Arcanum of the Fleeing Shadow", spellId = 59946, slot = "HEAD" },
    { id = 3812, name = "Arcanum of the Frosty Soul", spellId = 59944, slot = "HEAD" },
    
    { id = 3004, name = "Arcanum of the Gladiator", spellId = 35453, slot = "HEAD" },
    { id = 3096, name = "Arcanum of the Outcast", spellId = 37891, slot = "HEAD" },
    { id = 3842, name = "Arcanum of the Savage Gladiator", spellId = 61271, slot = "HEAD" },
    { id = 3818, name = "Arcanum of the Stalwart Protector", spellId = 59955, slot = "HEAD" },
    -- Shoulder enchants (Inscription)
    { id = 2982, name = "Greater Inscription of Discipline", spellId = 35406, slot = "SHOULDER" },
    { id = 2980, name = "Greater Inscription of Faith", spellId = 35404, slot = "SHOULDER" },
    { id = 2986, name = "Greater Inscription of Vengeance", spellId = 35417, slot = "SHOULDER" },
    { id = 2978, name = "Greater Inscription of Warding", spellId = 35402, slot = "SHOULDER" },
    { id = 3808, name = "Greater Inscription of the Axe", spellId = 59934, slot = "SHOULDER" },
    { id = 2997, name = "Greater Inscription of the Blade", spellId = 35439, slot = "SHOULDER" },
    { id = 3809, name = "Greater Inscription of the Crag", spellId = 59936, slot = "SHOULDER" },
    { id = 3852, name = "Greater Inscription of the Gladiator", spellId = 62384, slot = "SHOULDER" },
    { id = 2991, name = "Greater Inscription of the Knight", spellId = 35433, slot = "SHOULDER" },
    { id = 2993, name = "Greater Inscription of the Oracle", spellId = 35435, slot = "SHOULDER" },
    { id = 2995, name = "Greater Inscription of the Orb", spellId = 35437, slot = "SHOULDER" },
    { id = 3811, name = "Greater Inscription of the Pinnacle", spellId = 59941, slot = "SHOULDER" },
    { id = 3810, name = "Greater Inscription of the Storm", spellId = 59937, slot = "SHOULDER" },
    { id = 2981, name = "Inscription of Discipline", spellId = 35405, slot = "SHOULDER" },
    { id = 3794, name = "Inscription of Dominance", spellId = 59773, slot = "SHOULDER" },
    { id = 2998, name = "Inscription of Endurance", spellId = 35441, slot = "SHOULDER" },
    { id = 2979, name = "Inscription of Faith", spellId = 35403, slot = "SHOULDER" },
    { id = 3775, name = "Inscription of High Discipline", spellId = 58126, slot = "SHOULDER" },
    { id = 3777, name = "Inscription of Kings", spellId = 58129, slot = "SHOULDER" },
    { id = 3793, name = "Inscription of Triumph", spellId = 59771, slot = "SHOULDER" },
    { id = 2983, name = "Inscription of Vengeance", spellId = 35407, slot = "SHOULDER" },
    { id = 2977, name = "Inscription of Warding", spellId = 35355, slot = "SHOULDER" },
    { id = 3875, name = "Inscription of the Axe", spellId = 59929, slot = "SHOULDER" },
    { id = 2996, name = "Inscription of the Blade", spellId = 35438, slot = "SHOULDER" },
    { id = 3807, name = "Inscription of the Crag", spellId = 59928, slot = "SHOULDER" },
    { id = 3776, name = "Inscription of the Frostblade", spellId = 58128, slot = "SHOULDER" },
    { id = 2990, name = "Inscription of the Knight", spellId = 35432, slot = "SHOULDER" },
    { id = 2992, name = "Inscription of the Oracle", spellId = 35434, slot = "SHOULDER" },
    { id = 2994, name = "Inscription of the Orb", spellId = 35436, slot = "SHOULDER" },
    { id = 3876, name = "Inscription of the Pinnacle", spellId = 59932, slot = "SHOULDER" },
    { id = 3806, name = "Inscription of the Storm", spellId = 59927, slot = "SHOULDER" },
    { id = 3835, name = "Master's Inscription of the Axe", spellId = 61117, slot = "SHOULDER" },
    { id = 3836, name = "Master's Inscription of the Crag", spellId = 61118, slot = "SHOULDER" },
    { id = 3837, name = "Master's Inscription of the Pinnacle", spellId = 61119, slot = "SHOULDER" },
    { id = 3838, name = "Master's Inscription of the Storm", spellId = 61120, slot = "SHOULDER" },
    -- Leg enchants (Armor/Spellthread)
    { id = 3720, name = "Azure Spellthread", spellId = 55632, slot = "LEGS" },
    { id = 3719, name = "Brilliant Spellthread", spellId = 55631, slot = "LEGS" },
    { id = 3011, name = "Clefthide Leg Armor", spellId = 35489, slot = "LEGS" },
    { id = 3010, name = "Cobrahide Leg Armor", spellId = 35488, slot = "LEGS" },
    { id = 3331, name = "Dragonscale Leg Armor", spellId = 50911, slot = "LEGS" },
    { id = 3853, name = "Earthen Leg Armor", spellId = 62447, slot = "LEGS" },
    { id = 3822, name = "Frosthide Leg Armor", spellId = 60581, slot = "LEGS" },
    { id = 2746, name = "Golden Spellthread", spellId = 31370, slot = "LEGS" },
    { id = 3823, name = "Icescale Leg Armor", spellId = 60582, slot = "LEGS" },
    { id = 3325, name = "Jormungar Leg Armor", spellId = 50901, slot = "LEGS" },
    { id = 3873, name = "Master's Spellthread", spellId = 56034, slot = "LEGS" },
    { id = 2747, name = "Mystic Spellthread", spellId = 31371, slot = "LEGS" },
    { id = 3326, name = "Nerubian Leg Armor", spellId = 50902, slot = "LEGS" },
    { id = 3013, name = "Nethercleft Leg Armor", spellId = 35495, slot = "LEGS" },
    { id = 3012, name = "Nethercobra Leg Armor", spellId = 35490, slot = "LEGS" },
    { id = 2748, name = "Runic Spellthread", spellId = 31372, slot = "LEGS" },
    { id = 3872, name = "Sanctified Spellthread", spellId = 56039, slot = "LEGS" },
    { id = 3721, name = "Sapphire Spellthread", spellId = 55634, slot = "LEGS" },
    { id = 3718, name = "Shining Spellthread", spellId = 55630, slot = "LEGS" },
    { id = 2745, name = "Silver Spellthread", spellId = 31369, slot = "LEGS" },
    { id = 3332, name = "Wyrmscale Leg Armor", spellId = 50913, slot = "LEGS" },
}
