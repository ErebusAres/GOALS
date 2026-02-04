-- Goals: wishlistBuilds.lua
-- Build library for wishlist imports.
-- Format: each build contains metadata + items or a serialized wishlist string.
-- Items format: { slotKey = "HEAD", itemId = 0, enchantId = 0, gemIds = { } }
-- Notes:
-- - slotKey must match Goals.WishlistSlots.
-- - builds can store "wishlist" as a serialized WL1 string.
-- - builds can store "items" as a list of slot entries.
-- - builds can store "itemsBySlot" as a map keyed by slotKey.
-- - builds can store "wowhead" as a Wowhead gear planner URL or data string.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

local function normalizeString(value)
    if not value then
        return ""
    end
    return tostring(value)
end

local function normalizeTag(value)
    if not value then
        return nil
    end
    return tostring(value):lower()
end

local function normalizeTags(tags)
    if type(tags) ~= "table" then
        return {}
    end
    local normalized = {}
    for _, tag in ipairs(tags) do
        local value = normalizeTag(tag)
        if value and value ~= "" then
            table.insert(normalized, value)
        end
    end
    return normalized
end

Goals.WishlistBuildLibrary = Goals.WishlistBuildLibrary or {
    version = 1,
    notes = {
        "This library ships with full class/spec/tier builds sourced from wowtbc.gg phase lists and resolved to Wowhead item IDs.",
        "Builds are expected to be importable into the wishlist via slot item IDs.",
        "Alternate builds are included when sources disagree or when progression vs. end-phase lists differ.",
        "If a build uses wowhead data, store the URL or the raw data string in the wowhead field.",
        "Custom builds can be added in wishlistBuildCustom.lua and load alongside this library.",
    },
    sources = {
        {
            id = "wowtbc-gg-classic",
            name = "wowtbc.gg Classic BiS lists",
            url = "https://wowtbc.gg/classic",
            notes = "Phase-based Classic BiS lists (used for tier mapping).",
        },
        {
            id = "wowtbc-gg-tbc",
            name = "wowtbc.gg TBC BiS lists",
            url = "https://wowtbc.gg",
            notes = "Phase-based TBC BiS lists including Sunwell alternates.",
        },
        {
            id = "wowtbc-gg-wotlk",
            name = "wowtbc.gg WotLK BiS lists",
            url = "https://wowtbc.gg/wotlk",
            notes = "Phase-based WotLK BiS lists (T7-T10.5).",
        },
        {
            id = "wowhead",
            name = "Wowhead item database",
            url = "https://www.wowhead.com",
            notes = "Item ID resolution for wishlist imports.",
        },
        {
            id = "elitist-jerks",
            name = "Elitist Jerks 3.3.5 theorycraft archives",
            url = "https://web.archive.org/web/20100101000000*/elitistjerks.com",
            notes = "Historic theorycraft discussions for WotLK tiers.",
        },
        {
            id = "wowpedia-sets",
            name = "Wowpedia set and tier item pages",
            url = "https://wowpedia.fandom.com",
            notes = "Reference for tier set names and slot coverage.",
        },
        {
            id = "custom-classic",
            name = "Custom Classic builds",
            url = "",
            notes = "User-maintained builds in wishlistBuildCustom.lua.",
        },
        {
            id = "custom-tbc",
            name = "Custom TBC builds",
            url = "",
            notes = "User-maintained builds in wishlistBuildCustom.lua.",
        },
        {
            id = "custom-wotlk",
            name = "Custom WotLK builds",
            url = "",
            notes = "User-maintained builds in wishlistBuildCustom.lua.",
        },
    },
    tiers = {
        { id = "CLASSIC_PRE", label = "Classic Pre-Raid", minLevel = 60, maxLevel = 60, expansion = "Classic" },
        { id = "CLASSIC_T1", label = "Classic Tier 1", minLevel = 60, maxLevel = 60, expansion = "Classic" },
        { id = "CLASSIC_T2", label = "Classic Tier 2", minLevel = 60, maxLevel = 60, expansion = "Classic" },
        { id = "CLASSIC_T25", label = "Classic Tier 2.5", minLevel = 60, maxLevel = 60, expansion = "Classic" },
        { id = "CLASSIC_T3", label = "Classic Tier 3", minLevel = 60, maxLevel = 60, expansion = "Classic" },
        { id = "TBC_PRE", label = "TBC Pre-Raid", minLevel = 70, maxLevel = 70, expansion = "TBC" },
        { id = "TBC_T4", label = "TBC Tier 4", minLevel = 70, maxLevel = 70, expansion = "TBC" },
        { id = "TBC_T5", label = "TBC Tier 5", minLevel = 70, maxLevel = 70, expansion = "TBC" },
        { id = "TBC_T6", label = "TBC Tier 6", minLevel = 70, maxLevel = 70, expansion = "TBC" },
        { id = "WOTLK_PRE", label = "WotLK Pre-Raid", minLevel = 80, maxLevel = 80, expansion = "WotLK" },
        { id = "WOTLK_T7", label = "WotLK Tier 7", minLevel = 80, maxLevel = 80, expansion = "WotLK" },
        { id = "WOTLK_T8", label = "WotLK Tier 8", minLevel = 80, maxLevel = 80, expansion = "WotLK" },
        { id = "WOTLK_T9", label = "WotLK Tier 9", minLevel = 80, maxLevel = 80, expansion = "WotLK" },
        { id = "WOTLK_T10", label = "WotLK Tier 10", minLevel = 80, maxLevel = 80, expansion = "WotLK" },
    },
    builds = {},
}

local function ensureBuildsPopulated()
    local merged = {}
    if Goals.WishlistBuildData and Goals.WishlistBuildData.builds then
        for _, build in ipairs(Goals.WishlistBuildData.builds) do
            if not (build and build.disabled) then
                table.insert(merged, build)
            end
        end
    end
    if Goals.WishlistBuildCustomData and Goals.WishlistBuildCustomData.builds then
        for _, build in ipairs(Goals.WishlistBuildCustomData.builds) do
            if not (build and build.disabled) then
                table.insert(merged, build)
            end
        end
    end
    Goals.WishlistBuildLibrary.builds = merged
end

ensureBuildsPopulated()

local function findTierById(library, tierId)
    if not library or not library.tiers then
        return nil
    end
    for _, tier in ipairs(library.tiers) do
        if tier.id == tierId then
            return tier
        end
    end
    return nil
end

function Goals:GetWishlistBuildLibrary()
    if not self.WishlistBuildLibrary.builds or #self.WishlistBuildLibrary.builds == 0 then
        ensureBuildsPopulated()
    end
    return self.WishlistBuildLibrary
end

function Goals:GetWishlistBuildFilterOptions()
    local library = self:GetWishlistBuildLibrary() or {}
    local classSet, specSet, tierSet, tagSet = {}, {}, {}, {}
    for _, build in ipairs(library.builds or {}) do
        if build.class then
            classSet[normalizeString(build.class)] = true
        end
        if build.spec then
            specSet[normalizeString(build.spec)] = true
        end
        if build.tier then
            tierSet[normalizeString(build.tier)] = true
        end
        local tags = normalizeTags(build.tags)
        for _, tag in ipairs(tags) do
            tagSet[tag] = true
        end
    end
    local function sortedKeys(set)
        local list = {}
        for key in pairs(set) do
            table.insert(list, key)
        end
        table.sort(list)
        return list
    end
    return {
        classes = sortedKeys(classSet),
        specs = sortedKeys(specSet),
        tiers = sortedKeys(tierSet),
        tags = sortedKeys(tagSet),
    }
end

function Goals:GetPlayerClassId()
    if UnitClass then
        local _, classId = UnitClass("player")
        if classId and classId ~= "" then
            return classId
        end
    end
    return nil
end

function Goals:GetPlayerSpecName()
    if not GetTalentTabInfo then
        return nil
    end
    local bestName = nil
    local bestPoints = -1
    for tab = 1, 3 do
        local name, _, points = GetTalentTabInfo(tab)
        if points and points > bestPoints then
            bestPoints = points
            bestName = name
        end
    end
    return bestName
end

function Goals:GetPlayerLevel()
    if UnitLevel then
        return UnitLevel("player")
    end
    return nil
end

function Goals:GetSuggestedWishlistTier(level)
    local library = self:GetWishlistBuildLibrary() or {}
    local bestTier = nil
    local bestMin = nil
    local lv = tonumber(level) or 0
    for _, tier in ipairs(library.tiers or {}) do
        local minLevel = tonumber(tier.minLevel) or 0
        local maxLevel = tonumber(tier.maxLevel) or 999
        if lv >= minLevel and lv <= maxLevel then
            if not bestTier or minLevel >= (bestMin or 0) then
                bestTier = tier.id
                bestMin = minLevel
            end
        end
    end
    return bestTier
end

function Goals:GetEffectiveWishlistBuildFilters(settings)
    local filters = settings or {}
    local classFilter = normalizeString(filters.class or "AUTO")
    local specFilter = normalizeString(filters.spec or "AUTO")
    local tierFilter = normalizeString(filters.tier or "AUTO")
    local tagFilter = normalizeString(filters.tag or "ALL")
    local levelMode = normalizeString(filters.levelMode or "AUTO")
    local levelValue = tonumber(filters.level) or nil

    local detectedClass = self:GetPlayerClassId()
    local detectedSpec = self:GetPlayerSpecName()
    local detectedLevel = self:GetPlayerLevel()
    local detectedTier = self:GetSuggestedWishlistTier(detectedLevel)

    if classFilter == "AUTO" or classFilter == "" then
        classFilter = detectedClass or "ANY"
    end
    if specFilter == "AUTO" or specFilter == "" then
        specFilter = detectedSpec or "ANY"
    end
    if tierFilter == "AUTO" or tierFilter == "" then
        tierFilter = detectedTier or "ANY"
    end
    if levelMode == "AUTO" then
        levelValue = detectedLevel
    end

    return {
        class = classFilter,
        spec = specFilter,
        tier = tierFilter,
        tag = tagFilter,
        level = levelValue,
    }
end

local function buildHasTag(build, tag)
    if not tag or tag == "" or tag == "ALL" or tag == "all" then
        return true
    end
    local tags = normalizeTags(build.tags)
    for _, buildTag in ipairs(tags) do
        if buildTag == tag then
            return true
        end
    end
    return false
end

local function matchesFilter(value, filter)
    if not filter or filter == "" or filter == "ANY" then
        return true
    end
    return normalizeString(value) == filter
end

function Goals:FilterWishlistBuilds(filters)
    local library = self:GetWishlistBuildLibrary() or {}
    local results = {}
    for _, build in ipairs(library.builds or {}) do
        if matchesFilter(build.class, filters.class)
            and matchesFilter(build.spec, filters.spec)
            and matchesFilter(build.tier, filters.tier)
            and buildHasTag(build, normalizeTag(filters.tag)) then
            local level = tonumber(filters.level)
            if level then
                local buildMin = tonumber(build.minLevel)
                local buildMax = tonumber(build.maxLevel)
                local tier = findTierById(library, build.tier)
                local tierMin = tier and tonumber(tier.minLevel) or nil
                local tierMax = tier and tonumber(tier.maxLevel) or nil
                local minLevel = buildMin or tierMin or 0
                local maxLevel = buildMax or tierMax or 999
                if level >= minLevel and level <= maxLevel then
                    table.insert(results, build)
                end
            else
                table.insert(results, build)
            end
        end
    end
    table.sort(results, function(a, b)
        return normalizeString(a.name) < normalizeString(b.name)
    end)
    return results
end

local function normalizeItemId(rawId)
    local itemId = tonumber(rawId) or 0
    if itemId <= 0 then
        return 0, nil
    end
    -- Some imported lists use 6-digit IDs; trim to last 5 digits for 3.3.5a.
    if itemId > 100000 and itemId < 1000000 then
        local trimmed = itemId % 100000
        if trimmed > 0 then
            return trimmed, itemId
        end
    end
    return itemId, nil
end

local function normalizeGemIds(gemIds)
    if type(gemIds) ~= "table" then
        return {}
    end
    local normalized = {}
    for _, gemId in ipairs(gemIds) do
        local normalizedId = normalizeItemId(gemId)
        if normalizedId and normalizedId > 0 then
            table.insert(normalized, normalizedId)
        end
    end
    return normalized
end

local function addItemEntry(list, slotKey, entry)
    if not slotKey or slotKey == "" or not entry then
        return
    end
    local itemId, originalItemId = normalizeItemId(entry.itemId)
    if itemId <= 0 then
        return
    end
    local notes = entry.notes or ""
    if originalItemId and originalItemId ~= itemId then
        if notes ~= "" then
            notes = notes .. " "
        end
        notes = notes .. "(ID normalized from " .. tostring(originalItemId) .. ")"
    end
    table.insert(list, {
        slotKey = slotKey,
        itemId = itemId,
        enchantId = tonumber(entry.enchantId) or 0,
        gemIds = normalizeGemIds(entry.gemIds),
        notes = notes,
        source = entry.source or "Build",
    })
end

function Goals:ResolveWishlistBuildItems(build)
    if not build then
        return {}
    end
    if build.items and #build.items > 0 then
        local items = {}
        for _, entry in ipairs(build.items) do
            addItemEntry(items, entry.slotKey, entry)
        end
        return items
    end
    if build.itemsBySlot then
        local items = {}
        for slotKey, entry in pairs(build.itemsBySlot) do
            addItemEntry(items, slotKey, entry)
        end
        return items
    end
    if build.wishlist and self.DeserializeWishlist then
        local data = self:DeserializeWishlist(build.wishlist)
        if data and data.items then
            local items = {}
            for slotKey, entry in pairs(data.items) do
                addItemEntry(items, slotKey, entry)
            end
            return items
        end
    end
    if build.wowhead and self.ImportWowhead then
        local items = self:ImportWowhead(build.wowhead)
        if type(items) == "table" and #items > 0 then
            return items
        end
    end
    return {}
end

function Goals:ApplyWishlistBuild(build, mode)
    if not build then
        return false, "No build selected."
    end
    local function copyList(list)
        if type(list) ~= "table" then
            return nil
        end
        local out = {}
        for _, value in ipairs(list) do
            out[#out + 1] = value
        end
        return out
    end
    local function applyBuildMeta(listRef, buildRef)
        if not listRef or not buildRef then
            return
        end
        listRef.buildMeta = {
            id = buildRef.id,
            name = buildRef.name,
            class = buildRef.class,
            spec = buildRef.spec,
            tier = buildRef.tier,
            tags = copyList(buildRef.tags),
            sources = copyList(buildRef.sources),
        }
        listRef.updated = time()
    end
    local items = self:ResolveWishlistBuildItems(build)
    local targetId = nil
    if mode == "NEW" then
        local list = self:CreateWishlist(build.name or "Build")
        applyBuildMeta(list, build)
        targetId = list and list.id or nil
    else
        local list = self:GetActiveWishlist()
        applyBuildMeta(list, build)
        targetId = list and list.id or nil
    end
    if not targetId then
        return false, "No active wishlist."
    end
    if #items == 0 then
        local list = self:GetWishlistById(targetId)
        if list then
            list.items = {}
            list.updated = time()
            self:NotifyDataChanged()
        end
        return true, "Build imported (no items yet)."
    end
    local ok, summary = self:ApplyImportedWishlistItems(items, targetId)
    if ok and targetId then
        self:SetActiveWishlist(targetId)
    end
    return ok, summary
end
