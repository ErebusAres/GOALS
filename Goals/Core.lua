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

local function prefixMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGoals|r: " .. msg)
end

function Goals:Print(msg)
    if msg then
        prefixMessage(msg)
    end
end

function Goals:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debug and msg then
        prefixMessage("|cff999999DEBUG|r " .. msg)
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
    return GetNumRaidMembers and GetNumRaidMembers() > 0
end

function Goals:IsInParty()
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
    if self:IsInParty() then
        return 0
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
        local index = self:GetSelfLootIndex()
        if index == nil then
            return false, "Unable to determine loot master index."
        end
        SetLootMethod("master", index)
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
    if self:IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            local name, _, rank = GetRaidRosterInfo(i)
            if rank == 2 then
                return self:NormalizeName(name)
            end
        end
    elseif self:IsInParty() then
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
    if self:IsInRaid() or self:IsInParty() then
        return self:IsGroupLeader()
    end
    return self.Dev and self.Dev.enabled or false
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

function Goals:UpdateSyncStatus()
    if self:IsSyncMaster() then
        self.sync.isMaster = true
        self.sync.masterName = self:GetPlayerName()
        self.sync.status = "Master (You)"
    elseif self:IsInRaid() or self:IsInParty() then
        local leader = self:GetLeaderName() or "Unknown"
        self.sync.isMaster = false
        self.sync.masterName = leader
        self.sync.status = "Following " .. leader
    else
        self.sync.isMaster = false
        self.sync.masterName = nil
        self.sync.status = "Solo"
    end
    if self.UI and self.UI.RefreshStatus then
        self.UI:RefreshStatus()
    end
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
    if key == "" then
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
    if self:IsSyncMaster() and not skipSync and self.Comm then
        self.Comm:SendSetting(key, value)
    end
end

function Goals:SetDisenchanter(name, skipSync)
    local normalized = self:NormalizeName(name or "")
    self.db.settings.disenchanter = normalized
    self:NotifyDataChanged()
    if self:IsSyncMaster() and not skipSync and self.Comm then
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
    if self:IsSyncMaster() and not skipSync and self.Comm then
        self.Comm:SendAdjustment(name, delta, reason)
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
    if self:IsSyncMaster() and not skipSync and self.Comm then
        self.Comm:SendSetPoints(name, points, reason)
    end
end

function Goals:AwardBossKill(encounterName, members, skipSync)
    local roster = members or self:GetGroupMembers()
    if not roster or #roster == 0 then
        return
    end
    local names = {}
    for _, info in ipairs(roster) do
        local entry = self:EnsurePlayer(info.name, info.class)
        if entry then
            entry.points = (entry.points or 0) + 1
            table.insert(names, info.name)
        end
    end
    if self.History then
        self.History:AddBossKill(encounterName, 1, names, self.db.settings.combineBossHistory)
    end
    self:NotifyDataChanged()
    if self:IsSyncMaster() and not skipSync and self.Comm then
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

function Goals:IsMountOrPet(itemType, itemSubType)
    local miscType = MISCELLANEOUS or "Miscellaneous"
    local mountType = MOUNT or "Mount"
    local petType = COMPANION_PETS or "Companion Pets"
    local petTypeAlt = PETS or "Pets"
    if itemType ~= miscType then
        return false
    end
    return itemSubType == mountType or itemSubType == petType or itemSubType == petTypeAlt
end

function Goals:IsQuestItem(itemType)
    local questType = QUESTS or ITEM_CLASS_QUEST or "Quest"
    return itemType == questType
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

function Goals:IsTrackedLootType(itemType, itemSubType, equipSlot)
    local armorType = ARMOR or "Armor"
    local weaponType = WEAPON or "Weapon"
    if self:IsMountOrPet(itemType, itemSubType) then
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
    if not quality or quality < 4 then
        return false
    end
    if not self:IsInRaid() and not (self.Dev and self.Dev.enabled) then
        return false
    end
    return self:IsTrackedLootType(itemType, itemSubType, equipSlot)
end

function Goals:ShouldResetForLoot(itemType, itemSubType, equipSlot)
    local armorType = ARMOR or "Armor"
    local weaponType = WEAPON or "Weapon"
    if self:IsMountOrPet(itemType, itemSubType) then
        return self.db and self.db.settings and self.db.settings.resetMountPet and true or false
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
    local shouldReset = shouldTrack and self:ShouldResetForLoot(itemType, itemSubType, equipSlot)
    local resetApplied = shouldReset and not self:IsDisenchanter(playerName)
    if forceRecord or shouldTrack then
        self:RecordLootAssignment(playerName, itemLink, resetApplied)
        if self:IsSyncMaster() and not skipSync and self.Comm then
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
    if self.History then
        self.History:AddLootFound(itemLink)
    end
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
    local count = GetNumLootItems and GetNumLootItems() or 0
    for slot = 1, count do
        if GetLootSlotType and GetLootSlotType(slot) == 1 then
            local link = GetLootSlotLink(slot)
            if link then
                table.insert(list, {
                    slot = slot,
                    link = link,
                    ts = time(),
                    assignedTo = nil,
                })
                if seen[slot] ~= link then
                    seen[slot] = link
                    self:RecordLootFound(link)
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
    self:NotifyDataChanged()
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

function Goals:AssignLootSlot(slot, targetName, itemLink)
    if not slot or not targetName or targetName == "" then
        return
    end
    if not self:IsMasterLooter() and not (self.Dev and self.Dev.enabled) then
        return
    end
    local index = self:GetLootTargetIndex(targetName)
    if index == nil then
        return
    end
    if GiveMasterLoot and slot > 0 then
        GiveMasterLoot(slot, index)
    end
    local link = itemLink or (GetLootSlotLink and GetLootSlotLink(slot) or nil)
    if self.state.lootFound then
        for _, entry in ipairs(self.state.lootFound) do
            if entry.slot == slot then
                entry.assignedTo = self:NormalizeName(targetName)
                break
            end
        end
    end
    if link then
        self:HandleLootAssignment(targetName, link, false, true)
    end
    self:NotifyDataChanged()
end

function Goals:RecordLootAssignment(playerName, itemLink, resetApplied)
    self.state.lastLoot = { name = playerName, link = itemLink, ts = time() }
    if self.History then
        self.History:AddLootAssigned(playerName, itemLink, resetApplied)
    end
end

function Goals:ApplyLootAssignment(playerName, itemLink)
    self:RecordLootAssignment(playerName, itemLink, false)
    self:NotifyDataChanged()
end

function Goals:ApplyLootReset(playerName, itemLink)
    self:RecordLootAssignment(playerName, itemLink, true)
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
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
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
    SlashCmdList["GOALS"] = function()
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
    self:Print("Loaded v" .. self.version)
end

function Goals:CheckBuild()
    if not GetBuildInfo then
        return
    end
    local _, build, _, toc = GetBuildInfo()
    local buildOk = tostring(build or "") == "12340"
    local tocOk = tonumber(toc or 0) == 30300
    if not buildOk or not tocOk then
        self:Print("Warning: Goals targets Wrath 3.3.5a (build 12340).")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Goals:Init()
end)
