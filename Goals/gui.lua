-- Goals: gui.lua
-- UI implementation and layout helpers.

local addonName = ...
local Goals = _G.Goals or {}
_G.Goals = Goals

Goals.UI = Goals.UI or {}
local UI = Goals.UI
local L = Goals.L

local ROW_HEIGHT = 18
local ROSTER_ROWS = 20
local HISTORY_ROWS = 20
local HISTORY_ROW_HEIGHT = 18
local HISTORY_ROW_HEIGHT_DOUBLE = 26
local LOOT_HISTORY_ROWS = 20
local DEBUG_ROWS = 16
local DEBUG_ROW_HEIGHT = 14
local DAMAGE_ROWS = 20
local DAMAGE_ROW_HEIGHT = 18
local DAMAGE_COL_TIME = 70
local DAMAGE_COL_SOURCE = 120
local DAMAGE_COL_TARGET = 120
local DAMAGE_COL_AMOUNT = 70
local DAMAGE_COL_SPELL = 120
local DAMAGE_NAME_MAX_PLAYER = 12
local DAMAGE_NAME_MAX_NPC = 24
local MINI_ROW_HEIGHT = 16
local MINI_HEADER_HEIGHT = 22
local MINI_FRAME_WIDTH = 200
local MINI_DEFAULT_X = 260
local MINI_DEFAULT_Y = 0
local LOOT_HISTORY_ROW_HEIGHT = 28
local LOOT_HISTORY_ROW_HEIGHT_COMPACT = 18
local LOOT_ROWS = 18
local WISHLIST_SLOT_SIZE = 36
local WISHLIST_ROW_SPACING = 46
local OPTIONS_PANEL_WIDTH = 240
local OPTIONS_CONTROL_WIDTH = 196

local wishlistHasWowhead
local wishlistWowtbcSource
local wishlistHasBistooltip
local wishlistHasLoon
local wishlistSpecKey
local stripTextureTags
local showBuildPreviewTooltip
local hideBuildPreviewTooltip
local OPTIONS_BUTTON_HEIGHT = 24
local OPTIONS_CHECKBOX_SIZE = 24
local OPTIONS_DROPDOWN_HEIGHT = 26
local OPTIONS_EDITBOX_HEIGHT = 26
local MAIN_FRAME_HEIGHT = 520
local PAGE_BOTTOM_OFFSET = 12
local FOOTER_BOTTOM_INSET = 6
local FOOTER_BAR_HEIGHT = 24
local FOOTER_BAR_GAP = 4
local FOOTER_BAR_EXTRA = FOOTER_BAR_HEIGHT + FOOTER_BAR_GAP
local OPTIONS_HEADER_HEIGHT = 16
local OPTIONS_BUTTON_ID = 0
local createLabel

local THEME = {
    frameBg = { 0.08, 0.09, 0.12, 0.95 },
    frameLight = { 0.14, 0.15, 0.19, 0.4 },
    frameBorder = { 0.2, 0.22, 0.26, 0.75 },
    insetBg = { 0.1, 0.11, 0.15, 0.95 },
    insetBorder = { 0.17, 0.19, 0.24, 0.85 },
    titleText = { 0.9, 0.92, 0.98, 1.0 },
}

local DAMAGE_COLOR = { 1, 0.25, 0.25 }
local HEAL_COLOR = { 0.2, 1, 0.2 }
local DEATH_COLOR = { 0.7, 0.35, 0.9 }
local REVIVE_COLOR = { 1, 0.9, 0.2 }
local THREAT_COLOR = { 1, 0.7, 0.2 }
local ELITE_COLOR = { 1, 0.25, 0.25 }
local TRASH_COLOR = { 0.6, 0.6, 0.6 }
local COMBAT_SHOW_ALL = "Show all"
local COMBAT_SHOW_BOSS = "Show boss encounters"
local COMBAT_SHOW_TRASH = "Show trash"

local function applyTextureColor(texture, color)
    if not texture or not color then
        return
    end
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function applyFrameTheme(frame)
    if not frame or not frame.GetName then
        return
    end
    local name = frame:GetName()
    if not name then
        return
    end
    applyTextureColor(_G[name .. "Bg"], THEME.frameBg)
    applyTextureColor(_G[name .. "BgLight"], THEME.frameLight)
    applyTextureColor(_G[name .. "TitleBg"], THEME.frameBorder)
    applyTextureColor(_G[name .. "TopBorder"], THEME.frameBorder)
    applyTextureColor(_G[name .. "BottomBorder"], THEME.frameBorder)
    applyTextureColor(_G[name .. "LeftBorder"], THEME.frameBorder)
    applyTextureColor(_G[name .. "RightBorder"], THEME.frameBorder)
    applyTextureColor(_G[name .. "TopTileStreaks"], THEME.frameBorder)
    applyTextureColor(_G[name .. "TopLeftCorner"], THEME.frameBorder)
    applyTextureColor(_G[name .. "TopRightCorner"], THEME.frameBorder)
    applyTextureColor(_G[name .. "BotLeftCorner"], THEME.frameBorder)
    applyTextureColor(_G[name .. "BotRightCorner"], THEME.frameBorder)
end

local function applyInsetTheme(frame)
    if not frame or not frame.GetName then
        return
    end
    local name = frame:GetName()
    if not name then
        return
    end
    applyTextureColor(_G[name .. "InsetBg"], THEME.insetBg)
    applyTextureColor(_G[name .. "InsetTopBorder"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetBottomBorder"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetLeftBorder"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetRightBorder"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetTopLeftCorner"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetTopRightCorner"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetBotLeftCorner"], THEME.insetBorder)
    applyTextureColor(_G[name .. "InsetBotRightCorner"], THEME.insetBorder)
end

local function applySectionHeader(label, parent, yOffset)
    if not label or not parent then
        return nil
    end
    local bar = parent:CreateTexture(nil, "BORDER")
    bar:SetHeight(16)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset or -6)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset or -6)
    bar:SetTexture(0, 0, 0, 0.45)
    label:ClearAllPoints()
    label:SetPoint("LEFT", bar, "LEFT", 6, 0)
    label:SetTextColor(0.92, 0.8, 0.5, 1)
    return bar
end

local function applySectionHeaderAfter(label, parent, anchor, yOffset)
    if not label or not parent or not anchor then
        return nil
    end
    local bar = parent:CreateTexture(nil, "BORDER")
    bar:SetHeight(16)
    bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, yOffset or -8)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset or -8)
    bar:SetTexture(0, 0, 0, 0.45)
    label:ClearAllPoints()
    label:SetPoint("LEFT", bar, "LEFT", 6, 0)
    label:SetTextColor(0.92, 0.8, 0.5, 1)
    return bar
end
local function applySectionCaption(bar, text)
    if not bar or not text or text == "" then
        return nil
    end
    local parent = bar.GetParent and bar:GetParent() or nil
    if not parent then
        return nil
    end
    local caption = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    caption:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    caption:SetText(text)
    caption:SetTextColor(0.7, 0.75, 0.85, 1)
    return caption
end

local function createDivider(parent, anchor, yOffset)
    if not parent or not anchor then
        return nil
    end
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, yOffset or -8)
    line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -4, yOffset or -8)
    line:SetTexture(1, 1, 1, 0.08)
    return line
end

local function addRowStripe(row)
    if not row or row.stripe then
        return
    end
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(row)
    stripe:SetTexture(1, 1, 1, 0.06)
    row.stripe = stripe
end

local function styleOptionsButton(button, width)
    if not button then
        return
    end
    button:SetSize(width or OPTIONS_CONTROL_WIDTH, OPTIONS_BUTTON_HEIGHT)
    local font = button.GetFontString and button:GetFontString() or nil
    if font and font.SetFontObject then
        font:SetFontObject("GameFontHighlight")
    end
end

local function styleOptionsCheck(check)
    if not check then
        return
    end
    check:SetSize(OPTIONS_CHECKBOX_SIZE, OPTIONS_CHECKBOX_SIZE)
    if check.SetHitRectInsets then
        check:SetHitRectInsets(0, 0, 0, 0)
    end
    if check.SetNormalTexture then
        check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    end
    if check.SetPushedTexture then
        check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    end
    if check.SetHighlightTexture then
        check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    end
    if check.SetCheckedTexture then
        check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    if check.SetDisabledCheckedTexture then
        check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    end
end

local function styleOptionsEditBox(editBox, width)
    if not editBox then
        return
    end
    editBox:SetHeight(OPTIONS_EDITBOX_HEIGHT)
    if width then
        editBox:SetWidth(width)
    else
        editBox:SetWidth(OPTIONS_CONTROL_WIDTH)
    end
    if editBox.SetFontObject then
        editBox:SetFontObject("ChatFontNormal")
    end
    if editBox.SetTextInsets then
        editBox:SetTextInsets(0, 0, 3, 3)
    end
end

local function styleOptionsSlider(slider)
    if not slider then
        return
    end
    slider:SetWidth(OPTIONS_CONTROL_WIDTH)
    slider:SetHeight(14)
    if slider.SetMinMaxValues then
        slider:SetMinMaxValues(0, 100)
    end
    if slider.SetValueStep then
        slider:SetValueStep(1)
    end
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    local thumb = slider.GetThumbTexture and slider:GetThumbTexture() or nil
    if thumb and thumb.SetTexture then
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    local name = slider.GetName and slider:GetName() or nil
    if name then
        local low = _G[name .. "Low"]
        if low then
            low:Hide()
        end
        local high = _G[name .. "High"]
        if high then
            high:Hide()
        end
        local text = _G[name .. "Text"]
        if text then
            text:Hide()
        end
    end
end

local function styleOptionsLabel(label)
    if not label then
        return
    end
    if label.SetFontObject then
        label:SetFontObject("GameFontHighlightSmall")
    end
    if label.SetTextColor then
        label:SetTextColor(0.82, 0.86, 0.92, 1)
    end
end

local function createOptionsButton(parent)
    OPTIONS_BUTTON_ID = OPTIONS_BUTTON_ID + 1
    local name = "GoalsOptionsButton" .. OPTIONS_BUTTON_ID
    local ok, button = pcall(CreateFrame, "Button", name, parent, "UIPanelButtonTemplate2")
    if ok and button then
        return button
    end
    return CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
end

local styleDropdown

local function createOptionsDropdown(parent, name, yOffset)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(OPTIONS_CONTROL_WIDTH, OPTIONS_DROPDOWN_HEIGHT)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)

    local dropdown = CreateFrame("Frame", name, holder, "UIDropDownMenuTemplate")
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOPLEFT", holder, "TOPLEFT", -15, 0)
    dropdown:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 17, 0)
    styleDropdown(dropdown, OPTIONS_CONTROL_WIDTH)
    holder.dropdown = dropdown
    return dropdown, holder
end

local function styleOptionsControlLabel(label)
    if not label then
        return
    end
    if label.SetFontObject then
        label:SetFontObject("GameFontNormalSmall")
    end
    if label.SetTextColor then
        label:SetTextColor(0.92, 0.8, 0.5, 1)
    end
    if label.SetJustifyH then
        label:SetJustifyH("LEFT")
    end
    if label.SetWidth then
        label:SetWidth(OPTIONS_CONTROL_WIDTH)
    end
    if label.SetWordWrap then
        label:SetWordWrap(true)
    end
end

local function styleOptionsCheckLabel(label)
    if not label then
        return
    end
    if label.SetFontObject then
        label:SetFontObject("GameFontHighlight")
    end
    if label.SetTextColor then
        label:SetTextColor(1, 1, 1, 1)
    end
end

local function createOptionsHeader(parent, text, y)
    if not parent then
        return nil, nil
    end
    local heading = CreateFrame("Frame", nil, parent)
    heading:SetHeight(OPTIONS_HEADER_HEIGHT)
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y or -6)
    heading:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y or -6)

    local label = createLabel(heading, text, "GameFontNormalSmall")
    label:SetPoint("CENTER", heading, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetTextColor(0.92, 0.8, 0.5, 1)

    local lineLeft = heading:CreateTexture(nil, "BORDER")
    lineLeft:SetHeight(8)
    lineLeft:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    lineLeft:SetTexCoord(0.81, 0.94, 0.5, 1)
    lineLeft:SetPoint("LEFT", heading, "LEFT", 8, 0)
    lineLeft:SetPoint("RIGHT", label, "LEFT", -6, 0)

    local lineRight = heading:CreateTexture(nil, "BORDER")
    lineRight:SetHeight(8)
    lineRight:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    lineRight:SetTexCoord(0.81, 0.94, 0.5, 1)
    lineRight:SetPoint("LEFT", label, "RIGHT", 6, 0)
    lineRight:SetPoint("RIGHT", heading, "RIGHT", -8, 0)

    heading.label = label
    heading.leftLine = lineLeft
    heading.rightLine = lineRight
    return label, heading
end

local function wishlistCustomSources(build)
    local has = {}
    local function mark(value)
        if value == "custom-classic" then
            has["custom-classic"] = true
        elseif value == "custom-tbc" then
            has["custom-tbc"] = true
        elseif value == "custom-wotlk" then
            has["custom-wotlk"] = true
        end
    end
    if build then
        if type(build.tags) == "table" then
            for _, tag in ipairs(build.tags) do
                mark(tostring(tag or ""):lower())
            end
        end
        if type(build.sources) == "table" then
            for _, source in ipairs(build.sources) do
                mark(tostring(source or ""):lower())
            end
        end
    end
    return has
end

local function getExpansionBadge(tierId)
    local value = tostring(tierId or ""):upper()
    if value:find("WOTLK", 1, true) then
        return "WLK"
    end
    if value:find("TBC", 1, true) then
        return "TBC"
    end
    if value:find("CLASSIC", 1, true) then
        return "CLS"
    end
    return nil
end

local function getTierBadge(tierId)
    local value = tostring(tierId or ""):upper()
    if value:find("RS", 1, true) then
        return "RS"
    end
    local pr = value:match("PR(%d+)")
    if pr then
        return "PR" .. pr
    end
    local tnum = value:match("T(%d+)")
    if tnum then
        return "T" .. tnum
    end
    local pnum = value:match("_P(%d+)")
    if pnum then
        return "PR" .. pnum
    end
    if value:find("PRE", 1, true) then
        local expansion = getExpansionBadge(value)
        if expansion == "CLS" then
            return "PR1"
        elseif expansion == "TBC" then
            return "PR4"
        elseif expansion == "WLK" then
            return "PR7"
        end
        return "PR"
    end
    return nil
end

local function getExpansionTooltip(tierId)
    local value = tostring(tierId or ""):upper()
    if value:find("WOTLK", 1, true) then
        return "Wrath of the Lich King"
    end
    if value:find("TBC", 1, true) then
        return "The Burning Crusade"
    end
    if value:find("CLASSIC", 1, true) then
        return "World of Warcraft (Classic)"
    end
    return nil
end

local function getTierTooltip(tierId)
    local value = tostring(tierId or ""):upper()
    if value == "WOTLK_RS" then
        return "Ruby Sanctum"
    end
    local pr = value:match("PR(%d+)")
    if pr then
        return "Pre-Tier " .. pr
    end
    local tnum = value:match("T(%d+)")
    if tnum then
        return "Tier " .. tnum
    end
    return nil
end

local function getTierBadgeColor(tierId)
    local value = tostring(tierId or ""):upper()
    if value == "WOTLK_RS" then
        return 0.8, 0.2, 0.2
    end
    local expansion = getExpansionBadge(value)
    local tierNum = nil
    local pr = value:match("PR(%d+)")
    if pr then
        tierNum = 0
    end
    local tnum = value:match("T(%d+)")
    if tnum then
        tierNum = tonumber(tnum)
    end
    if value:find("T25", 1, true) then
        tierNum = 2.5
    end
    if not tierNum then
        tierNum = 0
    end
    local function lerp(a, b, t)
        return a + (b - a) * t
    end
    if expansion == "CLS" then
        -- Dark brown -> light tan
        local maxTier = 3
        local t = math.max(0, math.min(1, tierNum / maxTier))
        return lerp(0.22, 0.85, t), lerp(0.12, 0.72, t), lerp(0.05, 0.45, t)
    elseif expansion == "TBC" then
        -- Dark green -> bright lime
        local maxTier = 6
        local t = math.max(0, math.min(1, tierNum / maxTier))
        return lerp(0.08, 0.55, t), lerp(0.25, 0.95, t), lerp(0.08, 0.35, t)
    elseif expansion == "WLK" then
        -- Deep blue -> icy blue
        local maxTier = 10
        local t = math.max(0, math.min(1, tierNum / maxTier))
        return lerp(0.08, 0.55, t), lerp(0.18, 0.75, t), lerp(0.35, 1.0, t)
    end
    return 0.2, 0.2, 0.2
end

local function applyBadgeStyle(badge, text, r, g, b)
    if not badge or not badge.text then
        return
    end
    if badge.SetAlpha then
        badge:SetAlpha(1)
    end
    badge.text:SetText(text or "")
    local width = (badge.text.GetStringWidth and badge.text:GetStringWidth() or 0) + 12
    if badge.SetWidth then
        badge:SetWidth(width)
    end
    if badge.bg then
        badge.bg:SetTexture(r or 0.2, g or 0.2, b or 0.2, 0.7)
    end
    if badge.text.SetTextColor then
        badge.text:SetTextColor(1, 1, 1, 1)
    end
    badge:Show()
end

local function badgeColorCode(r, g, b)
    local function toByte(v)
        v = v or 0
        if v < 0 then v = 0 end
        if v > 1 then v = 1 end
        return math.floor(v * 255 + 0.5)
    end
    return string.format("|cff%02x%02x%02x", toByte(r), toByte(g), toByte(b))
end

local function buildBadgeText(expansionBadge, tierBadge)
    local parts = {}
    if expansionBadge then
        local code = badgeColorCode(0.3, 0.3, 0.3)
        if expansionBadge == "WLK" then
            code = badgeColorCode(0.2, 0.45, 0.8)
        elseif expansionBadge == "TBC" then
            code = badgeColorCode(0.25, 0.6, 0.35)
        elseif expansionBadge == "CLS" then
            code = badgeColorCode(0.7, 0.5, 0.2)
        end
        parts[#parts + 1] = string.format("%s[%s]|r", code, expansionBadge)
    end
    if tierBadge then
        local code = badgeColorCode(0.2, 0.2, 0.2)
        parts[#parts + 1] = string.format("%s[%s]|r", code, tierBadge)
    end
    if #parts == 0 then
        return ""
    end
    return "  " .. table.concat(parts, " ")
end

local function createBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetHeight(14)
    if badge.SetFrameLevel and parent and parent.GetFrameLevel then
        badge:SetFrameLevel(parent:GetFrameLevel() + 2)
    end
    if badge.SetFrameStrata and parent and parent.GetFrameStrata then
        badge:SetFrameStrata(parent:GetFrameStrata())
    end
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(badge)
    badge.bg = bg
    local text = badge:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetDrawLayer("OVERLAY")
    text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    badge.text = text
    badge:Hide()
    return badge
end

local function wrapTextToWidth(text, maxWidth, fontString)
    if not text or text == "" or not maxWidth or maxWidth <= 0 or not fontString or not fontString.GetStringWidth then
        return text or ""
    end
    local words = {}
    for w in tostring(text):gmatch("%S+") do
        words[#words + 1] = w
    end
    if #words == 0 then
        return text
    end
    local lines = {}
    local line = ""
    for _, w in ipairs(words) do
        local candidate = (line == "" and w) or (line .. " " .. w)
        fontString:SetText(candidate)
        if fontString:GetStringWidth() > maxWidth and line ~= "" then
            lines[#lines + 1] = line
            line = w
        else
            line = candidate
        end
    end
    if line ~= "" then
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

local function colorizeItemName(name, quality)
    if not name or name == "" or not quality or not ITEM_QUALITY_COLORS or not ITEM_QUALITY_COLORS[quality] then
        return name
    end
    local color = ITEM_QUALITY_COLORS[quality]
    local r = math.floor((color.r or 1) * 255 + 0.5)
    local g = math.floor((color.g or 1) * 255 + 0.5)
    local b = math.floor((color.b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, name)
end

local function resolveNoteItemIds(noteText)
    if not noteText or noteText == "" then
        return ""
    end
    local function replaceId(idText)
        local id = tonumber(idText)
        if not id or id < 1000 or id > 99999 then
            return idText
        end
        if Goals and Goals.CacheItemById then
            local cached = Goals:CacheItemById(id)
            if cached and cached.name and cached.name ~= "" then
                return colorizeItemName(cached.name, cached.quality)
            end
        end
        return idText
    end
    -- Replace standalone 4-5 digit sequences
    local replaced = noteText:gsub("%f[%d](%d%d%d%d%d?)%f[%D]", replaceId)
    return replaced
end

local function extractNoteItemIds(noteText)
    local ids = {}
    if not noteText or noteText == "" then
        return ids
    end
    for idText in tostring(noteText):gmatch("%f[%d](%d%d%d%d%d?)%f[%D]") do
        local id = tonumber(idText)
        if id and id >= 1000 and id <= 99999 then
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function createFooterBar(ui, page, key, suffix)
    if not ui or not page then
        return nil
    end
    local name = "GoalsTabFooter" .. (suffix or "") .. tostring(key or "")
    local footer = CreateFrame("Frame", name, page, "GoalsInsetTemplate")
    applyInsetTheme(footer)
    footer:SetHeight(FOOTER_BAR_HEIGHT)

    local leftText = createLabel(footer, "", "GameFontHighlightSmall")
    leftText:SetPoint("LEFT", footer, "LEFT", 8, 0)
    leftText:SetJustifyH("LEFT")
    footer.leftText = leftText

    local centerText = createLabel(footer, "", "GameFontHighlightSmall")
    centerText:SetPoint("CENTER", footer, "CENTER", 0, 0)
    centerText:SetJustifyH("CENTER")
    footer.centerText = centerText

    local rightText = createLabel(footer, "", "GameFontHighlightSmall")
    rightText:SetPoint("RIGHT", footer, "RIGHT", -8, 0)
    rightText:SetJustifyH("RIGHT")
    footer.rightText = rightText

    footer.key = key
    return footer
end

local function createTabFooter(ui, page, key)
    if not ui or not page then
        return nil
    end
    ui.tabFooters = ui.tabFooters or {}
    local footer = createFooterBar(ui, page, key)
    footer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", FOOTER_BOTTOM_INSET, FOOTER_BOTTOM_INSET)
    footer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -FOOTER_BOTTOM_INSET, FOOTER_BOTTOM_INSET)
    ui.tabFooters[key] = footer
    return footer
end

local function createTabFooter2(ui, page, key, footer1)
    if not ui or not page then
        return nil
    end
    ui.tabFooters2 = ui.tabFooters2 or {}
    local footer = createFooterBar(ui, page, key, "2")
    local yOffset = PAGE_BOTTOM_OFFSET + FOOTER_BOTTOM_INSET
    if footer1 and ui.frame then
        footer:SetPoint("LEFT", footer1, "LEFT", 0, 0)
        footer:SetPoint("RIGHT", footer1, "RIGHT", 0, 0)
        footer:SetPoint("BOTTOM", ui.frame, "BOTTOM", 0, yOffset)
    else
        footer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", FOOTER_BOTTOM_INSET, yOffset)
        footer:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -FOOTER_BOTTOM_INSET, yOffset)
    end
    ui.tabFooters2[key] = footer
    return footer
end

local function anchorToFooter(frame, footer, leftOffset, rightOffset, yOffset)
    if not frame or not footer then
        return
    end
    local y = yOffset or 6
    if leftOffset ~= nil then
        frame:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", leftOffset, y)
    end
    if rightOffset ~= nil then
        frame:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", rightOffset, y)
    end
end

local function getScrollBar(frame)
    if not frame then
        return nil
    end
    if frame.ScrollBar then
        return frame.ScrollBar
    end
    local name = frame.GetName and frame:GetName() or nil
    if name then
        return _G[name .. "ScrollBar"]
    end
    return nil
end

local function ensureScrollBarBackground(scrollFrame)
    if not scrollFrame then
        return
    end
    local bar = getScrollBar(scrollFrame)
    if not bar then
        return
    end
    if bar._goalsBg and bar._goalsBg.SetAllPoints then
        bar._goalsBg:Show()
        bar._goalsBg:ClearAllPoints()
        bar._goalsBg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 16)
        bar._goalsBg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -16)
        return
    end
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 16)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -16)
    bg:SetTexture(0.1, 0.1, 0.1, 0.6)
    bar._goalsBg = bg
end

local function setScrollBarAlwaysVisible(scrollFrame, contentHeight)
    ensureScrollBarBackground(scrollFrame)
    local bar = getScrollBar(scrollFrame)
    if not bar then
        return
    end
    bar:Show()
    local viewHeight = scrollFrame:GetHeight() or 0
    local enabled = (contentHeight or 0) > (viewHeight + 2)
    if enabled then
        if bar.Enable then
            bar:Enable()
        end
        if bar.SetAlpha then
            bar:SetAlpha(1)
        end
    else
        if bar.Disable then
            bar:Disable()
        end
        if bar.SetAlpha then
            bar:SetAlpha(0.35)
        end
    end
end

local function createOptionsPanel(parent, name, width)
    local panel = CreateFrame("Frame", name, parent, "GoalsInsetTemplate")
    applyInsetTheme(panel)
    panel:SetWidth(width or OPTIONS_PANEL_WIDTH)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -12)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)

    local divider = panel:CreateTexture(nil, "BORDER")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -2)
    divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 2)
    divider:SetTexture(1, 1, 1, 0.08)
    panel.divider = divider

    local scroll = CreateFrame("ScrollFrame", name .. "Scroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 6)
    panel.scroll = scroll
    ensureScrollBarBackground(scroll)

    local content = CreateFrame("Frame", name .. "Content", scroll)
    content:SetWidth((width or OPTIONS_PANEL_WIDTH) - 30)
    scroll:SetScrollChild(content)
    panel.content = content

    return panel, content
end

local function createTableWidget(parent, name, config)
    local widget = {}
    widget.columns = config.columns or {}
    widget.rowHeight = config.rowHeight or ROW_HEIGHT
    widget.rows = {}

    local headerLeft = 6
    local headerRight = -32
    local headerTop = -6
    local headerHeight = config.headerHeight or 18
    widget.headerLeft = headerLeft
    widget.headerRight = headerRight
    widget.rowTopOffset = -(headerHeight + 6)

    local header = CreateFrame("Frame", name .. "Header", parent)
    header:SetHeight(headerHeight)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", headerLeft, headerTop)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", headerRight, headerTop)
    local headerBg = header:CreateTexture(nil, "BORDER")
    headerBg:SetAllPoints(header)
    headerBg:SetTexture(0, 0, 0, 0.45)
    widget.header = header

    local headerLine = parent:CreateTexture(nil, "BORDER")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    headerLine:SetTexture(1, 1, 1, 0.08)
    widget.headerLine = headerLine

    local prevHeader = nil
    for _, col in ipairs(widget.columns) do
        local label = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        if prevHeader then
            label:SetPoint("LEFT", prevHeader, "RIGHT", col.spacing or 6, 0)
        else
            label:SetPoint("LEFT", header, "LEFT", 0, 0)
        end
        if col.fill then
            label:SetPoint("RIGHT", header, "RIGHT", -6, 0)
        else
            label:SetWidth(col.width or 80)
        end
        label:SetJustifyH(col.justify or "LEFT")
        label:SetText(col.title or "")
        label:SetTextColor(0.92, 0.8, 0.5, 1)
        col.header = label
        prevHeader = label
    end

    local scroll = CreateFrame("ScrollFrame", name .. "Scroll", parent, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -2)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -32, 6)
    widget.scroll = scroll
    ensureScrollBarBackground(scroll)

    for i = 1, (config.visibleRows or HISTORY_ROWS) do
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(widget.rowHeight)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", headerLeft, widget.rowTopOffset - (i - 1) * widget.rowHeight)
        row:SetPoint("RIGHT", parent, "RIGHT", headerRight, 0)
        addRowStripe(row)

        row.cols = {}
        local prev = nil
        for _, col in ipairs(widget.columns) do
            local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            if prev then
                text:SetPoint("LEFT", prev, "RIGHT", col.spacing or 6, 0)
            else
                text:SetPoint("LEFT", row, "LEFT", 0, 0)
            end
            if col.fill then
                text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            else
                text:SetWidth(col.width or 80)
            end
            text:SetJustifyH(col.justify or "LEFT")
            if col.wrap == false then
                text:SetWordWrap(false)
            else
                text:SetWordWrap(true)
            end
            row.cols[col.key] = text
            prev = text
        end

        if row.cols.time then
            row.timeText = row.cols.time
        end
        if row.cols.text then
            row.text = row.cols.text
        end

        widget.rows[i] = row
    end

    return widget
end
createLabel = function(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text or "")
    return label
end

local function bindEscapeClear(editBox)
    if not editBox then
        return
    end
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end

local function setCheckText(check, text)
    if not check then
        return
    end
    local label = check.Text
    if not label then
        local name = check:GetName()
        if name then
            label = _G[name .. "Text"]
        end
    end
    if not label then
        label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        check.Text = label
    end
    if label then
        if label.ClearAllPoints then
            label:ClearAllPoints()
        end
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        styleOptionsCheckLabel(label)
        if label.SetJustifyH then
            label:SetJustifyH("LEFT")
        end
        if label.SetWidth then
            label:SetWidth(OPTIONS_CONTROL_WIDTH - 6)
        end
        if label.SetWordWrap then
            label:SetWordWrap(true)
        end
        label:SetText(text or "")
    end
end

local function getDropDownPart(dropdown, part)
    if dropdown[part] then
        return dropdown[part]
    end
    local name = dropdown:GetName()
    if name then
        return _G[name .. part]
    end
    return nil
end

local function colorizeName(name)
    if Goals and Goals.ColorizeName then
        return Goals:ColorizeName(name)
    end
    return name
end

local classColorList = nil
local function getClassColorList()
    if classColorList then
        return classColorList
    end
    classColorList = {}
    if RAID_CLASS_COLORS then
        local classes = {}
        for className in pairs(RAID_CLASS_COLORS) do
            table.insert(classes, className)
        end
        table.sort(classes)
        for _, className in ipairs(classes) do
            local color = RAID_CLASS_COLORS[className]
            table.insert(classColorList, { r = color.r, g = color.g, b = color.b })
        end
    end
    if #classColorList == 0 then
        classColorList = {
            { r = 0.9, g = 0.9, b = 0.9 },
        }
    end
    return classColorList
end

local function getRainbowColor()
    local colors = getClassColorList()
    local count = #colors
    local t = GetTime and GetTime() or 0
    local index = (math.floor(t * 2) % count) + 1
    return colors[index]
end

local function formatPlayersCount(count)
    local text = tostring(count) .. " Players"
    local c = getRainbowColor()
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

local function fitLabelToWidth(label, text)
    if not label then
        return
    end
    local raw = text or ""
    label:SetText(raw)
    local maxWidth = label:GetWidth() or 0
    if maxWidth <= 0 then
        return
    end
    if label:GetStringWidth() <= maxWidth then
        return
    end
    local left, right = 1, #raw
    local best = "..."
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local candidate = raw:sub(1, mid) .. "..."
        label:SetText(candidate)
        if label:GetStringWidth() <= maxWidth then
            best = candidate
            left = mid + 1
        else
            right = mid - 1
        end
    end
    label:SetText(best)
end

local function setLootItemLabelText(label, text)
    if not label then
        return
    end
    local raw = text or ""
    local color, name = raw:match("|c(%x%x%x%x%x%x%x%x)|H.-|h%[(.-)%]|h|r")
    if color and name then
        fitLabelToWidth(label, name)
        local trimmed = label:GetText() or ""
        label:SetText("|c" .. color .. trimmed .. "|r")
    else
        fitLabelToWidth(label, raw)
    end
end

function UI:UpdateRainbowRows()
    local function updateRow(row)
        if not row or not row.rainbowData then
            return false
        end
        local data = row.rainbowData
        if row.cols then
            if data.kind == "loot" then
                local eventCol = row.cols.event or row.cols.item
                if eventCol then
                    if row.cols and eventCol == row.cols.item then
                        setLootItemLabelText(eventCol, data.itemLink or "")
                    else
                        eventCol:SetText(data.itemLink or "")
                    end
                end
                if row.cols.player then
                    row.cols.player:SetText(formatPlayersCount(data.count))
                    row.cols.player:SetTextColor(1, 1, 1)
                end
                if row.cols.notes then
                    row.cols.notes:SetText("Assigned")
                end
            elseif data.kind == "boss" then
                if row.cols.event then
                    row.cols.event:SetText(data.encounter or "Boss")
                end
                if row.cols.player then
                    row.cols.player:SetText(formatPlayersCount(data.count))
                    row.cols.player:SetTextColor(1, 1, 1)
                end
                if row.cols.notes then
                    row.cols.notes:SetText(string.format("+%d", data.points or 0))
                end
            end
            return true
        end
        if not row.text or not row.text.SetText then
            return false
        end
        if data.kind == "loot" then
            row.text:SetText(string.format("Gave %s: %s", formatPlayersCount(data.count), data.itemLink or ""))
        elseif data.kind == "boss" then
            row.text:SetText(string.format("Gave %s: +%d (%s)", formatPlayersCount(data.count), data.points or 0, data.encounter or "Boss"))
        end
        return true
    end

    local any = false
    if self.historyRows then
        for _, row in ipairs(self.historyRows) do
            if row:IsShown() then
                any = updateRow(row) or any
            end
        end
    end
    if self.lootHistoryRows then
        for _, row in ipairs(self.lootHistoryRows) do
            if row:IsShown() then
                any = updateRow(row) or any
            end
        end
    end
    return any
end

function UI:StartRainbowTicker()
    if not self.frame then
        return
    end
    if self.rainbowTickerActive then
        return
    end
    self.rainbowTickerActive = true
    self.rainbowElapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.rainbowElapsed = (self.rainbowElapsed or 0) + (elapsed or 0)
        if self.rainbowElapsed < 0.2 then
            return
        end
        self.rainbowElapsed = 0
        if not self:UpdateRainbowRows() then
            self.rainbowTickerActive = false
            self.frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function getUpdateInfo()
    local info = Goals and Goals.UpdateInfo or nil
    local installedMajor = info and tonumber(info.major) or 2
    local installedMinor = info and tonumber(info.version) or 0
    local url = info and info.url or ""
    local availableMajor = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateAvailableMajor or 0
    local availableMinor = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateAvailableVersion or 0
    return installedMajor, installedMinor, availableMajor, availableMinor, url
end

local function isUpdateAvailable()
    local installedMajor, installedMinor, availableMajor, availableMinor = getUpdateInfo()
    if availableMajor == 0 and availableMinor == 0 then
        return false
    end
    if availableMajor ~= installedMajor then
        return availableMajor > installedMajor
    end
    return availableMinor > installedMinor
end

local function hasModifyAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    if Goals and Goals.IsMasterLooter and Goals:IsMasterLooter() then
        return true
    end
    if not Goals or not Goals.IsGroupLeader then
        return false
    end
    local inRaid = Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals.IsInParty and Goals:IsInParty()
    return (inRaid or inParty) and Goals:IsGroupLeader()
end

local function getAccessStatus()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return "Dev Enabled"
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return "Dev Enabled"
    end
    if Goals and Goals.IsMasterLooter and Goals:IsMasterLooter() then
        return "Loot Master Enabled"
    end
    if UnitIsRaidOfficer and UnitIsRaidOfficer("player") then
        return "Loot Helper Enabled"
    end
    if Goals and Goals.IsGroupLeader and Goals:IsGroupLeader() then
        return "Admin Enabled"
    end
    local inRaid = Goals and Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals and Goals.IsInParty and Goals:IsInParty()
    if inRaid or inParty then
        return "Raid/Party Player"
    end
    return "Solo Player"
end

local function hasPointGainAccess()
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    if Goals and Goals.IsMasterLooter and Goals:IsMasterLooter() then
        return true
    end
    if Goals and Goals.IsGroupLeader and Goals:IsGroupLeader() then
        return true
    end
    return Goals and Goals.sync and Goals.sync.isMaster
end

local function hasDisenchanterAccess()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    if Goals and Goals.db and Goals.db.settings and Goals.db.settings.sudoDev then
        return true
    end
    if not Goals or not Goals.IsGroupLeader then
        return false
    end
    local inRaid = Goals.IsInRaid and Goals:IsInRaid()
    local inParty = Goals.IsInParty and Goals:IsInParty()
    return (inRaid or inParty) and Goals:IsGroupLeader()
end

local function setupSudoDevPopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_SUDO_DEV then
        return
    end
    StaticPopupDialogs.GOALS_SUDO_DEV = {
        text = L.POPUP_SUDO_DEV,
        button1 = L.POPUP_SUDO_DEV_ACCEPT,
        button2 = CANCEL,
        OnAccept = function()
            if Goals and Goals.db and Goals.db.settings then
                Goals.db.settings.sudoDev = true
                if Goals.UI then
                    Goals.UI:Refresh()
                end
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
end

local function setupSaveTableHelpPopup()
    return
end

local function getOverviewMigrationPromptText()
    return (L and L.POPUP_OVERVIEW_MIGRATE) or
        "Old table data detected. Click OK to combine all account-based tables."
end

local function layoutOverviewMigrationPrompt(frame)
    if not frame or not frame.content or not frame.body or not frame.okBtn then
        return
    end
    local content = frame.content
    local body = frame.body
    local button = frame.okBtn
    local contentWidth = (content.GetWidth and content:GetWidth()) or (OPTIONS_PANEL_WIDTH + 8)
    local textWidth = math.max(140, contentWidth - 16)

    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    body:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -8)
    if body.SetWidth then
        body:SetWidth(textWidth)
    end

    local textHeight = (body.GetStringHeight and body:GetStringHeight()) or 16
    if textHeight < 16 then
        textHeight = 16
    end
    local buttonHeight = (button.GetHeight and button:GetHeight()) or OPTIONS_BUTTON_HEIGHT
    local contentNeeded = textHeight + buttonHeight + 24
    local frameNeeded = contentNeeded + 30
    local targetHeight = math.max(124, math.min(220, math.ceil(frameNeeded)))
    frame:SetHeight(targetHeight)
end

local function ensureOverviewMigrationPrompt()
    if not UI or UI.overviewMigrationPrompt then
        return UI and UI.overviewMigrationPrompt or nil
    end
    local frame = CreateFrame("Frame", "GoalsOverviewMigrationPrompt", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(frame)
    frame:SetSize(OPTIONS_PANEL_WIDTH + 24, 132)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(1000)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText("GOALS Account Data")
        frame.TitleText:Show()
    end
    local frameName = frame.GetName and frame:GetName() or nil
    local close = frame.CloseButton or (frameName and _G[frameName .. "CloseButton"]) or nil
    if close then
        close:SetScript("OnClick", function()
            if Goals and Goals.MergeLegacyOverviewTables then
                Goals:MergeLegacyOverviewTables()
            elseif Goals and Goals.dbRoot then
                Goals.dbRoot.overviewMigrationPending = false
            end
            frame:Hide()
        end)
    end

    local content = CreateFrame("Frame", nil, frame, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.content = content

    local migrateText = getOverviewMigrationPromptText()
    local body = createLabel(content, migrateText, "GameFontHighlight")
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWidth(OPTIONS_PANEL_WIDTH)
    if body.SetWordWrap then
        body:SetWordWrap(true)
    end
    if body.SetNonSpaceWrap then
        body:SetNonSpaceWrap(true)
    end
    if body.SetMaxLines then
        body:SetMaxLines(0)
    end
    if body.SetTextColor then
        body:SetTextColor(0.9, 0.92, 0.98, 1)
    end
    frame.body = body

    local okBtn = createOptionsButton(content)
    styleOptionsButton(okBtn, 120)
    okBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)
    okBtn:SetText("OK")
    okBtn:SetScript("OnClick", function()
        if Goals and Goals.MergeLegacyOverviewTables then
            Goals:MergeLegacyOverviewTables()
        end
        frame:Hide()
    end)
    frame.okBtn = okBtn

    local frameNameForEscape = frame.GetName and frame:GetName() or nil
    if frameNameForEscape then
        if RegisterSpecialFrame then
            RegisterSpecialFrame(frameNameForEscape)
        elseif registerSpecialFrame then
            registerSpecialFrame(frameNameForEscape)
        end
    end
    UI.overviewMigrationPrompt = frame
    return frame
end

local function ensureOverviewMigrationPromptWidgets(frame)
    if not frame or not frame.content then
        return
    end
    local content = frame.content
    local migrateText = getOverviewMigrationPromptText()

    if not frame.body then
        local body = createLabel(content, migrateText, "GameFontHighlight")
        body:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetWidth(OPTIONS_PANEL_WIDTH)
        if body.SetWordWrap then
            body:SetWordWrap(true)
        end
        if body.SetNonSpaceWrap then
            body:SetNonSpaceWrap(true)
        end
        if body.SetMaxLines then
            body:SetMaxLines(0)
        end
        if body.SetTextColor then
            body:SetTextColor(0.9, 0.92, 0.98, 1)
        end
        frame.body = body
    end
    if frame.body then
        if frame.body.SetText then
            frame.body:SetText(migrateText)
        end
        if frame.body.SetFontObject then
            frame.body:SetFontObject("GameFontHighlight")
        end
        if frame.body.SetTextColor then
            frame.body:SetTextColor(0.9, 0.92, 0.98, 1)
        end
        if frame.body.SetJustifyV then
            frame.body:SetJustifyV("TOP")
        end
        if frame.body.SetWordWrap then
            frame.body:SetWordWrap(true)
        end
        if frame.body.SetMaxLines then
            frame.body:SetMaxLines(0)
        end
        if frame.body.SetWidth then
            frame.body:SetWidth(OPTIONS_PANEL_WIDTH)
        end
        if frame.body.SetDrawLayer then
            frame.body:SetDrawLayer("OVERLAY")
        end
        if frame.body.Show then
            frame.body:Show()
        end
    end

    local function forceButtonVisuals(btn, labelText)
        if not btn then
            return
        end
        if btn.SetText then
            btn:SetText(labelText or "")
        end
        local fs = btn.GetFontString and btn:GetFontString() or nil
        if not fs then
            fs = btn.goalsFallbackText
            if not fs then
                fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
                btn.goalsFallbackText = fs
            end
            fs:SetText(labelText or "")
        end
        if fs and fs.SetTextColor then
            fs:SetTextColor(1, 1, 1, 1)
        end
        if btn.SetAlpha then
            btn:SetAlpha(1)
        end
        if btn.Show then
            btn:Show()
        end
    end

    if not frame.okBtn then
        local okBtn = createOptionsButton(content)
        styleOptionsButton(okBtn, 120)
        okBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)
        okBtn:SetText("OK")
        okBtn:SetScript("OnClick", function()
            if Goals and Goals.MergeLegacyOverviewTables then
                Goals:MergeLegacyOverviewTables()
            end
            frame:Hide()
        end)
        frame.okBtn = okBtn
    end
    if frame.okBtn then
        frame.okBtn:SetFrameLevel((content:GetFrameLevel() or frame:GetFrameLevel() or 1) + 10)
        forceButtonVisuals(frame.okBtn, "OK")
    end

    if frame.cancelBtn then
        frame.cancelBtn:Hide()
    end

    layoutOverviewMigrationPrompt(frame)
end

local function setupBuildSharePopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_BUILD_SHARE then
        return
    end
    StaticPopupDialogs.GOALS_BUILD_SHARE = {
        text = "",
        button1 = L.POPUP_BUILD_SHARE_ACCEPT,
        button2 = L.POPUP_BUILD_SHARE_DECLINE,
        OnShow = function(self)
            local pending = Goals and Goals.state and Goals.state.pendingBuildShare or nil
            local sender = pending and pending.sender or "Someone"
            local name = pending and pending.data and pending.data.name or "Wishlist"
            local text = string.format(L.POPUP_BUILD_SHARE, sender, name)
            local textRegion = _G[self:GetName() .. "Text"]
            if textRegion then
                textRegion:SetText(text)
            end
        end,
        OnAccept = function()
            if Goals and Goals.AcceptPendingBuildShare then
                Goals:AcceptPendingBuildShare()
            end
        end,
        OnCancel = function()
            if Goals and Goals.DeclinePendingBuildShare then
                Goals:DeclinePendingBuildShare()
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
end

local function setDropdownEnabled(dropdown, enabled)
    if not dropdown then
        return
    end
    if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
        if enabled then
            UIDropDownMenu_EnableDropDown(dropdown)
        else
            UIDropDownMenu_DisableDropDown(dropdown)
        end
        return
    end
    if enabled then
        if dropdown.Enable then
            dropdown:Enable()
        end
    else
        if dropdown.Disable then
            dropdown:Disable()
        end
    end
end

local function getMiniSettings()
    if not Goals or not Goals.db or not Goals.db.settings then
        return nil
    end
    if type(Goals.db.settings.miniTracker) ~= "table" then
        Goals.db.settings.miniTracker = {
            show = false,
            minimized = false,
            x = MINI_DEFAULT_X,
            y = MINI_DEFAULT_Y,
            hasPosition = false,
            buttonX = 0,
            buttonY = 0,
        }
    end
    return Goals.db.settings.miniTracker
end

local function getQualityLabel(quality)
    local label = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, label)
    end
    return label
end

local function getQualityOptions()
    local qualities = { 0, 1, 2, 3, 4, 5, 6, 7 }
    local options = {}
    for _, quality in ipairs(qualities) do
        local label = _G["ITEM_QUALITY" .. quality .. "_DESC"]
        if label then
            table.insert(options, { value = quality, text = getQualityLabel(quality) })
        end
    end
    return options
end

styleDropdown = function(dropdown, width)
    UIDropDownMenu_SetWidth(dropdown, width or OPTIONS_CONTROL_WIDTH)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")
    local left = getDropDownPart(dropdown, "Left")
    local middle = getDropDownPart(dropdown, "Middle")
    local right = getDropDownPart(dropdown, "Right")
    if left then
        left:Show()
    end
    if middle then
        middle:Show()
        middle:ClearAllPoints()
    end
    if right then
        right:Show()
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 17)
    end
    if left and middle and right then
        middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
        middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    end
    local button = getDropDownPart(dropdown, "Button")
    if button then
        button:SetAlpha(1)
    end
    local text = getDropDownPart(dropdown, "Text")
    if text then
        if text.SetFontObject then
            text:SetFontObject("GameFontHighlight")
        end
        if text.SetTextColor then
            text:SetTextColor(0.95, 0.95, 0.95, 1)
        end
        text:ClearAllPoints()
        text:SetPoint("RIGHT", right or dropdown, "RIGHT", -43, 2)
        text:SetPoint("LEFT", left or dropdown, "LEFT", 25, 2)
        text:SetJustifyH("LEFT")
    end
end

local function formatTime(ts)
    return date("%H:%M:%S", ts or time())
end

local function formatCombatTimestamp(ts)
    if not ts then
        return ""
    end
    if ts > 1000000000 then
        return date("%H:%M:%S", ts)
    end
    return string.format("%.1f", ts)
end

local function setShown(frame, show)
    if not frame then
        return
    end
    if show then
        frame:Show()
    else
        frame:Hide()
    end
end

local function showSideTooltip(text)
    if not text or text == "" then
        return
    end
    local anchor = UI and UI.frame or UIParent
    local tip = UI and UI.sideTooltip or nil
    if not tip then
        tip = CreateFrame("GameTooltip", "GoalsSideTooltip", UIParent, "GameTooltipTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetClampedToScreen(true)
        if UI then
            UI.sideTooltip = tip
        end
    end
    tip:Hide()
    tip:ClearLines()
    tip:SetOwner(anchor, "ANCHOR_NONE")
    tip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, -30)
    if tip.SetWidth then
        tip:SetWidth(OPTIONS_PANEL_WIDTH)
    end
    tip:SetText(text, 1, 1, 1, true)
    tip:Show()
end

local function showSideTooltipAt(text, anchor, point, relativePoint, xOffset, yOffset)
    if not text or text == "" then
        return
    end
    local anchorFrame = anchor or (UI and UI.frame) or UIParent
    local tip = UI and UI.sideTooltip or nil
    if not tip then
        tip = CreateFrame("GameTooltip", "GoalsSideTooltip", UIParent, "GameTooltipTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetClampedToScreen(true)
        if UI then
            UI.sideTooltip = tip
        end
    end
    tip:Hide()
    tip:ClearLines()
    tip:SetOwner(anchorFrame, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint(point or "TOPLEFT", anchorFrame, relativePoint or "TOPRIGHT", xOffset or 10, yOffset or -30)
    if tip.SetWidth then
        tip:SetWidth(OPTIONS_PANEL_WIDTH)
    end
    tip:SetText(text, 1, 1, 1, true)
    tip:Show()
end

local function hideSideTooltip()
    if UI and UI.sideTooltip then
        UI.sideTooltip:Hide()
    end
end

local function attachSideTooltip(frame, text)
    if not frame or not text or text == "" then
        return
    end
    frame:SetScript("OnEnter", function()
        showSideTooltip(text)
    end)
    frame:SetScript("OnLeave", function()
        hideSideTooltip()
    end)
end

local function getPlayerColor(name)
    if Goals and Goals.GetPlayerColor and name and name ~= "" then
        local pr, pg, pb = Goals:GetPlayerColor(name)
        if pr and pg and pb then
            return pr, pg, pb
        end
    end
    return 1, 1, 1
end

local function getSourceColor(entry)
    if not entry then
        return 1, 1, 1
    end
    local kind = entry.sourceKind
    if kind == "boss" then
        if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] then
            local color = ITEM_QUALITY_COLORS[5]
            return color.r, color.g, color.b
        end
        return 1, 0.5, 0
    end
    if kind == "elite" then
        return ELITE_COLOR[1], ELITE_COLOR[2], ELITE_COLOR[3]
    end
    if kind == "trash" then
        return TRASH_COLOR[1], TRASH_COLOR[2], TRASH_COLOR[3]
    end
    if kind == "player" and entry.source then
        return getPlayerColor(entry.source)
    end
    return 1, 1, 1
end

local function hideCombatRowTooltip()
    if UI and UI.combatRowTooltip then
        UI.combatRowTooltip:Hide()
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function clearCombatRowTooltipLock()
    if UI then
        UI.combatTooltipLocked = false
        UI.combatTooltipEntry = nil
    end
end

local function ensureCombatRowTooltip()
    if not UI or not UI.frame then
        return nil
    end
    if UI.combatRowTooltip then
        return UI.combatRowTooltip
    end
    local tip = CreateFrame("Frame", "GoalsCombatRowTooltip", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(tip)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    tip:SetWidth(OPTIONS_PANEL_WIDTH + 12)
    tip:Hide()

    if tip.TitleText then
        tip.TitleText:SetText("Combat Details")
        tip.TitleText:Show()
    end
    local tipName = tip.GetName and tip:GetName() or nil
    local close = tip.CloseButton or (tipName and _G[tipName .. "CloseButton"]) or nil
    if close then
        close:Hide()
        close:SetAlpha(0)
        close:EnableMouse(false)
    end
    if tipName then
        local titleBg = _G[tipName .. "TitleBg"]
        if titleBg then
            titleBg:ClearAllPoints()
            titleBg:SetPoint("TOPLEFT", tip, "TOPLEFT", 2, -3)
            titleBg:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -2, -3)
        end
    end

    local content = CreateFrame("Frame", nil, tip, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -6, 6)
    tip.content = content

    local function makeRow(labelText)
        local row = CreateFrame("Frame", nil, content)
        row:SetWidth(OPTIONS_PANEL_WIDTH - 16)
        local label = createLabel(row, labelText, "GameFontNormalSmall")
        styleOptionsControlLabel(label)
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetWidth(70)
        local value = createLabel(row, "", "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT", label, "TOPRIGHT", 6, 0)
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        value:SetJustifyH("LEFT")
        value:SetJustifyV("TOP")
        value:SetWordWrap(true)
        row.label = label
        row.value = value
        return row
    end

    tip.rowTime = makeRow("Time:")
    tip.rowSource = makeRow("Source:")
    tip.rowTarget = makeRow("Target:")
    tip.rowAmount = makeRow("Amount:")
    tip.rowOverheal = makeRow("Overheal:")
    tip.rowDot = makeRow("DOT:")
    tip.rowAbility = makeRow("Ability:")

    tip.divider = content:CreateTexture(nil, "BORDER")
    tip.divider:SetHeight(8)
    tip.divider:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    tip.divider:SetTexCoord(0.81, 0.94, 0.5, 1)
    tip.divider:Hide()

    UI.combatRowTooltip = tip
    return tip
end

local function showCombatRowTooltip(entry)
    if not entry or entry.kind == "BREAK" then
        hideCombatRowTooltip()
        return
    end
    local tip = ensureCombatRowTooltip()
    if not tip then
        return
    end
    local anchor = UI and UI.frame or UIParent
    tip:ClearAllPoints()
    tip:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -10, -30)

    local kind = entry.kind or "DAMAGE"
    local sourceName = ""
    local targetName = ""
    if kind == "DAMAGE" then
        sourceName = entry.source or "Unknown"
        targetName = entry.player or "Unknown"
    elseif kind == "DAMAGE_OUT" then
        sourceName = entry.player or "Unknown"
        targetName = entry.source or "Unknown"
    elseif kind == "HEAL" then
        sourceName = entry.source or "Unknown"
        targetName = entry.player or "Unknown"
    elseif kind == "HEAL_OUT" then
        sourceName = entry.player or "Unknown"
        targetName = entry.source or "Unknown"
    elseif kind == "RES" then
        sourceName = entry.source or "Unknown"
        targetName = entry.player or "Unknown"
    elseif kind == "DEATH" then
        sourceName = ""
        targetName = entry.player or "Unknown"
    end

    local amount = math.floor(tonumber(entry.amount) or 0)
    local overheal = math.floor(tonumber(entry.overheal) or 0)
    local isHeal = (kind == "HEAL" or kind == "HEAL_OUT" or kind == "RES")
    local amountText = isHeal and string.format("+%d", amount) or string.format("-%d", amount)
    if kind == "DEATH" then
        amountText = "Died"
    elseif kind == "RES" then
        if amount > 0 then
            amountText = string.format("Revived +%d", amount)
        else
            amountText = "Revived"
        end
    end

    local abilityText = entry.spell or "Unknown"
    if entry.spellDuration and entry.spellDuration > 1 then
        abilityText = string.format("%s (%ds)", abilityText, entry.spellDuration)
    end

    local rows = {}
    local function setRow(row, text, r, g, b)
        row.value:SetText(text)
        if row.value.SetTextColor and r then
            row.value:SetTextColor(r, g or r, b or r, 1)
        end
        row:Show()
        table.insert(rows, row)
    end

    setRow(tip.rowTime, formatCombatTimestamp(entry.ts), 1, 1, 1)

    local sourceColorR, sourceColorG, sourceColorB = 1, 1, 1
    local targetColorR, targetColorG, targetColorB = 1, 1, 1
    if kind == "DAMAGE" then
        sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
        targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
    elseif kind == "DAMAGE_OUT" then
        sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
        targetColorR, targetColorG, targetColorB = getSourceColor(entry)
    elseif kind == "HEAL" or kind == "HEAL_OUT" then
        sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
        targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
    elseif kind == "RES" then
        sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
        targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
    elseif kind == "DEATH" then
        targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
    end

    setRow(tip.rowSource, sourceName ~= "" and sourceName or "None", sourceColorR, sourceColorG, sourceColorB)
    setRow(tip.rowTarget, targetName ~= "" and targetName or "None", targetColorR, targetColorG, targetColorB)

    local amountColor = DAMAGE_COLOR
    if kind == "HEAL" or kind == "HEAL_OUT" then
        amountColor = HEAL_COLOR
    elseif kind == "RES" then
        amountColor = REVIVE_COLOR
    elseif kind == "DEATH" then
        amountColor = DEATH_COLOR
    end
    setRow(tip.rowAmount, amountText, amountColor[1], amountColor[2], amountColor[3])

    if kind == "HEAL" or kind == "HEAL_OUT" then
        setRow(tip.rowOverheal, tostring(overheal), 0.55, 0.9, 0.55)
    else
        tip.rowOverheal:Hide()
    end

    setRow(tip.rowAbility, abilityText, 1, 1, 1)

    local content = tip.content or tip
    local y = -8
    for _, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
        row:SetPoint("RIGHT", content, "RIGHT", -8, 0)
        local height = math.max(row.label:GetStringHeight() or 12, row.value:GetStringHeight() or 12)
        y = y - (height + 6)
    end
    tip.divider:ClearAllPoints()
    tip.divider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y + 2)
    tip.divider:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    tip.divider:Show()
    local contentHeight = math.max(36, -y + 10)
    content:SetHeight(contentHeight)
    tip:SetHeight(contentHeight + 30)
    tip:Show()

    local spellId = entry.spellId or nil
    if spellId and GameTooltip then
        GameTooltip:Hide()
        GameTooltip:SetOwner(tip, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -4)
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spellId)
        elseif GameTooltip.SetHyperlink then
            GameTooltip:SetHyperlink("spell:" .. tostring(spellId))
        end
        GameTooltip:Show()
    end
end

local function setCombatRowTooltipLock(entry, locked)
    if not UI then
        return
    end
    UI.combatTooltipLocked = locked and true or false
    UI.combatTooltipEntry = locked and entry or nil
end

local function createSmallIconButton(parent, size, texture)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetText("")
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetDrawLayer("OVERLAY")
    icon:SetAllPoints(btn)
    icon:SetTexture(texture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    return btn
end

local function bindLiveSearch(editBox, callback, delay)
    if not editBox or not callback then
        return
    end
    editBox._liveSearchDelay = delay or 0.15
    editBox._liveSearchElapsed = 0
    editBox._liveSearchPending = false
    editBox._liveSearchLastText = nil
    editBox:SetScript("OnUpdate", function(selfBox, elapsed)
        if not selfBox._liveSearchPending then
            return
        end
        selfBox._liveSearchElapsed = selfBox._liveSearchElapsed + (elapsed or 0)
        if selfBox._liveSearchElapsed < selfBox._liveSearchDelay then
            return
        end
        selfBox._liveSearchElapsed = 0
        selfBox._liveSearchPending = false
        local text = selfBox:GetText() or ""
        if text ~= selfBox._liveSearchLastText then
            selfBox._liveSearchLastText = text
            callback()
        end
    end)
    editBox:SetScript("OnTextChanged", function(selfBox)
        selfBox._liveSearchPending = true
        selfBox._liveSearchElapsed = 0
    end)
end

function UI:GetAllPlayerNames()
    local names = {}
    local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
    for name in pairs(players) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function UI:GetPresentPlayerNames()
    local present = Goals:GetPresenceMap()
    local names = {}
    for name in pairs(present) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

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

function UI:GetDamageTrackerDropdownList()
    return {
        COMBAT_SHOW_ALL,
        COMBAT_SHOW_BOSS,
        COMBAT_SHOW_TRASH,
    }
end

function UI:GetDisenchanterCandidates()
    local list = self:GetPresentPlayerNames()
    table.insert(list, 1, L.NONE_OPTION)
    return list
end

function UI:GetDisenchanterStatus()
    local current = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
    if current == "" then
        return "None set"
    end
    local present = Goals:GetPresenceMap()
    if not present[current] then
        return "Not present"
    end
    return colorizeName(current)
end

function UI:GetSortedPlayers()
    local list = {}
    local playerMap = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players)
    if not playerMap then
        return list
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    local present = Goals:GetPresenceMap()
    local showPresentOnly = overviewSettings.showPresentOnly
    for name, data in pairs(playerMap) do
        local isPresent = present[name] or false
        if not showPresentOnly or isPresent then
            table.insert(list, {
                name = name,
                points = data.points or 0,
                class = data.class,
                present = isPresent,
            })
        end
    end
    local mode = overviewSettings.sortMode or "POINTS"
    table.sort(list, function(a, b)
        if mode == "ALPHA" then
            return a.name < b.name
        end
        if mode == "PRESENCE" then
            if a.present ~= b.present then
                return a.present and not b.present
            end
            if a.points ~= b.points then
                return a.points > b.points
            end
            return a.name < b.name
        end
        if a.points ~= b.points then
            return a.points > b.points
        end
        return a.name < b.name
    end)
    return list
end

function UI:GetLootHistoryEntries()
    local list = {}
    if not Goals.db or not Goals.db.history then
        return list
    end
    local minQuality = Goals.db.settings and Goals.db.settings.lootHistoryMinQuality or 0
    local hiddenBefore = Goals.db.settings and Goals.db.settings.lootHistoryHiddenBefore or 0
    for _, entry in ipairs(Goals.db.history) do
        if entry.kind == "LOOT_FOUND" or entry.kind == "LOOT_ASSIGN" then
            local include = true
            if hiddenBefore > 0 and (entry.ts or 0) <= hiddenBefore then
                include = false
            end
            if include and minQuality > 0 then
                local itemLink = entry.data and entry.data.item or nil
                if itemLink and GetItemInfo then
                    local quality = select(3, GetItemInfo(itemLink))
                    if quality and quality < minQuality then
                        include = false
                    end
                end
            end
            if include then
                table.insert(list, entry)
            end
        end
    end
    return list
end

local function getLootNoteKey(itemLink, ts)
    if not itemLink or itemLink == "" then
        return nil
    end
    return tostring(itemLink) .. "|" .. tostring(ts or 0)
end

function UI:GetLootNote(key)
    if not key or not Goals.db or not Goals.db.lootNotes then
        return nil
    end
    return Goals.db.lootNotes[key]
end

function UI:SetLootNote(key, text)
    if not key or not Goals.db then
        return
    end
    Goals.db.lootNotes = Goals.db.lootNotes or {}
    local noteText = text or ""
    if noteText == "" then
        Goals.db.lootNotes[key] = nil
        return
    end
    local author = Goals.GetPlayerName and Goals:GetPlayerName() or ""
    Goals.db.lootNotes[key] = {
        note = noteText,
        author = author,
        ts = time(),
    }
end

function UI:GetLootTableEntries()
    local list = {}
    local history = self:GetLootHistoryEntries()
    local foundByLink = {}
    local seenFound = {}
    local foundIndexByKey = {}
    local LOOT_GROUP_WINDOW = 15
    local LOOT_ASSIGN_MERGE_WINDOW = 3600

    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_FOUND" then
            local itemLink = entry.data and entry.data.item or nil
            if itemLink and itemLink ~= "" then
                foundByLink[itemLink] = foundByLink[itemLink] or {}
                table.insert(foundByLink[itemLink], {
                    entry = entry,
                    key = getLootNoteKey(itemLink, entry.ts),
                })
            end
        end
    end

    for _, entries in pairs(foundByLink) do
        table.sort(entries, function(a, b)
            return (a.entry.ts or 0) < (b.entry.ts or 0)
        end)
    end

    local function markFoundUsed(foundEntry)
        if not foundEntry then
            return
        end
        seenFound[foundEntry.key or ""] = true
    end

    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_ASSIGN" then
            local dataEntry = entry.data or {}
            local itemLink = dataEntry.item or ""
            local matched = nil
            local listForLink = foundByLink[itemLink]
            if listForLink then
                for i = #listForLink, 1, -1 do
                    local candidate = listForLink[i]
                    if (candidate.entry.ts or 0) <= (entry.ts or 0) then
                        matched = candidate
                        table.remove(listForLink, i)
                        break
                    end
                end
            end
            if matched and ((entry.ts or 0) - (matched.entry.ts or 0) <= LOOT_ASSIGN_MERGE_WINDOW) then
                markFoundUsed(matched)
                local playerName = dataEntry.player or ""
                local players = dataEntry.players
                local noteKey = matched.key or getLootNoteKey(itemLink, matched.entry.ts or entry.ts)
                table.insert(list, {
                    kind = "FOUND",
                    ts = matched.entry.ts or entry.ts,
                    item = itemLink,
                    slot = nil,
                    raw = nil,
                    assignedTo = playerName,
                    assignedCount = (players and #players) or nil,
                    assignedPlayers = players,
                    reset = dataEntry.reset,
                    resetBefore = dataEntry.resetBefore,
                    noteKey = noteKey,
                })
                if noteKey then
                    foundIndexByKey[noteKey] = #list
                end
            else
                entry.noteKey = getLootNoteKey(itemLink, entry.ts)
                table.insert(list, entry)
            end
        end
    end

    local remainingByLink = {}
    for _, entry in ipairs(history) do
        if entry.kind == "LOOT_FOUND" then
            local itemLink = entry.data and entry.data.item or nil
            local key = getLootNoteKey(itemLink, entry.ts)
            if key and not seenFound[key] then
                remainingByLink[itemLink] = remainingByLink[itemLink] or {}
                table.insert(remainingByLink[itemLink], { entry = entry, key = key })
            end
        end
    end

    for itemLink, entries in pairs(remainingByLink) do
        table.sort(entries, function(a, b)
            return (a.entry.ts or 0) < (b.entry.ts or 0)
        end)
        local groupCount = 0
        local groupLast = 0
        local groupFirst = 0
        local groupKey = nil
        local function flushGroup()
            if groupCount <= 0 then
                return
            end
            local noteKey = groupKey or getLootNoteKey(itemLink, groupLast)
            table.insert(list, {
                kind = "FOUND",
                ts = groupLast,
                item = itemLink,
                slot = nil,
                raw = nil,
                noteKey = noteKey,
                stackCount = groupCount,
            })
            if noteKey then
                foundIndexByKey[noteKey] = #list
            end
            groupCount = 0
            groupLast = 0
            groupFirst = 0
            groupKey = nil
        end
        for _, wrapper in ipairs(entries) do
            local ts = wrapper.entry.ts or 0
            if groupCount == 0 then
                groupCount = 1
                groupFirst = ts
                groupLast = ts
                groupKey = wrapper.key
            elseif ts - groupLast <= LOOT_GROUP_WINDOW then
                groupCount = groupCount + 1
                groupLast = ts
                groupKey = wrapper.key
            else
                flushGroup()
                groupCount = 1
                groupFirst = ts
                groupLast = ts
                groupKey = wrapper.key
            end
        end
        flushGroup()
    end

    if Goals and Goals.GetFoundLoot then
        local found = Goals:GetFoundLoot() or {}
        for _, entry in ipairs(found) do
            if entry and entry.link then
                local key = getLootNoteKey(entry.link, entry.ts)
                local matched = nil
                local listForLink = foundByLink[entry.link]
                if listForLink and #listForLink > 0 then
                    local bestIndex = nil
                    local bestDiff = nil
                    for i = #listForLink, 1, -1 do
                        local candidate = listForLink[i]
                        local diff = math.abs((candidate.entry.ts or 0) - (entry.ts or 0))
                        if diff <= 120 and (not bestDiff or diff < bestDiff) then
                            bestDiff = diff
                            bestIndex = i
                        end
                    end
                    if bestIndex then
                        matched = listForLink[bestIndex]
                        table.remove(listForLink, bestIndex)
                        key = matched.key or key
                        markFoundUsed(matched)
                    end
                end
                local existingIndex = key and foundIndexByKey[key] or nil
                if existingIndex then
                    local existing = list[existingIndex]
                    existing.raw = entry
                    existing.slot = entry.slot
                    existing.assignedTo = entry.assignedTo
                elseif key and not seenFound[key] then
                    table.insert(list, {
                        kind = "FOUND",
                        ts = entry.ts,
                        item = entry.link,
                        slot = entry.slot,
                        raw = entry,
                        assignedTo = entry.assignedTo,
                        noteKey = key,
                    })
                    foundIndexByKey[key] = #list
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return (a.ts or 0) > (b.ts or 0)
    end)

    return list
end

local function getHistoryFilterValue(settings, key)
    if not settings then
        return true
    end
    local value = settings[key]
    if value == nil then
        return true
    end
    return value
end

local function getHistoryItemLink(entry)
    local data = entry and entry.data or nil
    if not data then
        return nil
    end
    if data.item and data.item ~= "" then
        return data.item
    end
    if data.itemId and Goals and Goals.CacheItemById then
        local cached = Goals:CacheItemById(data.itemId)
        if cached and cached.link then
            return cached.link
        end
    end
    return nil
end

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

function UI:SetupDropdown(dropdown, getList, onSelect, fallbackText)
    dropdown.getList = getList
    dropdown.onSelect = onSelect
    dropdown.fallbackText = fallbackText or L.SELECT_OPTION
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local list = dropdown.getList and dropdown.getList() or {}
        local info
        if #list == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = L.LABEL_NO_PLAYERS
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, name in ipairs(list) do
            info = UIDropDownMenu_CreateInfo()
            if dropdown.colorize and name ~= L.NONE_OPTION then
                info.text = colorizeName(name)
            else
                info.text = name
            end
            info.value = name
            info.func = function()
                dropdown.selectedValue = name
                UIDropDownMenu_SetSelectedValue(dropdown, name)
                if dropdown.colorize and name ~= L.NONE_OPTION then
                    UIDropDownMenu_SetText(dropdown, colorizeName(name))
                else
                    UIDropDownMenu_SetText(dropdown, name)
                end
                if dropdown.onSelect then
                    dropdown.onSelect(name)
                end
            end
            info.checked = dropdown.selectedValue == name
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function UI:SetDropdownText(dropdown, text)
    local value = text or dropdown.fallbackText or L.SELECT_OPTION
    if dropdown.colorize and value ~= L.NONE_OPTION and value ~= dropdown.fallbackText then
        UIDropDownMenu_SetText(dropdown, colorizeName(value))
    else
        UIDropDownMenu_SetText(dropdown, value)
    end
end

function UI:SetupSortDropdown(dropdown)
    self.sortOptions = {
        { text = L.SORT_POINTS, value = "POINTS" },
        { text = L.SORT_ALPHA, value = "ALPHA" },
        { text = L.SORT_PRESENCE, value = "PRESENCE" },
    }
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(self.sortOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
                overviewSettings.sortMode = option.value
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                UIDropDownMenu_SetText(dropdown, option.text)
                Goals:NotifyDataChanged()
            end
            local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
            info.checked = overviewSettings.sortMode == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self:SyncSortDropdown()
end

function UI:SyncSortDropdown()
    if not self.sortDropdown then
        return
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    local selected = overviewSettings.sortMode or "POINTS"
    local text = L.SORT_POINTS
    if self.sortOptions then
        for _, option in ipairs(self.sortOptions) do
            if option.value == selected then
                text = option.text
                break
            end
        end
    end
    UIDropDownMenu_SetSelectedValue(self.sortDropdown, selected)
    UIDropDownMenu_SetText(self.sortDropdown, text)
end

function UI:SetupResetQualityDropdown(dropdown)
    dropdown.options = getQualityOptions()
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(dropdown.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals:SetRaidSetting("resetMinQuality", option.value)
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                UIDropDownMenu_SetText(dropdown, option.text)
            end
            info.checked = (Goals.db.settings.resetMinQuality or 4) == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self:SyncResetQualityDropdown()
end

function UI:SyncResetQualityDropdown()
    if not self.resetQualityDropdown then
        return
    end
    local value = Goals.db.settings.resetMinQuality or 4
    UIDropDownMenu_SetSelectedValue(self.resetQualityDropdown, value)
    UIDropDownMenu_SetText(self.resetQualityDropdown, getQualityLabel(value))
end

function UI:ShowBuildSharePrompt()
    setupBuildSharePopup()
    if StaticPopup_Show then
        StaticPopup_Show("GOALS_BUILD_SHARE")
    end
end

function UI:ShowOverviewMigrationPrompt()
    local frame = ensureOverviewMigrationPrompt()
    if not frame then
        return
    end
    if frame.content then
        frame.content:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
        frame.content:SetAlpha(1)
    end
    ensureOverviewMigrationPromptWidgets(frame)
    if self.frame and self.frame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    layoutOverviewMigrationPrompt(frame)
    frame:Show()
    layoutOverviewMigrationPrompt(frame)
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

local function ensureBuildShareTooltip()
    if not UI or not UI.frame then
        return nil
    end
    if UI.buildShareTooltip then
        return UI.buildShareTooltip
    end
    local tip = CreateFrame("Frame", "GoalsBuildShareTooltip", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(tip)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    tip:SetWidth(OPTIONS_PANEL_WIDTH + 12)
    tip:Hide()

    if tip.TitleText then
        tip.TitleText:SetText("Send Build")
        tip.TitleText:Show()
    end
    local tipName = tip.GetName and tip:GetName() or nil
    local close = tip.CloseButton or (tipName and _G[tipName .. "CloseButton"]) or nil
    if close then
        close:Hide()
        close:SetAlpha(0)
        close:EnableMouse(false)
    end
    if tipName then
        local titleBg = _G[tipName .. "TitleBg"]
        if titleBg then
            titleBg:ClearAllPoints()
            titleBg:SetPoint("TOPLEFT", tip, "TOPLEFT", 2, -3)
            titleBg:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -2, -3)
        end
    end

    local content = CreateFrame("Frame", nil, tip, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -6, 6)
    tip.content = content

    local label = createLabel(content, "", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -4)
    label:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -4)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    tip.text = label

    UI.buildShareTooltip = tip
    return tip
end

local function ensureBuildPreviewTooltip()
    if not UI or not UI.frame then
        return nil
    end
    if UI.buildPreviewTooltip then
        return UI.buildPreviewTooltip
    end
    local tip = CreateFrame("Frame", "GoalsBuildPreviewTooltip", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(tip)
    tip:SetFrameStrata("HIGH")
    tip:SetClampedToScreen(true)
    tip:SetWidth(OPTIONS_PANEL_WIDTH + 12)
    tip:Hide()

    if tip.TitleText then
        tip.TitleText:SetText("Build Preview")
        tip.TitleText:Show()
    end
    local tipName = tip.GetName and tip:GetName() or nil
    local close = tip.CloseButton or (tipName and _G[tipName .. "CloseButton"]) or nil
    if close then
        close:Hide()
        close:SetAlpha(0)
        close:EnableMouse(false)
    end
    if tipName then
        local titleBg = _G[tipName .. "TitleBg"]
        if titleBg then
            titleBg:ClearAllPoints()
            titleBg:SetPoint("TOPLEFT", tip, "TOPLEFT", 2, -3)
            titleBg:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -2, -3)
        end
    end

    local content = CreateFrame("Frame", nil, tip, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", tip, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -6, 6)
    tip.content = content
    tip.rows = {}
    tip.rowHeight = ROW_HEIGHT

    local buildName = createLabel(content, "", "GameFontHighlightSmall")
    buildName:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -4)
    buildName:SetJustifyH("LEFT")
    buildName:SetWordWrap(true)
    if buildName.SetNonSpaceWrap then
        buildName:SetNonSpaceWrap(true)
    end
    tip.buildNameText = buildName

    local buildMeta = createLabel(content, "", "GameFontHighlightSmall")
    buildMeta:SetJustifyH("LEFT")
    buildMeta:SetWordWrap(true)
    tip.buildMetaText = buildMeta

    local buildTierText = createLabel(content, "", "GameFontHighlightSmall")
    buildTierText:SetJustifyH("LEFT")
    buildTierText:SetWordWrap(true)
    tip.buildTierText = buildTierText

    local expansionBadge = createBadge(content)
    local tierBadge = createBadge(content)
    tip.expansionBadge = expansionBadge
    tip.tierBadge = tierBadge

    local refresh = CreateFrame("Button", nil, tip, "UIPanelButtonTemplate")
    refresh:SetText("Refresh")
    refresh:SetSize(64, 18)
    refresh:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -30, -6)
    refresh:SetScript("OnClick", function()
        if UI and UI.RefreshBuildPreviewItems then
            UI:RefreshBuildPreviewItems()
        end
    end)
    refresh:Hide()
    refresh:SetAlpha(0)
    refresh:EnableMouse(false)
    tip.refreshButton = refresh

    local notesHeaderLabel, notesHeaderFrame = createOptionsHeader(content, "Notes", 0)
    tip.notesHeader = notesHeaderLabel
    tip.notesHeaderFrame = notesHeaderFrame

    local notesText = createLabel(content, "", "GameFontHighlightSmall")
    notesText:SetJustifyH("LEFT")
    notesText:SetWordWrap(true)
    if notesText.SetJustifyV then
        notesText:SetJustifyV("TOP")
    end
    if notesText.SetNonSpaceWrap then
        notesText:SetNonSpaceWrap(true)
    end
    if notesText.SetMaxLines then
        notesText:SetMaxLines(0)
    end
    tip.notesText = notesText

    local sourcesHeaderLabel, sourcesHeaderFrame = createOptionsHeader(content, "Sources", 0)
    tip.sourcesLabel = sourcesHeaderLabel
    tip.sourcesHeaderFrame = sourcesHeaderFrame

    local sourcesFrame = CreateFrame("Frame", nil, content)
    sourcesFrame:SetHeight(16)
    tip.sourcesFrame = sourcesFrame
    tip.sourceIcons = {}

    UI.buildPreviewTooltip = tip
    return tip
end

local function buildPreviewEntries(build)
    local entries = {}
    if not build then
        return entries
    end
    if type(build.itemsBySlot) == "table" then
        for slotKey, entry in pairs(build.itemsBySlot) do
            if entry and entry.itemId then
                entries[#entries + 1] = {slotKey = slotKey, itemId = entry.itemId, notes = entry.notes}
            end
        end
    elseif type(build.items) == "table" then
        for _, entry in ipairs(build.items) do
            if entry and entry.slotKey and entry.itemId then
                entries[#entries + 1] = {slotKey = entry.slotKey, itemId = entry.itemId, notes = entry.notes}
            end
        end
    elseif build.wishlist and Goals.DeserializeWishlist then
        local data = Goals:DeserializeWishlist(build.wishlist)
        if data and data.items then
            for slotKey, entry in pairs(data.items) do
                if entry and entry.itemId then
                    entries[#entries + 1] = {slotKey = slotKey, itemId = entry.itemId, notes = entry.notes}
                end
            end
        end
    end
    local slotOrder = {}
    local slotDefs = Goals.GetWishlistSlotDefs and Goals:GetWishlistSlotDefs() or {}
    for i, def in ipairs(slotDefs) do
        slotOrder[def.key] = i
    end
    table.sort(entries, function(a, b)
        local ai = slotOrder[a.slotKey] or 999
        local bi = slotOrder[b.slotKey] or 999
        if ai == bi then
            return (a.slotKey or "") < (b.slotKey or "")
        end
        return ai < bi
    end)
    return entries
end

showBuildPreviewTooltip = function(build)
    if not UI or not UI.frame then
        return
    end
    UI.selectedWishlistBuild = build
    UI.previewBuildEntries = buildPreviewEntries(build)
    if UI.UpdateBuildPreviewTooltip then
        UI:UpdateBuildPreviewTooltip()
    end
end

hideBuildPreviewTooltip = function()
    if UI and UI.buildPreviewTooltip then
        UI.buildPreviewTooltip:Hide()
        UI.buildPreviewTooltip.pendingPreviewRefresh = nil
        UI.buildPreviewTooltip.previewRefreshAttempts = nil
    end
    if UI then
        UI.previewBuildEntries = nil
        UI.selectedWishlistBuild = nil
    end
end

local function showBuildShareTooltip(text)
    local tip = ensureBuildShareTooltip()
    if not tip then
        return
    end
    tip.text:SetText(text or "")
    local height = (tip.text.GetStringHeight and tip.text:GetStringHeight() or 16) + 34
    tip:SetHeight(height)
    tip:ClearAllPoints()
    if UI and UI.buildPreviewTooltip and UI.buildPreviewTooltip:IsShown() then
        local left = UI.buildPreviewTooltip:GetLeft()
        local bottom = UI.buildPreviewTooltip:GetBottom()
        if left and bottom then
            tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom - 6)
        else
            tip:SetPoint("TOPLEFT", UI.buildPreviewTooltip, "BOTTOMLEFT", 0, -6)
        end
    else
        tip:SetPoint("TOPLEFT", UI.frame, "TOPRIGHT", 10, -30)
    end
    tip:Show()
end

local function hideBuildShareTooltip()
    if UI and UI.buildShareTooltip then
        UI.buildShareTooltip:Hide()
    end
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

function UI:Init()
    if self.frame then
        return
    end
    self:CreateMainFrame()
    self:CreateMinimapButton()
    self:CreateFloatingButton()
    self:CreateMiniTracker()
    self:CreateMiniFloatingButton()
    self:CreateOptionsPanel()
    self:UpdateMinimapButton()
    self:Refresh()
end

function UI:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
        if self.combatBroadcastPopout and self.combatBroadcastPopout:IsShown() then
            self.combatBroadcastPopout:Hide()
        end
        if Goals.db and Goals.db.settings and Goals.db.settings.floatingButton and Goals.db.settings.floatingButton.show then
            self:ShowFloatingButton(true)
        end
        return
    end
    self.frame:Show()
    self:ShowFloatingButton(false)
    self:Refresh()
end

function UI:Minimize()
    if not self.frame then
        return
    end
    self.frame:Hide()
    if self.combatBroadcastPopout and self.combatBroadcastPopout:IsShown() then
        self.combatBroadcastPopout:Hide()
    end
    if Goals.db and Goals.db.settings and Goals.db.settings.floatingButton then
        Goals.db.settings.floatingButton.show = true
    end
    self:ShowFloatingButton(true)
end

function UI:ShowFloatingButton(show)
    if not self.floatingButton then
        return
    end
    if show then
        self.floatingButton:Show()
    else
        self.floatingButton:Hide()
    end
end

local function registerSpecialFrame(name)
    if not name then
        return
    end
    if not UISpecialFrames then
        UISpecialFrames = {}
    end
    for _, existing in ipairs(UISpecialFrames) do
        if existing == name then
            return
        end
    end
    table.insert(UISpecialFrames, name)
end

function UI:CreateMainFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "GoalsMainFrame", UIParent, "GoalsFrameTemplate")
    frame:SetSize(900, MAIN_FRAME_HEIGHT + FOOTER_BAR_EXTRA)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    applyFrameTheme(frame)

    local titleText = frame.TitleText
    if not titleText then
        titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    local version = Goals and Goals.GetDisplayVersion and Goals:GetDisplayVersion() or nil
    if version then
        titleText:SetText(string.format("GOALS v%s - By: ErebusAres", tostring(version)))
    else
        titleText:SetText(L.TITLE)
    end
    titleText:ClearAllPoints()
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -6)
    titleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -70, -6)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(THEME.titleText[1], THEME.titleText[2], THEME.titleText[3], THEME.titleText[4])
    frame.titleText = titleText

    local close = _G[frame:GetName() .. "CloseButton"]
    if close then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    frame:SetScript("OnHide", function()
        if UI and UI.combatBroadcastPopout and UI.combatBroadcastPopout:IsShown() then
            UI.combatBroadcastPopout:Hide()
        end
        if hideBuildPreviewTooltip then
            hideBuildPreviewTooltip()
        end
    end)

    registerSpecialFrame(frame:GetName())

    local minimize = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    if close then
        minimize:SetSize(close:GetWidth(), close:GetHeight())
        minimize:SetFrameLevel(close:GetFrameLevel() + 1)
    else
        minimize:SetSize(24, 24)
    end
    minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-HideButton-Highlight", "ADD")
    minimize:SetAlpha(1)
    if close then
        minimize:ClearAllPoints()
        minimize:SetPoint("TOPRIGHT", close, "TOPLEFT", 7, 0)
    else
        minimize:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -5)
    end
    minimize:SetScript("OnClick", function()
        UI:Minimize()
    end)
    frame.minimize = minimize

    self.frame = frame
    self.tabs = {}
    self.pages = {}

    local tabBar = CreateFrame("Frame", "GoalsMainTabBar", frame)
    tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
    tabBar:SetHeight(24)
    local tabBg = tabBar:CreateTexture(nil, "BORDER")
    tabBg:SetAllPoints(tabBar)
    tabBg:SetTexture(0, 0, 0, 0.45)
    self.tabBar = tabBar
    local tabLine = frame:CreateTexture(nil, "BORDER")
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -1)
    tabLine:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -1)
    tabLine:SetTexture(1, 1, 1, 0.08)
    self.tabBarLine = tabLine

    local tabDefs = {
        { key = "overview", text = L.TAB_OVERVIEW, create = "CreateOverviewTab" },
        { key = "loot", text = L.TAB_LOOT, create = "CreateLootTab" },
        { key = "history", text = L.TAB_HISTORY, create = "CreateHistoryTab" },
        { key = "wishlist", text = L.TAB_WISHLIST, create = "CreateWishlistTab" },
        { key = "damage", text = L.TAB_DAMAGE_TRACKER, create = "CreateDamageTrackerTab" },
    }
    if self:ShouldShowUpdateTab() then
        table.insert(tabDefs, { key = "update", text = L.TAB_UPDATE, create = "CreateUpdateTab" })
    end
    if Goals.Dev and Goals.Dev.enabled then
        table.insert(tabDefs, { key = "dev", text = L.TAB_DEV, create = "CreateDevTab" })
        table.insert(tabDefs, { key = "debug", text = L.TAB_DEBUG, create = "CreateDebugTab" })
    end
    -- Help tab removed; tooltips provide guidance inline.

    for i, def in ipairs(tabDefs) do
        local tabName = frame:GetName() .. "Tab" .. i
        local tab = CreateFrame("Button", tabName, tabBar, "OptionsFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetHeight(24)
        tab:SetText(def.text)
        PanelTemplates_TabResize(tab, 8)
        tab:SetScript("OnClick", function()
            UI:SelectTab(i)
        end)
        if i == 1 then
            tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
        else
            tab:SetPoint("TOPLEFT", self.tabs[i - 1], "TOPRIGHT", 0, 0)
        end
        if def.key == "update" then
            self.updateTab = tab
            self.updateTabId = i
        end
        if def.key == "loot" then
            self.lootTabId = i
        end
        if def.key == "history" then
            self.historyTabId = i
        end
        if def.key == "wishlist" then
            self.wishlistTabId = i
        end
        if def.key == "damage" then
            self.damageTab = tab
            self.damageTabId = i
        end
        if def.key == "dev" then
            self.devTab = tab
        end
        if def.key == "debug" then
            self.debugTab = tab
        end
        self.tabs[i] = tab

        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 2, -6)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, PAGE_BOTTOM_OFFSET + FOOTER_BAR_EXTRA)
        page:Hide()
        self.pages[i] = page
        page.footer = createTabFooter(self, page, def.key)
        page.footer2 = createTabFooter2(self, page, def.key, page.footer)

        local createFunc = self[def.create]
        if createFunc then
            createFunc(self, page)
        end
    end

    PanelTemplates_SetNumTabs(frame, #tabDefs)
    PanelTemplates_SetTab(frame, 1)
    self:SelectTab(1)
    self:UpdateUpdateTabGlow()
    self:LayoutTabs()
    self:UpdateDamageTabVisibility()
end

function UI:LayoutTabs()
    if not self.frame or not self.tabs then
        return
    end
    local tabBar = self.tabBar or self.frame
    local previous = nil
    for _, tab in ipairs(self.tabs) do
        if tab ~= self.helpTab and tab:IsShown() then
            tab:ClearAllPoints()
            if not previous then
                tab:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
            else
                tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 0, 0)
            end
            previous = tab
        end
    end
    if self.helpTab then
        self.helpTab:ClearAllPoints()
        self.helpTab:SetPoint("TOPRIGHT", tabBar, "TOPRIGHT", 0, 0)
    end
end

function UI:UpdateDamageTabVisibility()
    if not self.damageTab or not self.damageTabId then
        return
    end
    local enabled = true
    setShown(self.damageTab, enabled)
    self:LayoutTabs()
end

local function getQualityLabel(quality)
    if not quality or quality <= 0 then
        return "Any"
    end
    local desc = _G["ITEM_QUALITY" .. tostring(quality) .. "_DESC"]
    if desc and desc ~= "" then
        return desc
    end
    return "Quality " .. tostring(quality)
end

local function getSortLabel(mode)
    if mode == "ALPHA" then
        return "Sort: Name"
    end
    if mode == "PRESENCE" then
        return "Sort: Presence"
    end
    return "Sort: Points"
end

local function getHistoryFilterSummary(settings)
    local filters = {
        { key = "historyFilterEncounter", label = "Encounters" },
        { key = "historyFilterPoints", label = "Points" },
        { key = "historyFilterBuild", label = "Builds" },
        { key = "historyFilterWishlistStatus", label = "Wishlist status" },
        { key = "historyFilterWishlistItems", label = "Wishlist items" },
        { key = "historyFilterLoot", label = "Loot" },
        { key = "historyFilterSync", label = "Sync" },
    }
    local enabled = {}
    for _, entry in ipairs(filters) do
        if getHistoryFilterValue(settings, entry.key) then
            table.insert(enabled, entry.label)
        end
    end
    if #enabled == 0 then
        return "Filters: None"
    end
    if #enabled == #filters then
        return "Filters: All"
    end
    if #enabled <= 3 then
        return "Filters: " .. table.concat(enabled, ", ")
    end
    return string.format("Filters: %d/%d", #enabled, #filters)
end

function UI:GetTopPointsSummary()
    if not self.GetSortedPlayers then
        return nil
    end
    local list = self:GetSortedPlayers()
    if #list == 0 then
        return nil
    end
    local topPoints = nil
    local topNames = {}
    for _, entry in ipairs(list) do
        local points = entry.points or 0
        if topPoints == nil or points > topPoints then
            topPoints = points
            topNames = { entry.name }
        elseif points == topPoints then
            table.insert(topNames, entry.name)
        end
    end
    if #topNames == 0 then
        return nil
    end
    table.sort(topNames)
    local displayName = colorizeName(topNames[1])
    if #topNames > 1 then
        displayName = string.format("%s +%d", displayName, #topNames - 1)
    end
    return string.format("Top: (%d) %s", topPoints, displayName)
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

function UI:NormalizeCombatShowFlags(settings)
    if not settings then
        return false, false, true
    end
    local mode = settings.combatLogViewMode
    if mode ~= COMBAT_SHOW_ALL and mode ~= COMBAT_SHOW_BOSS and mode ~= COMBAT_SHOW_TRASH then
        mode = COMBAT_SHOW_ALL
        settings.combatLogViewMode = mode
    end
    local showHealing = false
    local showDealt = false
    local showReceived = true
    settings.combatLogShowHealing = showHealing
    settings.combatLogShowDamageDealt = showDealt
    settings.combatLogShowDamageReceived = showReceived
    return showHealing, showDealt, showReceived
end

function UI:GetCombatShowMode(settings)
    settings = settings or (Goals and Goals.db and Goals.db.settings) or nil
    if not settings then
        return COMBAT_SHOW_ALL
    end
    local mode = settings.combatLogViewMode
    if mode == COMBAT_SHOW_BOSS or mode == COMBAT_SHOW_TRASH then
        return mode
    end
    settings.combatLogViewMode = COMBAT_SHOW_ALL
    return COMBAT_SHOW_ALL
end

function UI:SetCombatShowMode(mode, settings)
    settings = settings or (Goals and Goals.db and Goals.db.settings) or nil
    if not settings then
        return
    end
    if mode ~= COMBAT_SHOW_ALL and mode ~= COMBAT_SHOW_BOSS and mode ~= COMBAT_SHOW_TRASH then
        mode = COMBAT_SHOW_ALL
    end
    settings.combatLogViewMode = mode
    settings.combatLogShowHealing = false
    settings.combatLogShowDamageDealt = false
    settings.combatLogShowDamageReceived = true
end

function UI:GetCombatShowSummary(settings)
    local mode = self:GetCombatShowMode(settings)
    if mode == COMBAT_SHOW_ALL then
        return "Show: All"
    end
    return "Show: " .. mode
end

function UI:GetTabFooter2Segments(key)
    local settings = (Goals and Goals.db and Goals.db.settings) or {}
    if key == "overview" then
        local topText = self:GetTopPointsSummary()
        local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or settings or {}
        local sortText = getSortLabel(overviewSettings.sortMode)
        local presentText = overviewSettings.showPresentOnly and "Present only: On" or "Present only: Off"
        return topText, sortText, presentText
    end
    if key == "loot" then
        local minQuality = settings.lootHistoryMinQuality or 0
        local qualityText = "Min quality: " .. getQualityLabel(minQuality)
        local resetText = settings.resetRequiresLootWindow and "Mode: Manual" or "Mode: Auto"
        local count = self.GetLootHistoryEntries and #self:GetLootHistoryEntries() or 0
        local entriesText = "Entries: " .. tostring(count)
        return qualityText, resetText, entriesText
    end
    if key == "history" then
        local filtersText = getHistoryFilterSummary(settings)
        local count = self.GetHistoryEntries and #self:GetHistoryEntries() or 0
        local entriesText = "Entries: " .. tostring(count)
        return filtersText, nil, entriesText
    end
    if key == "wishlist" then
        local list = Goals.GetActiveWishlist and Goals:GetActiveWishlist() or nil
        local listName = list and list.name or "Wishlist"
        local listText = "List: " .. listName
        local tabLabel = self:GetWishlistTabLabel(self.wishlistActiveTab)
        local tabText = tabLabel and ("Tab: " .. tabLabel) or nil
        local alertsText = self:GetWishlistAlertsSummary(settings)
        return listText, tabText, alertsText
    end
    if key == "damage" then
        local filter = self.damageTrackerFilter or COMBAT_SHOW_ALL
        local filterText = "Filter: " .. tostring(filter)
        local showText = self:GetCombatShowSummary(settings)
        local threshold = settings.combatLogBigThreshold or 0
        local thresholdText = string.format("Threshold: %d%%", math.floor(threshold + 0.5))
        local rightText = thresholdText
        return filterText, showText, rightText
    end
    return nil, nil, nil
end

function UI:UpdateTabFooters()
    if not self.tabFooters then
        return
    end
    local access = getAccessStatus()
    local settings = Goals.db and Goals.db.settings or {}
    local localOnly = settings.localOnly and "Local only" or "Sync enabled"
    local syncFrom = "Unknown"
    if Goals and Goals.sync then
        if Goals.sync.isMaster then
            syncFrom = Goals.GetPlayerName and Goals:GetPlayerName() or "You"
        elseif Goals.sync.masterName and Goals.sync.masterName ~= "" then
            syncFrom = colorizeName(Goals.sync.masterName)
        end
    end
    local last = Goals and Goals.lastSyncReceivedAt or nil
    local lastText = "--:--:--"
    if last then
        local elapsed = math.max(0, time() - last)
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        lastText = string.format("%02d:%02d:%02d", hours, mins, secs)
    end
    local dis = self.GetDisenchanterStatus and self:GetDisenchanterStatus() or "None set"
    local rightText = string.format("Tracking: Enabled | Disenchanter: %s", dis)
    local leftText = string.format("%s | %s", access, localOnly)
    local centerText = string.format("Syncing From: %s | %s ago", syncFrom, lastText)

    for key, footer in pairs(self.tabFooters) do
        if footer.leftText then
            footer.leftText:SetText(leftText)
        end
        if footer.centerText then
            footer.centerText:SetText(centerText)
        end
        if footer.rightText then
            footer.rightText:SetText(rightText)
        end

        local footer2 = self.tabFooters2 and self.tabFooters2[key] or nil
        if footer2 then
            local left2, center2, right2 = self:GetTabFooter2Segments(key)
            local hasAny = (left2 and left2 ~= "") or (center2 and center2 ~= "") or (right2 and right2 ~= "")
            if footer2.leftText then
                footer2.leftText:SetText(left2 or "")
            end
            if footer2.centerText then
                footer2.centerText:SetText(center2 or "")
            end
            if footer2.rightText then
                footer2.rightText:SetText(right2 or "")
            end
            setShown(footer2, hasAny)

        end
    end
end

function UI:ShouldShowUpdateTab()
    if Goals and Goals.Dev and Goals.Dev.enabled then
        return true
    end
    return isUpdateAvailable()
end

function UI:SetupUpdateTabGlow(tab)
    if not tab or tab.glow then
        return
    end
    local glow = tab:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 15, 0)
    glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 15, 0)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.15, 0.15)
    glow:SetAlpha(1)
    glow:Hide()
    tab.glow = glow

    local anim = glow:CreateAnimationGroup()
    local fadeIn = anim:CreateAnimation("Alpha")
    if fadeIn and fadeIn.SetFromAlpha then
        fadeIn:SetFromAlpha(0.2)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.8)
        fadeIn:SetOrder(1)
    end
    local fadeOut = anim:CreateAnimation("Alpha")
    if fadeOut and fadeOut.SetFromAlpha then
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.2)
        fadeOut:SetDuration(0.8)
        fadeOut:SetOrder(2)
    end
    if anim.SetLooping then
        anim:SetLooping("REPEAT")
    end
    tab.glowAnim = anim

    local tabPulse = tab:CreateAnimationGroup()
    local tabIn = tabPulse:CreateAnimation("Alpha")
    if tabIn and tabIn.SetFromAlpha then
        tabIn:SetFromAlpha(0.6)
        tabIn:SetToAlpha(1)
        tabIn:SetDuration(0.8)
        tabIn:SetOrder(1)
    end
    local tabOut = tabPulse:CreateAnimation("Alpha")
    if tabOut and tabOut.SetFromAlpha then
        tabOut:SetFromAlpha(1)
        tabOut:SetToAlpha(0.6)
        tabOut:SetDuration(0.8)
        tabOut:SetOrder(2)
    end
    if tabPulse.SetLooping then
        tabPulse:SetLooping("REPEAT")
    end
    tab.tabPulse = tabPulse
end

function UI:UpdateUpdateTabGlow()
    if not self.updateTab then
        return
    end
    local available = isUpdateAvailable()
    local seenFlag = Goals and Goals.db and Goals.db.settings and Goals.db.settings.updateHasBeenSeen
    if available then
        self:SetupUpdateTabGlow(self.updateTab)
        if self.updateTab.glow then
            self.updateTab.glow:Show()
        end
        if not seenFlag then
            if self.updateTab.glowAnim then
                self.updateTab.glowAnim:Stop()
                self.updateTab.glowAnim:Play()
            end
            if self.updateTab.tabPulse then
                self.updateTab.tabPulse:Stop()
                self.updateTab.tabPulse:Play()
            end
        else
            if self.updateTab.glowAnim then
                self.updateTab.glowAnim:Stop()
            end
            if self.updateTab.tabPulse then
                self.updateTab.tabPulse:Stop()
                self.updateTab:SetAlpha(1)
            end
        end
    else
        if self.updateTab.glowAnim then
            self.updateTab.glowAnim:Stop()
        end
        if self.updateTab.glow then
            self.updateTab.glow:Hide()
        end
        if self.updateTab.tabPulse then
            self.updateTab.tabPulse:Stop()
            self.updateTab:SetAlpha(1)
        end
    end
end

function UI:RefreshUpdateTab()
    if not self.updateStatusText or not self.updateVersionText or not self.updateUrlText then
        return
    end
    local installedMajor, installedMinor, availableMajor, availableMinor, updateUrl = getUpdateInfo()
    local installedVersion = string.format("%d.%d", installedMajor, installedMinor)
    local availableVersion = string.format("%d.%d", availableMajor, availableMinor)
    self.updateUrl = updateUrl or ""
    local available = isUpdateAvailable()
    if available and (availableMajor > 0 or availableMinor > 0) then
        self.updateStatusText:SetText(string.format(L.UPDATE_AVAILABLE, availableVersion))
        self.updateVersionText:SetText(string.format(L.UPDATE_VERSION_LINE, installedVersion, availableVersion))
    else
        self.updateStatusText:SetText(L.UPDATE_NONE)
        if installedMinor > 0 then
            self.updateVersionText:SetText(string.format(L.UPDATE_VERSION_CURRENT, installedVersion))
        else
            self.updateVersionText:SetText("")
        end
    end
    local urlText = updateUrl ~= "" and updateUrl or L.UPDATE_DOWNLOAD_MISSING
    if self.updateUrlText.SetText then
        self.updateUrlText._lockedText = urlText
        self.updateUrlText:SetText(urlText)
    end
    if self.updateDownloadButton then
        if updateUrl ~= "" then
            self.updateDownloadButton:Enable()
        else
            self.updateDownloadButton:Disable()
        end
    end
    if self.updateDismissButton then
        if available then
            self.updateDismissButton:Enable()
            self.updateDismissButton:Show()
        else
            self.updateDismissButton:Disable()
            self.updateDismissButton:Hide()
        end
    end
    if self.updateDebugText then
        local settings = Goals and Goals.db and Goals.db.settings or nil
        local seenMajor = settings and settings.updateSeenMajor or 0
        local seenMinor = settings and settings.updateSeenVersion or 0
        local seenFlag = settings and settings.updateHasBeenSeen and "true" or "false"
        self.updateDebugText:SetText(string.format("Debug: installed v%s, available v%s, seen v%d.%d, seenFlag %s", installedVersion, availableVersion, seenMajor, seenMinor, seenFlag))
    end
end

function UI:SelectTab(id)
    if not self.frame or not self.tabs[id] then
        return
    end
    if not self.frame.numTabs and self.tabs then
        self.frame.numTabs = #self.tabs
    end
    PanelTemplates_SetTab(self.frame, id)
    for index, page in ipairs(self.pages) do
        setShown(page, index == id)
    end
    self.currentTab = id
    clearCombatRowTooltipLock()
    hideCombatRowTooltip()
    if self.wishlistTabId and id ~= self.wishlistTabId then
        hideBuildPreviewTooltip()
        hideBuildShareTooltip()
        if self.buildShareTargetFrame then
            self.buildShareTargetFrame:Hide()
        end
    end
    if self.UpdateLootOptionsVisibility then
        self:UpdateLootOptionsVisibility()
    end
    if self.UpdateDamageOptionsVisibility then
        self:UpdateDamageOptionsVisibility()
    end
    if self.UpdateHistoryOptionsVisibility then
        self:UpdateHistoryOptionsVisibility()
    end
    if self.UpdateWishlistHelpVisibility then
        self:UpdateWishlistHelpVisibility()
    end
    if self.UpdateWishlistSocketPickerVisibility then
        self:UpdateWishlistSocketPickerVisibility()
    end
    self:Refresh()
end

function UI:UpdateLootOptionsVisibility()
    if not self.lootOptionsFrame then
        return
    end
    local open = self.lootOptionsOpen
    if self.lootOptionsInline then
        open = true
    end
    local show = self.currentTab == self.lootTabId and open
    if self.lootOptionsOuter then
        setShown(self.lootOptionsOuter, show)
    end
    setShown(self.lootOptionsFrame, show)
end

function UI:UpdateDamageOptionsVisibility()
    if not self.damageOptionsFrame then
        return
    end
    local open = self.damageOptionsOpen
    if self.damageOptionsInline then
        open = true
    end
    local show = self.currentTab == self.damageTabId and open
    if self.damageOptionsOuter then
        setShown(self.damageOptionsOuter, show)
    end
    setShown(self.damageOptionsFrame, show)
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

function UI:CreateOverviewTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsOverviewOptionsInset", OPTIONS_PANEL_WIDTH)
    self.overviewOptionsFrame = optionsPanel
    self.overviewOptionsScroll = optionsPanel.scroll
    self.overviewOptionsContent = optionsContent
    self.overviewOptionsOpen = true
    self.overviewOptionsInline = true

    local rosterInset = CreateFrame("Frame", "GoalsOverviewRosterInset", page, "GoalsInsetTemplate")
    applyInsetTheme(rosterInset)
    rosterInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    rosterInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    rosterInset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    self.rosterInset = rosterInset
    if page.footer then
        anchorToFooter(rosterInset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(rosterInset, "GoalsRosterTable", {
        columns = {
            { key = "status", title = "", width = 18, justify = "LEFT", wrap = false },
            { key = "player", title = "Player", width = 220, justify = "LEFT", wrap = false },
            { key = "points", title = "Points", width = 60, justify = "RIGHT", wrap = false },
            { key = "actions", title = "Actions", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = ROW_HEIGHT,
        visibleRows = ROSTER_ROWS,
        headerHeight = 16,
    })
    self.rosterTable = tableWidget
    self.rosterScroll = tableWidget.scroll
    self.rosterRows = tableWidget.rows

    local actionsHeader = nil
    for _, col in ipairs(tableWidget.columns or {}) do
        if col.key == "actions" then
            actionsHeader = col.header
            break
        end
    end
    if actionsHeader then
        local okAllPlus, allPlusBtn = pcall(CreateFrame, "Button", "GoalsRosterAllPlusButton", tableWidget.header, "UIPanelButtonTemplate2")
        if not (okAllPlus and allPlusBtn) then
            allPlusBtn = CreateFrame("Button", "GoalsRosterAllPlusButton", tableWidget.header, "UIPanelButtonTemplate")
        end
        allPlusBtn:SetSize(48, 16)
        allPlusBtn:SetText("+1 All")
        allPlusBtn:SetPoint("RIGHT", tableWidget.header, "RIGHT", -2, 0)
        allPlusBtn:SetScript("OnClick", function()
            Goals:AwardPresentPoints(1, "Roster +1 All")
        end)
        self.rosterAllPlusButton = allPlusBtn
    end

    self.rosterScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            UI:UpdateRosterList()
        end)
    end)
    self.rosterScroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, selfScroll._contentHeight or 0)
    end)
    local autoSyncTicker = CreateFrame("Frame", nil, rosterInset)
    autoSyncTicker.elapsed = 0
    local function startAutoSyncTicker()
        autoSyncTicker:SetScript("OnUpdate", function(selfFrame, elapsed)
            selfFrame.elapsed = selfFrame.elapsed + (elapsed or 0)
            if selfFrame.elapsed < 0.5 then
                return
            end
            selfFrame.elapsed = 0
            if UI and UI.UpdateAutoSyncLabel then
                UI:UpdateAutoSyncLabel()
            end
        end)
    end
    local function stopAutoSyncTicker()
        autoSyncTicker:SetScript("OnUpdate", nil)
    end
    autoSyncTicker:SetScript("OnShow", function()
        startAutoSyncTicker()
    end)
    autoSyncTicker:SetScript("OnHide", function()
        stopAutoSyncTicker()
    end)
    if autoSyncTicker:IsShown() then
        startAutoSyncTicker()
    end
    self.autoSyncTicker = autoSyncTicker

    for i = 1, #self.rosterRows do
        local row = self.rosterRows[i]
        if row.cols and row.cols.status then
            row.cols.status:SetText("")
        end
        if row.cols and row.cols.actions then
            row.cols.actions:SetText("")
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        if row.cols and row.cols.status then
            icon:SetPoint("LEFT", row.cols.status, "LEFT", 0, 0)
        else
            icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        end
        row.icon = icon

        local nameText = row.cols and row.cols.player or row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        nameText:SetText("")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        local pointsText = row.cols and row.cols.points or row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        pointsText:SetText("0")
        pointsText:SetWordWrap(false)
        pointsText:SetJustifyH("RIGHT")
        if not (row.cols and row.cols.points) then
            pointsText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        end
        row.pointsText = pointsText

        local actionsAnchor = CreateFrame("Frame", nil, row)
        if row.cols and row.cols.actions then
            actionsAnchor:SetPoint("LEFT", row.cols.actions, "LEFT", 0, 0)
        else
            actionsAnchor:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
        actionsAnchor:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        actionsAnchor:SetHeight(ROW_HEIGHT)
        row.actionsAnchor = actionsAnchor

        local add = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        add:SetSize(18, 16)
        add:SetText("+")
        row.add = add

        local sub = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        sub:SetSize(18, 16)
        sub:SetText("-")
        row.sub = sub

        local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        reset:SetSize(18, 16)
        reset:SetText("0")
        row.reset = reset

        local undo = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        undo:SetSize(22, 16)
        undo:SetText("U")
        row.undo = undo

        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetSize(18, 16)
        remove:SetText("X")
        row.remove = remove

        add:SetPoint("LEFT", actionsAnchor, "LEFT", 0, 0)
        sub:SetPoint("LEFT", add, "RIGHT", 2, 0)
        reset:SetPoint("LEFT", sub, "RIGHT", 2, 0)
        undo:SetPoint("LEFT", reset, "RIGHT", 2, 0)
        remove:SetPoint("LEFT", undo, "RIGHT", 2, 0)

        add:SetScript("OnClick", function()
            if row.playerName then
                Goals:AdjustPoints(row.playerName, 1, "Roster +1")
            end
        end)
        sub:SetScript("OnClick", function()
            if row.playerName then
                Goals:AdjustPoints(row.playerName, -1, "Roster -1")
            end
        end)
        reset:SetScript("OnClick", function()
            if row.playerName then
                local dis = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
                local playerName = row.playerName
                if dis ~= "" and Goals.NormalizeName and Goals:NormalizeName(dis) == Goals:NormalizeName(playerName) then
                    local last = Goals.state and Goals.state.lastLoot or nil
                    if last and last.name and last.link then
                        local window = 600
                        if Goals:NormalizeName(last.name) == Goals:NormalizeName(playerName) and (time() - (last.ts or 0)) <= window then
                            if Goals.HandleManualLootReset and Goals:HandleManualLootReset(playerName, last.link, false) then
                                return
                            end
                        end
                    end
                end
                Goals:SetPoints(playerName, 0, "Roster reset")
            end
        end)
        undo:SetScript("OnClick", function()
            if row.playerName then
                Goals:UndoPoints(row.playerName)
            end
        end)
        remove:SetScript("OnClick", function()
            if row.playerName then
                Goals:RemovePlayer(row.playerName)
            end
        end)
    end

    local y = -10
    local adminControls = {}
    local function trackAdmin(control)
        if control then
            table.insert(adminControls, control)
        end
    end
    self.overviewAdminControls = adminControls
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

    local function addCheck(text, onClick, tooltipText)
        local check = CreateFrame("CheckButton", nil, optionsContent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsCheck(check)
        setCheckText(check, text)
        check:SetScript("OnClick", onClick)
        attachSideTooltip(check, tooltipText)
        y = y - 28
        return check
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick, tooltipText)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        attachSideTooltip(btn, tooltipText)
        y = y - 30
        return btn
    end

    local function addButton(text, onClick)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    local function addButtonPair(leftText, leftClick, rightText, rightClick)
        local gap = 6
        local width = math.floor((OPTIONS_CONTROL_WIDTH - gap) / 2)
        local leftBtn = createOptionsButton(optionsContent)
        styleOptionsButton(leftBtn, width)
        leftBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        leftBtn:SetText(leftText)
        leftBtn:SetScript("OnClick", leftClick)

        local rightBtn = createOptionsButton(optionsContent)
        styleOptionsButton(rightBtn, width)
        rightBtn:SetPoint("LEFT", leftBtn, "RIGHT", gap, 0)
        rightBtn:SetText(rightText)
        rightBtn:SetScript("OnClick", rightClick)

        y = y - 30
        return leftBtn, rightBtn
    end

    addSectionHeader("Roster")
    addLabel(L.LABEL_SORT)
    local sortDrop = addDropdown("GoalsSortDropdown")
    attachSideTooltip(sortDrop, "Choose how the roster is sorted.")
    self.sortDropdown = sortDrop
    self:SetupSortDropdown(sortDrop)

    local presentCheck = addCheck("Show present players", function(selfBtn)
        local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
        overviewSettings.showPresentOnly = selfBtn:GetChecked() and true or false
        Goals:NotifyDataChanged()
    end, "Show only players currently in your group.")
    self.presentCheck = presentCheck

    local disableGainCheck = addCheck("Pause point gains", function(selfBtn)
        Goals:SetRaidSetting("disablePointGain", selfBtn:GetChecked() and true or false)
    end, "Pause automatic point awards and adjustments.")
    self.disablePointGainCheck = disableGainCheck

    local disableGainStatus = addInfoLabel("")
    disableGainStatus:SetJustifyH("LEFT")
    disableGainStatus:Hide()
    self.disablePointGainStatus = disableGainStatus

    y = y - 8
    addSectionHeader("General")

    local minimapCheck = addCheck("Show minimap button", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end, "Show the GOALS minimap button.")
    self.minimapCheck = minimapCheck

    local autoMinCheck = addCheck("Auto-minimize in combat", function(selfBtn)
        Goals.db.settings.autoMinimizeCombat = selfBtn:GetChecked() and true or false
    end, "Minimize GOALS automatically when combat starts.")
    self.autoMinimizeCheck = autoMinCheck

    local localOnlyCheck = addCheck("Local-only mode", function(selfBtn)
        Goals.db.settings.localOnly = selfBtn:GetChecked() and true or false
    end, "Disable syncing; changes stay on this client.")
    self.localOnlyCheck = localOnlyCheck

    local function hasDBM()
        if DBM and DBM.RegisterCallback then
            return true
        end
        if IsAddOnLoaded then
            return IsAddOnLoaded("DBM-Core") or IsAddOnLoaded("DBM-GUI")
        end
        return false
    end

    if hasDBM() then
        local dbmCheck = addCheck("Use DBM encounter events", function(selfBtn)
            Goals.db.settings.dbmIntegration = selfBtn:GetChecked() and true or false
            if Goals.db.settings.dbmIntegration and Goals.Events and Goals.Events.InitDBMCallbacks then
                Goals.Events:InitDBMCallbacks()
            end
        end, "Use DBM encounter events to improve boss tracking (if installed).")
        self.dbmIntegrationCheck = dbmCheck

        local dbmWishlistCheck = addCheck("DBM wishlist alerts", function(selfBtn)
            Goals.db.settings.wishlistDbmIntegration = selfBtn:GetChecked() and true or false
        end, "Use DBM events to help detect wishlist drops.")
        self.wishlistDbmIntegrationCheck = dbmWishlistCheck
    end

    y = y - 8
    addSectionHeader(L.LABEL_SYNC)
    local syncValue = createLabel(optionsContent, "", "GameFontHighlight")
    syncValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    syncValue:SetJustifyH("LEFT")
    self.syncValue = syncValue
    y = y - 18

    local autoSyncLabel = createLabel(optionsContent, "", "GameFontHighlightSmall")
    autoSyncLabel:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    autoSyncLabel:SetJustifyH("LEFT")
    styleOptionsLabel(autoSyncLabel)
    self.autoSyncLabel = autoSyncLabel
    y = y - 16

    local syncNote = createLabel(optionsContent, "", "GameFontHighlightSmall")
    syncNote:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    syncNote:SetJustifyH("LEFT")
    styleOptionsLabel(syncNote)
    syncNote:Hide()
    self.syncNoteLabel = syncNote
    y = y - 20

    local syncRequestBtn = addButton("Request sync", function()
        if Goals and Goals.Comm and Goals.Comm.RequestSync then
            Goals.Comm:RequestSync("MANUAL")
        end
    end)
    syncRequestBtn:SetScript("OnEnter", function(selfBtn)
        showSideTooltip("Request a full roster and points sync from the loot master.")
    end)
    syncRequestBtn:SetScript("OnLeave", function()
        hideSideTooltip()
    end)
    self.syncRequestButton = syncRequestBtn

    addLabel(L.LABEL_DISENCHANTER)
    local disValue = createLabel(optionsContent, "", "GameFontHighlight")
    disValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    disValue:SetJustifyH("LEFT")
    self.disenchantValue = disValue
    y = y - 18

    addLabel(L.SETTINGS_DISENCHANTER)
    local disDrop = addDropdown("GoalsDisenchanterDropdown")
    attachSideTooltip(disDrop, "Select the player who will disenchant items.")
    disDrop.colorize = true
    self.disenchanterDropdown = disDrop
    self:SetupDropdown(disDrop, function()
        return UI:GetDisenchanterCandidates()
    end, function(name)
        if name == L.NONE_OPTION then
            Goals:SetDisenchanter("")
            return
        end
        Goals:SetDisenchanter(name)
    end, L.SELECT_OPTION)
    y = y - 8

    setupSudoDevPopup()
    setupSaveTableHelpPopup()
    setupBuildSharePopup()

    local function addActionButton(text, onClick)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    y = y - 8
    local maintenanceLabel, maintenanceBar = addSectionHeader("Maintenance")
    self.overviewMaintenanceLabel = maintenanceLabel
    self.overviewMaintenanceBar = maintenanceBar
    trackAdmin(maintenanceLabel)
    trackAdmin(maintenanceBar)

    local clearPointsBtn = addActionButton("Clear All Points", function()
        if Goals and Goals.ClearAllPointsLocal then
            Goals:ClearAllPointsLocal()
        end
    end)
    trackAdmin(clearPointsBtn)
    self.overviewClearPointsBtn = clearPointsBtn

    local clearPlayersBtn = addActionButton("Clear Players List", function()
        if Goals and Goals.ClearPlayersLocal then
            Goals:ClearPlayersLocal()
        end
    end)
    trackAdmin(clearPlayersBtn)
    self.overviewClearPlayersBtn = clearPlayersBtn

    local clearHistoryBtn = addActionButton("Clear History", function()
        if Goals and Goals.ClearHistoryLocal then
            Goals:ClearHistoryLocal()
        end
    end)
    trackAdmin(clearHistoryBtn)
    self.overviewClearHistoryBtn = clearHistoryBtn

    local clearAllBtn = addActionButton("Clear All", function()
        if Goals and Goals.ClearAllLocal then
            Goals:ClearAllLocal()
        end
    end)
    trackAdmin(clearAllBtn)
    self.overviewClearAllBtn = clearAllBtn

    y = y - 8
    local miniLabel, miniBar = addSectionHeader(L.LABEL_MINI_TRACKER)
    self.overviewMiniLabel = miniLabel
    self.overviewMiniBar = miniBar
    local resetMiniBtn = addActionButton("Reset Mini Position", function()
        if UI and UI.ResetMiniTrackerPosition then
            UI:ResetMiniTrackerPosition()
        end
    end)
    self.overviewResetMiniBtn = resetMiniBtn

    local miniBtn = addActionButton(L.BUTTON_TOGGLE_MINI_TRACKER, function()
        if UI and UI.ToggleMiniTracker then
            UI:ToggleMiniTracker()
        end
    end)
    self.miniTrackerButton = miniBtn

    y = y - 8
    local devLabel, devBar = addSectionHeader("Dev Tools")
    self.overviewDevLabel = devLabel
    self.overviewDevBar = devBar
    trackAdmin(devLabel)
    trackAdmin(devBar)

    local sudoBtn = addActionButton("", function()
        if Goals.db.settings.sudoDev then
            Goals.db.settings.sudoDev = false
            UI:Refresh()
            return
        end
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_SUDO_DEV")
        end
    end)
    self.sudoDevButton = sudoBtn
    trackAdmin(sudoBtn)

    y = y - 8
    local keybindsLabel, keybindsBar = addSectionHeader("Keybindings")
    self.overviewKeybindsLabel = keybindsLabel
    self.overviewKeybindsBar = keybindsBar
    self.keybindsTitle = keybindsLabel

    local uiBindLabel = addLabel("Toggle main window:")
    self.keybindUiLabel = uiBindLabel
    local uiBindValue = createLabel(optionsContent, "", "GameFontHighlightSmall")
    uiBindValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    uiBindValue:SetJustifyH("LEFT")
    styleOptionsLabel(uiBindValue)
    self.keybindUiValue = uiBindValue
    y = y - 16

    local miniBindLabel = addLabel("Toggle mini tracker:")
    self.keybindMiniLabel = miniBindLabel
    local miniBindValue = createLabel(optionsContent, "", "GameFontHighlightSmall")
    miniBindValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    miniBindValue:SetJustifyH("LEFT")
    styleOptionsLabel(miniBindValue)
    self.keybindMiniValue = miniBindValue
    y = y - 16

    local function storeOverviewAnchor(control)
        if not control or control._overviewAnchor then
            return
        end
        local point, relative, relativePoint, x, y = control:GetPoint(1)
        if not point then
            return
        end
        control._overviewAnchor = {
            point = point,
            relative = relative,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end

    self.overviewShiftBelowMaintenance = {
        self.overviewMiniBar,
        self.overviewResetMiniBtn,
        self.miniTrackerButton,
        self.overviewDevBar,
        self.sudoDevButton,
    }

    self.overviewShiftBelowDev = {
        self.overviewKeybindsBar,
        self.keybindsTitle,
        self.keybindUiLabel,
        self.keybindUiValue,
        self.keybindMiniLabel,
        self.keybindMiniValue,
    }

    for _, control in ipairs(self.overviewShiftBelowMaintenance) do
        storeOverviewAnchor(control)
    end
    for _, control in ipairs(self.overviewShiftBelowDev) do
        storeOverviewAnchor(control)
    end
    storeOverviewAnchor(self.overviewMaintenanceBar)

    function UI:UpdateOverviewOptionsLayout(hasAccess)
        local function restore(list)
            for _, control in ipairs(list or {}) do
                local anchor = control and control._overviewAnchor or nil
                if anchor and control.ClearAllPoints then
                    control:ClearAllPoints()
                    control:SetPoint(anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y)
                end
            end
        end

        local function shift(list, delta)
            for _, control in ipairs(list or {}) do
                local anchor = control and control._overviewAnchor or nil
                if anchor and control.ClearAllPoints then
                    control:ClearAllPoints()
                    control:SetPoint(anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y + delta)
                end
            end
        end

        restore(self.overviewShiftBelowMaintenance)
        restore(self.overviewShiftBelowDev)

        if not hasAccess then
            local content = self.overviewOptionsContent or nil
            local anchor = self.overviewMaintenanceBar and self.overviewMaintenanceBar._overviewAnchor or nil
            if content and anchor then
                local y = anchor.y or 0
                local function setHeader(bar)
                    if not bar or not bar.ClearAllPoints then
                        return
                    end
                    bar:ClearAllPoints()
                    bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                    bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                    y = y - 22
                end
                local function setControl(control, step)
                    if not control or not control.ClearAllPoints then
                        return
                    end
                    control:ClearAllPoints()
                    control:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - (step or 30)
                end
                local function setControlIfShown(control, step)
                    if control and control.IsShown and not control:IsShown() then
                        return
                    end
                    setControl(control, step)
                end
                local function setSpacer(amount)
                    y = y - (amount or 8)
                end

                -- Mini section
                setHeader(self.overviewMiniBar)
                setControl(self.overviewResetMiniBtn, 30)
                setControl(self.miniTrackerButton, 30)

                -- Keybindings section (skip Dev Tools entirely)
                setSpacer(0)
                setHeader(self.overviewKeybindsBar)
                if self.keybindUiLabel and self.keybindUiLabel.ClearAllPoints then
                    self.keybindUiLabel:ClearAllPoints()
                    self.keybindUiLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 18
                end
                if self.keybindUiValue and self.keybindUiValue.ClearAllPoints then
                    self.keybindUiValue:ClearAllPoints()
                    self.keybindUiValue:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 16
                end
                if self.keybindMiniLabel and self.keybindMiniLabel.ClearAllPoints then
                    self.keybindMiniLabel:ClearAllPoints()
                    self.keybindMiniLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 18
                end
                if self.keybindMiniValue and self.keybindMiniValue.ClearAllPoints then
                    self.keybindMiniValue:ClearAllPoints()
                    self.keybindMiniValue:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    y = y - 16
                end

                local contentHeight = math.abs(y) + 24
                content:SetHeight(contentHeight)
                if self.overviewOptionsScroll then
                    setScrollBarAlwaysVisible(self.overviewOptionsScroll, contentHeight)
                end
            else
                shift(self.overviewShiftBelowMaintenance, 0)
            end
        else
            local content = self.overviewOptionsContent
            if content and content._defaultHeight then
                content:SetHeight(content._defaultHeight)
                if self.overviewOptionsScroll then
                    setScrollBarAlwaysVisible(self.overviewOptionsScroll, content._defaultHeight)
                end
            end
        end
    end

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    optionsContent._defaultHeight = contentHeight
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
end

function UI:CreateLootTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsLootOptionsInset", OPTIONS_PANEL_WIDTH)
    self.lootOptionsFrame = optionsPanel
    self.lootOptionsScroll = optionsPanel.scroll
    self.lootOptionsContent = optionsContent
    self.lootOptionsOpen = true
    self.lootOptionsInline = true

    local inset = CreateFrame("Frame", "GoalsLootInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    inset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    self.lootHistoryInset = inset
    if page.footer then
        anchorToFooter(inset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(inset, "GoalsLootTable", {
        columns = {
            { key = "time", title = "Time", width = 60, justify = "LEFT", wrap = false },
            { key = "item", title = "Item", width = 200, justify = "LEFT", wrap = false },
            { key = "player", title = "Player", width = 120, justify = "LEFT", wrap = false },
            { key = "notes", title = "Notes", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = LOOT_HISTORY_ROW_HEIGHT_COMPACT,
        visibleRows = LOOT_HISTORY_ROWS,
        headerHeight = 16,
    })
    self.lootTable = tableWidget
    self.lootHistoryScroll = tableWidget.scroll
    self.lootHistoryRows = tableWidget.rows

    self.lootHistoryScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, LOOT_HISTORY_ROW_HEIGHT_COMPACT, function()
            UI:UpdateLootHistoryList()
        end)
    end)

    for _, row in ipairs(self.lootHistoryRows) do
        row:EnableMouse(true)
        row.badgeExpansion = createBadge(row)
        row.badgeTier = createBadge(row)
        if row.badgeExpansion.SetFrameStrata then
            row.badgeExpansion:SetFrameStrata("DIALOG")
        end
        if row.badgeTier.SetFrameStrata then
            row.badgeTier:SetFrameStrata("DIALOG")
        end
        if row.badgeExpansion.SetFrameLevel then
            row.badgeExpansion:SetFrameLevel(row:GetFrameLevel() + 10)
        end
        if row.badgeTier.SetFrameLevel then
            row.badgeTier:SetFrameLevel(row:GetFrameLevel() + 10)
        end
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        selected:SetBlendMode("ADD")
        selected:SetAlpha(0.5)
        selected:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        selected:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
        selected:Hide()
        row.selected = selected
        row:SetScript("OnMouseUp", function(selfRow, button)
            if selfRow.entry then
                UI:SetLootSelection(selfRow, selfRow.entry)
            end
            if button == "RightButton" and selfRow.entry and selfRow.entry.kind == "FOUND"
                and selfRow.entry.raw and not selfRow.entry.raw.assignedTo then
                UI:ShowFoundLootMenu(selfRow, selfRow.entry.raw)
            end
        end)

        local itemButton = CreateFrame("Button", nil, row)
        itemButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        itemButton:SetPoint("TOPLEFT", row.cols.item, "TOPLEFT", 0, 0)
        itemButton:SetPoint("BOTTOMRIGHT", row.cols.item, "BOTTOMRIGHT", 0, 0)
        itemButton:SetScript("OnMouseUp", function(selfBtn, button)
            local selfRow = selfBtn:GetParent()
            if selfRow and selfRow.entry then
                UI:SetLootSelection(selfRow, selfRow.entry)
            end
            if button == "RightButton" and selfRow and selfRow.entry and selfRow.entry.kind == "FOUND"
                and selfRow.entry.raw and not selfRow.entry.raw.assignedTo then
                UI:ShowFoundLootMenu(selfRow, selfRow.entry.raw)
                return
            end
            if button == "LeftButton" and selfRow and selfRow.itemLink and selfRow.itemLink ~= "" then
                if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
                    HandleModifiedItemClick(selfRow.itemLink)
                    return
                end
                if ItemRefTooltip then
                    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                    ItemRefTooltip:SetHyperlink(selfRow.itemLink)
                elseif GameTooltip then
                    GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(selfRow.itemLink)
                end
            end
        end)
        itemButton:SetScript("OnEnter", function(selfBtn)
            local selfRow = selfBtn:GetParent()
            if not selfRow or not selfRow.itemLink or selfRow.itemLink == "" then
                return
            end
            if GameTooltip then
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(selfRow.itemLink)
                GameTooltip:Show()
            end
        end)
        itemButton:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        row.itemButton = itemButton
    end

    local function setLootMethod(method)
        local ok, err = Goals:SetLootMethod(method)
        if not ok and err then
            Goals:Print(err)
        end
    end

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

    local function addCheck(text, onClick, tooltipText)
        local check = CreateFrame("CheckButton", nil, optionsContent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsCheck(check)
        setCheckText(check, text)
        check:SetScript("OnClick", onClick)
        attachSideTooltip(check, tooltipText)
        y = y - 28
        return check
    end

    local function addButton(text, onClick)
        local btn = createOptionsButton(optionsContent)
        styleOptionsButton(btn, OPTIONS_CONTROL_WIDTH)
        btn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        y = y - 30
        return btn
    end

    local function addButtonPair(leftText, leftClick, rightText, rightClick)
        local gap = 6
        local width = math.floor((OPTIONS_CONTROL_WIDTH - gap) / 2)
        local leftBtn = createOptionsButton(optionsContent)
        styleOptionsButton(leftBtn, width)
        leftBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        leftBtn:SetText(leftText)
        leftBtn:SetScript("OnClick", leftClick)

        local rightBtn = createOptionsButton(optionsContent)
        styleOptionsButton(rightBtn, width)
        rightBtn:SetPoint("LEFT", leftBtn, "RIGHT", gap, 0)
        rightBtn:SetText(rightText)
        rightBtn:SetScript("OnClick", rightClick)

        y = y - 30
        return leftBtn, rightBtn
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    addSectionHeader(L.LABEL_LOOT_METHOD)
    addButton(L.LOOT_METHOD_MASTER, function()
        setLootMethod("master")
    end)
    addButton(L.LOOT_METHOD_GROUP, function()
        setLootMethod("group")
    end)
    addButton(L.LOOT_METHOD_FREE, function()
        setLootMethod("freeforall")
    end)

    y = y - 8
    addSectionHeader(L.LABEL_LOOT_HISTORY)
    addLabel(L.LABEL_LOOT_HISTORY_FILTER)

    local minFilterDrop = addDropdown("GoalsLootHistoryMinQuality")
    attachSideTooltip(minFilterDrop, "Hide items below this quality in Loot History.")
    minFilterDrop.options = getQualityOptions()
    UIDropDownMenu_Initialize(minFilterDrop, function(_, level)
        for _, option in ipairs(minFilterDrop.options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                Goals.db.settings.lootHistoryMinQuality = option.value
                UIDropDownMenu_SetSelectedValue(minFilterDrop, option.value)
                UIDropDownMenu_SetText(minFilterDrop, option.text)
                UI:UpdateLootHistoryList()
            end
            info.checked = (Goals.db.settings.lootHistoryMinQuality or 0) == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.lootHistoryMinQuality = minFilterDrop

    y = y - 8
    addSectionHeader(L.LABEL_RESET_POINTS)
    self.resetMountsCheck = addCheck("Reset mounts to 0", function(selfBtn)
        Goals:SetRaidSetting("resetMounts", selfBtn:GetChecked() and true or false)
    end, "Set mount winners to 0 points when they win these items.")
    self.resetPetsCheck = addCheck("Reset pets to 0", function(selfBtn)
        Goals:SetRaidSetting("resetPets", selfBtn:GetChecked() and true or false)
    end, "Set pet winners to 0 points when they win these items.")
    self.resetRecipesCheck = addCheck("Reset recipes to 0", function(selfBtn)
        Goals:SetRaidSetting("resetRecipes", selfBtn:GetChecked() and true or false)
    end, "Set recipe winners to 0 points when they win these items.")
    self.resetTokensCheck = addCheck("Reset tier tokens to 0", function(selfBtn)
        Goals:SetRaidSetting("resetTokens", selfBtn:GetChecked() and true or false)
    end, "Set tier token winners to 0 points when they win these items.")
    self.resetQuestItemsCheck = addCheck("Reset quest items to 0", function(selfBtn)
        Goals:SetRaidSetting("resetQuestItems", selfBtn:GetChecked() and true or false)
    end, "Set quest item winners to 0 points when they win these items.")
    self.resetLootWindowCheck = addCheck("Manual mode", function(selfBtn)
        Goals:SetRaidSetting("resetRequiresLootWindow", selfBtn:GetChecked() and true or false)
    end, "Disable automatic resets unless loot is being assigned.")

    addLabel(L.LABEL_MIN_RESET_QUALITY)
    local minDrop = addDropdown("GoalsResetQualityDropdown")
    attachSideTooltip(minDrop, "Only reset points for items at or above this quality.")
    self.resetQualityDropdown = minDrop
    self:SetupResetQualityDropdown(minDrop)

    y = y - 8
    addSectionHeader("Notes")

    addLabel("Selected entry")
    local selectedValue = createLabel(optionsContent, "None", "GameFontHighlightSmall")
    selectedValue:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    selectedValue:SetWidth(OPTIONS_CONTROL_WIDTH)
    selectedValue:SetJustifyH("LEFT")
    styleOptionsLabel(selectedValue)
    self.lootNotesSelectedLabel = selectedValue
    y = y - 18

    addLabel("Note text")
    local notesBox = CreateFrame("EditBox", nil, optionsContent, "InputBoxTemplate")
    notesBox:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 18, y)
    styleOptionsEditBox(notesBox, OPTIONS_CONTROL_WIDTH - 10)
    attachSideTooltip(notesBox, "Add a note for the selected loot entry.")
    notesBox:SetAutoFocus(false)
    bindEscapeClear(notesBox)
    notesBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    self.lootNotesBox = notesBox
    y = y - 30

    local applyBtn, clearBtn = addButtonPair("Apply", function()
        if not UI.lootSelectedNoteKey then
            return
        end
        UI:SetLootNote(UI.lootSelectedNoteKey, notesBox:GetText() or "")
        UI:UpdateLootHistoryList()
        UI:UpdateLootNoteSelection()
    end, "Clear", function()
        if not UI.lootSelectedNoteKey then
            return
        end
        UI:SetLootNote(UI.lootSelectedNoteKey, "")
        UI:UpdateLootHistoryList()
        UI:UpdateLootNoteSelection()
    end)
    self.lootNotesApplyButton = applyBtn
    self.lootNotesClearButton = clearBtn

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
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

local function fitWishlistLabel(label, text, maxLines)
    if not label then
        return
    end
    label:SetText(text or "")
    local font, size = label:GetFont()
    local lineHeight = (size or 12) + 2
    local limit = maxLines or 3
    local maxHeight = lineHeight * limit
    if label:GetStringHeight() <= maxHeight then
        return
    end
    local base = text or ""
    local left, right = 1, #base
    local best = ""
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local candidate = base:sub(1, mid) .. "..."
        label:SetText(candidate)
        if label:GetStringHeight() <= maxHeight then
            best = candidate
            left = mid + 1
        else
            right = mid - 1
        end
    end
    if best ~= "" then
        label:SetText(best)
    else
        label:SetText("...")
    end
end

-- reserved for future wishlist textbox styling tweaks

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
                    GameTooltip:Show()
                end
            end)
            gemBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            gemBtn:SetScript("OnClick", function(selfGem)
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
                GameTooltip:Show()
            end
        end)
        enchantBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        enchantBtn:SetScript("OnClick", function()
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
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnClick", function(selfBtn, btn)
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

function UI:CreateSettingsTab(page)
    local leftInset = CreateFrame("Frame", "GoalsSettingsInset", page, "GoalsInsetTemplate")
    applyInsetTheme(leftInset)
    leftInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    leftInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    leftInset:SetWidth(350)
    self.settingsInset = leftInset

    local rightInset = CreateFrame("Frame", "GoalsSettingsActionsInset", page, "GoalsInsetTemplate")
    applyInsetTheme(rightInset)
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 12, 0)
    rightInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    self.settingsActionsInset = rightInset

    local settingsTitle = createLabel(leftInset, L.TAB_SETTINGS, "GameFontNormal")
    local settingsBar = applySectionHeader(settingsTitle, leftInset, -6)
    applySectionCaption(settingsBar, "General")

    local combineCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    combineCheck:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -10)
    setCheckText(combineCheck, L.CHECK_COMBINE_HISTORY)
    combineCheck:SetScript("OnClick", function(selfBtn)
        Goals:SetRaidSetting("combineBossHistory", selfBtn:GetChecked() and true or false)
    end)
    self.combineCheck = combineCheck

    local minimapCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", combineCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(minimapCheck, L.CHECK_MINIMAP)
    minimapCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.minimap.hide = not selfBtn:GetChecked()
        UI:UpdateMinimapButton()
    end)
    self.minimapCheck = minimapCheck

    local autoMinCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    autoMinCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(autoMinCheck, L.CHECK_AUTO_MINIMIZE_COMBAT)
    autoMinCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.autoMinimizeCombat = selfBtn:GetChecked() and true or false
    end)
    self.autoMinimizeCheck = autoMinCheck

    local localOnlyCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
    localOnlyCheck:SetPoint("TOPLEFT", autoMinCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(localOnlyCheck, "Local-only mode")
    localOnlyCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.localOnly = selfBtn:GetChecked() and true or false
    end)
    self.localOnlyCheck = localOnlyCheck

    local function hasDBM()
        if DBM and DBM.RegisterCallback then
            return true
        end
        if IsAddOnLoaded then
            return IsAddOnLoaded("DBM-Core") or IsAddOnLoaded("DBM-GUI")
        end
        return false
    end

    if hasDBM() then
        local dbmCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
        dbmCheck:SetPoint("TOPLEFT", localOnlyCheck, "BOTTOMLEFT", 0, -8)
        setCheckText(dbmCheck, L.CHECK_DBM_INTEGRATION)
        dbmCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.dbmIntegration = selfBtn:GetChecked() and true or false
            if Goals.db.settings.dbmIntegration and Goals.Events and Goals.Events.InitDBMCallbacks then
                Goals.Events:InitDBMCallbacks()
            end
        end)
        self.dbmIntegrationCheck = dbmCheck

        local dbmWishlistCheck = CreateFrame("CheckButton", nil, leftInset, "UICheckButtonTemplate")
        dbmWishlistCheck:SetPoint("TOPLEFT", dbmCheck, "BOTTOMLEFT", 0, -8)
        setCheckText(dbmWishlistCheck, L.CHECK_DBM_WISHLIST)
        dbmWishlistCheck:SetScript("OnClick", function(selfBtn)
            Goals.db.settings.wishlistDbmIntegration = selfBtn:GetChecked() and true or false
        end)
        self.wishlistDbmIntegrationCheck = dbmWishlistCheck
    end

    local bindsTitle = createLabel(leftInset, "Keybindings", "GameFontNormal")
    bindsTitle:SetPoint("BOTTOMLEFT", leftInset, "BOTTOMLEFT", 12, 10)
    self.keybindsTitle = bindsTitle

    local uiBindLabel = createLabel(leftInset, "Toggle GOALS UI:", "GameFontHighlightSmall")
    uiBindLabel:SetPoint("BOTTOMLEFT", bindsTitle, "TOPLEFT", 0, 4)
    self.keybindUiLabel = uiBindLabel

    local uiBindValue = createLabel(leftInset, "", "GameFontHighlightSmall")
    uiBindValue:SetPoint("LEFT", uiBindLabel, "RIGHT", 6, 0)
    uiBindValue:SetJustifyH("LEFT")
    self.keybindUiValue = uiBindValue

    local miniBindLabel = createLabel(leftInset, "Toggle Mini Viewer:", "GameFontHighlightSmall")
    miniBindLabel:SetPoint("BOTTOMLEFT", uiBindLabel, "TOPLEFT", 0, 4)
    self.keybindMiniLabel = miniBindLabel

    local miniBindValue = createLabel(leftInset, "", "GameFontHighlightSmall")
    miniBindValue:SetPoint("LEFT", miniBindLabel, "RIGHT", 6, 0)
    miniBindValue:SetJustifyH("LEFT")
    self.keybindMiniValue = miniBindValue

    setupSudoDevPopup()
    setupSaveTableHelpPopup()
    setupBuildSharePopup()

    local actionsTitle = createLabel(rightInset, "Data Management", "GameFontNormal")
    local actionsBar = applySectionHeader(actionsTitle, rightInset, -6)
    applySectionCaption(actionsBar, "Local maintenance")

    local function createActionButton(text, onClick)
        local btn = CreateFrame("Button", nil, rightInset, "UIPanelButtonTemplate")
        btn:SetSize(180, 20)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local function createAlignedDivider(anchor, yOffset)
        if not anchor then
            return nil
        end
        local line = rightInset:CreateTexture(nil, "BORDER")
        line:SetHeight(1)
        line:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset or -8)
        line:SetPoint("LEFT", rightInset, "LEFT", 4, 0)
        line:SetPoint("RIGHT", rightInset, "RIGHT", -4, 0)
        line:SetTexture(1, 1, 1, 0.08)
        return line
    end

    local function applyAlignedSectionHeader(label, anchor, yOffset)
        if not label or not anchor then
            return nil
        end
        local bar = rightInset:CreateTexture(nil, "BORDER")
        bar:SetHeight(16)
        bar:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset or -8)
        bar:SetPoint("LEFT", rightInset, "LEFT", 4, 0)
        bar:SetPoint("RIGHT", rightInset, "RIGHT", -4, 0)
        bar:SetTexture(0, 0, 0, 0.45)
        label:ClearAllPoints()
        label:SetPoint("LEFT", bar, "LEFT", 6, 0)
        label:SetTextColor(0.92, 0.8, 0.5, 1)
        return bar
    end

    local ACTIONS_LEFT = 2

    local clearPointsBtn = createActionButton("Clear All Points", function()
        if Goals and Goals.ClearAllPointsLocal then
            Goals:ClearAllPointsLocal()
        end
    end)
    clearPointsBtn:SetPoint("TOPLEFT", actionsTitle, "BOTTOMLEFT", ACTIONS_LEFT, -10)

    local clearPlayersBtn = createActionButton("Clear Players List", function()
        if Goals and Goals.ClearPlayersLocal then
            Goals:ClearPlayersLocal()
        end
    end)
    clearPlayersBtn:SetPoint("TOPLEFT", clearPointsBtn, "BOTTOMLEFT", 0, -6)

    local clearHistoryBtn = createActionButton("Clear History", function()
        if Goals and Goals.ClearHistoryLocal then
            Goals:ClearHistoryLocal()
        end
    end)
    clearHistoryBtn:SetPoint("TOPLEFT", clearPlayersBtn, "BOTTOMLEFT", 0, -6)

    local clearAllBtn = createActionButton("Clear All", function()
        if Goals and Goals.ClearAllLocal then
            Goals:ClearAllLocal()
        end
    end)
    clearAllBtn:SetPoint("TOPLEFT", clearHistoryBtn, "BOTTOMLEFT", 0, -10)

    local miniDivider = createAlignedDivider(clearAllBtn, -6)
    local miniTitle = createLabel(rightInset, L.LABEL_MINI_TRACKER, "GameFontNormal")
    local miniBar = applyAlignedSectionHeader(miniTitle, miniDivider or clearAllBtn, -6)
    applySectionCaption(miniBar, "Quick view")
    if miniBar then
        local resetMiniBtn = createSmallIconButton(rightInset, 16, "Interface\\Buttons\\UI-RefreshButton")
        resetMiniBtn:SetPoint("RIGHT", miniBar, "RIGHT", -6, 0)
        resetMiniBtn:SetScript("OnClick", function()
            if UI and UI.ResetMiniTrackerPosition then
                UI:ResetMiniTrackerPosition()
            end
        end)
        resetMiniBtn:SetScript("OnEnter", function(selfBtn)
            showSideTooltip("Reset Mini Position")
        end)
        resetMiniBtn:SetScript("OnLeave", function()
            hideSideTooltip()
        end)
    end

    local miniBtn = createActionButton(L.BUTTON_TOGGLE_MINI_TRACKER, function()
        if UI and UI.ToggleMiniTracker then
            UI:ToggleMiniTracker()
        end
    end)
    miniBtn:SetPoint("TOPLEFT", miniTitle, "BOTTOMLEFT", ACTIONS_LEFT, -6)
    self.miniTrackerButton = miniBtn

    local editDivider = createAlignedDivider(miniBtn, -6)
    local editTitle = createLabel(rightInset, "Local Editing", "GameFontNormal")
    local editBar = applyAlignedSectionHeader(editTitle, editDivider or syncSeenBtn, -6)
    applySectionCaption(editBar, "Admin tools")

    local sudoBtn = createActionButton("", function()
        if Goals.db.settings.sudoDev then
            Goals.db.settings.sudoDev = false
            UI:Refresh()
            return
        end
        if StaticPopup_Show then
            StaticPopup_Show("GOALS_SUDO_DEV")
        end
    end)
    sudoBtn:SetPoint("TOPLEFT", editTitle, "BOTTOMLEFT", ACTIONS_LEFT, -10)
    self.sudoDevButton = sudoBtn

    local syncRequestBtn = createActionButton("Ask for sync", function()
        if Goals and Goals.Comm and Goals.Comm.RequestSync then
            Goals.Comm:RequestSync("MANUAL")
        end
    end)
    syncRequestBtn:SetPoint("TOPLEFT", sudoBtn, "BOTTOMLEFT", 0, -6)
    syncRequestBtn:SetScript("OnEnter", function(selfBtn)
        showSideTooltip("Ask the loot master to send a full roster/points sync.")
    end)
    syncRequestBtn:SetScript("OnLeave", function()
        hideSideTooltip()
    end)
    self.syncRequestButton = syncRequestBtn
end

function UI:CreateDamageTrackerTab(page)
    local optionsPanel, optionsContent = createOptionsPanel(page, "GoalsDamageOptionsInset", OPTIONS_PANEL_WIDTH)
    self.damageOptionsFrame = optionsPanel
    self.damageOptionsScroll = optionsPanel.scroll
    self.damageOptionsContent = optionsContent
    self.damageOptionsOpen = true
    self.damageOptionsInline = true

    local inset = CreateFrame("Frame", "GoalsDamageTrackerInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    inset:SetPoint("RIGHT", optionsPanel, "LEFT", -10, 0)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, nil, 6)
        anchorToFooter(optionsPanel, page.footer, nil, -2, 6)
    end

    local tableWidget = createTableWidget(inset, "GoalsDamageTrackerTable", {
        columns = {
            { key = "time", title = "Time", width = DAMAGE_COL_TIME, justify = "LEFT", wrap = false },
            { key = "source", title = "Source", width = DAMAGE_COL_SOURCE, justify = "LEFT", wrap = false },
            { key = "target", title = "Target", width = DAMAGE_COL_TARGET, justify = "LEFT", wrap = false },
            { key = "amount", title = "Amount", width = DAMAGE_COL_AMOUNT, justify = "RIGHT", wrap = false },
            { key = "spell", title = "Ability", fill = true, justify = "LEFT", wrap = false },
        },
        rowHeight = DAMAGE_ROW_HEIGHT,
        visibleRows = DAMAGE_ROWS,
        headerHeight = 16,
    })
    self.damageTrackerScroll = tableWidget.scroll
    self.damageTrackerRows = tableWidget.rows

    self.damageTrackerScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, DAMAGE_ROW_HEIGHT, function()
            UI:UpdateDamageTrackerList()
        end)
    end)
    self.damageTrackerScroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, selfScroll._contentHeight or 0)
    end)

    for _, row in ipairs(self.damageTrackerRows) do
        row:EnableMouse(true)
        if row.cols then
            row.timeText = row.cols.time
            row.sourceText = row.cols.source
            row.targetText = row.cols.target
            row.amountText = row.cols.amount
            row.spellText = row.cols.spell
        end

        local breakBg = row:CreateTexture(nil, "BACKGROUND")
        breakBg:SetAllPoints(row)
        breakBg:SetTexture(0.5, 0.5, 0.5, 0.2)
        breakBg:Hide()
        row.breakBg = breakBg

        local breakText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        breakText:SetPoint("LEFT", row, "LEFT", 4, 0)
        breakText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        breakText:SetJustifyH("LEFT")
        breakText:SetWordWrap(false)
        breakText:Hide()
        row.breakText = breakText

        row:SetScript("OnEnter", function(selfRow)
            if UI and UI.combatTooltipLocked then
                if UI.combatTooltipEntry == selfRow.entry then
                    showCombatRowTooltip(selfRow.entry)
                end
                return
            end
            showCombatRowTooltip(selfRow.entry)
        end)
        row:SetScript("OnLeave", function()
            if UI and UI.combatTooltipLocked then
                return
            end
            hideCombatRowTooltip()
        end)
        if row.RegisterForClicks then
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        row:SetScript("OnMouseUp", function(selfRow, button)
            if button == "LeftButton" then
                if selfRow.entry and selfRow.entry.kind ~= "BREAK" then
                    if UI and UI.combatTooltipLocked and UI.combatTooltipEntry == selfRow.entry then
                        setCombatRowTooltipLock(nil, false)
                        if selfRow.IsMouseOver and selfRow:IsMouseOver() then
                            showCombatRowTooltip(selfRow.entry)
                        else
                            hideCombatRowTooltip()
                        end
                    else
                        setCombatRowTooltipLock(selfRow.entry, true)
                        showCombatRowTooltip(selfRow.entry)
                    end
                end
                return
            end
            if button == "RightButton" and selfRow.entry and selfRow.entry.kind ~= "BREAK" then
                if UI and UI.ShowCombatRowMenu then
                    UI:ShowCombatRowMenu(selfRow.entry, selfRow)
                end
            end
        end)
    end

    local y = -10
    local function addSectionHeader(text)
        local label, bar = createOptionsHeader(optionsContent, text, y)
        y = y - 22
        return label, bar
    end

    local function addCheck(text, onClick, tooltipText)
        local check = CreateFrame("CheckButton", nil, optionsContent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsCheck(check)
        setCheckText(check, text)
        check:SetScript("OnClick", onClick)
        attachSideTooltip(check, tooltipText)
        y = y - 28
        return check
    end

    local function addLabel(text)
        local label = createLabel(optionsContent, text, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsControlLabel(label)
        y = y - 18
        return label
    end

    local function addDropdown(name)
        local dropdown = createOptionsDropdown(optionsContent, name, y)
        y = y - 32
        return dropdown
    end

    local function addSlider(name, labelText, tooltipText)
        local label = createLabel(optionsContent, labelText, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsControlLabel(label)
        local valueLabel = createLabel(optionsContent, "0%", "GameFontHighlightSmall")
        valueLabel:SetPoint("TOPRIGHT", optionsContent, "TOPLEFT", 8 + OPTIONS_CONTROL_WIDTH, y)
        valueLabel:SetJustifyH("RIGHT")
        if valueLabel.SetTextColor then
            valueLabel:SetTextColor(1, 1, 1, 1)
        end
        if valueLabel.SetWidth then
            valueLabel:SetWidth(48)
        end
        y = y - 18

        local slider = CreateFrame("Slider", name, optionsContent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
        styleOptionsSlider(slider)
        attachSideTooltip(slider, tooltipText)

        y = y - 28
        return slider, valueLabel
    end

    local trackingCheck = addCheck("Enable combat log tracking", function(selfBtn)
        local enabled = selfBtn:GetChecked() and true or false
        if Goals.DamageTracker and Goals.DamageTracker.SetEnabled then
            Goals.DamageTracker:SetEnabled(enabled)
        else
            Goals.db.settings.combatLogTracking = enabled
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
        if UI and UI.UpdateCombatDebugStatus then
            UI:UpdateCombatDebugStatus()
        end
    end, "Record combat log events for the tracker.")
    self.combatLogTrackingCheck = trackingCheck
    do
        local settings = Goals.db and Goals.db.settings or nil
        local trackingEnabled = settings and settings.combatLogTracking
        if trackingEnabled == nil then
            trackingEnabled = false
            if settings then
                settings.combatLogTracking = false
            end
        end
        trackingCheck:SetChecked(trackingEnabled and true or false)
    end
    y = y - 8

    addSectionHeader("Filter")
    addLabel("Show")

    local dropdown = addDropdown("GoalsDamageTrackerDropdown")
    attachSideTooltip(dropdown, "Choose which entries to show in the combat tracker.")
    self:SetupDropdown(dropdown, function()
        return self:GetDamageTrackerDropdownList()
    end, function(value)
        self.damageTrackerFilter = value
        self:SetCombatShowMode(value)
        self:UpdateDamageTrackerList()
    end, COMBAT_SHOW_ALL)
    local initialMode = self:GetCombatShowMode(Goals.db and Goals.db.settings or {})
    dropdown.selectedValue = initialMode
    UIDropDownMenu_SetSelectedValue(dropdown, initialMode)
    self:SetDropdownText(dropdown, initialMode)
    self.damageTrackerDropdown = dropdown
    self.damageTrackerFilter = initialMode
    self.combatLogShowDropdown = nil
    y = y - 8
    addSectionHeader(L.LABEL_DAMAGE_OPTIONS)

    local function clampSliderValue(value)
        local clamped = math.floor((tonumber(value) or 0) + 0.5)
        if clamped < 0 then
            clamped = 0
        elseif clamped > 100 then
            clamped = 100
        end
        return clamped
    end

    local bigThresholdSlider, bigThresholdValue = addSlider("GoalsCombatBigThresholdSlider", "Big number threshold", "Set the big number cutoff. 0% shows all numbers; 100% shows only the highest value in each encounter.")
    bigThresholdSlider:SetScript("OnValueChanged", function(selfSlider, value)
        local clamped = clampSliderValue(value)
        if clamped ~= value then
            selfSlider:SetValue(clamped)
        end
        if Goals.db and Goals.db.settings then
            Goals.db.settings.combatLogBigThreshold = clamped
        end
        if bigThresholdValue then
            bigThresholdValue:SetText(string.format("%d%%", clamped))
        end
        if Goals.UI and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
    end)
    self.combatLogBigThresholdSlider = bigThresholdSlider
    self.combatLogBigThresholdValue = bigThresholdValue

    local showBossHealingCheck = addCheck("Show boss/trash healing", function(selfBtn)
        Goals.db.settings.combatLogShowBossHealing = selfBtn:GetChecked() and true or false
        if Goals.UI and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
    end, "Show healing done by bosses/trash.")
    self.combatLogShowBossHealingCheck = showBossHealingCheck

    local showThreatAbilityCheck = addCheck("Show threat ability events", function(selfBtn)
        Goals.db.settings.combatLogShowThreatAbilities = selfBtn:GetChecked() and true or false
        if Goals.UI and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
    end, "Show entries when players use explicit threat up/down/transfer abilities.")
    self.combatLogShowThreatAbilitiesCheck = showThreatAbilityCheck

    local combinePeriodicCheck = addCheck("Combine periodic ticks", function(selfBtn)
        Goals.db.settings.combatLogCombinePeriodic = selfBtn:GetChecked() and true or false
        if Goals.DamageTracker and Goals.DamageTracker.RebuildPeriodicCombines then
            Goals.DamageTracker:RebuildPeriodicCombines()
        end
        if Goals.UI and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
    end, "Group periodic ticks into a single entry.")
    self.combatLogCombinePeriodicCheck = combinePeriodicCheck

    local combineAllCheck = addCheck("Collapse repeated events", function(selfBtn)
        Goals.db.settings.combatLogCombineAll = selfBtn:GetChecked() and true or false
        if Goals.UI and Goals.UI.UpdateDamageTrackerList then
            Goals.UI:UpdateDamageTrackerList()
        end
    end, "Collapse repeated combat entries per unit into one line.")
    self.combatLogCombineAllCheck = combineAllCheck

    y = y - 8
    addSectionHeader("Broadcast")
    local broadcastBtn = createOptionsButton(optionsContent)
    styleOptionsButton(broadcastBtn, OPTIONS_CONTROL_WIDTH)
    broadcastBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    broadcastBtn:SetText("Open broadcast panel")
    broadcastBtn:SetScript("OnClick", function()
        if UI and UI.ToggleCombatBroadcastPopout then
            UI:ToggleCombatBroadcastPopout()
        end
    end)
    attachSideTooltip(broadcastBtn, "Open a panel to send recent combat log lines to chat.")
    y = y - 28

    local clearBtn = createOptionsButton(optionsContent)
    styleOptionsButton(clearBtn, OPTIONS_CONTROL_WIDTH)
    clearBtn:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 8, y)
    clearBtn:SetText("Clear combat log")
    clearBtn:SetScript("OnClick", function()
        if Goals.DamageTracker and Goals.DamageTracker.ClearLog then
            Goals.DamageTracker:ClearLog()
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
        if UI and UI.UpdateCombatDebugStatus then
            UI:UpdateCombatDebugStatus()
        end
    end)
    attachSideTooltip(clearBtn, "Clear the current combat log list.")
    y = y - 30
    self.combatLogClearButton = clearBtn

    local contentHeight = math.abs(y) + 40
    optionsContent:SetHeight(contentHeight)
    setScrollBarAlwaysVisible(optionsPanel.scroll, contentHeight)
    optionsPanel.scroll:SetScript("OnShow", function(selfScroll)
        setScrollBarAlwaysVisible(selfScroll, contentHeight)
    end)
end

function UI:CreateHelpTab(page)
    local navInset = CreateFrame("Frame", "GoalsHelpNavInset", page, "GoalsInsetTemplate")
    applyInsetTheme(navInset)
    navInset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    navInset:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
    navInset:SetWidth(190)
    self.helpNavInset = navInset

    local contentInset = CreateFrame("Frame", "GoalsHelpContentInset", page, "GoalsInsetTemplate")
    applyInsetTheme(contentInset)
    contentInset:SetPoint("TOPLEFT", navInset, "TOPRIGHT", 12, 0)
    contentInset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    self.helpContentInset = contentInset
    if page.footer then
        anchorToFooter(navInset, page.footer, 2, nil, 6)
        anchorToFooter(contentInset, page.footer, nil, -2, 6)
    end

    local navTitle = createLabel(navInset, "Help Topics", "GameFontNormal")
    navTitle:SetPoint("TOPLEFT", navInset, "TOPLEFT", 10, -10)

    local navScroll = CreateFrame("ScrollFrame", "GoalsHelpNavScroll", navInset, "FauxScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", navTitle, "BOTTOMLEFT", -2, -6)
    navScroll:SetPoint("BOTTOMRIGHT", navInset, "BOTTOMRIGHT", -26, 10)
    self.helpNavScroll = navScroll

    local rowHeight = 18
    local maxRows = 24
    self.helpNavRows = {}
    for i = 1, maxRows do
        local row = CreateFrame("Button", nil, navInset)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", navScroll, "TOPLEFT", 0, -6 - (i - 1) * rowHeight)
        row:SetPoint("RIGHT", navInset, "RIGHT", -6, 0)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(row)
        row.highlight = highlight
        local selected = row:CreateTexture(nil, "ARTWORK")
        selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selected:SetBlendMode("ADD")
        selected:SetAllPoints(row)
        selected:Hide()
        row.selected = selected
        local expandBtn = CreateFrame("Button", nil, row)
        expandBtn:SetSize(14, 14)
        expandBtn:SetScript("OnClick", function()
            if row.nodeType ~= "folder" then
                return
            end
            self.helpNavState = self.helpNavState or {}
            self.helpNavState[row.nodeId] = not self.helpNavState[row.nodeId]
            self:RefreshHelpNav()
        end)
        row.expandBtn = expandBtn
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        row.text = text
        row:SetScript("OnClick", function()
            if row.nodeType == "folder" then
                self.helpNavState = self.helpNavState or {}
                self.helpNavState[row.nodeId] = not self.helpNavState[row.nodeId]
                self:RefreshHelpNav()
                return
            end
            if row.nodeId then
                self:SelectHelpPage(row.nodeId)
            end
        end)
        self.helpNavRows[i] = row
    end

    local contentTitle = createLabel(contentInset, "Help", "GameFontNormalLarge")
    contentTitle:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 12, -12)
    self.helpContentTitle = contentTitle

    local contentScroll = CreateFrame("ScrollFrame", "GoalsHelpContentScroll", contentInset, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT", contentTitle, "BOTTOMLEFT", -2, -8)
    contentScroll:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -26, 12)
    self.helpContentScroll = contentScroll

    local contentChild = CreateFrame("Frame", nil, contentScroll)
    contentChild:SetPoint("TOPLEFT", contentScroll, "TOPLEFT", 0, 0)
    contentChild:SetPoint("TOPRIGHT", contentScroll, "TOPRIGHT", -20, 0)
    contentChild:SetHeight(200)
    contentScroll:SetScrollChild(contentChild)
    self.helpContentChild = contentChild

    local contentText = contentChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    contentText:SetPoint("TOPLEFT", contentChild, "TOPLEFT", 8, -4)
    contentText:SetPoint("TOPRIGHT", contentChild, "TOPRIGHT", -8, -4)
    contentText:SetJustifyH("LEFT")
    contentText:SetText("")
    self.helpContentText = contentText

    local function updateHelpContentWidth()
        local width = contentScroll:GetWidth() or 0
        if width > 0 then
            local childWidth = math.max(1, width - 24)
            contentChild:SetWidth(childWidth)
            contentText:SetWidth(childWidth - 16)
            if self.helpContentText then
                local height = (self.helpContentText:GetStringHeight() or 0) + 12
                self.helpContentChild:SetHeight(height)
            end
        end
    end

    contentInset:SetScript("OnSizeChanged", updateHelpContentWidth)
    contentScroll:SetScript("OnShow", updateHelpContentWidth)
    navScroll:SetScript("OnSizeChanged", function()
        self:RefreshHelpNav()
    end)

    self.helpNodes = {
        {
            id = "home",
            title = "Home / About",
            type = "page",
            content = "GOALS is a DKP-style boss and loot tracker for Wrath 3.3.5a.\n\n" ..
                "What it does:\n" ..
                "- Track boss kills, attendance, and point changes.\n" ..
                "- Record loot assignments and history.\n" ..
                "- Maintain a wishlist with gems, enchants, and required tokens.\n" ..
                "- Notify you when wishlist items are found.\n\n" ..
                "Who it is for:\n" ..
                "- Raid leaders, loot masters, and guild admins.\n" ..
                "- Players who want a clean, searchable wishlist.\n\n" ..
                "Project:\n" ..
                "- GitHub: https://github.com/ErebusAres/GOALS/\n" ..
                "- Author: ErebusAres\n" ..
                "- Discord: erebusares\n" ..
                "- Bug reports: open an issue on GitHub with steps and errors.\n\n" ..
                "Tip: After updates, use /reload to refresh UI state.",
        },
                {
                    id = "getting_started",
                    title = "Getting Started",
                    type = "page",
                    content = "Quick start:\n" ..
                        "1) Open GOALS and choose the tab you need.\n" ..
                        "2) Use Overview to see the roster and points.\n" ..
                        "3) Use Loot to assign items and adjust points.\n" ..
                        "4) Use Wishlist to track personal upgrades.\n\n" ..
                        "Commands and shortcuts:\n" ..
                        "- /goals opens the main UI.\n" ..
                        "- /dkp opens the main UI.\n" ..
                        "- /goalsui opens the main UI.\n" ..
                        "- /goals mini toggles the Mini Viewer.\n" ..
                        "- /goals dev on|off|toggle|status controls dev mode.\n" ..
                        "- Alt-click the minimap icon to toggle the Mini Viewer.\n\n" ..
                        "Keybindings:\n" ..
                        "- Toggle GOALS UI (set in Key Bindings).\n" ..
                        "- Toggle Mini Viewer (set in Key Bindings).\n\n" ..
                        "Example: first raid flow:\n" ..
                        "- Track boss kills to award points.\n" ..
                        "- Assign loot as it drops.\n" ..
                        "- Check History to verify assignments.\n\n" ..
                        "Tip: Use Search to cache items by name, ID, or in-game link.",
                },
        {
            id = "overview_folder",
            title = "Overview",
            type = "folder",
            children = {
                {
                    id = "overview_basics",
                    title = "Overview Basics",
                    type = "page",
                    content = "Overview shows roster, attendance, and points at a glance.\n\n" ..
                        "Use filters to focus on present players, and watch point changes after boss kills or loot.\n\n" ..
                        "Tip: Keep Overview open during raids to monitor point swings.",
                },
                {
                    id = "overview_mini_viewer",
                    title = "Mini Viewer",
                    type = "page",
                    content = "Mini Viewer is a compact tracker that stays on screen during raids.\n\n" ..
                        "Use it to watch key info without keeping the full UI open.\n\n" ..
                        "Commands and shortcuts:\n" ..
                        "- Alt-click the minimap icon to toggle it.\n\n" ..
                        "Keybinding:\n" ..
                        "- Toggle Mini Viewer (set in Key Bindings).\n\n" ..
                        "Tip: Toggle it in Settings and reposition it if needed.",
                },
                {
                    id = "overview_roster",
                    title = "Roster and Filters",
                    type = "page",
                    content = "Use roster filters to focus on roles or specific players.\n\n" ..
                        "The Present Only toggle helps hide absentees.\n\n" ..
                        "Example: switch to Present Only before loot assignment.",
                },
                {
                    id = "overview_points",
                    title = "Point Tracking",
                    type = "page",
                    content = "Point tracking updates from boss kills and loot assignments.\n\n" ..
                        "Admins can disable tracking for testing or special events.\n\n" ..
                        "Note: When disabled, kills and minimum rank items do not change points.",
                },
                {
                    id = "overview_present",
                    title = "Present Only",
                    type = "page",
                    content = "Present Only limits the roster to players currently in raid.\n\n" ..
                        "Useful when distributing loot mid-raid.\n\n" ..
                        "Tip: Toggle off to review absent players after the raid.",
                },
            },
        },
        {
            id = "loot_folder",
            title = "Loot",
            type = "folder",
            children = {
                {
                    id = "loot_assign",
                    title = "Assigning Loot",
                    type = "page",
                    content = "Use the Loot tab to assign items to players.\n\n" ..
                        "You can set amounts, reasons, and see who is eligible.\n\n" ..
                        "Example:\n" ..
                        "- Select an item.\n" ..
                        "- Choose the recipient(s).\n" ..
                        "- Confirm to log the entry.",
                },
                {
                    id = "loot_found",
                    title = "Found Loot",
                    type = "page",
                    content = "Found Loot lists nearby drops and lets you assign quickly.\n\n" ..
                        "Right-click entries to move them into assignments.\n\n" ..
                        "Tip: This is fastest for farm content or badge runs.",
                },
                {
                    id = "loot_multi",
                    title = "Multi-Recipient Loot",
                    type = "page",
                    content = "When more than two players receive the same item, the history entry shows a grouped line.\n\n" ..
                        "This keeps logs readable for badge-style drops.\n\n" ..
                        "Example: \"Gave 5 Players: Badge of Justice\".",
                },
                {
                    id = "loot_manual",
                    title = "Manual Adjustments",
                    type = "page",
                    content = "Use Manual Adjust for point changes outside normal loot flow.\n\n" ..
                        "Always record a reason for auditing.\n\n" ..
                        "Tip: Use consistent reasons to keep logs clean.",
                },
            },
        },
        {
            id = "history_folder",
            title = "History",
            type = "folder",
            children = {
                {
                    id = "history_boss",
                    title = "Boss History",
                    type = "page",
                    content = "Boss history shows kills and point awards.\n\n" ..
                        "Use it to review attendance and raid pace.\n\n" ..
                        "Tip: Confirm kill counts after raid end.",
                },
                {
                    id = "history_loot",
                    title = "Loot History",
                    type = "page",
                    content = "Loot history records item awards and point changes.\n\n" ..
                        "Entries show time, recipient(s), and item links.\n\n" ..
                        "Tip: Use it to resolve loot disputes quickly.",
                },
                {
                    id = "history_filters",
                    title = "Filtering History",
                    type = "page",
                    content = "Use filters to narrow results by player or item.\n\n" ..
                        "This helps resolve disputes quickly.\n\n" ..
                        "Example: filter to a player to audit their loot.",
                },
            },
        },
        {
            id = "wishlist_folder",
            title = "Wishlist",
            type = "folder",
            children = {
                {
                    id = "wishlist_basics",
                    title = "Wishlist Basics",
                    type = "page",
                    content = "Wishlist stores gear goals by slot.\n\n" ..
                        "Select a slot and add items from Search to track upgrades.\n\n" ..
                        "Tip: The icon border highlights the selected slot.",
                },
                {
                    id = "wishlist_search",
                    title = "Search",
                    type = "page",
                    content = "Search supports item names, IDs, or in-game item links.\n\n" ..
                        "Paste a link to cache it instantly.\n\n" ..
                        "Examples:\n" ..
                        "- Name: \"Cataclysm Headguard\"\n" ..
                        "- ID: 30166\n" ..
                        "- Link: |cff...|Hitem:30166:...|h[Cataclysm Headguard]|h|r",
                },
                {
                    id = "wishlist_slots",
                    title = "Slots and Claims",
                    type = "page",
                    content = "Click a slot to select it. Right-click clears the slot.\n\n" ..
                        "Alt-click marks found/unfound manually.\n\n" ..
                        "Tip: The green checkmark means the item is claimed.",
                },
                {
                    id = "wishlist_gems",
                    title = "Gems and Enchants",
                    type = "page",
                    content = "Use the socket picker to add gems or enchants for a slot.\n\n" ..
                        "Hover icons to view tooltips and IDs.\n\n" ..
                        "Flow:\n" ..
                        "1) Select a slot.\n" ..
                        "2) Open the socket picker.\n" ..
                        "3) Search and Apply.",
                },
                {
                    id = "wishlist_tokens",
                    title = "Required Tokens",
                    type = "page",
                    content = "Required tokens list updates as wishlist items are added.\n\n" ..
                        "Claimed items are removed from the token list.\n\n" ..
                        "Tip: On custom servers, token rules may be adjusted.",
                },
                {
                    id = "wishlist_import",
                    title = "Import / Export",
                    type = "page",
                    content = "Import supports wishlist strings and Wowhead links.\n\n" ..
                        "Export copies your current list for sharing or backup.\n\n" ..
                        "Example: paste a Wowhead gear planner link to import.",
                },
                {
                    id = "wishlist_alerts",
                    title = "Alerts and Popups",
                    type = "page",
                    content = "Wishlist alerts can post to chat and show a popup.\n\n" ..
                        "Toggle sound and popup options in Actions.\n\n" ..
                        "Tip: Use local popup if chat spam is an issue.",
                },
            },
        },
        {
            id = "settings_folder",
            title = "Settings",
            type = "folder",
            children = {
                {
                    id = "settings_general",
                    title = "General Settings",
                    type = "page",
                    content = "Configure minimap, auto-minimize, and sync options here.\n\n" ..
                        "Table tools help manage saved data across sessions.\n\n" ..
                        "Tip: Keep auto-minimize enabled for raid combat.",
                },
                {
                    id = "settings_minimap",
                    title = "Minimap and UI",
                    type = "page",
                    content = "Toggle the minimap icon and configure auto-minimize.\n\n" ..
                        "Use this to keep the UI tidy during combat.\n\n" ..
                        "Tip: You can hide the minimap icon if it gets in the way.",
                },
                {
                    id = "settings_data",
                    title = "Data Management",
                    type = "page",
                    content = "Clear points, players, or history when needed.\n\n" ..
                        "Use these tools carefully before raids.\n\n" ..
                        "Warning: Clear actions are permanent.",
                },
                {
                    id = "settings_dbm",
                    title = "DBM Integration",
                    type = "page",
                    content = "If DBM is installed, you can enable wishlist loot integration.\n\n" ..
                        "Disable it if you prefer the local popup only.\n\n" ..
                        "Tip: DBM integration is auto-detected when available.",
                },
            },
        },
        {
            id = "update_folder",
            title = "Updates",
            type = "folder",
            children = {
                {
                    id = "update_check",
                    title = "Checking for Updates",
                    type = "page",
                    content = "The Update tab compares your version with the latest.\n\n" ..
                        "Use the download link shown to update manually.\n\n" ..
                        "Tip: The tab will glow if an update is available.",
                },
                {
                    id = "update_versions",
                    title = "Versioning",
                    type = "page",
                    content = "Versions follow the addon major/minor scheme.\n\n" ..
                        "The title bar and minimap tooltip show the current version.\n\n" ..
                        "Example: v2.11 means major 2, minor 11.",
                },
            },
        },
        {
            id = "faq",
            title = "FAQ / Troubleshooting",
            type = "page",
            content = "Common fixes:\n" ..
                "- Search results missing: press Refresh in Wishlist.\n" ..
                "- Enchants missing: clear search and reselect the slot.\n" ..
                "- Popups missing: check Actions settings.\n" ..
                "- Sync issues: verify local-only is disabled.\n\n" ..
                "If issues persist:\n" ..
                "- /reload and retry.\n" ..
                "- Report on GitHub with steps and errors.",
        },
    }

    self.helpNodeById = {}
    for _, node in ipairs(self.helpNodes) do
        self.helpNodeById[node.id] = node
        if node.children then
            for _, child in ipairs(node.children) do
                self.helpNodeById[child.id] = child
            end
        end
    end

    self.helpNavState = self.helpNavState or {
        overview_folder = true,
        loot_folder = true,
        history_folder = true,
        wishlist_folder = true,
        settings_folder = true,
        update_folder = true,
    }

    navScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, rowHeight, function()
            UI:RefreshHelpNav()
        end)
    end)

    self.helpSelectedId = self.helpSelectedId or "home"
    self:SelectHelpPage(self.helpSelectedId)
end

function UI:BuildHelpNavList()
    local list = {}
    local function addNode(node, depth)
        if not node then
            return
        end
        table.insert(list, {
            id = node.id,
            title = node.title,
            type = node.type,
            depth = depth or 0,
            node = node,
        })
        if node.type == "folder" then
            local expanded = self.helpNavState and self.helpNavState[node.id]
            if expanded then
                for _, child in ipairs(node.children or {}) do
                    addNode(child, (depth or 0) + 1)
                end
            end
        end
    end
    for _, node in ipairs(self.helpNodes or {}) do
        addNode(node, 0)
    end
    return list
end

function UI:RefreshHelpNav()
    if not self.helpNavScroll or not self.helpNavRows then
        return
    end
    local rows = self.helpNavRows
    local rowHeight = 18
    local navList = self:BuildHelpNavList()
    local offset = FauxScrollFrame_GetOffset(self.helpNavScroll) or 0
    FauxScrollFrame_Update(self.helpNavScroll, #navList, #rows, rowHeight)
    setScrollBarAlwaysVisible(self.helpNavScroll, #navList * rowHeight)

    for i = 1, #rows do
        local row = rows[i]
        local entry = navList[offset + i]
        if entry then
            row:Show()
            row.nodeId = entry.id
            row.nodeType = entry.type
            row.nodeDepth = entry.depth or 0
            local indent = 6 + (entry.depth or 0) * 12

            if row.expandBtn then
                if entry.type == "folder" then
                    row.expandBtn:Show()
                    row.expandBtn:ClearAllPoints()
                    row.expandBtn:SetPoint("LEFT", row, "LEFT", indent, 0)
                    local expanded = self.helpNavState and self.helpNavState[entry.id]
                    row.expandBtn:SetNormalTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                    row.expandBtn:SetPushedTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Down" or "Interface\\Buttons\\UI-PlusButton-Down")
                    row.expandBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                else
                    row.expandBtn:Hide()
                end
            end

            if row.text then
                row.text:ClearAllPoints()
                local textIndent = indent + (entry.type == "folder" and 16 or 4)
                row.text:SetPoint("LEFT", row, "LEFT", textIndent, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text:SetText(entry.title or "")
            end

            if row.selected then
                if entry.id == self.helpSelectedId and entry.type ~= "folder" then
                    row.selected:Show()
                else
                    row.selected:Hide()
                end
            end
        else
            row:Hide()
            row.nodeId = nil
            row.nodeType = nil
            row.nodeDepth = nil
            if row.selected then
                row.selected:Hide()
            end
        end
    end
end

function UI:SelectHelpPage(pageId)
    if not pageId then
        return
    end
    local node = self.helpNodeById and self.helpNodeById[pageId] or nil
    if not node then
        return
    end
    if node.type == "folder" then
        self.helpNavState = self.helpNavState or {}
        self.helpNavState[node.id] = not self.helpNavState[node.id]
        self:RefreshHelpNav()
        return
    end
    self.helpSelectedId = node.id
    if self.helpContentTitle then
        self.helpContentTitle:SetText(node.title or "Help")
    end
    if self.helpContentText then
        self.helpContentText:SetText(node.content or "")
    end
    if self.helpContentText and self.helpContentChild then
        local height = (self.helpContentText:GetStringHeight() or 0) + 12
        self.helpContentChild:SetHeight(height)
    end
    if self.helpContentScroll then
        self.helpContentScroll:SetVerticalScroll(0)
    end
    self:RefreshHelpNav()
end

function UI:CreateUpdateTab(page)
    local inset = CreateFrame("Frame", "GoalsUpdateInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

    local title = createLabel(inset, L.UPDATE_TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)

    local status = createLabel(inset, "", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    self.updateStatusText = status

    local versionLine = createLabel(inset, "", "GameFontHighlightSmall")
    versionLine:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)
    self.updateVersionText = versionLine

    local urlLabel = createLabel(inset, L.UPDATE_DOWNLOAD_LABEL, "GameFontNormal")
    urlLabel:SetPoint("TOPLEFT", versionLine, "BOTTOMLEFT", 0, -12)

    local urlBox = CreateFrame("EditBox", "GoalsUpdateUrlBox", inset, "InputBoxTemplate")
    urlBox:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", -4, -6)
    urlBox:SetSize(520, OPTIONS_EDITBOX_HEIGHT)
    urlBox:SetAutoFocus(false)
    urlBox:SetFontObject("ChatFontNormal")
    urlBox:SetTextInsets(6, 6, 3, 3)
    urlBox:SetScript("OnEditFocusGained", function(selfBox)
        selfBox:HighlightText()
    end)
    urlBox:SetScript("OnMouseUp", function(selfBox)
        if not selfBox:HasFocus() then
            selfBox:SetFocus()
        end
        selfBox:HighlightText()
    end)
    urlBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    urlBox:SetScript("OnTextChanged", function(selfBox, userInput)
        if userInput then
            local locked = selfBox._lockedText or ""
            if selfBox:GetText() ~= locked then
                selfBox:SetText(locked)
                selfBox:HighlightText()
            end
        end
    end)
    urlBox:SetScript("OnShow", function(selfBox)
        if selfBox:GetText() ~= "" then
            selfBox:HighlightText()
        end
    end)
    self.updateUrlText = urlBox

    local downloadBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    downloadBtn:SetSize(120, 20)
    downloadBtn:SetText(L.UPDATE_DOWNLOAD_BUTTON)
    downloadBtn:SetPoint("LEFT", urlLabel, "RIGHT", 8, 0)
    downloadBtn:SetScript("OnClick", function()
        if not UI.updateUrl or UI.updateUrl == "" then
            return
        end
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat(UI.updateUrl)
        else
            Goals:Print(UI.updateUrl)
        end
    end)
    self.updateDownloadButton = downloadBtn

    local copyHint = createLabel(inset, L.UPDATE_COPY_HINT, "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", urlBox, "BOTTOMLEFT", 4, -6)

    local stepsLabel = createLabel(inset, "Quick steps", "GameFontNormal")
    stepsLabel:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", 0, -12)

    local step1 = createLabel(inset, L.UPDATE_STEP1, "GameFontHighlight")
    step1:SetPoint("TOPLEFT", stepsLabel, "BOTTOMLEFT", 0, -6)
    step1:SetWidth(520)
    step1:SetJustifyH("LEFT")

    local step2 = createLabel(inset, L.UPDATE_STEP2, "GameFontHighlight")
    step2:SetPoint("TOPLEFT", step1, "BOTTOMLEFT", 0, -6)
    step2:SetWidth(520)
    step2:SetJustifyH("LEFT")

    local step3 = createLabel(inset, L.UPDATE_STEP3, "GameFontHighlight")
    step3:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -6)
    step3:SetWidth(520)
    step3:SetJustifyH("LEFT")

    local reloadBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 20)
    reloadBtn:SetText(L.UPDATE_RELOAD_BUTTON)
    reloadBtn:SetPoint("LEFT", step3, "RIGHT", 8, 0)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)

    local dismissBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    dismissBtn:SetSize(120, 20)
    dismissBtn:SetText("Dismiss")
    dismissBtn:SetPoint("TOPLEFT", step3, "BOTTOMLEFT", 0, -10)
    dismissBtn:SetScript("OnClick", function()
        local installedMajor, installedMinor, availableMajor, availableMinor = getUpdateInfo()
        local available = isUpdateAvailable()
        if available and Goals and Goals.db and Goals.db.settings then
            Goals.db.settings.updateSeenMajor = availableMajor
            Goals.db.settings.updateSeenVersion = availableMinor
            Goals.db.settings.updateHasBeenSeen = true
            if Goals.UI then
                Goals.UI:RefreshUpdateTab()
                Goals.UI:UpdateUpdateTabGlow()
            end
            Goals:Print("Update dismissed.")
        end
    end)
    self.updateDismissButton = dismissBtn

    self:RefreshUpdateTab()
end

function UI:CreateDevTab(page)
    local inset = CreateFrame("Frame", "GoalsDevInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

    local killBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    killBtn:SetSize(160, 20)
    killBtn:SetText(L.DEV_SIM_KILL)
    killBtn:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -12)
    killBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateBossKill()
    end)

    local wipeBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    wipeBtn:SetSize(160, 20)
    wipeBtn:SetText(L.DEV_SIM_WIPE)
    wipeBtn:SetPoint("TOPLEFT", killBtn, "BOTTOMLEFT", 0, -8)
    wipeBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateWipe()
    end)

    local lootBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    lootBtn:SetSize(160, 20)
    lootBtn:SetText(L.DEV_SIM_LOOT)
    lootBtn:SetPoint("TOPLEFT", wipeBtn, "BOTTOMLEFT", 0, -8)
    lootBtn:SetScript("OnClick", function()
        Goals.Dev:SimulateLoot()
    end)

    local syncBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    syncBtn:SetSize(160, 20)
    syncBtn:SetText("Send Sync")
    syncBtn:SetPoint("TOPLEFT", lootBtn, "BOTTOMLEFT", 0, -8)
    syncBtn:SetScript("OnClick", function()
        if Goals.Comm and Goals.Comm.BroadcastFullSync then
            Goals.Comm:BroadcastFullSync("MANUAL")
            Goals:Print("Sync sent.")
        end
    end)

    local resetUpdateBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    resetUpdateBtn:SetSize(160, 20)
    resetUpdateBtn:SetText("Reset Update Seen")
    resetUpdateBtn:SetPoint("TOPLEFT", syncBtn, "BOTTOMLEFT", 0, -8)
    resetUpdateBtn:SetScript("OnClick", function()
        if Goals.db and Goals.db.settings then
            Goals.db.settings.updateSeenMajor = 0
            Goals.db.settings.updateSeenVersion = 0
            Goals.db.settings.updateAvailableMajor = 0
            Goals.db.settings.updateAvailableVersion = 0
            Goals.db.settings.updateHasBeenSeen = false
            if Goals.UI then
                Goals.UI:RefreshUpdateTab()
                Goals.UI:UpdateUpdateTabGlow()
            end
            if Goals and Goals.GetInstalledUpdateVersion then
                local installedMajor = Goals:GetUpdateMajorVersion()
                local installedMinor = Goals:GetInstalledUpdateVersion()
                Goals:Print("Update notice reset. Installed v" .. installedMajor .. "." .. installedMinor .. ", available v0.")
            else
                Goals:Print("Update notice reset.")
            end
        end
    end)

    local simulateUpdateBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    simulateUpdateBtn:SetSize(160, 20)
    simulateUpdateBtn:SetText("Simulate Update")
    simulateUpdateBtn:SetPoint("TOPLEFT", resetUpdateBtn, "BOTTOMLEFT", 0, -8)
    simulateUpdateBtn:SetScript("OnClick", function()
        if Goals and Goals.GetInstalledUpdateVersion and Goals.HandleRemoteVersion then
            local installedMajor = Goals:GetUpdateMajorVersion()
            local installedMinor = Goals:GetInstalledUpdateVersion()
            local payload = string.format("%d.%d", installedMajor, installedMinor + 1)
            Goals:HandleRemoteVersion(payload, Goals:GetPlayerName())
            Goals:Print("Simulated update v" .. payload .. ".")
        end
    end)

    local testDbmBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testDbmBtn:SetSize(160, 20)
    testDbmBtn:SetText("Test Wishlist (DBM)")
    testDbmBtn:SetPoint("TOPLEFT", killBtn, "TOPRIGHT", 30, 0)
    testDbmBtn:SetScript("OnClick", function()
        if Goals and Goals.TestWishlistNotification then
            Goals:TestWishlistNotification(nil, true)
        end
    end)

    local testLocalBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testLocalBtn:SetSize(160, 20)
    testLocalBtn:SetText("Test Wishlist (Local)")
    testLocalBtn:SetPoint("TOPLEFT", testDbmBtn, "BOTTOMLEFT", 0, -6)
    testLocalBtn:SetScript("OnClick", function()
        if Goals and Goals.TestWishlistNotification then
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local function getWishlistTestResetDelay()
        local count = 3
        if Goals and Goals.db and Goals.db.settings then
            count = tonumber(Goals.db.settings.devTestWishlistItems) or count
        end
        if count < 1 then
            count = 1
        elseif count > 8 then
            count = 8
        end
        if Goals and Goals.GetDbmLootBannerDuration then
            return Goals:GetDbmLootBannerDuration(count) + 1
        end
        return 8
    end

    local testArcaneBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneBtn:SetSize(160, 20)
    testArcaneBtn:SetText("Test Local (Arcane)")
    testArcaneBtn:SetPoint("TOPLEFT", testLocalBtn, "BOTTOMLEFT", 0, -6)
    testArcaneBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local testArcaneBagBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneBagBtn:SetSize(160, 20)
    testArcaneBagBtn:SetText("Test Local (NewBag)")
    testArcaneBagBtn:SetPoint("TOPLEFT", testArcaneBtn, "BOTTOMLEFT", 0, -6)
    testArcaneBagBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow-NewBag"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local testArcaneGlowMetalBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    testArcaneGlowMetalBtn:SetSize(160, 20)
    testArcaneGlowMetalBtn:SetText("Test Local (GlowMetal)")
    testArcaneGlowMetalBtn:SetPoint("TOPLEFT", testArcaneBagBtn, "BOTTOMLEFT", 0, -6)
    testArcaneGlowMetalBtn:SetScript("OnClick", function()
        if Goals and Goals.ApplyWishlistBannerTexture and Goals.TestWishlistNotification then
            local path = "Interface\\AddOns\\Goals\\Texture\\BossBannerToast\\ArcaneGlow-NewBag-GlowMetal"
            Goals.WishlistBannerTextureTest = true
            Goals:ApplyWishlistBannerTexture(path)
            Goals:TestWishlistNotification(nil, false)
        end
    end)

    local combatTitle = createLabel(inset, "Combat Testing", "GameFontNormal")
    combatTitle:SetPoint("TOPLEFT", testDbmBtn, "TOPRIGHT", 30, 0)

    local combatAmountLabel = createLabel(inset, "Amount", "GameFontHighlightSmall")
    combatAmountLabel:SetPoint("TOPLEFT", combatTitle, "BOTTOMLEFT", 0, -6)

    local combatAmountBox = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    combatAmountBox:SetSize(60, 18)
    combatAmountBox:SetPoint("LEFT", combatAmountLabel, "RIGHT", 6, 0)
    combatAmountBox:SetNumeric(true)
    combatAmountBox:SetMaxLetters(6)
    combatAmountBox:SetAutoFocus(false)
    combatAmountBox:SetText("1234")
    bindEscapeClear(combatAmountBox)
    self.devCombatAmountBox = combatAmountBox

    local combatDamageBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatDamageBtn:SetSize(170, 20)
    combatDamageBtn:SetText("Self Damage")
    combatDamageBtn:SetPoint("TOPLEFT", combatAmountLabel, "BOTTOMLEFT", 0, -6)
    combatDamageBtn:SetScript("OnClick", function()
        local amount = tonumber(combatAmountBox:GetText()) or 1000
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfDamage then
            Goals.Dev:SimulateSelfDamage(amount)
        end
    end)

    local combatHealBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatHealBtn:SetSize(170, 20)
    combatHealBtn:SetText("Self Heal")
    combatHealBtn:SetPoint("TOPLEFT", combatDamageBtn, "BOTTOMLEFT", 0, -6)
    combatHealBtn:SetScript("OnClick", function()
        local amount = tonumber(combatAmountBox:GetText()) or 1000
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfHeal then
            Goals.Dev:SimulateSelfHeal(amount)
        end
    end)

    local combatDeathBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatDeathBtn:SetSize(170, 20)
    combatDeathBtn:SetText("Self Death")
    combatDeathBtn:SetPoint("TOPLEFT", combatHealBtn, "BOTTOMLEFT", 0, -6)
    combatDeathBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfDeath then
            Goals.Dev:SimulateSelfDeath()
        end
    end)

    local combatResBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatResBtn:SetSize(170, 20)
    combatResBtn:SetText("Self Res")
    combatResBtn:SetPoint("TOPLEFT", combatDeathBtn, "BOTTOMLEFT", 0, -6)
    combatResBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateSelfResurrect then
            Goals.Dev:SimulateSelfResurrect()
        end
    end)

    local combatStartBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatStartBtn:SetSize(170, 20)
    combatStartBtn:SetText("Encounter Start")
    combatStartBtn:SetPoint("TOPLEFT", combatResBtn, "BOTTOMLEFT", 0, -10)
    combatStartBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterStart then
            Goals.Dev:SimulateEncounterStart()
        end
    end)

    local combatEndSuccessBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatEndSuccessBtn:SetSize(170, 20)
    combatEndSuccessBtn:SetText("Encounter End (Success)")
    combatEndSuccessBtn:SetPoint("TOPLEFT", combatStartBtn, "BOTTOMLEFT", 0, -6)
    combatEndSuccessBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterEnd then
            Goals.Dev:SimulateEncounterEnd(true)
        end
    end)

    local combatEndFailBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    combatEndFailBtn:SetSize(170, 20)
    combatEndFailBtn:SetText("Encounter End (Wipe)")
    combatEndFailBtn:SetPoint("TOPLEFT", combatEndSuccessBtn, "BOTTOMLEFT", 0, -6)
    combatEndFailBtn:SetScript("OnClick", function()
        if Goals and Goals.Dev and Goals.Dev.SimulateEncounterEnd then
            Goals.Dev:SimulateEncounterEnd(false)
        end
    end)

    local socketLinkBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    socketLinkBtn:SetSize(170, 20)
    socketLinkBtn:SetText("Socket Link (29991)")
    socketLinkBtn:SetPoint("TOPLEFT", testDbmBtn, "TOPRIGHT", 190, 0)
    socketLinkBtn:SetScript("OnClick", function()
        if Goals and Goals.BuildFullItemLinkWithSockets then
            local link = Goals:BuildFullItemLinkWithSockets(29991, nil, 0, { 24029, 24029, 24029 })
            if link and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(link)
                DEFAULT_CHAT_FRAME:AddMessage(link:gsub("|", "||"))
            end
        end
    end)

    local socketLinkBtn2 = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    socketLinkBtn2:SetSize(170, 20)
    socketLinkBtn2:SetText("Socket Link (30166)")
    socketLinkBtn2:SetPoint("TOPLEFT", socketLinkBtn, "BOTTOMLEFT", 0, -6)
    socketLinkBtn2:SetScript("OnClick", function()
        if Goals and Goals.BuildFullItemLinkWithSockets then
            local link = Goals:BuildFullItemLinkWithSockets(30166, nil, 35445, { 25901, 30547 })
            if link and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(link)
                DEFAULT_CHAT_FRAME:AddMessage(link:gsub("|", "||"))
            end
        end
    end)

    local enchantInfoBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    enchantInfoBtn:SetSize(170, 20)
    enchantInfoBtn:SetText("Print Enchant IDs")
    enchantInfoBtn:SetPoint("TOPLEFT", socketLinkBtn2, "BOTTOMLEFT", 0, -6)
    enchantInfoBtn:SetScript("OnClick", function()
        local entry = nil
        if Goals and Goals.UI and Goals.UI.selectedWishlistEnchantResult then
            entry = Goals.UI.selectedWishlistEnchantResult
        end
        local enchantId = entry and entry.id or nil
        if not enchantId and Goals and Goals.GetActiveWishlist and Goals.UI then
            local slotKey = Goals.UI.selectedWishlistSlot
            local list = Goals:GetActiveWishlist()
            local slotEntry = slotKey and list and list.items and list.items[slotKey] or nil
            enchantId = slotEntry and slotEntry.enchantId or nil
        end
        if not enchantId then
            if Goals and Goals.Print then
                Goals:Print("No enchant selected.")
            end
            return
        end
        local info = Goals.GetEnchantInfoById and Goals:GetEnchantInfoById(enchantId) or nil
        local spellId = info and info.spellId or nil
        local name = info and info.name or ("Enchant " .. tostring(enchantId))
        local match = spellId and tostring(spellId) == tostring(enchantId) or false
        local msg = string.format("Enchant ID: %s, Spell ID: %s, Match: %s, Name: %s", tostring(enchantId), tostring(spellId or "nil"), match and "yes" or "no", name)
        if Goals and Goals.Print then
            Goals:Print(msg)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end)

    local devBossCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    devBossCheck:SetPoint("TOPLEFT", simulateUpdateBtn, "BOTTOMLEFT", 0, -12)
    setCheckText(devBossCheck, L.DEV_TEST_BOSS)
    devBossCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.devTestBoss = selfBtn:GetChecked() and true or false
        if Goals.Events and Goals.Events.BuildBossLookup then
            Goals.Events:BuildBossLookup()
        end
    end)
    self.devBossCheck = devBossCheck

    local debugCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", devBossCheck, "BOTTOMLEFT", 0, -8)
    setCheckText(debugCheck, "Enable debug log")
    debugCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.debug = selfBtn:GetChecked() and true or false
    end)
    self.debugCheck = debugCheck

    local wishlistChatCheck = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
    wishlistChatCheck:SetPoint("TOPLEFT", testArcaneGlowMetalBtn, "BOTTOMLEFT", 0, -10)
    setCheckText(wishlistChatCheck, "Test wishlist chat messages")
    wishlistChatCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.devTestWishlistChat = selfBtn:GetChecked() and true or false
    end)
    self.wishlistChatCheck = wishlistChatCheck

    local wishlistCountLabel = createLabel(inset, "Test wishlist items (1-8)", "GameFontNormalSmall")
    wishlistCountLabel:SetPoint("TOPLEFT", wishlistChatCheck, "BOTTOMLEFT", 0, -10)
    local wishlistCountBox = CreateFrame("EditBox", "GoalsDevWishlistCountBox", inset, "InputBoxTemplate")
    wishlistCountBox:SetSize(40, 18)
    wishlistCountBox:SetPoint("LEFT", wishlistCountLabel, "RIGHT", 8, 0)
    wishlistCountBox:SetNumeric(true)
    wishlistCountBox:SetMaxLetters(2)
    wishlistCountBox:SetAutoFocus(false)
    wishlistCountBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        local value = tonumber(selfBox:GetText()) or 1
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        Goals.db.settings.devTestWishlistItems = value
        selfBox:SetText(tostring(value))
    end)
    self.wishlistTestCountBox = wishlistCountBox

    local updateDebug = createLabel(inset, "", "GameFontHighlightSmall")
    updateDebug:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 12, 10)
    updateDebug:SetWidth(520)
    updateDebug:SetJustifyH("LEFT")
    self.updateDebugText = updateDebug
end

function UI:CreateDebugTab(page)
    local inset = CreateFrame("Frame", "GoalsDebugInset", page, "GoalsInsetTemplate")
    applyInsetTheme(inset)
    inset:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -12)
    inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    if page.footer then
        anchorToFooter(inset, page.footer, 2, -2, 6)
    end

    local combatLabel = createLabel(inset, "Combat Tracker", "GameFontNormal")
    combatLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    local combatBar = applySectionHeader(combatLabel, inset, -44)
    applySectionCaption(combatBar, "Debug")

    local combatLast = createLabel(inset, "Last CLEU: --", "GameFontHighlightSmall")
    combatLast:SetPoint("TOPLEFT", combatLabel, "BOTTOMLEFT", 0, -4)
    combatLast:SetJustifyH("LEFT")
    self.combatDebugLast = combatLast

    local combatCount = createLabel(inset, "CLEU events: 0 | Log entries: 0", "GameFontHighlightSmall")
    combatCount:SetPoint("TOPLEFT", combatLast, "BOTTOMLEFT", 0, -2)
    combatCount:SetJustifyH("LEFT")
    self.combatDebugCount = combatCount

    local testDamageBtn = CreateFrame("Button", "GoalsDebugTestDamageButton", inset, "UIPanelButtonTemplate")
    testDamageBtn:SetSize(120, 20)
    testDamageBtn:SetText("Test Damage")
    testDamageBtn:SetPoint("TOPLEFT", combatCount, "BOTTOMLEFT", 0, -6)
    testDamageBtn:SetScript("OnClick", function()
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or "Player"
        if Goals and Goals.DamageTracker and Goals.DamageTracker.AddEntry then
            Goals.DamageTracker:AddEntry({
                ts = time(),
                player = playerName,
                amount = 5,
                spell = "Debug Hit",
                source = "Debug",
                kind = "DAMAGE",
            })
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
    end)
    self.debugTestDamageButton = testDamageBtn

    local testHealBtn = CreateFrame("Button", "GoalsDebugTestHealButton", inset, "UIPanelButtonTemplate")
    testHealBtn:SetSize(120, 20)
    testHealBtn:SetText("Test Heal")
    testHealBtn:SetPoint("LEFT", testDamageBtn, "RIGHT", 6, 0)
    testHealBtn:SetScript("OnClick", function()
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or "Player"
        if Goals and Goals.DamageTracker and Goals.DamageTracker.AddEntry then
            Goals.DamageTracker:AddEntry({
                ts = time(),
                player = playerName,
                amount = 5,
                spell = "Debug Heal",
                source = "Debug",
                kind = "HEAL",
            })
        end
        if UI and UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
    end)
    self.debugTestHealButton = testHealBtn

    local title = createLabel(inset, "Debug Log", "GameFontNormal")
    title:SetPoint("TOPLEFT", testDamageBtn, "BOTTOMLEFT", 0, -16)
    local debugBar = applySectionHeader(title, inset, -6)
    applySectionCaption(debugBar, "Logs")

    local clearBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 20)
    clearBtn:SetText("Clear Log")
    clearBtn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -10)
    clearBtn:SetScript("OnClick", function()
        if Goals and Goals.ClearDebugLog then
            Goals:ClearDebugLog()
        end
    end)
    self.debugClearButton = clearBtn

    local copyBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 20)
    copyBtn:SetText("Copy Log")
    copyBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
    copyBtn:SetScript("OnClick", function()
        if UI and UI.PopulateDebugCopy then
            UI:PopulateDebugCopy()
        end
    end)
    self.debugCopyButton = copyBtn

    local hint = createLabel(inset, "Select all text below and copy to share.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    self.debugCopyHint = hint

    local logScroll = CreateFrame("ScrollFrame", "GoalsDebugCopyScroll", inset, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -2, -6)
    logScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 12)
    self.debugCopyScroll = logScroll
    self.debugLogScroll = logScroll
    self.debugLogRows = nil

    local edit = CreateFrame("EditBox", nil, logScroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(logScroll:GetWidth())
    bindEscapeClear(edit)
    logScroll:SetScrollChild(edit)
    logScroll:SetScript("OnSizeChanged", function(selfScroll)
        if edit and edit.SetWidth then
            edit:SetWidth(selfScroll:GetWidth())
        end
    end)
    self.debugCopyBox = edit
end

function UI:EnsureCombatWhisperPopup()
    if not StaticPopupDialogs or StaticPopupDialogs.GOALS_COMBAT_WHISPER then
        return
    end
    StaticPopupDialogs.GOALS_COMBAT_WHISPER = {
        text = "Whisper target",
        button1 = "Send",
        button2 = "Cancel",
        hasEditBox = 1,
        maxLetters = 64,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnShow = function(selfPopup, data)
            local target = data and data.target or ""
            selfPopup.editBox:SetText(target or "")
            selfPopup.editBox:SetFocus()
            selfPopup.editBox:HighlightText()
        end,
        OnAccept = function(selfPopup, data)
            local target = selfPopup.editBox:GetText()
            if target and target ~= "" and data and data.entry and Goals and Goals.UI and Goals.UI.SendCombatEntryToChannel then
                if Goals.db and Goals.db.settings then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = target
                end
                Goals.UI:SendCombatEntryToChannel(data.entry, "WHISPER", target)
            end
        end,
        EditBoxOnEnterPressed = function(selfPopup)
            local parent = selfPopup:GetParent()
            local target = selfPopup:GetText()
            local data = parent and parent.data or nil
            if target and target ~= "" and data and data.entry and Goals and Goals.UI and Goals.UI.SendCombatEntryToChannel then
                if Goals.db and Goals.db.settings then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = target
                end
                Goals.UI:SendCombatEntryToChannel(data.entry, "WHISPER", target)
            end
            parent:Hide()
        end,
    }
end

function UI:ShowCombatWhisperPopup(entry, defaultTarget)
    self:EnsureCombatWhisperPopup()
    if StaticPopup_Show then
        StaticPopup_Show("GOALS_COMBAT_WHISPER", nil, nil, { entry = entry, target = defaultTarget })
    end
end

function UI:SendCombatEntryToChannel(entry, channel, target)
    local line = self:FormatCombatBroadcastLine(entry)
    if not line or line == "" then
        return
    end
    if channel == "WHISPER_TARGET" then
        if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
            target = UnitName and UnitName("target") or target
            channel = "WHISPER"
        end
    end
    self:SendCombatChatLine(line, channel, target)
end

function UI:ShowCombatRowMenu(entry, anchor)
    if not entry then
        return
    end
    if not self.combatRowMenu then
        self.combatRowMenu = CreateFrame("Frame", "GoalsCombatRowMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = self.combatRowMenu
    menu.entry = entry
    local preview = self:FormatCombatBroadcastLine(entry)
    UIDropDownMenu_Initialize(menu, function(_, level)
        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            info.isTitle = true
            info.text = "Send To..."
            UIDropDownMenu_AddButton(info, level)

            local inRaid = Goals and Goals.IsInRaid and Goals:IsInRaid()
            local inParty = Goals and Goals.IsInParty and Goals:IsInParty() and (GetNumPartyMembers and GetNumPartyMembers() > 0)
            local isLeader = Goals and Goals.IsGroupLeader and Goals:IsGroupLeader()

            if inRaid then
                if isLeader then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Raid"
                    info.value = "RAID_MENU"
                    info.hasArrow = true
                    info.tooltipTitle = "Raid"
                    info.tooltipText = preview
                    UIDropDownMenu_AddButton(info, level)
                else
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Raid"
                    info.func = function() UI:SendCombatEntryToChannel(entry, "RAID") end
                    info.tooltipTitle = "Raid"
                    info.tooltipText = preview
                    UIDropDownMenu_AddButton(info, level)
                end
            end

            if inParty then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Party"
                info.func = function() UI:SendCombatEntryToChannel(entry, "PARTY") end
                info.tooltipTitle = "Party"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Local"
            info.func = function() UI:SendCombatEntryToChannel(entry, "SAY") end
            info.tooltipTitle = "Local"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)

            if IsInGuild and IsInGuild() then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Guild"
                info.func = function() UI:SendCombatEntryToChannel(entry, "GUILD") end
                info.tooltipTitle = "Guild"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Whisper Target"
                info.func = function() UI:SendCombatEntryToChannel(entry, "WHISPER_TARGET") end
                info.tooltipTitle = "Whisper Target"
                info.tooltipText = preview
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Whisper..."
            info.func = function() UI:ShowCombatWhisperPopup(entry, Goals.db.settings.combatLogBroadcastWhisperTarget or "") end
            info.tooltipTitle = "Whisper..."
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)
        elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "RAID_MENU" then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Raid"
            info.func = function() UI:SendCombatEntryToChannel(entry, "RAID") end
            info.tooltipTitle = "Raid"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Raid Warning"
            info.func = function() UI:SendCombatEntryToChannel(entry, "RAID_WARNING") end
            info.tooltipTitle = "Raid Warning"
            info.tooltipText = preview
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    ToggleDropDownMenu(1, nil, menu, anchor, 0, 0)
end

function UI:CreateCombatBroadcastPopout()
    if self.combatBroadcastPopout then
        return
    end
    local frame = CreateFrame("Frame", "GoalsCombatBroadcastPopout", UIParent, "GoalsFrameTemplate")
    applyFrameTheme(frame)
    frame:SetSize(OPTIONS_PANEL_WIDTH + 12, 230)
    frame.baseHeight = 190
    frame.whisperExtra = 54
    if self.frame then
        frame:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -2, -34)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    self.combatBroadcastPopout = frame

    if frame.TitleText then
        frame.TitleText:SetText("Combat Broadcast")
        frame.TitleText:Show()
    end

    local content = CreateFrame("Frame", nil, frame, "GoalsInsetTemplate")
    applyInsetTheme(content)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.content = content

    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local y = -24
    local sendLabel = createLabel(content, "Send to", "GameFontNormalSmall")
    sendLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(sendLabel)
    y = y - 18

    local dropdown = CreateFrame("Frame", "GoalsCombatBroadcastChannelDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", content, "TOPLEFT", -6, y)
    styleDropdown(dropdown, OPTIONS_CONTROL_WIDTH)
    self:SetupCombatBroadcastDropdown(dropdown)
    self.combatBroadcastChannelDropdown = dropdown
    y = y - 36
    frame.broadcastYAfterDropdown = y

    local whisperLabel = createLabel(content, "Whisper target", "GameFontNormalSmall")
    whisperLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(whisperLabel)
    local whisperBox = CreateFrame("EditBox", "GoalsCombatBroadcastWhisperBox", content, "InputBoxTemplate")
    whisperBox:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y - 18)
    whisperBox:SetAutoFocus(false)
    whisperBox:SetText(Goals.db.settings.combatLogBroadcastWhisperTarget or "")
    styleOptionsEditBox(whisperBox, OPTIONS_CONTROL_WIDTH)
    self.combatBroadcastWhisperLabel = whisperLabel
    self.combatBroadcastWhisperBox = whisperBox
    y = y - 54
    frame.broadcastYAfterWhisper = y

    local countLabel = createLabel(content, "Lines to send", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsControlLabel(countLabel)
    local countValue = createLabel(content, "9", "GameFontHighlightSmall")
    countValue:SetPoint("TOPRIGHT", content, "TOPLEFT", 8 + OPTIONS_CONTROL_WIDTH, y)
    countValue:SetJustifyH("RIGHT")
    y = y - 18

    local countSlider = CreateFrame("Slider", "GoalsCombatBroadcastCountSlider", content, "OptionsSliderTemplate")
    countSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    styleOptionsSlider(countSlider)
    countSlider:SetMinMaxValues(1, 9)
    countSlider:SetValueStep(1)
    if countSlider.SetObeyStepOnDrag then
        countSlider:SetObeyStepOnDrag(true)
    end
    self.combatBroadcastCountSlider = countSlider
    self.combatBroadcastCountValue = countValue
    y = y - 28

    local sendBtn = createOptionsButton(content)
    styleOptionsButton(sendBtn, OPTIONS_CONTROL_WIDTH)
    sendBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    sendBtn:SetText("Send")
    sendBtn:SetScript("OnClick", function()
        local channel = Goals.db.settings.combatLogBroadcastChannel or "SAY"
        local count = Goals.db.settings.combatLogBroadcastCount or 9
        local target = Goals.db.settings.combatLogBroadcastWhisperTarget or ""
        if channel == "WHISPER" then
            if self.combatBroadcastWhisperBox then
                target = self.combatBroadcastWhisperBox:GetText() or ""
                Goals.db.settings.combatLogBroadcastWhisperTarget = target
            end
            if target == "" then
                if Goals and Goals.Print then
                    Goals:Print("Enter a whisper target.")
                end
                return
            end
        elseif channel == "WHISPER_TARGET" then
            if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
                target = UnitName and UnitName("target") or target
            else
                if Goals and Goals.Print then
                    Goals:Print("No whisper target selected.")
                end
                return
            end
            channel = "WHISPER"
        end
        self:SendCombatBroadcastLines(channel, target, count)
    end)
    attachSideTooltip(sendBtn, "Send recent combat log lines to the selected chat.")

    countSlider:SetScript("OnValueChanged", function(selfSlider, value)
        local val = math.floor((tonumber(value) or 0) + 0.5)
        if val < 1 then
            val = 1
        elseif val > 9 then
            val = 9
        end
        Goals.db.settings.combatLogBroadcastCount = val
        if countValue then
            countValue:SetText(string.format("%d", val))
        end
    end)

    local count = tonumber(Goals.db.settings.combatLogBroadcastCount) or 9
    if count < 1 then
        count = 1
    elseif count > 9 then
        count = 9
    end
    Goals.db.settings.combatLogBroadcastCount = count
    countSlider:SetValue(count)

    self:RefreshCombatBroadcastDropdown()
    self:UpdateCombatBroadcastLayout()

    self.combatBroadcastCountLabel = countLabel
    self.combatBroadcastCountValue = countValue
    self.combatBroadcastCountSlider = countSlider
    self.combatBroadcastSendButton = sendBtn
end

function UI:ToggleCombatBroadcastPopout()
    if not self.combatBroadcastPopout then
        self:CreateCombatBroadcastPopout()
    end
    if not self.combatBroadcastPopout then
        return
    end
    if self.combatBroadcastPopout:IsShown() then
        self.combatBroadcastPopout:Hide()
    else
        self.combatBroadcastPopout:Show()
        self:RefreshCombatBroadcastDropdown()
        self:UpdateCombatBroadcastLayout()
    end
end

function UI:GetCombatBroadcastOptions()
    local options = {}
    local function add(label, value, target)
        table.insert(options, { label = label, value = value, target = target })
    end
    add("Local", "SAY")
    if Goals and Goals.IsInParty and Goals:IsInParty() then
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            add("Party", "PARTY")
        end
    end
    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        add("Raid", "RAID")
        if Goals.IsGroupLeader and Goals:IsGroupLeader() then
            add("Raid Warning", "RAID_WARNING")
        end
    end
    if IsInGuild and IsInGuild() then
        add("Guild", "GUILD")
    end
    if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
        local targetName = UnitName and UnitName("target") or nil
        if targetName and targetName ~= "" then
            add("Whisper Target", "WHISPER_TARGET", targetName)
        end
    end
    add("Whisper", "WHISPER")
    return options
end

function UI:SetupCombatBroadcastDropdown(dropdown)
    if not dropdown then
        return
    end
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local options = self:GetCombatBroadcastOptions()
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.func = function()
                Goals.db.settings.combatLogBroadcastChannel = option.value
                if option.value == "WHISPER_TARGET" and option.target then
                    Goals.db.settings.combatLogBroadcastWhisperTarget = option.target
                end
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                self:SetDropdownText(dropdown, option.label)
                if self.combatBroadcastWhisperBox then
                    if option.value == "WHISPER" then
                        self.combatBroadcastWhisperBox:Show()
                        if self.combatBroadcastWhisperLabel then
                            self.combatBroadcastWhisperLabel:Show()
                        end
                    else
                        self.combatBroadcastWhisperBox:Hide()
                        if self.combatBroadcastWhisperLabel then
                            self.combatBroadcastWhisperLabel:Hide()
                        end
                    end
                end
                if self.UpdateCombatBroadcastLayout then
                    self:UpdateCombatBroadcastLayout()
                end
            end
            info.checked = Goals.db.settings.combatLogBroadcastChannel == option.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function UI:RefreshCombatBroadcastDropdown()
    local dropdown = self.combatBroadcastChannelDropdown
    if not dropdown then
        return
    end
    local options = self:GetCombatBroadcastOptions()
    local selected = Goals.db.settings.combatLogBroadcastChannel or "SAY"
    local selectedLabel = nil
    local whisperTarget = Goals.db.settings.combatLogBroadcastWhisperTarget or ""
    for _, option in ipairs(options) do
        if option.value == selected then
            selectedLabel = option.label
            if option.value == "WHISPER_TARGET" and option.target then
                whisperTarget = option.target
            end
            break
        end
    end
    if not selectedLabel and options[1] then
        selected = options[1].value
        selectedLabel = options[1].label
    end
    Goals.db.settings.combatLogBroadcastChannel = selected
    if whisperTarget ~= "" then
        Goals.db.settings.combatLogBroadcastWhisperTarget = whisperTarget
    end
    UIDropDownMenu_SetSelectedValue(dropdown, selected)
    self:SetDropdownText(dropdown, selectedLabel or L.SELECT_OPTION)
    if self.combatBroadcastWhisperBox then
        if selected == "WHISPER" then
            self.combatBroadcastWhisperBox:Show()
            if self.combatBroadcastWhisperLabel then
                self.combatBroadcastWhisperLabel:Show()
            end
        else
            self.combatBroadcastWhisperBox:Hide()
            if self.combatBroadcastWhisperLabel then
                self.combatBroadcastWhisperLabel:Hide()
            end
        end
    end
    if self.UpdateCombatBroadcastLayout then
        self:UpdateCombatBroadcastLayout()
    end
end

function UI:UpdateCombatBroadcastLayout()
    if not self.combatBroadcastPopout then
        return
    end
    local frame = self.combatBroadcastPopout
    local content = frame.content or frame
    local showWhisper = self.combatBroadcastWhisperBox and self.combatBroadcastWhisperBox:IsShown()
    local height = frame.baseHeight or 170
    if showWhisper then
        height = height + (frame.whisperExtra or 44)
    end
    frame:SetHeight(height)
    if frame.content then
        frame.content:SetHeight(height - 30)
    end

    local countY = frame.broadcastYAfterDropdown or -86
    if showWhisper then
        countY = frame.broadcastYAfterWhisper or countY
    end
    if self.combatBroadcastCountLabel then
        self.combatBroadcastCountLabel:ClearAllPoints()
        self.combatBroadcastCountLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY)
    end
    if self.combatBroadcastCountValue then
        self.combatBroadcastCountValue:ClearAllPoints()
        self.combatBroadcastCountValue:SetPoint("TOPRIGHT", content, "TOPLEFT", 8 + OPTIONS_CONTROL_WIDTH, countY)
    end
    if self.combatBroadcastCountSlider then
        self.combatBroadcastCountSlider:ClearAllPoints()
        self.combatBroadcastCountSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY - 18)
    end
    if self.combatBroadcastSendButton then
        self.combatBroadcastSendButton:ClearAllPoints()
        self.combatBroadcastSendButton:SetPoint("TOPLEFT", content, "TOPLEFT", 8, countY - 46)
    end
end

function UI:UpdateCombatDebugStatus()
    if not self.combatDebugLast or not self.combatDebugCount then
        return
    end
    local debug = Goals and Goals.state and Goals.state.combatLogDebug or nil
    if debug and debug.lastEvent and debug.lastEvent ~= "" then
        local status = ""
        if debug.lastAdded then
            status = " | added"
        elseif debug.lastSkip and debug.lastSkip ~= "" then
            status = " | skip: " .. debug.lastSkip
        end
        self.combatDebugLast:SetText(string.format("Last CLEU: %s (src: %s | dest: %s)%s", debug.lastEvent, debug.lastSource or "?", debug.lastDest or "?", status))
    else
        self.combatDebugLast:SetText("Last CLEU: --")
    end
    local count = debug and debug.count or 0
    local logCount = Goals and Goals.state and Goals.state.damageLog and #Goals.state.damageLog or 0
    self.combatDebugCount:SetText(string.format("CLEU events: %d | Log entries: %d", count, logCount))
end

function UI:UpdateRosterList()
    if not self.rosterScroll or not self.rosterRows then
        return
    end
    local data = self:GetSortedPlayers()
    self.rosterData = data
    local offset = FauxScrollFrame_GetOffset(self.rosterScroll) or 0
    FauxScrollFrame_Update(self.rosterScroll, #data, ROSTER_ROWS, ROW_HEIGHT)
    local contentHeight = #data * ROW_HEIGHT
    self.rosterScroll._contentHeight = contentHeight
    setScrollBarAlwaysVisible(self.rosterScroll, contentHeight)
    local hasAccess = hasModifyAccess()
    for i = 1, ROSTER_ROWS do
        local row = self.rosterRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.playerName = entry.name
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(Goals:GetClassColor(entry.class))
            if not row.pointsText and row.cols and row.cols.points then
                row.pointsText = row.cols.points
            end
            if row.pointsText then
                row.pointsText:SetText(entry.points)
            end
            if entry.present then
                row.icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
            else
                row.icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
            end
            row.icon:SetVertexColor(1, 1, 1)
            row.icon:Show()
            if hasAccess then
                row.add:Show()
                row.sub:Show()
                row.reset:Show()
                row.undo:Show()
                if row.remove then
                    row.remove:Show()
                end
                row.add:Enable()
                row.sub:Enable()
                row.reset:Enable()
                row.undo:Enable()
                if row.remove then
                    row.remove:Enable()
                end
            else
                row.add:Hide()
                row.sub:Hide()
                row.reset:Hide()
                row.undo:Hide()
                if row.remove then
                    row.remove:Hide()
                end
            end
            if Goals:GetUndoPoints(entry.name) == nil then
                row.undo:Disable()
            end
        else
            row:Hide()
            row.playerName = nil
        end
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    if self.presentCheck then
        self.presentCheck:SetChecked(overviewSettings.showPresentOnly and true or false)
    end
    if self.disablePointGainCheck then
        self.disablePointGainCheck:SetChecked(overviewSettings.disablePointGain and true or false)
        local canToggle = hasPointGainAccess()
        setShown(self.disablePointGainCheck, canToggle)
        if self.disablePointGainStatus then
            if canToggle then
                self.disablePointGainStatus:Hide()
            else
                local enabled = not overviewSettings.disablePointGain
                if enabled then
                    self.disablePointGainStatus:SetText("Point tracking: enabled")
                    self.disablePointGainStatus:SetTextColor(0.2, 1, 0.2)
                else
                    self.disablePointGainStatus:SetText("Point tracking: disabled")
                    self.disablePointGainStatus:SetTextColor(1, 0.25, 0.25)
                end
                self.disablePointGainStatus:Show()
            end
        end
    end
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

function UI:RefreshDamageTrackerDropdown()
    if not self.damageTrackerDropdown then
        return
    end
    local list = self:GetDamageTrackerDropdownList()
    local selected = self.damageTrackerFilter or COMBAT_SHOW_ALL
    local found = false
    for _, name in ipairs(list) do
        if name == selected then
            found = true
            break
        end
    end
    if not found then
        selected = COMBAT_SHOW_ALL
        self.damageTrackerFilter = selected
    end
    UIDropDownMenu_SetSelectedValue(self.damageTrackerDropdown, selected)
    self:SetDropdownText(self.damageTrackerDropdown, selected)
end

local function getBossColor()
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[5] then
        local color = ITEM_QUALITY_COLORS[5]
        return color.r, color.g, color.b
    end
    return 1, 0.5, 0
end

local function getSourceColor(entry)
    if not entry then
        return 1, 1, 1
    end
    local kind = entry.sourceKind
    if kind == "boss" then
        return getBossColor()
    end
    if kind == "elite" then
        return ELITE_COLOR[1], ELITE_COLOR[2], ELITE_COLOR[3]
    end
    if kind == "trash" then
        return TRASH_COLOR[1], TRASH_COLOR[2], TRASH_COLOR[3]
    end
    if kind == "player" and entry.source then
        return Goals:GetPlayerColor(entry.source)
    end
    return 1, 1, 1
end

function UI:FormatDamageTrackerEntry(entry)
    if not entry then
        return ""
    end
    local function truncateName(name, maxLen)
        if not name or name == "" then
            return name or ""
        end
        local limit = tonumber(maxLen) or 0
        if limit < 4 then
            return name
        end
        if string.len(name) > limit then
            return string.sub(name, 1, limit - 3) .. "..."
        end
        return name
    end

    local function isPlayerName(name)
        if not name or name == "" then
            return false
        end
        if Goals and Goals.NormalizeName and Goals.DamageTracker and Goals.DamageTracker.rosterNameMap then
            local normalized = Goals:NormalizeName(name)
            return Goals.DamageTracker.rosterNameMap[normalized] and true or false
        end
        if Goals and Goals.GetPlayerName and Goals.NormalizeName then
            return Goals:NormalizeName(name) == Goals:NormalizeName(Goals:GetPlayerName())
        end
        return false
    end

    local function fitName(name)
        if isPlayerName(name) then
            return truncateName(name, DAMAGE_NAME_MAX_PLAYER)
        end
        return truncateName(name, DAMAGE_NAME_MAX_NPC)
    end

    local ts = formatCombatTimestamp(entry.ts)
    local player = entry.player or "Unknown"
    local kind = entry.kind or "DAMAGE"
    local sourceName = ""
    local targetName = ""
    if kind == "DAMAGE" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "THREAT" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "INTERRUPT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "THREAT_ABILITY" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "DAMAGE_OUT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "HEAL" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "HEAL_OUT" then
        sourceName = player
        targetName = entry.source or "Unknown"
    elseif kind == "BOSS_HEAL" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "RES" then
        sourceName = entry.source or "Unknown"
        targetName = player
    elseif kind == "DEATH" then
        sourceName = ""
        targetName = player
    end
    sourceName = fitName(sourceName)
    targetName = fitName(targetName)
    if kind == "DEATH" then
        return string.format("%s | %s | %s | Died |", ts, sourceName, targetName)
    end
    if kind == "THREAT" then
        local reason = entry.reason or "Threat changed"
        return string.format("%s | %s | %s | THREAT | %s", ts, sourceName, targetName, reason)
    end
    if kind == "INTERRUPT" then
        local interruptedText = entry.interruptedSpell or "Interrupted cast"
        local interruptSpell = entry.spell or "Interrupt"
        return string.format("%s | %s | %s | %s | %s", ts, sourceName, targetName, interruptedText, interruptSpell)
    end
    if kind == "THREAT_ABILITY" then
        local reason = entry.reason or "Threat"
        local spellText = entry.spell or "Unknown"
        return string.format("%s | %s | %s | %s | %s", ts, sourceName, targetName, reason, spellText)
    end
    if kind == "BOSS_HEAL" then
        local healAmount = math.floor(tonumber(entry.amount) or 0)
        local healSpell = entry.spell or "Boss heal"
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, healAmount, healSpell)
    end
    if kind == "RES" then
        local spell = entry.spell or "Unknown"
        local amount = math.floor(tonumber(entry.amount) or 0)
        if amount > 0 then
            return string.format("%s | %s | %s | Revived +%d | %s", ts, sourceName, targetName, amount, spell)
        end
        return string.format("%s | %s | %s | Revived | %s", ts, sourceName, targetName, spell)
    end
    local amount = math.floor(tonumber(entry.amount) or 0)
    local spell = entry.spell or "Unknown"
    local showOverheal = false
    if kind == "HEAL" then
        local overheal = math.floor(tonumber(entry.overheal) or 0)
        if showOverheal and overheal > 0 then
            return string.format("%s | %s | %s | +%d (%d) | %s", ts, sourceName, targetName, amount, overheal, spell)
        end
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, amount, spell)
    end
    if kind == "HEAL_OUT" then
        local overheal = math.floor(tonumber(entry.overheal) or 0)
        if showOverheal and overheal > 0 then
            return string.format("%s | %s | %s | +%d (%d) | %s", ts, sourceName, targetName, amount, overheal, spell)
        end
        return string.format("%s | %s | %s | +%d | %s", ts, sourceName, targetName, amount, spell)
    end
    if kind == "DAMAGE_OUT" then
        return string.format("%s | %s | %s | -%d | %s", ts, sourceName, targetName, amount, spell)
    end
    return string.format("%s | %s | %s | -%d | %s", ts, sourceName, targetName, amount, spell)
end

function UI:GetCombatEntrySourceTarget(entry)
    if not entry then
        return "", ""
    end
    local kind = entry.kind or "DAMAGE"
    if kind == "DAMAGE" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "THREAT" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "INTERRUPT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "THREAT_ABILITY" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "BOSS_HEAL" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "DAMAGE_OUT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "HEAL" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "HEAL_OUT" then
        return entry.player or "Unknown", entry.source or "Unknown"
    end
    if kind == "RES" then
        return entry.source or "Unknown", entry.player or "Unknown"
    end
    if kind == "DEATH" then
        return "", entry.player or "Unknown"
    end
    return entry.source or "Unknown", entry.player or "Unknown"
end

function UI:FormatCombatBroadcastLine(entry)
    if not entry or entry.kind == "BREAK" then
        return nil
    end
    local sourceName, targetName = self:GetCombatEntrySourceTarget(entry)
    local showOverheal = false
    local amount = math.floor(tonumber(entry.amount) or 0)
    local overheal = math.floor(tonumber(entry.overheal) or 0)
    local spell = entry.spell or "Unknown"
    local kind = entry.kind or "DAMAGE"
    local prefix = ""
    if sourceName ~= "" then
        prefix = sourceName .. " -> " .. (targetName ~= "" and targetName or "Unknown")
    else
        prefix = targetName ~= "" and targetName or "Unknown"
    end
    local amountText = ""
    local abilityText = spell
    if kind == "HEAL" or kind == "HEAL_OUT" then
        amountText = string.format("+%d", amount)
        if showOverheal and overheal > 0 then
            amountText = string.format("+%d (%d)", amount, overheal)
        end
    elseif kind == "RES" then
        if amount > 0 then
            amountText = string.format("Revived +%d", amount)
        else
            amountText = "Revived"
        end
    elseif kind == "DEATH" then
        amountText = "Died"
        abilityText = ""
    elseif kind == "THREAT" then
        amountText = "THREAT"
        abilityText = entry.reason or "Threat changed"
    elseif kind == "INTERRUPT" then
        amountText = entry.interruptedSpell or "Interrupted cast"
        abilityText = entry.spell or "Interrupt"
    elseif kind == "THREAT_ABILITY" then
        amountText = entry.reason or "THREAT"
        abilityText = entry.spell or "Threat ability"
    elseif kind == "BOSS_HEAL" then
        amountText = string.format("+%d", amount)
        abilityText = entry.spell or "Boss heal"
    else
        amountText = string.format("-%d", amount)
    end
    if abilityText ~= "" and entry.spellDuration and entry.spellDuration > 1 then
        abilityText = string.format("%s (%ds)", abilityText, entry.spellDuration)
    end
    if abilityText ~= "" then
        return string.format("%s %s %s", prefix, amountText, abilityText)
    end
    return string.format("%s %s", prefix, amountText)
end

function UI:SendCombatChatLine(line, channel, target)
    if not line or line == "" then
        return
    end
    if not SendChatMessage then
        return
    end
    if channel == "WHISPER" then
        if target and target ~= "" then
            SendChatMessage(line, "WHISPER", nil, target)
        end
        return
    end
    SendChatMessage(line, channel)
end

function UI:SendCombatBroadcastLines(channel, target, count)
    local tracker = Goals and Goals.DamageTracker
    if not tracker or not tracker.GetFilteredEntries then
        return
    end
    local filter = self.damageTrackerFilter or COMBAT_SHOW_ALL
    local data = tracker:GetFilteredEntries(filter) or {}
    local limit = tonumber(count) or 0
    if limit < 0 then
        limit = 0
    end
    local lines = {}
    for _, entry in ipairs(data) do
        if entry and entry.kind ~= "BREAK" then
            local line = self:FormatCombatBroadcastLine(entry)
            if line and line ~= "" then
                table.insert(lines, line)
                if limit > 0 and #lines >= limit then
                    break
                end
            end
        end
    end
    for i = #lines, 1, -1 do
        self:SendCombatChatLine(lines[i], channel, target)
    end
end

function UI:UpdateDamageTrackerList()
    if not self.damageTrackerScroll or not self.damageTrackerRows then
        return
    end
    local tracker = Goals and Goals.DamageTracker
    local filter = self.damageTrackerFilter or COMBAT_SHOW_ALL
    local data = tracker and tracker.GetFilteredEntries and tracker:GetFilteredEntries(filter, { ignoreBigFilter = true }) or {}
    local offset = FauxScrollFrame_GetOffset(self.damageTrackerScroll) or 0
    FauxScrollFrame_Update(self.damageTrackerScroll, #data, DAMAGE_ROWS, DAMAGE_ROW_HEIGHT)
    local contentHeight = #data * DAMAGE_ROW_HEIGHT
    self.damageTrackerScroll._contentHeight = contentHeight
    setScrollBarAlwaysVisible(self.damageTrackerScroll, contentHeight)
    local settings = Goals and Goals.db and Goals.db.settings or nil
    local threshold = settings and tonumber(settings.combatLogBigThreshold) or nil
    if threshold == nil and settings then
        local oldDamage = tonumber(settings.combatLogBigDamageThreshold)
        local oldHeal = tonumber(settings.combatLogBigHealingThreshold)
        if oldDamage or oldHeal then
            threshold = math.max(oldDamage or 0, oldHeal or 0)
        end
    end
    if threshold == nil then
        threshold = (settings and settings.combatLogShowBig) and 50 or 0
        if settings then
            settings.combatLogBigThreshold = threshold
        end
    end
    if threshold < 0 then
        threshold = 0
    elseif threshold > 100 then
        threshold = 100
    end
    local useBigFilter = threshold > 0
    local sliceStart = offset + 1
    local sliceEnd = math.min(offset + DAMAGE_ROWS, #data)
    local sliceMaxDamage = 0
    local sliceMaxHeal = 0
    if useBigFilter then
        for i = sliceStart, sliceEnd do
            local entry = data[i]
            if entry and entry.kind ~= "BREAK" and entry.kind ~= "DEATH" and entry.kind ~= "RES" then
                local amount = tonumber(entry.amount) or 0
                if entry.kind == "HEAL" or entry.kind == "HEAL_OUT" or entry.kind == "BOSS_HEAL" then
                    if amount > sliceMaxHeal then
                        sliceMaxHeal = amount
                    end
                elseif entry.kind == "DAMAGE" or entry.kind == "DAMAGE_OUT" then
                    if amount > sliceMaxDamage then
                        sliceMaxDamage = amount
                    end
                end
            end
        end
    end
    local function passesSliceThreshold(entry)
        if not useBigFilter or not entry then
            return true
        end
        if entry.kind == "BREAK" or entry.kind == "DEATH" or entry.kind == "RES" then
            return true
        end
        local amount = tonumber(entry.amount) or 0
        if entry.kind == "HEAL" or entry.kind == "HEAL_OUT" or entry.kind == "BOSS_HEAL" then
            if sliceMaxHeal <= 0 then
                return true
            end
            return amount >= (sliceMaxHeal * (threshold / 100))
        end
        if entry.kind == "DAMAGE" or entry.kind == "DAMAGE_OUT" then
            if sliceMaxDamage <= 0 then
                return true
            end
            return amount >= (sliceMaxDamage * (threshold / 100))
        end
        return true
    end
    local visibleEntries = {}
    local visibleIndexes = {}
    if useBigFilter then
        for i = sliceStart, sliceEnd do
            local entry = data[i]
            if entry and passesSliceThreshold(entry) then
                table.insert(visibleEntries, entry)
                table.insert(visibleIndexes, i)
            end
        end
    else
        for i = sliceStart, sliceEnd do
            local entry = data[i]
            if entry then
                table.insert(visibleEntries, entry)
                table.insert(visibleIndexes, i)
            end
        end
    end
    local showOverheal = false
    local function setNameText(font, name, r, g, b)
        if not font then
            return
        end
        font:SetText(name or "")
        if r and g and b then
            font:SetTextColor(r, g, b)
        else
            font:SetTextColor(1, 1, 1)
        end
    end

    local function getPlayerColor(name)
        if Goals and Goals.GetPlayerColor and name and name ~= "" then
            local pr, pg, pb = Goals:GetPlayerColor(name)
            if pr and pg and pb then
                return pr, pg, pb
            end
        end
        return 1, 1, 1
    end

    local function truncateName(name, maxLen)
        if not name or name == "" then
            return name or ""
        end
        local limit = tonumber(maxLen) or 0
        if limit < 4 then
            return name
        end
        if string.len(name) > limit then
            return string.sub(name, 1, limit - 3) .. "..."
        end
        return name
    end

    local function isPlayerName(name)
        if not name or name == "" then
            return false
        end
        if Goals and Goals.NormalizeName and Goals.DamageTracker and Goals.DamageTracker.rosterNameMap then
            local normalized = Goals:NormalizeName(name)
            return Goals.DamageTracker.rosterNameMap[normalized] and true or false
        end
        if Goals and Goals.GetPlayerName and Goals.NormalizeName then
            return Goals:NormalizeName(name) == Goals:NormalizeName(Goals:GetPlayerName())
        end
        return false
    end

    local function fitName(name)
        if isPlayerName(name) then
            return truncateName(name, DAMAGE_NAME_MAX_PLAYER)
        end
        return truncateName(name, DAMAGE_NAME_MAX_NPC)
    end

    for i = 1, DAMAGE_ROWS do
        local row = self.damageTrackerRows[i]
        local entry = visibleEntries[i]
        local entryIndex = visibleIndexes[i] or (offset + i)
        if entry then
            row:Show()
            row.entry = entry
            local isBreak = entry.kind == "BREAK"
            if isBreak then
                if row.stripe then
                    setShown(row.stripe, false)
                end
                setShown(row.breakBg, true)
                setShown(row.breakText, true)
                local label = entry.label or ""
                local ts = formatCombatTimestamp(entry.ts)
                if ts ~= "" then
                    label = ts .. " - " .. label
                end
                row.breakText:SetText(label)
                row.breakText:SetTextColor(0.9, 0.9, 0.9)
                row.timeText:SetText("")
                if row.sourceText then
                    row.sourceText:SetText("")
                end
                if row.targetText then
                    row.targetText:SetText("")
                end
                row.amountText:SetText("")
                row.spellText:SetText("")
            else
                setShown(row.breakBg, false)
                setShown(row.breakText, false)
                if row.stripe then
                    setShown(row.stripe, (entryIndex % 2) == 0)
                end
                row.timeText:SetText(formatCombatTimestamp(entry.ts))
                local kind = entry.kind or "DAMAGE"
                local sourceName = ""
                local targetName = ""
                local sourceColorR, sourceColorG, sourceColorB = 1, 1, 1
                local targetColorR, targetColorG, targetColorB = 1, 1, 1

                if kind == "DAMAGE" then
                    sourceName = entry.source or "Unknown"
                    targetName = entry.player or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                elseif kind == "THREAT" then
                    sourceName = entry.source or "Unknown"
                    targetName = entry.player or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                elseif kind == "INTERRUPT" then
                    sourceName = entry.player or "Unknown"
                    targetName = entry.source or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
                    targetColorR, targetColorG, targetColorB = getSourceColor(entry)
                elseif kind == "THREAT_ABILITY" then
                    sourceName = entry.player or "Unknown"
                    targetName = entry.source or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
                    targetColorR, targetColorG, targetColorB = getSourceColor(entry)
                elseif kind == "BOSS_HEAL" then
                    sourceName = entry.source or "Unknown"
                    targetName = entry.player or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
                    targetColorR, targetColorG, targetColorB = getSourceColor({ sourceKind = entry.targetKind, source = targetName })
                elseif kind == "DAMAGE_OUT" then
                    sourceName = entry.player or "Unknown"
                    targetName = entry.source or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
                    targetColorR, targetColorG, targetColorB = getSourceColor(entry)
                elseif kind == "HEAL" then
                    sourceName = entry.source or "Unknown"
                    targetName = entry.player or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                elseif kind == "HEAL_OUT" then
                    sourceName = entry.player or "Unknown"
                    targetName = entry.source or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getPlayerColor(sourceName)
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                elseif kind == "RES" then
                    sourceName = entry.source or "Unknown"
                    targetName = entry.player or "Unknown"
                    sourceColorR, sourceColorG, sourceColorB = getSourceColor(entry)
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                elseif kind == "DEATH" then
                    sourceName = ""
                    targetName = entry.player or "Unknown"
                    targetColorR, targetColorG, targetColorB = getPlayerColor(targetName)
                end

                sourceName = fitName(sourceName)
                targetName = fitName(targetName)

                setNameText(row.sourceText, sourceName, sourceColorR, sourceColorG, sourceColorB)
                setNameText(row.targetText, targetName, targetColorR, targetColorG, targetColorB)

                if kind == "DEATH" then
                if row.amountText then
                    row.amountText:SetText("Died")
                    row.amountText:SetTextColor(DEATH_COLOR[1], DEATH_COLOR[2], DEATH_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText("")
                end
            elseif kind == "RES" then
                local amount = math.floor(tonumber(entry.amount) or 0)
                if row.amountText then
                    if amount > 0 then
                        row.amountText:SetText(string.format("Revived +%d", amount))
                    else
                        row.amountText:SetText("Revived")
                    end
                    row.amountText:SetTextColor(REVIVE_COLOR[1], REVIVE_COLOR[2], REVIVE_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText(entry.spell or "")
                end
            elseif kind == "HEAL" then
                local amount = math.floor(tonumber(entry.amount) or 0)
                local overheal = math.floor(tonumber(entry.overheal) or 0)
                if row.amountText then
                    if showOverheal and overheal > 0 then
                        row.amountText:SetText(string.format("+%d |cff55aa55(%d)|r", amount, overheal))
                    else
                        row.amountText:SetText(string.format("+%d", amount))
                    end
                    row.amountText:SetTextColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3])
                end
                local spellText = entry.spell or ""
                if entry.spellDuration and entry.spellDuration > 1 then
                    spellText = string.format("%s (%ds)", spellText ~= "" and spellText or "Unknown", entry.spellDuration)
                end
                if row.spellText then
                    row.spellText:SetText(spellText)
                end
            elseif kind == "HEAL_OUT" then
                local amount = math.floor(tonumber(entry.amount) or 0)
                local overheal = math.floor(tonumber(entry.overheal) or 0)
                if row.amountText then
                    if showOverheal and overheal > 0 then
                        row.amountText:SetText(string.format("+%d |cff55aa55(%d)|r", amount, overheal))
                    else
                        row.amountText:SetText(string.format("+%d", amount))
                    end
                    row.amountText:SetTextColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3])
                end
                local spellText = entry.spell or ""
                if entry.spellDuration and entry.spellDuration > 1 then
                    spellText = string.format("%s (%ds)", spellText ~= "" and spellText or "Unknown", entry.spellDuration)
                end
                if row.spellText then
                    row.spellText:SetText(spellText)
                end
            elseif kind == "DAMAGE_OUT" then
                local amount = math.floor(tonumber(entry.amount) or 0)
                if row.amountText then
                    row.amountText:SetText(string.format("-%d", amount))
                    row.amountText:SetTextColor(DAMAGE_COLOR[1], DAMAGE_COLOR[2], DAMAGE_COLOR[3])
                end
                local spellText = entry.spell or ""
                if entry.spellDuration and entry.spellDuration > 1 then
                    spellText = string.format("%s (%ds)", spellText ~= "" and spellText or "Unknown", entry.spellDuration)
                end
                if row.spellText then
                    row.spellText:SetText(spellText)
                end
            elseif kind == "THREAT" then
                if row.amountText then
                    row.amountText:SetText("THREAT")
                    row.amountText:SetTextColor(THREAT_COLOR[1], THREAT_COLOR[2], THREAT_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText(entry.reason or "Threat changed")
                end
            elseif kind == "THREAT_ABILITY" then
                if row.amountText then
                    row.amountText:SetText(entry.reason or "THREAT")
                    row.amountText:SetTextColor(THREAT_COLOR[1], THREAT_COLOR[2], THREAT_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText(entry.spell or "Threat ability")
                end
            elseif kind == "INTERRUPT" then
                if row.amountText then
                    row.amountText:SetText(entry.interruptedSpell or "Interrupted cast")
                    row.amountText:SetTextColor(THREAT_COLOR[1], THREAT_COLOR[2], THREAT_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText(entry.spell or "Interrupt")
                end
            elseif kind == "BOSS_HEAL" then
                local amount = math.floor(tonumber(entry.amount) or 0)
                if row.amountText then
                    row.amountText:SetText(string.format("+%d", amount))
                    row.amountText:SetTextColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3])
                end
                if row.spellText then
                    row.spellText:SetText(entry.spell or "Boss heal")
                end
            else
                local amount = math.floor(tonumber(entry.amount) or 0)
                if row.amountText then
                    local isBigBoss = entry.sourceKind == "boss" and sliceMaxDamage > 0 and amount >= (sliceMaxDamage * 0.8)
                    if isBigBoss then
                        row.amountText:SetText(string.format("-%d !!!", amount))
                        row.amountText:SetTextColor(1, 0.55, 0.1)
                    else
                        row.amountText:SetText(string.format("-%d", amount))
                        row.amountText:SetTextColor(DAMAGE_COLOR[1], DAMAGE_COLOR[2], DAMAGE_COLOR[3])
                    end
                end
                local spellText = entry.spell or ""
                if entry.spellDuration and entry.spellDuration > 1 then
                    spellText = string.format("%s (%ds)", spellText ~= "" and spellText or "Unknown", entry.spellDuration)
                end
                if row.spellText then
                    row.spellText:SetText(spellText)
                end
            end
            end
        else
            row:Hide()
            row.entry = nil
            setShown(row.breakBg, false)
            setShown(row.breakText, false)
            row.timeText:SetText("")
            if row.sourceText then
                row.sourceText:SetText("")
            end
            if row.targetText then
                row.targetText:SetText("")
            end
            if row.amountText then
                row.amountText:SetText("")
            end
            if row.spellText then
                row.spellText:SetText("")
            end
        end
    end
end

function UI:UpdateDebugLogList()
    local data = (Goals and Goals.GetDebugLog and Goals:GetDebugLog()) or {}
    if self.debugCopyBox and Goals and Goals.GetDebugLogText then
        self.debugCopyBox:SetText(Goals:GetDebugLogText() or "")
    end
    if not self.debugLogScroll or not self.debugLogRows then
        return
    end
    local offset = FauxScrollFrame_GetOffset(self.debugLogScroll) or 0
    FauxScrollFrame_Update(self.debugLogScroll, #data, DEBUG_ROWS, DEBUG_ROW_HEIGHT)
    for i = 1, DEBUG_ROWS do
        local row = self.debugLogRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            local ts = entry.ts and formatTime(entry.ts) or ""
            row.text:SetText(string.format("%s %s", ts, entry.msg or ""))
        else
            row:Hide()
            row.text:SetText("")
        end
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

wishlistHasWowhead = function(build)
    if not build then
        return false
    end
    if type(build.tags) == "table" then
        for _, tag in ipairs(build.tags) do
            local value = tostring(tag or ""):lower()
            if value == "wowhead" then
                return true
            end
        end
    end
    if type(build.sources) == "table" then
        for _, source in ipairs(build.sources) do
            local value = tostring(source or ""):lower()
            if value:find("wowhead", 1, true) then
                return true
            end
        end
    end
    return false
end

wishlistHasBistooltip = function(build)
    if not build then
        return false
    end
    if type(build.tags) == "table" then
        for _, tag in ipairs(build.tags) do
            local value = tostring(tag or ""):lower()
            if value == "bistooltip" or value == "bis-tooltip" then
                return true
            end
        end
    end
    if type(build.sources) == "table" then
        for _, source in ipairs(build.sources) do
            local value = tostring(source or ""):lower()
            if value:find("bistooltip", 1, true) then
                return true
            end
        end
    end
    return false
end

    wishlistWowtbcSource = function(build)
        if not build then
            return nil, nil
        end
        local function normalize(value)
            if value:find("wowtbc-gg-wotlk", 1, true) then
                return "wowtbc-gg-wotlk", "wowtbc.gg WotLK"
            end
            if value:find("wowtbc-gg-tbc", 1, true) then
                return "wowtbc-gg-tbc", "wowtbc.gg TBC"
            end
            if value:find("wowtbc-gg-classic", 1, true) then
                return "wowtbc-gg-classic", "wowtbc.gg Classic"
            end
            if value:find("wowtbc.gg", 1, true) then
                local tier = tostring(build.tier or ""):upper()
                if tier:find("WOTLK", 1, true) then
                    return "wowtbc-gg-wotlk", "wowtbc.gg WotLK"
                end
                if tier:find("TBC", 1, true) then
                    return "wowtbc-gg-tbc", "wowtbc.gg TBC"
                end
                if tier:find("CLASSIC", 1, true) then
                    return "wowtbc-gg-classic", "wowtbc.gg Classic"
                end
                return "wowtbc-gg-wotlk", "wowtbc.gg"
            end
            if value:find("custom-wotlk", 1, true) then
                return "custom-wotlk", "Custom WotLK"
            end
            if value:find("custom-tbc", 1, true) then
                return "custom-tbc", "Custom TBC"
            end
            if value:find("custom-classic", 1, true) then
                return "custom-classic", "Custom Classic"
            end
            return nil, nil
        end
    if type(build.tags) == "table" then
        for _, tag in ipairs(build.tags) do
            local value = tostring(tag or ""):lower()
            local key, tooltip = normalize(value)
            if key then
                return key, tooltip
            end
        end
    end
    if type(build.sources) == "table" then
        for _, source in ipairs(build.sources) do
            local value = tostring(source or ""):lower()
            local key, tooltip = normalize(value)
            if key then
                return key, tooltip
            end
        end
    end
    return nil, nil
end

wishlistHasLoon = function(build)
    if not build then
        return false
    end
    if type(build.tags) == "table" then
        for _, tag in ipairs(build.tags) do
            local value = tostring(tag or ""):lower()
            if value == "loonbis" or value == "loon bis" or value == "loonbestinslot" or value == "loon" then
                return true
            end
        end
    end
    if type(build.sources) == "table" then
        for _, source in ipairs(build.sources) do
            local value = tostring(source or ""):lower()
            if value:find("loonbis", 1, true) or value:find("loonbestinslot", 1, true) then
                return true
            end
        end
    end
    return false
end

stripTextureTags = function(text)
    if not text then
        return ""
    end
    local clean = tostring(text)
    clean = clean:gsub("|T.-|t", "")
    clean = clean:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

wishlistSpecKey = function(build)
    if not build or not build.class or not build.spec then
        return nil
    end
    local spec = tostring(build.spec):lower()
    local class = build.class
    if class == "DEATHKNIGHT" then
        if spec:find("blood", 1, true) then return "DEATHKNIGHT_BLOOD" end
        if spec:find("frost", 1, true) then return "DEATHKNIGHT_FROST" end
        if spec:find("unholy", 1, true) then return "DEATHKNIGHT_UNHOLY" end
    elseif class == "DRUID" then
        if spec:find("balance", 1, true) then return "DRUID_BALANCE" end
        if spec:find("feral", 1, true) then return "DRUID_FERAL" end
        if spec:find("restoration", 1, true) then return "DRUID_RESTORATION" end
    elseif class == "HUNTER" then
        if spec:find("beast", 1, true) then return "HUNTER_BEASTMASTERY" end
        if spec:find("marks", 1, true) then return "HUNTER_MARKSMANSHIP" end
        if spec:find("survival", 1, true) then return "HUNTER_SURVIVAL" end
    elseif class == "MAGE" then
        if spec:find("arcane", 1, true) then return "MAGE_ARCANE" end
        if spec:find("fire", 1, true) then return "MAGE_FIRE" end
        if spec:find("frost", 1, true) then return "MAGE_FROST" end
    elseif class == "PALADIN" then
        if spec:find("holy", 1, true) then return "PALADIN_HOLY" end
        if spec:find("protection", 1, true) then return "PALADIN_PROTECTION" end
        if spec:find("retribution", 1, true) then return "PALADIN_RETRIBUTION" end
    elseif class == "PRIEST" then
        if spec:find("discipline", 1, true) then return "PRIEST_DISCIPLINE" end
        if spec:find("holy", 1, true) then return "PRIEST_HOLY" end
        if spec:find("shadow", 1, true) then return "PRIEST_SHADOW" end
    elseif class == "ROGUE" then
        if spec:find("assassination", 1, true) then return "ROGUE_ASSASSINATION" end
        if spec:find("combat", 1, true) then return "ROGUE_COMBAT" end
        if spec:find("subtlety", 1, true) then return "ROGUE_SUBTLETY" end
    elseif class == "SHAMAN" then
        if spec:find("elemental", 1, true) then return "SHAMAN_ELEMENTAL" end
        if spec:find("enhancement", 1, true) then return "SHAMAN_ENHANCEMENT" end
        if spec:find("restoration", 1, true) then return "SHAMAN_RESTORATION" end
    elseif class == "WARLOCK" then
        if spec:find("affliction", 1, true) then return "WARLOCK_AFFLICTION" end
        if spec:find("demonology", 1, true) then return "WARLOCK_DEMONOLOGY" end
        if spec:find("destruction", 1, true) then return "WARLOCK_DESTRUCTION" end
    elseif class == "WARRIOR" then
        if spec:find("arms", 1, true) then return "WARRIOR_ARMS" end
        if spec:find("fury", 1, true) then return "WARRIOR_FURY" end
        if spec:find("protection", 1, true) then return "WARRIOR_PROTECTION" end
    end
    return nil
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
    for slotKey, button in pairs(self.wishlistSlotButtons) do
        local slotDef = Goals:GetWishlistSlotDef(slotKey)
        local entry = list and list.items and list.items[slotKey] or nil
        local cached = entry and entry.itemId and Goals:CacheItemById(entry.itemId) or nil
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
                else
                    gem.icon:SetTexture(nil)
                    gem.icon:SetVertexColor(1, 1, 1, 0)
                    if gem.frame then
                        gem.frame:SetVertexColor(1, 1, 1, 0.7)
                        gem.frame:Show()
                    end
                    gem.itemId = nil
                    gem.socketType = socketType or "Socket"
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


function UI:PopulateDebugCopy()
    if not self.debugCopyBox then
        return
    end
    local text = Goals and Goals.GetDebugLogText and Goals:GetDebugLogText() or ""
    self.debugCopyBox:SetText(text)
    self.debugCopyBox:HighlightText()
    self.debugCopyBox:SetFocus()
end

function UI:SetLootSelection(row, entry)
    if self.lootSelectedRow and self.lootSelectedRow.selected then
        self.lootSelectedRow.selected:Hide()
    end
    self.lootSelectedRow = row
    self.lootSelectedEntry = entry
    self.lootSelectedNoteKey = entry and entry.noteKey or nil
    if row and row.selected then
        row.selected:Show()
    end
    if self.UpdateLootNoteSelection then
        self:UpdateLootNoteSelection()
    end
end

function UI:UpdateLootNoteSelection()
    if not self.lootNotesBox or not self.lootNotesApplyButton or not self.lootNotesClearButton then
        return
    end
    local key = self.lootSelectedNoteKey
    local entry = self.lootSelectedEntry
    if not key or not entry then
        if self.lootNotesSelectedLabel then
            self.lootNotesSelectedLabel:SetText("None")
        end
        self.lootNotesBox:SetText("")
        if self.lootNotesApplyButton.Disable then
            self.lootNotesApplyButton:Disable()
        end
        if self.lootNotesClearButton.Disable then
            self.lootNotesClearButton:Disable()
        end
        return
    end
    local label = entry.item or (entry.data and entry.data.item) or entry.text or "Selected"
    if self.lootNotesSelectedLabel then
        self.lootNotesSelectedLabel:SetText(label)
    end
    local note = self:GetLootNote(key)
    self.lootNotesBox:SetText(note and note.note or "")
    if self.lootNotesApplyButton.Enable then
        self.lootNotesApplyButton:Enable()
    end
    if self.lootNotesClearButton.Enable then
        self.lootNotesClearButton:Enable()
    end
end

function UI:UpdateLootHistoryList()
    if not self.lootHistoryScroll or not self.lootHistoryRows then
        return
    end
    local data = self:GetLootTableEntries()
    self.lootHistoryData = data
    local offset = FauxScrollFrame_GetOffset(self.lootHistoryScroll) or 0
    local visibleRows = #self.lootHistoryRows
    FauxScrollFrame_Update(self.lootHistoryScroll, #data, visibleRows, LOOT_HISTORY_ROW_HEIGHT_COMPACT)
    setScrollBarAlwaysVisible(self.lootHistoryScroll, #data * LOOT_HISTORY_ROW_HEIGHT_COMPACT)
    local dis = Goals.db and Goals.db.settings and Goals.db.settings.disenchanter or ""
    local disenchanterActive = dis ~= "" and dis ~= "0" and dis ~= L.NONE_OPTION
    local groupSize = 0
    if Goals and Goals.IsInRaid and Goals:IsInRaid() then
        groupSize = GetNumRaidMembers and GetNumRaidMembers() or 0
    elseif Goals and Goals.IsInParty and Goals:IsInParty() then
        local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
        groupSize = partyCount + 1
    else
        groupSize = 1
    end
    local hasRainbow = false
    local selectedFound = false
    for i = 1, visibleRows do
        local row = self.lootHistoryRows[i]
        local entry = data[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.entry = entry
            if row.timeText then
                row.timeText:SetText(formatTime(entry.ts))
            end
            row.rainbowData = nil
            row.itemLink = nil
            local itemText = ""
            local playerText = ""
            local notesText = ""
            local isPlayer = false

            if entry.kind == "FOUND" then
                itemText = entry.item or ""
                if entry.assignedCount and entry.assignedCount >= 3 then
                    playerText = formatPlayersCount(entry.assignedCount)
                    notesText = "Assigned"
                    row.rainbowData = {
                        kind = "loot",
                        count = entry.assignedCount,
                        itemLink = entry.item or "",
                    }
                    hasRainbow = true
                elseif entry.assignedTo and entry.assignedTo ~= "" then
                    playerText = entry.assignedTo
                    isPlayer = true
                    local isDisenchant = disenchanterActive and playerText == dis
                    if isDisenchant then
                        notesText = "Disenchanted"
                    elseif entry.reset then
                        local before = tonumber(entry.resetBefore) or 0
                        notesText = string.format("Assigned (Reset -%d)", before)
                    else
                        notesText = "Assigned"
                    end
                else
                    local stackCount = entry.stackCount or 0
                    if stackCount > 1 then
                        if groupSize > 0 and (stackCount % groupSize) == 0 then
                            local perPlayer = math.floor(stackCount / groupSize)
                            if perPlayer > 1 then
                                itemText = string.format("%s x%d", itemText, perPlayer)
                            else
                                itemText = string.format("%s x%d", itemText, stackCount)
                            end
                            playerText = "All Players"
                        else
                            itemText = string.format("%s x%d", itemText, stackCount)
                            playerText = "Group"
                        end
                    else
                        playerText = "Unassigned"
                    end
                    if entry.raw then
                        notesText = "Found"
                    else
                        notesText = "Looted"
                    end
                end
                row.itemLink = entry.item
            elseif entry.kind == "LOOT_FOUND" then
                local itemLink = entry.data and entry.data.item or ""
                itemText = itemLink
                notesText = "Looted"
                row.itemLink = itemLink
            elseif entry.kind == "LOOT_ASSIGN" then
                local dataEntry = entry.data or {}
                local itemLink = dataEntry.item or ""
                local players = dataEntry.players or nil
                itemText = itemLink
                row.itemLink = itemLink
                if players and #players >= 3 then
                    local count = #players
                    row.rainbowData = {
                        kind = "loot",
                        count = count,
                        itemLink = itemLink,
                    }
                    playerText = formatPlayersCount(count)
                    notesText = "Assigned"
                    hasRainbow = true
                else
                    playerText = dataEntry.player or ""
                    isPlayer = playerText ~= ""
                    local isDisenchant = disenchanterActive and playerText ~= "" and playerText == dis
                    if isDisenchant then
                        notesText = "Disenchanted"
                    elseif dataEntry.reset then
                        local before = tonumber(dataEntry.resetBefore) or 0
                        notesText = string.format("Assigned (Reset -%d)", before)
                    else
                        notesText = "Assigned"
                    end
                end
            else
                itemText = entry.text or ""
            end

            if entry.noteKey then
                local manualNote = self:GetLootNote(entry.noteKey)
                if manualNote and manualNote.note and manualNote.note ~= "" then
                    notesText = manualNote.note
                end
            end

            if row.cols then
                if row.cols.item then
                    setLootItemLabelText(row.cols.item, itemText or "")
                end
                if row.cols.player then
                    row.cols.player:SetText(playerText or "")
                    if isPlayer and playerText ~= "" then
                        local r, g, b = Goals:GetPlayerColor(playerText)
                        row.cols.player:SetTextColor(r, g, b)
                    elseif entry.kind == "FOUND" then
                        row.cols.player:SetTextColor(0.8, 0.8, 0.8)
                    else
                        row.cols.player:SetTextColor(1, 1, 1)
                    end
                end
                if row.cols.notes then
                    row.cols.notes:SetText(notesText or "")
                end
            elseif row.text then
                row.text:SetText(entry.text or "")
            end
            if row.selected then
                if entry.noteKey and self.lootSelectedNoteKey and entry.noteKey == self.lootSelectedNoteKey then
                    row.selected:Show()
                    self.lootSelectedRow = row
                    self.lootSelectedEntry = entry
                    selectedFound = true
                else
                    row.selected:Hide()
                end
            end
        else
            row:Hide()
            row.itemLink = nil
            row.rainbowData = nil
            row.entry = nil
            if row.selected then
                row.selected:Hide()
            end
        end
    end
    if hasRainbow then
        self:StartRainbowTicker()
    end
    if self.lootSelectedNoteKey and not selectedFound then
        self.lootSelectedRow = nil
        self.lootSelectedEntry = nil
        self.lootSelectedNoteKey = nil
    end
    if self.UpdateLootNoteSelection then
        self:UpdateLootNoteSelection()
    end
end

function UI:UpdateFoundLootList()
    if not self.foundLootScroll or not self.foundLootRows then
        return
    end
    local hasAccess = hasModifyAccess()
    if self.foundHintLabel then
        setShown(self.foundHintLabel, hasAccess)
    end
    if self.foundLockedLabel then
        setShown(self.foundLockedLabel, not hasAccess)
    end
    if not hasAccess then
        self.foundLootScroll:Hide()
        for _, row in ipairs(self.foundLootRows) do
            row:Hide()
            row.selected:Hide()
            row.entry = nil
        end
        FauxScrollFrame_Update(self.foundLootScroll, 0, LOOT_ROWS, ROW_HEIGHT)
        return
    end
    self.foundLootScroll:Show()
    local data = Goals:GetFoundLoot() or {}
    local filtered = {}
    for _, entry in ipairs(data) do
        if entry and not entry.assignedTo then
            table.insert(filtered, entry)
        end
    end
    self.foundLootData = filtered
    local offset = FauxScrollFrame_GetOffset(self.foundLootScroll) or 0
    FauxScrollFrame_Update(self.foundLootScroll, #filtered, LOOT_ROWS, ROW_HEIGHT)
    for i = 1, LOOT_ROWS do
        local row = self.foundLootRows[i]
        local entry = filtered[offset + i]
        if entry then
            row:Show()
            if row.stripe then
                setShown(row.stripe, ((offset + i) % 2) == 0)
            end
            row.entry = entry
            row.text:SetText(entry.link or "")
            if self.foundSelected == row then
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
end

function UI:ShowFoundLootMenu(row, entry)
    if not entry or not hasModifyAccess() then
        return
    end
    self.foundSelected = row
    for _, rowItem in ipairs(self.foundLootRows or {}) do
        setShown(rowItem.selected, rowItem == row)
    end
    if not self.foundLootMenu then
        self.foundLootMenu = CreateFrame("Frame", "GoalsFoundLootMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = self.foundLootMenu
    UIDropDownMenu_Initialize(menu, function(_, level)
        local info
        local players = {}
        if Goals.GetGroupMembers then
            local members = Goals:GetGroupMembers()
            local seen = {}
            for _, member in ipairs(members) do
                local normalized = Goals:NormalizeName(member.name)
                if normalized ~= "" and not seen[normalized] then
                    seen[normalized] = true
                    table.insert(players, member.name)
                end
            end
        end
        if #players == 0 then
            players = UI:GetPresentPlayerNames()
        end
        if #players == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = L.LABEL_NO_PLAYERS
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, name in ipairs(players) do
            info = UIDropDownMenu_CreateInfo()
            info.text = colorizeName(name)
            info.value = name
            info.func = function()
                Goals:AssignLootSlot(entry.slot, name, entry.link)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

function UI:RefreshStatus()
    if Goals and Goals.UpdateSyncStatus then
        Goals:UpdateSyncStatus(true)
    end
    if self.syncValue then
        local status = Goals.sync and Goals.sync.status or ""
        if Goals.sync then
            if Goals.sync.isMaster then
                status = "Master (You)"
            elseif Goals.sync.masterName and Goals.sync.masterName ~= "" then
                status = "Following " .. colorizeName(Goals.sync.masterName)
            end
        end
        self.syncValue:SetText(status)
    end
    if self.disenchantValue then
        self.disenchantValue:SetText(self:GetDisenchanterStatus())
    end
    self:RefreshUpdateTab()
    self:UpdateUpdateTabGlow()
    if self.UpdateAutoSyncLabel then
        self:UpdateAutoSyncLabel()
    end
    if self.syncNoteLabel then
        if Goals and Goals.db and Goals.db.settings and Goals.db.settings.localOnly then
            self.syncNoteLabel:SetText("Sync disabled (Local-only mode).")
            self.syncNoteLabel:Show()
        else
            self.syncNoteLabel:SetText("")
            self.syncNoteLabel:Hide()
        end
    end
end

function UI:UpdateAutoSyncLabel()
    if not self.autoSyncLabel then
        return
    end
    local isMaster = (Goals and Goals.IsSyncMaster and Goals:IsSyncMaster()) or (Goals and Goals.IsMasterLooter and Goals:IsMasterLooter())
    if not isMaster then
        local last = Goals and Goals.lastSyncReceivedAt or nil
        if last then
            self.autoSyncLabel:SetText("Last sync: " .. date("%H:%M:%S", last))
        else
            self.autoSyncLabel:SetText("Last sync: --:--:--")
        end
        return
    end
    local remaining = Goals and Goals.GetAutoSyncRemaining and Goals:GetAutoSyncRemaining() or nil
    if not remaining then
        self.autoSyncLabel:SetText("Auto sync: --")
        return
    end
    local seconds = math.floor(remaining + 0.5)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    self.autoSyncLabel:SetText(string.format("Auto sync: %d:%02d", mins, secs))
end

function UI:Refresh()
    if not self.frame then
        return
    end
    self:RefreshStatus()
    self:SyncSortDropdown()
    if self.disenchanterDropdown then
        local current = Goals.db.settings.disenchanter or ""
        self.disenchanterDropdown.selectedValue = current
        if current ~= "" then
            self:SetDropdownText(self.disenchanterDropdown, current)
        else
            self:SetDropdownText(self.disenchanterDropdown, L.NONE_OPTION)
        end
        local canEditDis = hasDisenchanterAccess()
        setDropdownEnabled(self.disenchanterDropdown, canEditDis)
        if self.disenchanterDropdown.SetAlpha then
            self.disenchanterDropdown:SetAlpha(canEditDis and 1 or 0.6)
        end
    end
    if self.combineCheck then
        self.combineCheck:SetChecked(Goals.db.settings.combineBossHistory and true or false)
    end
    if self.minimapCheck then
        self.minimapCheck:SetChecked(not Goals.db.settings.minimap.hide)
    end
    if self.autoMinimizeCheck then
        self.autoMinimizeCheck:SetChecked(Goals.db.settings.autoMinimizeCombat and true or false)
    end
    local trackingEnabled = Goals.db.settings.combatLogTracking and true or false
    if self.combatLogTrackingCheck then
        self.combatLogTrackingCheck:SetChecked(trackingEnabled)
    end
    if Goals and Goals.db and Goals.db.settings then
        self:NormalizeCombatShowFlags(Goals.db.settings)
    end
    local mode = self:GetCombatShowMode(Goals.db.settings)
    self.damageTrackerFilter = mode
    if self.damageTrackerDropdown then
        self.damageTrackerDropdown.selectedValue = mode
        UIDropDownMenu_SetSelectedValue(self.damageTrackerDropdown, mode)
        self:SetDropdownText(self.damageTrackerDropdown, mode)
        setDropdownEnabled(self.damageTrackerDropdown, trackingEnabled)
        if self.damageTrackerDropdown.SetAlpha then
            self.damageTrackerDropdown:SetAlpha(trackingEnabled and 1 or 0.6)
        end
    end
    if self.combatLogShowDropdown then
        local enabled = trackingEnabled
        self.combatLogShowDropdown.selectedValue = mode
        UIDropDownMenu_SetSelectedValue(self.combatLogShowDropdown, mode)
        self:SetDropdownText(self.combatLogShowDropdown, mode)
        setDropdownEnabled(self.combatLogShowDropdown, enabled)
        if self.combatLogShowDropdown.SetAlpha then
            self.combatLogShowDropdown:SetAlpha(enabled and 1 or 0.6)
        end
    end
    local function clampSliderValue(value)
        local clamped = math.floor((tonumber(value) or 0) + 0.5)
        if clamped < 0 then
            clamped = 0
        elseif clamped > 100 then
            clamped = 100
        end
        return clamped
    end

    local threshold = tonumber(Goals.db.settings.combatLogBigThreshold)
    if threshold == nil then
        local oldDamage = tonumber(Goals.db.settings.combatLogBigDamageThreshold)
        local oldHeal = tonumber(Goals.db.settings.combatLogBigHealingThreshold)
        if oldDamage or oldHeal then
            threshold = math.max(oldDamage or 0, oldHeal or 0)
        end
    end
    if threshold == nil then
        threshold = (Goals.db.settings.combatLogShowBig and 50 or 0)
    end
    Goals.db.settings.combatLogBigThreshold = threshold
    threshold = clampSliderValue(threshold)

    local function updateSlider(slider, valueLabel, value, enabled)
        if slider then
            slider:SetValue(value)
            if slider.SetAlpha then
                slider:SetAlpha(enabled and 1 or 0.6)
            end
            if enabled then
                if slider.Enable then
                    slider:Enable()
                end
            else
                if slider.Disable then
                    slider:Disable()
                end
            end
        end
        if valueLabel then
            valueLabel:SetText(string.format("%d%%", value))
        end
    end

    if self.combatLogBigThresholdSlider then
        updateSlider(self.combatLogBigThresholdSlider, self.combatLogBigThresholdValue, threshold, trackingEnabled)
    end
    if self.combatLogShowBossHealingCheck then
        local enabled = trackingEnabled
        local showBossHealing = Goals.db.settings.combatLogShowBossHealing
        if showBossHealing == nil then
            showBossHealing = true
            Goals.db.settings.combatLogShowBossHealing = true
        end
        self.combatLogShowBossHealingCheck:SetChecked(showBossHealing and true or false)
        if self.combatLogShowBossHealingCheck.SetAlpha then
            self.combatLogShowBossHealingCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogShowBossHealingCheck.Enable then
                self.combatLogShowBossHealingCheck:Enable()
            end
        else
            if self.combatLogShowBossHealingCheck.Disable then
                self.combatLogShowBossHealingCheck:Disable()
            end
        end
    end
    if self.combatLogShowThreatAbilitiesCheck then
        local enabled = trackingEnabled
        local showThreatAbilities = Goals.db.settings.combatLogShowThreatAbilities
        if showThreatAbilities == nil then
            showThreatAbilities = true
            Goals.db.settings.combatLogShowThreatAbilities = true
        end
        self.combatLogShowThreatAbilitiesCheck:SetChecked(showThreatAbilities and true or false)
        if self.combatLogShowThreatAbilitiesCheck.SetAlpha then
            self.combatLogShowThreatAbilitiesCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogShowThreatAbilitiesCheck.Enable then
                self.combatLogShowThreatAbilitiesCheck:Enable()
            end
        else
            if self.combatLogShowThreatAbilitiesCheck.Disable then
                self.combatLogShowThreatAbilitiesCheck:Disable()
            end
        end
    end
    if self.combatLogCombinePeriodicCheck then
        local enabled = trackingEnabled
        self.combatLogCombinePeriodicCheck:SetChecked(Goals.db.settings.combatLogCombinePeriodic and true or false)
        if self.combatLogCombinePeriodicCheck.SetAlpha then
            self.combatLogCombinePeriodicCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogCombinePeriodicCheck.Enable then
                self.combatLogCombinePeriodicCheck:Enable()
            end
        else
            if self.combatLogCombinePeriodicCheck.Disable then
                self.combatLogCombinePeriodicCheck:Disable()
            end
        end
    end
    if self.combatLogCombineAllCheck then
        local enabled = trackingEnabled
        self.combatLogCombineAllCheck:SetChecked(Goals.db.settings.combatLogCombineAll and true or false)
        if self.combatLogCombineAllCheck.SetAlpha then
            self.combatLogCombineAllCheck:SetAlpha(enabled and 1 or 0.6)
        end
        if enabled then
            if self.combatLogCombineAllCheck.Enable then
                self.combatLogCombineAllCheck:Enable()
            end
        else
            if self.combatLogCombineAllCheck.Disable then
                self.combatLogCombineAllCheck:Disable()
            end
        end
    end
    if self.localOnlyCheck then
        self.localOnlyCheck:SetChecked(Goals.db.settings.localOnly and true or false)
    end
    if self.dbmIntegrationCheck then
        self.dbmIntegrationCheck:SetChecked(Goals.db.settings.dbmIntegration and true or false)
    end
    if self.wishlistDbmIntegrationCheck then
        self.wishlistDbmIntegrationCheck:SetChecked(Goals.db.settings.wishlistDbmIntegration and true or false)
    end
    if self.sudoDevButton then
        if Goals.db.settings.sudoDev then
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_DISABLE)
        else
            self.sudoDevButton:SetText(L.BUTTON_SUDO_DEV_ENABLE)
        end
    end
    local overviewSettings = Goals.GetOverviewSettings and Goals:GetOverviewSettings() or (Goals.db and Goals.db.settings) or {}
    if self.resetMountsCheck then
        self.resetMountsCheck:SetChecked(Goals.db.settings.resetMounts and true or false)
    end
    if self.resetPetsCheck then
        self.resetPetsCheck:SetChecked(Goals.db.settings.resetPets and true or false)
    end
    if self.resetRecipesCheck then
        self.resetRecipesCheck:SetChecked(Goals.db.settings.resetRecipes and true or false)
    end
    if self.resetTokensCheck then
        self.resetTokensCheck:SetChecked(Goals.db.settings.resetTokens and true or false)
    end
    if self.resetQuestItemsCheck then
        self.resetQuestItemsCheck:SetChecked(Goals.db.settings.resetQuestItems and true or false)
    end
    if self.resetLootWindowCheck then
        self.resetLootWindowCheck:SetChecked(Goals.db.settings.resetRequiresLootWindow and true or false)
    end
    if self.debugCheck then
        self.debugCheck:SetChecked(Goals.db.settings.debug and true or false)
    end
    if self.wishlistChatCheck then
        self.wishlistChatCheck:SetChecked(Goals.db.settings.devTestWishlistChat and true or false)
    end

    local function formatBinding(action)
        if not GetBindingKey then
            return "Unbound"
        end
        local key1, key2 = GetBindingKey(action)
        local function normalizeKey(key)
            if not key or key == "" then
                return nil
            end
            if GetBindingText then
                return GetBindingText(key, "KEY_") or key
            end
            return key
        end
        local text1 = normalizeKey(key1)
        local text2 = normalizeKey(key2)
        if text1 and text2 then
            return text1 .. " / " .. text2
        end
        return text1 or text2 or "Unbound"
    end

    if self.keybindUiValue then
        self.keybindUiValue:SetText(formatBinding("GOALS_TOGGLE_UI"))
    end
    if self.keybindMiniValue then
        self.keybindMiniValue:SetText(formatBinding("GOALS_TOGGLE_MINI"))
    end
    if self.wishlistTestCountBox then
        local value = tonumber(Goals.db.settings.devTestWishlistItems) or 1
        if value < 1 then
            value = 1
        elseif value > 8 then
            value = 8
        end
        self.wishlistTestCountBox:SetText(tostring(value))
    end
    if self.wishlistAnnounceCheck then
        self.wishlistAnnounceCheck:SetChecked(Goals.db.settings.wishlistAnnounce and true or false)
    end
    if self.wishlistPopupDisableCheck then
        self.wishlistPopupDisableCheck:SetChecked(Goals.db.settings.wishlistPopupDisabled and true or false)
    end
    if self.wishlistPopupSoundToggle and self.wishlistPopupSoundToggle.icon then
        self.wishlistPopupSoundToggle.icon:SetTexture("Interface\\Common\\VoiceChat-Speaker")
        if self.wishlistPopupSoundToggle.waveIcon then
            setShown(self.wishlistPopupSoundToggle.waveIcon, Goals.db.settings.wishlistPopupSound ~= false)
        end
    end
    if self.UpdateCombatDebugStatus then
        self:UpdateCombatDebugStatus()
    end
    if self.UpdateTabFooters then
        self:UpdateTabFooters()
    end
    -- Auto-only announcement channel; no user selection.
    if self.wishlistTemplateBox then
        self.wishlistTemplateBox:SetText(Goals.db.settings.wishlistAnnounceTemplate or "%s is on my wishlist")
    end
    if self.lootHistoryMinQuality then
        local value = Goals.db.settings.lootHistoryMinQuality or 0
        UIDropDownMenu_SetSelectedValue(self.lootHistoryMinQuality, value)
        UIDropDownMenu_SetText(self.lootHistoryMinQuality, getQualityLabel(value))
    end
    if self.historyPointsCheck then
        local settings = Goals.db.settings or {}
        self.historyEncounterCheck:SetChecked(settings.historyFilterEncounter ~= false)
        self.historyPointsCheck:SetChecked(settings.historyFilterPoints ~= false)
        self.historyBuildCheck:SetChecked(settings.historyFilterBuild ~= false)
        self.historyWishlistStatusCheck:SetChecked(settings.historyFilterWishlistStatus ~= false)
        self.historyWishlistItemsCheck:SetChecked(settings.historyFilterWishlistItems ~= false)
        self.historyLootCheck:SetChecked(settings.historyFilterLoot ~= false)
        if self.historySyncCheck then
            self.historySyncCheck:SetChecked(settings.historyFilterSync ~= false)
        end
    end
    if self.historyLootMinQuality then
        local value = Goals.db.settings.historyLootMinQuality or 0
        UIDropDownMenu_SetSelectedValue(self.historyLootMinQuality, value)
        UIDropDownMenu_SetText(self.historyLootMinQuality, getQualityLabel(value))
    end
    self:SyncResetQualityDropdown()
    if self.devBossCheck then
        self.devBossCheck:SetChecked(Goals.db.settings.devTestBoss and true or false)
    end
    local hasAccess = hasModifyAccess()
    if self.overviewAdminControls then
        for _, control in ipairs(self.overviewAdminControls) do
            setShown(control, hasAccess)
        end
    end
    if self.UpdateOverviewOptionsLayout then
        self:UpdateOverviewOptionsLayout(hasAccess)
    end
    self:UpdateRosterList()
    self:UpdateHistoryList()
    self:UpdateLootHistoryList()
    self:UpdateFoundLootList()
    self:UpdateDamageTrackerList()
    self:UpdateDebugLogList()
    self:UpdateWishlistUI()
    self:UpdateMiniTracker()
    self:UpdateMiniFloatingButtonPosition()
    self:UpdateMinimapButton()
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

function UI:CreateMinimapButton()
    if self.minimapButton then
        return
    end
    local button = CreateFrame("Button", "GoalsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            if IsShiftKeyDown and IsShiftKeyDown() then
                if UI and UI.ToggleMiniTracker then
                    UI:ToggleMiniTracker()
                end
                return
            end
            Goals:ToggleUI()
        end
    end)
    button:SetScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_LEFT")
        local versionText = Goals and Goals.GetDisplayVersion and Goals:GetDisplayVersion() or "2"
        GameTooltip:SetText("Goals v" .. versionText)
        local playerName = Goals and Goals.GetPlayerName and Goals:GetPlayerName() or ""
        local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
        local entry = players[playerName]
        local points = entry and entry.points or 0
        if playerName ~= "" then
            GameTooltip:AddLine(string.format("%s has %d points", colorizeName(playerName), points), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local icon = button:CreateTexture(nil, "ARTWORK")
    local function setIconTexture(path)
        icon:SetTexture(nil)
        icon:SetTexture(path)
        if icon:GetTexture() then
            return true
        end
        return false
    end

    local iconPath = string.format("Interface\\AddOns\\%s\\Icons\\GoalsRune-Glow", addonName)
    if not setIconTexture(iconPath) then
        icon:SetTexture("Interface\\Icons\\achievement_bg_killflagcarriers_grabflag_capit")
    end
    icon:SetSize(18, 18)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:Show()
    button.border = border

    button:SetScript("OnDragStart", function(selfBtn)
        selfBtn.isMoving = true
        selfBtn:SetScript("OnUpdate", function()
            UI:UpdateMinimapPositionFromCursor()
        end)
    end)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn.isMoving = false
        selfBtn:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = button
    self:UpdateMinimapPosition()
end

function UI:UpdateMinimapPositionFromCursor()
    if not self.minimapButton then
        return
    end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    x = x / scale
    y = y / scale
    local mx, my = Minimap:GetCenter()
    local dx = x - mx
    local dy = y - my
    local angle = math.deg(math.atan2(dy, dx))
    Goals.db.settings.minimap.angle = angle
    self:UpdateMinimapPosition(true)
end

function UI:UpdateMinimapPosition(force)
    if not self.minimapButton then
        return
    end
    local angle = Goals.db.settings.minimap.angle or 220
    if not force and self.minimapLastAngle == angle then
        return
    end
    local radius = (Minimap:GetWidth() / 2) + 8
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    self.minimapLastAngle = angle
end

function UI:UpdateMinimapButton()
    if not self.minimapButton or not Goals.db or not Goals.db.settings then
        return
    end
    if Goals.db.settings.minimap.hide then
        if self.minimapButton:IsShown() then
            self.minimapButton:Hide()
        end
        return
    end
    if not self.minimapButton:IsShown() then
        self.minimapButton:Show()
    end
    self:UpdateMinimapPosition()
end

function UI:UpdateMiniFloatingButtonPosition()
    if not self.miniFloatingButton then
        return
    end
    self:UpdateMiniFloatingPosition()
end

function UI:CreateMiniTracker()
    if self.miniTracker then
        return
    end
    local frame = CreateFrame("Frame", "GoalsMiniTracker", UIParent, "GoalsInsetTemplate")
    applyInsetTheme(frame)
    frame:SetSize(MINI_FRAME_WIDTH, MINI_HEADER_HEIGHT + 10)
    frame:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfFrame:GetCenter()
        local settings = getMiniSettings()
        if settings then
            settings.x = x - uiX
            settings.y = y - uiY
            settings.hasPosition = true
        end
    end)
    frame:SetAlpha(0.85)
    frame:Hide()

    local titleBg = frame:CreateTexture(nil, "BORDER")
    titleBg:SetTexture("Interface\\AddOns\\Goals\\Texture\\FrameGeneral\\_UI-Frame")
    titleBg:SetHeight(17)
    titleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -3)
    titleBg:SetTexCoord(0.0, 1.0, 0.2890625, 0.421875)
    frame.titleBg = titleBg

    local title = createLabel(frame, L.LABEL_MINI_TRACKER, "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -6)
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
    close:SetScript("OnClick", function()
        UI:CloseMiniTracker()
    end)
    frame.close = close

    local minimize = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    minimize:SetSize(18, 18)
    minimize:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
    minimize:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    minimize:SetHighlightTexture("Interface\\Buttons\\UI-Panel-HideButton-Highlight", "ADD")
    minimize:SetPoint("RIGHT", close, "LEFT", 2, 0)
    minimize:SetScript("OnClick", function()
        UI:MinimizeMiniTracker()
    end)
    frame.minimize = minimize

    frame.rows = {}
    self.miniTracker = frame
    self:UpdateMiniTrackerPosition()
end

function UI:UpdateMiniTrackerPosition()
    if not self.miniTracker then
        return
    end
    local pos = getMiniSettings()
    if not pos then
        return
    end
    self.miniTracker:ClearAllPoints()
    if pos.hasPosition then
        self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", pos.x or MINI_DEFAULT_X, pos.y or MINI_DEFAULT_Y)
    else
        self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
    end
end

function UI:ShowMiniTracker(show)
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.show = show and true or false
    settings.minimized = false
    if show then
        if not settings.hasPosition then
            self.miniTracker:ClearAllPoints()
            if self.frame and self.frame:IsShown() then
                self.miniTracker:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", -4, -2)
            else
                self.miniTracker:SetPoint("CENTER", UIParent, "CENTER", MINI_DEFAULT_X, MINI_DEFAULT_Y)
            end
            local uiX, uiY = UIParent:GetCenter()
            local x, y = self.miniTracker:GetCenter()
            settings.x = x - uiX
            settings.y = y - uiY
            settings.hasPosition = true
        else
            self:UpdateMiniTrackerPosition()
        end
    else
        self:UpdateMiniTrackerPosition()
    end
    self:UpdateMiniTracker()
end

function UI:ToggleMiniTracker()
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    if not settings.show then
        self:ShowMiniTracker(true)
        return
    end
    if settings.minimized then
        self:ShowMiniTracker(true)
        return
    end
    self:MinimizeMiniTracker()
end

function UI:UpdateMiniTrackerVisibility()
    if not self.miniTracker then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    local wantShow = settings.show and not settings.minimized
    if Goals.Dev and Goals.Dev.enabled then
        setShown(self.miniTracker, wantShow)
        return
    end
    local inGroup = Goals.IsInRaid and Goals:IsInRaid() or false
    if not inGroup and Goals.IsInParty then
        inGroup = Goals:IsInParty()
    end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local autoHide = Goals.db.settings.autoMinimizeCombat and true or false
    setShown(self.miniTracker, wantShow and inGroup and (not autoHide or not inCombat))
end

function UI:UpdateMiniTracker()
    if not self.miniTracker or not Goals.db or not Goals.db.settings then
        return
    end
    self:UpdateMiniTrackerVisibility()
    if not self.miniTracker:IsShown() then
        self:UpdateMiniFloatingButton()
        return
    end
    local present = self:GetPresentPlayerNames()
    local rowCount = #present
    local rowY = -MINI_HEADER_HEIGHT
    for i = 1, rowCount do
        local row = self.miniTracker.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.miniTracker)
            row:SetHeight(MINI_ROW_HEIGHT)
            row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.pointsText:SetPoint("RIGHT", row, "RIGHT", -11, 0)
            row.pointsText:SetJustifyH("RIGHT")
            self.miniTracker.rows[i] = row
        end
        local name = present[i]
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.miniTracker, "TOPLEFT", 0, rowY)
        row:SetPoint("RIGHT", self.miniTracker, "RIGHT", 0, 0)
        local players = Goals.GetOverviewPlayers and Goals:GetOverviewPlayers() or (Goals.db and Goals.db.players) or {}
        local entry = players[name]
        local points = entry and entry.points or 0
        local r, g, b = Goals:GetClassColor(entry and entry.class or nil)
        row.nameText:SetText(name)
        row.nameText:SetTextColor(r, g, b)
        row.pointsText:SetText(points)
        rowY = rowY - MINI_ROW_HEIGHT
    end
    for i = rowCount + 1, #self.miniTracker.rows do
        self.miniTracker.rows[i]:Hide()
    end
    local height = MINI_HEADER_HEIGHT + 8 + (rowCount * MINI_ROW_HEIGHT)
    if height < MINI_HEADER_HEIGHT + 10 then
        height = MINI_HEADER_HEIGHT + 10
    end
    self.miniTracker:SetHeight(height)
    self:UpdateMiniFloatingButton()
end

function UI:MinimizeMiniTracker()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.minimized = true
    self:UpdateMiniTracker()
end

function UI:CloseMiniTracker()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.show = false
    settings.minimized = false
    self:UpdateMiniTracker()
end

function UI:ResetMiniTrackerPosition()
    local settings = getMiniSettings()
    if not settings then
        return
    end
    settings.hasPosition = false
    if self.miniTracker and self.miniTracker:IsShown() then
        self:ShowMiniTracker(true)
    end
end

function UI:CreateMiniFloatingButton()
    if self.miniFloatingButton then
        return
    end
    local button = CreateFrame("Button", "GoalsMiniFloatingButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetText(L.BUTTON_TOGGLE_MINI_TRACKER)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfBtn:GetCenter()
        local settings = getMiniSettings()
        if settings then
            settings.buttonX = x - uiX
            settings.buttonY = y - uiY
        end
    end)
    button:SetScript("OnClick", function()
        UI:ShowMiniTracker(true)
    end)
    button:Hide()
    self.miniFloatingButton = button
    self:UpdateMiniFloatingPosition()
end

function UI:UpdateMiniFloatingPosition()
    if not self.miniFloatingButton then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    self.miniFloatingButton:ClearAllPoints()
    self.miniFloatingButton:SetPoint("CENTER", UIParent, "CENTER", settings.buttonX or 0, settings.buttonY or 0)
end

function UI:UpdateMiniFloatingButton()
    if not self.miniFloatingButton then
        return
    end
    local settings = getMiniSettings()
    if not settings then
        return
    end
    local show = settings.show and settings.minimized
    setShown(self.miniFloatingButton, show)
end

function UI:CreateFloatingButton()
    if self.floatingButton then
        return
    end
    local button = CreateFrame("Button", "GoalsFloatingButton", UIParent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetText(L.BUTTON_OPEN)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(selfBtn)
        selfBtn:StopMovingOrSizing()
        local uiX, uiY = UIParent:GetCenter()
        local x, y = selfBtn:GetCenter()
        Goals.db.settings.floatingButton.x = x - uiX
        Goals.db.settings.floatingButton.y = y - uiY
    end)
    button:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)
    self.floatingButton = button
    self:UpdateFloatingPosition()
    if Goals.db.settings.floatingButton.show then
        button:Show()
    else
        button:Hide()
    end
end

function UI:UpdateFloatingPosition()
    if not self.floatingButton or not Goals.db or not Goals.db.settings then
        return
    end
    local pos = Goals.db.settings.floatingButton or { x = 0, y = 0 }
    self.floatingButton:ClearAllPoints()
    self.floatingButton:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
end

function UI:CreateOptionsPanel()
    if self.optionsPanel then
        return
    end
    local panel = CreateFrame("Frame", "GoalsOptionsPanel", UIParent)
    panel.name = L.TITLE

    local title = createLabel(panel, L.TITLE, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(120, 22)
    openButton:SetText(L.BUTTON_OPEN)
    openButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    openButton:SetScript("OnClick", function()
        Goals:ToggleUI()
    end)

    local floatingCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    floatingCheck:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", -2, -8)
    setCheckText(floatingCheck, "Show floating button")
    floatingCheck:SetScript("OnClick", function(selfBtn)
        Goals.db.settings.floatingButton.show = selfBtn:GetChecked() and true or false
        UI:ShowFloatingButton(Goals.db.settings.floatingButton.show)
    end)

    panel:SetScript("OnShow", function()
        floatingCheck:SetChecked(Goals.db.settings.floatingButton.show and true or false)
    end)

    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
end

