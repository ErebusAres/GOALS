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
function UI:GetBuildShareCandidates()
    if not (Goals:IsInRaid() or Goals:IsInParty()) then
        return {}
    end
    local present = Goals:GetPresenceMap()
    local names = {}
    local playerName = Goals:GetPlayerName()
    for name in pairs(present) do
        if name ~= playerName then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function UI:ShowBuildSharePrompt()
    setupBuildSharePopup()
    if StaticPopup_Show then
        StaticPopup_Show("GOALS_BUILD_SHARE")
    end
end

function UI:CreateBuildShareTargetFrame()
    if self.buildShareTargetFrame then
        return
    end
    local frame = CreateFrame("Frame", "GoalsBuildShareTargetFrame", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(frame)
    frame:SetSize(OPTIONS_PANEL_WIDTH + 12, 140)
    if self.frame then
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText(L.BUTTON_SEND_BUILD)
        frame.TitleText:Show()
    end
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local content = CreateFrame("Frame", nil, frame, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.content = content

    local y = -20
    local targetLabel = createLabel(content, "Send to", "GameFontNormalSmall")
    targetLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(targetLabel)
    y = y - 18

    local dropdown = CreateFrame("Frame", "GoalsBuildShareTargetDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", content, "TOPLEFT", -6, y)
    dropdown.colorize = true
    self:SetupDropdown(dropdown, function()
        return self:GetBuildShareCandidates()
    end, function(name)
        if frame.editBox then
            frame.editBox:SetText(name or "")
        end
        frame.selectedTarget = name
    end, L.SELECT_OPTION)
    styleDropdown(dropdown, OPTIONS_CONTROL_WIDTH)
    frame.dropdown = dropdown
    y = y - 36

    local editBox = CreateFrame("EditBox", "GoalsBuildShareTargetEditBox", content, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
    editBox:SetAutoFocus(false)
    styleOptionsEditBox(editBox, OPTIONS_CONTROL_WIDTH)
    bindEscapeClear(editBox)
    frame.editBox = editBox
    y = y - 30

    local sendBtn = createOptionsButton(content)
    styleOptionsButton(sendBtn, OPTIONS_CONTROL_WIDTH)
    sendBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    sendBtn:SetText(L.BUTTON_SEND_BUILD)
    sendBtn:SetScript("OnClick", function()
        local target = frame.editBox and frame.editBox:GetText() or frame.selectedTarget
        if not target or target == "" then
            Goals:Print("No target selected.")
            return
        end
        local ok, err = Goals:SendWishlistBuildTo(target)
        if ok then
            Goals:Print(err)
            frame:Hide()
        else
            if err == "SEND_FAILED" or not err or err == "" then
                Goals:Print("Failed to send build.")
            else
                Goals:Print(err)
            end
        end
    end)
    frame.sendBtn = sendBtn

    self.buildShareTargetFrame = frame
end

function UI:ShowBuildShareTargetPrompt()
    self:CreateBuildShareTargetFrame()
    local frame = self.buildShareTargetFrame
    local candidates = self:GetBuildShareCandidates()
    local targetName = nil
    if UnitExists and UnitIsPlayer and UnitExists("target") and UnitIsPlayer("target") then
        targetName = UnitName and UnitName("target") or nil
    end

    if #candidates > 0 then
        frame.dropdown:Show()
        local selected = candidates[1]
        if targetName then
            for _, name in ipairs(candidates) do
                if name == targetName then
                    selected = name
                    break
                end
            end
        end
        frame.selectedTarget = selected
        UIDropDownMenu_SetSelectedValue(frame.dropdown, selected)
        self:SetDropdownText(frame.dropdown, selected)
    else
        frame.dropdown:Hide()
        frame.selectedTarget = nil
    end

    frame.editBox:Show()
    if targetName and targetName ~= "" then
        frame.editBox:SetText(targetName)
    elseif frame.selectedTarget then
        frame.editBox:SetText(frame.selectedTarget)
    else
        frame.editBox:SetText("")
    end

    if self.buildPreviewTooltip and self.buildPreviewTooltip:IsShown() then
        local left = self.buildPreviewTooltip:GetLeft()
        local bottom = self.buildPreviewTooltip:GetBottom()
        frame:ClearAllPoints()
        if left and bottom then
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom - 6)
        else
            frame:SetPoint("TOPLEFT", self.buildPreviewTooltip, "BOTTOMLEFT", 0, -6)
        end
    else
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 10, -30)
    end

    local content = frame.content
    if content and content.GetTop and frame.sendBtn and frame.sendBtn.GetBottom then
        local top = content:GetTop() or 0
        local bottom = frame.sendBtn:GetBottom() or 0
        if top > 0 and bottom > 0 then
            local contentHeight = (top - bottom) + 12
            local totalHeight = contentHeight + 30
            frame:SetHeight(totalHeight)
        end
    end

    frame:Show()
end

function UI:GetWishlistTabLabel(tabKey)
    local map = {
        manage = "Manage",
        search = "Search",
        actions = "Actions",
        options = "Builds",
        builds = "Builds",
    }
    return map[tabKey]
end

function UI:GetWishlistAlertsSummary(settings)
    local alerts = {}
    if settings.wishlistAnnounce then
        table.insert(alerts, "Chat")
    end
    if not settings.wishlistPopupDisabled then
        table.insert(alerts, "Popup")
    end
    if #alerts == 0 then
        return "Alerts: Off"
    end
    return "Alerts: " .. table.concat(alerts, " + ")
end

function UI:UpdateWishlistHelpVisibility()
    if not self.wishlistHelpFrame then
        return
    end
    local show = self.currentTab == self.wishlistTabId and self.wishlistHelpOpen
    if self.wishlistHelpOuter then
        setShown(self.wishlistHelpOuter, show)
    end
    setShown(self.wishlistHelpFrame, show)
end

function UI:UpdateWishlistSocketPickerVisibility()
    if not self.wishlistSocketPickerFrame then
        return
    end
    local show = self.currentTab == self.wishlistTabId and self.wishlistSocketPickerOpen
    if show then
        local gemAvailable, enchantAvailable = self:GetWishlistSocketAvailability()
        if not gemAvailable and not enchantAvailable then
            show = false
            self.wishlistSocketPickerOpen = false
        end
    end
    if self.wishlistSocketPickerOuter then
        setShown(self.wishlistSocketPickerOuter, show)
    end
    setShown(self.wishlistSocketPickerFrame, show)
end

function UI:GetWishlistSocketAvailability()
    local slotKey = self.selectedWishlistSlot
    if not slotKey then
        return false, false, nil
    end
    local previewItemId = nil
    if self.wishlistActiveTab == "search" and self.selectedWishlistResult then
        previewItemId = self.selectedWishlistResult.id or self.selectedWishlistResult.itemId
    end
    if not previewItemId then
        local list = Goals:GetActiveWishlist()
        local entry = list and list.items and list.items[slotKey] or nil
        previewItemId = entry and entry.itemId or nil
    end
    local socketTypes = nil
    if previewItemId and Goals.GetItemSocketTypes then
        socketTypes = Goals:GetItemSocketTypes(previewItemId)
    end
    local gemAvailable = socketTypes and #socketTypes > 0 or false
    local enchantAvailable = Goals.IsWishlistSlotEnchantable and Goals:IsWishlistSlotEnchantable(slotKey) or false
    return gemAvailable, enchantAvailable, previewItemId, socketTypes
end

function UI:CreateWishlistTab(page)
    local leftInset = CreateFrame("Frame", "GoalsWishlistLeftInset", page, "GoalsInsetTemplate")
    applyInsetTheme(leftInset)
    leftInset:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -8)
    leftInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 2, 2)
    leftInset:SetWidth(450)
    self.wishlistLeftInset = leftInset

    local rightInset = CreateFrame("Frame", "GoalsWishlistRightInset", page, "GoalsInsetTemplate")
    applyInsetTheme(rightInset)
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 12, 0)
    rightInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -2, 2)
    self.wishlistRightInset = rightInset
    if page.footer then
        anchorToFooter(leftInset, page.footer, 0, nil, 6)
        anchorToFooter(rightInset, page.footer, nil, -8, 6)
    end

    local tabBar = CreateFrame("Frame", nil, rightInset)
    tabBar:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 8, -6)
    tabBar:SetPoint("TOPRIGHT", rightInset, "TOPRIGHT", -8, -6)
    tabBar:SetHeight(24)
    local tabBg = tabBar:CreateTexture(nil, "BORDER")
    tabBg:SetAllPoints(tabBar)
    tabBg:SetTexture(0, 0, 0, 0.45)
    local tabLine = rightInset:CreateTexture(nil, "BORDER")
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    tabLine:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -1)
    tabLine:SetTexture(1, 1, 1, 0.08)

    local managerPage = CreateFrame("Frame", nil, rightInset)
    managerPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -30)
    managerPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)

    local searchPage = CreateFrame("Frame", nil, rightInset)
    searchPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -30)
    searchPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)
    searchPage:Hide()

    local actionsPage = CreateFrame("Frame", nil, rightInset)
    actionsPage:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -30)
    actionsPage:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -6, 6)
    actionsPage:Hide()

    local optionsScroll = CreateFrame("ScrollFrame", "GoalsWishlistOptionsScroll", rightInset, "UIPanelScrollFrameTemplate")
    optionsScroll:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 6, -30)
    optionsScroll:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -26, 6)
    optionsScroll:Hide()
    self.wishlistOptionsScroll = optionsScroll

    local optionsContent = CreateFrame("Frame", "GoalsWishlistOptionsContent", optionsScroll)
    optionsContent:SetPoint("TOPLEFT", optionsScroll, "TOPLEFT", 0, 0)
    optionsContent:SetPoint("TOPRIGHT", optionsScroll, "TOPRIGHT", -20, 0)
    optionsContent:SetHeight(200)
    optionsScroll:SetScrollChild(optionsContent)
    self.wishlistOptionsContent = optionsContent

    local function setWishlistTabSelected(button, selected)
        if not button then
            return
        end
        if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            if selected then
                PanelTemplates_SelectTab(button)
            else
                PanelTemplates_DeselectTab(button)
            end
        elseif selected then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end

    local function selectWishlistTab(key)
        setShown(managerPage, key == "manage")
        setShown(searchPage, key == "search")
        setShown(actionsPage, key == "actions")
        setShown(optionsScroll, key == "options")
        self.wishlistActiveTab = key
        if key ~= "options" then
            hideBuildPreviewTooltip()
            hideBuildShareTooltip()
        end
        if key ~= "manage" and self.buildShareTargetFrame then
            self.buildShareTargetFrame:Hide()
        end
        if self.wishlistSubTabs then
            for name, button in pairs(self.wishlistSubTabs) do
                setWishlistTabSelected(button, name == key)
            end
        end
        if key == "options" and self.wishlistOptionsScroll then
            self.wishlistOptionsScroll:SetVerticalScroll(0)
            local child = self.wishlistOptionsScroll:GetScrollChild()
            if child then
                child:Show()
            end
            if self.UpdateWishlistOptionsLayout then
                self:UpdateWishlistOptionsLayout()
            end
        end
        if self.UpdateTabFooters then
            self:UpdateTabFooters()
        end
    end

    local function createTabButton(text, key, anchor)
        local name = "GoalsWishlistTab" .. tostring(key or "")
        local btn = CreateFrame("Button", name, tabBar, "OptionsFrameTabButtonTemplate")
        btn:SetHeight(24)
        btn:SetText(text)
        if PanelTemplates_TabResize then
            PanelTemplates_TabResize(btn, 8)
        end
        if anchor then
            btn:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
        end
        btn:SetScript("OnClick", function()
            selectWishlistTab(key)
        end)
        return btn
    end

    self.wishlistSubTabs = {}
    self.wishlistSubTabs.manage = createTabButton("Manage", "manage", nil)
    self.wishlistSubTabs.search = createTabButton("Search", "search", self.wishlistSubTabs.manage)
    self.wishlistSubTabs.actions = createTabButton("Actions", "actions", self.wishlistSubTabs.search)
    self.wishlistSubTabs.options = createTabButton("Builds", "options", self.wishlistSubTabs.actions)

    local helpBtn = CreateFrame("Button", "GoalsWishlistHelpButton", tabBar)
    helpBtn:SetSize(18, 18)
    local closeBtn = self.frame and _G[self.frame:GetName() .. "CloseButton"] or nil
    if closeBtn then
        helpBtn:SetPoint("TOPRIGHT", closeBtn, "BOTTOMRIGHT", -20, -2)
    else
        helpBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -28)
    end

    -- info icon
    local icon = helpBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(helpBtn)
    icon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
    helpBtn.icon = icon

    -- highlight
    helpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    local helpLabel = createLabel(tabBar, "Help", "GameFontNormalSmall")
    helpLabel:SetPoint("RIGHT", helpBtn, "LEFT", -4, 0)
    helpLabel:Hide()

    helpBtn:SetScript("OnClick", function()
        self.wishlistHelpOpen = not self.wishlistHelpOpen
        if self.wishlistHelpOpen then
            self.wishlistSocketPickerOpen = false
            if self.UpdateWishlistSocketPickerVisibility then
                self:UpdateWishlistSocketPickerVisibility()
            end
        end
        if self.UpdateWishlistHelpVisibility then
            self:UpdateWishlistHelpVisibility()
        end
    end)
    helpBtn:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Wishlist Help")
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.wishlistHelpButton = helpBtn

    selectWishlistTab("manage")

    if self.wishlistHelpOpen == nil then
        self.wishlistHelpOpen = false
    end
    if not self.wishlistHelpFrame then
        local outer = CreateFrame("Frame", "GoalsWishlistHelpOuter", self.frame)
        outer:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
        outer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -2, 26 + FOOTER_BAR_EXTRA)
        outer:SetWidth(260)
        outer:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        outer:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        outer:Hide()
        self.wishlistHelpOuter = outer

        local helpFrame = CreateFrame("Frame", "GoalsWishlistHelpFrame", outer, "GoalsInsetTemplate")
        applyInsetTheme(helpFrame)
        helpFrame:SetPoint("TOPLEFT", outer, "TOPLEFT", 4, -4)
        helpFrame:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -4, 4)
        helpFrame:Hide()
        self.wishlistHelpFrame = helpFrame

        local helpTitle = createLabel(helpFrame, "Wishlist Help", "GameFontNormal")
        helpTitle:SetPoint("TOPLEFT", helpFrame, "TOPLEFT", 10, -10)

        local helpText = helpFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helpText:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -8)
        helpText:SetPoint("TOPRIGHT", helpFrame, "TOPRIGHT", -10, -8)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(
            "Tips:\n" ..
            "- Use Search to find items and add to a slot.\n" ..
            "- Paste an in-game item link into Search to cache it.\n" ..
            "- Example: |cff...|Hitem:12345:...|h[Item]|h|r\n" ..
            "- You can also paste a raw item ID (12345).\n" ..
            "- Click a slot icon to select it before adding.\n" ..
            "- Alt-click a slot icon to mark found/unfound.\n" ..
            "- Right-click a slot icon to clear it.\n" ..
            "- Enchant ID and Gems apply to the selected slot.\n" ..
            "- Import supports wishlist strings and Wowhead links.\n" ..
            "- Required tokens update as items are marked found."
        )
        self.wishlistHelpText = helpText
    end

    if self.wishlistSocketPickerOpen == nil then
        self.wishlistSocketPickerOpen = false
    end

    local function showEnchantTooltip(owner, enchantId)
        if not enchantId then
            return
        end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        local info = Goals.GetEnchantInfoById and Goals:GetEnchantInfoById(enchantId) or nil
        local spellId = info and info.spellId or nil
        if not spellId and GetSpellInfo then
            local name = GetSpellInfo(enchantId)
            if name then
                spellId = enchantId
            end
        end
        local shown = false
        if spellId then
            local spellLink = GetSpellLink and GetSpellLink(spellId) or nil
            if spellLink then
                GameTooltip:SetHyperlink(spellLink)
                shown = true
            else
                GameTooltip:SetHyperlink("spell:" .. tostring(spellId))
                shown = true
            end
        end
        if not shown then
            if info and info.name then
                GameTooltip:SetText(info.name)
            else
                GameTooltip:SetText("Enchant ID: " .. tostring(enchantId))
            end
        end
        GameTooltip:AddLine("ID: " .. tostring(enchantId), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end

    if not self.wishlistSocketPickerFrame then
        local outer = CreateFrame("Frame", "GoalsWishlistSocketPickerOuter", self.frame)
        outer:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
        outer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -2, 26 + FOOTER_BAR_EXTRA)
        outer:SetWidth(260)
        outer:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        outer:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        outer:Hide()
        self.wishlistSocketPickerOuter = outer

        local pickerFrame = CreateFrame("Frame", "GoalsWishlistSocketPickerFrame", outer, "GoalsInsetTemplate")
        applyInsetTheme(pickerFrame)
        pickerFrame:SetPoint("TOPLEFT", outer, "TOPLEFT", 4, -4)
        pickerFrame:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -4, 4)
        pickerFrame:Hide()
        self.wishlistSocketPickerFrame = pickerFrame

        local title = createLabel(pickerFrame, "Socket Picker", "GameFontNormal")
        title:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 10, -10)
        self.wishlistSocketPickerTitle = title

        local slotLabel = pickerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        slotLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        slotLabel:SetJustifyH("LEFT")
        self.wishlistSocketPickerSlotLabel = slotLabel

        local closeBtn = CreateFrame("Button", "GoalsWishlistSocketPickerCloseButton", pickerFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(20, 18)
        closeBtn:SetText("X")
        closeBtn:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -8, -8)
        closeBtn:SetScript("OnClick", function()
            if UI and UI.CloseWishlistSocketPicker then
                UI:CloseWishlistSocketPicker()
            end
        end)
        self.wishlistSocketPickerClose = closeBtn

        local function createSocketBlock(mode, titleText, topAnchor)
            local block = {}
            block.mode = mode
            block.title = createLabel(pickerFrame, titleText, "GameFontNormal")
            if topAnchor then
                block.title:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -12)
            else
                block.title:SetPoint("TOPLEFT", slotLabel, "BOTTOMLEFT", 0, -10)
            end

            block.searchBox = CreateFrame("EditBox", "GoalsWishlistSocket" .. mode .. "SearchBox", pickerFrame, "InputBoxTemplate")
            block.searchBox:SetPoint("LEFT", block.title, "RIGHT", 8, 0)
            block.searchBox:SetSize(150, 18)
            block.searchBox:SetAutoFocus(false)
            bindEscapeClear(block.searchBox)
            block.searchBox:SetScript("OnEnterPressed", function(selfBox)
                selfBox:ClearFocus()
                UI:UpdateWishlistSocketPickerResults()
            end)
            bindLiveSearch(block.searchBox, function()
                UI:UpdateWishlistSocketPickerResults()
            end, 0.15)

            block.resultsInset = CreateFrame("Frame", "GoalsWishlistSocket" .. mode .. "ResultsInset", pickerFrame, "GoalsInsetTemplate")
            applyInsetTheme(block.resultsInset)
            block.resultsInset:SetPoint("TOPLEFT", block.title, "BOTTOMLEFT", -4, -6)
            block.resultsInset:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -10, 0)
            block.resultsInset:SetHeight((ROW_HEIGHT * 5) + 12)

            block.resultsScroll = CreateFrame("ScrollFrame", "GoalsWishlistSocket" .. mode .. "ResultsScroll", block.resultsInset, "FauxScrollFrameTemplate")
            block.resultsScroll:SetPoint("TOPLEFT", block.resultsInset, "TOPLEFT", 2, -6)
            block.resultsScroll:SetPoint("BOTTOMRIGHT", block.resultsInset, "BOTTOMRIGHT", -26, 6)
            block.resultsScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
                FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
                    UI:UpdateWishlistSocketPickerResults()
                end)
            end)

            block.rows = {}
            for i = 1, 5 do
                local row = CreateFrame("Button", nil, block.resultsInset)
                row:SetHeight(ROW_HEIGHT)
                row:SetPoint("TOPLEFT", block.resultsInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
                row:SetPoint("RIGHT", block.resultsInset, "RIGHT", -26, 0)
                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.icon = icon
                local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text = text
                local selected = row:CreateTexture(nil, "ARTWORK")
                selected:SetAllPoints(row)
                selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
                selected:SetBlendMode("ADD")
                selected:Hide()
                row.selected = selected
                row:SetScript("OnClick", function(selfRow)
                    local chatLink = nil
                    if block.mode == "ENCHANT" then
                        chatLink = getWishlistEnchantChatLink(selfRow.entry and selfRow.entry.id, selfRow.entry)
                    else
                        local itemId = selfRow.entry and (selfRow.entry.id or selfRow.entry.itemId)
                        chatLink = getWishlistItemChatLink(itemId, selfRow.entry and selfRow.entry.link)
                    end
                    if insertWishlistChatLink(chatLink) then
                        return
                    end
                    if block.mode == "ENCHANT" then
                        UI.selectedWishlistEnchantResult = selfRow.entry
                        UI.selectedWishlistEnchantResultId = selfRow.entry and selfRow.entry.id or nil
                        UI.selectedWishlistSocketMode = "ENCHANT"
                        if Goals.CacheEnchantByEntry then
                            Goals:CacheEnchantByEntry(selfRow.entry)
                        end
                    else
                        UI.selectedWishlistGemResult = selfRow.entry
                        UI.selectedWishlistGemResultId = selfRow.entry and selfRow.entry.id or nil
                        UI.selectedWishlistSocketMode = "GEM"
                        if Goals.CacheItemById then
                            local itemId = selfRow.entry and (selfRow.entry.id or selfRow.entry.itemId)
                            if itemId then
                                Goals:CacheItemById(itemId)
                            end
                        end
                    end
                    UI:UpdateWishlistSocketPickerResults()
                end)
                row:SetScript("OnEnter", function(selfRow)
                    if block.mode == "ENCHANT" then
                        if selfRow.entry and selfRow.entry.id then
                            showEnchantTooltip(selfRow, selfRow.entry.id)
                        end
                    elseif selfRow.entry and selfRow.entry.link then
                        GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(selfRow.entry.link)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                block.rows[i] = row
            end

            block.emptyLabel = block.resultsInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            block.emptyLabel:SetPoint("TOPLEFT", block.resultsInset, "TOPLEFT", 8, -10)
            block.emptyLabel:SetText("No results.")
            block.emptyLabel:Hide()

            block.applyBtn = CreateFrame("Button", "GoalsWishlistSocket" .. mode .. "ApplyButton", pickerFrame, "UIPanelButtonTemplate")
            block.applyBtn:SetPoint("TOPLEFT", block.resultsInset, "BOTTOMLEFT", 0, -6)
            block.applyBtn:SetSize(60, 20)
            block.applyBtn:SetText(L.BUTTON_APPLY)
            block.applyBtn:SetScript("OnClick", function()
                if UI and UI.ApplyWishlistSocketSelection then
                    UI:ApplyWishlistSocketSelection(block.mode, block.mode == "ENCHANT" and UI.selectedWishlistEnchantResult or UI.selectedWishlistGemResult, UI.selectedWishlistSocketIndex)
                end
            end)

            block.clearBtn = CreateFrame("Button", "GoalsWishlistSocket" .. mode .. "ClearButton", pickerFrame, "UIPanelButtonTemplate")
            block.clearBtn:SetPoint("LEFT", block.applyBtn, "RIGHT", 6, 0)
            block.clearBtn:SetSize(60, 20)
            block.clearBtn:SetText("Clear")
            block.clearBtn:SetScript("OnClick", function()
                if UI and UI.ClearWishlistSocketSelection then
                    UI:ClearWishlistSocketSelection(block.mode, UI.selectedWishlistSocketIndex)
                end
            end)

            return block
        end

        self.wishlistSocketGemBlock = createSocketBlock("GEM", "Gems", nil)
        self.wishlistSocketEnchantBlock = createSocketBlock("ENCHANT", "Enchants", self.wishlistSocketGemBlock.applyBtn)
    end

    local refreshBtn = CreateFrame("Button", nil, leftInset, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("BOTTOMRIGHT", leftInset, "BOTTOMRIGHT", -8, 10)
    refreshBtn:SetSize(70, 18)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if Goals.RefreshWishlistItemCache then
            Goals:RefreshWishlistItemCache()
        end
    end)
    refreshBtn:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Refresh wishlist cache")
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.wishlistRefreshButton = refreshBtn

    local summary = createLabel(leftInset, "0/0 items found", "GameFontHighlightSmall")
    -- Completion details are displayed in the wishlist footer. Keeping this
    -- compatibility font string hidden avoids covering bottom-row item names.
    summary:Hide()
    self.wishlistCompletionSummary = summary

    local undoBtn = CreateFrame("Button", nil, leftInset, "UIPanelButtonTemplate")
    undoBtn:SetSize(240, 20)
    undoBtn:SetPoint("BOTTOM", leftInset, "BOTTOM", 0, 38)
    undoBtn:SetText("Undo removed item")
    undoBtn:SetScript("OnClick", function()
        if Goals:UndoWishlistRemoval() then UI:UpdateWishlistUI() end
    end)
    undoBtn:Hide()
    self.wishlistUndoButton = undoBtn

    self.wishlistSlotButtons = {}
    local slots = Goals:GetWishlistSlotDefs() or {}
    local leftColumnX = 28
    local rightColumnX = leftInset:GetWidth() - WISHLIST_SLOT_SIZE - 28
    local columnCenter = leftInset:GetWidth() * 0.52
    local centerGap = 3
    local nameOffset = 2
    self.wishlistNameOffset = nameOffset
    local leftLabelWidth = math.max(80, (columnCenter - centerGap) - (leftColumnX + WISHLIST_SLOT_SIZE + nameOffset))
    local rightLabelWidth = math.max(80, (rightColumnX - nameOffset) - (columnCenter + centerGap))
    local topY = -9
    local bottomRowY = 60
    local bottomRowX = {
        MAINHAND = 110,
        OFFHAND = 210,
        RELIC = 310,
    }

    local function createSlotButton(slotDef)
        local button = CreateFrame("Button", nil, leftInset)
        button:SetSize(WISHLIST_SLOT_SIZE, WISHLIST_SLOT_SIZE)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetPoint("CENTER", button, "CENTER", 0, 0)
        border:SetSize(WISHLIST_SLOT_SIZE * 1.8, WISHLIST_SLOT_SIZE * 1.8)
        border:Hide()
        button.border = border

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(button)
        button:SetHighlightTexture(highlight)

        local selected = button:CreateTexture(nil, "OVERLAY")
        selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        selected:SetBlendMode("ADD")
        selected:SetAllPoints(button)
        selected:Hide()
        button.selected = selected

        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.label = label
        button.slotKey = slotDef.key

        local foundShadow = button:CreateTexture(nil, "ARTWORK")
        foundShadow:SetTexture("Interface\\Cooldown\\ping4")
        foundShadow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        foundShadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        foundShadow:SetVertexColor(0, 0, 0, 0.45)
        foundShadow:SetDrawLayer("ARTWORK", 0)
        foundShadow:SetBlendMode("BLEND")
        foundShadow:Hide()
        button.foundShadow = foundShadow

        local foundIcon = button:CreateTexture(nil, "OVERLAY")
        foundIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        foundIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        foundIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        foundIcon:SetVertexColor(0.2, 1, 0.2)
        foundIcon:SetDrawLayer("OVERLAY", 5)
        foundIcon:SetBlendMode("BLEND")
        foundIcon:Hide()
        button.foundIcon = foundIcon

        button.gems = {}
        for i = 1, 3 do
            local gemBtn = CreateFrame("Button", nil, button)
            gemBtn:SetSize(12, 12)
            gemBtn:Hide()
            local gemFrame = gemBtn:CreateTexture(nil, "BACKGROUND")
            gemFrame:SetAllPoints(gemBtn)
            gemBtn.frame = gemFrame
            local gemTex = gemBtn:CreateTexture(nil, "ARTWORK")
            gemTex:SetPoint("TOPLEFT", gemBtn, "TOPLEFT", 1, -1)
            gemTex:SetPoint("BOTTOMRIGHT", gemBtn, "BOTTOMRIGHT", -1, 1)
            gemBtn.icon = gemTex
            gemTex:SetDrawLayer("OVERLAY", 1)
            local gemPlus = gemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            gemPlus:SetPoint("CENTER", gemBtn, "CENTER", 0, 0)
            gemPlus:SetText("+")
            gemPlus:SetTextColor(0.95, 0.82, 0.35)
            gemPlus:Hide()
            gemBtn.plus = gemPlus
            local gemSelected = gemBtn:CreateTexture(nil, "OVERLAY")
            gemSelected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            gemSelected:SetBlendMode("ADD")
            gemSelected:SetAllPoints(gemBtn)
            gemSelected:Hide()
            gemBtn.selected = gemSelected
            gemBtn:SetScript("OnEnter", function(selfGem)
                if selfGem.itemId then
                    GameTooltip:SetOwner(selfGem, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. tostring(selfGem.itemId))
                    GameTooltip:Show()
                elseif selfGem.socketType then
                    GameTooltip:SetOwner(selfGem, "ANCHOR_RIGHT")
                    GameTooltip:SetText(selfGem.socketType .. " Socket")
                end
                GameTooltip:AddLine("Click: Choose gem", 0.75, 0.75, 0.75)
                if selfGem.itemId then
                    GameTooltip:AddLine("Shift-click: Link in chat", 0.75, 0.75, 0.75)
                end
                GameTooltip:Show()
            end)
            gemBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            gemBtn:SetScript("OnClick", function(selfGem)
                if insertWishlistChatLink(getWishlistItemChatLink(selfGem.itemId)) then
                    return
                end
                if UI and UI.OpenWishlistSocketPicker then
                    UI:OpenWishlistSocketPicker("GEM", slotDef.key, selfGem.socketIndex or i)
                end
            end)
            gemBtn.socketIndex = i
            button.gems[i] = gemBtn
        end

        local enchantBtn = CreateFrame("Button", nil, button)
        enchantBtn:SetSize(12, 12)
        enchantBtn:Hide()
        local enchantTex = enchantBtn:CreateTexture(nil, "ARTWORK")
        enchantTex:SetAllPoints(enchantBtn)
        enchantTex:SetTexture("Interface\\Icons\\inv_enchant_formulagood_01")
        enchantBtn.icon = enchantTex
        local enchantPlus = enchantBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        enchantPlus:SetPoint("CENTER", enchantBtn, "CENTER", 0, 0)
        enchantPlus:SetText("+")
        enchantPlus:SetTextColor(0.95, 0.82, 0.35)
        enchantPlus:Hide()
        enchantBtn.plus = enchantPlus
        local enchantSelected = enchantBtn:CreateTexture(nil, "OVERLAY")
        enchantSelected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        enchantSelected:SetBlendMode("ADD")
        enchantSelected:SetAllPoints(enchantBtn)
        enchantSelected:Hide()
        enchantBtn.selected = enchantSelected
        enchantBtn:SetScript("OnEnter", function(selfIcon)
            if selfIcon.enchantId then
                showEnchantTooltip(selfIcon, selfIcon.enchantId)
            elseif selfIcon.enchantAvailable then
                GameTooltip:SetOwner(selfIcon, "ANCHOR_RIGHT")
                GameTooltip:SetText("Empty enchant slot")
            end
            GameTooltip:AddLine("Click: Choose enchant", 0.75, 0.75, 0.75)
            if selfIcon.enchantId then
                GameTooltip:AddLine("Shift-click: Link in chat", 0.75, 0.75, 0.75)
            end
            GameTooltip:Show()
        end)
        enchantBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        enchantBtn:SetScript("OnClick", function(selfEnchant)
            if insertWishlistChatLink(getWishlistEnchantChatLink(selfEnchant.enchantId)) then
                return
            end
            if UI and UI.OpenWishlistSocketPicker then
                UI:OpenWishlistSocketPicker("ENCHANT", slotDef.key)
            end
        end)
        button.enchantIcon = enchantBtn

        button:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            if selfBtn.itemLink then
                GameTooltip:SetHyperlink(selfBtn.itemLink)
            elseif selfBtn.itemId then
                GameTooltip:SetHyperlink("item:" .. tostring(selfBtn.itemId))
            else
                GameTooltip:SetText(slotDef.label or "")
            end
            if selfBtn.itemId then
                GameTooltip:AddLine("Shift-click: Link in chat", 0.75, 0.75, 0.75)
                GameTooltip:AddLine("Alt-click: Mark found   Right-click: Remove", 0.75, 0.75, 0.75)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnClick", function(selfBtn, btn)
            if btn == "LeftButton" and insertWishlistChatLink(getWishlistItemChatLink(selfBtn.itemId, selfBtn.itemLink)) then
                return
            end
            local altDown = (IsModifiedClick and IsModifiedClick("ALT")) or (IsAltKeyDown and IsAltKeyDown())
            if btn == "LeftButton" and altDown then
                if Goals.ToggleWishlistFoundForSlot then
                    Goals:ToggleWishlistFoundForSlot(slotDef.key)
                end
                self.selectedWishlistSlot = slotDef.key
                self:UpdateWishlistUI()
                return
            end
            if btn == "RightButton" then
                Goals:ClearWishlistItem(slotDef.key)
                return
            end
            self.selectedWishlistSlot = slotDef.key
            self:UpdateWishlistUI()
            if self.wishlistActiveTab == "search" and UI and UI.OpenWishlistSocketPicker then
                local gemAvailable, enchantAvailable = self:GetWishlistSocketAvailability()
                if gemAvailable or enchantAvailable then
                    UI:OpenWishlistSocketPicker("AUTO", slotDef.key, 1)
                end
            end
        end)

        return button
    end

    for _, slotDef in ipairs(slots) do
        local button = createSlotButton(slotDef)
        if slotDef.column == 1 then
            button:SetPoint("TOPLEFT", leftInset, "TOPLEFT", leftColumnX, topY - (slotDef.row - 1) * WISHLIST_ROW_SPACING)
            button.label:SetPoint("TOPLEFT", button, "TOPRIGHT", nameOffset, -2)
            button.label:SetFontObject("GameFontHighlightSmall")
            button.label:SetWidth(leftLabelWidth)
            button.label:SetHeight(26)
            button.label:SetJustifyH("LEFT")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("TOP")
            end
            button.label:SetWordWrap(true)
        elseif slotDef.column == 2 then
            button:SetPoint("TOPLEFT", leftInset, "TOPLEFT", rightColumnX, topY - (slotDef.row - 1) * WISHLIST_ROW_SPACING)
            button.label:SetPoint("TOPRIGHT", button, "TOPLEFT", -nameOffset, -2)
            button.label:SetFontObject("GameFontHighlightSmall")
            button.label:SetJustifyH("RIGHT")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("TOP")
            end
            button.label:SetWidth(rightLabelWidth)
            button.label:SetHeight(26)
            button.label:SetWordWrap(true)
        else
            local x = bottomRowX[slotDef.key] or 90
            button:SetPoint("BOTTOMLEFT", leftInset, "BOTTOMLEFT", x, bottomRowY - 24)
            button.label:SetPoint("TOP", button, "BOTTOM", 0, -6)
            button.label:SetFontObject("GameFontHighlightSmall")
            button.label:SetWidth(86)
            button.label:SetJustifyH("CENTER")
            if button.label.SetJustifyV then
                button.label:SetJustifyV("MIDDLE")
            end
            button.label:SetWordWrap(true)
        end
        button.slotKey = slotDef.key
        button.slotLabel = slotDef.label or slotDef.key
        button.column = slotDef.column
        self.wishlistSlotButtons[slotDef.key] = button
    end

    local managerLabel = createLabel(managerPage, L.LABEL_WISHLIST_MANAGER, "GameFontNormal")
    managerLabel:SetPoint("TOPLEFT", managerPage, "TOPLEFT", 4, -4)

    local managerInset = CreateFrame("Frame", "GoalsWishlistManagerInset", managerPage, "GoalsInsetTemplate")
    applyInsetTheme(managerInset)
    managerInset:SetPoint("TOPLEFT", managerPage, "TOPLEFT", 0, -40)
    managerInset:SetPoint("TOPRIGHT", managerPage, "TOPRIGHT", 0, -40)
    managerInset:SetHeight(110)
    self.wishlistManagerInset = managerInset

    local managerScroll = CreateFrame("ScrollFrame", "GoalsWishlistManagerScroll", managerInset, "FauxScrollFrameTemplate")
    managerScroll:SetPoint("TOPLEFT", managerInset, "TOPLEFT", 2, -6)
    managerScroll:SetPoint("BOTTOMRIGHT", managerInset, "BOTTOMRIGHT", -26, 6)
    managerScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistManagerList()
        end)
    end)
    self.wishlistManagerScroll = managerScroll

    self.wishlistManagerRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, managerInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", managerInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", managerInset, "RIGHT", -26, 0)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetBlendMode("ADD")
        row:SetHighlightTexture(highlight)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 2, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        local function createIcon()
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(16, 16)
            icon.tex = icon:CreateTexture(nil, "ARTWORK")
            icon.tex:SetAllPoints(icon)
            icon:SetScript("OnEnter", function(selfIcon)
                if selfIcon.tooltipText then
                    GameTooltip:SetOwner(selfIcon, "ANCHOR_RIGHT")
                    GameTooltip:SetText(selfIcon.tooltipText)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            icon:Hide()
            return icon
        end
                row.iconLoon = createIcon()
                row.iconBistooltip = createIcon()
                row.iconWowtbc = createIcon()
                row.iconCustomClassic = createIcon()
                row.iconCustomTbc = createIcon()
                row.iconCustomWotlk = createIcon()
                row.iconWowhead = createIcon()
                row.iconClass = createIcon()
                row.iconSpec = createIcon()
        row:SetScript("OnClick", function(selfRow)
            if selfRow.listId then
                Goals:SetActiveWishlist(selfRow.listId)
                UI.selectedWishlistList = selfRow.listId
                UI:UpdateWishlistUI()
            end
        end)
        self.wishlistManagerRows[i] = row
    end

    local nameBox = CreateFrame("EditBox", nil, managerPage, "InputBoxTemplate")
    nameBox:SetPoint("TOPLEFT", managerInset, "BOTTOMLEFT", 6, -8)
    nameBox:SetSize(140, 20)
    nameBox:SetAutoFocus(false)
    bindEscapeClear(nameBox)
    self.wishlistNameBox = nameBox

    local createBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    createBtn:SetSize(64, 20)
    createBtn:SetText(L.BUTTON_CREATE)
    createBtn:SetScript("OnClick", function()
        Goals:CreateWishlist(nameBox:GetText())
        nameBox:SetText("")
    end)
    self.wishlistCreateButton = createBtn

    local renameBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    renameBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
    renameBtn:SetSize(64, 20)
    renameBtn:SetText(L.BUTTON_RENAME)
    renameBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if list then
            Goals:RenameWishlist(list.id, nameBox:GetText())
            nameBox:SetText("")
        end
    end)
    self.wishlistRenameButton = renameBtn

    local copyBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    copyBtn:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)
    copyBtn:SetSize(64, 20)
    copyBtn:SetText(L.BUTTON_COPY)
    copyBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if list then
            Goals:CopyWishlist(list.id, nameBox:GetText())
            nameBox:SetText("")
        end
    end)
    self.wishlistCopyButton = copyBtn

    local deleteBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    deleteBtn:SetSize(64, 20)
    deleteBtn:SetText(L.BUTTON_DELETE)
    deleteBtn:SetScript("OnClick", function()
        local list = Goals:GetActiveWishlist()
        if not list then
            return
        end
        StaticPopupDialogs.GOALS_DELETE_WISHLIST = StaticPopupDialogs.GOALS_DELETE_WISHLIST or {
            text = L.WISHLIST_DELETE_CONFIRM,
            button1 = L.WISHLIST_DELETE_ACCEPT,
            button2 = CANCEL,
            OnAccept = function(selfPopup)
                if selfPopup and selfPopup.data then
                    Goals:DeleteWishlist(selfPopup.data)
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        local dialog = StaticPopup_Show("GOALS_DELETE_WISHLIST", list.name or "", nil, list.id)
    end)
    self.wishlistDeleteButton = deleteBtn

    local sendBuildLabel = createLabel(managerPage, L.LABEL_BUILD_SHARE, "GameFontNormal")
    sendBuildLabel:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -14)

    local sendBuildBtn = CreateFrame("Button", nil, managerPage, "UIPanelButtonTemplate")
    sendBuildBtn:SetPoint("TOPLEFT", sendBuildLabel, "BOTTOMLEFT", 0, -4)
    sendBuildBtn:SetSize(120, 20)
    sendBuildBtn:SetText(L.BUTTON_SEND_BUILD)
    sendBuildBtn:SetScript("OnClick", function()
        if UnitExists and UnitIsPlayer and UnitExists("target") and UnitIsPlayer("target") then
            if UnitCanCooperate and not UnitCanCooperate("player", "target") then
                Goals:Print("Build share requires a friendly target or party/raid member.")
                if UI and UI.ShowBuildShareTargetPrompt then
                    UI:ShowBuildShareTargetPrompt()
                end
                return
            end
            local targetName = UnitName("target")
            local ok, err = Goals:SendWishlistBuildTo(targetName)
            if ok then
                Goals:Print(err)
            else
                if err == "SEND_FAILED" or not err or err == "" then
                    Goals:Print("Failed to send build.")
                else
                    Goals:Print(err)
                end
            end
            return
        end
        if UI and UI.ShowBuildShareTargetPrompt then
            UI:ShowBuildShareTargetPrompt()
        end
    end)
    sendBuildBtn:SetScript("OnEnter", function()
        showBuildShareTooltip("Send the selected build to a friendly target, party member, or raid member.")
    end)
    sendBuildBtn:SetScript("OnLeave", function()
        hideBuildShareTooltip()
    end)
    self.wishlistSendBuildButton = sendBuildBtn

    local announceLabel = createLabel(managerPage, L.LABEL_WISHLIST_ANNOUNCE, "GameFontNormal")
    announceLabel:SetPoint("TOPLEFT", sendBuildBtn, "BOTTOMLEFT", 0, -14)

    local announceCheck = CreateFrame("CheckButton", nil, managerPage, "UICheckButtonTemplate")
    announceCheck:SetPoint("TOPLEFT", announceLabel, "BOTTOMLEFT", -4, -2)
    setCheckText(announceCheck, L.CHECK_WISHLIST_ANNOUNCE)
    announceCheck:SetScript("OnClick", function(selfCheck)
        Goals.db.settings.wishlistAnnounce = selfCheck:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    attachSideTooltip(announceCheck, "Post wishlist alerts to chat when items are found.")
    self.wishlistAnnounceCheck = announceCheck

    local soundToggle = createSmallIconButton(managerPage, 20, "Interface\\Common\\VoiceChat-Speaker")
    soundToggle:SetPoint("LEFT", announceLabel, "RIGHT", 6, 0)
    local soundWave = soundToggle:CreateTexture(nil, "OVERLAY")
    soundWave:SetAllPoints(soundToggle)
    soundWave:SetTexture("Interface\\Common\\VoiceChat-On")
    soundWave:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    soundToggle.waveIcon = soundWave
    soundToggle:SetScript("OnClick", function()
        local enabled = Goals.db.settings.wishlistPopupSound and true or false
        Goals.db.settings.wishlistPopupSound = not enabled
        if soundToggle.waveIcon then
            setShown(soundToggle.waveIcon, Goals.db.settings.wishlistPopupSound)
        end
        Goals:NotifyDataChanged()
    end)
    soundToggle:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
        if Goals.db.settings.wishlistPopupSound then
            GameTooltip:SetText("Wishlist alert sound: enabled")
        else
            GameTooltip:SetText("Wishlist alert sound: muted")
        end
        GameTooltip:Show()
    end)
    soundToggle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.wishlistPopupSoundToggle = soundToggle

    local disablePopupCheck = CreateFrame("CheckButton", nil, managerPage, "UICheckButtonTemplate")
    disablePopupCheck:SetPoint("LEFT", announceCheck, "RIGHT", 120, 0)
    setCheckText(disablePopupCheck, "Disable popup alert")
    disablePopupCheck:SetScript("OnClick", function(selfCheck)
        Goals.db.settings.wishlistPopupDisabled = selfCheck:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end)
    attachSideTooltip(disablePopupCheck, "Disable the on-screen wishlist popup.")
    self.wishlistPopupDisableCheck = disablePopupCheck

    local searchLabel = createLabel(searchPage, L.LABEL_WISHLIST_SEARCH, "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", searchPage, "TOPLEFT", 4, -4)

    local searchBox = CreateFrame("EditBox", "GoalsWishlistSearchBox", searchPage, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetSize(210, 20)
    searchBox:SetAutoFocus(false)
    bindEscapeClear(searchBox)
    searchBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        UI:UpdateWishlistSearchResults()
    end)
    bindLiveSearch(searchBox, function()
        UI:UpdateWishlistSearchResults()
    end, 0.15)
    self.wishlistSearchBox = searchBox

    local linkHint = createLabel(searchPage, "Paste item link or item:ID", "GameFontHighlightSmall")
    linkHint:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -4)
    linkHint:SetTextColor(0.7, 0.7, 0.7)

    self.wishlistSlotFilter = nil
    self.wishlistIlvlBox = nil
    self.wishlistStatsBox = nil
    self.wishlistSourceBox = nil

    local resultsLabel = createLabel(searchPage, L.LABEL_WISHLIST_RESULTS, "GameFontNormal")
    resultsLabel:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -14)

    local resultsInset = CreateFrame("Frame", "GoalsWishlistResultsInset", searchPage, "GoalsInsetTemplate")
    applyInsetTheme(resultsInset)
    resultsInset:SetPoint("TOPLEFT", resultsLabel, "BOTTOMLEFT", -4, -6)
    resultsInset:SetPoint("TOPRIGHT", searchPage, "TOPRIGHT", -6, 0)
    resultsInset:SetHeight(110)
    self.wishlistResultsInset = resultsInset

    local resultsScroll = CreateFrame("ScrollFrame", "GoalsWishlistResultsScroll", resultsInset, "FauxScrollFrameTemplate")
    resultsScroll:SetPoint("TOPLEFT", resultsInset, "TOPLEFT", 2, -6)
    resultsScroll:SetPoint("BOTTOMRIGHT", resultsInset, "BOTTOMRIGHT", -26, 6)
    resultsScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistSearchResults()
        end)
    end)
    self.wishlistResultsScroll = resultsScroll

    self.wishlistResultsRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, resultsInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", resultsInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", resultsInset, "RIGHT", -26, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints(row)
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:Hide()
        row.selected = selected
        row:SetScript("OnClick", function(selfRow)
            local itemId = selfRow.entry and (selfRow.entry.id or selfRow.entry.itemId)
            if insertWishlistChatLink(getWishlistItemChatLink(itemId, selfRow.entry and selfRow.entry.link)) then
                return
            end
            UI.selectedWishlistResult = selfRow.entry
            UI:UpdateWishlistSearchResults()
            UI:UpdateWishlistUI()
            if UI.wishlistActiveTab == "search" and UI.selectedWishlistSlot and UI.OpenWishlistSocketPicker then
                local gemAvailable, enchantAvailable = UI:GetWishlistSocketAvailability()
                if gemAvailable or enchantAvailable then
                    UI:OpenWishlistSocketPicker("AUTO", UI.selectedWishlistSlot, 1)
                end
            end
        end)
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.entry and selfRow.entry.link then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.entry.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.wishlistResultsRows[i] = row
    end

    local addSlotBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    addSlotBtn:SetPoint("TOPLEFT", resultsInset, "BOTTOMLEFT", 0, -10)
    addSlotBtn:SetSize(110, 20)
    addSlotBtn:SetText(L.BUTTON_ADD_SLOT)
    addSlotBtn:SetScript("OnClick", function()
        if UI.selectedWishlistResult and UI.selectedWishlistSlot then
            local entry = UI.selectedWishlistResult
            Goals:SetWishlistItemSmart(UI.selectedWishlistSlot, {
                itemId = entry.id or entry.itemId,
                enchantId = 0,
                gemIds = {},
                notes = "",
                source = entry.source or "",
            })
            if UI and UI.TriggerWishlistRefresh then
                UI:TriggerWishlistRefresh()
            end
        end
    end)
    self.wishlistAddSlotButton = addSlotBtn

    local clearSlotBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    clearSlotBtn:SetPoint("LEFT", addSlotBtn, "RIGHT", 8, 0)
    clearSlotBtn:SetSize(100, 20)
    clearSlotBtn:SetText(L.BUTTON_CLEAR_SLOT)
    clearSlotBtn:SetScript("OnClick", function()
        if UI.selectedWishlistSlot then
            Goals:ClearWishlistItem(UI.selectedWishlistSlot)
        end
    end)
    self.wishlistClearSlotButton = clearSlotBtn

    local enchantLabel = createLabel(searchPage, "Enchant ID", "GameFontNormal")
    enchantLabel:SetPoint("TOP", addSlotBtn, "BOTTOM", 0, -12)
    enchantLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)
    self.wishlistEnchantLabel = enchantLabel

    local enchantBox = CreateFrame("EditBox", "GoalsWishlistEnchantBox", searchPage, "InputBoxTemplate")
    enchantBox:SetPoint("LEFT", enchantLabel, "RIGHT", 10, 0)
    enchantBox:SetSize(90, 20)
    enchantBox:SetAutoFocus(false)
    enchantBox:SetNumeric(true)
    enchantBox:SetFontObject(searchBox:GetFontObject())
    bindEscapeClear(enchantBox)
    self.wishlistEnchantBox = enchantBox

    local gemsLabel = createLabel(searchPage, "Gems", "GameFontNormal")
    gemsLabel:SetPoint("TOP", enchantLabel, "BOTTOM", 0, -10)
    gemsLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)
    self.wishlistGemsLabel = gemsLabel

    local gemBoxes = {}
    for i = 1, 3 do
        local gemBox = CreateFrame("EditBox", "GoalsWishlistGemBox"..i, searchPage, "InputBoxTemplate")
        if i == 1 then
            gemBox:SetPoint("LEFT", gemsLabel, "RIGHT", 10, 0)
        else
            gemBox:SetPoint("LEFT", gemBoxes[i - 1], "RIGHT", 6, 0)
        end
        gemBox:SetSize(46, 20)
        gemBox:SetAutoFocus(false)
        gemBox:SetNumeric(true)
        gemBox:SetFontObject(searchBox:GetFontObject())
        bindEscapeClear(gemBox)
        gemBoxes[i] = gemBox
    end
    self.wishlistGemBoxes = gemBoxes

    local applyGemsBtn = CreateFrame("Button", nil, searchPage, "UIPanelButtonTemplate")
    applyGemsBtn:SetPoint("TOPLEFT", addSlotBtn, "BOTTOMLEFT", 0, -66)
    applyGemsBtn:SetSize(60, 20)
    applyGemsBtn:SetText(L.BUTTON_APPLY)
    applyGemsBtn:SetScript("OnClick", function()
        if not UI.selectedWishlistSlot then
            return
        end
        local entry = Goals:GetWishlistItem(UI.selectedWishlistSlot)
        if not entry then
            return
        end
        entry.enchantId = tonumber(enchantBox:GetText()) or 0
        entry.gemIds = {}
        for i = 1, 3 do
            local value = tonumber(gemBoxes[i]:GetText())
            if value and value > 0 then
                table.insert(entry.gemIds, value)
            end
        end
        Goals:SetWishlistItemSmart(UI.selectedWishlistSlot, entry)
        if UI and UI.TriggerWishlistRefresh then
            UI:TriggerWishlistRefresh()
        end
    end)
    self.wishlistApplyGemsButton = applyGemsBtn

    local tokenLabel = createLabel(searchPage, "Required tokens", "GameFontNormal")
    tokenLabel:SetPoint("TOP", applyGemsBtn, "BOTTOM", 0, -10)
    tokenLabel:SetPoint("LEFT", searchLabel, "LEFT", 0, 0)

    local tokenInset = CreateFrame("Frame", "GoalsWishlistTokenInset", searchPage, "GoalsInsetTemplate")
    applyInsetTheme(tokenInset)
    tokenInset:SetPoint("TOPLEFT", tokenLabel, "BOTTOMLEFT", -4, -6)
    tokenInset:SetPoint("TOPRIGHT", searchPage, "TOPRIGHT", -6, 0)
    tokenInset:SetHeight(ROW_HEIGHT * 5 + 12)
    self.wishlistTokenInset = tokenInset

    local tokenScroll = CreateFrame("ScrollFrame", "GoalsWishlistTokenScroll", tokenInset, "FauxScrollFrameTemplate")
    tokenScroll:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 2, -6)
    tokenScroll:SetPoint("BOTTOMRIGHT", tokenInset, "BOTTOMRIGHT", -26, 6)
    tokenScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistTokenDisplay()
        end)
    end)
    self.wishlistTokenScroll = tokenScroll

    self.wishlistTokenRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, tokenInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", tokenInset, "RIGHT", -26, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.itemLink then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.itemLink)
                GameTooltip:Show()
            elseif selfRow.itemId then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. tostring(selfRow.itemId))
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(selfRow)
            insertWishlistChatLink(getWishlistItemChatLink(selfRow.itemId, selfRow.itemLink))
        end)
        self.wishlistTokenRows[i] = row
    end
    local tokenEmpty = tokenInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tokenEmpty:SetPoint("TOPLEFT", tokenInset, "TOPLEFT", 8, -10)
    tokenEmpty:SetText("None required")
    tokenEmpty:Hide()
    self.wishlistTokenEmpty = tokenEmpty
    self.wishlistTokenLabel = tokenLabel

    local popout = actionsPage
    local optionsPopout = optionsContent

    local popoutTitle = createLabel(popout, L.LABEL_WISHLIST_ACTIONS, "GameFontNormal")
    popoutTitle:SetPoint("TOPLEFT", popout, "TOPLEFT", 4, -4)

    local optionsTitle = createLabel(optionsPopout, "Builds", "GameFontNormal")
    optionsTitle:SetPoint("TOPLEFT", optionsPopout, "TOPLEFT", 4, -4)

    local notesLabel = createLabel(popout, L.LABEL_WISHLIST_NOTES, "GameFontNormal")
    notesLabel:SetPoint("TOPLEFT", popout, "TOPLEFT", 10, -36)

    local notesBox = CreateFrame("EditBox", "GoalsWishlistNotesBox", popout, "InputBoxTemplate")
    notesBox:SetPoint("TOPLEFT", notesLabel, "BOTTOMLEFT", 0, -2)
    notesBox:SetSize(180, 20)
    notesBox:SetAutoFocus(false)
    bindEscapeClear(notesBox)
    self.wishlistNotesBox = notesBox

    local sourceEntryLabel = createLabel(popout, L.LABEL_WISHLIST_SOURCE, "GameFontNormal")
    sourceEntryLabel:SetPoint("TOPLEFT", popout, "TOPLEFT", 200, -36)

    local sourceEntryBox = CreateFrame("EditBox", "GoalsWishlistSourceBox", popout, "InputBoxTemplate")
    sourceEntryBox:SetPoint("TOPLEFT", sourceEntryLabel, "BOTTOMLEFT", 0, -2)
    sourceEntryBox:SetSize(120, 20)
    sourceEntryBox:SetAutoFocus(false)
    bindEscapeClear(sourceEntryBox)
    self.wishlistSourceEntryBox = sourceEntryBox

    local applyNotesBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    applyNotesBtn:SetPoint("TOPLEFT", notesBox, "BOTTOMLEFT", 0, -6)
    applyNotesBtn:SetSize(60, 20)
    applyNotesBtn:SetText(L.BUTTON_APPLY)
    applyNotesBtn:SetScript("OnClick", function()
        if not UI.selectedWishlistSlot then
            return
        end
        local entry = Goals:GetWishlistItem(UI.selectedWishlistSlot)
        if not entry then
            return
        end
        entry.notes = notesBox:GetText() or ""
        entry.source = sourceEntryBox:GetText() or ""
        Goals:SetWishlistItem(UI.selectedWishlistSlot, entry)
    end)
    self.wishlistApplyNotesButton = applyNotesBtn

    local importLabel = createLabel(popout, L.LABEL_WISHLIST_IMPORT, "GameFontNormal")
    importLabel:SetPoint("TOPLEFT", applyNotesBtn, "BOTTOMLEFT", 0, -10)

    local importFrame = CreateFrame("Frame", "GoalsWishlistImportFrame", popout, "GoalsInsetTemplate")
    applyInsetTheme(importFrame)
    importFrame:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -4)
    importFrame:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -10, 0)
    importFrame:SetHeight(110)

    local importScroll = CreateFrame("ScrollFrame", "GoalsWishlistImportScroll", importFrame, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 4, -4)
    importScroll:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -26, 4)
    self.wishlistImportScroll = importScroll

    local importBox = CreateFrame("EditBox", "GoalsWishlistImportBox", importScroll)
    importBox:SetMultiLine(true)
    importBox:SetAutoFocus(false)
    importBox:SetFontObject("GameFontHighlightSmall")
    importBox:SetTextInsets(2, 2, 2, 2)
    importBox:SetJustifyH("LEFT")
    importBox:SetPoint("TOPLEFT", importScroll, "TOPLEFT", 0, 0)
    bindEscapeClear(importBox)
    importBox:EnableMouse(true)
    importBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    local importMeasure = importFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    importMeasure:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 0, 0)
    importMeasure:SetJustifyH("LEFT")
    importMeasure:SetWordWrap(true)
    importMeasure:SetFontObject(importBox:GetFontObject())
    importMeasure:Hide()
    importBox:SetScript("OnCursorChanged", function(self, x, y)
        local scroll = -y
        if scroll < 0 then
            scroll = 0
        end
        local maxScroll = math.max(0, (self:GetHeight() or 0) - (importScroll:GetHeight() or 0))
        if scroll > maxScroll then
            scroll = maxScroll
        end
        importScroll:SetVerticalScroll(scroll)
    end)
    local function updateImportBoxSize()
        local width = importScroll:GetWidth() or 0
        local height = importScroll:GetHeight() or 0
        if width <= 0 then
            width = 1
        end
        importBox:SetWidth(width)
        importMeasure:SetWidth(width)
        importMeasure:SetText(importBox:GetText() or "")
        local textHeight = importMeasure:GetStringHeight() + 6
        if height > textHeight then
            textHeight = height
        end
        importBox:SetHeight(textHeight)
        importScroll:UpdateScrollChildRect()
    end
    local function normalizeImportText()
        if importBox.isWrapping then
            return
        end
        local text = importBox:GetText() or ""
        local raw = text:gsub("\r", "")
        raw = raw:gsub("||", "|")
        importBox.rawText = raw
        importBox.isWrapping = true
        updateImportBoxSize()
        importBox.isWrapping = false
    end
    importBox:SetScript("OnTextChanged", function()
        normalizeImportText()
    end)
    importBox:SetScript("OnEditFocusLost", function()
        normalizeImportText()
    end)
    importScroll:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth() or 0
        if width > 0 and importBox.SetWidth then
            importBox:SetWidth(width)
        end
        normalizeImportText()
    end)
    local function scheduleImportNormalize()
        if importBox.normalizeScheduled then
            return
        end
        importBox.normalizeScheduled = true
        importScroll:SetScript("OnUpdate", function(self)
            local width = self:GetWidth() or 0
            if width > 0 then
                self:SetScript("OnUpdate", nil)
                importBox.normalizeScheduled = false
                normalizeImportText()
            end
        end)
    end
    importScroll:SetScript("OnShow", function()
        scheduleImportNormalize()
    end)
    importScroll:SetScrollChild(importBox)
    updateImportBoxSize()
    scheduleImportNormalize()
    self.wishlistImportBox = importBox

    local importModeLabel = createLabel(popout, L.WISHLIST_IMPORT_MODE, "GameFontNormal")
    importModeLabel:SetPoint("TOPLEFT", importScroll, "BOTTOMLEFT", 0, -6)

    local importModeDrop = CreateFrame("Frame", "GoalsWishlistImportModeDropdown", popout, "UIDropDownMenuTemplate")
    importModeDrop:SetPoint("TOPLEFT", importModeLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(importModeDrop, 90)
    UIDropDownMenu_SetButtonWidth(importModeDrop, 104)
    importModeDrop.selectedValue = "NEW"
    UIDropDownMenu_Initialize(importModeDrop, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_NEW
        info.value = "NEW"
        info.func = function()
            importModeDrop.selectedValue = "NEW"
            UIDropDownMenu_SetSelectedValue(importModeDrop, "NEW")
            UI:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_NEW)
        end
        info.checked = importModeDrop.selectedValue == "NEW"
        UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_ACTIVE
        info.value = "ACTIVE"
        info.func = function()
            importModeDrop.selectedValue = "ACTIVE"
            UIDropDownMenu_SetSelectedValue(importModeDrop, "ACTIVE")
            UI:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_ACTIVE)
        end
        info.checked = importModeDrop.selectedValue == "ACTIVE"
        UIDropDownMenu_AddButton(info, level)
    end)
    self.wishlistImportMode = importModeDrop
    self:SetDropdownText(importModeDrop, L.WISHLIST_IMPORT_NEW)

    local exportBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    exportBtn:SetPoint("LEFT", importModeDrop, "RIGHT", 0, 2)
    exportBtn:SetSize(60, 20)
    exportBtn:SetText(L.BUTTON_EXPORT)
    exportBtn:SetScript("OnClick", function()
        local text = Goals:ExportActiveWishlist() or ""
        local display = text:gsub("|", "||")
        importBox.rawText = text
        importBox:SetText(display)
        updateImportBoxSize()
        importBox:HighlightText()
    end)
    self.wishlistExportButton = exportBtn

    local importBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)
    importBtn:SetSize(60, 20)
    importBtn:SetText(L.BUTTON_IMPORT)
    importBtn:SetScript("OnClick", function()
        local text = importBox.rawText or importBox:GetText() or ""
        if importModeDrop.selectedValue == "NEW" then
            local ok, err = Goals:ImportWishlistString(text)
            if not ok then
                Goals:Print(err or "Import failed.")
            end
        else
            local data, err = Goals:DeserializeWishlist(text)
            if not data then
                Goals:Print(err or "Import failed.")
                return
            end
            local list = Goals:GetActiveWishlist()
            if list then
                list.items = data.items or {}
                list.updated = time()
                Goals:NotifyDataChanged()
            end
        end
    end)
    self.wishlistImportButton = importBtn

    local wowheadBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
    wowheadBtn:SetPoint("TOPLEFT", importModeDrop, "BOTTOMLEFT", 16, -6)
    wowheadBtn:SetSize(130, 20)
    wowheadBtn:SetText(L.BUTTON_IMPORT_WOWHEAD)
    wowheadBtn:SetScript("OnClick", function()
        local text = importBox.rawText or importBox:GetText() or ""
        local items, err = Goals:ImportWowhead(text)
        if not items then
            Goals:Print(err or "Wowhead import failed.")
            return
        end
        local targetId = nil
        if importModeDrop.selectedValue == "NEW" then
            local list = Goals:CreateWishlist("Wowhead Import")
            targetId = list and list.id or nil
        else
            local list = Goals:GetActiveWishlist()
            targetId = list and list.id or nil
        end
        local ok, summary = Goals:ApplyImportedWishlistItems(items, targetId)
        if ok and summary then
            Goals:Print(summary)
            if targetId then
                Goals:SetActiveWishlist(targetId)
            end
        elseif not ok then
            Goals:Print(summary or "Import failed.")
        end
    end)
    self.wishlistWowheadButton = wowheadBtn

    local function formatAtlasListOptions(lists)
        local maxList = 10
        local lines = {}
        local count = math.min(#lists, maxList)
        for i = 1, count do
            local entry = lists[i]
            table.insert(lines, string.format("%d) %s", i, entry.name or entry.key))
        end
        if #lists > maxList then
            table.insert(lines, string.format("...and %d more (type full name).", #lists - maxList))
        end
        return table.concat(lines, "\n")
    end

    local function showAtlasSelectPopup(lists)
        StaticPopupDialogs.GOALS_ATLAS_SELECT = StaticPopupDialogs.GOALS_ATLAS_SELECT or {
            text = "Multiple AtlasLoot wishlists found.",
            button1 = "Import",
            button2 = CANCEL,
            hasEditBox = 1,
            editBoxWidth = 220,
            OnShow = function(selfPopup, data)
                selfPopup.editBox:SetText("")
                selfPopup.editBox:SetFocus()
                if data and data.message then
                    selfPopup.text:SetText(data.message)
                end
            end,
            OnAccept = function(selfPopup, data)
                local input = selfPopup.editBox:GetText() or ""
                local listsData = data and data.lists or {}
                local selected = nil
                local index = tonumber(input)
                if index and listsData[index] then
                    selected = listsData[index]
                elseif input ~= "" then
                    for _, entry in ipairs(listsData) do
                        if entry.name == input or entry.key == input then
                            selected = entry
                            break
                        end
                    end
                end
                if not selected then
                    Goals:Print("No matching AtlasLoot wishlist found.")
                    return
                end
                Goals.db.settings.atlasSelectedListKey = selected.key
                if Goals.ImportAtlasLootWishlist then
                    local ok, msg = Goals:ImportAtlasLootWishlist(selected.key)
                    if msg then
                        Goals:Print(msg)
                    end
                    if ok and Goals.UI and Goals.UI.UpdateWishlistUI then
                        Goals.UI:UpdateWishlistUI()
                    end
                end
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        local message = "Multiple AtlasLoot wishlists found.\nEnter number or name to import:\n" .. formatAtlasListOptions(lists)
        StaticPopup_Show("GOALS_ATLAS_SELECT", nil, nil, { lists = lists, message = message })
    end

    local function startAtlasImport()
        if not Goals.GetAtlasLootWishlistSelection then
            return
        end
        if not (Goals.db and Goals.db.settings) then
            return
        end
        local lists, selected = Goals:GetAtlasLootWishlistSelection()
        if #lists == 0 then
            Goals:Print("No AtlasLoot wishlist items found.")
            return
        end
        if #lists == 1 then
            selected = lists[1]
        end
        if not selected then
            showAtlasSelectPopup(lists)
            return
        end
        Goals.db.settings.atlasSelectedListKey = selected.key
        if Goals.ImportAtlasLootWishlist then
            local ok, msg = Goals:ImportAtlasLootWishlist(selected.key)
            if msg then
                Goals:Print(msg)
            end
            if ok and Goals.UI and Goals.UI.UpdateWishlistUI then
                Goals.UI:UpdateWishlistUI()
            end
        end
    end

    if Goals.HasAtlasLootEnhanced and Goals:HasAtlasLootEnhanced() then
        local atlasBtn = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
        atlasBtn:SetPoint("LEFT", wowheadBtn, "RIGHT", 6, 0)
        atlasBtn:SetSize(120, 20)
        atlasBtn:SetText("Import AtlasLoot")
        atlasBtn:SetScript("OnClick", function()
            startAtlasImport()
        end)
        self.wishlistAtlasButton = atlasBtn
    else
        self.wishlistAtlasButton = nil
    end

    if Goals and Goals.db and Goals.db.settings and not Goals.db.settings.atlasImportPrompted then
        if Goals.HasAtlasLootEnhanced and Goals:HasAtlasLootEnhanced() then
            StaticPopupDialogs.GOALS_ATLAS_IMPORT = StaticPopupDialogs.GOALS_ATLAS_IMPORT or {
                text = "AtlasLoot wishlist detected. Import now?",
                button1 = "Import",
                button2 = CANCEL,
                OnAccept = function()
                    Goals.db.settings.atlasImportPrompted = true
                    startAtlasImport()
                end,
                OnCancel = function()
                    Goals.db.settings.atlasImportPrompted = true
                end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
            }
            StaticPopup_Show("GOALS_ATLAS_IMPORT")
        else
            Goals.db.settings.atlasImportPrompted = true
        end
    end

    local buildLibraryAnchor = optionsTitle

    local buildFilterLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_FILTERS, "GameFontHighlightSmall")
    buildFilterLabel:SetPoint("TOPLEFT", buildLibraryAnchor, "BOTTOMLEFT", 0, -6)
    buildFilterLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)
    self.wishlistBuildFilterLabel = buildFilterLabel

    local classLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_CLASS, "GameFontNormalSmall")
    classLabel:SetPoint("TOPLEFT", buildFilterLabel, "BOTTOMLEFT", 0, -8)
    classLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)

    local classDrop = CreateFrame("Frame", "GoalsWishlistBuildClassDrop", optionsPopout, "UIDropDownMenuTemplate")
    classDrop:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", -16, -2)
    styleDropdown(classDrop, 140)
    self.wishlistBuildClassDrop = classDrop

    local specLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_SPEC, "GameFontNormalSmall")
    specLabel:SetPoint("TOPLEFT", classDrop, "BOTTOMLEFT", 16, -8)
    specLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)

    local specDrop = CreateFrame("Frame", "GoalsWishlistBuildSpecDrop", optionsPopout, "UIDropDownMenuTemplate")
    specDrop:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -16, -2)
    styleDropdown(specDrop, 140)
    self.wishlistBuildSpecDrop = specDrop

    local rightColumnAnchor = CreateFrame("Frame", nil, optionsPopout)
    rightColumnAnchor:SetPoint("TOPLEFT", buildFilterLabel, "BOTTOMLEFT", 170, -8)
    rightColumnAnchor:SetSize(1, 1)

    local tierLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_TIER, "GameFontNormalSmall")
    tierLabel:SetPoint("TOPLEFT", rightColumnAnchor, "TOPLEFT", 0, 0)

    local tierDrop = CreateFrame("Frame", "GoalsWishlistBuildTierDrop", optionsPopout, "UIDropDownMenuTemplate")
    tierDrop:SetPoint("TOPLEFT", tierLabel, "BOTTOMLEFT", -16, -2)
    styleDropdown(tierDrop, 170)
    self.wishlistBuildTierDrop = tierDrop

    local tagLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_TAG, "GameFontNormalSmall")
    tagLabel:SetPoint("TOPLEFT", tierDrop, "BOTTOMLEFT", 16, -8)
    tagLabel:SetPoint("LEFT", rightColumnAnchor, "LEFT", 0, 0)

    local tagDrop = CreateFrame("Frame", "GoalsWishlistBuildTagDrop", optionsPopout, "UIDropDownMenuTemplate")
    tagDrop:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", -16, -2)
    styleDropdown(tagDrop, 170)
    self.wishlistBuildTagDrop = tagDrop
    tagDrop:SetPoint("LEFT", tierDrop, "LEFT", 0, 0)

    local levelLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_LEVEL, "GameFontNormalSmall")
    levelLabel:SetPoint("TOPLEFT", specDrop, "BOTTOMLEFT", 16, -8)
    levelLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)

    local levelBox = CreateFrame("EditBox", "GoalsWishlistBuildLevelBox", optionsPopout, "InputBoxTemplate")
    levelBox:SetPoint("LEFT", levelLabel, "RIGHT", 8, 0)
    levelBox:SetSize(40, 18)
    levelBox:SetAutoFocus(false)
    levelBox:SetNumeric(true)
    bindEscapeClear(levelBox)
    levelBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        if UI and UI.UpdateWishlistBuildList then
            UI:UpdateWishlistBuildList()
        end
    end)
    self.wishlistBuildLevelBox = levelBox

    local levelAutoCheck = CreateFrame("CheckButton", nil, optionsPopout, "UICheckButtonTemplate")
    levelAutoCheck:SetPoint("LEFT", levelBox, "RIGHT", 6, 0)
    setCheckText(levelAutoCheck, "Auto")
    levelAutoCheck:SetScript("OnClick", function(selfCheck)
        if Goals.db and Goals.db.settings and Goals.db.settings.wishlistBuildFilters then
            Goals.db.settings.wishlistBuildFilters.levelMode = selfCheck:GetChecked() and "AUTO" or "MANUAL"
        end
        if UI and UI.UpdateWishlistBuildList then
            UI:UpdateWishlistBuildList()
        end
    end)
    self.wishlistBuildLevelAuto = levelAutoCheck

    local resetFiltersBtn = CreateFrame("Button", nil, optionsPopout, "UIPanelButtonTemplate")
    resetFiltersBtn:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", -2, -8)
    resetFiltersBtn:SetSize(110, 20)
    resetFiltersBtn:SetText(L.BUTTON_RESET_FILTERS)
    resetFiltersBtn:SetScript("OnClick", function()
        if UI and UI.ResetWishlistBuildFilters then
            UI:ResetWishlistBuildFilters(false)
        end
    end)
    self.wishlistBuildResetFilters = resetFiltersBtn

    local useDetectedBtn = CreateFrame("Button", nil, optionsPopout, "UIPanelButtonTemplate")
    useDetectedBtn:SetPoint("LEFT", resetFiltersBtn, "RIGHT", 6, 0)
    useDetectedBtn:SetSize(110, 20)
    useDetectedBtn:SetText(L.BUTTON_USE_DETECTED)
    useDetectedBtn:SetScript("OnClick", function()
        if UI and UI.ResetWishlistBuildFilters then
            UI:ResetWishlistBuildFilters(true)
        end
    end)
    self.wishlistBuildUseDetected = useDetectedBtn

    local buildResultsLabel = createLabel(optionsPopout, L.LABEL_WISHLIST_BUILD_RESULTS, "GameFontNormal")
    buildResultsLabel:SetPoint("TOPLEFT", resetFiltersBtn, "BOTTOMLEFT", 2, -10)
    buildResultsLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)
    self.wishlistBuildResultsLabel = buildResultsLabel

    local buildResultsInset = CreateFrame("Frame", "GoalsWishlistBuildResultsInset", optionsPopout, "GoalsInsetTemplate")
    applyInsetTheme(buildResultsInset)
    buildResultsInset:SetPoint("TOPLEFT", buildResultsLabel, "BOTTOMLEFT", -4, -6)
    buildResultsInset:SetPoint("TOPRIGHT", optionsPopout, "TOPRIGHT", -10, 0)
    buildResultsInset:SetHeight(110)
    self.wishlistBuildResultsInset = buildResultsInset

    local buildResultsScroll = CreateFrame("ScrollFrame", "GoalsWishlistBuildResultsScroll", buildResultsInset, "FauxScrollFrameTemplate")
    buildResultsScroll:SetPoint("TOPLEFT", buildResultsInset, "TOPLEFT", 2, -6)
    buildResultsScroll:SetPoint("BOTTOMRIGHT", buildResultsInset, "BOTTOMRIGHT", -26, 6)
    buildResultsScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateWishlistBuildList()
        end)
    end)
    self.wishlistBuildResultsScroll = buildResultsScroll

    self.wishlistBuildResultsRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Button", nil, buildResultsInset)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", buildResultsInset, "TOPLEFT", 8, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", buildResultsInset, "RIGHT", -26, 0)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetBlendMode("ADD")
        row:SetHighlightTexture(highlight)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 2, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text = text
        local function createIcon()
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(16, 16)
            icon.tex = icon:CreateTexture(nil, "ARTWORK")
            icon.tex:SetAllPoints(icon)
            icon:SetScript("OnEnter", function(selfIcon)
                if selfIcon.tooltipText then
                    GameTooltip:SetOwner(selfIcon, "ANCHOR_RIGHT")
                    GameTooltip:SetText(selfIcon.tooltipText)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            icon:Hide()
            return icon
        end
            row.iconLoon = createIcon()
            row.iconBistooltip = createIcon()
            row.iconWowtbc = createIcon()
            row.iconCustomClassic = createIcon()
            row.iconCustomTbc = createIcon()
            row.iconCustomWotlk = createIcon()
            row.iconWowhead = createIcon()
            row.iconClass = createIcon()
            row.iconSpec = createIcon()
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetAllPoints(row)
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:Hide()
        row.selected = selected
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.build then
                GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfRow.build.name or "Build")
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(selfRow)
            if selfRow.build then
                if UI.selectedWishlistBuild == selfRow.build then
                    hideBuildPreviewTooltip()
                else
                    showBuildPreviewTooltip(selfRow.build)
                end
                UI:UpdateWishlistBuildList()
            end
        end)
        self.wishlistBuildResultsRows[i] = row
    end

    local buildEmptyLabel = buildResultsInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    buildEmptyLabel:SetPoint("TOPLEFT", buildResultsInset, "TOPLEFT", 8, -10)
    buildEmptyLabel:SetPoint("TOPRIGHT", buildResultsInset, "TOPRIGHT", -8, -10)
    buildEmptyLabel:SetJustifyH("LEFT")
    buildEmptyLabel:SetText("Build library is installed, but item data is not available yet.")
    buildEmptyLabel:Hide()
    self.wishlistBuildEmptyLabel = buildEmptyLabel

    local buildNoMatchLabel = buildResultsInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    buildNoMatchLabel:SetPoint("TOPLEFT", buildResultsInset, "TOPLEFT", 8, -10)
    buildNoMatchLabel:SetPoint("TOPRIGHT", buildResultsInset, "TOPRIGHT", -8, -10)
    buildNoMatchLabel:SetJustifyH("LEFT")
    buildNoMatchLabel:SetText("No builds match the current filters.")
    buildNoMatchLabel:Hide()
    self.wishlistBuildNoMatchLabel = buildNoMatchLabel

    local buildModeLabel = createLabel(optionsPopout, L.WISHLIST_IMPORT_MODE, "GameFontNormalSmall")
    buildModeLabel:SetPoint("TOPLEFT", buildResultsInset, "BOTTOMLEFT", 0, -8)
    buildModeLabel:SetPoint("LEFT", optionsTitle, "LEFT", 0, 0)

    local buildModeDrop = CreateFrame("Frame", "GoalsWishlistBuildImportModeDropdown", optionsPopout, "UIDropDownMenuTemplate")
    buildModeDrop:SetPoint("TOPLEFT", buildModeLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(buildModeDrop, 90)
    UIDropDownMenu_SetButtonWidth(buildModeDrop, 104)
    buildModeDrop.selectedValue = "NEW"
    UIDropDownMenu_Initialize(buildModeDrop, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_NEW
        info.value = "NEW"
        info.func = function()
            buildModeDrop.selectedValue = "NEW"
            UIDropDownMenu_SetSelectedValue(buildModeDrop, "NEW")
            UI:SetDropdownText(buildModeDrop, L.WISHLIST_IMPORT_NEW)
        end
        info.checked = buildModeDrop.selectedValue == "NEW"
        UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = L.WISHLIST_IMPORT_ACTIVE
        info.value = "ACTIVE"
        info.func = function()
            buildModeDrop.selectedValue = "ACTIVE"
            UIDropDownMenu_SetSelectedValue(buildModeDrop, "ACTIVE")
            UI:SetDropdownText(buildModeDrop, L.WISHLIST_IMPORT_ACTIVE)
        end
        info.checked = buildModeDrop.selectedValue == "ACTIVE"
        UIDropDownMenu_AddButton(info, level)
    end)
    self.wishlistBuildImportMode = buildModeDrop
    self:SetDropdownText(buildModeDrop, L.WISHLIST_IMPORT_NEW)

    local buildImportBtn = CreateFrame("Button", nil, optionsPopout, "UIPanelButtonTemplate")
    buildImportBtn:SetPoint("LEFT", buildModeDrop, "RIGHT", 0, 2)
    buildImportBtn:SetSize(120, 20)
    buildImportBtn:SetText(L.BUTTON_IMPORT_BUILD)
    buildImportBtn:SetScript("OnClick", function()
        if not UI.selectedWishlistBuild then
            Goals:Print("Select a build to import.")
            return
        end
        local mode = buildModeDrop and buildModeDrop.selectedValue or "NEW"
        local ok, msg = Goals:ApplyWishlistBuild(UI.selectedWishlistBuild, mode)
        if msg then
            Goals:Print(msg)
        end
        if ok and Goals.UI and Goals.UI.UpdateWishlistUI then
            Goals.UI:UpdateWishlistUI()
        end
        if ok and UI and UI.TriggerWishlistRefresh then
            UI:TriggerWishlistRefresh()
        end
    end)
    self.wishlistBuildImportButton = buildImportBtn

    local function updateOptionsContentHeight()
        local scrollWidth = optionsScroll:GetWidth() or 0
        if scrollWidth > 0 then
            optionsContent:SetWidth(scrollWidth - 24)
        end
        local top = optionsContent:GetTop() or 0
        local bottom = 0
        if buildImportBtn and buildImportBtn.GetBottom then
            bottom = buildImportBtn:GetBottom() or 0
        end
        local height = 0
        if top > 0 and bottom > 0 then
            height = (top - bottom) + 30
        end
        if height <= 0 then
            height = math.max(optionsScroll:GetHeight() or 0, 160)
        end
        if height < (optionsScroll:GetHeight() or 0) then
            height = optionsScroll:GetHeight()
        end
        optionsContent:SetHeight(height)
        setScrollBarAlwaysVisible(optionsScroll, height)
    end
    optionsScroll:SetScript("OnShow", function(selfScroll)
        updateOptionsContentHeight()
        selfScroll:SetVerticalScroll(0)
    end)
    optionsScroll:SetScript("OnSizeChanged", updateOptionsContentHeight)
    self.UpdateWishlistOptionsLayout = updateOptionsContentHeight

    self.wishlistChannelDrop = nil
    -- Auto-only announcement channel; no user selection.

    if slots[1] then
        self.selectedWishlistSlot = slots[1].key
    end
end

function UI:UpdateWishlistManagerList()
    if not self.wishlistManagerScroll or not self.wishlistManagerRows then
        return
    end
    local data = Goals:EnsureWishlistData()
    local lists = data and data.lists or {}
    local offset = FauxScrollFrame_GetOffset(self.wishlistManagerScroll) or 0
    FauxScrollFrame_Update(self.wishlistManagerScroll, #lists, #self.wishlistManagerRows, ROW_HEIGHT)
    for i = 1, #self.wishlistManagerRows do
        local row = self.wishlistManagerRows[i]
        local index = i + offset
        local list = lists[index]
        if list then
            row:Show()
            row.listId = list.id
            local count = 0
            for _ in pairs(list.items or {}) do
                count = count + 1
            end
            local iconX = 2
            local function placeIcon(icon, tooltipText)
                icon.tooltipText = tooltipText
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", row, "LEFT", iconX, 0)
                icon:Show()
                iconX = iconX + 18
            end
            local meta = list.buildMeta
            if meta then
                local loonTexture = Goals.IconTextures and Goals.IconTextures.loonbis or nil
                if loonTexture and wishlistHasLoon(meta) then
                    row.iconLoon.tex:SetTexture(loonTexture)
                    row.iconLoon.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconLoon, "LoonBiS")
                else
                    row.iconLoon:Hide()
                end
                local bistooltipTexture = Goals.IconTextures and Goals.IconTextures.bistooltip or nil
                if bistooltipTexture and wishlistHasBistooltip(meta) then
                    row.iconBistooltip.tex:SetTexture(bistooltipTexture)
                    row.iconBistooltip.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconBistooltip, "BiS-Tooltip")
                else
                    row.iconBistooltip:Hide()
                end
                local wowtbcKey, wowtbcTooltip = wishlistWowtbcSource(meta)
                local wowtbcTexture = wowtbcKey and Goals.IconTextures and Goals.IconTextures[wowtbcKey] or nil
                if wowtbcTexture then
                    row.iconWowtbc.tex:SetTexture(wowtbcTexture)
                    row.iconWowtbc.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconWowtbc, wowtbcTooltip or "wowtbc.gg")
                else
                    row.iconWowtbc:Hide()
                end
                local customSources = wishlistCustomSources(meta)
                local customClassic = Goals.IconTextures and Goals.IconTextures["custom-classic"] or nil
                if customClassic and customSources["custom-classic"] then
                    row.iconCustomClassic.tex:SetTexture(customClassic)
                    row.iconCustomClassic.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconCustomClassic, "Custom Classic")
                else
                    row.iconCustomClassic:Hide()
                end
                local customTbc = Goals.IconTextures and Goals.IconTextures["custom-tbc"] or nil
                if customTbc and customSources["custom-tbc"] then
                    row.iconCustomTbc.tex:SetTexture(customTbc)
                    row.iconCustomTbc.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconCustomTbc, "Custom TBC")
                else
                    row.iconCustomTbc:Hide()
                end
                local customWotlk = Goals.IconTextures and Goals.IconTextures["custom-wotlk"] or nil
                if customWotlk and customSources["custom-wotlk"] then
                    row.iconCustomWotlk.tex:SetTexture(customWotlk)
                    row.iconCustomWotlk.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconCustomWotlk, "Custom WotLK")
                else
                    row.iconCustomWotlk:Hide()
                end
                local wowheadTexture = Goals.IconTextures and Goals.IconTextures.wowhead or nil
                if wowheadTexture and wishlistHasWowhead(meta) then
                    row.iconWowhead.tex:SetTexture(wowheadTexture)
                    row.iconWowhead.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconWowhead, "Wowhead")
                else
                    row.iconWowhead:Hide()
                end
                if meta.class then
                    local classCoords = _G.CLASS_BUTTONS and _G.CLASS_BUTTONS[meta.class]
                    if classCoords then
                        local classSprite = Goals.IconTextures and Goals.IconTextures.classSprite or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
                        row.iconClass.tex:SetTexture(classSprite)
                        row.iconClass.tex:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4])
                    else
                        row.iconClass.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        row.iconClass.tex:SetTexCoord(0, 1, 0, 1)
                    end
                    local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[meta.class]) or meta.class
                    placeIcon(row.iconClass, className)
                else
                    row.iconClass:Hide()
                end
                local specKey = wishlistSpecKey({class = meta.class, spec = meta.spec})
                local specTexture = specKey and Goals.IconTextures and Goals.IconTextures.spec and Goals.IconTextures.spec[specKey] or nil
                if specTexture then
                    row.iconSpec.tex:SetTexture(specTexture)
                    row.iconSpec.tex:SetTexCoord(0, 1, 0, 1)
                    placeIcon(row.iconSpec, meta.spec or specKey)
                else
                    row.iconSpec:Hide()
                end
            else
                row.iconLoon:Hide()
                row.iconBistooltip:Hide()
                row.iconWowtbc:Hide()
                row.iconCustomClassic:Hide()
                row.iconCustomTbc:Hide()
                row.iconCustomWotlk:Hide()
                row.iconWowhead:Hide()
                row.iconClass:Hide()
                row.iconSpec:Hide()
            end
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row, "LEFT", iconX + 2, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            local displayName = meta and stripTextureTags(list.name or "Wishlist") or (list.name or "Wishlist")
            row.text:SetText(string.format("%s (%d)", displayName, count))
            if data and data.activeId == list.id then
                row.text:SetTextColor(0.1, 1, 0.1)
            else
                row.text:SetTextColor(1, 1, 1)
            end
        else
            row:Hide()
            row.listId = nil
            if row.iconLoon then row.iconLoon:Hide() end
            if row.iconBistooltip then row.iconBistooltip:Hide() end
            if row.iconWowtbc then row.iconWowtbc:Hide() end
            if row.iconCustomClassic then row.iconCustomClassic:Hide() end
            if row.iconCustomTbc then row.iconCustomTbc:Hide() end
            if row.iconCustomWotlk then row.iconCustomWotlk:Hide() end
            if row.iconWowhead then row.iconWowhead:Hide() end
            if row.iconClass then row.iconClass:Hide() end
            if row.iconSpec then row.iconSpec:Hide() end
        end
    end
end

function UI:UpdateWishlistSearchResults()
    if not self.wishlistResultsScroll or not self.wishlistResultsRows then
        return
    end
    local query = self.wishlistSearchBox and self.wishlistSearchBox:GetText() or ""
    self.wishlistResults = Goals:SearchWishlistItems(query, nil)
    local offset = FauxScrollFrame_GetOffset(self.wishlistResultsScroll) or 0
    FauxScrollFrame_Update(self.wishlistResultsScroll, #self.wishlistResults, #self.wishlistResultsRows, ROW_HEIGHT)
    for i = 1, #self.wishlistResultsRows do
        local row = self.wishlistResultsRows[i]
        local index = i + offset
        local entry = self.wishlistResults[index]
        if entry then
            row:Show()
            row.entry = entry
            row.text:SetText(entry.name or ("Item " .. tostring(entry.id or "")))
            if entry.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality] then
                local color = ITEM_QUALITY_COLORS[entry.quality]
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            if entry.texture then
                row.icon:SetTexture(entry.texture)
                row.icon:Show()
            else
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end
            if self.selectedWishlistResult == entry then
                row.selected:Show()
            else
                row.selected:Hide()
            end
        else
            row:Hide()
            row.entry = nil
            row.selected:Hide()
        end
    end
    if self.wishlistAddSlotButton then
        if self.selectedWishlistSlot and self.selectedWishlistResult then
            self.wishlistAddSlotButton:Enable()
        else
            self.wishlistAddSlotButton:Disable()
        end
    end
    if self.wishlistClearSlotButton then
        if self.selectedWishlistSlot then
            self.wishlistClearSlotButton:Enable()
        else
            self.wishlistClearSlotButton:Disable()
        end
    end
    if self.UpdateWishlistTokenDisplay then
        self:UpdateWishlistTokenDisplay()
    end
end

function UI:UpdateWishlistTokenDisplay()
    if not self.wishlistTokenRows or not self.wishlistTokenScroll then
        return
    end
    local list = Goals:GetActiveWishlist()
    local tokens = {}
    local ordered = {}
    local foundMap = nil
    if list and list.id and Goals.GetWishlistFoundMap then
        foundMap = Goals:GetWishlistFoundMap(list.id)
    end
    local slotRank = {}
    if Goals.GetWishlistSlotDefs then
        local defs = Goals:GetWishlistSlotDefs() or {}
        for index, def in ipairs(defs) do
            if def and def.key then
                slotRank[def.key] = index
            end
        end
    end
    for slotKey, entry in pairs(list and list.items or {}) do
        if entry and entry.itemId then
            local isClaimed = foundMap and (foundMap[entry.itemId] or (entry.tokenId and foundMap[entry.tokenId]))
            if not isClaimed then
                local tokenId = Goals.GetArmorTokenForItem and Goals:GetArmorTokenForItem(entry.itemId) or entry.tokenId
                if tokenId and tokenId > 0 then
                    local rank = slotRank[slotKey] or 999
                    if tokens[tokenId] then
                        tokens[tokenId].count = tokens[tokenId].count + 1
                        if rank < tokens[tokenId].rank then
                            tokens[tokenId].rank = rank
                        end
                    else
                        tokens[tokenId] = { count = 1, rank = rank }
                    end
                end
            end
        end
    end
    for tokenId, count in pairs(tokens) do
        table.insert(ordered, { id = tokenId, count = count.count, rank = count.rank })
    end
    table.sort(ordered, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.id < b.id
    end)
    if self.wishlistTokenEmpty then
        setShown(self.wishlistTokenEmpty, #ordered == 0)
    end
    local visibleRows = math.min(#self.wishlistTokenRows, math.max(#ordered, 1))
    local insetHeight = (visibleRows * ROW_HEIGHT) + 12
    if self.wishlistTokenInset then
        self.wishlistTokenInset:SetHeight(insetHeight)
    end
    if self.wishlistTokenScroll then
        if #ordered > #self.wishlistTokenRows then
            self.wishlistTokenScroll:Show()
        else
            self.wishlistTokenScroll:Hide()
        end
    end
    local offset = FauxScrollFrame_GetOffset(self.wishlistTokenScroll) or 0
    FauxScrollFrame_Update(self.wishlistTokenScroll, #ordered, #self.wishlistTokenRows, ROW_HEIGHT)
    for i = 1, #self.wishlistTokenRows do
        local row = self.wishlistTokenRows[i]
        local index = i + offset
        local entry = ordered[index]
        if entry then
            row:Show()
            local cached = Goals.CacheItemById and Goals:CacheItemById(entry.id) or nil
            local name = cached and cached.name or ("Token " .. tostring(entry.id))
            if entry.count and entry.count > 1 then
                name = name .. " x" .. tostring(entry.count)
            end
            row.text:SetText(name)
            row.itemId = entry.id
            row.itemLink = cached and cached.link or nil
            if cached and cached.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[cached.quality] then
                local color = ITEM_QUALITY_COLORS[cached.quality]
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            if cached and cached.texture then
                row.icon:SetTexture(cached.texture)
                row.icon:Show()
            else
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end
        else
            row:Hide()
            row.itemId = nil
            row.itemLink = nil
        end
    end
end

function UI:OpenWishlistSocketPicker(mode, slotKey, socketIndex)
    if mode ~= "ENCHANT" and mode ~= "GEM" then
        mode = "AUTO"
    end
    self.wishlistSocketPickerOpen = true
    self.wishlistSocketPickerMode = mode
    if slotKey then
        self.selectedWishlistSlot = slotKey
    end
    if self.wishlistHelpOpen then
        self.wishlistHelpOpen = false
        if self.UpdateWishlistHelpVisibility then
            self:UpdateWishlistHelpVisibility()
        end
    end
    if mode == "GEM" then
        self.selectedWishlistSocketMode = "GEM"
        self.selectedWishlistSocketIndex = socketIndex or 1
    elseif mode == "ENCHANT" then
        self.selectedWishlistSocketMode = "ENCHANT"
        self.selectedWishlistSocketIndex = nil
    else
        self.selectedWishlistSocketMode = nil
        self.selectedWishlistSocketIndex = socketIndex or 1
    end
    self.selectedWishlistSocketResult = nil
    self.selectedWishlistSocketResultId = nil
    self.selectedWishlistGemResult = nil
    self.selectedWishlistGemResultId = nil
    self.selectedWishlistEnchantResult = nil
    self.selectedWishlistEnchantResultId = nil
    if self.wishlistSocketGemBlock and self.wishlistSocketGemBlock.searchBox then
        self.wishlistSocketGemBlock.searchBox:SetText("")
    end
    if self.wishlistSocketEnchantBlock and self.wishlistSocketEnchantBlock.searchBox then
        self.wishlistSocketEnchantBlock.searchBox:SetText("")
    end
    self:UpdateWishlistSocketPickerVisibility()
    self:UpdateWishlistSocketPickerResults()
    self:UpdateWishlistUI()
end

function UI:CloseWishlistSocketPicker()
    self.wishlistSocketPickerOpen = false
    self.selectedWishlistSocketMode = nil
    self.selectedWishlistSocketIndex = nil
    self.selectedWishlistSocketResult = nil
    self.selectedWishlistSocketResultId = nil
    self.selectedWishlistGemResult = nil
    self.selectedWishlistGemResultId = nil
    self.selectedWishlistEnchantResult = nil
    self.selectedWishlistEnchantResultId = nil
    self:UpdateWishlistSocketPickerVisibility()
    self:UpdateWishlistUI()
end

function UI:UpdateWishlistSocketPickerResults()
    if not self.wishlistSocketGemBlock or not self.wishlistSocketEnchantBlock then
        return
    end

    local gemAvailable, enchantAvailable = self:GetWishlistSocketAvailability()
    local slotKey = self.selectedWishlistSlot
    local slotDef = slotKey and Goals.GetWishlistSlotDef and Goals:GetWishlistSlotDef(slotKey) or nil
    local slotName = slotDef and slotDef.label or (slotKey or "")
    if self.wishlistSocketPickerSlotLabel then
        self.wishlistSocketPickerSlotLabel:SetText(slotName)
    end

    if self.wishlistSocketGemBlock then
        setShown(self.wishlistSocketGemBlock.title, gemAvailable)
        setShown(self.wishlistSocketGemBlock.searchBox, gemAvailable)
        setShown(self.wishlistSocketGemBlock.resultsInset, gemAvailable)
        setShown(self.wishlistSocketGemBlock.applyBtn, gemAvailable)
        setShown(self.wishlistSocketGemBlock.clearBtn, gemAvailable)
    end

    if self.wishlistSocketEnchantBlock then
        if gemAvailable then
            self.wishlistSocketEnchantBlock.title:ClearAllPoints()
            self.wishlistSocketEnchantBlock.title:SetPoint("TOPLEFT", self.wishlistSocketGemBlock.applyBtn, "BOTTOMLEFT", 0, -12)
        else
            self.wishlistSocketEnchantBlock.title:ClearAllPoints()
            self.wishlistSocketEnchantBlock.title:SetPoint("TOPLEFT", self.wishlistSocketPickerSlotLabel, "BOTTOMLEFT", 0, -10)
        end
        setShown(self.wishlistSocketEnchantBlock.title, enchantAvailable)
        setShown(self.wishlistSocketEnchantBlock.searchBox, enchantAvailable)
        setShown(self.wishlistSocketEnchantBlock.resultsInset, enchantAvailable)
        setShown(self.wishlistSocketEnchantBlock.applyBtn, enchantAvailable)
        setShown(self.wishlistSocketEnchantBlock.clearBtn, enchantAvailable)
    end

    local function updateBlock(block, mode, query, selectedId)
        if not block then
            return
        end
        local results = {}
        if mode == "ENCHANT" and Goals.SearchEnchantments then
            results = Goals:SearchEnchantments(query, { slotKey = slotKey })
        elseif mode == "GEM" and Goals.SearchGemItems then
            results = Goals:SearchGemItems(query)
        end
        block.results = results
        local offset = 0
        if block.resultsScroll and block.resultsScroll.GetName and block.resultsScroll:GetName() then
            offset = FauxScrollFrame_GetOffset(block.resultsScroll) or 0
            FauxScrollFrame_Update(block.resultsScroll, #results, #block.rows, ROW_HEIGHT)
        end
        for i = 1, #block.rows do
            local row = block.rows[i]
            local index = i + offset
            local entry = results[index]
            if entry then
                row:Show()
                row.entry = entry
                if mode == "ENCHANT" and Goals.CacheEnchantByEntry then
                    Goals:CacheEnchantByEntry(entry)
                end
                setShown(row.selected, selectedId == entry.id)
                local rowName = entry.name or (mode == "ENCHANT" and tostring(entry.id or 0) or ("Item " .. tostring(entry.id or 0)))
                if mode == "ENCHANT" and rowName and rowName:sub(1, 8) == "Enchant " then
                    rowName = rowName:sub(9)
                end
                if mode == "ENCHANT" and entry.slotKey and Goals.GetWishlistSlotDef then
                    local def = Goals:GetWishlistSlotDef(entry.slotKey)
                    if def and def.label then
                        local labelLower = string.lower(def.label)
                        local nameLower = rowName and string.lower(rowName) or ""
                        if not string.find(nameLower, labelLower, 1, true) then
                            rowName = rowName .. " (" .. def.label .. ")"
                        end
                    end
                end
                row.text:SetText(rowName)
                if mode == "ENCHANT" then
                    row.icon:SetTexture(entry.icon or "Interface\\Icons\\inv_enchant_formulagood_01")
                    row.text:SetTextColor(1, 1, 1)
                else
                    row.icon:SetTexture(entry.texture)
                    if entry.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[entry.quality] then
                        local color = ITEM_QUALITY_COLORS[entry.quality]
                        row.text:SetTextColor(color.r, color.g, color.b)
                    else
                        row.text:SetTextColor(1, 1, 1)
                    end
                end
            else
                row:Hide()
                row.entry = nil
            end
        end
        setShown(block.emptyLabel, #results == 0)
        if block.applyBtn then
            if selectedId then
                block.applyBtn:Enable()
            else
                block.applyBtn:Disable()
            end
        end
        if block.clearBtn then
            if slotKey then
                block.clearBtn:Enable()
            else
                block.clearBtn:Disable()
            end
        end
    end

    if gemAvailable then
        local gemQuery = self.wishlistSocketGemBlock.searchBox and self.wishlistSocketGemBlock.searchBox:GetText() or ""
        updateBlock(self.wishlistSocketGemBlock, "GEM", gemQuery, self.selectedWishlistGemResultId)
    end
    if enchantAvailable then
        local enchantQuery = self.wishlistSocketEnchantBlock.searchBox and self.wishlistSocketEnchantBlock.searchBox:GetText() or ""
        updateBlock(self.wishlistSocketEnchantBlock, "ENCHANT", enchantQuery, self.selectedWishlistEnchantResultId)
    end
end

function UI:ApplyWishlistSocketSelection(mode, result, socketIndex)
    local useMode = mode or self.selectedWishlistSocketMode
    if not self.selectedWishlistSlot or not useMode then
        return
    end
    local list = Goals:GetActiveWishlist()
    local entry = list and list.items and list.items[self.selectedWishlistSlot] or nil
    if not entry or not entry.itemId then
        return
    end
    local selectedResult = result or self.selectedWishlistSocketResult
    if not selectedResult then
        return
    end
    if useMode == "GEM" then
        local itemId = selectedResult.itemId or selectedResult.id
        if not itemId or itemId <= 0 then
            return
        end
        local gems = entry.gemIds or {}
        local index = socketIndex or self.selectedWishlistSocketIndex or (#gems + 1)
        if index < 1 then
            index = 1
        elseif index > 3 then
            index = 3
        end
        if index > #gems + 1 then
            index = #gems + 1
        end
        gems[index] = itemId
        entry.gemIds = gems
    else
        if not selectedResult.id or selectedResult.id <= 0 then
            return
        end
        entry.enchantId = selectedResult.id
    end
    Goals:SetWishlistItem(self.selectedWishlistSlot, entry)
    self:UpdateWishlistSocketPickerResults()
    self:UpdateWishlistUI()
    if self.TriggerWishlistRefresh then
        self:TriggerWishlistRefresh()
    end
end

function UI:ClearWishlistSocketSelection(mode, socketIndex)
    local useMode = mode or self.selectedWishlistSocketMode
    if not self.selectedWishlistSlot or not useMode then
        return
    end
    local list = Goals:GetActiveWishlist()
    local entry = list and list.items and list.items[self.selectedWishlistSlot] or nil
    if not entry or not entry.itemId then
        return
    end
    if useMode == "GEM" then
        local index = socketIndex or self.selectedWishlistSocketIndex or 1
        if entry.gemIds and entry.gemIds[index] then
            table.remove(entry.gemIds, index)
        end
    else
        entry.enchantId = 0
    end
    Goals:SetWishlistItem(self.selectedWishlistSlot, entry)
    self:UpdateWishlistSocketPickerResults()
    self:UpdateWishlistUI()
end

function UI:GetWishlistBuildSettings()
    if not (Goals.db and Goals.db.settings) then
        return {}
    end
    Goals.db.settings.wishlistBuildFilters = Goals.db.settings.wishlistBuildFilters or {
        class = "AUTO",
        spec = "AUTO",
        tier = "AUTO",
        tag = "ALL",
        levelMode = "AUTO",
        level = 80,
    }
    return Goals.db.settings.wishlistBuildFilters
end

function UI:ResetWishlistBuildFilters(useDetected)
    local settings = self:GetWishlistBuildSettings()
    if useDetected then
        settings.class = "AUTO"
        settings.spec = "AUTO"
        settings.tier = "AUTO"
        settings.tag = "ALL"
        settings.levelMode = "AUTO"
        local detected = Goals.GetPlayerLevel and Goals:GetPlayerLevel()
        if detected then
            settings.level = detected
        end
    else
        settings.class = "AUTO"
        settings.spec = "AUTO"
        settings.tier = "AUTO"
        settings.tag = "ALL"
        settings.levelMode = "AUTO"
        settings.level = 80
    end
    self:UpdateWishlistBuildList()
end

function UI:UpdateWishlistBuildFilterControls()
    if not (self.wishlistBuildClassDrop and self.wishlistBuildSpecDrop and self.wishlistBuildTierDrop and self.wishlistBuildTagDrop) then
        return
    end
    local settings = self:GetWishlistBuildSettings()
    local library = Goals.GetWishlistBuildLibrary and Goals:GetWishlistBuildLibrary() or {}
    local options = Goals.GetWishlistBuildFilterOptions and Goals:GetWishlistBuildFilterOptions() or {}
    local tierLabels = {}
    for _, tier in ipairs(library.tiers or {}) do
        tierLabels[tier.id] = tier.label or tier.id
    end
    local classSpecs = {}
    for _, build in ipairs(library.builds or {}) do
        if build.class and build.spec then
            classSpecs[tostring(build.class)] = classSpecs[tostring(build.class)] or {}
            classSpecs[tostring(build.class)][tostring(build.spec)] = true
        end
    end

    local function getClassHex(classId)
        if Goals and Goals.GetClassColor then
            local r, g, b = Goals:GetClassColor(classId)
            if r and g and b then
                return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            end
        end
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classId] then
            local c = RAID_CLASS_COLORS[classId]
            return string.format("|cff%02x%02x%02x", (c.r or 1) * 255, (c.g or 1) * 255, (c.b or 1) * 255)
        end
        return nil
    end

    local function addOption(list, value, text)
        table.insert(list, { value = value, text = text or value })
    end

    local classOptions = {}
    addOption(classOptions, "AUTO", "Auto")
    addOption(classOptions, "ANY", "Any")
    for _, classId in ipairs(options.classes or {}) do
        local hex = getClassHex(classId)
        if hex then
            addOption(classOptions, classId, string.format("%s%s|r", hex, classId))
        else
            addOption(classOptions, classId, classId)
        end
    end

    local specOptions = {}
    addOption(specOptions, "AUTO", "Auto")
    addOption(specOptions, "ANY", "Any")
    local selectedClass = tostring(settings.class or "AUTO")
    if selectedClass ~= "AUTO" and selectedClass ~= "ANY" and classSpecs[selectedClass] then
        local specList = {}
        for spec in pairs(classSpecs[selectedClass]) do
            table.insert(specList, spec)
        end
        table.sort(specList)
        for _, spec in ipairs(specList) do
            addOption(specOptions, spec, spec)
        end
    else
        for _, spec in ipairs(options.specs or {}) do
            addOption(specOptions, spec, spec)
        end
    end

    local tierOptions = {}
    addOption(tierOptions, "AUTO", "Auto")
    addOption(tierOptions, "ANY", "Any")
    for _, tierId in ipairs(options.tiers or {}) do
        local label = tierLabels[tierId] or tierId
        addOption(tierOptions, tierId, label)
    end

    local tagOptions = {}
    addOption(tagOptions, "ALL", "All")
    for _, tag in ipairs(options.tags or {}) do
        addOption(tagOptions, tag, tag)
    end

    local function setupDropdown(dropdown, optionList, selectedValue, onSelect)
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            for _, option in ipairs(optionList) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.text
                info.value = option.value
                info.func = function()
                    dropdown.selectedValue = option.value
                    UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                    UI:SetDropdownText(dropdown, option.text)
                    if onSelect then
                        onSelect(option.value)
                    end
                end
                info.checked = dropdown.selectedValue == option.value
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        local valid = false
        for _, option in ipairs(optionList) do
            if option.value == selectedValue then
                valid = true
                break
            end
        end
        if not valid then
            selectedValue = "AUTO"
        end
        dropdown.selectedValue = selectedValue
        UIDropDownMenu_SetSelectedValue(dropdown, selectedValue)
        local selectedLabel = nil
        for _, option in ipairs(optionList) do
            if option.value == selectedValue then
                selectedLabel = option.text
                break
            end
        end
        UI:SetDropdownText(dropdown, selectedLabel or L.SELECT_OPTION)
    end

    setupDropdown(self.wishlistBuildClassDrop, classOptions, settings.class or "AUTO", function(value)
        settings.class = value
        UI:UpdateWishlistBuildList()
    end)
    setupDropdown(self.wishlistBuildSpecDrop, specOptions, settings.spec or "AUTO", function(value)
        settings.spec = value
        UI:UpdateWishlistBuildList()
    end)
    setupDropdown(self.wishlistBuildTierDrop, tierOptions, settings.tier or "AUTO", function(value)
        settings.tier = value
        UI:UpdateWishlistBuildList()
    end)
    setupDropdown(self.wishlistBuildTagDrop, tagOptions, settings.tag or "ALL", function(value)
        settings.tag = value
        UI:UpdateWishlistBuildList()
    end)

    if self.wishlistBuildLevelAuto then
        self.wishlistBuildLevelAuto:SetChecked(settings.levelMode == "AUTO")
    end
    if self.wishlistBuildLevelBox then
        local effective = Goals.GetEffectiveWishlistBuildFilters and Goals:GetEffectiveWishlistBuildFilters(settings) or settings
        local function setLevelBoxEnabled(isEnabled)
            if isEnabled then
                if self.wishlistBuildLevelBox.Enable then
                    self.wishlistBuildLevelBox:Enable()
                elseif self.wishlistBuildLevelBox.EnableKeyboard then
                    self.wishlistBuildLevelBox:EnableKeyboard(true)
                end
            else
                if self.wishlistBuildLevelBox.Disable then
                    self.wishlistBuildLevelBox:Disable()
                elseif self.wishlistBuildLevelBox.EnableKeyboard then
                    self.wishlistBuildLevelBox:EnableKeyboard(false)
                end
            end
        end
        if settings.levelMode == "AUTO" then
            self.wishlistBuildLevelBox:SetText(effective.level or "")
            setLevelBoxEnabled(false)
        else
            setLevelBoxEnabled(true)
            if settings.level then
                self.wishlistBuildLevelBox:SetText(tostring(settings.level))
            end
        end
    end
end

function UI:UpdateWishlistBuildList()
    if not self.wishlistBuildResultsScroll or not self.wishlistBuildResultsRows then
        return
    end
    local settings = self:GetWishlistBuildSettings()
    if self.wishlistBuildLevelBox and settings.levelMode ~= "AUTO" then
        local value = tonumber(self.wishlistBuildLevelBox:GetText())
        if value then
            settings.level = value
        end
    end
    self:UpdateWishlistBuildFilterControls()
    local filters = Goals.GetEffectiveWishlistBuildFilters and Goals:GetEffectiveWishlistBuildFilters(settings) or settings
    local builds = Goals.FilterWishlistBuilds and Goals:FilterWishlistBuilds(filters) or {}
    if #builds == 0 then
        local fallback = {}
        for key, value in pairs(filters or {}) do
            fallback[key] = value
        end
        local function tryFallback()
            builds = Goals.FilterWishlistBuilds and Goals:FilterWishlistBuilds(fallback) or {}
            return #builds > 0
        end
        if settings.spec == "AUTO" then
            fallback.spec = "ANY"
        end
        if #builds == 0 and not tryFallback() and settings.tier == "AUTO" then
            fallback.tier = "ANY"
        end
        if #builds == 0 and not tryFallback() and settings.class == "AUTO" then
            fallback.class = "ANY"
        end
        if #builds == 0 and not tryFallback() and settings.levelMode == "AUTO" then
            fallback.level = nil
        end
        if #builds == 0 then
            tryFallback()
        end
    end
    self.wishlistBuildResults = builds
    local library = Goals.GetWishlistBuildLibrary and Goals:GetWishlistBuildLibrary() or {}
    local totalBuilds = library.builds and #library.builds or 0
    local hasBuildItems = false
    for _, build in ipairs(builds) do
        if (build.items and #build.items > 0)
            or (build.itemsBySlot and next(build.itemsBySlot))
            or (build.wishlist and build.wishlist ~= "")
            or (build.wowhead and build.wowhead ~= "") then
            hasBuildItems = true
            break
        end
    end
    if self.wishlistBuildEmptyLabel then
        setShown(self.wishlistBuildEmptyLabel, (#builds > 0) and (not hasBuildItems))
    end
    if self.wishlistBuildNoMatchLabel then
        setShown(self.wishlistBuildNoMatchLabel, (totalBuilds > 0) and (#builds == 0))
        if #builds == 0 and totalBuilds > 0 then
            local detail = string.format("No builds match filters. (%d builds loaded)", totalBuilds)
            self.wishlistBuildNoMatchLabel:SetText(detail)
        end
    end
    local offset = FauxScrollFrame_GetOffset(self.wishlistBuildResultsScroll) or 0
    FauxScrollFrame_Update(self.wishlistBuildResultsScroll, #builds, #self.wishlistBuildResultsRows, ROW_HEIGHT)
    for i = 1, #self.wishlistBuildResultsRows do
        local row = self.wishlistBuildResultsRows[i]
        local index = offset + i
        local build = builds[index]
        if build then
            row:Show()
            row.build = build
            local iconX = 2
            local function placeIcon(icon, tooltipText)
                icon.tooltipText = tooltipText
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", row, "LEFT", iconX, 0)
                icon:Show()
                iconX = iconX + 18
            end
            local loonTexture = Goals.IconTextures and Goals.IconTextures.loonbis or nil
            if loonTexture and wishlistHasLoon(build) then
                row.iconLoon.tex:SetTexture(loonTexture)
                row.iconLoon.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconLoon, "LoonBiS")
            else
                row.iconLoon:Hide()
            end
            local bistooltipTexture = Goals.IconTextures and Goals.IconTextures.bistooltip or nil
            if bistooltipTexture and wishlistHasBistooltip(build) then
                row.iconBistooltip.tex:SetTexture(bistooltipTexture)
                row.iconBistooltip.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconBistooltip, "BiS-Tooltip")
            else
                row.iconBistooltip:Hide()
            end
            local wowtbcKey, wowtbcTooltip = wishlistWowtbcSource(build)
            local wowtbcTexture = wowtbcKey and Goals.IconTextures and Goals.IconTextures[wowtbcKey] or nil
            if wowtbcTexture then
                row.iconWowtbc.tex:SetTexture(wowtbcTexture)
                row.iconWowtbc.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconWowtbc, wowtbcTooltip or "wowtbc.gg")
            else
                row.iconWowtbc:Hide()
            end
            local customSources = wishlistCustomSources(build)
            local customClassic = Goals.IconTextures and Goals.IconTextures["custom-classic"] or nil
            if customClassic and customSources["custom-classic"] then
                row.iconCustomClassic.tex:SetTexture(customClassic)
                row.iconCustomClassic.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconCustomClassic, "Custom Classic")
            else
                row.iconCustomClassic:Hide()
            end
            local customTbc = Goals.IconTextures and Goals.IconTextures["custom-tbc"] or nil
            if customTbc and customSources["custom-tbc"] then
                row.iconCustomTbc.tex:SetTexture(customTbc)
                row.iconCustomTbc.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconCustomTbc, "Custom TBC")
            else
                row.iconCustomTbc:Hide()
            end
            local customWotlk = Goals.IconTextures and Goals.IconTextures["custom-wotlk"] or nil
            if customWotlk and customSources["custom-wotlk"] then
                row.iconCustomWotlk.tex:SetTexture(customWotlk)
                row.iconCustomWotlk.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconCustomWotlk, "Custom WotLK")
            else
                row.iconCustomWotlk:Hide()
            end
            local wowheadTexture = Goals.IconTextures and Goals.IconTextures.wowhead or nil
            if wowheadTexture and wishlistHasWowhead(build) then
                row.iconWowhead.tex:SetTexture(wowheadTexture)
                row.iconWowhead.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconWowhead, "Wowhead")
            else
                row.iconWowhead:Hide()
            end
            if build.class then
                local classCoords = _G.CLASS_BUTTONS and _G.CLASS_BUTTONS[build.class]
                if classCoords then
                    local classSprite = Goals.IconTextures and Goals.IconTextures.classSprite or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
                    row.iconClass.tex:SetTexture(classSprite)
                    row.iconClass.tex:SetTexCoord(classCoords[1], classCoords[2], classCoords[3], classCoords[4])
                else
                    row.iconClass.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    row.iconClass.tex:SetTexCoord(0, 1, 0, 1)
                end
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[build.class]) or build.class
                placeIcon(row.iconClass, className)
            else
                row.iconClass:Hide()
            end
            local specKey = wishlistSpecKey(build)
            local specTexture = specKey and Goals.IconTextures and Goals.IconTextures.spec and Goals.IconTextures.spec[specKey] or nil
            if specTexture then
                row.iconSpec.tex:SetTexture(specTexture)
                row.iconSpec.tex:SetTexCoord(0, 1, 0, 1)
                placeIcon(row.iconSpec, build.spec or specKey)
            else
                row.iconSpec:Hide()
            end
            local function placeTextBadgeLeft(key, text, r, g, b, tooltipText)
                if not text or text == "" then
                    return
                end
                local frameKey = "badgeFrame" .. key
                if not row[frameKey] then
                    local badge = CreateFrame("Frame", nil, row)
                    badge.bg = badge:CreateTexture(nil, "BACKGROUND")
                    badge.bg:SetAllPoints(badge)
                    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
                    badge.text:SetJustifyH("CENTER")
                    badge:EnableMouse(true)
                    badge:SetScript("OnEnter", function(selfBadge)
                        if selfBadge.tooltipText then
                            GameTooltip:SetOwner(selfBadge, "ANCHOR_RIGHT")
                            GameTooltip:SetText(selfBadge.tooltipText)
                            GameTooltip:Show()
                        end
                    end)
                    badge:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    row[frameKey] = badge
                end
                local badge = row[frameKey]
                badge.text:SetText(text)
                badge.text:SetTextColor(1, 1, 1, 1)
                local w = (badge.text.GetStringWidth and badge.text:GetStringWidth() or 18) + 10
                local h = 14
                local br, bg, bb, ba = r or 0.2, g or 0.2, b or 0.2, 0.7
                if badge.bg.SetColorTexture then
                    badge.bg:SetColorTexture(br, bg, bb, ba)
                else
                    badge.bg:SetTexture(br, bg, bb, ba)
                end
                badge:SetSize(w, h)
                badge:ClearAllPoints()
                badge:SetPoint("LEFT", row, "LEFT", iconX, 0)
                badge.tooltipText = tooltipText
                badge:Show()
                iconX = iconX + w + 4
            end
            local expansionBadge = getExpansionBadge(build.tier)
            if expansionBadge then
                if expansionBadge == "WLK" then
                    placeTextBadgeLeft("Expansion", expansionBadge, 0.2, 0.45, 0.8, getExpansionTooltip(build.tier))
                elseif expansionBadge == "TBC" then
                    placeTextBadgeLeft("Expansion", expansionBadge, 0.25, 0.6, 0.35, getExpansionTooltip(build.tier))
                elseif expansionBadge == "CLS" then
                    placeTextBadgeLeft("Expansion", expansionBadge, 0.7, 0.5, 0.2, getExpansionTooltip(build.tier))
                else
                    placeTextBadgeLeft("Expansion", expansionBadge, 0.3, 0.3, 0.3, getExpansionTooltip(build.tier))
                end
            elseif row.badgeExpansion then
                row.badgeExpansion:Hide()
            end
            local tierBadge = getTierBadge(build.tier)
            if tierBadge then
                local tr, tg, tb = getTierBadgeColor(build.tier)
                placeTextBadgeLeft("Tier", tierBadge, tr, tg, tb, getTierTooltip(build.tier))
            elseif row.badgeTier then
                row.badgeTier:Hide()
            end
            if not expansionBadge and row.badgeFrameExpansion then
                row.badgeFrameExpansion:Hide()
            end
            if not tierBadge and row.badgeFrameTier then
                row.badgeFrameTier:Hide()
            end
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row, "LEFT", iconX + 2, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.text:SetText(build.name or "Build")
            if self.selectedWishlistBuild == build then
                row.selected:Show()
            else
                row.selected:Hide()
            end
        else
            row:Hide()
            row.build = nil
            if row.iconLoon then row.iconLoon:Hide() end
            if row.iconBistooltip then row.iconBistooltip:Hide() end
            if row.iconWowtbc then row.iconWowtbc:Hide() end
            if row.iconCustomClassic then row.iconCustomClassic:Hide() end
            if row.iconCustomTbc then row.iconCustomTbc:Hide() end
            if row.iconCustomWotlk then row.iconCustomWotlk:Hide() end
            if row.iconWowhead then row.iconWowhead:Hide() end
            if row.iconClass then row.iconClass:Hide() end
            if row.iconSpec then row.iconSpec:Hide() end
            if row.badgeExpansion then row.badgeExpansion:Hide() end
            if row.badgeTier then row.badgeTier:Hide() end
        end
    end
end

function UI:RefreshBuildPreviewItems()
    local entries = self.previewBuildEntries or {}
    if Goals and Goals.CacheItemById then
        for _, entry in ipairs(entries) do
            if entry and entry.itemId then
                Goals:CacheItemById(entry.itemId)
            end
        end
    end
    if self.UpdateBuildPreviewTooltip then
        self:UpdateBuildPreviewTooltip()
    end
end

function UI:UpdateBuildPreviewTooltip()
    local frame = ensureBuildPreviewTooltip()
    if not frame or not frame.rows then
        return
    end
    local entries = self.previewBuildEntries or {}
    if frame.TitleText then
        frame.TitleText:SetText("Build Preview")
    end
    if frame.buildNameText then
        frame.buildNameText:Hide()
    end
    if frame.buildMetaText then
        frame.buildMetaText:Hide()
    end
    if frame.buildTierText then
        frame.buildTierText:Hide()
    end
    local content = frame.content
    local rowCount = #entries
    local headerHeight = 24
    local padBottom = 14
    local notesGap = 6
    local sourcesGap = 6
    local sourcesIconHeight = 16
    local sourcesIconCount = 0
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UI.frame, "TOPRIGHT", 10, -30)

    frame.itemRows = frame.itemRows or {}
    frame.noteRows = frame.noteRows or {}
    frame.textRows = frame.textRows or {}

    local function ensureRow(idx)
        if frame.itemRows[idx] then
            return frame.itemRows[idx]
        end
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(frame.rowHeight)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -24 - (idx - 1) * frame.rowHeight)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = icon
        local label = createLabel(row, "", "GameFontNormalSmall")
        styleOptionsControlLabel(label)
        label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        label:SetWidth(70)
        label:SetJustifyH("LEFT")
        row.label = label
        local value = createLabel(row, "", "GameFontHighlightSmall")
        value:SetPoint("LEFT", label, "RIGHT", 6, 0)
        value:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        value:SetJustifyH("LEFT")
        value:SetWordWrap(true)
        row.value = value
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.itemId then
                GameTooltip:ClearAllPoints()
                GameTooltip:SetOwner(frame, "ANCHOR_NONE")
                GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -8)
                GameTooltip:SetFrameStrata("FULLSCREEN_DIALOG")
                if GameTooltip.SetFrameLevel and frame.GetFrameLevel then
                    GameTooltip:SetFrameLevel(frame:GetFrameLevel() + 20)
                end
                GameTooltip:SetHyperlink("item:" .. tostring(selfRow.itemId))
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.itemRows[idx] = row
        return row
    end

    local function ensureNoteRow(idx)
        if frame.noteRows[idx] then
            return frame.noteRows[idx]
        end
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(frame.rowHeight)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -24 - (idx - 1) * frame.rowHeight)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        local note = createLabel(row, "", "GameFontHighlightSmall")
        note:SetJustifyH("CENTER")
        note:SetWordWrap(true)
        if note.SetNonSpaceWrap then
            note:SetNonSpaceWrap(true)
        end
        if note.SetMaxLines then
            note:SetMaxLines(0)
        end
        note:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -2)
        note:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -2)
        note:SetTextColor(0.8, 0.8, 0.8)
        row.note = note
        frame.noteRows[idx] = row
        return row
    end

    local function ensureTextRow(idx, fontObject)
        if frame.textRows[idx] then
            return frame.textRows[idx]
        end
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(frame.rowHeight)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -24 - (idx - 1) * frame.rowHeight)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        local text = createLabel(row, "", fontObject or "GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        if text.SetNonSpaceWrap then
            text:SetNonSpaceWrap(true)
        end
        if text.SetMaxLines then
            text:SetMaxLines(0)
        end
        text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        row.text = text
        frame.textRows[idx] = row
        return row
    end

    local needsRefresh = false
    local build = self.selectedWishlistBuild

    if frame.buildTierTooltipFrame then
        frame.buildTierTooltipFrame:Hide()
    end

    if frame.expansionBadge then frame.expansionBadge:Hide() end
    if frame.tierBadge then frame.tierBadge:Hide() end

    local listStartY = -6
    local yOffset = listStartY
    local rowIndex = 1
    local noteRowIndex = 1
    local textRowIndex = 1

    local function addTextRow(text, font)
        if not text or text == "" then
            return
        end
        local row = ensureTextRow(textRowIndex, font)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yOffset)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        row.text:SetText(text)
        local h = (row.text.GetStringHeight and row.text:GetStringHeight() or frame.rowHeight)
        if h < 16 then
            h = 16
        end
        row:SetHeight(h)
        yOffset = yOffset - h
        textRowIndex = textRowIndex + 1
    end
    local function addHeaderRow(text)
        if not text or text == "" then
            return
        end
        local row = ensureTextRow(textRowIndex, "GameFontNormalSmall")
        if not row.headerFrame then
            local label, heading = createOptionsHeader(row, text, 0)
            row.headerLabel = label
            row.headerFrame = heading
        end
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        if row.headerLabel then
            row.headerLabel:SetText(text)
        end
        if row.headerFrame then
            row.headerFrame:ClearAllPoints()
            row.headerFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.headerFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            row.headerFrame:Show()
        end
        local h = OPTIONS_HEADER_HEIGHT or 18
        row:SetHeight(h)
        yOffset = yOffset - h
        textRowIndex = textRowIndex + 1
    end

    local buildName = stripTextureTags((build and build.name) or "Build")
    addTextRow(buildName, "GameFontHighlight")
    local metaText = ""
    if build and build.class and build.spec then
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[build.class]) or build.class
        metaText = string.format("%s, %s", tostring(build.spec), tostring(className))
    elseif build and build.spec then
        metaText = tostring(build.spec)
    elseif build and build.class then
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[build.class]) or build.class
        metaText = tostring(className)
    end
    addTextRow(metaText, "GameFontHighlightSmall")
    local expansion = build and getExpansionBadge(build.tier) or nil
    local tierBadge = build and getTierBadge(build.tier) or nil
    local expansionText = ""
    if expansion == "WLK" then
        expansionText = "WotLK"
    elseif expansion == "TBC" then
        expansionText = "TBC"
    elseif expansion == "CLS" then
        expansionText = "Classic"
    end
    local tierText = tierBadge or ""
    local combined = expansionText
    if tierText ~= "" then
        combined = (combined ~= "" and (combined .. " " .. tierText)) or tierText
    end
    addTextRow(combined, "GameFontHighlightSmall")
    addHeaderRow("Items")
    for i = 1, rowCount do
        local entry = entries[i]

        local row = ensureRow(rowIndex)
        row:Show()
        row.itemId = entry.itemId
        row:SetHeight(frame.rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yOffset)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)

        local cached = Goals.CacheItemById and Goals:CacheItemById(entry.itemId) or nil
        local label = cached and cached.name or ("Item " .. tostring(entry.itemId))
        local slotLabel = entry.slotKey or ""
        row.label:SetText(slotLabel .. ":")
        row.value:SetText(label)
        if not (cached and cached.name and cached.name ~= "") then
            needsRefresh = true
        end
        if cached and cached.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[cached.quality] then
            local color = ITEM_QUALITY_COLORS[cached.quality]
            row.value:SetTextColor(color.r, color.g, color.b)
        else
            row.value:SetTextColor(1, 1, 1)
        end
        local texture = cached and cached.texture or (GetItemIcon and GetItemIcon(entry.itemId) or nil)
        if texture then
            row.icon:SetTexture(texture)
            row.icon:Show()
        else
            row.icon:SetTexture(nil)
            row.icon:Hide()
        end

        local rawNoteText = stripTextureTags(entry.notes or "")
        local noteIds = extractNoteItemIds(rawNoteText)
        local noteText = resolveNoteItemIds(rawNoteText)

        yOffset = yOffset - frame.rowHeight
        rowIndex = rowIndex + 1

        if noteText ~= "" then
            local noteRow = ensureNoteRow(noteRowIndex)
            noteRow:Show()
            noteRow:ClearAllPoints()
            noteRow:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yOffset)
            noteRow:SetPoint("RIGHT", content, "RIGHT", -6, 0)
            local rowWidth = noteRow.GetWidth and noteRow:GetWidth() or nil
            if rowWidth and noteRow.note.SetWidth then
                noteRow.note:SetWidth(math.max(40, rowWidth - 24))
            end
            noteRow.note:SetText(noteText)
            noteRow.note:Show()
            local noteHeight = (noteRow.note.GetStringHeight and noteRow.note:GetStringHeight() or 0)
            if noteHeight < 12 then
                noteHeight = 12
            end
            noteRow:SetHeight(noteHeight + 6)

            if not noteRow.noteTip then
                local tip = CreateFrame("Frame", nil, noteRow)
                tip:EnableMouse(true)
                tip:SetScript("OnEnter", function(selfTip)
                    if not selfTip.itemId then
                        return
                    end
                    GameTooltip:ClearAllPoints()
                    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
                    GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -8)
                    GameTooltip:SetFrameStrata("FULLSCREEN_DIALOG")
                    if GameTooltip.SetFrameLevel and frame.GetFrameLevel then
                        GameTooltip:SetFrameLevel(frame:GetFrameLevel() + 20)
                    end
                    GameTooltip:SetHyperlink("item:" .. tostring(selfTip.itemId))
                    GameTooltip:Show()
                end)
                tip:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                noteRow.noteTip = tip
            end
            if #noteIds > 0 then
                noteRow.noteTip.itemId = noteIds[1]
                noteRow.noteTip:ClearAllPoints()
                noteRow.noteTip:SetPoint("TOPLEFT", noteRow.note, "TOPLEFT", 0, 0)
                noteRow.noteTip:SetPoint("BOTTOMRIGHT", noteRow.note, "BOTTOMRIGHT", 0, 0)
                noteRow.noteTip:Show()
            elseif noteRow.noteTip then
                noteRow.noteTip.itemId = nil
                noteRow.noteTip:Hide()
            end

            yOffset = yOffset - noteRow:GetHeight()
            noteRowIndex = noteRowIndex + 1
        end
    end
    for i = rowIndex, #frame.itemRows do
        local row = frame.itemRows[i]
        row:Hide()
        row.itemId = nil
        if row.label then row.label:SetText("") end
        if row.value then
            row.value:SetText("")
            row.value:SetTextColor(1, 1, 1)
        end
        if row.icon then
            row.icon:SetTexture(nil)
            row.icon:Hide()
        end
    end
    for i = noteRowIndex, #frame.noteRows do
        local row = frame.noteRows[i]
        row:Hide()
        if row.note then
            row.note:SetText("")
            row.note:Hide()
        end
        if row.noteTip then
            row.noteTip.itemId = nil
            row.noteTip:Hide()
        end
    end
    for i = textRowIndex, #frame.textRows do
        local row = frame.textRows[i]
        row:Hide()
        if row.text then
            row.text:SetText("")
        end
        if row.bar then row.bar:Hide() end
        if row.headerFrame then row.headerFrame:Hide() end
        if row.lineLeft then row.lineLeft:Hide() end
        if row.lineRight then row.lineRight:Hide() end
    end

    if needsRefresh then
        frame.previewRefreshAttempts = (frame.previewRefreshAttempts or 0) + 1
        if frame.previewRefreshAttempts <= 6 and not frame.pendingPreviewRefresh then
            frame.pendingPreviewRefresh = true
            if Goals and Goals.Delay then
                Goals:Delay(0.4, function()
                    frame.pendingPreviewRefresh = nil
                    if frame:IsShown() and UI and UI.RefreshBuildPreviewItems then
                        UI:RefreshBuildPreviewItems()
                    end
                end)
            else
                frame.pendingPreviewRefresh = nil
            end
        end
    else
        frame.previewRefreshAttempts = nil
        frame.pendingPreviewRefresh = nil
    end

    local notesText = frame.notesText
    local notesHeader = frame.notesHeader
    local notesHeaderFrame = frame.notesHeaderFrame
    local sourcesLabel = frame.sourcesLabel
    local sourcesHeaderFrame = frame.sourcesHeaderFrame
    local sourcesFrame = frame.sourcesFrame
    if notesHeaderFrame then
        notesHeaderFrame:Hide()
    end
    if notesText then
        notesText:Hide()
    end
    local notesBody = stripTextureTags(build and build.notes or "")
    if notesBody ~= "" then
        addHeaderRow("Notes")
        local row = ensureTextRow(textRowIndex, "GameFontHighlightSmall")
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yOffset)
        row:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        if row.text.SetNonSpaceWrap then
            row.text:SetNonSpaceWrap(true)
        end
        if row.text.SetMaxLines then
            row.text:SetMaxLines(0)
        end
        local contentWidth = content and content.GetWidth and content:GetWidth() or nil
        if contentWidth and row.text.SetWidth then
            row.text:SetWidth(contentWidth - 12)
        end
        row.text:SetText(notesBody)
        local h = (row.text.GetStringHeight and row.text:GetStringHeight() or frame.rowHeight)
        if h < 16 then
            h = 16
        end
        row:SetHeight(h)
        yOffset = yOffset - h
        textRowIndex = textRowIndex + 1
    end

    local sourcesRow = nil
    if (sourcesLabel or sourcesHeaderFrame) and sourcesFrame then
        if sourcesHeaderFrame then sourcesHeaderFrame:Hide() end
        if sourcesLabel then sourcesLabel:Hide() end
        addHeaderRow("Sources")
        sourcesRow = ensureNoteRow(noteRowIndex)
        sourcesRow:Show()
        sourcesRow:ClearAllPoints()
        sourcesRow:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yOffset)
        sourcesRow:SetPoint("RIGHT", content, "RIGHT", -6, 0)
        if sourcesRow.note then
            sourcesRow.note:SetText("")
            sourcesRow.note:Hide()
        end
        if sourcesRow.noteTip then
            sourcesRow.noteTip.itemId = nil
            sourcesRow.noteTip:Hide()
        end
        sourcesFrame:ClearAllPoints()
        sourcesFrame:SetPoint("LEFT", sourcesRow, "LEFT", 0, 0)
        sourcesFrame:SetPoint("TOP", sourcesRow, "TOP", 0, -2)
        sourcesFrame:Show()
        noteRowIndex = noteRowIndex + 1

        local iconEntries = {}
        if build then
            local wowtbcKey, wowtbcTooltip = wishlistWowtbcSource(build)
            if wowtbcKey then
                iconEntries[#iconEntries + 1] = { key = wowtbcKey, tooltip = wowtbcTooltip or "wowtbc.gg" }
            end
            if wishlistHasWowhead(build) then
                iconEntries[#iconEntries + 1] = { key = "wowhead", tooltip = "Wowhead" }
            end
            if wishlistHasLoon(build) then
                iconEntries[#iconEntries + 1] = { key = "loonbis", tooltip = "LoonBiS" }
            end
            if wishlistHasBistooltip(build) then
                iconEntries[#iconEntries + 1] = { key = "bistooltip", tooltip = "BiS-Tooltip" }
            end
            local customSources = wishlistCustomSources(build)
            if customSources["custom-classic"] then
                iconEntries[#iconEntries + 1] = { key = "custom-classic", tooltip = "Custom Classic" }
            end
            if customSources["custom-tbc"] then
                iconEntries[#iconEntries + 1] = { key = "custom-tbc", tooltip = "Custom TBC" }
            end
            if customSources["custom-wotlk"] then
                iconEntries[#iconEntries + 1] = { key = "custom-wotlk", tooltip = "Custom WotLK" }
            end
        end
        if #iconEntries == 0 then
            iconEntries[#iconEntries + 1] = { key = "unknown-source", tooltip = "Unknown source" }
        end

        local iconX = 0
        for i = 1, math.max(#iconEntries, #frame.sourceIcons) do
            local icon = frame.sourceIcons[i]
            if not icon then
                icon = CreateFrame("Frame", nil, sourcesFrame)
                icon:SetSize(16, 16)
                icon.tex = icon:CreateTexture(nil, "ARTWORK")
                icon.tex:SetAllPoints(icon)
                icon:SetScript("OnEnter", function(selfFrame)
                    if selfFrame.tooltipText then
                        GameTooltip:ClearAllPoints()
                        GameTooltip:SetOwner(frame, "ANCHOR_NONE")
                        GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -8)
                        GameTooltip:SetFrameStrata("FULLSCREEN_DIALOG")
                        if GameTooltip.SetFrameLevel and frame.GetFrameLevel then
                            GameTooltip:SetFrameLevel(frame:GetFrameLevel() + 20)
                        end
                        GameTooltip:SetText(selfFrame.tooltipText)
                        GameTooltip:Show()
                    end
                end)
                icon:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                frame.sourceIcons[i] = icon
            end
            local entry = iconEntries[i]
            if entry and entry.key == "unknown-source" then
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", sourcesFrame, "LEFT", iconX, 0)
                icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                icon.tex:SetTexCoord(0, 1, 0, 1)
                icon.tooltipText = entry.tooltip
                icon:Show()
                iconX = iconX + 18
                sourcesIconCount = sourcesIconCount + 1
            elseif entry and Goals.IconTextures and Goals.IconTextures[entry.key] then
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", sourcesFrame, "LEFT", iconX, 0)
                icon.tex:SetTexture(Goals.IconTextures[entry.key])
                icon.tex:SetTexCoord(0, 1, 0, 1)
                icon.tooltipText = entry.tooltip
                icon:Show()
                iconX = iconX + 18
                sourcesIconCount = sourcesIconCount + 1
            elseif entry then
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", sourcesFrame, "LEFT", iconX, 0)
                icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                icon.tex:SetTexCoord(0, 1, 0, 1)
                icon.tooltipText = entry.tooltip or "Unknown source"
                icon:Show()
                iconX = iconX + 18
                sourcesIconCount = sourcesIconCount + 1
            else
                icon:Hide()
                icon.tooltipText = nil
            end
        end
        if sourcesIconCount > 0 then
            sourcesFrame:SetHeight(sourcesIconHeight)
            if sourcesFrame.SetWidth then
                sourcesFrame:SetWidth(math.max(16, (sourcesIconCount * 18)))
            end
            sourcesFrame:Show()
            if sourcesRow then
                sourcesRow:SetHeight(sourcesIconHeight + 6)
            end
        else
            sourcesFrame:Hide()
        end
    end
    if sourcesRow then
        yOffset = yOffset - sourcesRow:GetHeight()
    end

    local sourcesHeight = sourcesIconCount > 0 and sourcesIconHeight or 0
    local rowsHeight = listStartY - yOffset
    if rowsHeight < 0 then
        rowsHeight = 0
    end
    local sourcesPad = sourcesHeight > 0 and 18 or 0
    local neededHeight = headerHeight + rowsHeight + padBottom + sourcesPad - 10
    frame:SetHeight(neededHeight)
    frame:Show()
end

function UI:UpdateWishlistUI()
    if not self.wishlistSlotButtons then
        return
    end
    if self.activeTab and self.activeTab ~= "wishlist" then
        hideBuildPreviewTooltip()
        return
    end
    local list = Goals:GetActiveWishlist()
    local foundMap = nil
    if list and list.id and Goals.GetWishlistFoundMap then
        foundMap = Goals:GetWishlistFoundMap(list.id)
    end
    if Goals and Goals.IsWishlistItemOwned and Goals.GetWishlistFoundMap and Goals.EnsureWishlistData then
        local data = Goals:EnsureWishlistData()
        local lists = data and data.lists or {}
        for _, wish in pairs(lists) do
            if wish and wish.id and wish.items then
                local map = Goals:GetWishlistFoundMap(wish.id)
                if map then
                    for _, entry in pairs(wish.items) do
                        if entry and entry.itemId then
                            if entry.manualFound == true then
                                map[entry.itemId] = true
                            else
                                local owned = Goals:IsWishlistItemOwned(entry.itemId)
                                map[entry.itemId] = owned and true or nil
                            end
                        end
                        if entry and entry.tokenId and entry.tokenId > 0 then
                            if entry.manualFound == true then
                                map[entry.tokenId] = true
                            else
                                local owned = Goals:IsWishlistItemOwned(entry.tokenId)
                                map[entry.tokenId] = owned and true or nil
                            end
                        end
                    end
                end
            end
        end
    end
    if not self.selectedWishlistSlot then
        for slotKey in pairs(self.wishlistSlotButtons) do
            self.selectedWishlistSlot = slotKey
            break
        end
    end
    Goals:BuildWishlistItemCache()
    local configuredCount = 0
    local foundCount = 0
    local emptySocketCount = 0
    local missingEnchantCount = 0
    for slotKey, button in pairs(self.wishlistSlotButtons) do
        local slotDef = Goals:GetWishlistSlotDef(slotKey)
        local entry = list and list.items and list.items[slotKey] or nil
        local cached = entry and entry.itemId and Goals:CacheItemById(entry.itemId) or nil
        if entry and entry.itemId then
            configuredCount = configuredCount + 1
        end
        local iconTexture = nil
        if slotDef and slotDef.inv then
            local _, texture = GetInventorySlotInfo(slotDef.inv)
            iconTexture = texture
        end
        if cached and cached.texture then
            button.icon:SetTexture(cached.texture)
            button.icon:SetVertexColor(1, 1, 1)
            local labelText = cached.name or slotDef.label or slotKey
            fitWishlistLabel(button.label, labelText, button.column == 3 and 3 or 2)
            if cached.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[cached.quality] then
                local color = ITEM_QUALITY_COLORS[cached.quality]
            button.label:SetTextColor(color.r, color.g, color.b)
            button.border:Show()
            button.border:SetVertexColor(color.r, color.g, color.b)
            else
            button.label:SetTextColor(1, 1, 1)
            button.border:Hide()
            end
            button.itemId = cached.id
            button.itemLink = cached.link
            button.previewLink = nil
        else
            if iconTexture then
                button.icon:SetTexture(iconTexture)
            button.icon:SetVertexColor(0.7, 0.7, 0.7)
            else
                button.icon:SetTexture(nil)
            end
            if entry and entry.itemId and entry.itemId > 0 then
                fitWishlistLabel(button.label, "Item " .. tostring(entry.itemId), button.column == 3 and 3 or 2)
            else
                if slotDef and slotDef.key == "RELIC" then
                    fitWishlistLabel(button.label, "Relic / Ranged", button.column == 3 and 3 or 2)
                else
                    fitWishlistLabel(button.label, (slotDef and slotDef.label) or slotKey, button.column == 3 and 3 or 2)
                end
            end
            button.label:SetTextColor(0.9, 0.9, 0.9)
            button.border:Hide()
            button.itemId = entry and entry.itemId or nil
            button.itemLink = nil
            button.previewLink = nil
        end
        if entry and entry.itemId then
            local hasEnchant = entry.enchantId and entry.enchantId > 0
            local hasGems = false
            if entry.gemIds then
                for _, gemId in pairs(entry.gemIds) do
                    if tonumber(gemId) and tonumber(gemId) > 0 then
                        hasGems = true
                        break
                    end
                end
            end
            if hasEnchant or hasGems then
                if Goals.BuildItemLinkWithSockets then
                    button.previewLink = Goals:BuildItemLinkWithSockets(entry.itemId, button.itemLink, entry.enchantId, entry.gemIds)
                end
            end
        end
        if button.foundIcon then
            local found = false
            if entry and foundMap then
                if entry.itemId and foundMap[entry.itemId] then
                    found = true
                elseif entry.tokenId and foundMap[entry.tokenId] then
                    found = true
                end
            end
            if found then
                foundCount = foundCount + 1
                button.foundIcon:Show()
                if button.foundShadow then
                    button.foundShadow:Show()
                end
            else
                button.foundIcon:Hide()
                if button.foundShadow then
                    button.foundShadow:Hide()
                end
            end
        end
        button.entry = entry
        local socketTypes = entry and entry.itemId and Goals.GetItemSocketTypes and Goals:GetItemSocketTypes(entry.itemId) or nil
        local socketCount = socketTypes and #socketTypes or 0
        local maxSockets = button.gems and #button.gems or 0
        if socketCount > maxSockets then
            socketCount = maxSockets
        end
        if button.label then
            local nameOffset = self.wishlistNameOffset or 2
            if (button.column == 1 or button.column == 2) and socketCount == 0 then
                button.label:ClearAllPoints()
                if button.column == 1 then
                    button.label:SetPoint("LEFT", button, "RIGHT", nameOffset, 0)
                else
                    button.label:SetPoint("RIGHT", button, "LEFT", -nameOffset, 0)
                end
                if button.label.SetJustifyV then
                    button.label:SetJustifyV("MIDDLE")
                end
            elseif button.column == 1 then
                button.label:ClearAllPoints()
                button.label:SetPoint("TOPLEFT", button, "TOPRIGHT", nameOffset, -2)
                if button.label.SetJustifyV then
                    button.label:SetJustifyV("TOP")
                end
            elseif button.column == 2 then
                button.label:ClearAllPoints()
                button.label:SetPoint("TOPRIGHT", button, "TOPLEFT", -nameOffset, -2)
                if button.label.SetJustifyV then
                    button.label:SetJustifyV("TOP")
                end
            end
        end
        local gemOffset = (socketCount - 1) * 0.5
        for i = 1, maxSockets do
            local gem = button.gems[i]
            if i <= socketCount then
                local gemId = entry and entry.gemIds and entry.gemIds[i] or nil
                local gemTexture = nil
                local socketType = socketTypes and socketTypes[i] or nil
                local function getSocketFrameTexture(socketKind)
                    local socketFrame = Goals.SocketTextureMap and socketKind and Goals.SocketTextureMap[socketKind] or nil
                    if socketFrame then
                        return socketFrame
                    end
                    local key = socketKind and string.lower(socketKind) or ""
                    if string.find(key, "meta", 1, true) then
                        return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta"
                    end
                    if string.find(key, "blue", 1, true) then
                        return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue"
                    end
                    if string.find(key, "red", 1, true) then
                        return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red"
                    end
                    if string.find(key, "yellow", 1, true) then
                        return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow"
                    end
                    if string.find(key, "prismatic", 1, true) then
                        return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"
                    end
                    return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"
                end
                local socketFrame = getSocketFrameTexture(socketType)
                if gem.frame then
                    gem.frame:SetTexture(socketFrame)
                    gem.frame:SetDrawLayer("ARTWORK", 0)
                end
                if gemId then
                    local gemCache = Goals:CacheItemById(gemId)
                    gemTexture = gemCache and gemCache.texture or nil
                    if not gemTexture and GetItemIcon then
                        gemTexture = GetItemIcon(gemId)
                    end
                end
                if gemTexture then
                    gem.icon:SetTexture(gemTexture)
                    gem.icon:SetVertexColor(1, 1, 1, 1)
                    gem.icon:SetDrawLayer("ARTWORK", 1)
                    if gem.frame then
                        gem.frame:Hide()
                    end
                    gem.itemId = gemId
                    gem.socketType = socketType
                    if gem.plus then
                        gem.plus:Hide()
                    end
                else
                    gem.icon:SetTexture(nil)
                    gem.icon:SetVertexColor(1, 1, 1, 0)
                    if gem.frame then
                        gem.frame:SetVertexColor(1, 1, 1, 0.7)
                        gem.frame:Show()
                    end
                    gem.itemId = nil
                    gem.socketType = socketType or "Socket"
                    emptySocketCount = emptySocketCount + 1
                    if gem.plus then
                        gem.plus:Show()
                    end
                end
                gem:Show()
                gem:ClearAllPoints()
                local yOffset = (gemOffset - (i - 1)) * 14
                    if button.column == 1 or button.column == 2 then
                        local positionIndex = i
                        if button.column == 2 then
                            positionIndex = socketCount - i + 1
                        end
                        local xOffset = (positionIndex - 1) * 13
                        local yOffsetRow = 4
                        local nameOffset = self.wishlistNameOffset or 2
                        if button.column == 1 then
                            gem:SetPoint("LEFT", button, "BOTTOMRIGHT", nameOffset + xOffset, yOffsetRow)
                        else
                        gem:SetPoint("RIGHT", button, "BOTTOMLEFT", -nameOffset - xOffset, yOffsetRow)
                    end
                else
                    gem:SetPoint("CENTER", button, "RIGHT", 8, yOffset)
                end
                if gem.selected then
                    if self.selectedWishlistSlot == slotKey and self.selectedWishlistSocketMode == "GEM" and self.selectedWishlistSocketIndex == i then
                        gem.selected:Show()
                    else
                        gem.selected:Hide()
                    end
                end
            else
                gem:Hide()
                gem.itemId = nil
                gem.socketType = nil
                if gem.plus then
                    gem.plus:Hide()
                end
                if gem.selected then
                    gem.selected:Hide()
                end
            end
        end
        local enchantable = entry and entry.itemId and Goals.IsWishlistSlotEnchantable and Goals:IsWishlistSlotEnchantable(slotKey)
        if enchantable then
            local hasEnchant = entry and entry.enchantId and entry.enchantId > 0
            button.enchantIcon:Show()
            local enchantId = hasEnchant and (tonumber(entry.enchantId) or entry.enchantId) or nil
            button.enchantIcon.enchantId = enchantId
            button.enchantIcon.enchantAvailable = not hasEnchant
            if not hasEnchant then
                missingEnchantCount = missingEnchantCount + 1
            end
            if button.enchantIcon.plus then
                if hasEnchant then
                    button.enchantIcon.plus:Hide()
                else
                    button.enchantIcon.plus:Show()
                end
            end
            if hasEnchant and Goals.GetEnchantInfoById then
                local info = Goals:GetEnchantInfoById(entry.enchantId)
                if info and info.matchedSpellId and info.id and info.id ~= entry.enchantId then
                    entry.enchantId = info.id
                    Goals:SetWishlistItem(slotKey, entry)
                end
                if info and info.icon then
                    button.enchantIcon.icon:SetTexture(info.icon)
                else
                    button.enchantIcon.icon:SetTexture("Interface\\Icons\\inv_enchant_formulagood_01")
                end
            else
                button.enchantIcon.icon:SetTexture("Interface\\Icons\\inv_enchant_formulagood_01")
            end
            button.enchantIcon.icon:SetVertexColor(1, 1, 1, hasEnchant and 1 or 0.4)
            button.enchantIcon:ClearAllPoints()
            if button.column == 2 then
                button.enchantIcon:SetPoint("CENTER", button, "RIGHT", 12, 0)
            elseif button.column == 1 then
                button.enchantIcon:SetPoint("CENTER", button, "LEFT", -12, 0)
            else
                button.enchantIcon:SetPoint("CENTER", button, "LEFT", -12, 0)
            end
            if button.enchantIcon.selected then
                if self.selectedWishlistSlot == slotKey and self.selectedWishlistSocketMode == "ENCHANT" then
                    button.enchantIcon.selected:Show()
                else
                    button.enchantIcon.selected:Hide()
                end
            end
        else
            button.enchantIcon:Hide()
            button.enchantIcon.enchantId = nil
            button.enchantIcon.enchantAvailable = nil
            if button.enchantIcon.plus then
                button.enchantIcon.plus:Hide()
            end
            if button.enchantIcon.selected then
                button.enchantIcon.selected:Hide()
            end
        end
        if self.selectedWishlistSlot == slotKey then
            button.selected:Show()
        else
            button.selected:Hide()
        end
    end
    if self.wishlistCompletionSummary then
        local parts = { string.format("%d/%d found", foundCount, configuredCount) }
        if emptySocketCount > 0 then
            table.insert(parts, tostring(emptySocketCount) .. " empty sockets")
        end
        if missingEnchantCount > 0 then
            table.insert(parts, tostring(missingEnchantCount) .. " missing enchants")
        end
        self.wishlistCompletionText = table.concat(parts, " | ")
        self.wishlistCompletionSummary:SetText(self.wishlistCompletionText)
        local wishlistFooter = self.tabFooters2 and self.tabFooters2.wishlist
        if wishlistFooter and wishlistFooter.centerText then
            wishlistFooter.centerText:SetText(self.wishlistCompletionText)
        end
    end
    if self.wishlistUndoButton then
        local undo = Goals.wishlistUndo
        if undo and undo.entry then
            local itemName = undo.entry.itemName or undo.entry.name
            if (not itemName or itemName == "") and undo.entry.itemId and GetItemInfo then
                itemName = GetItemInfo(undo.entry.itemId)
            end
            self.wishlistUndoButton:SetText(itemName and ("Undo: " .. itemName) or "Undo removed item")
        else
            self.wishlistUndoButton:SetText("Undo removed item")
        end
        setShown(self.wishlistUndoButton, undo and (time() - (undo.ts or 0)) <= 60)
    end
    if self.wishlistNotesBox and self.wishlistSourceEntryBox then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        self.wishlistNotesBox:SetText(selected and selected.notes or "")
        self.wishlistSourceEntryBox:SetText(selected and selected.source or "")
    end
    if self.wishlistEnchantBox then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        self.wishlistEnchantBox:SetText(selected and selected.enchantId or "")
    end
    if self.wishlistGemBoxes then
        local selected = self.selectedWishlistSlot and list and list.items and list.items[self.selectedWishlistSlot] or nil
        local gems = selected and selected.gemIds or {}
        for i = 1, 3 do
            local value = gems[i]
            if self.wishlistGemBoxes[i] then
                self.wishlistGemBoxes[i]:SetText(value or "")
            end
        end
    end
    local slotKey = self.selectedWishlistSlot
    local previewItemId = nil
    if self.selectedWishlistResult then
        previewItemId = self.selectedWishlistResult.id or self.selectedWishlistResult.itemId
    end
    if not previewItemId then
        local selected = slotKey and list and list.items and list.items[slotKey] or nil
        previewItemId = selected and selected.itemId or nil
    end
    local socketCount = 0
    if previewItemId and Goals.GetItemSocketTypes then
        local socketTypes = Goals:GetItemSocketTypes(previewItemId)
        socketCount = socketTypes and #socketTypes or 0
    end
    local enchantable = slotKey and Goals.IsWishlistSlotEnchantable and Goals:IsWishlistSlotEnchantable(slotKey) or false
    if self.wishlistEnchantLabel then
        setShown(self.wishlistEnchantLabel, enchantable)
    end
    if self.wishlistEnchantBox then
        setShown(self.wishlistEnchantBox, enchantable)
    end
    if self.wishlistGemsLabel then
        setShown(self.wishlistGemsLabel, socketCount > 0)
    end
    if self.wishlistGemBoxes then
        for i = 1, #self.wishlistGemBoxes do
            local gemBox = self.wishlistGemBoxes[i]
            if gemBox then
                setShown(gemBox, i <= socketCount)
            end
        end
    end
    if self.wishlistApplyGemsButton then
        setShown(self.wishlistApplyGemsButton, enchantable or socketCount > 0)
    end
    if self.UpdateWishlistTokenDisplay then
        self:UpdateWishlistTokenDisplay()
    end
    self:UpdateWishlistManagerList()
    self:UpdateWishlistSearchResults()
    if self.UpdateWishlistBuildList then
        self:UpdateWishlistBuildList()
    end
    if self.wishlistSocketPickerOpen then
        self:UpdateWishlistSocketPickerResults()
    end
    if self.wishlistAddSlotButton then
        if self.selectedWishlistSlot and self.selectedWishlistResult then
            self.wishlistAddSlotButton:Enable()
        else
            self.wishlistAddSlotButton:Disable()
        end
    end
    if self.wishlistClearSlotButton then
        if self.selectedWishlistSlot then
            self.wishlistClearSlotButton:Enable()
        else
            self.wishlistClearSlotButton:Disable()
        end
    end
end

function UI:TriggerWishlistRefresh()
    if self.wishlistRefreshButton and self.wishlistRefreshButton.Click then
        self.wishlistRefreshButton:Click()
        return
    end
    if Goals and Goals.RefreshWishlistItemCache then
        Goals:RefreshWishlistItemCache()
    end
    if self.UpdateWishlistUI then
        self:UpdateWishlistUI()
    end
end
