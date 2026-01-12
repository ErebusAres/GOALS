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
