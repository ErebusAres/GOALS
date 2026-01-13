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
    return self:IsSyncMaster() or (self.Dev and self.Dev.enabled)
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
                    if self.Comm and (self:IsSyncMaster() or (self.IsGroupLeader and self:IsGroupLeader()) or (self.Dev and self.Dev.enabled)) then
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
        return { players = {}, history = {}, settings = {}, debugLog = {}, lastUpdated = time() }
    end
    tableData.players = tableData.players or {}
    tableData.history = tableData.history or {}
    tableData.settings = tableData.settings or {}
    tableData.debugLog = tableData.debugLog or {}
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
    target.debugLog = {}
    target.lastUpdated = time()
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
            debugLog = {},
            lastUpdated = time(),
        }
        self.dbRoot.tables[playerName] = initial
    end
    self:SelectSaveTable(playerName)
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
