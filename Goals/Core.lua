-- Goals: Core.lua
-- Bootstrap, shared helpers, and public API.
-- Usage:
--   Goals:ToggleUI()
--   Goals:AdjustPoints("Player", 1, "Manual award")

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

if not _G.BINDING_HEADER_GOALS then
    _G.BINDING_HEADER_GOALS = "GOALS"
end
if not _G.BINDING_NAME_GOALS_TOGGLE_UI then
    _G.BINDING_NAME_GOALS_TOGGLE_UI = "Toggle GOALS UI"
end
if not _G.BINDING_NAME_GOALS_TOGGLE_MINI then
    _G.BINDING_NAME_GOALS_TOGGLE_MINI = "Toggle Mini Viewer"
end

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
    buildShareCooldown = {},
    buildReceiveCooldown = {},
    pendingBuildShare = nil,
}
Goals.state.lootFound = Goals.state.lootFound or {}
Goals.state.lootFoundSeen = Goals.state.lootFoundSeen or {}
Goals.state.recentAssignments = Goals.state.recentAssignments or {}
Goals.state.buildShareCooldown = Goals.state.buildShareCooldown or {}
Goals.state.buildReceiveCooldown = Goals.state.buildReceiveCooldown or {}
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

Goals.WishlistExportOrder = Goals.WishlistExportOrder or {
    "HEAD",
    "NECK",
    "SHOULDER",
    "BACK",
    "CHEST",
    "WRIST",
    "HANDS",
    "WAIST",
    "LEGS",
    "FEET",
    "RING1",
    "RING2",
    "TRINKET1",
    "TRINKET2",
    "MAINHAND",
    "OFFHAND",
    "RELIC",
}

Goals.WishlistSlotIndex = Goals.WishlistSlotIndex or {}
for _, entry in ipairs(Goals.WishlistSlots) do
    Goals.WishlistSlotIndex[entry.key] = entry
end

Goals.EnchantableSlots = Goals.EnchantableSlots or {
    HEAD = true,
    SHOULDER = true,
    BACK = true,
    CHEST = true,
    WRIST = true,
    HANDS = true,
    LEGS = true,
    FEET = true,
    MAINHAND = true,
    OFFHAND = true,
    RING1 = true,
    RING2 = true,
}

Goals.SocketTextureMap = Goals.SocketTextureMap or {
    META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
    RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
    YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
    BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
    PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
}

local function prefixMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGoals|r: " .. msg)
end

function Goals:GetClassColor(class)
    local key = class and strupper(class) or "UNKNOWN"
    local color = self.classColors[key] or self.classColors.UNKNOWN
    return color.r, color.g, color.b
end

function Goals:GetOverviewPlayers()
    if self.dbRoot then
        if type(self.dbRoot.players) ~= "table" then
            self.dbRoot.players = {}
        end
        return self.dbRoot.players
    end
    if self.db then
        if type(self.db.players) ~= "table" then
            self.db.players = {}
        end
        return self.db.players
    end
    return {}
end

function Goals:GetOverviewSettings()
    if self.dbRoot then
        if type(self.dbRoot.overviewSettings) ~= "table" then
            self.dbRoot.overviewSettings = {}
        end
        local settings = self.dbRoot.overviewSettings
        if self.CopyDefaults then
            self:CopyDefaults(settings, {
                showPresentOnly = false,
                sortMode = "POINTS",
                disablePointGain = false,
            })
        else
            if settings.showPresentOnly == nil then settings.showPresentOnly = false end
            if settings.sortMode == nil then settings.sortMode = "POINTS" end
            if settings.disablePointGain == nil then settings.disablePointGain = false end
        end
        return settings
    end
    return self.db and self.db.settings or {}
end

function Goals:MergeLegacyOverviewTables()
    if not self.dbRoot or self.dbRoot.overviewMigrated then
        return false
    end
    local merged = {}
    local function applyPlayers(source)
        if type(source) ~= "table" then
            return
        end
        for name, data in pairs(source) do
            local key = self:NormalizeName(name)
            if key ~= "" and key ~= "Unknown" then
                merged[key] = {
                    points = (data and data.points) or 0,
                    class = (data and data.class) or "UNKNOWN",
                }
            end
        end
    end
    applyPlayers(self.dbRoot.players)
    local tables = {}
    for _, tableData in pairs(self.dbRoot.tables or {}) do
        table.insert(tables, tableData)
    end
    table.sort(tables, function(a, b)
        return (a.lastUpdated or 0) < (b.lastUpdated or 0)
    end)
    local latestSettings = nil
    for _, tableData in ipairs(tables) do
        applyPlayers(tableData.players)
        if type(tableData.settings) == "table" then
            latestSettings = tableData.settings
        end
    end
    self.dbRoot.players = merged
    local settingsSource = latestSettings or self.dbRoot.settings
    if type(settingsSource) == "table" then
        local overviewSettings = self:GetOverviewSettings()
        if settingsSource.showPresentOnly ~= nil then
            overviewSettings.showPresentOnly = settingsSource.showPresentOnly
        end
        if settingsSource.sortMode ~= nil then
            overviewSettings.sortMode = settingsSource.sortMode
        end
        if settingsSource.disablePointGain ~= nil then
            overviewSettings.disablePointGain = settingsSource.disablePointGain
        end
    end
    self.dbRoot.overviewMigrated = true
    self.dbRoot.overviewMigrationPending = false
    self.dbRoot.overviewMigrationPrompted = true
    self.dbRoot.overviewLastUpdated = time()
    self:NotifyDataChanged()
    return true
end

function Goals:MaybePromptOverviewMigration()
    if not self.dbRoot or self.dbRoot.overviewMigrated then
        return
    end
    if not self.dbRoot.overviewMigrationPending or self.dbRoot.overviewMigrationPrompted then
        return
    end
    if self.UI and self.UI.ShowOverviewMigrationPrompt then
        self.dbRoot.overviewMigrationPrompted = true
        self.UI:ShowOverviewMigrationPrompt()
    end
end

function Goals:GetPlayerClass(name)
    local players = self:GetOverviewPlayers()
    local entry = players[self:NormalizeName(name)]
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
    local count = #wipeMessages
    if count == 0 then
        self:Print(string.format("%s wiped.", encounterName or "Group"))
        return
    end
    local index = math.random(count)
    local template = wipeMessages[index] or "%s wiped."
    self:Print(string.format(template, encounterName or "Group"))
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
    if name == nil then
        return ""
    end
    if type(name) ~= "string" then
        name = tostring(name)
    end
    if name == "" then
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

function Goals:GetUpdateMajorVersion()
    local info = self.UpdateInfo
    return info and tonumber(info.major) or 2
end

function Goals:GetDisplayVersion()
    local major = self:GetUpdateMajorVersion()
    local minor = self:GetInstalledUpdateVersion()
    return string.format("%d.%d", major, minor)
end

function Goals:IsVersionNewer(majorA, minorA, majorB, minorB)
    majorA = tonumber(majorA) or 0
    minorA = tonumber(minorA) or 0
    majorB = tonumber(majorB) or 0
    minorB = tonumber(minorB) or 0
    if majorA ~= majorB then
        return majorA > majorB
    end
    return minorA > minorB
end

function Goals:HandleRemoteVersion(version, sender)
    if not self.db or not self.db.settings then
        return
    end
    local installedMajor = self:GetUpdateMajorVersion()
    local installedMinor = self:GetInstalledUpdateVersion()
    local incomingMajor, incomingMinor = tostring(version or ""):match("^(%d+)%.(%d+)$")
    incomingMajor = tonumber(incomingMajor) or installedMajor
    incomingMinor = tonumber(incomingMinor) or tonumber(version) or 0
    if not self:IsVersionNewer(incomingMajor, incomingMinor, installedMajor, installedMinor) then
        return
    end
    if self:IsVersionNewer(incomingMajor, incomingMinor, self.db.settings.updateAvailableMajor or 0, self.db.settings.updateAvailableVersion or 0) then
        self.db.settings.updateAvailableMajor = incomingMajor
        self.db.settings.updateAvailableVersion = incomingMinor
        self.db.settings.updateHasBeenSeen = false
        self:NotifyDataChanged()
        local who = sender and self:NormalizeName(sender) or "someone"
        self:Print("Update available (v" .. string.format("%d.%d", incomingMajor, incomingMinor) .. ") from " .. who .. ".")
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
    local players = self:GetOverviewPlayers()
    if key == "" or key == "Unknown" then
        players[key] = nil
        return nil
    end
    local entry = players[key]
    if type(entry) ~= "table" then
        entry = { points = 0, class = class or "UNKNOWN" }
        players[key] = entry
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
    if key == "disablePointGain" then
        local overviewSettings = self:GetOverviewSettings()
        overviewSettings.disablePointGain = value and true or false
    else
        self.db.settings[key] = value
    end
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
    local overviewSettings = self:GetOverviewSettings()
    if delta > 0 and overviewSettings.disablePointGain then
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
    local overviewSettings = self:GetOverviewSettings()
    if overviewSettings.disablePointGain then
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
    local players = self:GetOverviewPlayers()
    local key = self:NormalizeName(name)
    if key == "" then
        return
    end
    if players[key] then
        players[key] = nil
        self.undo[key] = nil
        self:NotifyDataChanged()
    end
end

function Goals:AwardBossKill(encounterName, members, skipSync)
    local roster = members or self:GetGroupMembers()
    if not roster or #roster == 0 then
        return
    end
    if not skipSync and not self:IsSyncMaster() then
        return
    end
    local overviewSettings = self:GetOverviewSettings()
    if overviewSettings.disablePointGain then
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
    if itemType == recipeType then
        return true
    end
    return itemType == "Pattern"
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
    local itemId = self:GetItemIdFromLink(itemLink)
    local shouldTrack = self:ShouldTrackLoot(quality, itemType, itemSubType, equipSlot)
    local shouldReset = shouldTrack and self:ShouldResetForLoot(itemType, itemSubType, equipSlot, quality)
    local isToken = self:IsToken(itemType, itemSubType)
    if shouldReset and itemId then
        local tokenId = self:GetArmorTokenForItem(itemId)
        if tokenId and tokenId ~= itemId then
            shouldReset = false
        end
    end
    if shouldReset and self.db and self.db.settings and self.db.settings.resetRequiresLootWindow then
        if not self:WasLootFound(itemLink) then
            shouldReset = false
        end
    end
    local overviewSettings = self:GetOverviewSettings()
    if overviewSettings.disablePointGain then
        if not isToken then
            shouldReset = false
        end
    end
    local resetApplied = shouldReset and not self:IsDisenchanter(playerName)
    if forceRecord or shouldTrack then
        local before = nil
        if resetApplied then
            local players = self:GetOverviewPlayers()
            local entry = players[self:NormalizeName(playerName)]
            before = entry and entry.points or 0
        end
        self:RecordLootAssignment(playerName, itemLink, resetApplied, before)
        self:RemoveFoundLootByLink(itemLink)
        local canSyncLoot = self:CanSync() or (self:IsMasterLooter() and not self:IsSyncMaster())
        if canSyncLoot and not skipSync and self.Comm then
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

function Goals:HandleManualLootReset(playerName, itemLink, skipSync)
    if not playerName or not itemLink then
        return false
    end
    playerName = self:NormalizeName(playerName)
    self:EnsurePlayer(playerName)
    if self:ShouldSkipLootAssignment(playerName, itemLink) then
        return false
    end
    local players = self:GetOverviewPlayers()
    local entry = players[playerName]
    local before = entry and entry.points or 0
    self:RecordLootAssignment(playerName, itemLink, true, before)
    self:RemoveFoundLootByLink(itemLink)
    self:SetPoints(playerName, 0, "Loot reset: " .. itemLink, true, true)
    self:HandleWishlistLoot(itemLink)
    if self:CanSync() and not skipSync and self.Comm then
        self.Comm:SendLootReset(playerName, itemLink)
    end
    return true
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
    if next(self.state.lootFoundSeenLinks) then
        local now = time()
        for link, ts in pairs(self.state.lootFoundSeenLinks) do
            if (now - (ts or 0)) > 300 then
                self.state.lootFoundSeenLinks[link] = nil
            end
        end
    end
    self.state.lootFoundSeenLinks[itemLink] = time()
    if self.History then
        self.History:AddLootFound(itemLink)
    end
end

function Goals:RemoveFoundLootByLink(itemLink)
    if not itemLink or not self.state.lootFound then
        return
    end
    local removed = false
    for i = #self.state.lootFound, 1, -1 do
        local entry = self.state.lootFound[i]
        if entry and entry.link == itemLink then
            table.remove(self.state.lootFound, i)
            removed = true
        end
    end
    if removed then
        return
    end
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        return
    end
    for i = #self.state.lootFound, 1, -1 do
        local entry = self.state.lootFound[i]
        if entry and entry.link then
            local entryId = self:GetItemIdFromLink(entry.link)
            if entryId and entryId == itemId then
                table.remove(self.state.lootFound, i)
                break
            end
        end
    end
end

function Goals:WasLootFound(itemLink)
    if not itemLink or not self.state.lootFound then
        return false
    end
    for _, entry in ipairs(self.state.lootFound) do
        if entry and entry.link == itemLink then
            return true
        end
    end
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        return false
    end
    for _, entry in ipairs(self.state.lootFound) do
        if entry and entry.link then
            local entryId = self:GetItemIdFromLink(entry.link)
            if entryId and entryId == itemId then
                return true
            end
        end
    end
    return false
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
        local seenAt = self.state.lootFoundSeenIds[key]
        if seenAt and math.abs(now - seenAt) < 120 then
            return
        end
        if next(self.state.lootFoundSeenIds) then
            for seenKey, seenTs in pairs(self.state.lootFoundSeenIds) do
                if (now - (seenTs or 0)) > 300 then
                    self.state.lootFoundSeenIds[seenKey] = nil
                end
            end
        end
        self.state.lootFoundSeenIds[key] = now
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
                    local canSync = self:CanSync() or (self.IsMasterLooter and self:IsMasterLooter())
                    if self.Comm and canSync then
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
    local players = self:GetOverviewPlayers()
    for _, entry in pairs(players) do
        if type(entry) == "table" then
            entry.points = 0
        end
    end
    self.undo = {}
    self:NotifyDataChanged()
end

function Goals:ClearPlayersLocal()
    if not self.dbRoot then
        return
    end
    self.dbRoot.players = {}
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
    self:RemoveFoundLootByLink(itemLink)
    self:HandleWishlistLoot(itemLink)
    self:NotifyDataChanged()
end

function Goals:ApplyLootReset(playerName, itemLink)
    if self:ShouldSkipLootAssignment(playerName, itemLink) then
        return
    end
    local players = self:GetOverviewPlayers()
    local entry = players[self:NormalizeName(playerName)]
    local before = entry and entry.points or 0
    self:RecordLootAssignment(playerName, itemLink, true, before)
    self:RemoveFoundLootByLink(itemLink)
    self:SetPoints(playerName, 0, "Loot reset: " .. itemLink, true, true)
    self:HandleWishlistLoot(itemLink)
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
    if self.dbRoot then
        self.dbRoot.overviewLastUpdated = time()
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
    else
        local baseName = clean
        local maxIndex = -1
        for _, list in ipairs(data.lists) do
            local listName = self:NormalizeWishlistName(list.name or "")
            if listName == baseName then
                maxIndex = math.max(maxIndex, 0)
            else
                local idx = listName:match("^" .. baseName .. " (%d+)$")
                if idx then
                    maxIndex = math.max(maxIndex, tonumber(idx) or -1)
                end
            end
        end
        if maxIndex >= 0 then
            clean = string.format("%s %d", baseName, maxIndex + 1)
        end
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

function Goals:GetDefaultArmorTokenForItem(itemId)
    if not itemId then
        return nil
    end
    if not self.ArmorTokenReverse or not next(self.ArmorTokenReverse) then
        self:RefreshArmorTokenMap()
    end
    return self.ArmorTokenMap[itemId]
end

function Goals:GetArmorTokenForItem(itemId)
    if not itemId then
        return nil
    end
    local defaultToken = self:GetDefaultArmorTokenForItem(itemId)
    local override = self:GetCustomRealmTokenOverride(itemId, defaultToken)
    if override then
        return override
    end
    return defaultToken
end

function Goals:GetCustomRealmTokenOverride(itemId, defaultToken)
    local realm = GetRealmName and GetRealmName() or ""
    if realm == "" or string.lower(realm) ~= "redus" then
        return nil
    end
    local tokenId = defaultToken
    if not tokenId then
        return nil
    end
    local t4Map = {
        [29753] = 29755, [29754] = 29755, [29755] = 29755, -- Chestguard of the Fallen Hero
        [29756] = 29756, [29757] = 29756, [29758] = 29756, -- Gloves of the Fallen Hero
        [29759] = 29759, [29760] = 29759, [29761] = 29759, -- Helm of the Fallen Hero
        [29762] = 29762, [29763] = 29762, [29764] = 29762, -- Pauldrons of the Fallen Hero
        [29765] = 29765, [29766] = 29765, [29767] = 29765, -- Leggings of the Fallen Hero
    }
    local t5Map = {
        [30236] = 30238, [30237] = 30238, [30238] = 30238, -- Chestguard of the Vanquished Hero
        [30239] = 30241, [30240] = 30241, [30241] = 30241, -- Gloves of the Vanquished Hero
        [30242] = 30244, [30243] = 30244, [30244] = 30244, -- Helm of the Vanquished Hero
        [30245] = 30247, [30246] = 30247, [30247] = 30247, -- Leggings of the Vanquished Hero
        [30248] = 30250, [30249] = 30250, [30250] = 30250, -- Pauldrons of the Vanquished Hero
    }
    local t6Map = {
        [31089] = 31091, [31090] = 31091, [31091] = 31091, -- Chestguard of the Forgotten Protector
        [31092] = 31094, [31093] = 31094, [31094] = 31094, -- Gloves of the Forgotten Protector
        [31095] = 31095, [31096] = 31095, [31097] = 31095, -- Helm of the Forgotten Protector
        [31098] = 31100, [31099] = 31100, [31100] = 31100, -- Leggings of the Forgotten Protector
        [31101] = 31103, [31102] = 31103, [31103] = 31103, -- Pauldrons of the Forgotten Protector
    }
    if t4Map[tokenId] then
        return t4Map[tokenId]
    end
    if t5Map[tokenId] then
        return t5Map[tokenId]
    end
    if t6Map[tokenId] then
        return t6Map[tokenId]
    end
    return nil
end

local function gemsEqual(a, b)
    a = a or {}
    b = b or {}
    local maxCount = math.max(#a, #b)
    for i = 1, maxCount do
        local left = tonumber(a[i] or 0) or 0
        local right = tonumber(b[i] or 0) or 0
        if left ~= right then
            return false
        end
    end
    return true
end

function Goals:SetWishlistItem(slotKey, itemData)
    local list = self:GetActiveWishlist()
    if not list or not slotKey or type(itemData) ~= "table" then
        return
    end
    local oldEntry = list.items and list.items[slotKey] or nil
    local oldItemId = oldEntry and tonumber(oldEntry.itemId) or 0
    local oldEnchantId = oldEntry and tonumber(oldEntry.enchantId) or 0
    local oldGems = oldEntry and oldEntry.gemIds or {}
    if itemData.itemId then
        itemData.tokenId = self:GetArmorTokenForItem(itemData.itemId) or 0
    end
    if itemData.found == nil then
        itemData.found = false
    end
    -- Leave manualFound nil by default so ownership auto-detect can apply.
    list.items = list.items or {}
    if oldEntry and oldEntry.itemId and itemData.itemId and oldEntry.itemId ~= itemData.itemId then
        local foundMap = self:GetWishlistFoundMap(list.id)
        if foundMap then
            foundMap[oldEntry.itemId] = nil
            if oldEntry.tokenId then
                foundMap[oldEntry.tokenId] = nil
            end
        end
    end
    list.items[slotKey] = itemData
    local newItemId = tonumber(itemData.itemId) or 0
    local newEnchantId = tonumber(itemData.enchantId) or 0
    local newGems = itemData.gemIds or {}
    if self.History and newItemId > 0 then
        if oldItemId > 0 and oldItemId ~= newItemId then
            self.History:AddWishlistItemRemoved(slotKey, oldItemId)
        end
        if oldItemId ~= newItemId then
            self.History:AddWishlistItemAdded(slotKey, newItemId)
        else
            if oldEnchantId ~= newEnchantId then
                self.History:AddWishlistItemEnchanted(slotKey, newItemId, newEnchantId)
            end
            if not gemsEqual(oldGems, newGems) then
                self.History:AddWishlistItemSocketed(slotKey, newItemId, newGems)
            end
        end
    end
    list.updated = time()
    self:NotifyDataChanged()
end

function Goals:ClearWishlistItem(slotKey)
    local list = self:GetActiveWishlist()
    if not list or not slotKey then
        return
    end
    list.items = list.items or {}
    local entry = list.items[slotKey]
    if entry then
        if self.History and entry.itemId then
            self.History:AddWishlistItemRemoved(slotKey, entry.itemId)
        end
        local foundMap = self:GetWishlistFoundMap(list.id)
        if foundMap and entry.itemId then
            foundMap[entry.itemId] = nil
            if entry.tokenId then
                foundMap[entry.tokenId] = nil
            end
        end
    end
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

function Goals:IsWishlistSlotEnchantable(slotKey)
    if not slotKey then
        return false
    end
    if self.EnchantableSlots and self.EnchantableSlots[slotKey] then
        return true
    end
    return false
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

function Goals:CacheEnchantByEntry(entry)
    if not entry then
        return nil
    end
    local id = entry.id or entry.enchantId
    if not id then
        return nil
    end
    id = tonumber(id) or id
    self.enchantCache = self.enchantCache or {}
    local cached = self.enchantCache[id]
    if cached and cached.name then
        return cached
    end
    local name = entry.name
    local icon = entry.icon
    local spellId = entry.spellId and tonumber(entry.spellId) or entry.spellId
    if spellId and GetSpellInfo then
        local spellName, _, spellIcon = GetSpellInfo(spellId)
        if not name or name == "" then
            name = spellName
        end
        if not icon or icon == "" then
            icon = spellIcon
        end
    end
    name = name or ("Enchant " .. tostring(id))
    cached = {
        id = id,
        name = name,
        icon = icon,
        spellId = spellId,
    }
    self.enchantCache[id] = cached
    entry.name = name
    if icon then
        entry.icon = icon
    end
    return cached
end

function Goals:GetEnchantInfoById(enchantId)
    enchantId = tonumber(enchantId)
    if not enchantId or enchantId <= 0 then
        return nil
    end
    self.enchantById = self.enchantById or {}
    local cached = self.enchantById[enchantId]
    if cached then
        if not cached.spellId and GetSpellInfo then
            local name = GetSpellInfo(enchantId)
            if name then
                cached.spellId = enchantId
                cached.name = cached.name or name
            end
        end
        return cached
    end
    local list = self:GetEnchantSearchList() or {}
    for _, entry in ipairs(list) do
        local entryId = entry and (entry.id or entry.enchantId)
        if entryId == enchantId then
            cached = self:CacheEnchantByEntry(entry)
            if cached and not cached.spellId and GetSpellInfo then
                local name = GetSpellInfo(enchantId)
                if name then
                    cached.spellId = enchantId
                    cached.name = cached.name or name
                end
            end
            self.enchantById[enchantId] = cached
            return cached
        end
    end
    for _, entry in ipairs(list) do
        local entrySpellId = entry and entry.spellId or nil
        if entrySpellId == enchantId then
            cached = self:CacheEnchantByEntry(entry)
            if cached then
                cached.matchedSpellId = true
            end
            self.enchantById[enchantId] = cached
            return cached
        end
    end
    cached = { id = enchantId, name = "Enchant " .. tostring(enchantId) }
    self.enchantById[enchantId] = cached
    return cached
end

function Goals:GetItemSocketTypes(itemId)
    if not itemId then
        return nil
    end
    self.itemCache = self.itemCache or {}
    local cached = self.itemCache[itemId]
    if cached and cached.socketTypes then
        return cached.socketTypes
    end
    local link = cached and cached.link
    local stats = GetItemStats and GetItemStats(link or ("item:" .. tostring(itemId))) or nil
    if not stats then
        return nil
    end
    local sockets = {}
    local function addSockets(statKey, socketType)
        local count = stats[statKey]
        if count and count > 0 then
            for _ = 1, count do
                table.insert(sockets, socketType)
            end
        end
    end
    addSockets("EMPTY_SOCKET_META", "META")
    addSockets("EMPTY_SOCKET_RED", "RED")
    addSockets("EMPTY_SOCKET_YELLOW", "YELLOW")
    addSockets("EMPTY_SOCKET_BLUE", "BLUE")
    addSockets("EMPTY_SOCKET_PRISMATIC", "PRISMATIC")
    if cached then
        cached.socketTypes = sockets
    else
        self.itemCache[itemId] = { socketTypes = sockets }
    end
    return sockets
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
    if updated and self.UI then
        if self.UI.UpdateWishlistUI then
            self.UI:UpdateWishlistUI()
        end
        if self.UI.UpdateBuildPreviewTooltip and self.UI.buildPreviewTooltip and self.UI.buildPreviewTooltip.IsShown and self.UI.buildPreviewTooltip:IsShown() then
            self.UI:UpdateBuildPreviewTooltip()
        end
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
    local used = {}
    local function addItem(slotKey, entry)
        if not entry or not slotKey or slotKey == "" then
            return
        end
        local exportKey = slotKey == "RANGED" and "RELIC" or slotKey
        used[slotKey] = true
        used[exportKey] = true
        local gems = entry.gemIds or {}
        local gemStrs = {}
        for i = 1, #gems do
            gemStrs[i] = tostring(gems[i])
        end
        local itemPart = table.concat({
            exportKey,
            tostring(entry.itemId or 0),
            tostring(entry.enchantId or 0),
            table.concat(gemStrs, ","),
            escapeWishlistText(entry.notes or ""),
            escapeWishlistText(entry.source or ""),
            tostring(entry.manualFound and 1 or 0),
        }, ":")
        table.insert(items, itemPart)
    end
    local exportOrder = self.WishlistExportOrder or {}
    local listItems = list.items or {}
    for _, slotKey in ipairs(exportOrder) do
        addItem(slotKey, listItems[slotKey])
    end
    if listItems.RANGED and not used.RANGED then
        addItem("RANGED", listItems.RANGED)
    end
    local extraKeys = {}
    for slotKey in pairs(listItems) do
        if not used[slotKey] then
            table.insert(extraKeys, slotKey)
        end
    end
    table.sort(extraKeys)
    for _, slotKey in ipairs(extraKeys) do
        addItem(slotKey, listItems[slotKey])
    end
    table.insert(parts, "items=" .. table.concat(items, "|"))
    return table.concat(parts, ";")
end

function Goals:DeserializeWishlist(text)
    if not text or text == "" then
        return nil, "Empty import string."
    end
    text = text:gsub("||", "|")
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
                local slotKey, itemId, enchantId, gems, notes, source, manualFound = entry:match("([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):?([^:]*):?(.*)")
                if slotKey and slotKey ~= "" then
                    local normalizedKey = strupper(slotKey)
                    if normalizedKey == "RANGED" then
                        normalizedKey = "RELIC"
                    end
                    local gemIds = {}
                    for gem in string.gmatch(gems or "", "([^,]+)") do
                        local id = tonumber(gem)
                        if id and id > 0 then
                            table.insert(gemIds, id)
                        end
                    end
                    items[normalizedKey] = {
                        itemId = tonumber(itemId) or 0,
                        enchantId = tonumber(enchantId) or 0,
                        gemIds = gemIds,
                        notes = unescapeWishlistText(notes),
                        source = unescapeWishlistText(source),
                        manualFound = (tonumber(manualFound) == 1) and true or nil,
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

local BUILD_SHARE_COOLDOWN = 30

local function buildShareKey(senderOrTarget, buildName)
    return tostring(senderOrTarget or "") .. "\n" .. tostring(buildName or "")
end

function Goals:GetBuildShareCooldownRemaining(senderOrTarget, buildName, map)
    local key = buildShareKey(senderOrTarget, buildName)
    local lastSent = map and map[key] or nil
    if not lastSent then
        return 0
    end
    local remaining = (lastSent + BUILD_SHARE_COOLDOWN) - time()
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function Goals:CanSendBuildTo(targetName, buildName)
    if not targetName or targetName == "" then
        return false, "No target selected."
    end
    local remaining = self:GetBuildShareCooldownRemaining(targetName, buildName, self.state.buildShareCooldown or {})
    if remaining > 0 then
        return false, string.format("Please wait %d seconds before sending that build again.", math.ceil(remaining))
    end
    return true
end

function Goals:MarkBuildShareCooldown(targetName, buildName)
    self.state.buildShareCooldown[buildShareKey(targetName, buildName)] = time()
end

function Goals:CanReceiveBuildFrom(senderName, buildName)
    local remaining = self:GetBuildShareCooldownRemaining(senderName, buildName, self.state.buildReceiveCooldown or {})
    return remaining <= 0
end

function Goals:MarkBuildReceiveCooldown(senderName, buildName)
    self.state.buildReceiveCooldown[buildShareKey(senderName, buildName)] = time()
end

function Goals:SendWishlistBuildTo(targetName)
    local list = self:GetActiveWishlist()
    if not list then
        return false, "No active wishlist."
    end
    local buildName = list.name or "Wishlist"
    local normalized = self:NormalizeName(targetName)
    if normalized == "" then
        return false, "No target selected."
    end
    local ok, err = self:CanSendBuildTo(normalized, buildName)
    if not ok then
        return false, err
    end
    if self:IsInRaid() or self:IsInParty() then
        local present = self:GetPresenceMap()
        if not present[normalized] then
            return false, normalized .. " is not online or not in your group."
        end
    end
    local payload = self:SerializeWishlist(list)
    if self.Comm and self.Comm.SendWishlistBuild then
        local sent = self.Comm:SendWishlistBuild(normalized, payload)
        if sent then
            self:MarkBuildShareCooldown(normalized, buildName)
            if self.History then
                self.History:AddBuildSent(normalized, buildName)
            end
            return true, "Sent build '" .. buildName .. "' to " .. normalized .. "."
        end
        return false, "SEND_FAILED"
    end
    return false, "Build share unavailable."
end

function Goals:HandleIncomingBuild(payload, sender)
    if not payload or payload == "" or not sender or sender == "" then
        return
    end
    local data = self:DeserializeWishlist(payload)
    if not data then
        return
    end
    local buildName = data.name or "Wishlist"
    local senderName = self:NormalizeName(sender)
    if not self:CanReceiveBuildFrom(senderName, buildName) then
        return
    end
    self.state.pendingBuildShare = {
        sender = senderName,
        data = data,
    }
    if self.UI and self.UI.ShowBuildSharePrompt then
        self.UI:ShowBuildSharePrompt()
    elseif StaticPopup_Show then
        StaticPopup_Show("GOALS_BUILD_SHARE")
    end
end

function Goals:AcceptPendingBuildShare()
    local pending = self.state.pendingBuildShare
    if not pending then
        return
    end
    local sender = pending.sender or "Unknown"
    local data = pending.data or {}
    local baseName = data.name or "Wishlist"
    local listName = string.format("%s - %s", sender, baseName)
    local list = self:CreateWishlist(listName)
    if list then
        list.items = data.items or {}
        list.updated = time()
        self:SetActiveWishlist(list.id)
        self:NotifyDataChanged()
        if self.History then
            self.History:AddBuildAccepted(sender, baseName, list.name or listName)
        end
        self:Print("Saved build '" .. (list.name or baseName) .. "' from " .. sender .. ".")
    end
    self:MarkBuildReceiveCooldown(sender, baseName)
    self.state.pendingBuildShare = nil
end

function Goals:DeclinePendingBuildShare()
    local pending = self.state.pendingBuildShare
    if not pending then
        return
    end
    local sender = pending.sender or "Unknown"
    local baseName = (pending.data and pending.data.name) or "Wishlist"
    self:MarkBuildReceiveCooldown(sender, baseName)
    self.state.pendingBuildShare = nil
end

function Goals:EnqueueWishlistAnnounce(itemLink, listNames)
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
    table.insert(self.wishlistState.announceQueue, {
        link = itemLink,
        lists = listNames,
    })
    self.wishlistState.announcedItems[itemId] = true
    local now = GetTime and GetTime() or 0
    if self.wishlistState.announceNextFlush == 0 or now >= self.wishlistState.announceNextFlush then
        self.wishlistState.announceNextFlush = now + 0.5
        self:Delay(0.6, function()
            self:FlushWishlistAnnouncements()
        end)
    end
end

function Goals:GetWishlistTokenName(tokenId)
    if not tokenId or tokenId == 0 then
        return nil
    end
    local cached = self:CacheItemById(tokenId)
    if cached and cached.name then
        return cached.name
    end
    return "Token " .. tostring(tokenId)
end

function Goals:FormatWishlistItemWithToken(itemLink)
    if not itemLink or itemLink == "" then
        return ""
    end
    local itemId = self:GetItemIdFromLink(itemLink)
    if not itemId then
        return itemLink
    end
    local tokenId = self:GetArmorTokenForItem(itemId)
    local tokenName = self:GetWishlistTokenName(tokenId)
    if tokenName then
        return string.format("%s (Token: %s)", itemLink, tokenName)
    end
    return itemLink
end

function Goals:ShowWishlistFoundAlert(itemLinks, forceDbm)
    if not UIParent then
        return
    end
    local settings = self.db and self.db.settings or {}
    if settings.wishlistPopupDisabled then
        return
    end
    local allowSound = settings.wishlistPopupSound ~= false
    local bossBanner = _G.BossBanner
    local allowDbm = (forceDbm == true) or (forceDbm ~= false and settings.wishlistDbmIntegration)
    if IsAddOnLoaded and IsAddOnLoaded("DBM-Core") and allowDbm and bossBanner and bossBanner.PlayBanner then
        local links = {}
        if type(itemLinks) == "table" then
            for i = 1, math.min(8, #itemLinks) do
                local entry = itemLinks[i]
                links[i] = type(entry) == "table" and entry.link or entry
            end
        else
            links[1] = itemLinks
        end
        bossBanner.pendingLoot = bossBanner.pendingLoot or {}
        for i = #bossBanner.pendingLoot, 1, -1 do
            bossBanner.pendingLoot[i] = nil
        end
        if bossBanner.AnimIn then
            bossBanner.AnimIn:Stop()
        end
        if bossBanner.AnimSwitch then
            bossBanner.AnimSwitch:Stop()
        end
        if bossBanner.AnimOut then
            bossBanner.AnimOut:Stop()
        end
        bossBanner.animState = nil
        bossBanner.animTimeLeft = nil
        bossBanner.lootShown = 0
        if bossBanner.LootFrames then
            for i = 1, #bossBanner.LootFrames do
                bossBanner.LootFrames[i]:Hide()
            end
        end
        if bossBanner.baseHeight then
            bossBanner:SetHeight(bossBanner.baseHeight)
        end
        bossBanner:Hide()

        local sourceName = "Wishlist items found"
        for i, link in ipairs(links) do
            local texture = select(10, GetItemInfo(link)) or "Interface\\Icons\\inv_misc_questionmark"
            local entry = type(itemLinks) == "table" and itemLinks[i] or nil
            local listNames = entry and entry.lists or nil
            local lootSource = sourceName
            if listNames and #listNames > 0 then
                lootSource = "Wishlist: " .. table.concat(listNames, ", ")
            end
            table.insert(bossBanner.pendingLoot, {
                itemID = self:GetItemIdFromLink(link),
                quantity = 1,
                slot = i,
                lootSourceName = lootSource,
                itemLink = link,
                texture = texture,
            })
        end
        bossBanner.encounterID = "GoalsWishlist"
        bossBanner.encounterName = sourceName
        local restoreSound
        if DBM and DBM.Options and DBM.Options.PlayBBSound ~= nil then
            restoreSound = DBM.Options.PlayBBSound
            if not allowSound then
                DBM.Options.PlayBBSound = false
            end
        end
        bossBanner:PlayBanner({ encounterID = "GoalsWishlist", name = sourceName, mode = "LOOT" })
        if restoreSound ~= nil then
            DBM.Options.PlayBBSound = restoreSound
        end
        return
    end
    if self.ShowWishlistFoundAlertLocal then
        if self.wishlistAlertFrame then
            self.wishlistAlertFrame:SetScript("OnUpdate", nil)
            self.wishlistAlertFrame:Hide()
        end
        self:ShowWishlistFoundAlertLocal(itemLinks, allowSound)
        return
    end
    if not self.wishlistAlertFrame then
        local frame = CreateFrame("Frame", "GoalsWishlistAlert", UIParent)
        frame.headerHeight = 40
        frame.rowHeight = 44
        frame.rowStride = 50
        frame.maxRows = 8
        frame:SetSize(440, frame.headerHeight + frame.rowStride * 3 + 24)
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
        frame:SetFrameStrata("HIGH")
        local useDbm = true
        frame.useDbmBanner = useDbm

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -18)
        title:SetText("Wishlist items found")
        frame.title = title

        local bannerTexturePath = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\BossBanner"
        local iconFramePath = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\WhiteIconFrame"
        if IsAddOnLoaded and IsAddOnLoaded("DBM-Core") then
            bannerTexturePath = "Interface\\AddOns\\DBM-Core\\textures\\BossBannerToast\\BossBanner"
            iconFramePath = "Interface\\AddOns\\DBM-Core\\textures\\BossBannerToast\\WhiteIconFrame"
        end

        local atlasData = {
            ["BossBanner-BgBanner-Bottom"] = { width = 440, height = 112, left = 0.00195312, right = 0.861328, top = 0.00195312, bottom = 0.220703 },
            ["BossBanner-BgBanner-Top"] = { width = 440, height = 112, left = 0.00195312, right = 0.861328, top = 0.224609, bottom = 0.443359 },
            ["BossBanner-BgBanner-Mid"] = { width = 440, height = 64, left = 0.00195312, right = 0.861328, top = 0.447266, bottom = 0.572266 },
            ["LootBanner-LootBagCircle"] = { width = 44, height = 44, left = 0.865234, right = 0.951172, top = 0.224609, bottom = 0.310547 },
            ["LootBanner-ItemBg"] = { width = 269, height = 41, left = 0.244141, right = 0.769531, top = 0.724609, bottom = 0.804688 },
            ["LootBanner-IconGlow"] = { width = 40, height = 40, left = 0.865234, right = 0.943359, top = 0.447266, bottom = 0.525391 },
        }

        local function setGoalsAtlas(texture, name)
            local entry = atlasData[name]
            if not entry then
                return
            end
            texture:SetTexture(bannerTexturePath)
            texture:SetTexCoord(entry.left, entry.right, entry.top, entry.bottom)
            texture:SetSize(entry.width, entry.height)
        end

        local banner = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        banner:SetTexture(bannerTexturePath)
        banner:SetPoint("TOPLEFT", frame, "TOPLEFT", -32, 32)
        banner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 32, -32)
        banner:SetTexCoord(0, 1, 0, 1)
        banner:SetAlpha(0.9)
        frame.banner = banner

        local bannerTop = frame:CreateTexture(nil, "BACKGROUND")
        bannerTop:SetPoint("TOP", frame, "TOP", 0, 8)
        setGoalsAtlas(bannerTop, "BossBanner-BgBanner-Top")
        frame.bannerTop = bannerTop

        local bannerBottom = frame:CreateTexture(nil, "BACKGROUND")
        bannerBottom:SetPoint("BOTTOM", frame, "BOTTOM", 0, -8)
        setGoalsAtlas(bannerBottom, "BossBanner-BgBanner-Bottom")
        frame.bannerBottom = bannerBottom

        local bannerMid = frame:CreateTexture(nil, "BACKGROUND")
        bannerMid:SetPoint("TOP", bannerTop, "BOTTOM", 0, 0)
        bannerMid:SetPoint("BOTTOM", bannerBottom, "TOP", 0, 0)
        bannerMid:SetPoint("LEFT", frame, "LEFT", 0, 0)
        bannerMid:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        bannerMid:SetTexture(bannerTexturePath)
        bannerMid:SetTexCoord(atlasData["BossBanner-BgBanner-Mid"].left, atlasData["BossBanner-BgBanner-Mid"].right, atlasData["BossBanner-BgBanner-Mid"].top, atlasData["BossBanner-BgBanner-Mid"].bottom)
        frame.bannerMid = bannerMid

        local lootCircle = frame:CreateTexture(nil, "ARTWORK")
        lootCircle:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -44)
        setGoalsAtlas(lootCircle, "LootBanner-LootBagCircle")
        lootCircle:SetAlpha(0.7)
        frame.lootCircle = lootCircle

        frame.rows = {}
        for i = 1, frame.maxRows do
            local row = CreateFrame("Frame", nil, frame)
            row:SetSize(360, frame.rowHeight)
            row.baseX = 34
            row.baseY = 0
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", row.baseX, -frame.headerHeight)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetPoint("CENTER", row, "CENTER", 0, 0)
            bg:SetAlpha(0.95)
            setGoalsAtlas(bg, "LootBanner-ItemBg")
            row.bg = bg

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", row, "LEFT", 6, 0)
            icon:SetSize(36, 36)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon
            if useDbm then
                local iconFrame = row:CreateTexture(nil, "OVERLAY")
                iconFrame:SetTexture(iconFramePath)
                iconFrame:SetPoint("CENTER", icon, "CENTER", 0, 0)
                iconFrame:SetSize(38, 38)
                iconFrame:SetBlendMode("ADD")
                row.iconFrame = iconFrame
            end
            local glow = row:CreateTexture(nil, "BORDER")
            glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
            setGoalsAtlas(glow, "LootBanner-IconGlow")
            glow:SetBlendMode("ADD")
            glow:SetAlpha(0.25)
            row.iconGlow = glow

            local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
            text:SetPoint("LEFT", icon, "RIGHT", 12, 0)
            text:SetWidth(260)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            row.text = text

            row:Hide()
            frame.rows[i] = row
        end
        frame:Hide()
        self.wishlistAlertFrame = frame
    end
    local frame = self.wishlistAlertFrame
    local links = {}
    if type(itemLinks) == "table" then
        for i = 1, math.min(8, #itemLinks) do
            links[i] = itemLinks[i]
        end
    else
        links[1] = itemLinks
    end
    local rowsShown = math.max(1, #links)
    frame:SetHeight(frame.headerHeight + (rowsShown * frame.rowStride) + 24)
    for i = 1, frame.maxRows do
        local row = frame.rows[i]
        local link = links[i]
        if row and link then
            local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
            row.text:SetText(name or link)
            row.icon:SetTexture(texture or "Interface\\Icons\\inv_misc_questionmark")
            local color = (quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]) or nil
            if color then
                row.text:SetTextColor(color.r, color.g, color.b)
                row.bg:SetVertexColor(color.r, color.g, color.b, 0.6)
            else
                row.text:SetTextColor(1, 0.82, 0)
                row.bg:SetVertexColor(1, 1, 1, 0.75)
            end
            row.baseY = -frame.headerHeight - (i - 1) * frame.rowStride
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", row.baseX, row.baseY)
            row.animStart = (frame.startTime or 0) + (i - 1) * 0.08
            row:SetAlpha(0)
            row:Show()
        elseif row then
            row:Hide()
            row.animStart = nil
        end
    end
    frame.startTime = GetTime and GetTime() or 0
    frame.duration = 5.5
    frame.fadeIn = 0.2
    frame.fadeOut = 0.6
    frame:SetAlpha(0)
    frame:Show()
    frame:SetScript("OnUpdate", function(selfFrame)
        local now = GetTime and GetTime() or 0
        local elapsed = now - (selfFrame.startTime or 0)
        local alpha = 1
        if elapsed < (selfFrame.fadeIn or 0) then
            alpha = elapsed / (selfFrame.fadeIn or 0.2)
        elseif elapsed > (selfFrame.duration - (selfFrame.fadeOut or 0.6)) then
            alpha = (selfFrame.duration - elapsed) / (selfFrame.fadeOut or 0.6)
        end
        if alpha < 0 then
            alpha = 0
        elseif alpha > 1 then
            alpha = 1
        end
        selfFrame:SetAlpha(alpha)
        if selfFrame.shimmer then
            local pulse = 0.2 + 0.2 * math.abs(math.sin(elapsed * 4))
            selfFrame.shimmer:SetAlpha(pulse)
        end
        if selfFrame.ring then
            local ringPulse = 0.12 + 0.06 * math.abs(math.sin(elapsed * 3))
            selfFrame.ring:SetAlpha(ringPulse)
        end
        if elapsed < 0.4 then
            local scale = 0.9 + (elapsed / 0.4) * 0.1
            selfFrame:SetScale(scale)
        else
            selfFrame:SetScale(1)
        end
        if selfFrame.rows then
            for _, row in ipairs(selfFrame.rows) do
                if row:IsShown() and row.animStart then
                    local rowElapsed = now - row.animStart
                    if rowElapsed < 0 then
                        row:SetAlpha(0)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", selfFrame, "TOPLEFT", row.baseX - 12, row.baseY)
                    elseif rowElapsed < 0.2 then
                        local t = rowElapsed / 0.2
                        row:SetAlpha(t)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", selfFrame, "TOPLEFT", row.baseX - (1 - t) * 12, row.baseY)
                    else
                        row:SetAlpha(1)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", selfFrame, "TOPLEFT", row.baseX, row.baseY)
                    end
                end
            end
        end
        if elapsed >= (selfFrame.duration or 0) then
            selfFrame:SetScript("OnUpdate", nil)
            selfFrame:Hide()
        end
    end)
    if PlaySound and allowSound then
        PlaySound("ReadyCheck")
    end
end

function Goals:GetDbmLootBannerDuration(itemCount)
    local items = tonumber(itemCount) or 1
    if items < 1 then
        items = 1
    end
    -- DBM loot banner: 0.25s expand per extra item + ~4s insert hold + ~0.5s anim out.
    local expand = 0
    if items > 1 then
        expand = 0.25 * (items - 1)
    end
    return 4.5 + expand
end

function Goals:GetWishlistAlertDelay(forceDbm, itemCount)
    if forceDbm == false then
        local settings = self.db and self.db.settings or {}
        if IsAddOnLoaded and IsAddOnLoaded("DBM-Core") and not settings.wishlistDbmIntegration then
            return self:GetDbmLootBannerDuration(itemCount)
        end
        return 0.4
    end
    local settings = self.db and self.db.settings or {}
    local allowDbm = (forceDbm == true) or settings.wishlistDbmIntegration
    if IsAddOnLoaded and IsAddOnLoaded("DBM-Core") and allowDbm then
        return 2.0
    end
    if IsAddOnLoaded and IsAddOnLoaded("DBM-Core") and not allowDbm then
        return self:GetDbmLootBannerDuration(itemCount)
    end
    return 0.4
end

function Goals:TestWishlistNotification(itemLink, forceDbm)
    local links = {}
    if itemLink then
        links = { itemLink }
    else
        local count = 3
        if self.db and self.db.settings then
            count = tonumber(self.db.settings.devTestWishlistItems) or count
        end
        if count < 1 then
            count = 1
        elseif count > 8 then
            count = 8
        end
        local pool = {
            select(2, GetItemInfo(30166)) or "item:30166",
            select(2, GetItemInfo(30168)) or "item:30168",
            select(2, GetItemInfo(29976)) or "item:29976",
            select(2, GetItemInfo(29950)) or "item:29950",
            select(2, GetItemInfo(30190)) or "item:30190",
            select(2, GetItemInfo(30018)) or "item:30018",
            select(2, GetItemInfo(29376)) or "item:29376",
            select(2, GetItemInfo(30047)) or "item:30047",
        }
        for i = 1, count do
            links[i] = pool[i]
        end
    end
    local chatEnabled = self.db and self.db.settings and self.db.settings.devTestWishlistChat
    if chatEnabled then
        if self.db and self.db.settings and self.db.settings.wishlistAnnounce then
            for _, link in ipairs(links) do
                self:EnqueueWishlistAnnounce(link)
            end
            self:FlushWishlistAnnouncements()
        else
            for _, link in ipairs(links) do
                local msg = self:FormatWishlistItemWithToken(link)
                self:Print("Wishlist found: " .. msg)
            end
        end
    end
    local delay = self:GetWishlistAlertDelay(forceDbm, #links)
    if delay > 0 then
        self:Delay(delay, function()
            self:ShowWishlistFoundAlert(links, forceDbm)
        end)
    else
        self:ShowWishlistFoundAlert(links, forceDbm)
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
    local function sendSplitMessage(msg)
        local maxLen = 252
        local text = msg or ""
        while #text > maxLen do
            local cut = maxLen
            local chunk = text:sub(1, maxLen)
            local commaPos = chunk:match(".*(), ")
            local spacePos = chunk:match(".*() ")
            if commaPos then
                cut = commaPos - 1
            elseif spacePos then
                cut = spacePos - 1
            end
            if cut < 1 then
                cut = maxLen
            end
            SendChatMessage(text:sub(1, cut), channel)
            text = text:sub(cut + 1):gsub("^%s+", "")
        end
        if text ~= "" then
            SendChatMessage(text, channel)
        end
    end
    local idx = 1
    while idx <= #queue do
        local slice = { queue[idx] }
        if queue[idx + 1] then
            table.insert(slice, queue[idx + 1])
        end
        if queue[idx + 2] then
            table.insert(slice, queue[idx + 2])
        end
        local formatted = {}
        for _, entry in ipairs(slice) do
            local link = type(entry) == "table" and entry.link or entry
            local lists = type(entry) == "table" and entry.lists or nil
            local label = self:FormatWishlistItemWithToken(link)
            if lists and #lists > 0 then
                label = string.format("%s [%s]", label, table.concat(lists, ", "))
            end
            table.insert(formatted, label)
        end
        local itemText = table.concat(formatted, ", ")
        local msg = string.format(template, itemText)
        sendSplitMessage(msg)
        idx = idx + #slice
    end
    self.wishlistState.announceQueue = {}
end

function Goals:WishlistContainsItem(itemId)
    if not itemId then
        return false
    end
    local data = self:EnsureWishlistData()
    local lists = data and data.lists or {}
    for _, list in pairs(lists) do
        if list and list.items then
            for _, entry in pairs(list.items) do
                if entry and (entry.itemId == itemId or entry.tokenId == itemId) then
                    return true
                end
            end
        end
    end
    return false
end

function Goals:GetWishlistsContainingItem(itemId)
    if not itemId then
        return {}
    end
    local data = self:EnsureWishlistData()
    local lists = data and data.lists or {}
    local names = {}
    for _, list in pairs(lists) do
        if list and list.items then
            for _, entry in pairs(list.items) do
                if entry and (entry.itemId == itemId or entry.tokenId == itemId) then
                    table.insert(names, list.name or "Wishlist")
                    break
                end
            end
        end
    end
    table.sort(names)
    return names
end

function Goals:IsWishlistItemOwned(itemId)
    if not itemId then
        return false
    end
    local count = 0
    if GetItemCount then
        count = GetItemCount(itemId, true) or 0
    end
    if count > 0 then
        return true
    end
    if IsEquippedItem and IsEquippedItem(itemId) then
        return true
    end
    return false
end

function Goals:GetWishlistFoundMap(listId)
    self.wishlistState = self.wishlistState or {}
    self.wishlistState.foundItemsByList = self.wishlistState.foundItemsByList or {}
    if not listId then
        return nil
    end
    if not self.wishlistState.foundItemsByList[listId] then
        self.wishlistState.foundItemsByList[listId] = {}
    end
    return self.wishlistState.foundItemsByList[listId]
end

function Goals:MarkWishlistFound(itemId)
    if not itemId then
        return
    end
    local data = self:EnsureWishlistData()
    local lists = data and data.lists or {}
    local updated = false
    for _, list in pairs(lists) do
        if list and list.id and list.items then
            local foundMap = self:GetWishlistFoundMap(list.id)
            if foundMap then
                local listUpdated = false
                for _, entry in pairs(list.items) do
                    if entry and (entry.itemId == itemId or entry.tokenId == itemId) then
                        foundMap[entry.itemId] = true
                        listUpdated = true
                    end
                end
                if listUpdated then
                    list.updated = time()
                    updated = true
                end
            end
        end
    end
    if updated then
        if self.History then
            self.History:AddWishlistItemFound(itemId)
        end
        self:NotifyDataChanged()
    end
    return updated
end

function Goals:ToggleWishlistFoundForSlot(slotKey)
    local list = self:GetActiveWishlist()
    if not list or not list.id or not slotKey then
        return
    end
    local entry = list.items and list.items[slotKey]
    if not entry or not entry.itemId then
        return
    end
    local foundMap = self:GetWishlistFoundMap(list.id)
    if not foundMap then
        return
    end
    local current = entry.manualFound and true or false
    local nextState = not current
    if nextState then
        foundMap[entry.itemId] = true
        if entry.tokenId and entry.tokenId > 0 then
            foundMap[entry.tokenId] = true
        end
        entry.manualFound = true
    else
        foundMap[entry.itemId] = nil
        if entry.tokenId and entry.tokenId > 0 then
            foundMap[entry.tokenId] = nil
        end
        entry.manualFound = nil
    end
    if self.History then
        self.History:AddWishlistItemClaimed(slotKey, entry.itemId, nextState)
    end
    list.updated = time()
    self:NotifyDataChanged()
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
        local updated = self:MarkWishlistFound(itemId)
        local listNames = self:GetWishlistsContainingItem(itemId)
        if self.db and self.db.settings and not self.db.settings.wishlistAnnounce then
            local msg = self:FormatWishlistItemWithToken(itemLink)
            if listNames and #listNames > 0 then
                msg = string.format("%s [%s]", msg, table.concat(listNames, ", "))
            end
            self:Print("Wishlist found: " .. msg)
        end
        self:EnqueueWishlistAnnounce(itemLink, listNames)
        local delay = self:GetWishlistAlertDelay(nil, 1)
        if delay > 0 then
            local link = itemLink
            self:Delay(delay, function()
                self:ShowWishlistFoundAlert({ { link = link, lists = listNames } })
            end)
        else
            self:ShowWishlistFoundAlert({ { link = itemLink, lists = listNames } })
        end
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
            if entry and entry.data then
                if entry.data.item then
                    self:CacheItemByLink(entry.data.item)
                elseif entry.data.itemId then
                    self:CacheItemById(entry.data.itemId)
                end
                if entry.data.gemIds then
                    for _, gemId in ipairs(entry.data.gemIds) do
                        self:CacheItemById(gemId)
                    end
                end
            end
        end
    end
end

function Goals:BuildItemLinkWithSockets(itemId, baseLink, enchantId, gemIds)
    if not itemId then
        return nil
    end
    local enchant = tonumber(enchantId) or 0
    local gem1 = gemIds and tonumber(gemIds[1]) or 0
    local gem2 = gemIds and tonumber(gemIds[2]) or 0
    local gem3 = gemIds and tonumber(gemIds[3]) or 0
    local level = UnitLevel and UnitLevel("player") or 0
    return string.format("item:%d:%d:%d:%d:%d:0:0:0:%d:0:0:0:0:0:0:0:0:0:0", itemId, enchant, gem1, gem2, gem3, level)
end

function Goals:BuildFullItemLinkWithSockets(itemId, baseLink, enchantId, gemIds)
    local itemString = self:BuildItemLinkWithSockets(itemId, baseLink, enchantId, gemIds)
    if not itemString then
        return nil
    end
    local cached = self.CacheItemById and self:CacheItemById(itemId) or nil
    local name = cached and cached.name or ("Item " .. tostring(itemId))
    local quality = cached and cached.quality or 1
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local hex = color and string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or "ffffffff"
    return string.format("|c%s|H%s|h[%s]|h|r", hex, itemString, name)
end

function Goals:RefreshWishlistItemCache()
    self.itemCache = {}
    self.pendingWishlistInfo = {}
    self:BuildWishlistItemCache()
    self:ProcessPendingWishlistInfo()
    if self.UI and self.UI.UpdateWishlistUI then
        self.UI:UpdateWishlistUI()
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

function Goals:GetGemSearchList()
    return self.GemSearchList or {}
end

function Goals:SearchGemItems(query)
    self.itemCache = self.itemCache or {}
    local results = {}
    local seen = {}
    local clean = query and tostring(query) or ""
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    local queryLower = string.lower(clean)

    local function addItem(itemId)
        if not itemId or itemId <= 0 or seen[itemId] then
            return
        end
        seen[itemId] = true
        local cached = self:CacheItemById(itemId)
        local name = cached and cached.name or ("Item " .. tostring(itemId))
        if clean == "" or tostring(itemId) == clean or string.find(string.lower(name), queryLower, 1, true) then
            table.insert(results, {
                id = itemId,
                itemId = itemId,
                name = name,
                link = cached and cached.link or nil,
                texture = cached and cached.texture or nil,
                quality = cached and cached.quality or nil,
            })
        end
    end

    local directId = tonumber(clean)
    if directId and directId > 0 then
        addItem(directId)
        return results
    end
    local linkId = self:GetItemIdFromLink(clean)
    if linkId then
        addItem(linkId)
        return results
    end

    for _, entry in ipairs(self:GetGemSearchList()) do
        local itemId = nil
        if type(entry) == "table" then
            itemId = tonumber(entry.id or entry.itemId)
        else
            itemId = tonumber(entry)
        end
        addItem(itemId)
    end

    table.sort(results, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return results
end

function Goals:GetEnchantSearchList()
    return self.EnchantSearchList or {}
end

function Goals:SearchEnchantments(query, filters)
    local results = {}
    local clean = query and tostring(query) or ""
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    local queryLower = string.lower(clean)
    local seen = {}
    local slotFilter = filters and filters.slotKey or nil
    local blockedTokens = {
        "poison",
        "oil",
        "flametongue",
        "frostbrand",
        "rockbiter",
        "windfury",
        "sharpened",
        "weighted",
        "fishing lure",
        "spellstone",
        "firestone",
        "flametongue totem",
        "mind-numbing",
        "crippling",
        "instant poison",
        "wound poison",
        "deadly poison",
        "anesthetic poison",
    }
    local function isBlockedEnchantName(name)
        if not name or name == "" then
            return false
        end
        local lower = string.lower(name)
        for _, token in ipairs(blockedTokens) do
            if string.find(lower, token, 1, true) then
                return true
            end
        end
        return false
    end
    local function inferSlotsFromName(name)
        if not name or name == "" then
            return nil
        end
        local lower = string.lower(name)
        local slots = {}
        if string.find(lower, "arcanum", 1, true) then
            slots.HEAD = true
        end
        if string.find(lower, "inscription", 1, true) then
            slots.SHOULDER = true
        end
        if string.find(lower, "bracer", 1, true) or string.find(lower, "wrist", 1, true) then
            slots.WRIST = true
        end
        if string.find(lower, "cloak", 1, true) then
            slots.BACK = true
        end
        if string.find(lower, "chest", 1, true) then
            slots.CHEST = true
        end
        if string.find(lower, "gloves", 1, true) then
            slots.HANDS = true
        end
        if string.find(lower, "boots", 1, true) then
            slots.FEET = true
        end
        if string.find(lower, "shoulder", 1, true) then
            slots.SHOULDER = true
        end
        if string.find(lower, "head", 1, true) or string.find(lower, "helm", 1, true) then
            slots.HEAD = true
        end
        if string.find(lower, "leg", 1, true) or string.find(lower, "pants", 1, true) then
            slots.LEGS = true
        end
        if string.find(lower, "leg armor", 1, true) or string.find(lower, "spellthread", 1, true) then
            slots.LEGS = true
        end
        if string.find(lower, "ring", 1, true) then
            slots.RING1 = true
            slots.RING2 = true
        end
        if string.find(lower, "shield", 1, true) then
            slots.OFFHAND = true
        end
        if string.find(lower, "off%-hand", 1) or string.find(lower, "off hand", 1, true) then
            slots.OFFHAND = true
        end
        local twoHand = string.find(lower, "2h weapon", 1, true)
            or string.find(lower, "two%-hand", 1)
            or string.find(lower, "two hand", 1, true)
        if string.find(lower, "weapon", 1, true) then
            slots.MAINHAND = true
            if not twoHand then
                slots.OFFHAND = true
            end
        elseif twoHand then
            slots.MAINHAND = true
        end
        for _ in pairs(slots) do
            return slots
        end
        return nil
    end

    local slotKeywords = {
        HEAD = { "head", "helm", "helmet", "hood", "circlet", "diadem", "cowl", "arcanum" },
        SHOULDER = { "shoulder", "inscription" },
        BACK = { "cloak", "cape" },
        CHEST = { "chest" },
        WRIST = { "bracer", "wrist" },
        HANDS = { "gloves" },
        LEGS = { "leg", "pants", "trousers", "leg armor", "spellthread" },
        FEET = { "boots" },
        RING1 = { "ring" },
        RING2 = { "ring" },
        MAINHAND = { "weapon", "two hand", "two-hand", "2h weapon" },
        OFFHAND = { "weapon", "off hand", "off-hand", "shield" },
    }

    local function matchesSlot(entry)
        if not slotFilter or slotFilter == "" then
            return true, nil
        end
        if not entry or not entry.slot then
            local name = entry and entry.name or nil
            if name and slotKeywords[slotFilter] then
                local lower = string.lower(name)
                for _, token in ipairs(slotKeywords[slotFilter]) do
                    if string.find(lower, token, 1, true) then
                        return true, slotFilter
                    end
                end
            end
            return false, nil
        end
        if type(entry.slot) == "table" then
            for _, slotKey in ipairs(entry.slot) do
                if slotKey == slotFilter then
                    return true, slotKey
                end
            end
            return false, nil
        end
        if entry.slot == slotFilter then
            return true, entry.slot
        end
        return false, nil
    end

    local function addEntry(entry, bypassSlotFilter)
        local id = entry and (entry.id or entry.enchantId)
        if not id or id <= 0 or seen[id] then
            return
        end
        local name = entry and entry.name or nil
        local icon = entry and entry.icon or nil
        local iconNeedsResolve = (not icon or icon == "" or icon == "Interface\\Icons\\INV_Misc_QuestionMark")
        if entry and entry.spellId and GetSpellInfo then
            local spellName, _, spellIcon = GetSpellInfo(entry.spellId)
            if not name or name == "" then
                name = spellName
            end
            if iconNeedsResolve then
                icon = spellIcon
            end
        end
        name = name or ("Enchant " .. tostring(id))
        if entry and (not entry.name or entry.name == "") then
            entry.name = name
        end
        if entry and (not entry.icon or entry.icon == "") and icon then
            entry.icon = icon
        end
        if entry and not entry.slot then
            local inferred = inferSlotsFromName(name)
            if inferred then
                local slotList = {}
                for key in pairs(inferred) do
                    table.insert(slotList, key)
                end
                table.sort(slotList)
                entry.slot = slotList
            end
        end
        local matchedSlot = nil
        if not bypassSlotFilter then
            local slotOk, slotMatch = matchesSlot(entry)
            if not slotOk then
                return
            end
            matchedSlot = slotMatch
            if not matchedSlot and entry and type(entry.slot) == "string" then
                matchedSlot = entry.slot
            end
        else
            matchedSlot = slotFilter or nil
        end
        if isBlockedEnchantName(name) then
            return
        end
        if clean == "" or tostring(id) == clean or string.find(string.lower(name), queryLower, 1, true) then
            seen[id] = true
            table.insert(results, {
                id = id,
                name = name,
                icon = icon,
                spellId = entry and entry.spellId or nil,
                slotKey = matchedSlot,
            })
        end
    end

    local list = self:GetEnchantSearchList()
    local directId = tonumber(clean)
    if directId and directId > 0 then
        for _, entry in ipairs(list) do
            local entryId = entry and (entry.id or entry.enchantId)
            local entrySpellId = entry and entry.spellId or nil
            if entryId == directId or entrySpellId == directId then
                addEntry(entry, true)
                return results
            end
        end
        addEntry({ id = directId, name = "Enchant " .. tostring(directId) }, true)
        return results
    end

    for _, entry in ipairs(list) do
        addEntry(entry)
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


function Goals:GetSeenPlayersSnapshot()
    local snapshot = {}
    if not self.dbRoot or not self.dbRoot.tables then
        return snapshot
    end
    local tables = {}
    for _, tableData in pairs(self.dbRoot.tables) do
        table.insert(tables, tableData)
    end
    table.sort(tables, function(a, b)
        return (a.lastUpdated or 0) < (b.lastUpdated or 0)
    end)
    for _, tableData in ipairs(tables) do
        local updated = tableData.lastUpdated or 0
        for playerName, data in pairs(tableData.players or {}) do
            snapshot[playerName] = {
                points = data.points or 0,
                class = data.class,
                updated = updated,
            }
        end
    end
    return snapshot
end

function Goals:MergeSeenPlayersIntoCurrent()
    local players = self:GetOverviewPlayers()
    local snapshot = self:GetSeenPlayersSnapshot()
    for name, data in pairs(snapshot) do
        players[name] = { points = data.points or 0, class = data.class or "UNKNOWN" }
    end
    self:NotifyDataChanged()
end

function Goals:MergeSeenPlayersForGroup()
    return
end

function Goals:GetCombinedPlayers()
    return self:GetOverviewPlayers()
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
        if cmd:match("^dev") then
            local action = cmd:match("^dev%s*(.*)$") or ""
            action = action:gsub("^%s+", ""):gsub("%s+$", "")
            if not self.Dev or not self.Dev.SetEnabled then
                self:Print("Dev mode unavailable.")
                return
            end
            if action == "" or action == "toggle" then
                self.Dev:SetEnabled(not self.Dev.enabled)
            elseif action == "on" or action == "enable" or action == "1" then
                self.Dev:SetEnabled(true)
            elseif action == "off" or action == "disable" or action == "0" then
                self.Dev:SetEnabled(false)
            elseif action == "status" then
                self:Print(self.Dev.enabled and "Dev mode is enabled." or "Dev mode is disabled.")
            else
                self:Print("Usage: /goals dev on|off|toggle|status")
            end
            return
        end
        if cmd:match("^mini") then
            if self.UI and self.UI.ToggleMiniTracker then
                self.UI:ToggleMiniTracker()
            end
            return
        end
        self:ToggleUI()
    end
end

local function isTypingInEditBox()
    if ChatEdit_GetActiveWindow then
        local editBox = ChatEdit_GetActiveWindow()
        if editBox and editBox:IsShown() then
            return true
        end
    end
    if IsInEditMode and IsInEditMode() then
        return true
    end
    return false
end

function Goals_ToggleUIBinding()
    if isTypingInEditBox() then
        return
    end
    if Goals and Goals.ToggleUI then
        Goals:ToggleUI()
    end
end

function Goals_ToggleMiniBinding()
    if isTypingInEditBox() then
        return
    end
    if Goals and Goals.UI and Goals.UI.ToggleMiniTracker then
        Goals.UI:ToggleMiniTracker()
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
        local installedMajor = self:GetUpdateMajorVersion()
        local installedMinor = self:GetInstalledUpdateVersion()
        if not self:IsVersionNewer(self.db.settings.updateAvailableMajor or 0, self.db.settings.updateAvailableVersion or 0, installedMajor, installedMinor) then
            self.db.settings.updateAvailableMajor = 0
            self.db.settings.updateAvailableVersion = 0
        end
        if self.db.settings.updateSeenVersion == nil then
            self.db.settings.updateSeenVersion = installedMinor
        end
        if self.db.settings.updateSeenMajor == nil then
            self.db.settings.updateSeenMajor = installedMajor
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
    if self.DamageTracker and self.DamageTracker.Init then
        self.DamageTracker:Init()
    end
    if self.UI and self.UI.Init then
        self.UI:Init()
    end
    if self.MaybePromptOverviewMigration then
        self:MaybePromptOverviewMigration()
    end
    self:UpdateSyncStatus()
    if self.StartAutoSyncPush then
        self:StartAutoSyncPush()
    end
    self:Debug("Loaded v" .. self.version)
end

function Goals:StartAutoSyncPush()
    if self.autoSyncFrame then
        return
    end
    local interval = 60
    local elapsed = 0
    self.autoSyncInterval = interval
    self.nextAutoSyncAt = time() + interval

    local frame = CreateFrame("Frame")
    local function canSync()
        if not self.IsSyncMaster or not self:IsSyncMaster() then
            if not (self.IsMasterLooter and self:IsMasterLooter()) then
                return false
            end
        end
        if not self:IsInRaid() and not self:IsInParty() then
            return false
        end
        return true
    end
    local function updateOnUpdate()
        if canSync() then
            frame:SetScript("OnUpdate", function(_, delta)
                elapsed = elapsed + (delta or 0)
                if elapsed < interval then
                    return
                end
                elapsed = 0
                if not canSync() then
                    return
                end
                if self.Comm and self.Comm.SendPointsSync then
                    self.Comm:SendPointsSync(nil, "AUTO")
                elseif self.Comm and self.Comm.SerializePoints then
                    self.Comm:Send("SYNC_POINTS", self.Comm:SerializePoints())
                end
                self:MarkSyncSent()
            end)
        else
            frame:SetScript("OnUpdate", nil)
        end
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    frame:SetScript("OnEvent", function()
        updateOnUpdate()
    end)

    updateOnUpdate()
    self.autoSyncFrame = frame
end

function Goals:GetAutoSyncRemaining()
    if not self.nextAutoSyncAt then
        return nil
    end
    local remaining = self.nextAutoSyncAt - time()
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function Goals:MarkSyncSent()
    if self.autoSyncInterval then
        self.nextAutoSyncAt = time() + self.autoSyncInterval
    end
    self.lastSyncSentAt = time()
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
