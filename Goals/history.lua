-- Goals: history.lua
-- History logging for boss kills, manual adjustments, and loot assignments.
-- Usage: Goals.History:AddBossKill("Anub'arak", 1, names, true)

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.History = Goals.History or {}
local History = Goals.History

function History:Init(db)
    self.db = db
end

local function getItemLink(itemId)
    if not itemId then
        return nil
    end
    if Goals and Goals.CacheItemById then
        local cached = Goals:CacheItemById(itemId)
        if cached and cached.link then
            return cached.link
        end
    end
    if GetItemInfo then
        local _, link = GetItemInfo(itemId)
        return link
    end
    return nil
end

local function getSlotLabel(slotKey)
    if Goals and Goals.GetWishlistSlotDef then
        local def = Goals:GetWishlistSlotDef(slotKey)
        if def and def.label then
            return def.label
        end
    end
    return slotKey or "Slot"
end

local function formatItemFallback(itemId)
    if not itemId then
        return "item"
    end
    return "item:" .. tostring(itemId)
end

function History:AddEntry(kind, text, data)
    if not self.db or not self.db.history then
        return
    end
    local entry = {
        ts = time(),
        kind = kind,
        text = text,
        data = data,
    }
    table.insert(self.db.history, 1, entry)
end

function History:AddBossKill(encounterName, points, names, combine)
    local count = #names
    if combine then
        self:AddEntry(
            "BOSSKILL",
            string.format("%s: +%d to %d players", encounterName, points, count),
            { encounter = encounterName, points = points, players = names }
        )
        return
    end
    for _, name in ipairs(names) do
        self:AddEntry(
            "BOSSKILL",
            string.format("%s: %s +%d", encounterName, name, points),
            { encounter = encounterName, player = name, points = points }
        )
    end
end

function History:AddEncounterStart(encounterName)
    self:AddEntry(
        "ENCOUNTER_START",
        string.format("%s: started", encounterName),
        { encounter = encounterName }
    )
end

function History:AddAdjustment(playerName, delta, reason)
    local sign = delta >= 0 and "+" or ""
    self:AddEntry(
        "ADJUST",
        string.format("%s: %s%d (%s)", playerName, sign, delta, reason or "Adjustment"),
        { player = playerName, delta = delta, reason = reason }
    )
end

function History:AddSetPoints(playerName, before, after, reason)
    self:AddEntry(
        "SET",
        string.format("%s: %d -> %d (%s)", playerName, before, after, reason or "Set points"),
        { player = playerName, before = before, after = after, reason = reason }
    )
end

function History:AddLootFound(itemLink)
    self:AddEntry(
        "LOOT_FOUND",
        string.format("Found %s", itemLink),
        { item = itemLink }
    )
end

function History:AddLootAssigned(playerName, itemLink, resetPoints, resetBefore)
    local suffix = ""
    if resetPoints then
        local before = tonumber(resetBefore) or 0
        suffix = string.format(" (%s's points set to 0 (-%d))", playerName or "", before)
    end
    if not resetPoints and itemLink and self.db and self.db.history and self.db.history[1] then
        local last = self.db.history[1]
        if last.kind == "LOOT_ASSIGN" and last.data and last.data.item == itemLink and not last.data.reset then
            local lastTs = last.ts or 0
            if (time() - lastTs) <= 3 then
                last.data.players = last.data.players or { last.data.player }
                table.insert(last.data.players, playerName)
                last.data.player = nil
                last.data.playerCount = #last.data.players
                last.text = string.format("Gave %d players: %s", last.data.playerCount, itemLink)
                return
            end
        end
    end
    self:AddEntry(
        "LOOT_ASSIGN",
        string.format("Assigned to %s: %s%s", playerName, itemLink, suffix),
        { player = playerName, item = itemLink, reset = resetPoints or false, resetBefore = resetBefore }
    )
end

function History:AddLootAssignment(playerName, itemLink, resetPoints)
    self:AddLootAssigned(playerName, itemLink, resetPoints)
end

function History:AddLootReset(playerName, itemLink)
    self:AddLootAssigned(playerName, itemLink, true)
end

function History:AddWipe(encounterName)
    self:AddEntry(
        "WIPE",
        string.format("%s: wipe", encounterName),
        { encounter = encounterName }
    )
end

function History:AddBuildSent(targetName, buildName)
    self:AddEntry(
        "BUILD_SENT",
        string.format("Sent build '%s' to %s", buildName or "Wishlist", targetName or "Unknown"),
        { target = targetName, build = buildName }
    )
end

function History:AddBuildAccepted(senderName, buildName, listName)
    self:AddEntry(
        "BUILD_ACCEPTED",
        string.format("Accepted build '%s' from %s", buildName or "Wishlist", senderName or "Unknown"),
        { sender = senderName, build = buildName, list = listName }
    )
end

function History:AddWishlistItemAdded(slotKey, itemId)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    self:AddEntry(
        "WISHLIST_ADD",
        string.format("Wishlist add: %s %s", getSlotLabel(slotKey), link),
        { slot = slotKey, itemId = itemId, item = link }
    )
end

function History:AddWishlistItemRemoved(slotKey, itemId)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    self:AddEntry(
        "WISHLIST_REMOVE",
        string.format("Wishlist remove: %s %s", getSlotLabel(slotKey), link),
        { slot = slotKey, itemId = itemId, item = link }
    )
end

function History:AddWishlistItemSocketed(slotKey, itemId, gemIds)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    self:AddEntry(
        "WISHLIST_SOCKET",
        string.format("Wishlist socketed: %s %s", getSlotLabel(slotKey), link),
        { slot = slotKey, itemId = itemId, item = link, gemIds = gemIds }
    )
end

function History:AddWishlistItemEnchanted(slotKey, itemId, enchantId)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    self:AddEntry(
        "WISHLIST_ENCHANT",
        string.format("Wishlist enchanted: %s %s", getSlotLabel(slotKey), link),
        { slot = slotKey, itemId = itemId, item = link, enchantId = enchantId }
    )
end

function History:AddWishlistItemFound(itemId)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    self:AddEntry(
        "WISHLIST_FOUND",
        string.format("Wishlist found: %s", link),
        { itemId = itemId, item = link }
    )
end

function History:AddWishlistItemClaimed(slotKey, itemId, claimed)
    local link = getItemLink(itemId) or formatItemFallback(itemId)
    local action = claimed and "Wishlist claimed" or "Wishlist unclaimed"
    self:AddEntry(
        "WISHLIST_CLAIM",
        string.format("%s: %s %s", action, getSlotLabel(slotKey), link),
        { slot = slotKey, itemId = itemId, item = link, claimed = claimed and true or false }
    )
end
