-- Goals: Core.lua
-- Bootstrap, shared helpers, and public API.
-- Usage:
--   Goals:ToggleUI()
--   Goals:AdjustPoints("Player", 1, "Manual award")

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.name = addonName or "Goals"
Goals.version = GetAddOnMetadata(Goals.name, "Version") or "dev"
Goals.db = Goals.db or nil
Goals.sync = Goals.sync or { isMaster = false, masterName = nil, status = "Solo" }
Goals.encounter = Goals.encounter or { active = false, name = nil, remaining = nil, startTime = 0 }
Goals.state = Goals.state or {
    lastLoot = nil,
    lootFound = {},
    lootFoundSeen = {},
    recentAssignments = {},
}
Goals.state.lootFound = Goals.state.lootFound or {}
Goals.state.lootFoundSeen = Goals.state.lootFoundSeen or {}
Goals.state.recentAssignments = Goals.state.recentAssignments or {}
Goals.pendingLoot = Goals.pendingLoot or {}
Goals.pendingItemInfo = Goals.pendingItemInfo or {}
Goals.undo = Goals.undo or {}
Goals.wishlistState = Goals.wishlistState or {
    announceQueue = {},
    announceNextFlush = 0,
    announcedItems = {},
}
Goals.itemCache = Goals.itemCache or {}
Goals.pendingWishlistInfo = Goals.pendingWishlistInfo or {}
Goals.ArmorTokenMap = Goals.ArmorTokenMap or {}
Goals.ArmorTokenReverse = Goals.ArmorTokenReverse or {}

local DEBUG_LOG_LIMIT = 400
local function deepCopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = deepCopyTable(value)
        else
            dst[key] = value
        end
    end
    return dst
end

local wipeMessages = {
    "%s wiped. Better luck next time!",
    "%s wiped. Try again!",
    "%s wiped. Shake it off!",
    "%s wiped. Clean pull next time!",
    "%s wiped. Regroup and go again!",
}

Goals.classColors = Goals.classColors or {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    DRUID = { r = 1.0, g = 0.49, b = 0.04 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    PRIEST = { r = 1.0, g = 1.0, b = 1.0 },
    ROGUE = { r = 1.0, g = 0.96, b = 0.41 },
    SHAMAN = { r = 0.0, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    WARRIOR = { r = 0.78, g = 0.63, b = 0.43 },
    UNKNOWN = { r = 0.5, g = 0.5, b = 0.5 },
}

Goals.WishlistSlots = Goals.WishlistSlots or {
    { key = "HEAD", label = "Head", inv = "HeadSlot", column = 1, row = 1 },
    { key = "NECK", label = "Neck", inv = "NeckSlot", column = 1, row = 2 },
    { key = "SHOULDER", label = "Shoulders", inv = "ShoulderSlot", column = 1, row = 3 },
    { key = "BACK", label = "Back", inv = "BackSlot", column = 1, row = 4 },
    { key = "CHEST", label = "Chest", inv = "ChestSlot", column = 1, row = 5 },
    { key = "WRIST", label = "Wrist", inv = "WristSlot", column = 1, row = 6 },
    { key = "HANDS", label = "Hands", inv = "HandsSlot", column = 1, row = 7 },
    { key = "WAIST", label = "Waist", inv = "WaistSlot", column = 2, row = 1 },
    { key = "LEGS", label = "Legs", inv = "LegsSlot", column = 2, row = 2 },
    { key = "FEET", label = "Feet", inv = "FeetSlot", column = 2, row = 3 },
    { key = "RING1", label = "Ring 1", inv = "Finger0Slot", column = 2, row = 4 },
    { key = "RING2", label = "Ring 2", inv = "Finger1Slot", column = 2, row = 5 },
    { key = "TRINKET1", label = "Trinket 1", inv = "Trinket0Slot", column = 2, row = 6 },
    { key = "TRINKET2", label = "Trinket 2", inv = "Trinket1Slot", column = 2, row = 7 },
    { key = "MAINHAND", label = "Main Hand", inv = "MainHandSlot", column = 3, row = 1 },
    { key = "OFFHAND", label = "Off Hand", inv = "SecondaryHandSlot", column = 3, row = 1 },
    { key = "RELIC", label = "Relic", inv = "RangedSlot", column = 3, row = 1 },
}

Goals.WishlistSlotIndex = Goals.WishlistSlotIndex or {}
for _, entry in ipairs(Goals.WishlistSlots) do
    Goals.WishlistSlotIndex[entry.key] = entry
end

local function prefixMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGoals|r: " .. msg)
end

function Goals:GetClassColor(class)
    local key = class and strupper(class) or "UNKNOWN"
    local color = self.classColors[key] or self.classColors.UNKNOWN
    return color.r, color.g, color.b
end

function Goals:GetPlayerClass(name)
    if not self.db or not self.db.players then
        return nil
    end
    local entry = self.db.players[self:NormalizeName(name)]
    return entry and entry.class
end

function Goals:GetPlayerColor(name)
    return self:GetClassColor(self:GetPlayerClass(name))
end

function Goals:ColorizeName(name)
    if not name or name == "" then
        return ""
    end
    local r, g, b = self:GetPlayerColor(name)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

function Goals:Print(msg)
    if msg then
        prefixMessage(msg)
    end
end

function Goals:GetGroupChannel()
    if self:IsInRaid() then
        return "RAID"
    end
    if self:IsInParty() then
        return "PARTY"
    end
    return nil
end

function Goals:AnnounceWipe(encounterName)
    self:Print(string.format("%s wiped.", encounterName or "Group"))
end

function Goals:AnnounceEncounterStart(encounterName)
    self:Print(string.format("Good luck! %s started.", encounterName or "Encounter"))
end

function Goals:Debug(msg)
    if not (self.Dev and self.Dev.enabled) then
        return
    end
    if not msg or msg == "" then
        return
    end
    if not (self.db and self.db.settings and self.db.settings.debug) then
        return
    end
    self:AppendDebugLog(msg)
end

function Goals:AppendDebugLog(msg)
    if not self.db then
        return
    end
    if type(self.db.debugLog) ~= "table" then
        self.db.debugLog = {}
    end
    table.insert(self.db.debugLog, 1, { ts = time(), msg = tostring(msg) })
    while #self.db.debugLog > DEBUG_LOG_LIMIT do
        table.remove(self.db.debugLog)
    end
    if self.UI and self.UI.UpdateDebugLogList then
        self.UI:UpdateDebugLogList()
    end
end

function Goals:GetDebugLog()
    if not self.db or type(self.db.debugLog) ~= "table" then
        return {}
    end
    return self.db.debugLog
end

function Goals:GetDebugLogText()
    local log = self:GetDebugLog()
    local lines = {}
    for _, entry in ipairs(log) do
        local ts = entry.ts and date("%H:%M:%S", entry.ts) or ""
        local msg = entry.msg or ""
        if ts ~= "" then
            table.insert(lines, ts .. " " .. msg)
        else
            table.insert(lines, msg)
        end
    end
    return table.concat(lines, "\n")
end

function Goals:ClearDebugLog()
    if not self.db then
        return
    end
    self.db.debugLog = {}
    if self.UI and self.UI.UpdateDebugLogList then
        self.UI:UpdateDebugLogList()
    end
end

function Goals:NormalizeName(name)
    if not name or name == "" then
        return ""
    end
    name = name:gsub("%-.*$", "")
    return name:sub(1, 1):upper() .. name:sub(2)
end

function Goals:GetPlayerName()
    return self:NormalizeName(UnitName("player") or "")
end

function Goals:GetInstalledUpdateVersion()
    local info = self.UpdateInfo
    local version = info and tonumber(info.version) or 0
    return version
end

function Goals:HandleRemoteVersion(version, sender)
    if not self.db or not self.db.settings then
        return
    end
    local installed = self:GetInstalledUpdateVersion()
    local incoming = tonumber(version) or 0
    if incoming <= installed then
        return
    end
    if (self.db.settings.updateAvailableVersion or 0) < incoming then
        self.db.settings.updateAvailableVersion = incoming
        self.db.settings.updateHasBeenSeen = false
        self:NotifyDataChanged()
        local who = sender and self:NormalizeName(sender) or "someone"
        self:Print("Update available (v" .. incoming .. ") from " .. who .. ".")
    end
end

function Goals:Delay(seconds, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= seconds then
            self:SetScript("OnUpdate", nil)
            func()
            self:Hide()
        end
    end)
end

function Goals:IsInRaid()
    if IsInRaid and IsInRaid() then
        return true
    end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        return true
    end
    if UnitInRaid and UnitInRaid("player") ~= nil then
        return true
    end
    if UnitExists and UnitExists("raid1") then
        return true
    end
    if GetRaidRosterInfo then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name then
                return true
            end
        end
    end
    return false
end

function Goals:IsInParty()
    if self:IsInRaid() then
        return false
    end
    if UnitInParty then
        return UnitInParty("player") ~= nil
    end
    return GetNumPartyMembers and GetNumPartyMembers() > 0
end

function Goals:IsGroupLeader()
    if self:IsInRaid() then
        return IsRaidLeader and IsRaidLeader()
    end
    if UnitIsPartyLeader then
        return UnitIsPartyLeader("player")
    end
    if GetPartyLeaderIndex then
        return GetPartyLeaderIndex() == 0
    end
    return false
end

function Goals:GetSelfLootIndex()
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local name = GetRaidRosterInfo(i)
            if self:NormalizeName(name) == self:GetPlayerName() then
                return i
            end
        end
        return nil
    end
    return nil
end

function Goals:SetLootMethod(method)
    if not SetLootMethod then
        return false, "Loot method API unavailable."
    end
    if not self:IsInRaid() and not self:IsInParty() then
        return false, "You must be in a party or raid."
    end
    if method == "master" then
        if self:IsInRaid() then
            local name = self:GetPlayerName()
            SetLootMethod("master", name)
            return true
        end
        if self:IsInParty() then
            SetLootMethod("master", "player")
            return true
        end
        SetLootMethod("master")
        return true
    end
    SetLootMethod(method)
    return true
end

function Goals:IsMasterLooter()
    if not GetLootMethod then
        return false
    end
    local method, partyID, raidID = GetLootMethod()
    if method ~= "master" then
        return false
    end
    local playerName = self:GetPlayerName()
    if raidID and raidID > 0 then
        local name = GetRaidRosterInfo(raidID)
        return self:NormalizeName(name) == playerName
    end
    if partyID and partyID > 0 then
        local name = UnitName("party" .. partyID)
        return self:NormalizeName(name) == playerName
    end
    return true
end

function Goals:HasLootAccess()
    if self.Dev and self.Dev.enabled then
        return true
    end
    return self:IsGroupLeader() or self:IsMasterLooter()
end

function Goals:GetLeaderName()
    if UnitExists and UnitIsRaidLeader then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitIsRaidLeader(unit) then
                return self:NormalizeName(UnitName(unit))
            end
        end
    end
    if GetRaidRosterInfo then
        for i = 1, 40 do
            local name, rank = GetRaidRosterInfo(i)
            if name and (rank == 2 or rank == "leader" or rank == "LEADER") then
                return self:NormalizeName(name)
            end
        end
    end
    if self:IsInRaid() then
        return "Unknown"
    end
    if self:IsInParty() then
        if UnitIsPartyLeader and UnitIsPartyLeader("player") then
            return self:GetPlayerName()
        end
        if GetPartyLeaderIndex then
            local index = GetPartyLeaderIndex()
            if index and index > 0 then
                return self:NormalizeName(UnitName("party" .. index))
            end
        end
    end
    return self:GetPlayerName()
end

function Goals:IsSyncMaster()
    local raidLeader = self.GetRaidLeaderFromRoster and self:GetRaidLeaderFromRoster() or nil
    if raidLeader and raidLeader ~= "" then
        return raidLeader == self:GetPlayerName()
    end
    if self:IsInParty() then
        return self:IsGroupLeader()
    end
    return self.Dev and self.Dev.enabled or false
end

function Goals:CanSync()
    if self.db and self.db.settings and self.db.settings.localOnly then
        return false
    end
    return self:IsSyncMaster()
end

function Goals:HasLeaderAccess()
    if self.Dev and self.Dev.enabled then
        return true
    end
    if not self:IsInRaid() and not self:IsInParty() then
        return true
    end
    return self:IsSyncMaster()
end

function Goals:UpdateSyncStatus(skipUI)
    local raidLeader = self.GetRaidLeaderFromRoster and self:GetRaidLeaderFromRoster() or nil
    if raidLeader and raidLeader ~= "" then
        if raidLeader == self:GetPlayerName() then
            self.sync.isMaster = true
            self.sync.masterName = self:GetPlayerName()
            self.sync.status = "Master (You)"
        else
            self.sync.isMaster = false
            self.sync.masterName = raidLeader
            self.sync.status = "Following " .. raidLeader
        end
    elseif self:IsInRaid() then
        self.sync.isMaster = false
        self.sync.masterName = nil
        self.sync.status = "Following Unknown"
    elseif self:IsInParty() then
        local leader = self:GetLeaderName() or "Unknown"
        self.sync.isMaster = false
        self.sync.masterName = leader
        self.sync.status = "Following " .. leader
    else
        self.sync.isMaster = false
        self.sync.masterName = nil
        self.sync.status = "Solo"
    end
    if not skipUI and self.UI and self.UI.RefreshStatus then
        self.UI:RefreshStatus()
    end
end

function Goals:GetRaidLeaderFromRoster()
    if UnitExists and (UnitIsGroupLeader or UnitIsRaidLeader) then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) then
                if UnitIsGroupLeader and UnitIsGroupLeader(unit) then
                    return self:NormalizeName(UnitName(unit))
                end
                if UnitIsRaidLeader and UnitIsRaidLeader(unit) then
                    return self:NormalizeName(UnitName(unit))
                end
            end
        end
    end
    if GetRaidRosterInfo then
        for i = 1, 40 do
            local name, rank = GetRaidRosterInfo(i)
            if name and (rank == 2 or rank == "leader" or rank == "LEADER") then
                return self:NormalizeName(name)
            end
        end
    end
    return nil
end

function Goals:GetGroupMembers()
    local members = {}
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local name, _, _, _, class, classFile = GetRaidRosterInfo(i)
            if name then
                table.insert(members, { name = self:NormalizeName(name), class = classFile or class })
            end
        end
    elseif self:IsInParty() then
        table.insert(members, { name = self:GetPlayerName(), class = select(2, UnitClass("player")) })
        for i = 1, GetNumPartyMembers() do
            local name, class = UnitName("party" .. i), UnitClass("party" .. i)
            if name then
                table.insert(members, { name = self:NormalizeName(name), class = class })
            end
        end
    else
        table.insert(members, { name = self:GetPlayerName(), class = select(2, UnitClass("player")) })
    end
    return members
end

function Goals:GetPresenceMap()
    local present = {}
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and online then
                present[self:NormalizeName(name)] = true
            end
        end
    elseif self:IsInParty() then
        local playerName = self:GetPlayerName()
        if UnitIsConnected("player") ~= false then
            present[playerName] = true
        end
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name and UnitIsConnected(unit) ~= false then
                present[self:NormalizeName(name)] = true
            end
        end
    else
        local playerName = self:GetPlayerName()
        if UnitIsConnected("player") ~= false then
            present[playerName] = true
        end
    end
    return present
end

function Goals:EnsureGroupMembers()
    local members = self:GetGroupMembers()
    local changed = false
    for _, info in ipairs(members) do
        local entry = self:EnsurePlayer(info.name, info.class)
        if entry then
            changed = true
        end
    end
    if changed then
        self:NotifyDataChanged()
    end
end

function Goals:EnsurePlayer(name, class)
    local key = self:NormalizeName(name)
    if key == "" or key == "Unknown" then
        if self.db and self.db.players then
            self.db.players[key] = nil
        end
        return nil
    end
    local entry = self.db.players[key]
    if type(entry) ~= "table" then
        entry = { points = 0, class = class or "UNKNOWN" }
        self.db.players[key] = entry
    end
    if class and class ~= "" then
        entry.class = class
    end
    if entry.points == nil then
        entry.points = 0
    end
    return entry, key
end

function Goals:SetRaidSetting(key, value, skipSync)
    if not self.db or not self.db.settings then
        return
    end
    self.db.settings[key] = value
    self:NotifyDataChanged()
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendSetting(key, value)
    end
end

function Goals:SetDisenchanter(name, skipSync)
    local normalized = self:NormalizeName(name or "")
    self.db.settings.disenchanter = normalized
    self:NotifyDataChanged()
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendSetting("disenchanter", normalized)
    end
end

function Goals:IsDisenchanter(name)
    local current = self.db.settings.disenchanter or ""
    if current == "" then
        return false
    end
    return self:NormalizeName(name) == self:NormalizeName(current)
end

function Goals:AdjustPoints(name, delta, reason, skipSync, skipUndo)
    local entry = self:EnsurePlayer(name)
    if not entry or not delta or delta == 0 then
        return
    end
    if delta > 0 and self.db and self.db.settings and self.db.settings.disablePointGain then
        return
    end
    if not skipUndo then
        self:RecordUndo(name, entry.points or 0)
    end
    entry.points = (entry.points or 0) + delta
    if self.History then
        self.History:AddAdjustment(name, delta, reason or "Manual adjustment")
    end
    self:NotifyDataChanged()
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendAdjustment(name, delta, reason)
    end
end

function Goals:AwardPresentPoints(delta, reason)
    local amount = tonumber(delta or 0) or 0
    if amount == 0 then
        return
    end
    if self.db and self.db.settings and self.db.settings.disablePointGain then
        return
    end
    local present = self:GetPresenceMap()
    local members = self:GetGroupMembers()
    for _, info in ipairs(members) do
        local name = info.name
        if name and present[self:NormalizeName(name)] then
            self:AdjustPoints(name, amount, reason or "Manual group award")
        end
    end
end

function Goals:SetPoints(name, points, reason, skipSync, skipHistory, skipUndo)
    local entry = self:EnsurePlayer(name)
    if not entry or points == nil then
        return
    end
    local before = entry.points or 0
    if not skipUndo then
        self:RecordUndo(name, before)
    end
    entry.points = points
    if self.History and not skipHistory then
        self.History:AddSetPoints(name, before, points, reason or "Set points")
    end
    self:NotifyDataChanged()
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendSetPoints(name, points, reason)
    end
end

function Goals:RemovePlayer(name)
    if not self.db or not self.db.players then
        return
    end
    local key = self:NormalizeName(name)
    if key == "" then
        return
    end
    if self.db.players[key] then
        self.db.players[key] = nil
        self.undo[key] = nil
        self:NotifyDataChanged()
    end
end

function Goals:AwardBossKill(encounterName, members, skipSync)
    local roster = members or self:GetGroupMembers()
    if not roster or #roster == 0 then
        return
    end
    if self.db and self.db.settings and self.db.settings.disablePointGain then
        return
    end
    local present = self:GetPresenceMap()
    local hasPresence = present and next(present) ~= nil
    local names = {}
    for _, info in ipairs(roster) do
        local playerName = info.name
        if hasPresence and not present[self:NormalizeName(playerName)] then
            playerName = nil
        end
        if not playerName then
            -- Skip offline/non-present players.
        else
        local entry = self:EnsurePlayer(playerName, info.class)
        if entry then
            entry.points = (entry.points or 0) + 1
            table.insert(names, playerName)
        end
        end
    end
    if self.History then
        self.History:AddBossKill(encounterName, 1, names, self.db.settings.combineBossHistory)
    end
    self:Print(encounterName .. " was completed. +1 Point.")
    self:NotifyDataChanged()
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendBossKill(encounterName, names)
    end
end

function Goals:ApplyBossKillFromSync(encounterName, names)
    if not names or #names == 0 then
        return
    end
    local roster = {}
    for _, name in ipairs(names) do
        table.insert(roster, { name = name })
    end
    self:AwardBossKill(encounterName, roster, true)
end

function Goals:IsMount(itemType, itemSubType)
    local miscType = MISCELLANEOUS or "Miscellaneous"
    local mountType = MOUNT or "Mount"
    if itemType ~= miscType then
        return false
    end
    return itemSubType == mountType
end

function Goals:IsPet(itemType, itemSubType)
    local miscType = MISCELLANEOUS or "Miscellaneous"
    local petType = COMPANION_PETS or "Companion Pets"
    local petTypeAlt = PETS or "Pets"
    if itemType ~= miscType then
        return false
    end
    return itemSubType == petType or itemSubType == petTypeAlt
end

function Goals:IsQuestItem(itemType)
    local questType = QUESTS or ITEM_CLASS_QUEST or "Quest"
    return itemType == questType
end

function Goals:IsRecipe(itemType)
    local recipeType = ITEM_CLASS_RECIPE or "Recipe"
    return itemType == recipeType
end

function Goals:IsToken(itemType, itemSubType)
    local miscType = MISCELLANEOUS or "Miscellaneous"
    if itemType ~= miscType then
        return false
    end
    local armorToken = ITEM_SUBCLASS_ARMOR_TOKEN or "Armor Token"
    local tokenSub = TOKEN or "Token"
    return itemSubType == armorToken or itemSubType == tokenSub
end

function Goals:IsEquippableSlot(equipSlot)
    if not equipSlot or equipSlot == "" then
        return false
    end
    return equipSlot ~= "INVTYPE_NON_EQUIP"
end

function Goals:IsEquippableItemId(itemId)
    if not itemId then
        return false
    end
    if IsEquippableItem then
        return IsEquippableItem(itemId)
    end
    return true
end

function Goals:IsTrinket(itemSubType, equipSlot)
    local trinketType = ITEM_SUBCLASS_ARMOR_TRINKET or "Trinket"
    local trinketSlot = INVTYPE_TRINKET or "INVTYPE_TRINKET"
    return itemSubType == trinketType or equipSlot == trinketSlot
end

function Goals:GetResetMinQuality()
    local minQuality = self.db and self.db.settings and self.db.settings.resetMinQuality
    if type(minQuality) ~= "number" then
        return 4
    end
    if minQuality < 0 then
        return 0
    end
    if minQuality > 7 then
        return 7
    end
    return minQuality
end

function Goals:IsTrackedLootType(itemType, itemSubType, equipSlot)
    local armorType = ARMOR or "Armor"
    local weaponType = WEAPON or "Weapon"
    if self:IsMount(itemType, itemSubType) or self:IsPet(itemType, itemSubType) then
        return true
    end
    if self:IsToken(itemType, itemSubType) then
        return true
    end
    if itemType == armorType or itemType == weaponType then
        return true
    end
    if self:IsQuestItem(itemType) then
        return true
    end
    if self:IsTrinket(itemSubType, equipSlot) then
        return true
    end
    if self:IsEquippableSlot(equipSlot) then
        return true
    end
    return false
end

function Goals:ShouldTrackLoot(quality, itemType, itemSubType, equipSlot)
    if not self:IsInRaid() and not (self.Dev and self.Dev.enabled) then
        return false
    end
    if not quality then
        return false
    end
    local armorType = ARMOR or "Armor"
    local weaponType = WEAPON or "Weapon"
    local minQuality = self:GetResetMinQuality()
    if self:IsMount(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetMounts or false
    end
    if self:IsPet(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetPets or false
    end
    if self:IsToken(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetTokens or false
    end
    if self:IsRecipe(itemType) then
        return self.db and self.db.settings and self.db.settings.resetRecipes or false
    end
    if self:IsQuestItem(itemType) then
        return self.db and self.db.settings and self.db.settings.resetQuestItems or false
    end
    if itemType == armorType or itemType == weaponType or self:IsTrinket(itemSubType, equipSlot) or self:IsEquippableSlot(equipSlot) then
        return quality >= minQuality
    end
    return false
end

function Goals:ShouldResetForLoot(itemType, itemSubType, equipSlot, quality)
    local armorType = ARMOR or "Armor"
    local weaponType = WEAPON or "Weapon"
    if self:IsMount(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetMounts and true or false
    end
    if self:IsPet(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetPets and true or false
    end
    if self:IsToken(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetTokens and true or false
    end
    if self:IsRecipe(itemType) then
        return self.db and self.db.settings and self.db.settings.resetRecipes and true or false
    end
    if self:IsQuestItem(itemType) then
        return self.db and self.db.settings and self.db.settings.resetQuestItems and true or false
    end
    if itemType == armorType or itemType == weaponType or self:IsTrinket(itemSubType, equipSlot) or self:IsEquippableSlot(equipSlot) then
        if not quality then
            return false
        end
        return quality >= self:GetResetMinQuality()
    end
    return false
end

function Goals:ShouldSkipLootAssignment(playerName, itemLink)
    local key = playerName .. "|" .. itemLink
    local now = time()
    local recent = self.state.recentAssignments or {}
    local last = recent[key]
    if last and (now - last) < 3 then
        return true
    end
    recent[key] = now
    if next(recent) then
        for k, ts in pairs(recent) do
            if (now - ts) > 60 then
                recent[k] = nil
            end
        end
    end
    self.state.recentAssignments = recent
    return false
end

function Goals:HandleLoot(playerName, itemLink, skipSync)
    self:HandleLootAssignment(playerName, itemLink, skipSync, false)
end

function Goals:HandleLootAssignment(playerName, itemLink, skipSync, forceRecord)
    if not playerName or not itemLink then
        return
    end
    playerName = self:NormalizeName(playerName)
    self:EnsurePlayer(playerName)
    if self:ShouldSkipLootAssignment(playerName, itemLink) then
        return
    end
    if not self:IsInRaid() and not (self.Dev and self.Dev.enabled) then
        return
    end
    local itemName, _, quality, _, _, itemType, itemSubType, _, equipSlot = GetItemInfo(itemLink)
    if not itemName then
        self.pendingLoot[itemLink] = self.pendingLoot[itemLink] or {}
        self.pendingLoot[itemLink][playerName] = { skipSync = skipSync, forceRecord = forceRecord }
        self:RequestItemInfo(itemLink)
        return
    end
    local shouldTrack = self:ShouldTrackLoot(quality, itemType, itemSubType, equipSlot)
    local shouldReset = shouldTrack and self:ShouldResetForLoot(itemType, itemSubType, equipSlot, quality)
    local resetApplied = shouldReset and not self:IsDisenchanter(playerName)
    if forceRecord or shouldTrack then
        local before = nil
        if resetApplied then
            local entry = self.db and self.db.players and self.db.players[self:NormalizeName(playerName)] or nil
            before = entry and entry.points or 0
        end
        self:RecordLootAssignment(playerName, itemLink, resetApplied, before)
        if self:CanSync() and not skipSync and self.Comm then
            if resetApplied then
                self.Comm:SendLootReset(playerName, itemLink)
            else
                self.Comm:SendLootAssignment(playerName, itemLink)
            end
        end
    end
    if resetApplied then
        self:SetPoints(playerName, 0, "Loot reset: " .. itemLink, true, true)
    elseif shouldReset and self:IsDisenchanter(playerName) then
        self:Debug("Disenchanter loot ignored for points: " .. itemName)
    end
    if forceRecord or shouldTrack then
        self:NotifyDataChanged()
    end
end

function Goals:RequestItemInfo(itemLink)
    if not itemLink then
        return
    end
    self.pendingItemInfo = self.pendingItemInfo or {}
    if self.pendingItemInfo[itemLink] then
        return
    end
    self.pendingItemInfo[itemLink] = true
    if not self.itemInfoTooltip then
        self.itemInfoTooltip = CreateFrame("GameTooltip", "GoalsItemInfoTooltip", UIParent, "GameTooltipTemplate")
    end
    local tooltip = self.itemInfoTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    tooltip:Hide()
    self:Delay(0.5, function()
        self.pendingItemInfo[itemLink] = nil
        self:ProcessPendingLoot()
        self:ProcessPendingWishlistInfo()
    end)
end

function Goals:RecordLootFound(itemLink)
    if not itemLink then
        return
    end
    self.state.lootFoundSeenLinks = self.state.lootFoundSeenLinks or {}
    local lastSeen = self.state.lootFoundSeenLinks[itemLink] or 0
    if lastSeen > 0 and (time() - lastSeen) < 120 then
        return
    end
    self.state.lootFoundSeenLinks[itemLink] = time()
    if self.History then
        self.History:AddLootFound(itemLink)
    end
end

function Goals:ApplyLootFound(id, ts, itemLink, sender)
    if not itemLink then
        return
    end
    self.state.lootFound = self.state.lootFound or {}
    self.state.lootFoundSeenIds = self.state.lootFoundSeenIds or {}
    self.state.lootFoundSeenLinks = self.state.lootFoundSeenLinks or {}
    local now = ts or time()
    local lastSeen = self.state.lootFoundSeenLinks[itemLink] or 0
    if lastSeen > 0 and math.abs(now - lastSeen) < 120 then
        return
    end
    if id and id > 0 then
        local key = tostring(id)
        if ts then
            key = key .. ":" .. tostring(ts)
        end
        if sender then
            key = sender .. ":" .. key
        end
        if self.state.lootFoundSeenIds[key] then
            return
        end
        self.state.lootFoundSeenIds[key] = true
    end
    table.insert(self.state.lootFound, 1, {
        slot = 0,
        link = itemLink,
        ts = ts or time(),
        assignedTo = nil,
        synced = true,
    })
    self.state.lootFoundSeenLinks[itemLink] = ts or time()
    if self.History then
        self.History:AddLootFound(itemLink)
    end
    self:NotifyDataChanged()
end

function Goals:UpdateLootSlots(resetSeen)
    if not self:HasLootAccess() then
        return
    end
    if resetSeen then
        self.state.lootFoundSeen = {}
    end
    local seen = self.state.lootFoundSeen or {}
    local list = {}
    self.state.lootFoundCounter = self.state.lootFoundCounter or 0
    local count = GetNumLootItems and GetNumLootItems() or 0
    for slot = 1, count do
        local isItem = GetLootSlotType and GetLootSlotType(slot) == 1
        local link = GetLootSlotLink and GetLootSlotLink(slot) or nil
        if isItem or link then
            if link then
                local entryTs = time()
                self.state.lootFoundCounter = self.state.lootFoundCounter + 1
                local entryId = self.state.lootFoundCounter
                table.insert(list, {
                    slot = slot,
                    link = link,
                    ts = entryTs,
                    assignedTo = nil,
                    id = entryId,
                })
                if seen[slot] ~= link then
                    seen[slot] = link
                    self:RecordLootFound(link)
                    if self.Comm and self:CanSync() then
                        self.Comm:SendLootFound(entryId, entryTs, link)
                    end
                end
            end
        end
    end
    self.state.lootFound = list
    self.state.lootFoundSeen = seen
    self:NotifyDataChanged()
end

function Goals:ClearFoundLoot()
    self.state.lootFound = {}
    self.state.lootFoundSeen = {}
    self.state.lootFoundSeenIds = {}
    self.state.lootFoundSeenLinks = {}
    self:NotifyDataChanged()
end

function Goals:ClearAllPointsLocal()
    if not self.db or not self.db.players then
        return
    end
    for _, entry in pairs(self.db.players) do
        if type(entry) == "table" then
            entry.points = 0
        end
    end
    self.undo = {}
    self:NotifyDataChanged()
end

function Goals:ClearPlayersLocal()
    if not self.db then
        return
    end
    self.db.players = {}
    self.undo = {}
    self:NotifyDataChanged()
end

function Goals:ClearLootHistoryLocal()
    if not self.db or not self.db.settings then
        return
    end
    self.db.settings.lootHistoryHiddenBefore = time()
    self:ClearFoundLoot()
    self:NotifyDataChanged()
end

function Goals:ClearHistoryLocal()
    if not self.db then
        return
    end
    self.db.history = {}
    self:ClearFoundLoot()
    self:NotifyDataChanged()
end

function Goals:ClearAllLocal()
    self:ClearAllPointsLocal()
    self:ClearPlayersLocal()
    self:ClearLootHistoryLocal()
    self:ClearHistoryLocal()
end

function Goals:GetFoundLoot()
    self.state.lootFound = self.state.lootFound or {}
    return self.state.lootFound
end

function Goals:GetLootTargetIndex(name)
    local target = self:NormalizeName(name)
    if target == "" then
        return nil
    end
    if target == self:GetPlayerName() then
        return 0
    end
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local raidName = GetRaidRosterInfo(i)
            if self:NormalizeName(raidName) == target then
                return i
            end
        end
    elseif self:IsInParty() then
        for i = 1, GetNumPartyMembers() do
            local partyName = UnitName("party" .. i)
            if self:NormalizeName(partyName) == target then
                return i
            end
        end
    end
    return nil
end

function Goals:GetLootCandidateIndex(slot, name)
    if not GetMasterLootCandidate or not slot then
        return nil
    end
    local target = self:NormalizeName(name)
    if target == "" then
        return nil
    end
    for i = 1, 40 do
        local candidate = GetMasterLootCandidate(slot, i)
        if not candidate then
            break
        end
        if self:NormalizeName(candidate) == target then
            return i
        end
    end
    return nil
end

function Goals:AssignLootSlot(slot, targetName, itemLink)
    if not slot or not targetName or targetName == "" then
        return
    end
    if slot <= 0 then
        if not (self.Dev and self.Dev.enabled) then
            self:Print("Loot must be assigned from an open loot window.")
            return
        end
        if not itemLink or itemLink == "" then
            self:Debug("AssignLootSlot skipped: dev test requires an item link.")
            return
        end
        if self.state.lootFound then
            for i, entry in ipairs(self.state.lootFound) do
                if entry.link == itemLink then
                    entry.assignedTo = self:NormalizeName(targetName)
                    table.remove(self.state.lootFound, i)
                    break
                end
            end
        end
        self:HandleLootAssignment(targetName, itemLink, false, true)
        self:NotifyDataChanged()
        return
    end
    if not self:IsMasterLooter() and not (self.Dev and self.Dev.enabled) then
        return
    end
    if (not self.Dev or not self.Dev.enabled) and (not GetMasterLootCandidate or not GetMasterLootCandidate(slot, 1)) then
        self:Print("Loot must be assigned from an open loot window.")
        return
    end
    local index = self:GetLootCandidateIndex(slot, targetName)
    if (self.db and self.db.settings and self.db.settings.debug) or (self.Dev and self.Dev.enabled) then
        local candidates = {}
        if GetMasterLootCandidate then
            for i = 1, 40 do
                local candidate = GetMasterLootCandidate(slot, i)
                if not candidate then
                    break
                end
                table.insert(candidates, candidate)
            end
        end
        self:Debug(string.format("AssignLootSlot slot=%s target=%s index=%s candidates=%s",
            tostring(slot), tostring(targetName), tostring(index), table.concat(candidates, ", ")))
    end
    if index == nil then
        if (self.db and self.db.settings and self.db.settings.debug) or (self.Dev and self.Dev.enabled) then
            self:Debug("AssignLootSlot failed: target not in master loot candidate list.")
        end
        self:Print("Target not eligible for this loot (out of range or not on loot table).")
        return
    end
    if GiveMasterLoot and slot > 0 then
        GiveMasterLoot(slot, index)
    end
    local link = itemLink or (GetLootSlotLink and GetLootSlotLink(slot) or nil)
    if self.state.lootFound then
        for i, entry in ipairs(self.state.lootFound) do
            if entry.slot == slot then
                entry.assignedTo = self:NormalizeName(targetName)
                table.remove(self.state.lootFound, i)
                break
            end
        end
    end
    if link then
        self:HandleLootAssignment(targetName, link, false, true)
    end
    self:NotifyDataChanged()
end

function Goals:RecordLootAssignment(playerName, itemLink, resetApplied, resetBefore)
    self.state.lastLoot = { name = playerName, link = itemLink, ts = time() }
    if self.History then
        self.History:AddLootAssigned(playerName, itemLink, resetApplied, resetBefore)
    end
end

function Goals:ApplyLootAssignment(playerName, itemLink)
    if self:ShouldSkipLootAssignment(playerName, itemLink) then
        return
    end
    self:RecordLootAssignment(playerName, itemLink, false)
    self:NotifyDataChanged()
end

function Goals:ApplyLootReset(playerName, itemLink)
    if self:ShouldSkipLootAssignment(playerName, itemLink) then
        return
    end
    local entry = self.db and self.db.players and self.db.players[self:NormalizeName(playerName)] or nil
    local before = entry and entry.points or 0
    self:RecordLootAssignment(playerName, itemLink, true, before)
    self:SetPoints(playerName, 0, "Loot reset: " .. itemLink, true, true)
end

function Goals:RecordUndo(name, points)
    local key = self:NormalizeName(name)
    if key == "" then
        return
    end
    self.undo[key] = points
end

function Goals:GetUndoPoints(name)
    local key = self:NormalizeName(name)
    if key == "" then
        return nil
    end
    return self.undo[key]
end

function Goals:UndoPoints(name)
    local key = self:NormalizeName(name)
    if key == "" then
        return
    end
    local previous = self.undo[key]
    if previous == nil then
        return
    end
    self.undo[key] = nil
    self:SetPoints(key, previous, "Undo", false, false, true)
end

function Goals:ProcessPendingLoot()
    for itemLink, players in pairs(self.pendingLoot) do
        local itemName = GetItemInfo(itemLink)
        if itemName then
            for playerName, data in pairs(players) do
                local skip = data and data.skipSync
                local forceRecord = data and data.forceRecord
                self:HandleLootAssignment(playerName, itemLink, skip, forceRecord)
            end
            self.pendingLoot[itemLink] = nil
        end
    end
end

function Goals:IsGroupInCombat()
    if UnitAffectingCombat("player") then
        return true
    end
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            if UnitAffectingCombat("raid" .. i) then
                return true
            end
        end
    elseif self:IsInParty() then
        for i = 1, GetNumPartyMembers() do
            if UnitAffectingCombat("party" .. i) then
                return true
            end
        end
    end
    return false
end

function Goals:NotifyDataChanged()
    if self.db then
        self.db.lastUpdated = time()
    end
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function Goals:EnsureTableDefaults(tableData)
    if type(tableData) ~= "table" then
        return { players = {}, history = {}, settings = {}, debugLog = {}, wishlists = {}, lastUpdated = time() }
    end
    tableData.players = tableData.players or {}
    tableData.history = tableData.history or {}
    tableData.settings = tableData.settings or {}
    tableData.debugLog = tableData.debugLog or {}
    tableData.wishlists = tableData.wishlists or {}
    if not tableData.lastUpdated then
        tableData.lastUpdated = time()
    end
    self:CopyDefaults(tableData, self.defaults)
    return tableData
end

function Goals:GetTableRoot()
    return self.dbRoot
end

function Goals:EnsureSaveTable(name)
    if not self.dbRoot or not self.dbRoot.tables then
        return nil
    end
    local key = self:NormalizeName(name or "")
    if key == "" then
        return nil
    end
    if not self.dbRoot.tables[key] then
        self.dbRoot.tables[key] = {
            players = {},
            history = {},
            settings = deepCopyTable(self.defaults.settings or {}),
            wishlists = deepCopyTable(self.defaults.wishlists or {}),
            debugLog = {},
            lastUpdated = time(),
        }
    else
        self.dbRoot.tables[key] = self:EnsureTableDefaults(self.dbRoot.tables[key])
    end
    return self.dbRoot.tables[key]
end

function Goals:CopyTableData(source, target)
    if not source or not target then
        return
    end
    target.players = deepCopyTable(source.players or {})
    target.history = deepCopyTable(source.history or {})
    target.settings = deepCopyTable(source.settings or {})
    target.settings.devTestBoss = false
    target.wishlists = deepCopyTable(source.wishlists or {})
    target.debugLog = {}
    target.lastUpdated = time()
end

function Goals:EnsureWishlistData()
    if not self.db then
        return nil
    end
    if type(self.db.wishlists) ~= "table" then
        self.db.wishlists = {}
    end
    local data = self.db.wishlists
    data.version = data.version or 1
    data.activeId = data.activeId or 1
    data.nextId = data.nextId or 1
    if type(data.lists) ~= "table" then
        data.lists = {}
    end
    local nextId = data.nextId
    for _, list in ipairs(data.lists) do
        if list.id and list.id >= nextId then
            nextId = list.id + 1
        end
        if type(list.items) ~= "table" then
            list.items = {}
        end
    end
    data.nextId = nextId
    if #data.lists == 0 then
        local defaultName = self:GetPlayerName()
        if defaultName ~= "" then
            defaultName = defaultName .. " Wishlist"
        else
            defaultName = "Wishlist"
        end
        local list = {
            id = data.nextId,
            name = defaultName,
            created = time(),
            updated = time(),
            items = {},
        }
        data.nextId = data.nextId + 1
        table.insert(data.lists, list)
        data.activeId = list.id
    end
    return data
end

function Goals:GetWishlistById(id)
    local data = self:EnsureWishlistData()
    if not data then
        return nil
    end
    for _, list in ipairs(data.lists) do
        if list.id == id then
            return list
        end
    end
    return nil
end

function Goals:GetActiveWishlist()
    local data = self:EnsureWishlistData()
    if not data then
        return nil
    end
    local list = self:GetWishlistById(data.activeId)
    if list then
        return list
    end
    if data.lists[1] then
        data.activeId = data.lists[1].id
        return data.lists[1]
    end
    return nil
end

function Goals:SetActiveWishlist(id)
    local data = self:EnsureWishlistData()
    if not data or not id then
        return
    end
    if self:GetWishlistById(id) then
        data.activeId = id
        self:NotifyDataChanged()
    end
end

function Goals:NormalizeWishlistName(name)
    if not name or name == "" then
        return ""
    end
    name = tostring(name):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

function Goals:CreateWishlist(name)
    local data = self:EnsureWishlistData()
    if not data then
        return nil
    end
    local clean = self:NormalizeWishlistName(name)
    if clean == "" then
        local baseName = self:GetPlayerName()
        if baseName == "" then
            baseName = "Wishlist"
        end
        local maxIndex = -1
        for _, list in ipairs(data.lists) do
            local listName = list.name or ""
            local idx = listName:match("^" .. baseName .. " (%d+)$")
            if idx then
                maxIndex = math.max(maxIndex, tonumber(idx) or -1)
            end
        end
        clean = string.format("%s %d", baseName, maxIndex + 1)
    end
    local list = {
        id = data.nextId,
        name = clean,
        created = time(),
        updated = time(),
        items = {},
    }
    data.nextId = (data.nextId or 1) + 1
    table.insert(data.lists, list)
    data.activeId = list.id
    self:NotifyDataChanged()
    return list
end

function Goals:RenameWishlist(id, newName)
    local list = self:GetWishlistById(id)
    if not list then
        return false
    end
    local clean = self:NormalizeWishlistName(newName)
    if clean == "" then
        return false
    end
    list.name = clean
    list.updated = time()
    self:NotifyDataChanged()
    return true
end

function Goals:CopyWishlist(id, newName)
    local list = self:GetWishlistById(id)
    if not list then
        return nil
    end
    local copy = self:CreateWishlist(newName ~= "" and newName or (list.name .. " Copy"))
    if not copy then
        return nil
    end
    copy.items = deepCopyTable(list.items or {})
    copy.updated = time()
    self:NotifyDataChanged()
    return copy
end

function Goals:DeleteWishlist(id)
    local data = self:EnsureWishlistData()
    if not data then
        return false
    end
    for index, list in ipairs(data.lists) do
        if list.id == id then
            table.remove(data.lists, index)
            if data.activeId == id then
                data.activeId = data.lists[1] and data.lists[1].id or 0
            end
            self:NotifyDataChanged()
            return true
        end
    end
    return false
end

function Goals:GetWishlistItem(slotKey)
    local list = self:GetActiveWishlist()
    if not list or not slotKey then
        return nil
    end
    list.items = list.items or {}
    return list.items[slotKey]
end

function Goals:RefreshArmorTokenMap()
    self.ArmorTokenReverse = {}
    for _, tokenId in pairs(self.ArmorTokenMap or {}) do
        if tokenId and tokenId > 0 then
            self.ArmorTokenReverse[tokenId] = true
        end
    end
end

function Goals:GetArmorTokenForItem(itemId)
    if not itemId then
        return nil
    end
    if not self.ArmorTokenReverse or not next(self.ArmorTokenReverse) then
        self:RefreshArmorTokenMap()
    end
    return self.ArmorTokenMap[itemId]
end

function Goals:SetWishlistItem(slotKey, itemData)
    local list = self:GetActiveWishlist()
    if not list or not slotKey or type(itemData) ~= "table" then
        return
    end
    if itemData.itemId then
        itemData.tokenId = self:GetArmorTokenForItem(itemData.itemId) or 0
    end
    list.items = list.items or {}
    list.items[slotKey] = itemData
    list.updated = time()
    self:NotifyDataChanged()
end

function Goals:ClearWishlistItem(slotKey)
    local list = self:GetActiveWishlist()
    if not list or not slotKey then
        return
    end
    list.items = list.items or {}
    list.items[slotKey] = nil
    list.updated = time()
    self:NotifyDataChanged()
end

function Goals:GetWishlistSlotDefs()
    return self.WishlistSlots
end

function Goals:GetWishlistSlotDef(slotKey)
    return self.WishlistSlotIndex and self.WishlistSlotIndex[slotKey] or nil
end

function Goals:GetItemIdFromLink(link)
    if not link or link == "" then
        return nil
    end
    local itemId = link:match("item:(%d+)")
    return itemId and tonumber(itemId) or nil
end

function Goals:CacheItemById(itemId)
    if not itemId then
        return nil
    end
    self.itemCache = self.itemCache or {}
    self.pendingWishlistInfo = self.pendingWishlistInfo or {}
    local cached = self.itemCache[itemId]
    if cached and cached.name then
        return cached
    end
    if self.pendingWishlistInfo[itemId] then
        return nil
    end
    local itemName, itemLink, quality, itemLevel, _, itemType, itemSubType, _, equipSlot, texture = GetItemInfo(itemId)
    if itemName then
        cached = {
            id = itemId,
            name = itemName,
            link = itemLink,
            quality = quality,
            level = itemLevel,
            type = itemType,
            subType = itemSubType,
            equipSlot = equipSlot,
            texture = texture,
        }
        self.itemCache[itemId] = cached
        return cached
    end
    self.pendingWishlistInfo[itemId] = true
    self:RequestItemInfo("item:" .. tostring(itemId))
    return nil
end

function Goals:CacheItemByLink(itemLink)
    local itemId = self:GetItemIdFromLink(itemLink)
    if itemId then
        local cached = self:CacheItemById(itemId)
        if cached and not cached.link then
            cached.link = itemLink
        end
        return cached
    end
    return nil
end

function Goals:ProcessPendingWishlistInfo()
    if not self.pendingWishlistInfo or not next(self.pendingWishlistInfo) then
        return
    end
    local updated = false
    for itemId in pairs(self.pendingWishlistInfo) do
        if self:CacheItemById(itemId) then
            self.pendingWishlistInfo[itemId] = nil
            updated = true
        end
    end
    if updated and self.UI and self.UI.UpdateWishlistUI then
        self.UI:UpdateWishlistUI()
    end
end

local function escapeWishlistText(text)
    if text == nil then
        return ""
    end
    text = tostring(text)
    text = text:gsub("%%", "%%25")
    text = text:gsub("|", "%%7C")
    text = text:gsub(";", "%%3B")
    text = text:gsub(":", "%%3A")
    text = text:gsub(",", "%%2C")
    return text
end

local function unescapeWishlistText(text)
    if text == nil then
        return ""
    end
    text = tostring(text)
    text = text:gsub("%%2C", ",")
    text = text:gsub("%%3A", ":")
    text = text:gsub("%%3B", ";")
    text = text:gsub("%%7C", "|")
    text = text:gsub("%%25", "%%")
    return text
end

function Goals:SerializeWishlist(list)
    if not list then
        return ""
    end
    local parts = {
        "WL1",
        "name=" .. escapeWishlistText(list.name or ""),
    }
    local items = {}
    for slotKey, entry in pairs(list.items or {}) do
        local gems = entry.gemIds or {}
        local gemStrs = {}
        for i = 1, #gems do
            gemStrs[i] = tostring(gems[i])
        end
        local itemPart = table.concat({
            slotKey or "",
            tostring(entry.itemId or 0),
            tostring(entry.enchantId or 0),
            table.concat(gemStrs, ","),
            escapeWishlistText(entry.notes or ""),
            escapeWishlistText(entry.source or ""),
        }, ":")
        table.insert(items, itemPart)
    end
    table.insert(parts, "items=" .. table.concat(items, "|"))
    return table.concat(parts, ";")
end

function Goals:DeserializeWishlist(text)
    if not text or text == "" then
        return nil, "Empty import string."
    end
    if not text:find("^WL1") then
        return nil, "Unknown wishlist format."
    end
    local name = "Wishlist"
    local items = {}
    for part in string.gmatch(text, "([^;]+)") do
        local key, value = part:match("([^=]+)=(.*)")
        if key == "name" then
            local clean = unescapeWishlistText(value)
            if clean ~= "" then
                name = clean
            end
        elseif key == "items" then
            for entry in string.gmatch(value or "", "([^|]+)") do
                local slotKey, itemId, enchantId, gems, notes, source = entry:match("([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):?(.*)")
                if slotKey and slotKey ~= "" then
                    local gemIds = {}
                    for gem in string.gmatch(gems or "", "([^,]+)") do
                        local id = tonumber(gem)
                        if id and id > 0 then
                            table.insert(gemIds, id)
                        end
                    end
                    items[slotKey] = {
                        itemId = tonumber(itemId) or 0,
                        enchantId = tonumber(enchantId) or 0,
                        gemIds = gemIds,
                        notes = unescapeWishlistText(notes),
                        source = unescapeWishlistText(source),
                    }
                end
            end
        end
    end
    return {
        name = name,
        items = items,
    }, nil
end

function Goals:ExportActiveWishlist()
    local list = self:GetActiveWishlist()
    if not list then
        return ""
    end
    return self:SerializeWishlist(list)
end

function Goals:ImportWishlistString(text)
    local data, err = self:DeserializeWishlist(text)
    if not data then
        return false, err
    end
    local list = self:CreateWishlist(data.name)
    if not list then
        return false, "Failed to create wishlist."
    end
    list.items = data.items or {}
    list.updated = time()
    self:NotifyDataChanged()
    return true, nil
end

function Goals:SerializeAllWishlists()
    local data = self:EnsureWishlistData()
    if not data then
        return ""
    end
    local parts = { "WLS1" }
    for _, list in ipairs(data.lists) do
        table.insert(parts, self:SerializeWishlist(list))
    end
    return table.concat(parts, "||")
end

function Goals:ApplyWishlistSync(payload)
    if not payload or payload == "" then
        return
    end
    if not payload:find("^WLS1") then
        return
    end
    local lists = {}
    local parts = {}
    local start = 1
    while true do
        local sepStart, sepEnd = payload:find("||", start, true)
        if not sepStart then
            table.insert(parts, payload:sub(start))
            break
        end
        table.insert(parts, payload:sub(start, sepStart - 1))
        start = sepEnd + 1
    end
    for _, entry in ipairs(parts) do
        if entry ~= "WLS1" and entry ~= "" then
            local data = self:DeserializeWishlist(entry)
            if data and data.items then
                table.insert(lists, data)
            end
        end
    end
    local wishlistData = self:EnsureWishlistData()
    if not wishlistData then
        return
    end
    wishlistData.version = 1
    wishlistData.lists = {}
    wishlistData.nextId = 1
    for _, data in ipairs(lists) do
        local list = {
            id = wishlistData.nextId,
            name = data.name,
            created = time(),
            updated = time(),
            items = data.items or {},
        }
        wishlistData.nextId = wishlistData.nextId + 1
        table.insert(wishlistData.lists, list)
    end
    if wishlistData.lists[1] then
        wishlistData.activeId = wishlistData.lists[1].id
    else
        wishlistData.activeId = 0
        self:EnsureWishlistData()
    end
    self:NotifyDataChanged()
end

function Goals:EnqueueWishlistAnnounce(itemLink)
    if not itemLink or itemLink == "" then
        return
    end
    if self.db and self.db.settings and not self.db.settings.wishlistAnnounce then
        return
    end
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        return
    end
    self.wishlistState = self.wishlistState or {}
    self.wishlistState.announceQueue = self.wishlistState.announceQueue or {}
    self.wishlistState.announcedItems = self.wishlistState.announcedItems or {}
    if self.wishlistState.announcedItems[itemId] then
        return
    end
    table.insert(self.wishlistState.announceQueue, itemLink)
    self.wishlistState.announcedItems[itemId] = true
    local now = GetTime and GetTime() or 0
    if self.wishlistState.announceNextFlush == 0 or now >= self.wishlistState.announceNextFlush then
        self.wishlistState.announceNextFlush = now + 0.5
        self:Delay(0.6, function()
            self:FlushWishlistAnnouncements()
        end)
    end
end

function Goals:FlushWishlistAnnouncements()
    local settings = self.db and self.db.settings or {}
    if not settings.wishlistAnnounce then
        return
    end
    local queue = self.wishlistState and self.wishlistState.announceQueue or {}
    if not queue or #queue == 0 then
        return
    end
    local channel = settings.wishlistAnnounceChannel or "AUTO"
    if channel == "AUTO" then
        if self:IsInRaid() then
            channel = "RAID"
        elseif self:IsInParty() then
            channel = "PARTY"
        else
            channel = "SAY"
        end
    end
    local template = settings.wishlistAnnounceTemplate or "%s is on my wishlist"
    local idx = 1
    while idx <= #queue do
        local slice = { queue[idx] }
        if queue[idx + 1] then
            table.insert(slice, queue[idx + 1])
        end
        if queue[idx + 2] then
            table.insert(slice, queue[idx + 2])
        end
        local itemText = table.concat(slice, ", ")
        local msg = string.format(template, itemText)
        SendChatMessage(msg, channel)
        idx = idx + #slice
    end
    self.wishlistState.announceQueue = {}
end

function Goals:WishlistContainsItem(itemId)
    local list = self:GetActiveWishlist()
    if not list or not itemId then
        return false
    end
    for _, entry in pairs(list.items or {}) do
        if entry and (entry.itemId == itemId or entry.tokenId == itemId) then
            return true
        end
    end
    return false
end

function Goals:HandleWishlistLoot(itemLink)
    if not itemLink then
        return
    end
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        return
    end
    if self:WishlistContainsItem(itemId) then
        self:EnqueueWishlistAnnounce(itemLink)
    end
end

function Goals:BuildWishlistItemCache()
    self.itemCache = self.itemCache or {}
    local list = self:GetActiveWishlist()
    if list and list.items then
        for _, entry in pairs(list.items) do
            if entry and entry.itemId then
                self:CacheItemById(entry.itemId)
            end
            if entry and entry.gemIds then
                for _, gemId in ipairs(entry.gemIds) do
                    self:CacheItemById(gemId)
                end
            end
        end
    end
    if self.db and self.db.history then
        for _, entry in ipairs(self.db.history) do
            if entry and entry.data and entry.data.item then
                self:CacheItemByLink(entry.data.item)
            end
        end
    end
end

function Goals:MapEquipSlotToGroup(equipSlot)
    local map = {
        INVTYPE_HEAD = "HEAD",
        INVTYPE_NECK = "NECK",
        INVTYPE_SHOULDER = "SHOULDER",
        INVTYPE_CLOAK = "BACK",
        INVTYPE_CHEST = "CHEST",
        INVTYPE_ROBE = "CHEST",
        INVTYPE_WRIST = "WRIST",
        INVTYPE_HAND = "HANDS",
        INVTYPE_WAIST = "WAIST",
        INVTYPE_LEGS = "LEGS",
        INVTYPE_FEET = "FEET",
        INVTYPE_FINGER = "RING",
        INVTYPE_TRINKET = "TRINKET",
        INVTYPE_WEAPON = "MAINHAND",
        INVTYPE_WEAPONMAINHAND = "MAINHAND",
        INVTYPE_2HWEAPON = "MAINHAND",
        INVTYPE_WEAPONOFFHAND = "OFFHAND",
        INVTYPE_SHIELD = "OFFHAND",
        INVTYPE_HOLDABLE = "OFFHAND",
        INVTYPE_RANGED = "RELIC",
        INVTYPE_RANGEDRIGHT = "RELIC",
        INVTYPE_RELIC = "RELIC",
    }
    return map[equipSlot]
end

function Goals:GuessWishlistSlot(itemId)
    if not itemId then
        return nil
    end
    local cached = self:CacheItemById(itemId)
    local equipSlot = cached and cached.equipSlot or nil
    local group = equipSlot and self:MapEquipSlotToGroup(equipSlot) or nil
    if not group then
        return nil
    end
    local list = self:GetActiveWishlist()
    local items = list and list.items or {}
    if group == "RING" then
        if not items.RING1 then
            return "RING1"
        end
        if not items.RING2 then
            return "RING2"
        end
        return "RING1"
    end
    if group == "TRINKET" then
        if not items.TRINKET1 then
            return "TRINKET1"
        end
        if not items.TRINKET2 then
            return "TRINKET2"
        end
        return "TRINKET1"
    end
    return group
end

function Goals:SetWishlistItemSmart(slotKey, itemData)
    if not itemData or not itemData.itemId then
        return
    end
    local desired = slotKey
    local guessed = self:GuessWishlistSlot(itemData.itemId)
    if guessed and guessed ~= desired then
        desired = guessed
    end
    self:SetWishlistItem(desired, itemData)
end

function Goals:HasAtlasLootEnhanced()
    return _G.AtlasLoot or _G.AtlasLootEnhanced or _G.AtlasLootWishList or _G.AtlasLootWishListDB
end

local function collectItemIdsFromTable(tbl, out, depth, maxNodes)
    if type(tbl) ~= "table" then
        return
    end
    depth = depth or 0
    if depth > 6 then
        return
    end
    local nodes = 0
    for key, value in pairs(tbl) do
        nodes = nodes + 1
        if nodes > maxNodes then
            return
        end
        if type(value) == "number" then
            if value > 0 then
                out[value] = true
            end
        elseif type(value) == "string" then
            local id = value:match("item:(%d+)")
            if id then
                out[tonumber(id)] = true
            end
        elseif type(value) == "table" then
            collectItemIdsFromTable(value, out, depth + 1, maxNodes)
        elseif type(key) == "number" then
            if key > 0 and (type(value) == "boolean" or value == nil) then
                out[key] = true
            end
        elseif type(key) == "string" and type(value) == "table" then
            collectItemIdsFromTable(value, out, depth + 1, maxNodes)
        end
    end
end

function Goals:CollectAtlasLootWishlists()
    local candidates = {
        AtlasLootWishList = _G.AtlasLootWishList,
        AtlasLootWishListDB = _G.AtlasLootWishListDB,
        AtlasLootCharDB = _G.AtlasLootCharDB,
        AtlasLoot = _G.AtlasLoot,
    }
    local lists = {}
    local playerName = self:GetPlayerName()

    local function addList(name, tbl)
        local items = {}
        collectItemIdsFromTable(tbl, items, 0, 2000)
        local ids = {}
        for itemId in pairs(items) do
            table.insert(ids, itemId)
        end
        if #ids > 0 then
            table.sort(ids)
            table.insert(lists, {
                key = name,
                name = name,
                items = ids,
                score = (playerName ~= "" and name:find(playerName, 1, true)) and 1 or 0,
            })
        end
    end

    local function scanTable(rootName, tbl, depth)
        if type(tbl) ~= "table" or depth > 3 then
            return
        end
        local hasSubtables = false
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                hasSubtables = true
                local childName = rootName .. "/" .. tostring(key)
                scanTable(childName, value, depth + 1)
            end
        end
        if not hasSubtables then
            addList(rootName, tbl)
        end
    end

    for name, tbl in pairs(candidates) do
        if type(tbl) == "table" then
            scanTable(name, tbl, 0)
        end
    end

    table.sort(lists, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)
    return lists
end

function Goals:GetAtlasLootWishlistSelection()
    local lists = self:CollectAtlasLootWishlists()
    local selected = nil
    local selectedKey = self.db and self.db.settings and self.db.settings.atlasSelectedListKey
    if selectedKey and selectedKey ~= "" then
        for _, entry in ipairs(lists) do
            if entry.key == selectedKey then
                selected = entry
                break
            end
        end
    end
    return lists, selected
end

function Goals:ImportAtlasLootWishlist(listKey)
    local lists = self:CollectAtlasLootWishlists()
    if #lists == 0 then
        return false, "No AtlasLoot wishlist items found."
    end
    local selected = nil
    if listKey and listKey ~= "" then
        for _, entry in ipairs(lists) do
            if entry.key == listKey then
                selected = entry
                break
            end
        end
    end
    if not selected then
        return false, "No AtlasLoot wishlist selected."
    end
    local ids = selected.items or {}
    local imported = 0
    for _, itemId in ipairs(ids) do
        if self:IsEquippableItemId(itemId) then
            local slotKey = self:GuessWishlistSlot(itemId)
            if slotKey then
                self:SetWishlistItemSmart(slotKey, {
                    itemId = itemId,
                    enchantId = 0,
                    gemIds = {},
                    notes = "Imported from AtlasLoot",
                    source = "AtlasLoot",
                })
                imported = imported + 1
            end
        end
    end
    if imported == 0 then
        return false, "No equippable AtlasLoot items to import."
    end
    self:NotifyDataChanged()
    return true, string.format("Imported %d AtlasLoot items from %s.", imported, selected.name or "AtlasLoot")
end
function Goals:MatchesSlotFilter(filterKey, equipSlot)
    if not filterKey or filterKey == "" or filterKey == "ALL" then
        return true
    end
    local group = self:MapEquipSlotToGroup(equipSlot)
    if not group then
        return false
    end
    if group == "RING" then
        return filterKey == "RING1" or filterKey == "RING2"
    end
    if group == "TRINKET" then
        return filterKey == "TRINKET1" or filterKey == "TRINKET2"
    end
    return group == filterKey
end

function Goals:TooltipHasText(itemLink, needle)
    if not needle or needle == "" then
        return true
    end
    if not itemLink then
        return false
    end
    self.statsTooltip = self.statsTooltip or CreateFrame("GameTooltip", "GoalsStatsTooltip", UIParent, "GameTooltipTemplate")
    local tooltip = self.statsTooltip
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    local lowerNeedle = string.lower(needle)
    for i = 1, tooltip:NumLines() do
        local line = _G["GoalsStatsTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and string.find(string.lower(text), lowerNeedle, 1, true) then
                tooltip:Hide()
                return true
            end
        end
    end
    tooltip:Hide()
    return false
end

function Goals:SearchWishlistItems(query, filters)
    self:BuildWishlistItemCache()
    local results = {}
    local clean = query and tostring(query) or ""
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    local queryLower = string.lower(clean)
    local filterSlot = filters and filters.slotKey or "ALL"
    local minLevel = filters and tonumber(filters.minLevel) or 0
    local statsNeedle = filters and filters.stats or ""
    local sourceNeedle = filters and filters.source or ""
    local function addResult(itemId, itemLink)
        local cached = self:CacheItemById(itemId)
        if cached then
            if not self:IsEquippableSlot(cached.equipSlot) then
                return
            end
            if minLevel > 0 and (cached.level or 0) < minLevel then
                return
            end
            if not self:MatchesSlotFilter(filterSlot, cached.equipSlot) then
                return
            end
            if sourceNeedle ~= "" and not self:TooltipHasText(cached.link, sourceNeedle) then
                return
            end
            if statsNeedle ~= "" and not self:TooltipHasText(cached.link, statsNeedle) then
                return
            end
            table.insert(results, cached)
        else
            if not self:IsEquippableItemId(itemId) then
                return
            end
            table.insert(results, {
                id = itemId,
                name = "Item " .. tostring(itemId),
                link = itemLink,
                quality = 1,
                level = 0,
                equipSlot = nil,
                texture = nil,
                pending = true,
            })
        end
    end
    local itemId = tonumber(clean)
    if itemId and itemId > 0 then
        addResult(itemId)
        return results
    end
    local linkId = self:GetItemIdFromLink(clean)
    if linkId then
        addResult(linkId, clean)
        return results
    end
    local itemIdFromString = clean:match("item:(%d+)")
    if itemIdFromString then
        addResult(tonumber(itemIdFromString), clean)
        return results
    end
    for _, cached in pairs(self.itemCache or {}) do
        if cached and cached.name and self:IsEquippableSlot(cached.equipSlot) then
            if queryLower == "" or string.find(string.lower(cached.name), queryLower, 1, true) then
                if self:MatchesSlotFilter(filterSlot, cached.equipSlot) and (minLevel == 0 or (cached.level or 0) >= minLevel) then
                    if (statsNeedle == "" or self:TooltipHasText(cached.link, statsNeedle)) and (sourceNeedle == "" or self:TooltipHasText(cached.link, sourceNeedle)) then
                        table.insert(results, cached)
                    end
                end
            end
        end
    end
    table.sort(results, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return results
end

function Goals:DecodeBase64(input)
    if not input or input == "" then
        return ""
    end
    input = input:gsub("[^%w%+%/%=]", "")
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local t = {}
    local function decodeChar(x)
        if x == "=" then
            return nil
        end
        return b:find(x, 1, true) - 1
    end
    local i = 1
    while i <= #input do
        local c1 = decodeChar(input:sub(i, i)); i = i + 1
        local c2 = decodeChar(input:sub(i, i)); i = i + 1
        local c3 = decodeChar(input:sub(i, i)); i = i + 1
        local c4 = decodeChar(input:sub(i, i)); i = i + 1
        if not c1 or not c2 then
            break
        end
        local n1 = (c1 * 4) + math.floor(c2 / 16)
        table.insert(t, string.char(n1))
        if c3 then
            local n2 = ((c2 % 16) * 16) + math.floor(c3 / 4)
            table.insert(t, string.char(n2))
        end
        if c4 then
            local n3 = ((c3 % 4) * 64) + c4
            table.insert(t, string.char(n3))
        end
    end
    return table.concat(t)
end

function Goals:DecodeJson(text)
    local pos = 1
    local function skipWhitespace()
        while true do
            local c = text:sub(pos, pos)
            if c == " " or c == "\n" or c == "\r" or c == "\t" then
                pos = pos + 1
            else
                break
            end
        end
    end
    local function parseString()
        pos = pos + 1
        local result = {}
        while pos <= #text do
            local c = text:sub(pos, pos)
            if c == "\"" then
                pos = pos + 1
                return table.concat(result)
            elseif c == "\\" then
                local nextChar = text:sub(pos + 1, pos + 1)
                if nextChar == "\"" or nextChar == "\\" or nextChar == "/" then
                    table.insert(result, nextChar)
                    pos = pos + 2
                elseif nextChar == "b" then
                    table.insert(result, "\b")
                    pos = pos + 2
                elseif nextChar == "f" then
                    table.insert(result, "\f")
                    pos = pos + 2
                elseif nextChar == "n" then
                    table.insert(result, "\n")
                    pos = pos + 2
                elseif nextChar == "r" then
                    table.insert(result, "\r")
                    pos = pos + 2
                elseif nextChar == "t" then
                    table.insert(result, "\t")
                    pos = pos + 2
                else
                    pos = pos + 2
                end
            else
                table.insert(result, c)
                pos = pos + 1
            end
        end
        return nil
    end
    local function parseNumber()
        local startPos = pos
        while pos <= #text do
            local char = text:sub(pos, pos)
            if not char:match("[%d%+%-%eE%.]") then
                break
            end
            pos = pos + 1
        end
        local num = tonumber(text:sub(startPos, pos - 1))
        return num
    end
    local function parseValue()
        skipWhitespace()
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            while pos <= #text do
                skipWhitespace()
                local key = parseString()
                skipWhitespace()
                pos = pos + 1
                local value = parseValue()
                obj[key] = value
                skipWhitespace()
                local sep = text:sub(pos, pos)
                if sep == "}" then
                    pos = pos + 1
                    break
                end
                pos = pos + 1
            end
            return obj
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if text:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            local i = 1
            while pos <= #text do
                arr[i] = parseValue()
                i = i + 1
                skipWhitespace()
                local sep = text:sub(pos, pos)
                if sep == "]" then
                    pos = pos + 1
                    break
                end
                pos = pos + 1
            end
            return arr
        elseif c == "\"" then
            return parseString()
        elseif c == "t" and text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif c == "f" and text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif c == "n" and text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        else
            return parseNumber()
        end
    end
    skipWhitespace()
    local ok, result = pcall(parseValue)
    if not ok then
        return nil, "Failed to parse JSON."
    end
    return result, nil
end

local function normalizeSlotKey(slotValue)
    if not slotValue then
        return nil
    end
    local text = tostring(slotValue):lower()
    text = text:gsub("slot", "")
    text = text:gsub("%s+", "")
    if text == "head" then return "HEAD" end
    if text == "neck" then return "NECK" end
    if text == "shoulder" or text == "shoulders" then return "SHOULDER" end
    if text == "back" or text == "cloak" then return "BACK" end
    if text == "chest" or text == "robe" then return "CHEST" end
    if text == "wrist" then return "WRIST" end
    if text == "hands" or text == "hand" then return "HANDS" end
    if text == "waist" or text == "belt" then return "WAIST" end
    if text == "legs" then return "LEGS" end
    if text == "feet" or text == "boots" then return "FEET" end
    if text == "ring1" or text == "finger1" then return "RING1" end
    if text == "ring2" or text == "finger2" then return "RING2" end
    if text == "trinket1" then return "TRINKET1" end
    if text == "trinket2" then return "TRINKET2" end
    if text == "mainhand" or text == "mainhandweapon" then return "MAINHAND" end
    if text == "offhand" or text == "secondaryhand" then return "OFFHAND" end
    if text == "relic" or text == "ranged" then return "RELIC" end
    return nil
end

local function slotIdToKey(slotId)
    local map = {
        [1] = "HEAD",
        [2] = "NECK",
        [3] = "SHOULDER",
        [5] = "CHEST",
        [6] = "WAIST",
        [7] = "LEGS",
        [8] = "FEET",
        [9] = "WRIST",
        [10] = "HANDS",
        [11] = "RING1",
        [12] = "RING2",
        [13] = "TRINKET1",
        [14] = "TRINKET2",
        [15] = "BACK",
        [16] = "MAINHAND",
        [17] = "OFFHAND",
        [18] = "RELIC",
    }
    return map[slotId]
end

function Goals:ExtractWowheadItems(payload)
    local items = {}
    if type(payload) ~= "table" then
        return items
    end
    local list = payload.items or payload.gear or payload.slots or payload
    if type(list) ~= "table" then
        return items
    end
    local function handleEntry(entry, slotKeyFromMap)
        if type(entry) ~= "table" then
            return
        end
        local itemId = entry.id or entry.item or entry.itemId or entry.item_id
        local slotKey = normalizeSlotKey(entry.slot or entry.slotName or entry.name)
        if not slotKey and entry.slotId then
            slotKey = slotIdToKey(tonumber(entry.slotId))
        end
        if not slotKey and entry.slot then
            slotKey = slotIdToKey(tonumber(entry.slot))
        end
        if not slotKey and slotKeyFromMap then
            slotKey = slotIdToKey(tonumber(slotKeyFromMap))
        end
        if slotKey and itemId then
            local gems = entry.gems or entry.gemIds or {}
            local gemIds = {}
            if type(gems) == "table" then
                for _, gem in ipairs(gems) do
                    local gemId = tonumber(gem)
                    if gemId and gemId > 0 then
                        table.insert(gemIds, gemId)
                    end
                end
                if #gemIds == 0 then
                    for _, gem in pairs(gems) do
                        local gemId = tonumber(gem)
                        if gemId and gemId > 0 then
                            table.insert(gemIds, gemId)
                        end
                    end
                end
            end
            local item = {
                slotKey = slotKey,
                itemId = tonumber(itemId) or 0,
                enchantId = tonumber(entry.enchant or entry.enchantId or entry.enchantID) or 0,
                gemIds = gemIds,
                source = "Wowhead",
            }
            table.insert(items, item)
        end
    end
    if #list > 0 then
        for _, entry in ipairs(list) do
            handleEntry(entry)
        end
    else
        for slotKey, entry in pairs(list) do
            handleEntry(entry, slotKey)
        end
    end
    return items
end

function Goals:ImportWowhead(text)
    if not text or text == "" then
        return nil, "Empty import text."
    end
    local jsonText = nil
    if text:find("{") then
        jsonText = text
    else
        local data = text:match("data=([^&]+)")
        if data then
            data = data:gsub("%%2B", "+")
            data = data:gsub("%%2F", "/")
            data = data:gsub("%%3D", "=")
            jsonText = self:DecodeBase64(data)
        end
    end
    if jsonText then
        local decoded, err = self:DecodeJson(jsonText)
        if not decoded then
            return nil, err or "Could not parse JSON."
        end
        local items = self:ExtractWowheadItems(decoded)
        if #items > 0 then
            return items, nil
        end
    end
    local itemsParam = text:match("items=([^&]+)")
    if itemsParam then
        local items = {}
        for chunk in string.gmatch(itemsParam, "([^;]+)") do
            local slotId, itemId, enchantId, gems = chunk:match("(%d+):(%d+):?(%d*):?(.*)")
            local slotKey = slotIdToKey(tonumber(slotId))
            if slotKey and itemId then
                local gemIds = {}
                for gem in string.gmatch(gems or "", "([^,]+)") do
                    local gemId = tonumber(gem)
                    if gemId and gemId > 0 then
                        table.insert(gemIds, gemId)
                    end
                end
                table.insert(items, {
                    slotKey = slotKey,
                    itemId = tonumber(itemId) or 0,
                    enchantId = tonumber(enchantId) or 0,
                    gemIds = gemIds,
                    source = "Wowhead",
                })
            end
        end
        if #items > 0 then
            return items, nil
        end
    end
    return nil, "No recognizable Wowhead data found."
end

function Goals:ApplyImportedWishlistItems(items, targetListId)
    if type(items) ~= "table" then
        return false, "No items to import."
    end
    local list = targetListId and self:GetWishlistById(targetListId) or self:GetActiveWishlist()
    if not list then
        return false, "No active wishlist."
    end
    local missingItems, unknownGems, unknownEnchants = 0, 0, 0
    for _, entry in ipairs(items) do
        if entry.slotKey and entry.itemId and entry.itemId > 0 then
            local gemIds = entry.gemIds or {}
            for _, gemId in ipairs(gemIds) do
                if not self:CacheItemById(gemId) then
                    unknownGems = unknownGems + 1
                end
            end
            if entry.enchantId and entry.enchantId > 0 then
                unknownEnchants = unknownEnchants + 1
            end
            if not self:CacheItemById(entry.itemId) then
                missingItems = missingItems + 1
            end
            list.items = list.items or {}
            local tokenId = self:GetArmorTokenForItem(entry.itemId) or 0
            list.items[entry.slotKey] = {
                itemId = entry.itemId,
                enchantId = entry.enchantId or 0,
                gemIds = gemIds,
                notes = entry.notes or "",
                source = entry.source or "Import",
                tokenId = tokenId,
            }
        else
            missingItems = missingItems + 1
        end
    end
    list.updated = time()
    self:NotifyDataChanged()
    local summary = string.format("Imported %d items (%d missing, %d unknown enchants, %d unknown gems).", #items, missingItems, unknownEnchants, unknownGems)
    return true, summary
end

function Goals:SelectSaveTable(name)
    if not self.dbRoot then
        return
    end
    local tableData = self:EnsureSaveTable(name)
    if not tableData then
        return
    end
    self.dbRoot.activeTableName = name
    self.db = tableData
    self:EnsureWishlistData()
end

function Goals:SaveCurrentTableAs(name)
    if not self.dbRoot or not self.db or not name or name == "" then
        return
    end
    local target = self:EnsureSaveTable(name)
    if not target then
        return
    end
    self:CopyTableData(self.db, target)
    self:Print("Saving Table: " .. name)
end

function Goals:FindLatestTableForPlayer(name)
    if not self.dbRoot or not self.dbRoot.tables then
        return nil
    end
    local key = self:NormalizeName(name or "")
    if key == "" then
        return nil
    end
    local latestTable
    local latestTs = 0
    for _, tableData in pairs(self.dbRoot.tables) do
        local players = tableData.players or {}
        if players[key] and (tableData.lastUpdated or 0) > latestTs then
            latestTable = tableData
            latestTs = tableData.lastUpdated or 0
        end
    end
    return latestTable
end

function Goals:GetSeenPlayersSnapshot()
    local snapshot = {}
    if not self.dbRoot or not self.dbRoot.tables then
        return snapshot
    end
    for _, tableData in pairs(self.dbRoot.tables) do
        local updated = tableData.lastUpdated or 0
        for playerName, data in pairs(tableData.players or {}) do
            local existing = snapshot[playerName]
            if not existing or (existing.updated or 0) < updated then
                snapshot[playerName] = {
                    points = data.points or 0,
                    class = data.class,
                    updated = updated,
                }
            end
        end
    end
    return snapshot
end

function Goals:MergeSeenPlayersIntoCurrent()
    if not self.db or not self.db.players then
        return
    end
    local snapshot = self:GetSeenPlayersSnapshot()
    for name, data in pairs(snapshot) do
        self.db.players[name] = { points = data.points or 0, class = data.class or "UNKNOWN" }
    end
    self:NotifyDataChanged()
end

function Goals:MergeSeenPlayersForGroup()
    if not self.db or not self.db.players then
        return
    end
    if not (self.db.settings and self.db.settings.tableAutoLoadSeen) then
        return
    end
    local members = self.GetGroupMembers and self:GetGroupMembers() or {}
    if #members == 0 then
        return
    end
    local snapshot = self:GetSeenPlayersSnapshot()
    local changed = false
    for _, info in ipairs(members) do
        local name = self:NormalizeName(info.name)
        if name ~= "" and not self.db.players[name] then
            local seen = snapshot[name]
            if seen then
                self.db.players[name] = { points = seen.points or 0, class = seen.class or info.class or "UNKNOWN" }
                changed = true
            end
        end
    end
    if changed then
        self:NotifyDataChanged()
    end
end

function Goals:GetCombinedPlayers()
    local combined = {}
    if not self.dbRoot or not self.dbRoot.tables then
        return combined
    end
    for _, tableData in pairs(self.dbRoot.tables) do
        for name, data in pairs(tableData.players or {}) do
            local entry = combined[name]
            if not entry then
                entry = { points = 0, class = data.class }
                combined[name] = entry
            end
            entry.points = (entry.points or 0) + (data.points or 0)
            if not entry.class and data.class then
                entry.class = data.class
            end
        end
    end
    return combined
end

function Goals:ToggleUI()
    if self.UI then
        self.UI:Toggle()
    end
end

function Goals:InitSlashCommands()
    SLASH_GOALS1 = "/goals"
    SLASH_GOALS2 = "/dkp"
    SLASH_GOALS3 = "/goalsui"
    SlashCmdList["GOALS"] = function(msg)
        local cmd = msg and msg:lower() or ""
        if cmd:match("^mini") then
            if self.UI and self.UI.ToggleMiniTracker then
                self.UI:ToggleMiniTracker()
            end
            return
        end
        self:ToggleUI()
    end
end

function Goals:Init()
    if self.initialized then
        return
    end
    self.initialized = true
    if self.InitDB then
        self:InitDB()
    end
    self.dbRoot = self.db
    if self.dbRoot and not self.dbRoot.tables then
        self.dbRoot.tables = {}
    end
    local playerName = self:GetPlayerName()
    if self.dbRoot and (not self.dbRoot.activeTableName or self.dbRoot.activeTableName == "") then
        self.dbRoot.activeTableName = playerName
    end
    if self.dbRoot and self.dbRoot.tables and not next(self.dbRoot.tables) then
        local initial = {
            players = self.dbRoot.players or {},
            history = self.dbRoot.history or {},
            settings = self.dbRoot.settings or {},
            wishlists = self.dbRoot.wishlists or {},
            debugLog = {},
            lastUpdated = time(),
        }
        self.dbRoot.tables[playerName] = initial
    end
    self:SelectSaveTable(playerName)
    self:EnsureWishlistData()
    if not self.linkHooked and hooksecurefunc then
        self.linkHooked = true
        hooksecurefunc("SetItemRef", function(link)
            if link and link:find("^item:") then
                Goals:CacheItemByLink(link)
            end
        end)
    end
    if self.db and self.db.settings then
        local installed = self:GetInstalledUpdateVersion()
        if (self.db.settings.updateAvailableVersion or 0) < installed then
            self.db.settings.updateAvailableVersion = 0
        end
        if self.db.settings.updateSeenVersion == nil then
            self.db.settings.updateSeenVersion = installed
        end
        if self.db.settings.updateHasBeenSeen == nil then
            self.db.settings.updateHasBeenSeen = false
        end
    end
    self:EnsureGroupMembers()
    self:InitSlashCommands()
    self:CheckBuild()
    if self.Dev and self.Dev.Init then
        self.Dev:Init()
    end
    if self.History and self.History.Init then
        self.History:Init(self.db)
    end
    if self.Comm and self.Comm.Init then
        self.Comm:Init()
    end
    if self.Events and self.Events.Init then
        self.Events:Init()
    end
    if self.UI and self.UI.Init then
        self.UI:Init()
    end
    self:UpdateSyncStatus()
    self:Debug("Loaded v" .. self.version)
end

function Goals:CheckBuild()
    if not GetBuildInfo then
        return
    end
    local _, build, _, toc = GetBuildInfo()
    local buildOk = tostring(build or "") == "12340"
    local tocOk = tonumber(toc or 0) == 30300
    if not buildOk or not tocOk then
        self:Debug("Warning: Goals targets Wrath 3.3.5a (build 12340).")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Goals:Init()
end)
