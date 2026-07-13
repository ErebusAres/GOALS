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
local COMBAT_DETAIL_WIDTH_BASE = 112
local COMBAT_TOTAL_WIDTH_BASE = 76
local COMBAT_DYNAMIC_EXTRA_MAX = 640
local COMBAT_WHERE_MIN_WIDTH = 130
local FRAME_EDGE_MARGIN_UI = 96
local COMBAT_DETAIL_DYNAMIC_CAP = 190
local COMBAT_TOTAL_DYNAMIC_CAP = 180
local COMBAT_DYNAMIC_DEADZONE = 6
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
local MAIN_FRAME_WIDTH = 900
local MAIN_FRAME_WIDTH_COMBAT = 1240
local PAGE_BOTTOM_OFFSET = 12
local FOOTER_BOTTOM_INSET = 6
local FOOTER_BAR_HEIGHT = 24
local FOOTER_BAR_GAP = 4
local FOOTER_BAR_EXTRA = FOOTER_BAR_HEIGHT + FOOTER_BAR_GAP
local OPTIONS_HEADER_HEIGHT = 16
local OPTIONS_BUTTON_ID = 0
local createLabel

local function insertWishlistChatLink(link)
    if not link or link == "" then
        return false
    end
    if not (IsModifiedClick and IsModifiedClick("CHATLINK")) then
        return false
    end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return true
    end
    if HandleModifiedItemClick then
        HandleModifiedItemClick(link)
        return true
    end
    return false
end

local function getWishlistItemChatLink(itemId, itemLink)
    if itemLink and itemLink ~= "" then
        return itemLink
    end
    local cached = itemId and Goals.CacheItemById and Goals:CacheItemById(itemId) or nil
    return (cached and cached.link) or (itemId and ("item:" .. tostring(itemId))) or nil
end

local function getWishlistEnchantChatLink(enchantId, entry)
    local info = entry
    if not info and enchantId and Goals.GetEnchantInfoById then
        info = Goals:GetEnchantInfoById(enchantId)
    end
    local spellId = info and tonumber(info.spellId) or nil
    if spellId and GetSpellLink then
        local link = GetSpellLink(spellId)
        if link and link ~= "" then
            return link
        end
    end
    if spellId then
        local name = (info and info.name) or (GetSpellInfo and GetSpellInfo(spellId)) or ("Enchant " .. tostring(enchantId or spellId))
        return "|cff71d5ff|Hspell:" .. tostring(spellId) .. "|h[" .. tostring(name) .. "]|h|r"
    end
    return info and info.name or nil
end

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
local COMBAT_DISPLAY_TABLE = "table"
local COMBAT_DISPLAY_CHAT = "chat"
local COMBAT_THEME_NEUTRAL = "neutral"
local COMBAT_THEME_ALLIANCE = "alliance"
local COMBAT_THEME_HORDE = "horde"
local COMBAT_THEME_CLASS = "class"
local COMBAT_ROW_BG_EVENT_TINT = "event_tint"
local COMBAT_ROW_BG_NEUTRAL = "neutral"
local CPU_DEBUG_DEFAULT_INTERVAL = 2
local CPU_DEBUG_MIN_INTERVAL = 0.2
local CPU_DEBUG_MAX_INTERVAL = 30
local CPU_DEBUG_MAX_LINES = 180
local CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD = 8
local CPU_DEBUG_MIN_SPIKE_THRESHOLD = 0.5
local CPU_DEBUG_MAX_SPIKE_THRESHOLD = 200

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
    widget.headerBg = headerBg
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
        local fmt = "%H:%M:%S"
        if Goals and Goals.db and Goals.db.settings and Goals.db.settings.combatWhtmTimestampFormat == "12h" then
            fmt = "%I:%M:%S %p"
        end
        return date(fmt, ts)
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

local function isSelfCombatName(name)
    if not name or name == "" or not Goals or not Goals.GetPlayerName then
        return false
    end
    local playerName = Goals:GetPlayerName()
    if not playerName or playerName == "" then
        return false
    end
    if Goals.NormalizeName then
        return Goals:NormalizeName(name) == Goals:NormalizeName(playerName)
    end
    return name == playerName
end

local function decorateSelfCombatName(name)
    if not name or name == "" then
        return name or ""
    end
    if isSelfCombatName(name) then
        return "< " .. name .. " >"
    end
    return name
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
        UI.combatTooltipEntryKey = nil
        if UI.UpdateDamageTrackerList then
            UI:UpdateDamageTrackerList()
        end
    end
end

local function combatEventKey(event)
    if not event then
        return nil
    end
    if event.id ~= nil then
        return "id:" .. tostring(event.id)
    end
    return table.concat({
        tostring(event.timestamp or event.ts or ""),
        tostring(event.subevent or ""),
        tostring(event.sourceGUID or ""),
        tostring(event.destGUID or ""),
        tostring(event.spellId or event.spellName or ""),
        tostring(event.amount or ""),
    }, "|")
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
    tip:SetFrameStrata("HIGH")
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
    tip.valueRows = {}
    tip.headerRows = {}

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

    local function colorForTier(tier)
        if tier == "junk" then return 0.62, 0.62, 0.62 end
        if tier == "normal" then return 0.95, 0.95, 0.95 end
        if tier == "elite" then return 1.00, 0.30, 0.30 end
        if tier == "boss" then return 1.00, 0.50, 0.00 end
        return nil
    end
    local function colorForClass(classFile)
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local c = RAID_CLASS_COLORS[classFile]
            return c.r, c.g, c.b
        end
        return nil
    end
    local function colorForUnit(isSource)
        local name = isSource and entry.sourceName or entry.destName
        local classFile = isSource and entry.sourceClass or entry.destClass
        if Goals and Goals.GetPlayerColor and name and name ~= "" then
            local pr, pg, pb = Goals:GetPlayerColor(name)
            if pr and pg and pb then
                return pr, pg, pb
            end
        end
        local tier = isSource and entry.sourceTier or entry.destTier
        local tr, tg, tb = colorForTier(tier)
        if tr then
            return tr, tg, tb
        end
        local cr, cg, cb = colorForClass(classFile)
        if cr then
            return cr, cg, cb
        end
        return 1, 1, 1
    end
    local function groupType(event)
        if event.eventGroup == "aura" then return "Aura" end
        if event.eventGroup == "heal" then return "Heal" end
        if event.eventGroup == "damage" then return "Damage" end
        if event.eventGroup == "death" then return "Death" end
        if event.eventGroup == "miss" then return "Miss" end
        if event.eventGroup == "control" then return "Control" end
        if event.eventGroup == "resource" then return "Resource" end
        return "Event"
    end
    local function auraAction(event)
        if event.subevent == "SPELL_AURA_APPLIED" then return "Applied" end
        if event.subevent == "SPELL_AURA_REMOVED" then return "Lost" end
        if event.subevent == "SPELL_AURA_REFRESH" then return "Refreshed" end
        if event.subevent == "SPELL_AURA_APPLIED_DOSE" then return "Stacked" end
        if event.subevent == "SPELL_AURA_REMOVED_DOSE" then return "Unstacked" end
        if event.subevent == "SPELL_AURA_BROKEN" or event.subevent == "SPELL_AURA_BROKEN_SPELL" then return "Broken" end
        return "Changed"
    end

    local function ensureHeaderRow(index)
        if tip.headerRows[index] then
            return tip.headerRows[index]
        end
        local row = CreateFrame("Frame", nil, tip.content)
        local label, frame = createOptionsHeader(row, "", 0)
        row.headerLabel = label
        row.headerFrame = frame
        tip.headerRows[index] = row
        return row
    end
    local function ensureValueRow(index)
        if tip.valueRows[index] then
            return tip.valueRows[index]
        end
        local row = CreateFrame("Frame", nil, tip.content)
        local label = createLabel(row, "", "GameFontNormalSmall")
        styleOptionsControlLabel(label)
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        label:SetWidth(78)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        local value = createLabel(row, "", "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT", label, "TOPRIGHT", 6, 0)
        value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        value:SetJustifyH("LEFT")
        value:SetJustifyV("TOP")
        value:SetWordWrap(true)
        if value.SetNonSpaceWrap then
            value:SetNonSpaceWrap(true)
        end
        row.label = label
        row.value = value
        tip.valueRows[index] = row
        return row
    end

    local y = -6
    local usedHeaderRows = 0
    local usedValueRows = 0
    local function pushHeader(text)
        usedHeaderRows = usedHeaderRows + 1
        local row = ensureHeaderRow(usedHeaderRows)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tip.content, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", tip.content, "TOPRIGHT", 0, y)
        row:SetHeight(OPTIONS_HEADER_HEIGHT or 18)
        if row.headerLabel then
            row.headerLabel:SetText(text or "")
        end
        if row.headerFrame then
            row.headerFrame:Show()
            row.headerFrame:ClearAllPoints()
            row.headerFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.headerFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        end
        y = y - ((OPTIONS_HEADER_HEIGHT or 18) + 2)
    end
    local function pushValue(labelText, valueText, r, g, b)
        if not valueText or valueText == "" then
            return
        end
        valueText = tostring(valueText)
        usedValueRows = usedValueRows + 1
        local row = ensureValueRow(usedValueRows)
        row:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", tip.content, "TOPLEFT", 8, y)
        row:SetPoint("TOPRIGHT", tip.content, "TOPRIGHT", -8, y)
        row.label:SetText(labelText or "")
        row.value:SetText(valueText)
        if row.value.SetTextColor and r then
            row.value:SetTextColor(r, g or r, b or r, 1)
        else
            row.value:SetTextColor(1, 1, 1, 1)
        end
        local h = math.max(row.label:GetStringHeight() or 12, row.value:GetStringHeight() or 12)
        row:SetHeight(h)
        y = y - (h + 4)
    end

    if tip.TitleText then
        local title = "Combat Details"
        if UI and UI.combatTooltipLocked then
            title = title .. " (Locked)"
        end
        tip.TitleText:SetText(title)
        if UI and UI.GetCombatThemePalette then
            local pal = UI:GetCombatThemePalette()
            if pal and pal.accent then
                tip.TitleText:SetTextColor(pal.accent[1], pal.accent[2], pal.accent[3], 1)
            end
        end
    end

    local sourceName = decorateSelfCombatName(entry.sourceName or entry.source or "Unknown")
    local targetName = decorateSelfCombatName(entry.destName or entry.player or "Unknown")
    local ability = entry.spellName or entry.spell or entry.subevent or ""
    local function fmtDuration(seconds)
        local s = tonumber(seconds) or 0
        if s < 0.1 then
            s = 0.1
        end
        local rounded = math.floor((s * 10) + 0.5) / 10
        local text = tostring(rounded)
        return string.gsub(text, "%.0$", "")
    end
    local where = (entry.subzone and entry.subzone ~= "" and entry.subzone) or entry.zone or ""
    if entry.coordsText and entry.coordsText ~= "" then
        where = where ~= "" and (where .. " " .. entry.coordsText) or entry.coordsText
    end
    local detailText, totalText
    if entry.eventGroup == "aura" then
        detailText = (entry.auraType == "BUFF" and "Buff") or (entry.auraType == "DEBUFF" and "Debuff") or "Aura"
        totalText = auraAction(entry)
    elseif entry.isCombinedOverTime then
        local total = tonumber(entry.combinedTotal or entry.effectiveAmount or entry.amount) or 0
        local duration = math.max(0.1, tonumber(entry.combinedDuration) or 0.1)
        local rate = tonumber(entry.combinedRate) or (total / duration)
        local oh = tonumber(entry.combinedOverheal or entry.overheal) or 0
        local ok = tonumber(entry.combinedOverkill or entry.overkill) or 0
        local rs = tonumber(entry.combinedResisted or entry.resisted) or 0
        local bl = tonumber(entry.combinedBlocked or entry.blocked) or 0
        local ab = tonumber(entry.combinedAbsorbed or entry.absorbed) or 0
        local prevented = (entry.eventGroup == "heal") and oh or (ok + rs + bl + ab)
        detailText = tostring(math.floor(rate + 0.5)) .. " (" .. tostring(math.floor((prevented / duration) + 0.5)) .. ") /s"
        totalText = tostring(math.floor(total + 0.5)) .. " ( " .. tostring(math.floor(prevented + 0.5)) .. " ) /" .. fmtDuration(duration) .. "s"
    elseif entry.amount then
        detailText = tostring(entry.effectiveAmount or entry.amount)
        if entry.overheal then
            detailText = detailText .. " (" .. tostring(entry.overheal) .. ")"
        elseif entry.resisted then
            detailText = detailText .. " (" .. tostring(entry.resisted) .. ")"
        elseif entry.overkill then
            detailText = detailText .. " (" .. tostring(entry.overkill) .. ")"
        end
        totalText = tostring(entry.rawAmount or entry.amount)
    elseif entry.eventText and entry.eventText ~= "" then
        detailText = entry.eventText
        totalText = "-"
    else
        detailText = entry.missType or ""
        totalText = "-"
    end
    local mitigations = {}
    if tonumber(entry.resisted) and tonumber(entry.resisted) > 0 then
        mitigations[#mitigations + 1] = "Resist " .. tostring(entry.resisted)
    end
    if tonumber(entry.blocked) and tonumber(entry.blocked) > 0 then
        mitigations[#mitigations + 1] = "Block " .. tostring(entry.blocked)
    end
    if tonumber(entry.absorbed) and tonumber(entry.absorbed) > 0 then
        mitigations[#mitigations + 1] = "Absorb " .. tostring(entry.absorbed)
    end
    if tonumber(entry.overkill) and tonumber(entry.overkill) > 0 then
        mitigations[#mitigations + 1] = "Overkill " .. tostring(entry.overkill)
    end
    if tonumber(entry.overheal) and tonumber(entry.overheal) > 0 then
        mitigations[#mitigations + 1] = "Overheal " .. tostring(entry.overheal)
    end
    local mitigationText = table.concat(mitigations, ", ")

    local sr, sg, sb = colorForUnit(true)
    local tr, tg, tb = colorForUnit(false)
    pushHeader("Summary")
    pushValue("Time:", formatCombatTimestamp(entry.timestamp or entry.ts))
    pushValue("Type:", groupType(entry))
    pushValue("Detail:", detailText)
    pushValue("Total:", totalText)
    pushValue("Where:", where, 0.8, 0.9, 1)

    pushHeader("Actors")
    pushValue("Source:", sourceName, sr, sg, sb)
    pushValue("Target:", targetName, tr, tg, tb)
    pushValue("Ability:", ability)
    pushValue("Subevent:", entry.subevent or "")
    pushValue("Raid Icon:", tostring(entry.sourceRaidIcon or ""))

    pushHeader("Breakdown")
    pushValue("Effective:", tostring(entry.effectiveAmount or ""))
    pushValue("Mitigation:", mitigationText)
    pushValue("Aura:", entry.auraType or "")
    pushValue("Result:", entry.auraState or auraAction(entry))
    if entry.isCombinedOverTime then
        local total = tonumber(entry.combinedTotal or entry.effectiveAmount or entry.amount) or 0
        local rawTotal = tonumber(entry.combinedRawTotal or entry.rawAmount or entry.amount) or total
        local duration = math.max(0.1, tonumber(entry.combinedDuration) or 0.1)
        local ticks = math.max(1, math.floor((tonumber(entry.combinedTicks) or 1) + 0.5))
        local rate = tonumber(entry.combinedRate) or (total / duration)
        local oh = tonumber(entry.combinedOverheal or entry.overheal) or 0
        local ok = tonumber(entry.combinedOverkill or entry.overkill) or 0
        local rs = tonumber(entry.combinedResisted or entry.resisted) or 0
        local bl = tonumber(entry.combinedBlocked or entry.blocked) or 0
        local ab = tonumber(entry.combinedAbsorbed or entry.absorbed) or 0
        local prevented = (entry.eventGroup == "heal") and oh or (ok + rs + bl + ab)

        pushHeader("Over-Time Combine")
        pushValue("Kind:", (entry.combinedKind == "hot" and "HoT") or "DoT")
        pushValue("Ticks:", tostring(ticks))
        pushValue("Duration:", fmtDuration(duration) .. "s")
        pushValue("Rate:", tostring(math.floor(rate + 0.5)) .. "/s")
        pushValue("Prevented/s:", tostring(math.floor((prevented / duration) + 0.5)) .. "/s")
        pushValue("Net Total:", tostring(math.floor(total + 0.5)))
        pushValue("Prevented:", tostring(math.floor(prevented + 0.5)))
        pushValue("Raw Total:", tostring(math.floor(rawTotal + 0.5)))
        pushValue("Overheal:", tostring(math.floor(oh + 0.5)))
        pushValue("Overkill:", tostring(math.floor(ok + 0.5)))
        pushValue("Resisted:", tostring(math.floor(rs + 0.5)))
        pushValue("Blocked:", tostring(math.floor(bl + 0.5)))
        pushValue("Absorbed:", tostring(math.floor(ab + 0.5)))
        pushValue("Start:", formatCombatTimestamp(entry.combinedStartTs or entry.timestamp or entry.ts))
        pushValue("End:", formatCombatTimestamp(entry.combinedEndTs or entry.timestamp or entry.ts))
    end

    for i = usedValueRows + 1, #tip.valueRows do
        tip.valueRows[i]:Hide()
    end
    for i = usedHeaderRows + 1, #tip.headerRows do
        tip.headerRows[i]:Hide()
    end

    local contentHeight = math.max(86, -y + 8)
    tip.content:SetHeight(contentHeight)
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
    UI.combatTooltipEntryKey = locked and combatEventKey(entry) or nil
    if UI and UI.UpdateDamageTrackerList then
        UI:UpdateDamageTrackerList()
    end
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









local function getLootNoteKey(itemLink, ts)
    if not itemLink or itemLink == "" then
        return nil
    end
    return tostring(itemLink) .. "|" .. tostring(ts or 0)
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


-- Diagnostics and Settings tab implementations are loaded from UI modules.









































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

-- Private lexical bridge for UI modules loaded immediately after this file.
UI.ModuleContext = {
    addonName = addonName,
    addRowStripe = addRowStripe,
    anchorToFooter = anchorToFooter,
    applyBadgeStyle = applyBadgeStyle,
    applyFrameTheme = applyFrameTheme,
    applyInsetTheme = applyInsetTheme,
    applySectionCaption = applySectionCaption,
    applySectionHeader = applySectionHeader,
    applySectionHeaderAfter = applySectionHeaderAfter,
    applyTextureColor = applyTextureColor,
    attachSideTooltip = attachSideTooltip,
    badgeColorCode = badgeColorCode,
    bindEscapeClear = bindEscapeClear,
    bindLiveSearch = bindLiveSearch,
    buildBadgeText = buildBadgeText,
    buildPreviewEntries = buildPreviewEntries,
    classColorList = classColorList,
    clearCombatRowTooltipLock = clearCombatRowTooltipLock,
    colorizeItemName = colorizeItemName,
    colorizeName = colorizeName,
    COMBAT_DETAIL_DYNAMIC_CAP = COMBAT_DETAIL_DYNAMIC_CAP,
    COMBAT_DETAIL_WIDTH_BASE = COMBAT_DETAIL_WIDTH_BASE,
    COMBAT_DISPLAY_CHAT = COMBAT_DISPLAY_CHAT,
    COMBAT_DISPLAY_TABLE = COMBAT_DISPLAY_TABLE,
    COMBAT_DYNAMIC_DEADZONE = COMBAT_DYNAMIC_DEADZONE,
    COMBAT_DYNAMIC_EXTRA_MAX = COMBAT_DYNAMIC_EXTRA_MAX,
    COMBAT_ROW_BG_EVENT_TINT = COMBAT_ROW_BG_EVENT_TINT,
    COMBAT_ROW_BG_NEUTRAL = COMBAT_ROW_BG_NEUTRAL,
    COMBAT_SHOW_ALL = COMBAT_SHOW_ALL,
    COMBAT_SHOW_BOSS = COMBAT_SHOW_BOSS,
    COMBAT_SHOW_TRASH = COMBAT_SHOW_TRASH,
    COMBAT_THEME_ALLIANCE = COMBAT_THEME_ALLIANCE,
    COMBAT_THEME_CLASS = COMBAT_THEME_CLASS,
    COMBAT_THEME_HORDE = COMBAT_THEME_HORDE,
    COMBAT_THEME_NEUTRAL = COMBAT_THEME_NEUTRAL,
    COMBAT_TOTAL_DYNAMIC_CAP = COMBAT_TOTAL_DYNAMIC_CAP,
    COMBAT_TOTAL_WIDTH_BASE = COMBAT_TOTAL_WIDTH_BASE,
    COMBAT_WHERE_MIN_WIDTH = COMBAT_WHERE_MIN_WIDTH,
    combatEventKey = combatEventKey,
    CPU_DEBUG_DEFAULT_INTERVAL = CPU_DEBUG_DEFAULT_INTERVAL,
    CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD = CPU_DEBUG_DEFAULT_SPIKE_THRESHOLD,
    CPU_DEBUG_MAX_INTERVAL = CPU_DEBUG_MAX_INTERVAL,
    CPU_DEBUG_MAX_LINES = CPU_DEBUG_MAX_LINES,
    CPU_DEBUG_MAX_SPIKE_THRESHOLD = CPU_DEBUG_MAX_SPIKE_THRESHOLD,
    CPU_DEBUG_MIN_INTERVAL = CPU_DEBUG_MIN_INTERVAL,
    CPU_DEBUG_MIN_SPIKE_THRESHOLD = CPU_DEBUG_MIN_SPIKE_THRESHOLD,
    createBadge = createBadge,
    createDivider = createDivider,
    createFooterBar = createFooterBar,
    createLabel = createLabel,
    createOptionsButton = createOptionsButton,
    createOptionsDropdown = createOptionsDropdown,
    createOptionsHeader = createOptionsHeader,
    createOptionsPanel = createOptionsPanel,
    createSmallIconButton = createSmallIconButton,
    createTabFooter = createTabFooter,
    createTabFooter2 = createTabFooter2,
    createTableWidget = createTableWidget,
    DAMAGE_COL_AMOUNT = DAMAGE_COL_AMOUNT,
    DAMAGE_COL_SOURCE = DAMAGE_COL_SOURCE,
    DAMAGE_COL_SPELL = DAMAGE_COL_SPELL,
    DAMAGE_COL_TARGET = DAMAGE_COL_TARGET,
    DAMAGE_COL_TIME = DAMAGE_COL_TIME,
    DAMAGE_COLOR = DAMAGE_COLOR,
    DAMAGE_NAME_MAX_NPC = DAMAGE_NAME_MAX_NPC,
    DAMAGE_NAME_MAX_PLAYER = DAMAGE_NAME_MAX_PLAYER,
    DAMAGE_ROW_HEIGHT = DAMAGE_ROW_HEIGHT,
    DAMAGE_ROWS = DAMAGE_ROWS,
    DEATH_COLOR = DEATH_COLOR,
    DEBUG_ROW_HEIGHT = DEBUG_ROW_HEIGHT,
    DEBUG_ROWS = DEBUG_ROWS,
    decorateSelfCombatName = decorateSelfCombatName,
    ELITE_COLOR = ELITE_COLOR,
    ensureBuildPreviewTooltip = ensureBuildPreviewTooltip,
    ensureBuildShareTooltip = ensureBuildShareTooltip,
    ensureCombatRowTooltip = ensureCombatRowTooltip,
    ensureOverviewMigrationPrompt = ensureOverviewMigrationPrompt,
    ensureOverviewMigrationPromptWidgets = ensureOverviewMigrationPromptWidgets,
    ensureScrollBarBackground = ensureScrollBarBackground,
    extractNoteItemIds = extractNoteItemIds,
    fitLabelToWidth = fitLabelToWidth,
    fitWishlistLabel = fitWishlistLabel,
    FOOTER_BAR_EXTRA = FOOTER_BAR_EXTRA,
    FOOTER_BAR_GAP = FOOTER_BAR_GAP,
    FOOTER_BAR_HEIGHT = FOOTER_BAR_HEIGHT,
    FOOTER_BOTTOM_INSET = FOOTER_BOTTOM_INSET,
    formatCombatTimestamp = formatCombatTimestamp,
    formatPlayersCount = formatPlayersCount,
    formatTime = formatTime,
    FRAME_EDGE_MARGIN_UI = FRAME_EDGE_MARGIN_UI,
    getAccessStatus = getAccessStatus,
    getBossColor = getBossColor,
    getClassColorList = getClassColorList,
    getDropDownPart = getDropDownPart,
    getExpansionBadge = getExpansionBadge,
    getExpansionTooltip = getExpansionTooltip,
    getHistoryFilterSummary = getHistoryFilterSummary,
    getHistoryFilterValue = getHistoryFilterValue,
    getHistoryItemLink = getHistoryItemLink,
    getLootNoteKey = getLootNoteKey,
    getMiniSettings = getMiniSettings,
    getOverviewMigrationPromptText = getOverviewMigrationPromptText,
    getPlayerColor = getPlayerColor,
    getQualityLabel = getQualityLabel,
    getQualityOptions = getQualityOptions,
    getRainbowColor = getRainbowColor,
    getScrollBar = getScrollBar,
    getSortLabel = getSortLabel,
    getSourceColor = getSourceColor,
    getTierBadge = getTierBadge,
    getTierBadgeColor = getTierBadgeColor,
    getTierTooltip = getTierTooltip,
    getUpdateInfo = getUpdateInfo,
    getWishlistEnchantChatLink = getWishlistEnchantChatLink,
    getWishlistItemChatLink = getWishlistItemChatLink,
    Goals = Goals,
    hasDisenchanterAccess = hasDisenchanterAccess,
    hasModifyAccess = hasModifyAccess,
    hasPointGainAccess = hasPointGainAccess,
    HEAL_COLOR = HEAL_COLOR,
    hideBuildPreviewTooltip = hideBuildPreviewTooltip,
    hideBuildShareTooltip = hideBuildShareTooltip,
    hideCombatRowTooltip = hideCombatRowTooltip,
    hideSideTooltip = hideSideTooltip,
    HISTORY_ROW_HEIGHT = HISTORY_ROW_HEIGHT,
    HISTORY_ROW_HEIGHT_DOUBLE = HISTORY_ROW_HEIGHT_DOUBLE,
    HISTORY_ROWS = HISTORY_ROWS,
    insertWishlistChatLink = insertWishlistChatLink,
    isSelfCombatName = isSelfCombatName,
    isUpdateAvailable = isUpdateAvailable,
    L = L,
    layoutOverviewMigrationPrompt = layoutOverviewMigrationPrompt,
    LOOT_HISTORY_ROW_HEIGHT = LOOT_HISTORY_ROW_HEIGHT,
    LOOT_HISTORY_ROW_HEIGHT_COMPACT = LOOT_HISTORY_ROW_HEIGHT_COMPACT,
    LOOT_HISTORY_ROWS = LOOT_HISTORY_ROWS,
    LOOT_ROWS = LOOT_ROWS,
    MAIN_FRAME_HEIGHT = MAIN_FRAME_HEIGHT,
    MAIN_FRAME_WIDTH = MAIN_FRAME_WIDTH,
    MAIN_FRAME_WIDTH_COMBAT = MAIN_FRAME_WIDTH_COMBAT,
    MINI_DEFAULT_X = MINI_DEFAULT_X,
    MINI_DEFAULT_Y = MINI_DEFAULT_Y,
    MINI_FRAME_WIDTH = MINI_FRAME_WIDTH,
    MINI_HEADER_HEIGHT = MINI_HEADER_HEIGHT,
    MINI_ROW_HEIGHT = MINI_ROW_HEIGHT,
    OPTIONS_BUTTON_HEIGHT = OPTIONS_BUTTON_HEIGHT,
    OPTIONS_BUTTON_ID = OPTIONS_BUTTON_ID,
    OPTIONS_CHECKBOX_SIZE = OPTIONS_CHECKBOX_SIZE,
    OPTIONS_CONTROL_WIDTH = OPTIONS_CONTROL_WIDTH,
    OPTIONS_DROPDOWN_HEIGHT = OPTIONS_DROPDOWN_HEIGHT,
    OPTIONS_EDITBOX_HEIGHT = OPTIONS_EDITBOX_HEIGHT,
    OPTIONS_HEADER_HEIGHT = OPTIONS_HEADER_HEIGHT,
    OPTIONS_PANEL_WIDTH = OPTIONS_PANEL_WIDTH,
    PAGE_BOTTOM_OFFSET = PAGE_BOTTOM_OFFSET,
    registerSpecialFrame = registerSpecialFrame,
    resolveNoteItemIds = resolveNoteItemIds,
    REVIVE_COLOR = REVIVE_COLOR,
    ROSTER_ROWS = ROSTER_ROWS,
    ROW_HEIGHT = ROW_HEIGHT,
    setCheckText = setCheckText,
    setCombatRowTooltipLock = setCombatRowTooltipLock,
    setDropdownEnabled = setDropdownEnabled,
    setLootItemLabelText = setLootItemLabelText,
    setScrollBarAlwaysVisible = setScrollBarAlwaysVisible,
    setShown = setShown,
    setupBuildSharePopup = setupBuildSharePopup,
    setupSaveTableHelpPopup = setupSaveTableHelpPopup,
    setupSudoDevPopup = setupSudoDevPopup,
    showBuildPreviewTooltip = showBuildPreviewTooltip,
    showBuildShareTooltip = showBuildShareTooltip,
    showCombatRowTooltip = showCombatRowTooltip,
    showSideTooltip = showSideTooltip,
    showSideTooltipAt = showSideTooltipAt,
    stripTextureTags = stripTextureTags,
    styleDropdown = styleDropdown,
    styleOptionsButton = styleOptionsButton,
    styleOptionsCheck = styleOptionsCheck,
    styleOptionsCheckLabel = styleOptionsCheckLabel,
    styleOptionsControlLabel = styleOptionsControlLabel,
    styleOptionsEditBox = styleOptionsEditBox,
    styleOptionsLabel = styleOptionsLabel,
    styleOptionsSlider = styleOptionsSlider,
    THEME = THEME,
    THREAT_COLOR = THREAT_COLOR,
    TRASH_COLOR = TRASH_COLOR,
    UI = UI,
    WISHLIST_ROW_SPACING = WISHLIST_ROW_SPACING,
    WISHLIST_SLOT_SIZE = WISHLIST_SLOT_SIZE,
    wishlistCustomSources = wishlistCustomSources,
    wishlistHasBistooltip = wishlistHasBistooltip,
    wishlistHasLoon = wishlistHasLoon,
    wishlistHasWowhead = wishlistHasWowhead,
    wishlistSpecKey = wishlistSpecKey,
    wishlistWowtbcSource = wishlistWowtbcSource,
    wrapTextToWidth = wrapTextToWidth,
}
setmetatable(UI.ModuleContext, { __index = _G })
UI.ModuleHelpers = UI.ModuleContext
