-- Goals UI feature module. Methods are mechanically extracted from gui.lua.

local Goals = _G.Goals
local context = Goals and Goals.UI and Goals.UI.ModuleContext
if not context then
    return
end

local moduleEnvironment = setmetatable({}, {
    __index = context,
    __newindex = context,
})
setfenv(1, moduleEnvironment)
function UI:HistoryEntryMatchesFilters(entry, settings)
    if not entry then
        return false
    end
    local kind = entry.kind
    local data = entry.data or {}
    local minQuality = settings and settings.historyLootMinQuality or 0
    local encounterEnabled = getHistoryFilterValue(settings, "historyFilterEncounter")
    local pointsEnabled = getHistoryFilterValue(settings, "historyFilterPoints")
    local buildEnabled = getHistoryFilterValue(settings, "historyFilterBuild")
    local wishlistStatusEnabled = getHistoryFilterValue(settings, "historyFilterWishlistStatus")
    local wishlistItemsEnabled = getHistoryFilterValue(settings, "historyFilterWishlistItems")
    local lootEnabled = getHistoryFilterValue(settings, "historyFilterLoot")
    local syncEnabled = getHistoryFilterValue(settings, "historyFilterSync")
    local function passesLootQuality()
        if minQuality <= 0 then
            return true
        end
        local itemLink = getHistoryItemLink(entry)
        if itemLink and GetItemInfo then
            local quality = select(3, GetItemInfo(itemLink))
            if quality and quality < minQuality then
                return false
            end
        end
        return true
    end

    if kind == "BOSSKILL" or kind == "ADJUST" then
        return pointsEnabled
    end
    if kind == "SET" then
        return pointsEnabled
    end
    if kind == "ENCOUNTER_START" or kind == "ENCOUNTER_END" or kind == "WIPE" then
        return encounterEnabled
    end
    if kind == "LOOT_ASSIGN" then
        if not passesLootQuality() then
            return false
        end
        return lootEnabled
    end
    if kind == "LOOT_FOUND" then
        if not passesLootQuality() then
            return false
        end
        return lootEnabled
    end
    if kind == "BUILD_SENT" or kind == "BUILD_ACCEPTED" then
        return buildEnabled
    end
    if kind == "WISHLIST_FOUND" or kind == "WISHLIST_CLAIM" then
        return wishlistStatusEnabled
    end
    if kind == "WISHLIST_ADD" or kind == "WISHLIST_REMOVE" or kind == "WISHLIST_SOCKET" or kind == "WISHLIST_ENCHANT" then
        return wishlistItemsEnabled
    end
    if kind == "SYNC" then
        return syncEnabled
    end
    return true
end

function UI:GetHistoryEntries()
    local list = {}
    if not Goals.db or not Goals.db.history then
        return list
    end
    local settings = Goals.db.settings or {}
    for _, entry in ipairs(Goals.db.history) do
        if self:HistoryEntryMatchesFilters(entry, settings) then
            table.insert(list, entry)
        end
    end
    return list
end

function UI:UpdateHistoryOptionsVisibility()
    if not self.historyOptionsFrame then
        return
    end
    local open = self.historyOptionsOpen
    if self.historyOptionsInline then
        open = true
    end
    local show = self.currentTab == self.historyTabId and open
    if self.historyOptionsOuter then
        setShown(self.historyOptionsOuter, show)
    end
    setShown(self.historyOptionsFrame, show)
end

function UI:CreateHistoryTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsHistoryOptionsInset", OPTIONS_PANEL_WIDTH)
    self.historyOptionsFrame = optionsPanel
    self.historyOptionsScroll = optionsPanel.scroll
    self.historyOptionsContent = optionsContent
    self.historyOptionsOpen = true
    self.historyOptionsInline = true

    local inset = CreateFrame("Frame", "GoalsHistoryInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    inset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    self.historyInset = inset
    if page.footer then
        anchorToFooter(inset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(inset, "GoalsHistoryTable", {
        columns = {
            { key = "time", title = "Time", width = 60, justify = "LEFT", wrap = false },
            { key = "event", title = "Event", width = 240, justify = "LEFT", wrap = false },
            { key = "player", title = "Player", width = 120, justify = "LEFT", wrap = false },
            { key = "notes", title = "Notes", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = HISTORY_ROW_HEIGHT,
        visibleRows = HISTORY_ROWS,
        headerHeight = 16,
    })
    self.historyTable = tableWidget
    self.historyScroll = tableWidget.scroll
    self.historyRows = tableWidget.rows

    self.historyScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, HISTORY_ROW_HEIGHT, function()
            UI:UpdateHistoryList()
        end)
    end)

    local y = -10
    local function addSectionHeader(text)
        local label, bar = createOptionsHeader(optionsContent, text, y)
        y = y - 22
        return label, bar
    end

    local function addLabel(text)
        local label = createLabel(optionsContent, text, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsControlLabel(label)
        y = y - 18
        return label
    end

    local function addInfoLabel(text, template)
        local label = createLabel(optionsContent, text, template or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsLabel(label)
        y = y - 16
        return label
    end

    local function addCheck(text, key, tooltipText)
        local check = CreateFrame("CheckButton", nil, optionsContent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsCheck(check)
        setCheckText(check, text)
        check:SetScript("OnClick", function(selfBtn)
            Goals.db.settings[key] = selfBtn:GetChecked() and true or false
            UI:UpdateHistoryList()
        end)
        attachSideTooltip(check, tooltipText)
        y = y - 28
        return check
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    addSectionHeader(L.LABEL_HISTORY_OPTIONS)
    addLabel(L.LABEL_HISTORY_FILTERS)

    local combineCheck = addCheck("Group boss kills", "combineBossHistory",
        "Group multiple boss kills into one history entry.")
    combineCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("combineBossHistory", selfBtn:GetChecked() and true or false)
        UI:UpdateHistoryList()
    end)
    self.combineCheck = combineCheck

    local encounterCheck = addCheck("Show boss kills", "historyFilterEncounter", "Show boss kill entries.")
    local pointsCheck = addCheck("Show point changes", "historyFilterPoints", "Show point awards, adjustments, and resets.")
    local buildCheck = addCheck("Show wishlist builds", "historyFilterBuild", "Show wishlist build/save entries.")
    local wishlistStatusCheck = addCheck("Show wishlist status", "historyFilterWishlistStatus", "Show wishlist status changes.")
    local wishlistItemsCheck = addCheck("Show wishlist items", "historyFilterWishlistItems", "Show wishlist item add/remove entries.")
    local lootCheck = addCheck("Show loot assignments", "historyFilterLoot", "Show loot assignments and resets.")
    local syncCheck = addCheck("Show sync events", "historyFilterSync", "Show sync send/receive events.")

    self.historyEncounterCheck = encounterCheck
    self.historyPointsCheck = pointsCheck
    self.historyBuildCheck = buildCheck
    self.historyWishlistStatusCheck = wishlistStatusCheck
    self.historyWishlistItemsCheck = wishlistItemsCheck
    self.historyLootCheck = lootCheck
    self.historySyncCheck = syncCheck

    y = y - 8
    addLabel(L.LABEL_HISTORY_LOOT_MIN_QUALITY)

    local minQualityDrop = addDropdown("GoalsHistoryMinQuality")
    attachSideTooltip(minQualityDrop, "Only show loot entries at or above this quality.")
    minQualityDrop.options = getQualityOptions()
    UIDropDownMenu_Initialize(minQualityDrop, function(_, level)
        for _, option in ipairs(minQualityDrop.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals.db.settings.historyLootMinQuality = option.value
                UIDropDownMenu_SetSelectedValue(minQualityDrop, option.value)
                UIDropDownMenu_SetText(minQualityDrop, option.text)
                UI:UpdateHistoryList()
            end
            info.checked = (Goals.db.settings.historyLootMinQuality or 0) == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.historyLootMinQuality = minQualityDrop

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
end

function UI:FormatHistoryEntry(entry)
    if not entry then
        return ""
    end
    local data = entry.data or {}
    local function formatSlotLabel(slotKey)
        if Goals and Goals.GetWishlistSlotDef then
            local def = Goals:GetWishlistSlotDef(slotKey)
            if def and def.label then
                return def.label
            end
        end
        return slotKey or "Slot"
    end
    local function formatItemLink(itemId, itemLink)
        if itemLink and itemLink ~= "" then
            return itemLink
        end
        if itemId and Goals and Goals.CacheItemById then
            local cached = Goals:CacheItemById(itemId)
            if cached and cached.link then
                return cached.link
            end
        end
        if itemId then
            return "item:" .. tostring(itemId)
        end
        return "item"
    end
    local function formatGemList(gemIds)
        if not gemIds or #gemIds == 0 then
            return "none"
        end
        local gems = {}
        for _, gemId in ipairs(gemIds) do
            table.insert(gems, formatItemLink(gemId))
        end
        return table.concat(gems, ", ")
    end
    local function formatChannelLabel(channel)
        if not channel or channel == "" then
            return nil
        end
        if channel == "RAID" then
            return "raid"
        end
        if channel == "PARTY" then
            return "party"
        end
        if channel == "WHISPER" then
            return "whisper"
        end
        return string.lower(channel)
    end
    local function formatSyncTypeLabel(syncType)
        if syncType == "FULL" then
            return "full sync"
        end
        if syncType == "POINTS" then
            return "points sync"
        end
        if syncType == "SETTINGS" then
            return "settings sync"
        end
        return "sync"
    end
    if entry.kind == "BOSSKILL" and data.player then
        return string.format("%s: %s +%d", data.encounter or "Boss", colorizeName(data.player), data.points or 0)
    end
    if entry.kind == "BOSSKILL" and data.players then
        local count = #data.players
        return string.format("Gave %s: +%d (%s)", formatPlayersCount(count), data.points or 0, data.encounter or "Boss")
    end
    if entry.kind == "ADJUST" then
        local delta = data.delta or 0
        local sign = delta >= 0 and "+" or ""
        return string.format("%s: %s%d (%s)", colorizeName(data.player or ""), sign, delta, data.reason or "Adjustment")
    end
    if entry.kind == "SET" then
        return string.format("%s: %d -> %d (%s)", colorizeName(data.player or ""), data.before or 0, data.after or 0, data.reason or "Set points")
    end
    if entry.kind == "LOOT_ASSIGN" then
        local itemLink = data.item or ""
        local quality = itemLink ~= "" and select(3, GetItemInfo(itemLink)) or nil
        if data.players and #data.players >= 3 then
            return string.format("Gave %s: %s", formatPlayersCount(#data.players), itemLink)
        end
        if quality and quality < 4 then
            return string.format("%s Looted: %s", colorizeName(data.player or ""), itemLink)
        end
        if data.reset then
            local before = tonumber(data.resetBefore) or 0
            local playerName = colorizeName(data.player or "")
            return string.format("Gave %s: %s\n%s's points set to 0 (-%d).", playerName, itemLink, playerName, before)
        end
        return string.format("Gave %s: %s", colorizeName(data.player or ""), itemLink)
    end
    if entry.kind == "LOOT_FOUND" then
        return entry.text or ""
    end
    if entry.kind == "BUILD_SENT" then
        local target = data.target or "Unknown"
        return string.format("Sent build '%s' to %s", data.build or "Wishlist", colorizeName(target))
    end
    if entry.kind == "BUILD_ACCEPTED" then
        local sender = data.sender or "Unknown"
        return string.format("Accepted build '%s' from %s", data.build or "Wishlist", colorizeName(sender))
    end
    if entry.kind == "WISHLIST_FOUND" then
        return string.format("Wishlist found: %s", formatItemLink(data.itemId, data.item))
    end
    if entry.kind == "WISHLIST_CLAIM" then
        local action = data.claimed and "Wishlist item claimed" or "Wishlist item unclaimed"
        local slot = formatSlotLabel(data.slot)
        return string.format("%s: %s %s", action, slot, formatItemLink(data.itemId, data.item))
    end
    if entry.kind == "WISHLIST_ADD" then
        local slot = formatSlotLabel(data.slot)
        return string.format("Wishlist add: %s %s", slot, formatItemLink(data.itemId, data.item))
    end
    if entry.kind == "WISHLIST_REMOVE" then
        local slot = formatSlotLabel(data.slot)
        return string.format("Wishlist remove: %s %s", slot, formatItemLink(data.itemId, data.item))
    end
    if entry.kind == "WISHLIST_SOCKET" then
        local slot = formatSlotLabel(data.slot)
        return string.format("Wishlist socketed: %s %s (gems: %s)", slot, formatItemLink(data.itemId, data.item), formatGemList(data.gemIds))
    end
    if entry.kind == "WISHLIST_ENCHANT" then
        local slot = formatSlotLabel(data.slot)
        local enchantId = tonumber(data.enchantId) or 0
        local enchantName = nil
        if enchantId > 0 and Goals and Goals.GetEnchantInfoById then
            local info = Goals:GetEnchantInfoById(enchantId)
            enchantName = info and info.name or nil
        end
        if enchantId <= 0 then
            enchantName = "cleared"
        elseif not enchantName or enchantName == "" then
            enchantName = "Enchant " .. tostring(enchantId)
        end
        return string.format("Wishlist enchanted: %s %s (enchant: %s)", slot, formatItemLink(data.itemId, data.item), enchantName)
    end
    if entry.kind == "SYNC" then
        local action = data.action or ""
        local channel = formatChannelLabel(data.channel)
        local sender = data.sender
        local target = data.target
        local syncLabel = formatSyncTypeLabel(data.syncType)
        local source = data.source
        local prefix = source == "AUTO" and "Auto " or ""
        local suffix = source == "REQUEST" and " (request)" or ""
        if action == "REQUEST_SENT" then
            if target and target ~= "" then
                return prefix .. "Requested sync from " .. colorizeName(target)
            end
            if channel then
                return prefix .. "Requested sync (" .. channel .. ")"
            end
            return prefix .. "Requested sync"
        end
        if action == "REQUEST_RECEIVED" then
            if sender and sender ~= "" then
                if channel then
                    return "Sync requested by " .. colorizeName(sender) .. " (" .. channel .. ")"
                end
                return "Sync requested by " .. colorizeName(sender)
            end
            return "Sync requested"
        end
        if action == "SENT" then
            if target and target ~= "" then
                return prefix .. "Sent " .. syncLabel .. " to " .. colorizeName(target) .. suffix
            end
            if channel then
                return prefix .. "Sent " .. syncLabel .. " (" .. channel .. ")" .. suffix
            end
            return prefix .. "Sent " .. syncLabel .. suffix
        end
        if action == "RECEIVED" then
            if sender and sender ~= "" then
                if channel then
                    return "Received " .. syncLabel .. " from " .. colorizeName(sender) .. " (" .. channel .. ")"
                end
                return "Received " .. syncLabel .. " from " .. colorizeName(sender)
            end
            return "Received " .. syncLabel
        end
        return entry.text or "Sync"
    end
    return entry.text or ""
end

function UI:GetHistoryColumnData(entry)
    if not entry then
        return "", "", "", false
    end
    local data = entry.data or {}
    local kind = entry.kind or ""

    local function formatSlotLabel(slotKey)
        if Goals and Goals.GetWishlistSlotDef then
            local def = Goals:GetWishlistSlotDef(slotKey)
            if def and def.label then
                return def.label
            end
        end
        return slotKey or "Slot"
    end

    local function formatItemLink(itemId, itemLink)
        if itemLink and itemLink ~= "" then
            return itemLink
        end
        if itemId and Goals and Goals.CacheItemById then
            local cached = Goals:CacheItemById(itemId)
            if cached and cached.link then
                return cached.link
            end
        end
        if itemId then
            return "item:" .. tostring(itemId)
        end
        return ""
    end

    local event = ""
    local target = ""
    local notes = ""
    local targetIsPlayer = false

    if kind == "BOSSKILL" then
        event = data.encounter or "Boss"
        if data.player then
            target = data.player
            targetIsPlayer = true
        elseif data.players then
            target = string.format("%d players", #data.players)
        end
        if data.points then
            notes = string.format("+%d", data.points)
        end
    elseif kind == "ENCOUNTER_START" then
        event = data.encounter or "Encounter"
        notes = "Start"
    elseif kind == "WIPE" then
        event = data.encounter or "Encounter"
        notes = "Wipe"
    elseif kind == "ADJUST" then
        event = "Points"
        target = data.player or ""
        targetIsPlayer = target ~= ""
        local delta = tonumber(data.delta) or 0
        local sign = delta >= 0 and "+" or ""
        notes = string.format("%s%d", sign, delta)
        if data.reason and data.reason ~= "" then
            notes = notes .. " (" .. data.reason .. ")"
        end
    elseif kind == "SET" then
        event = "Points"
        target = data.player or ""
        targetIsPlayer = target ~= ""
        notes = string.format("%d -> %d", data.before or 0, data.after or 0)
        if data.reason and data.reason ~= "" then
            notes = notes .. " (" .. data.reason .. ")"
        end
    elseif kind == "LOOT_ASSIGN" then
        event = data.item or ""
        if data.player then
            target = data.player
            targetIsPlayer = true
        elseif data.players then
            target = string.format("%d players", #data.players)
        end
        if data.reset then
            local before = tonumber(data.resetBefore) or 0
            notes = string.format("reset (-%d)", before)
        end
    elseif kind == "LOOT_FOUND" then
        event = data.item or entry.text or ""
        notes = "Found"
    elseif kind == "BUILD_SENT" then
        event = data.build or "Build"
        target = data.target or ""
        targetIsPlayer = target ~= ""
        notes = "Sent"
    elseif kind == "BUILD_ACCEPTED" then
        event = data.build or "Build"
        target = data.sender or ""
        targetIsPlayer = target ~= ""
        notes = "Accepted"
    elseif kind == "WISHLIST_FOUND" then
        event = formatItemLink(data.itemId, data.item)
        notes = "Found"
    elseif kind == "WISHLIST_CLAIM" then
        event = formatItemLink(data.itemId, data.item)
        target = formatSlotLabel(data.slot)
        notes = data.claimed and "Wishlist item claimed" or "Wishlist item unclaimed"
    elseif kind == "WISHLIST_ADD" then
        event = formatItemLink(data.itemId, data.item)
        target = formatSlotLabel(data.slot)
        notes = "Added"
    elseif kind == "WISHLIST_REMOVE" then
        event = formatItemLink(data.itemId, data.item)
        target = formatSlotLabel(data.slot)
        notes = "Removed"
    elseif kind == "WISHLIST_SOCKET" then
        event = formatItemLink(data.itemId, data.item)
        target = formatSlotLabel(data.slot)
        notes = "Socketed"
    elseif kind == "WISHLIST_ENCHANT" then
        event = formatItemLink(data.itemId, data.item)
        target = formatSlotLabel(data.slot)
        notes = "Enchanted"
    elseif kind == "SYNC" then
        event = "Sync"
        target = data.sender or data.target or ""
        targetIsPlayer = target ~= ""
        notes = entry.text or ""
    else
        event = entry.text or ""
    end

    return event, target, notes, targetIsPlayer
end

function UI:UpdateHistoryList()
    if not self.historyScroll or not self.historyRows then
        return
    end
    local data = self:GetHistoryEntries()
    self.historyData = data
    local offset = FauxScrollFrame_GetOffset(self.historyScroll) or 0
    FauxScrollFrame_Update(self.historyScroll, #data, HISTORY_ROWS, HISTORY_ROW_HEIGHT)
    setScrollBarAlwaysVisible(self.historyScroll, #data * HISTORY_ROW_HEIGHT)
    local hasRainbow = false
    local rowTopOffset = self.historyTable and self.historyTable.rowTopOffset or -26
    local rowLeft = self.historyTable and self.historyTable.headerLeft or 6
    local rowRight = self.historyTable and self.historyTable.headerRight or -6
    for i = 1, HISTORY_ROWS do
        local row = self.historyRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.timeText:SetText(formatTime(entry.ts))
            row.rainbowData = nil
            local eventText, playerText, notesText, isPlayer = self:GetHistoryColumnData(entry)
            if entry.kind == "BOSSKILL" and entry.data and entry.data.players then
                local count = #entry.data.players
                row.rainbowData = {
                    kind = "boss",
                    count = count,
                    points = entry.data.points or 0,
                    encounter = entry.data.encounter or "Boss",
                }
                if row.cols then
                    if row.cols.event then
                        row.cols.event:SetText(entry.data.encounter or "Boss")
                    end
                    if row.cols.player then
                        row.cols.player:SetText(formatPlayersCount(count))
                        row.cols.player:SetTextColor(1, 1, 1)
                    end
                    if row.cols.notes then
                        row.cols.notes:SetText(string.format("+%d", entry.data.points or 0))
                    end
                elseif row.text then
                    row.text:SetText(string.format("Gave %s: +%d (%s)", formatPlayersCount(count), entry.data.points or 0, entry.data.encounter or "Boss"))
                end
                hasRainbow = true
            elseif entry.kind == "LOOT_ASSIGN" and entry.data and entry.data.players and #entry.data.players >= 3 then
                local count = #entry.data.players
                row.rainbowData = {
                    kind = "loot",
                    count = count,
                    itemLink = entry.data.item or "",
                }
                if row.cols then
                    if row.cols.event then
                        row.cols.event:SetText(entry.data.item or "")
                    end
                    if row.cols.player then
                        row.cols.player:SetText(formatPlayersCount(count))
                        row.cols.player:SetTextColor(1, 1, 1)
                    end
                    if row.cols.notes then
                        row.cols.notes:SetText("Assigned")
                    end
                elseif row.text then
                    row.text:SetText(string.format("Gave %s: %s", formatPlayersCount(count), entry.data.item or ""))
                end
                hasRainbow = true
            else
                if row.cols then
                    if row.cols.event then
                        row.cols.event:SetText(eventText or "")
                    end
                    if row.cols.player then
                        row.cols.player:SetText(playerText or "")
                        if isPlayer and playerText ~= "" then
                            local r, g, b = Goals:GetPlayerColor(playerText)
                            row.cols.player:SetTextColor(r, g, b)
                        else
                            row.cols.player:SetTextColor(1, 1, 1)
                        end
                    end
                    if row.cols.notes then
                        row.cols.notes:SetText(notesText or "")
                    end
                elseif row.text then
                    row.text:SetText(self:FormatHistoryEntry(entry))
                end
            end
            row:SetHeight(HISTORY_ROW_HEIGHT)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.historyInset, "TOPLEFT", rowLeft, rowTopOffset - (i - 1) * HISTORY_ROW_HEIGHT)
            row:SetPoint("RIGHT", self.historyInset, "RIGHT", rowRight, 0)
        else
            row:Hide()
            row.rainbowData = nil
        end
    end
    if hasRainbow then
        self:StartRainbowTicker()
    end
end
