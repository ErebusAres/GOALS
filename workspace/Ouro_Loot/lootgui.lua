
--[[
g_loot's numeric indices are loot entries (including titles, separators,
etc); its named indices are:
- forum:		saved text from forum markup window, default nil
- attend:		saved text from raid attendence window, default nil
- printed.FOO:	last index formatted into text window FOO, default 0
- saved:		table of copies of saved texts, default nil; keys are numeric
				indices of tables, subkeys of those are name/forum/attend/date
- autoshard:	optional name of disenchanting player, default nil
- threshold:	optional loot threshold, default nil

Functions arranged like this, with these lables (for jumping to).  As a
rule, member functions with UpperCamelCase names are called directly by
user-facing code, ones with lowercase names are "one step removed", and
names with leading underscores are strictly internal helper functions.
------ Saved variables
------ Constants
------ Globals
------ Expiring caches
------ Ace3 framework stuff
------ Event handlers
------ Slash command handler
------ On/off
------ Behind the scenes routines
------ Saved texts
------ Display window routines
------ Player communication
------ Popup dialogs

This started off as part of a raid addon package written by somebody else.
After he retired, I began modifying the code.  Eventually I set aside the
entire package and rewrote the loot tracker module from scratch.  Many of the
variable/function naming conventions (sv_*, g_*, and family) stayed across
the rewrite.
]]

------ Saved variables
sv_OLoot		= nil   -- possible copy of g_loot
sv_OLoot_opts	= nil   -- same as option_defaults until changed


------ Constants
local option_defaults = {
	["popup_on_join"] = true,
	["register_slashloot"] = true,
	["scroll_to_bottom"] = true,
	["chatty_on_kill"] = false,
	["snarky_boss"] = true,
	["keybinding"] = false,
	["keybinding_text"] = 'CTRL-SHIFT-O',
	["forum"] = {
		["[url]"] = '[url=http://www.wowhead.com/?item=$I]$N[/url]$X - $T',
		["[item] by name"] = '[item]$N[/item]$X - $T',
		["[item] by ID"] = '[item]$I[/item]$X - $T',
		["Custom..."] = '',
	},
	["forum_current"] = "[item] by name",
}
local virgin = "First time loaded?  Hi!  Use the /ouroloot or /loot command"
	.." to show the main display.  You should probably browse the instructions"
	.." if you've never used this before; %s to display the help window.  This"
	.." welcome message will not intrude again."
local revision					= 14
local ident, identTg			= "OuroLoot2", "OuroLoot2Tg"
local comm_cleanup_ttl			= 5   -- seconds in the cache
local qualnames = {
	["gray"] = 0, ["grey"] = 0, ["poor"] = 0, ["trash"] = 0,
	["white"] = 1, ["common"] = 1,
	["green"] = 2, ["uncommon"] = 2,
	["blue"] = 3, ["rare"] = 3,
	["epic"] = 4, ["purple"] = 4,
	["legendary"] = 5, ["orange"] = 5,
	["artifact"] = 6,
	--["heirloom"] = 7,
}
local thresholds, quality_hexes = {}, {}
for i = 0,6 do
	local hex = select(4,GetItemQualityColor(i))
	local desc = _G["ITEM_QUALITY"..i.."_DESC"]
	quality_hexes[i] = hex
	thresholds[i] = hex .. desc .. "|r"
end
-- This is an amalgamation of all four LOOT_ITEM_* patterns.
-- Captures:   1 person/You, 2 itemstring, 3 rest of string after final |r until '.'
-- Can change 'loot' to 'item' to trigger on, e.g., extracting stuff from mail.
local loot_pattern				= "(%S+) receives? loot:.*|cff%x+|H(.-)|h.*|r(.*)%.$"
local my_name					= UnitName("player")
local hypertext_format_str		= "|HOuroRaid:%s|h%s[%s]|r|h"

local eoi_st_rowheight			= 20
local eoi_st_displayed_rows		= math.floor(366/eoi_st_rowheight)
local eoi_st_textured_item_format = "|T%s:"..(eoi_st_rowheight-2).."|t %s[%s]|r%s"
local eoi_st_otherrow_bgcolortable = {
	wipe	= { ["r"] = 0.3, ["g"] = 0.3, ["b"] = 0.3},
	kill	= { ["r"] = 0.2, ["g"] = 0.2, ["b"] = 0.2},
	time	= { ["r"] = 0x0/255, ["g"] = 0x0/255, ["b"] = 1, ["a"] = 0.3},
}
eoi_st_otherrow_bgcolortable[""] = eoi_st_otherrow_bgcolortable["kill"]
local eoi_st_lootrow_col3_colortable = {
	[""]	= { text = "", r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
	shard	= { text = "shard", r = 0xa3/255, g = 0x35/255, b = 0xee/255, a = 1.0 },
	offspec	= { text = "offspec", r = 0.78, g = 0.61, b = 0.43, a = 1.0 },
	gvault	= { text = "guild vault", r = 0x33/255, g = 1.0, b = 0x99/255, a = 1.0 },
}
local function eoi_st_lootrow_col3_colortable_func (data, cols, realrow, column, table)
	local disp = data[realrow].disposition
	return eoi_st_lootrow_col3_colortable[disp or ""]
end


------ Globals
local addon = select(2,...)
local DEBUG_PRINT = false
local g_debug = {
	comm = false,
	loot = false,
	flow = false,
	notraid = false,
	cache = false,
}
local function dprint(t,...)
	if DEBUG_PRINT and g_debug[t] then return _G.print("<"..t.."> ",...) end
end
--[[
local function tabledump(...)
	UIParentLoadAddOn"Blizzard_DebugTools"
	_G.CHEESE=...
	DevTools_DumpCommand("CHEESE")
end]]
local function pprint(t,...)
	--if my_name == "Farmbuyer" then return _G.print("<"..t.."> ",...) end
end

local g_display			= nil   -- visible display frame
local g_popped			= nil   -- non-nil when reminder has been shown, actual value unimportant
local g_enabled			= false
local g_rebroadcast		= false
local g_sender_list		= {active={},names={}}   -- this should be reworked
local g_loot			= nil
local g_loot_clean		= nil
local g_generated		= nil
local g_threshold		= g_debug.loot and 0 or 3     -- rare by default
local g_dbm_registered	= nil
local g_restore_p		= nil
local g_status_text		= nil
local g_saved_tmp		= nil   -- restoring across a clear
local g_sharder			= nil   -- name of person whose loot is marked as shards
local g_wafer_thin		= nil   -- for prompting for additional rebroadcasters
local g_requesting		= nil   -- for prompting for additional rebroadcasters

-- En masse forward decls of symbols defined inside local blocks
local _registerDBM, _mark_boss_kill   -- DBM
local makedate, _fill_out_data, _generate_text, _populate_text_specials
local _addLootEntry, create_new_cache, _init, _find_next_after
local tabtexts, taborder -- filled out in gui block scope

addon = LibStub("AceAddon-3.0"):NewAddon(addon, "Ouro Loot",
                "AceTimer-3.0", "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0")
--_G.OL = addon -- XXX debug only
local GUI = LibStub("AceGUI-3.0")

-- Hypertext support, inspired by DBM broadcast pizza timers
local function format_hypertext (code, text, color)
	return hypertext_format_str:format (code,
		type(color)=="number" and quality_hexes[color] or color,
		text)
end
do
	DEFAULT_CHAT_FRAME:HookScript("OnHyperlinkClick", function(self, link, string, mousebutton)
		local ltype, arg = strsplit(":",link)
		if ltype ~= "OuroRaid" then return end
		if arg == 'openloot' then
			addon:BuildMainDisplay()
		elseif arg == 'help' then
			addon:BuildMainDisplay('help')
		elseif arg == 'bcaston' then
			if not g_rebroadcast then
				addon:Activate(nil,true)
			end
			addon:broadcast('bcast_responder')
		elseif arg == 'waferthin' then   -- mint? it's wafer thin!
			g_wafer_thin = true          -- fuck off, I'm full
			addon:broadcast('bcast_denied')   -- XXX remove once tested
		end
	end)

	local old = ItemRefTooltip.SetHyperlink
	function ItemRefTooltip:SetHyperlink (link, ...)
		if link:match("^OuroRaid") then return end
		return old (self, link, ...)
	end
end

do
	-- copied here because it's declared local to the calendar ui, thanks blizz ><
	local CALENDAR_FULLDATE_MONTH_NAMES = {
		FULLDATE_MONTH_JANUARY, FULLDATE_MONTH_FEBRUARY, FULLDATE_MONTH_MARCH,
		FULLDATE_MONTH_APRIL, FULLDATE_MONTH_MAY, FULLDATE_MONTH_JUNE,
		FULLDATE_MONTH_JULY, FULLDATE_MONTH_AUGUST, FULLDATE_MONTH_SEPTEMBER,
		FULLDATE_MONTH_OCTOBER, FULLDATE_MONTH_NOVEMBER, FULLDATE_MONTH_DECEMBER,
	}
	-- returns "dd Month yyyy", mm, dd, yyyy
	function makedate()
		Calendar_LoadUI()
		local _, M, D, Y = CalendarGetDate()
		local text = ("%d %s %d"):format(D, CALENDAR_FULLDATE_MONTH_NAMES[M], Y)
		return text, M, D, Y
	end
end

-- Working around this bug:
-- http://forums.wowace.com/showpost.php?p=295202&postcount=31
do
	local function FixFrameLevel (level, ...)
		for i = 1, select("#", ...) do
			local button = select(i, ...)
			button:SetFrameLevel(level)
		end
	end

	local function FixMenuFrameLevels()
		local f = DropDownList1
		local i = 1
		while f do
			FixFrameLevel (f:GetFrameLevel() + 2, f:GetChildren())
			i = i + 1
			f = _G["DropDownList"..i]
		end
	end

	-- To fix Blizzard's bug caused by the new "self:SetFrameLevel(2);"
	hooksecurefunc("UIDropDownMenu_CreateFrames", FixMenuFrameLevels)
end

-- Returns an instance name or abbreviation
local function instance_tag()
	local name, typeof, diffcode, diffstr, _, perbossheroic, isdynamic = GetInstanceInfo()
	local t
	name = addon.instance_abbrev[name] or name
	if typeof == "none" then return name end
	-- diffstr is "5 Player", "10 Player (Heroic)", etc.  ugh.
	if diffcode == 1 then
		t = ((GetNumRaidMembers()>0) and "10" or "5")
	elseif diffcode == 2 then
		t = ((GetNumRaidMembers()>0) and "25" or "5h")
	elseif diffcode == 3 then
		t = "10h"
	elseif diffcode == 4 then
		t = "25h"
	end
	-- dynamic difficulties always return normal "codes"
	if isdynamic and perbossheroic == 1 then
		t = t .. "h"
	end
	return name .. "(" .. t .. ")"
end


------ Expiring caches
--[[
foo = create_new_cache("myfoo",15[,cleanup]) -- ttl
foo:add("blah")
foo:test("blah")   -- returns true
]]
do
	local caches = {}
	local cleanup_group = AnimTimerFrame:CreateAnimationGroup()
	cleanup_group:SetLooping("REPEAT")
	cleanup_group:SetScript("OnLoop", function(cg)
		dprint('cache',"OnLoop firing")
		local now = GetTime()
		local alldone = true
		-- this is ass-ugly
		for _,c in ipairs(caches) do
			while (#c > 0) and (now - c[1].t > c.ttl) do
				dprint('cache', c.name, "cache removing",c[1].t, c[1].m)
				table.remove(c,1)
			end
			alldone = alldone and (#c == 0)
		end
		if alldone then
			dprint('cache',"OnLoop finishing animation group")
			cleanup_group:Finish()
			for _,c in ipairs(caches) do
				if c.func then c:func() end
			end
		end
		dprint('cache',"OnLoop done")
	end)

	local function _add (cache, x)
		table.insert(cache, {t=GetTime(),m=x})
		if not cleanup_group:IsPlaying() then
			dprint('cache', cache.name, "STARTING animation group")
			cache.cleanup:SetDuration(2)  -- hmmm
			cleanup_group:Play()
		end
	end
	local function _test (cache, x)
		for _,v in ipairs(cache) do
			if v.m == x then return true end
		end
	end
	function create_new_cache (name, ttl, on_alldone)
		local c = {
			ttl = ttl,
			name = name,
			add = _add,
			test = _test,
			cleanup = cleanup_group:CreateAnimation("Animation"),
			func = on_alldone,
		}
		c.cleanup:SetOrder(1)
		-- setting OnFinished for cleanup fires at the end of each inner loop,
		-- with no 'requested' argument to distinguish cases.  thus, on_alldone.
		table.insert (caches, c)
		return c
	end
end


------ Ace3 framework stuff
function addon:OnInitialize()
	-- VARIABLES_LOADED has fired by this point; test if we're doing something like
	-- relogging during a raid and already have collected loot data
	g_restore_p = sv_OLoot ~= nil
	dprint('flow', "oninit sets restore as", g_restore_p)

	if sv_OLoot_opts == nil then
		sv_OLoot_opts = {}
		self:ScheduleTimer(function(s)
			s:Print(virgin, format_hypertext('help',"click here",ITEM_QUALITY_UNCOMMON))
			virgin = nil
		end,10,self)
	end
	for opt,default in pairs(option_defaults) do
		if sv_OLoot_opts[opt] == nil then
			sv_OLoot_opts[opt] = default
		end
	end
	option_defaults = nil
	-- transition/remove old options
	sv_OLoot_opts["forum_use_itemid"] = nil
	if sv_OLoot_opts["forum_format"] then
		sv_OLoot_opts.forum["Custom..."] = sv_OLoot_opts["forum_format"]
		sv_OLoot_opts["forum_format"] = nil
	end
	-- get item filter table if needed
	if sv_OLoot_opts.itemfilter == nil then
		sv_OLoot_opts.itemfilter = addon.default_itemfilter
	end
	addon.default_itemfilter = nil

	self:RegisterChatCommand("ouroloot", "OnSlash")
	-- maybe try to detect if this command is already in use...
	if sv_OLoot_opts.register_slashloot then
		SLASH_ACECONSOLE_OUROLOOT2 = "/loot"
	end

	_init(self)
	self.OnInitialize = nil
end

function addon:OnEnable()
	self:RegisterEvent "PLAYER_LOGOUT"
	self:RegisterEvent "RAID_ROSTER_UPDATE"

	-- Cribbed from Talented.  I like the way jerry thinks: the first argument
	-- can be a format spec for the remainder of the arguments.  (The new
	-- AceConsole:Printf isn't used because we can't specify a prefix without
	-- jumping through ridonkulous hoops.)  The part about overriding :Print
	-- with a version using prefix hyperlinks is my fault.
	do
		local AC = LibStub("AceConsole-3.0")
		local chat_prefix = format_hypertext('openloot',"Ouro Loot",--[[legendary]]5)
		function addon:Print (str, ...)
			if type(str) == "string" and str:find("%", nil, --[[plainmatch=]]true) then
				return AC:Print (chat_prefix, str:format(...))
			else
				return AC:Print (chat_prefix, str, ...)
			end
		end
	end

	if sv_OLoot_opts.keybinding then
		local btn = CreateFrame("Button", "OuroLootBindingOpen", nil, "SecureActionButtonTemplate")
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("macrotext", "/ouroloot toggle")
		if SetBindingClick(sv_OLoot_opts.keybinding_text, "OuroLootBindingOpen") then
			SaveBindings(GetCurrentBindingSet())
		else
			self:Print("Error registering '%s' as a keybinding, check spelling!",
				sv_OLoot_opts.keybinding_text)
		end
	end

	if g_debug.flow then self:Print"is in control-flow debug mode." end
end
--function addon:OnDisable() end


------ Event handlers
function addon:PLAYER_LOGOUT()
	if (#g_loot > 0) or g_loot.saved
	   or (g_loot.forum and g_loot.forum ~= "")
	   or (g_loot.attend and g_loot.attend ~= "")
	then
		g_loot.autoshard = g_sharder
		g_loot.threshold = g_threshold
		sv_OLoot = g_loot
		for i,e in ipairs(sv_OLoot) do
			e.cols = nil
		end
	end
end

function addon:RAID_ROSTER_UPDATE (event)
	if GetNumRaidMembers() > 0 then
		local inside,whatkind = IsInInstance()
		if inside and (whatkind == "pvp" or whatkind == "arena") then
			return dprint('flow', "got RRU event but in pvp zone, bailing")
		end
		if event == "Activate" then
			-- dispatched manually from Activate
			self:RegisterEvent "CHAT_MSG_LOOT"
			_registerDBM(self)
		elseif event == "RAID_ROSTER_UPDATE" then
			-- event registration from onload, joined a raid, maybe show popup
			if sv_OLoot_opts.popup_on_join and not g_popped then
				g_popped = StaticPopup_Show "OUROL_REMIND"
				g_popped.data = self
			end
		end
	else
		self:UnregisterEvent "CHAT_MSG_LOOT"
		g_popped = nil
	end
end

-- helper for CHAT_MSG_LOOT handler
do
	-- Recent loot cache
	addon.recent_loot = create_new_cache ('loot', comm_cleanup_ttl)

	-- 'from' and onwards only present if this is triggered by a broadcast
	local function _do_loot (self, recipient, itemid, count, from, extratext)
		local iname, ilink, iquality, _,_,_,_,_,_, itexture = GetItemInfo(itemid)
		if not iname then return end   -- sigh
		dprint('loot',">>_do_loot, R:", recipient, "I:", itemid, "C:", count, "frm:", from, "ex:", extratext)

		local i
		itemid = tonumber(ilink:match("item:(%d+)"))
		if (iquality >= g_threshold) and not sv_OLoot_opts.itemfilter[itemid] then
			if g_rebroadcast and (not from) then
				self:broadcast('loot', recipient, itemid, count)
			end
			if g_enabled then
				local signature = recipient .. iname .. (count or "")
				if self.recent_loot:test(signature) then
					dprint('cache', "loot <",signature,"> already in cache, skipping")
				else
					self.recent_loot:add(signature)
					i = _addLootEntry{   -- There is some redundancy here...
						kind		= 'loot',
						person		= recipient,
						person_class= select(2,UnitClass(recipient)),
						quality		= iquality,
						itemname	= iname,
						id			= itemid,
						itemlink	= ilink,
						itexture	= itexture,
						disposition	= (recipient == g_sharder) and 'shard' or nil,
						count		= count,
						bcast_from	= from,
						extratext	= extratext,
						is_heroic	= self:is_heroic_item(ilink),
					}
					dprint('loot', "added entry", i)
					if g_display and g_display:IsVisible() then
						local st = g_display:GetUserData("ST")
						if st and st.frame:IsVisible() then
							st:OuroLoot_Refresh()
						end
					end
				end
			end
		end
		dprint('loot',"<<_do_loot out")
		return i
	end

	function addon:CHAT_MSG_LOOT (event, ...)
		if (not g_rebroadcast) and (not g_enabled) and (event ~= "manual") then return end

		--[[
			iname:		Hearthstone
			iquality:	integer
			ilink:		clickable formatted link
			itemstring:	item:6948:....
			itexture:	inventory icon texture
		]]

		if event == "CHAT_MSG_LOOT" then
			local msg = ...
			--ChatFrame2:AddMessage("original string:  >"..(msg:gsub("\124","\124\124")).."<")
			local person, itemstring, remainder = msg:match(loot_pattern)
			dprint('loot', "CHAT_MSG_LOOT, person is", person, ", itemstring is", itemstring, ", rest is", remainder)
			if not person then return end    -- "So-and-So selected Greed", etc, not actual looting
			local count = remainder and remainder:match(".*(x%d+)$")

			-- Name might be colorized, remove the highlighting
			local p = person:match("|c%x%x%x%x%x%x%x%x(%S+)")
			person = p or person
			person = (person == UNIT_YOU) and my_name or person

			local id = tonumber((select(2, strsplit(":", itemstring))))

			return _do_loot (self, person, id, count)

		elseif event == "broadcast" then
			return _do_loot(self,...)

		elseif event == "manual" then
			local r,i,n = ...
			return _do_loot(self,r,i,nil,nil,n)
		end
	end
end


------ Slash command handler
-- Thought about breaking this up into a table-driven dispatcher.  But
-- that would result in a pile of teensy functions, most of which would
-- never be called.  Too much overhead.  (2.0:  Most of these removed now
-- that GUI is in place.)
function addon:OnSlash(txt, editbox)
	txt = strtrim(txt:lower())
	local cmd, arg = ""
	do
		local s,e = txt:find("^%a+")
		if s then
			cmd = txt:sub(s,e)
			s = txt:find("%S", e+2)
			if s then arg = txt:sub(s,-1) end
		end
	end

	if cmd == "" then
		if InCombatLockdown() then
			return self:Print("Can't display window in combat.")
		else
			return self:BuildMainDisplay()
		end

	elseif cmd:find("^thre") then
		self:SetThreshold(arg)

	elseif cmd == "on" then								self:Activate(arg)
	elseif cmd == "off" then							self:Deactivate()
	elseif cmd == "broadcast" or cmd == "bcast" then	self:Activate(nil,true)

	elseif cmd == "fake" then  -- maybe comment this out for real users
		_mark_boss_kill (self, _addLootEntry{
			kind='boss',reason='kill',bosskill="Baron Steamroller",instance=instance_tag(),duration=0
		})
		self:Print"Baron Steamroller has been slain.  *yawn*   Congratulations."

	elseif cmd == "debug" then
		if arg then
			g_debug[arg] = not g_debug[arg]
			print(arg,g_debug[arg])
			if g_debug[arg] then DEBUG_PRINT = true end
		else
			DEBUG_PRINT = not DEBUG_PRINT
		end

	elseif cmd == "save" and arg and arg:len() > 0 then
		self:save_saveas(arg)
	elseif cmd == "list" then
		self:save_list()
	elseif cmd == "restore" and arg and arg:len() > 0 then
		self:save_restore(tonumber(arg))
	elseif cmd == "delete" and arg and arg:len() > 0 then
		self:save_delete(tonumber(arg))

	elseif cmd == "help" then
		self:BuildMainDisplay('help')
	elseif cmd == "toggle" then
		if g_display and g_display:IsVisible() then
			g_display:Hide()
		else
			return self:BuildMainDisplay()
		end

	else
		for tab,v in pairs(tabtexts) do
			if v.title:lower():find('^'..cmd) then
				self:BuildMainDisplay(tab)
				return
			end
		end
		self:Print("Unknown command '%s'. %s to see the help window.",
			cmd, format_hypertext('help',"Click here",ITEM_QUALITY_UNCOMMON))
	end
end

function addon:SetThreshold (arg, quiet_p)
	local q = tonumber(arg)
	if q then
		q = math.floor(q+0.001)
		if q<0 or q>6 then
			return self:Print("Threshold must be 0-6.")
		end
	else
		q = qualnames[arg]
		if not q then
			return self:Print("Unrecognized item quality argument.")
		end
	end
	g_threshold = q
	if not quiet_p then self:Print("Threshold now set to %s.", thresholds[q]) end
end


------ On/off
function addon:Activate (opt_threshold, opt_bcast_only)
	self:RegisterEvent "RAID_ROSTER_UPDATE"
	g_popped = true
	if GetNumRaidMembers() > 0 then
		self:RAID_ROSTER_UPDATE("Activate")
	elseif g_debug.notraid then
		self:RegisterEvent "CHAT_MSG_LOOT"
		_registerDBM(self)
	elseif g_restore_p then
		g_restore_p = nil
		if #g_loot == 0 then return end -- only saved texts, not worth verbage
		self:Print("Ouro Raid Loot restored previous data, but not in a raid",
				"and 5-person mode not active.  |cffff0505NOT tracking loot|r;",
				"use 'enable' to activate loot tracking, or 'clear' to erase",
				"previous data, or 'help' to read about saved-texts commands.")
		g_popped = nil  -- get the reminder if later joining a raid
		return
	end
	g_rebroadcast = true  -- hardcode to true; this used to be more complicated
	g_enabled = not opt_bcast_only
	if opt_threshold then
		self:SetThreshold(opt_threshold, --[[quiet_p=]]true)
	end
	self:Print("Ouro Raid Loot is %s.  Threshold currently %s.",
		g_enabled and "tracking" or "only broadcasting",
		thresholds[g_threshold])
end

-- Note:  running '/loot off' will also avoid the popup reminder when
-- joining a raid, but will not change the saved option setting.
function addon:Deactivate()
	g_enabled = false
	g_rebroadcast = false
	self:UnregisterEvent "RAID_ROSTER_UPDATE"
	self:UnregisterEvent "CHAT_MSG_LOOT"
	self:Print("Ouro Raid Loot deactivated.")
end

function addon:Clear(verbose_p)
	local repopup, st
	if g_display and g_display:IsVisible() then
		-- in the new version, this is likely to always be the case
		repopup = true
		st = g_display:GetUserData("ST")
		if not st then
			dprint('flow', "Clear: display visible but ST not set??")
		end
		g_display:Hide()
	end
	g_restore_p = nil
	sv_OLoot = nil
	self:_reset_timestamps()
	g_saved_tmp = g_loot.saved
	if verbose_p then
		if (g_saved_tmp and #g_saved_tmp>0) then
			self:Print("Current loot data cleared, %d saved sets remaining.", #g_saved_tmp)
		else
			self:Print("Current loot data cleared.")
		end
	end
	_init(self,st)
	if repopup then
		addon:BuildMainDisplay()
	end
end


------ Behind the scenes routines
-- Message sending.
-- See OCR_funcs.tag at the end of this file for incoming message treatment.
do
	local function assemble(...)
		local msg = ...
		for i = 2, select('#',...) do
			msg = msg .. '\a' .. (select(i,...) or "")
		end
		return msg
	end

	-- broadcast('tag', <stuff>)
	function addon:broadcast(...)
		local msg = assemble(...)
		dprint('comm', "<broadcast>:", msg)
		-- the "GUILD" here is just so that we can also pick up on it
		self:SendCommMessage(ident, msg, g_debug.comm and "GUILD" or "RAID")
	end
	-- whispercast(<to>, 'tag', <stuff>)
	function addon:whispercast(to,...)
		local msg = assemble(...)
		dprint('comm', "<whispercast>@", to, ":", msg)
		self:SendCommMessage(identTg, msg, "WHISPER", to)
	end
end

-- Generic helpers
function _find_next_after (kind, index)
	index = index + 1
	while index <= #g_loot do
		if g_loot[index].kind == kind then
			return index, g_loot[index]
		end
		index = index + 1
	end
end

-- Iterate through g_loot entries according to the KIND field.  Loop variables
-- are g_loot indices and the corresponding entries (essentially ipairs + some
-- conditionals).
function addon:filtered_loot_iter (filter_kind)
	return _find_next_after, filter_kind, 0
end

do
	local itt
	local function create()
		local tip, lefts = CreateFrame("GameTooltip"), {}
		for i = 1, 2 do -- scanning idea here also snagged from Talented
			local L,R = tip:CreateFontString(), tip:CreateFontString()
			L:SetFontObject(GameFontNormal)
			R:SetFontObject(GameFontNormal)
			tip:AddFontStrings(L,R)
			lefts[i] = L
		end
		tip.lefts = lefts
		return tip
	end
	function addon:is_heroic_item(item)   -- returns true or *nil*
		itt = itt or create()
		itt:SetOwner(UIParent,"ANCHOR_NONE")
		itt:ClearLines()
		itt:SetHyperlink(item)
		local t = itt.lefts[2]:GetText()
		itt:Hide()
		return (t == ITEM_HEROIC) or nil
	end
end

-- Called when first loading up, and then also when a 'clear' is being
-- performed.  If SV's are present then restore_p will be true.
function _init (self, possible_st)
	dprint('flow',"_init running")
	g_loot_clean = nil
	g_generated = nil
	if g_restore_p then
		g_loot = sv_OLoot
		g_popped = true
		dprint('flow', "restoring", #g_loot, "entries")
		self:ScheduleTimer("Activate", 8, g_loot.threshold)
		-- XXX printed could be too large if entries were deleted, how much do we care?
		g_sharder = g_loot.autoshard
		self:zero_printed_fenceposts()                  -- g_loot.printed.* = previous/safe values
	else
		g_loot = { printed = {} }
		self:zero_printed_fenceposts(0)                 -- g_loot.printed.* = 0
		g_loot.saved = g_saved_tmp; g_saved_tmp = nil	-- potentially restore across a clear
	end
	g_threshold = g_loot.threshold or g_threshold -- in the case of restoring but not tracking
	if possible_st then
		possible_st:SetData(g_loot)
	end
	self:RegisterComm(ident)
	self:RegisterComm(identTg, "OnCommReceivedNocache")
	g_status_text = "v2r" .. revision .. " communicating as ident " .. ident
end

-- Tie-ins with Deadly Boss Mods
do
	local callback = function(...) addon:DBMBossCallback(...) end
	local candidates, location
	local function fixup_durations (cache)
		if candidates == nil then return end  -- this is called for *all* cache expirations, including non-boss
		local boss, bossi
		boss = candidates[1]
		if #candidates == 1 then
			-- (1) or (2)
			boss.duration = boss.duration or 0
			dprint('loot', "only one candidate")
		else
			-- (3), should only be one 'cast entry and our local entry
			if #candidates ~= 2 then
				-- could get a bunch of 'cast entries on the heels of one another
				-- before the local one ever fires, apparently... sigh
				--addon:Print("<warning> s3 cache has %d entries, does that seem right to you?", #candidates)
			end
			if candidates[2].duration == nil then
				--addon:Print("<warning> s3's second entry is not the local trigger, does that seem right to you?")
			end
			-- try and be generic anyhow
			for i,c in ipairs(candidates) do
				if c.duration then
					boss = c
					dprint('loot', "fixup found candidate", i, "duration", c.duration)
					break
				end
			end
		end
		bossi = _addLootEntry(boss)
		dprint('loot', "added entry", bossi)
		if boss.reason == 'kill' then
			_mark_boss_kill (addon, bossi)
			if sv_OLoot_opts.chatty_on_kill then
				addon:Print("Registered kill for '%s' in %s!", boss.bosskill, boss.instance)
			end
		end
		candidates = nil
	end
	addon.recent_boss = create_new_cache ('boss', 10, fixup_durations)

	function _registerDBM(self)
		if DBM then
			if not g_dbm_registered then
				local rev = tonumber(DBM.Revision) or 0
				if rev < 1503 then
					g_status_text = "Deadly Boss Mods must be version 1.26 or newer to work with Ouro Loot."
					return
				end
				local r = DBM:RegisterCallback("kill", callback)
						  DBM:RegisterCallback("wipe", callback)
						  DBM:RegisterCallback("pull", function() location = instance_tag() end)
				g_dbm_registered = r > 0
			end
		else
			g_status_text = "Ouro Loot cannot find Deadly Boss Mods, loot will not be grouped by boss."
		end
	end

	-- Similar to _do_loot, but duration+ parms only present when locally generated.
	local function _do_boss (self, reason, bossname, intag, duration, raiders)
		dprint('loot',">>_do_boss, R:", reason, "B:", bossname, "T:", intag,
		       "D:", duration, "RL:", (raiders and #raiders or 'nil'))
		if g_rebroadcast and duration then
			self:broadcast('boss', reason, bossname, intag)
		end
		if g_enabled then
			bossname = (sv_OLoot_opts.snarky_boss and self.boss_abbrev[bossname] or bossname) or bossname
			local not_from_local = duration == nil
			local signature = bossname .. reason
			if not_from_local and self.recent_boss:test(signature) then
				dprint('cache', "boss <",signature,"> already in cache, skipping")
			else
				self.recent_boss:add(signature)
				-- Possible scenarios:  (1) we don't see a boss event at all (e.g., we're
				-- outside the instance) and so this only happens once as a non-local event,
				-- (2) we see a local event first and all non-local events are filtered
				-- by the cache, (3) we happen to get some non-local events before doing
				-- our local event (not because of network weirdness but because our local
				-- DBM might not trigger for a while).
				local c = {
					kind		= 'boss',
					bosskill	= bossname,      -- minor misnomer, might not actually be a kill
					reason		= reason,
					instance	= intag,
					duration	= duration,      -- these two deliberately may be nil
					raiderlist	= raiders and table.concat(raiders, ", ")
				}
				candidates = candidates or {}
				table.insert(candidates,c)
			end
		end
		dprint('loot',"<<_do_boss out")
	end
	-- No wrapping layer for now
	addon.on_boss_broadcast = _do_boss

	function addon:DBMBossCallback (reason, mod, ...)
		if (not g_rebroadcast) and (not g_enabled) then return end

		local name
		if mod.combatInfo and mod.combatInfo.name then
			name = mod.combatInfo.name
		elseif mod.id then
			name = mod.id
		else
			name = "Unknown Boss"
		end

		local it = location or instance_tag()
		location = nil

		local duration = 0
		if mod.combatInfo and mod.combatInfo.pull then
			duration = math.floor (GetTime() - mod.combatInfo.pull)
		end

		-- attendance:  maybe put people in groups 6,7,8 into a "backup/standby"
		-- list?  probably too specific to guild practices.
		local raiders = {}
		for i = 1, GetNumRaidMembers() do
			table.insert(raiders, (GetRaidRosterInfo(i)))
		end
		table.sort(raiders)

		return _do_boss (self, reason, name, it, duration, raiders)
	end

	function _mark_boss_kill (self, index)
		local e = g_loot[index]
		if not e.bosskill then
			return self:Print("Something horribly wrong;", index, "is not a boss entry!")
		end
		if e.reason ~= 'wipe' then
			-- enh, bail
			g_loot_clean = index-1
		end
		local attempts = 1
		local first

		local i,d = 1,g_loot[1]
		while d ~= e do
			if d.bosskill and
			   d.bosskill == e.bosskill and
			   d.reason == 'wipe'
			then
				first = first or i
				attempts = attempts + 1
				assert(table.remove(g_loot,i)==d,"_mark_boss_kill screwed up data badly")
			else
				i = i + 1
			end
			d = g_loot[i]
		end
		e.reason = 'kill'
		e.attempts = attempts
		g_loot_clean = first or index-1
	end
end  -- DBM tie-ins

-- Adding entries to the loot record, and tracking the corresponding timestamp.
do
	-- This shouldn't be required.  /sadface
	local loot_entry_mt = {
		__index = function (e,key)
			if key == 'cols' then _fill_out_data(1) end
			return rawget(e,key)
		end
	}

	-- Given a loot index, searches backwards for a timestamp.  Returns that
	-- index and the time entry, or nil if it falls off the beginning.  Pass an
	-- optional second index to search no earlier than it.
	-- May also be able to make good use of this in forum-generation routine.
	function addon:find_previous_time_entry(i,stop)
		local stop = stop or 0
		while i > stop do
			if g_loot[i].kind == 'time' then
				return i, g_loot[i]
			end
			i = i - 1
		end
	end

	local done_todays_date, TODAY
	function addon:_reset_timestamps()
		done_todays_date = nil
	end
	local function do_todays_date()
		local text, M, D, Y = makedate()
		TODAY = {text=text, month=M, day=D, year=Y}
		local found,ts = #g_loot+1
		repeat
			found,ts = addon:find_previous_time_entry(found-1)
			if found and ts.startday.text == TODAY.text then
				done_todays_date = true
			end
		until done_todays_date or (not found)
		if not done_todays_date then
			--g_loot[#g_loot+1] = {kind = 'time', startday = TODAY}
			--done_todays_date = true
			done_todays_date = true
			_addLootEntry { kind = 'time', startday = TODAY }
		end
		_fill_out_data(1)
	end

	-- Adding anything original to g_loot goes through this routine.
	function _addLootEntry (e)
		setmetatable(e,loot_entry_mt)

		if not done_todays_date then do_todays_date() end

		local h, m = GetGameTime()
		local localuptime = math.floor(GetTime())
		e.hour = h
		e.minute = m
		e.stamp = localuptime
		local index = #g_loot + 1
		g_loot[index] = e
		return index
	end
end

------ Saved texts
function addon:check_saved_table(silent_p)
	local s = g_loot.saved
	if s and (#s > 0) then return s end
	g_loot.saved = nil
	if not silent_p then self:Print("There are no saved loot texts.") end
end

function addon:save_list()
	local s = self:check_saved_table(); if not s then return end;
	for i,t in ipairs(s) do
		self:Print("#%d   %s    %d entries     %s", i, t.date, t.count, t.name)
	end
end

function addon:save_saveas(name)
	g_loot.saved = g_loot.saved or {}
	local n = #(g_loot.saved) + 1
	local save = {
		name = name,
		date = makedate(),
		count = #g_loot,
		forum = g_loot.forum,
		attend = g_loot.attend,
	}
	self:Print("Saving current loot texts to #%d '%s'", n, name)
	g_loot.saved[n] = save
	return self:save_list()
end

function addon:save_restore(num)
	local s = self:check_saved_table(); if not s then return end;
	if (not num) or (num > #s) then
		return self:Print("Saved text number must be 1 - "..#s)
	end
	local save = s[num]
	self:Print("Overwriting current loot data with saved text #%d '%s'", num, save.name)
	self:Clear(--[[verbose_p=]]false)
	-- Clear will already have displayed the window, and re-selected the first
	-- tab.  Set these up for when the text tabs are clicked.
	g_loot.forum = save.forum
	g_loot.attend = save.attend
end

function addon:save_delete(num)
	local s = self:check_saved_table(); if not s then return end;
	if (not num) or (num > #s) then
		return self:Print("Saved text number must be 1 - "..#s)
	end
	self:Print("Deleting saved text #"..num)
	table.remove(s,num)
	return self:save_list()
end


------ Display window routines
-- Text generation
do
	local next_insertion_position = 2   -- taborder
	local text_gen_funcs, specials_gen_funcs = {}, {}
	local accumulator = {}

	-- Can do clever things by passing other halting points as zero
	function addon:zero_printed_fenceposts(zero)
		for t in pairs(text_gen_funcs) do
			g_loot.printed[t] = zero or g_loot.printed[t] or 0
		end
	end

	-- This function is called during load, so be careful!
	function addon:register_text_generator (text_type, title, description, generator, opt_specgen)
		if type(generator) ~= "function" then
			error(("Generator for text type '%s' must be a function!"):format(text_type))
		end
		tabtexts[text_type] = { title=title, desc=description }
		table.insert (taborder, next_insertion_position, text_type)
		next_insertion_position = next_insertion_position + 1
		text_gen_funcs[text_type] = generator
		specials_gen_funcs[text_type] = opt_specgen
	end

	-- Called by tabs_generated_text_OGS
	function _generate_text (text_type)
		local f = text_gen_funcs[text_type]
		if not f then
			error(("Generator called for unregistered text type '%s'."):format(text_type))
		end
		g_generated = g_generated or {}
		g_loot[text_type] = g_loot[text_type] or ""

		if g_loot.printed[text_type] >= #g_loot then return false end
		assert(g_loot_clean == #g_loot, tostring(g_loot_clean) .. " ~= " .. #g_loot)
		-- if glc is nil, #==0 test already returned

		local ok,ret = pcall (f, text_type, g_loot, g_loot.printed[text_type], g_generated, accumulator)
		if not ok then
			error(("ERROR:  text generator '%s' failed:  %s"):format(text_type, ret))
			return false
		end
		if ret then
			g_loot.printed[text_type] = #g_loot
			g_generated[text_type] = (g_generated[text_type] or "") .. table.concat(accumulator,'\n') .. '\n'
		end
		wipe(accumulator)
		return ret
	end
	function _populate_text_specials (editbox, specials, mkb, text_type)
		local f = specials_gen_funcs[text_type]
		if not f then return end
		pcall (f, text_type, editbox, specials, mkb)
	end
end

--[[
The g_loot table is populated only with "behavior-relevant" data (names,
links, etc).  This function runs through it and fills out the "display-
relevant" bits (icons, user-friendly labels, etc).  Everything from the
g_loot_clean index to the end of the table is filled out, g_loot_clean is
updated.  Override the starting point with the argument.

XXX blizzard's scrolling update and lib-st keep finding some way of displaying
the grid without ever calling the hooked refresh, thereby skipping this
function and erroring on missing columnar data.  fuckit.  from now on
this function gets called everywhere, all the time, and loops over the
entire goddamn table each time.  If we can't find blizz's scrollframe bugs,
we'll just work around them.  Sorry for your smoking CPU.

FIXME just move this functionality to a per-entry function and call it once
in _addlootentry.  --actually no, then the columnar data won't be updated once
the backend data is changed on the fly.
]]
do
	local grammar = { -- not worth making a mt for this
		[2] = "nd",
		[3] = "rd",
	}
	function _fill_out_data (opt_starting_index)
		if #g_loot < 1 then
			pprint('_f_o_d', "#g_loot<1")
			g_loot_clean = nil
			opt_starting_index = nil --return
		end
		for i = (opt_starting_index or g_loot_clean or 1), #g_loot do
			local e = g_loot[i]
			if e == nil then
				g_loot_clean = nil
				pprint('_f_o_d', "index",i,"somehow still in loop past",#g_loot,"bailing")
				return
			end

			-- XXX FIXME a major weakness here is that we're constantly replacing
			-- what's already been created.  Lots of garbage.  Trying to detect what
			-- actually needs to be replaced is even worse.  We'll live with
			-- garbage for now.
			if e.kind == 'loot' then
				local textured = eoi_st_textured_item_format:format (e.itexture, quality_hexes[e.quality], e.itemname, e.count or "")
				e.cols = {
					{value = textured},
					{value = e.person},
					{
						--value = eoi_st_lootrow_col3_colortable[e.disposition or ""].text,
						color = eoi_st_lootrow_col3_colortable_func,
					},
				}
				-- This is horrible. Must do better.
				if e.extratext then for k,v in pairs(eoi_st_lootrow_col3_colortable) do
					if v.text == e.extratext then
						e.disposition = k
						--e.extratext = nil, not feasible
						break
					end
				end end
				local ex = eoi_st_lootrow_col3_colortable[e.disposition or ""].text
				if e.bcast_from and e.extratext then
					ex = e.extratext .. " (from " .. e.bcast_from .. ")"
				elseif e.bcast_from then
					ex = "(from " .. e.bcast_from .. ")"
				elseif e.extratext then
					ex = e.extratext
				end
				e.cols[3].value = ex

			elseif e.kind == 'boss' then
				local v
				if e.reason == 'kill' then
					if e.attempts == 1 then
						v = "one-shot"
					else
						v = ("kill on %d%s attempt"):format(e.attempts, grammar[e.attempts] or "th")
					end
					v = ("%s (%d:%.2d)"):format(v, math.floor(e.duration/60), math.floor(e.duration%60))
				elseif e.reason == 'wipe' then
					v = ("wipe (%d:%.2d)"):format(math.floor(e.duration/60), math.floor(e.duration%60))
				end
				e.cols = {
					{value = e.bosskill},
					{value = e.instance},
					{value = v or ""},
				}

			elseif e.kind == 'time' then
				e.cols = {
					{value=e.startday.text},
					{value=""},
					{value=""},
				}

			end
		end
		g_loot_clean = #g_loot
	end
end

-- main GUI window
-- Lots of shared data here, kept in a large local scope.  For readability,
-- indentation of the scope as a whole is kicked left a notch.
do
local _d
local function setstatus(txt) _d:SetStatusText(txt) end

--[[
Controls for the tabs on the left side of the main display.
]]
tabtexts = {
	["eoi"] = {title=[[Loot]], desc=[[Observed loot, plus boss kills and other events of interest]]},
	["help"] = {title=[[Help]], desc=[[Instructions, reminders, and tips for non-obvious features]]},
	["opt"] = {title=[[Options]], desc=[[Options for fine-tuning behavior]]},
	["adv"] = {title=[[Advanced]], desc=[[Debugging and testing]]},
}
taborder = { "eoi", "help", "opt", "adv" }

--[[
This is a table of callback functions, each responsible for drawing a tab
into the container passed in the first argument.  Special-purpose buttons
can optionally be created (mkbutton) and added to the container in the second
argument.
]]
local tabs_OnGroupSelected = {}
local mkbutton
local tabs_OnGroupSelected_func

-- Tab 1:  Events Of Interest
-- This actually takes up quite a bit of the file.
local eoi_editcell

local function dropdownmenu_handler (ddbutton, subfunc, arg)
	local i = _d:GetUserData("DD loot index")
	subfunc(i,arg)
	_d:GetUserData("ST"):OuroLoot_Refresh(i)
end

local function gen_easymenu_table (initial, list, funcs)
	for _,tag in ipairs(list) do
		local name, arg, tiptext
		name, tiptext = strsplit('|',tag)
		name, arg = strsplit('%',name)
		if name == "--" then
			table.insert (initial, {
				disabled = true, text = "",
			})
		else
			if not funcs[name] then
				error(("'%s' not defined as a dropdown function"):format(name))
			end
			table.insert (initial, {
				text = name,
				func = dropdownmenu_handler,
				arg1 = funcs[name],
				arg2 = arg,
				notCheckable = true,
				tooltipTitle = tiptext and name or nil,
				tooltipText = tiptext,
			})
		end
	end
	return initial
end

local dropdownmenuframe = CreateFrame("Frame", "OuroLootDropDownMenu", nil, "UIDropDownMenuTemplate")
local dropdownfuncs
dropdownfuncs = {
	[CLOSE] = function() CloseDropDownMenus() end,

	df_INSERT = function(rowi,text)
		local which = (text == 'loot') and "OUROL_EOI_INSERT_LOOT" or "OUROL_EOI_INSERT"
		local dialog = StaticPopup_Show(which,text)
		dialog.wideEditBox:SetScript("OnTextChanged",StaticPopup_EditBoxOnTextChanged)
		dialog.data = {rowindex=rowi, display=_d, kind=text}
	end,

	df_DELETE = function(rowi)
		local gone = table.remove(g_loot,rowi)
		addon:Print("Removed %s.",
			gone.itemlink or gone.bosskill or gone.startday.text)
	end,

	-- if kind is boss, also need to stop at new timestamp
	["Delete remaining entries for this day"] = function(rowi,kind)
		local fencepost
		local closest_time = _find_next_after('time',rowi)
		if kind == 'time' then
			fencepost = closest_time
		elseif kind == 'boss' then
			local closest_boss = _find_next_after('boss',rowi)
			if not closest_boss then
				fencepost = closest_time
			elseif not closest_time then
				fencepost = closest_boss
			else
				fencepost = math.min(closest_time,closest_boss)
			end
		end
		local count = fencepost and (fencepost-rowi) or (#g_loot-rowi+1)
		repeat
			dropdownfuncs.df_DELETE(rowi)
			count = count - 1
		until count < 1
	end,

	["Rebroadcast this loot entry"] = function(rowi)
		local e = g_loot[rowi]
		-- This only works because GetItemInfo accepts multiple argument formats
		addon:broadcast('loot', e.person, e.itemlink, e.count, e.cols[3].value)
		addon:Print("Rebroadcast entry",rowi,e.itemlink)
	end,

	["Rebroadcast this boss"] = function(rowi,kind)
		addon:Print("not implemented yet") -- TODO
	end,

	["Mark as normal"] = function(rowi,disp) -- broadcast the change?  ugh
		g_loot[rowi].disposition = disp
		g_loot[rowi].bcast_from = nil
		g_loot[rowi].extratext = nil
	end,

	["Show only this player"] = function(rowi)
		local st = _d:GetUserData("ST")
		_d:SetUserData("player filter name", g_loot[rowi].person)
		st:SetFilter(_d:GetUserData("player filter by name"))
		_d:GetUserData("eoi_filter_reset"):SetDisabled(false)
	end,

	["Change from 'wipe' to 'kill'"] = function(rowi)
		_mark_boss_kill(addon,rowi)
		-- the fillout function called automatically will start too far down the list
		_d:GetUserData("ST"):OuroLoot_Refresh()
	end,

	["Edit note"] = function(rowi)
		eoi_editcell (rowi, _d:GetUserData("DD loot cell"))
	end,

	df_REASSIGN = function(rowi,to_whom)
		g_loot[rowi].person = to_whom
		g_loot[rowi].person_class = select(2,UnitClass(to_whom))
		CloseDropDownMenus()  -- also need to close parent menu
	end,
	["Enter name..."] = function(rowi)
		local dialog = StaticPopup_Show "OUROL_REASSIGN_ENTER"
		dialog.data = {index=rowi, display=_d}
	end,
}
-- Would be better to move the %arg to this list rather than below, but
-- that's a lot of extra effort that doesn't buy much in return.
dropdownfuncs["Delete this loot event"] = dropdownfuncs.df_DELETE
dropdownfuncs["Delete this boss event"] = dropdownfuncs.df_DELETE
dropdownfuncs["Insert new loot entry"] = dropdownfuncs.df_INSERT
dropdownfuncs["Insert new boss kill event"] = dropdownfuncs.df_INSERT
dropdownfuncs["Mark as disenchanted"] = dropdownfuncs["Mark as normal"]
dropdownfuncs["Mark as guild vault"] = dropdownfuncs["Mark as normal"]
dropdownfuncs["Mark as offspec"] = dropdownfuncs["Mark as normal"]
dropdownfuncs["Delete remaining entries for this boss"] = dropdownfuncs["Delete remaining entries for this day"]
dropdownfuncs["Rebroadcast this day"] = dropdownfuncs["Rebroadcast this boss"]
local eoi_time_dropdown = gen_easymenu_table(
	{{
		-- this is the dropdown title, text filled in on the fly
		isTitle = true,
		notClickable = true,
		notCheckable = true,
	}},
	{
		"Rebroadcast this day%time|Broadcasts everything from here down until a new day",
		"Delete remaining entries for this day%time|Erases everything down until a new day",
		"Insert new loot entry%loot|Inserts new loot above this one, prompting you for information",
		"Insert new boss kill event%boss|Inserts new event above this one, prompting you for information",
		CLOSE
	}, dropdownfuncs)
local eoi_loot_dropdown = gen_easymenu_table(
	{{
		-- this is the dropdown title, text filled in on the fly
		notClickable = true,
		notCheckable = true,
	}},
	{
		"Mark as disenchanted%shard",
		"Mark as offspec%offspec",
		"Mark as guild vault%gvault",
		"Mark as normal|This is the default. Selecting any 'Mark as <x>' action blanks out extra notes about who broadcast this entry, etc.",
		"--",
		"Rebroadcast this loot entry|Sends this loot event, including special notes, as if it just happened.",
		"Delete this loot event|Permanent, no going back!",
		"Delete remaining entries for this boss%boss|Erases everything down until a new boss/day",
		"Insert new loot entry%loot|Inserts new loot above this one, prompting you for information",
		"Insert new boss kill event%boss|Inserts new event above this one, prompting you for information",
		"Edit note|Same as double-clicking in the notes column",
		"--",
		CLOSE
	}, dropdownfuncs)
local eoi_player_dropdown = gen_easymenu_table(
	{
		{
			-- this is the dropdown title, text filled in on the fly
			isTitle = true,
			notClickable = true,
			notCheckable = true,
		},
		{
			text = "Reassign to...",
			hasArrow = true,
			--menuList = filled in in the fly,
		},
	},
	{
		"Show only this player",
		CLOSE
	}, dropdownfuncs)
local eoi_boss_dropdown = gen_easymenu_table(
	{{
		-- this is the dropdown title, text filled in on the fly
		isTitle = true,
		notClickable = true,
		notCheckable = true,
	}},
	{
		"Change from 'wipe' to 'kill'|Also collapses other wipe entries",
		"Rebroadcast this boss|Broadcasts the kill event and all subsequent loot until next boss",
		"Delete this boss event|Permanent, no going back!",
		"Delete remaining entries for this boss%boss|Erases everything down until a new boss/day",
		"Insert new loot entry%loot|Inserts new loot above this one, prompting you for information",
		"Insert new boss kill event%boss|Inserts new event above this one, prompting you for information",
		"--",
		CLOSE
	}, dropdownfuncs)

--[[ quoted verbatim from lib-st docs:
rowFrame This is the UI Frame table for the row.
cellFrame This is the UI Frame table for the cell in the row.
data This is the data table supplied to the scrolling table (in case you lost it :) )
cols This is the cols table supplied to the scrolling table (again, in case you lost it :) )
row This is the number of the UI row that the event was triggered for.<br/> ex. If your scrolling table only shows ten rows, this number will be a number between 1 and 10.
realrow This is the exact row index (after sorting and filtering) in the data table of what data is displayed in the row you triggered the event in. (NOT the UI row!)
column This is the index of which column the event was triggered in.
table This is a reference to the scrollingtable table.
...  Any arguments generated by the '''NORMAL''' Blizzard event triggered by the frame are passed as is.
]]
local function eoi_st_OnEnter (rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
	if (row == nil) or (realrow == nil) then return end  -- mouseover column header
	local e = data[realrow]
	local kind = e.kind

	if kind == 'loot' and column == 1 then
		GameTooltip:SetOwner (cellFrame, "ANCHOR_RIGHT", -20, 0)
		GameTooltip:SetHyperlink (e.itemlink)

	elseif kind == 'loot' and column == 2 then
		GameTooltip:SetOwner (cellFrame, "ANCHOR_BOTTOMRIGHT", -50, 5)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(e.person.." Loot:")
		local counter = 0
		for i,e2 in ipairs(data) do
			if e2.person == e.person then  -- would be awesome to test for alts
				if counter > 10 then
					GameTooltip:AddLine("...")
					break
				else
					-- textures screw up too badly, strip them
					local textured = e2.cols[1].value
					local space = textured:find(" ")
					GameTooltip:AddLine(textured:sub(space+1))
					counter = counter + 1
				end
			end
		end
		GameTooltip:Show()

	elseif kind == 'loot' and column == 3 then
		setstatus(e.cols[column].value)

	end

	return false  -- continue with default highlighting behavior
end
local function eoi_st_OnLeave (rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
	GameTooltip:Hide()
	if row and realrow and data[realrow].kind ~= 'loot' then
		table:SetHighLightColor (rowFrame, eoi_st_otherrow_bgcolortable[data[realrow].reason or data[realrow].kind])
		return true   -- do not do anything further
	else
		--setstatus("")
		return false  -- continue with default un-highlighting behavior
	end
end

local function eoi_st_OnClick (rowFrame, cellFrame, data, cols, row, realrow, column, stable, button, ...)
	if (row == nil) or (realrow == nil) then return true end  -- click column header, suppress reordering
	local e = data[realrow]
	local kind = e.kind

	-- Check for shift-clicking a loot line
	if IsModifiedClick("CHATLINK") and kind == 'loot' and column == 1 then
		ChatEdit_InsertLink (e.itemlink)
		return true  -- do not do anything further
	end

	-- Remaining actions are all right-click
	if button ~= "RightButton" then return true end
	_d:SetUserData("DD loot index", realrow)

	if kind == 'loot' and (column == 1 or column == 3) then
		_d:SetUserData("DD loot cell", cellFrame)
		eoi_loot_dropdown[1].text = e.itemlink
		EasyMenu (eoi_loot_dropdown, dropdownmenuframe, cellFrame, 0, 0, "MENU")

	elseif kind == 'loot' and column == 2 then
		eoi_player_dropdown[1].text = e.person
		local raiders = {}
		for i = 1, GetNumRaidMembers() do
			table.insert (raiders, (GetRaidRosterInfo(i)))
		end
		table.sort(raiders)
		for i = 1, #raiders do
			local name = raiders[i]
			raiders[i] = {
				text = name,
				func = dropdownmenu_handler,
				arg1 = dropdownfuncs.df_REASSIGN,
				arg2 = name,
				notCheckable = true,
			}
		end
		eoi_player_dropdown[2].menuList =
			gen_easymenu_table (raiders, {"Enter name...",CLOSE}, dropdownfuncs)
		--tabledump(eoi_player_dropdown)
		EasyMenu (eoi_player_dropdown, dropdownmenuframe, cellFrame, 0, 0, "MENU")

	elseif kind == 'boss' then
		eoi_boss_dropdown[1].text = e.bosskill
		EasyMenu (eoi_boss_dropdown, dropdownmenuframe, cellFrame, 0, 0, "MENU")

	elseif kind == 'time' then
		eoi_time_dropdown[1].text = e.startday.text
		EasyMenu (eoi_time_dropdown, dropdownmenuframe, cellFrame, 0, 0, "MENU")

	end

	return true  -- do not do anything further
end

function eoi_editcell (row_index, cell_frame)
	local e = g_loot[row_index]
	if not e then return end   -- how the hell could we get this far?
	local celldata = e.cols[3]
	local box = GUI:Create("EditBox")
	box:SetText(celldata.value)
	box.editbox:SetScript("OnShow", box.editbox.SetFocus)
	box:SetUserData("old escape", box.editbox:GetScript("OnEscapePressed"))
	box.editbox:SetScript("OnEscapePressed", function(this)
		this:ClearFocus()
		this.obj:Release()
	end)
	box:SetCallback("OnEnterPressed", function(_b,event,value)
		e.extratext = value
		celldata.value = value
		e.bcast_from = nil  -- things get screwy if this field is still present. sigh.
		e.extratext_byhand = true
		value = value and value:match("^(x%d+)")
		if value then e.count = value end
		_b:Release()
		return _d:GetUserData("ST"):Refresh()
	end)
	box:SetCallback("OnRelease", function(_b)
		_b.editbox:ClearFocus()
		_b.editbox:SetScript("OnShow", nil)
		_b.editbox:SetScript("OnEscapePressed", _b:GetUserData("old escape"))
		setstatus("")
	end)
	box.frame:SetAllPoints(cell_frame)
	box.frame:SetParent(cell_frame)
	box.frame:SetFrameLevel(cell_frame:GetFrameLevel()+1)
	box.frame:Show()
	setstatus("Press Enter or click Okay to accept changes, or press Escape to cancel them.")
end

local function eoi_st_OnDoubleClick (rowFrame, cellFrame, data, cols, row, realrow, column, stable, button, ...)
	if (row == nil) or (realrow == nil) then return true end  -- they clicked on column header, suppress reordering
	local e = data[realrow]
	local kind = e.kind

	--_d:SetUserData("DD loot index", realrow)
	if kind == 'loot' and column == 3 and button == "LeftButton" then
		eoi_editcell (realrow, cellFrame)
	end

	return true  -- do not do anything further
end

local function eoi_st_col2_DoCellUpdate (rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...) 
	if not fShow then
		cellFrame.text:SetText("")
		if cellFrame.icontexture then
			cellFrame.icontexture:Hide()
		end
		return
	end

	local e = data[realrow]
	local cell = e.cols[column]

	cellFrame.text:SetText(cell.value)
	cellFrame.text:SetTextColor(1,1,1,1)

	if e.person_class then
		local icon
		if cellFrame.icontexture then
			icon = cellFrame.icontexture
		else
			icon = cellFrame:CreateTexture(nil,"BACKGROUND")
			icon:SetPoint("LEFT", cellFrame, "LEFT")
			icon:SetHeight(eoi_st_rowheight-4)
			icon:SetWidth(eoi_st_rowheight-4)
			icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
			cellFrame.icontexture = icon
		end
		icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[e.person_class]))
		icon:Show()
		cellFrame.text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
	else
		if cellFrame.icontexture then
			cellFrame.icontexture:Hide()
			cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT")
		end
	end

	if e.kind ~= 'loot' then
		table:SetHighLightColor (rowFrame, eoi_st_otherrow_bgcolortable[e.reason or e.kind])
	else
		table:SetHighLightColor (rowFrame, table:GetDefaultHighlightBlank())
	end
end

local eoi_st_cols = {
	{  -- col 1
		name	= "Item",
		width	= 250,
	},
	{  -- col 2
		name	= "Player",
		width	= 130,
		DoCellUpdate = eoi_st_col2_DoCellUpdate,
	},
	{  -- col 3
		name	= "Notes",
		width	= 160,
	},
}

local rowfilter_all
local rowfilter_by_name = function (st, e)
	if e.kind ~= 'loot' then return true end
	return e.person == _d:GetUserData("player filter name")
end

tabs_OnGroupSelected["eoi"] = function(ocontainer,specials)
	if (not g_rebroadcast) and (not g_enabled) and (#g_loot < 1) then
		return dprint('flow', "Nothing to show in first tab, skipping creation")
	end

	-- The first time this function is called, we set up a persistent ST
	-- object and store it.  Any other delayed setup work is done, and then
	-- this function replaces itself with a smaller, sleeker, sexier one.
	-- This function will later be garbage collected.
	local ST = LibStub("ScrollingTable"):CreateST(eoi_st_cols,eoi_st_displayed_rows,eoi_st_rowheight)
	_d:SetUserData("ST",ST)

	-- Calling SetData breaks (trying to call Refresh) if g_loot hasn't gone
	-- through this loop.
	_fill_out_data(1)
	-- safety check  begin
	for i,e in ipairs(g_loot) do
		if type(e.cols) ~= "table" then
			addon:Print("ARGH, index",i,"bad in eoi_OGS, type",type(e.cols),
				"entry kind", e.kind, "data", e.itemname or e.bosskill or e.startday.text,
				"-- please take a screenshot and send to Farmbuyer.")
		end
	end
	-- safety check  end
	ST:SetData(g_loot)
	ST:RegisterEvents{
		OnEnter = eoi_st_OnEnter,
		OnLeave = eoi_st_OnLeave,
		OnClick = eoi_st_OnClick,
		OnDoubleClick = eoi_st_OnDoubleClick,
	}

	-- We want a single "update and redraw" function for the ST.  Also, the
	-- given refresh function is badly named and does nothing; the actual
	-- function is SortData (also badly named when no sorting is being done),
	-- which unconditionally calls the *hooked* Refresh.
	local oldrefresh = ST.Refresh
	ST.Refresh = function (self, opt_index)
		_fill_out_data(opt_index)
		return oldrefresh(self)
	end
	ST.OuroLoot_Refresh = function (self, opt_index)
		_fill_out_data(opt_index)
		-- safety check  begin
		for i,e in ipairs(g_loot) do
			if type(e.cols) ~= "table" then
				addon:Print("ARGH, index",i,"bad in refresh, refreshed at", opt_index, "type",type(e.cols),
					"entry kind", e.kind, "data", e.itemname or e.bosskill or e.startday.text,
					"-- please take a screenshot and send to Farmbuyer.")
			end
		end
		-- safety check  end
		self:SortData()  -- calls hooked refresh
	end

	-- No need to keep creating function closures that all just "return true",
	-- instead we grab the one made inside lib-st.  There's no "get filter" API
	-- so we just reach inside.
	rowfilter_all = ST.Filter

	-- Now set up the future drawing function...
	tabs_OnGroupSelected["eoi"] = function(container,specials)
		local st_widget = GUI:Create("lib-st")
		local st = _d:GetUserData("ST")

		_d:SetUserData ("player filter clear", rowfilter_all)
		_d:SetUserData ("player filter by name", rowfilter_by_name)

		st:OuroLoot_Refresh()
		st_widget:WrapST(st)

		if sv_OLoot_opts.scroll_to_bottom then
			local scrollbar = _G[st.scrollframe:GetName().."ScrollBar"]
			if scrollbar then
				local _,max = scrollbar:GetMinMaxValues()
				scrollbar:SetValue(max)   -- also calls hooked Refresh
			end
		end

		container:SetLayout("Fill")
		container:AddChild(st_widget)

		local b = mkbutton('eoi_filter_reset', "Reset Player Filter",
			[[Return to showing complete loot information.]])
		b:SetFullWidth(true)
		b:SetCallback("OnClick", function (_b)
			local st = _d:GetUserData("ST")
			st:SetFilter(rowfilter_all)
			_b:SetDisabled(true)
		end)
		b:SetDisabled(st.Filter == rowfilter_all)
		specials:AddChild(b)

		local people = { "<nobody>" }
		for i=1,GetNumRaidMembers() do
			table.insert(people,(GetRaidRosterInfo(i)))
		end
		table.sort(people)
		local initial
		for i,n in ipairs(people) do
			if n == g_sharder then initial = i end
		end
		b = mkbutton("Dropdown", nil, "",
			[[If set, items received by this person will be automatically marked as disenchanted.]])
		b:SetFullWidth(true)
		b:SetLabel("Auto-mark as shard:")
		b:SetList(people)
		b:SetValue(initial or 1)
		b:SetCallback("OnValueChanged", function(_dd,event,choice)
			g_sharder = (choice ~= 1) and people[choice] or nil
		end)
		specials:AddChild(b)

		local b = mkbutton('eoi_bcast_req', "Request B'casters",
			[[Sends out a request for others to enable loot rebroadcasting if they have not already done so.]])
		b:SetFullWidth(true)
		b:SetCallback("OnClick", function ()
			addon:Print("Sending request!")
			g_requesting = true
			addon:broadcast('bcast_req')
		end)
		b:SetDisabled(not g_enabled)
		specials:AddChild(b)
	end
	-- ...and call it.
	return tabs_OnGroupSelected["eoi"](ocontainer,specials)
end

-- Tab 2/3 (generated text)
local function tabs_generated_text_OGS (container, specials, text_kind)
	container:SetLayout("Fill")
	local box = GUI:Create("MultiLineEditBoxPreviousAPI")
	box:SetFullWidth(true)
	box:SetFullHeight(true)
	box:SetLabel("Pressing the Escape key while typing will return keystroke control to the usual chat window.")
	box:ShowButton(false)  -- this got ripped out in old multilineeditbox ><
	_fill_out_data(1)

	-- Update the savedvar copy of the text before presenting it for editing,
	-- then save it again when editing finishes.  This way if the user goes
	-- offline while editing, at least the unedited version is saved instead
	-- of all the new text being lost entirely.  (Yes, it's happened.)
	--
	-- No good local-ish place to store the cursor position that will also
	-- survive the entire display being released.  Abuse the generated text
	-- cache for this purpose.
	local pos = text_kind.."_pos"
	if _generate_text(text_kind) then
		g_loot[text_kind] = g_loot[text_kind] .. g_generated[text_kind]
		g_generated[text_kind] = nil
	end
	box:SetText(g_loot[text_kind])
	box.editBox:SetCursorPosition(g_generated[pos] or 0)
	box.editBox:SetScript("OnShow", box.editBox.SetFocus)
	box:SetCallback("OnRelease", function(_box)
		box.editBox:ClearFocus()
		g_loot[text_kind] = _box:GetText()
		g_generated[pos] = _box.editBox:GetCursorPosition()
	end)
	container:AddChild(box)

	local w = mkbutton("Regenerate",
		[[+DISCARD> all text in this tab, and regenerate it from the current loot information.]])
	w:SetFullWidth(true)
	w:SetDisabled ((#g_loot == 0) and (box:GetText() == ""))
	w:SetCallback("OnClick", function(_w)
		box:SetText("")
		g_loot[text_kind] = ""
		g_loot.printed[text_kind] = 0
		g_generated.last_instance = nil
		g_generated[pos] = nil
		addon:Print("'%s' has been regenerated.", tabtexts[text_kind].title)
		return tabs_OnGroupSelected_func(container,"OnGroupSelected",text_kind)
	end)
	specials:AddChild(w)
	_populate_text_specials (box, specials, mkbutton, text_kind)
end

-- Tab 4:  Help (content in lootaux.lua)
do
	local tabs_help_OnGroupSelected_func = function (treeg,event,category)
		treeg:ReleaseChildren()
		local txt = GUI:Create("Label")
		txt:SetFullWidth(true)
		txt:SetFontObject(GameFontNormal)--Highlight)
		txt:SetText(addon.helptext[category])
		local sf = GUI:Create("ScrollFrame")
		local sfstat = _d:GetUserData("help tab scroll status") or {}
		sf:SetStatusTable(sfstat)
		_d:SetUserData("help tab scroll status",sfstat)
		sf:SetLayout("Fill")
		-- This forces the scrolling area to be bigger than the visible area; else
		-- some of the text gets cut off.
		sf.content:SetHeight(700)
		sf:AddChild(txt)
		treeg:AddChild(sf)
		if treeg:GetUserData("help restore scroll") then
			sfstat = sfstat.scrollvalue
			if sfstat then sf:SetScroll(sfstat) end
			treeg:SetUserData("help restore scroll", false)
		else
			sf:SetScroll(0)
		end
	end
	tabs_OnGroupSelected["help"] = function(container,specials)
		container:SetLayout("Fill")
		local left = GUI:Create("TreeGroup")
		local leftstat = _d:GetUserData("help tab select status")
						 or {treewidth=145}
		left:SetStatusTable(leftstat)
		_d:SetUserData("help tab select status",leftstat)
		left:SetLayout("Fill")
		left:SetFullWidth(true)
		left:SetFullHeight(true)
		left:EnableButtonTooltips(false)
		left:SetTree(addon.helptree)
		left:SetCallback("OnGroupSelected", tabs_help_OnGroupSelected_func)
		container:AddChild(left)
		leftstat = leftstat.selected
		if leftstat then
			left:SetUserData("help restore scroll", true)
			left:SelectByValue(leftstat)
		else
			left:SelectByValue("basic")
		end
	end
end
--[===[
tabs_OnGroupSelected["help"] = function(container,specials)
	local TRIGGER_BUG = true
	local txt,sf
	local example_txt = ("The quick brown fox jumped over the lazy dog.  "):rep(20)

	container:SetLayout("Fill")

	txt = GUI:Create("Label")
	txt:SetFullWidth(true)
	txt:SetText(addon.helptext)
	--txt:SetText(example_txt)

	if TRIGGER_BUG then
		sf = GUI:Create("ScrollFrame")
		--sf:SetFullWidth(true) -- XXX causes cpu lockup!
		--sf:SetFullHeight(true) -- XXX causes cpu lockup!
		sf:SetLayout("Fill")  -- has no effect
		sf:SetWidth(container.content:GetWidth() - 5)  -- has no effect
		--sf:SetHeight(container.content:GetHeight() - 5)  -- has no effect
		--sf:SetHeight(_d:GetUserData("area height"))
		sf:AddChild(txt)
	end

	container:AddChild(TRIGGER_BUG and sf or txt)
end ]===]

-- Tab 5:  Options
do
	local function mkoption (opt, label, width, desc, opt_func)
		local w = mkbutton("CheckBox", nil, "", desc)
		w:SetRelativeWidth(width)
		w:SetType("checkbox")
		w:SetLabel(label)
		if opt then
			w:SetValue(sv_OLoot_opts[opt])
			w:SetCallback("OnValueChanged", opt_func or (function(_w,event,value)
				sv_OLoot_opts[opt] = value
			end))
		end
		return w
	end

	tabs_OnGroupSelected["opt"] = function(container,specials)
		container:SetLayout("List")
		local grp, w

		grp = GUI:Create("InlineGroup")
		grp:SetFullWidth(true)
		grp:SetLayout("Flow")
		grp:SetTitle("User Options     [these are saved across sessions]")

		-- reminder popup
		w = mkoption ('popup_on_join', "Show reminder popup", 0.35,
			[[When joining a raid and not already tracking, display a dialog asking for instructions.]])
		grp:AddChild(w)

		-- toggle scroll-to-bottom on first tab
		w = mkoption('scroll_to_bottom', "Scroll to bottom when opening display", 0.60,
			[[Scroll to the bottom of the loot window (most recent entries) when displaying the GUI.]])
		grp:AddChild(w)

		-- /loot option
		w = mkoption('register_slashloot', "Register /loot slash command on login", 0.55,
			[[Register "/loot" as a slash command in addition to the normal "/ouroloot".  Relog to take effect.]])
		grp:AddChild(w)

		-- chatty mode
		w = mkoption('chatty_on_kill', "Be chatty on boss kill", 0.40,
			[[Print something to chat output when DBM tells Ouro Loot about a successful boss kill.]])
		grp:AddChild(w)

		-- cutesy abbrevs
		w = mkoption('snarky_boss', "Use snarky boss names", 0.35,
			[[Irreverent replacement names for boss events.]])
		grp:AddChild(w)

		-- possible keybindings
		do
			local pair = GUI:Create("SimpleGroup")
			pair:SetLayout("Flow")
			pair:SetRelativeWidth(0.6)
			local editbox, checkbox
			editbox = mkbutton("EditBox", nil, sv_OLoot_opts.keybinding_text,
				[[Keybinding text format is fragile!  Relog to take effect.]])
			editbox:SetRelativeWidth(0.5)
			editbox:SetLabel("Keybinding text")
			editbox:SetCallback("OnEnterPressed", function(_w,event,value)
				sv_OLoot_opts.keybinding_text = value
			end)
			editbox:SetDisabled(not sv_OLoot_opts.keybinding)
			checkbox = mkoption('keybinding', "Register keybinding", 0.5,
				[[Register a keybinding to toggle the loot display.  Relog to take effect.]],
				function (_w,_,value)
					sv_OLoot_opts.keybinding = value
					editbox:SetDisabled(not sv_OLoot_opts.keybinding)
				end)
			pair:AddChild(checkbox)
			pair:AddChild(editbox)
			grp:AddChild(pair)
		end

		-- item filter
		w = GUI:Create("Spacer")
		w:SetFullWidth(true)
		w:SetHeight(20)
		grp:AddChild(w)
		do
			local list = {}
			for id in pairs(sv_OLoot_opts.itemfilter) do
				local iname, _, iquality = GetItemInfo(id)
				list[id] = quality_hexes[iquality] .. iname .. "|r"
			end
			w = GUI:Create("EditBoxDropDown")
			w:SetRelativeWidth(0.4)
			w:SetText("Item filter")
			w:SetEditBoxTooltip("Link items which should no longer be tracked.")
			w:SetList(list)
			w:SetCallback("OnTextEnterPressed", function(_w, _, text)
				local iname, ilink, iquality = GetItemInfo(strtrim(text))
				if not iname then
					return addon:Print("Error:  %s is not a valid item name/link!", text)
				end
				local id = tonumber(ilink:match("item:(%d+)"))
				list[id] = quality_hexes[iquality] .. iname .. "|r"
				sv_OLoot_opts.itemfilter[id] = true
				addon:Print("Now filtering out", ilink)
			end)
			w:SetCallback("OnListItemClicked", function(_w, _, key_id, val_name)
				--local ilink = select(2,GetItemInfo(key_id))
				sv_OLoot_opts.itemfilter[tonumber(key_id)] = nil
				--addon:Print("No longer filtering out", ilink)
				addon:Print("No longer filtering out", val_name)
			end)
			grp:AddChild(w)
		end

		container:AddChild(grp)

		--local senders = table.concat(g_sender_list.names,'\n')   -- sigh
		local senders = ""
		for _,s in pairs(g_sender_list.names) do
			senders = senders .. s .. '\n'
		end
		-- If 39 other people in the raid are running this, the label will
		-- explode... is it likely enough to care about?  No.
		if #senders > 0 then
			w = GUI:Create("Spacer")
			w:SetFullWidth(true)
			w:SetHeight(20)
			container:AddChild(w)
			w = GUI:Create("Label")
			w:SetRelativeWidth(0.4)
			w:SetText(quality_hexes[3].."Echo from latest ping:|r\n"..senders)
			container:AddChild(w)
		end

		w = mkbutton("ReloadUI", [[Does what you think it does.  Loot information is written out and restored.]])
		w:SetFullWidth(true)
		w:SetCallback("OnClick", ReloadUI)
		specials:AddChild(w)

		w = mkbutton("Ping!",
			[[Asks other raid users for their addon version and current status.  Results displayed on this panel.]])
		w:SetFullWidth(true)
		w:SetCallback("OnClick", function(_w)
			addon:Print("Give me a ping, Vasili. One ping only, please.")
			g_sender_list = {active={},names={}}
			_w:SetText("5... 4... 3...")
			_w:SetDisabled(true)
			addon:broadcast('ping')
			addon:ScheduleTimer(function(b)
				if b:IsVisible() then
					return tabs_OnGroupSelected_func(container,"OnGroupSelected","opt")
				end
			end, 5, _w)
		end)
		specials:AddChild(w)
	end
end

-- Tab 6:  Advanced
do
	local function adv_careful_OnTextChanged (ebox,event,value)
		-- The EditBox widget's code will call an internal ShowButton routine
		-- after this callback returns.  ShowButton will test for this flag:
		ebox:DisableButton (value == "")
		-- Skipping ShowButton does not actively hide the button however.  We
		-- copy HideButton()'s lines here verbatim (HideButton is private).
		-- There is also no way to test whether the button is disabled, so we
		-- access private data for that too.
		if ebox.disablebutton then
			ebox.button:Hide()
			ebox.editbox:SetTextInsets(0,0,3,3)
		end
	end
	-- Like the first tab, we use a pair of functions; first and repeating.
	local function adv_real (container, specials)
		local grp, w

		grp = GUI:Create("InlineGroup")
		grp:SetFullWidth(true)
		grp:SetLayout("Flow")
		grp:SetTitle("Debugging/Testing Options      [not saved across sessions]")

		w = mkbutton("EditBox", 'comm_ident', ident,
			[[Disable the addon, change this field (click Okay or press Enter), then re-enable the addon.]])
		w:SetRelativeWidth(0.2)
		w:SetLabel("Addon channel ID")
		w:SetCallback("OnTextChanged", adv_careful_OnTextChanged)
		w:SetCallback("OnEnterPressed", function(_w,event,value)
			-- if they set it to blank spaces, they're boned.  oh well.
			ident = (value == "") and "OuroLoot2" or value
			_w:SetText(ident)
			addon:Print("Addon channel ID set to '"..ident.."' for rebroadcasting and listening.")
		end)
		w:SetDisabled(g_enabled or g_rebroadcast)
		grp:AddChild(w)

		w = mkbutton("EditBox", nil, addon.recent_messages.ttl, [[comm cache (only) ttl]])
		w:SetRelativeWidth(0.05)
		w:SetLabel("ttl")
		w:SetCallback("OnTextChanged", adv_careful_OnTextChanged)
		w:SetCallback("OnEnterPressed", function(_w,event,value)
			value = tonumber(value) or addon.recent_messages.ttl
			addon.recent_messages.ttl = value
			_w:SetText(tostring(value))
		end)
		grp:AddChild(w)

		w = mkbutton("load nsaab1548", [[Cursed Darkhound]])
		w:SetRelativeWidth(0.25)
		w:SetCallback("OnClick", function()
			for i, v in ipairs(DBM.AddOns) do
				if v.modId == "DBM-NotScaryAtAll" then
					DBM:LoadMod(v)
					break
				end
			end
			local mod = DBM:GetModByName("NotScaryAtAll")
			if mod then
				mod:EnableMod()
				addon:Print("Now tracking ID",mod.creatureId)
			else addon:Print("Can do nothing; DBM testing mod wasn't loaded.") end
		end)
		grp:AddChild(w)

		w = mkbutton("GC", [[full GC cycle]])
		w:SetRelativeWidth(0.1)
		w:SetCallback("OnClick", function() collectgarbage() end)
		grp:AddChild(w)

		w = mkbutton("EditBox", nil, loot_pattern:sub(17), [[]])
		w:SetRelativeWidth(0.35)
		w:SetLabel("CML pattern suffix")
		w:SetCallback("OnEnterPressed", function(_w,event,value)
			loot_pattern = loot_pattern:sub(1,16) .. value
			print(loot_pattern:gsub("\124","\124\124"))
		end)
		grp:AddChild(w)

		local simple = GUI:Create("SimpleGroup")
		simple:SetLayout("List")
		simple:SetRelativeWidth(0.3)
		w = GUI:Create("CheckBox")
		w:SetFullWidth(true)
		w:SetType("checkbox")
		w:SetLabel("master dtoggle")
		w.text:SetFontObject(GameFontHighlightSmall) -- XXX
		w:SetValue(DEBUG_PRINT)
		w:SetCallback("OnValueChanged", function(_w,event,value) DEBUG_PRINT = value end)
		simple:AddChild(w)
		w = mkbutton("Clear All & Reload",
			[[No confirmation!  |cffff1010Erases absolutely all> Ouro Loot saved variables and reloads the UI.]])
		w:SetFullWidth(true)
		w:SetCallback("OnClick", function()
			g_loot = {}  -- not saved, just fooling PLAYER_LOGOUT tests
			sv_OLoot = nil
			sv_OLoot_opts = nil
			ReloadUI()
		end)
		simple:AddChild(w)
		grp:AddChild(simple)

		simple = GUI:Create("SimpleGroup")
		simple:SetLayout("List")
		simple:SetRelativeWidth(0.5)
		for d,v in pairs(g_debug) do
			w = GUI:Create("CheckBox")
			w:SetFullWidth(true)
			w:SetType("checkbox")
			w:SetLabel(d)
			w.text:SetFontObject(GameFontHighlightSmall)  -- XXX
			if d == "notraid" then
				w:SetDescription("Tick this before enabling to make the addon work outside of raid groups")
			end
			w:SetValue(v)
			w:SetCallback("OnValueChanged", function(_w,event,value) g_debug[d] = value end)
			simple:AddChild(w)
		end
		grp:AddChild(simple)

		container:AddChild(grp)
		GUI:ClearFocus()
	end
	local function adv_lower (container, specials)
		local speedbump = GUI:Create("InteractiveLabel")
		speedbump:SetFullWidth(true)
		speedbump:SetFontObject(GameFontHighlightLarge)
		speedbump:SetImage("Interface\\DialogFrame\\DialogAlertIcon")
		speedbump:SetImageSize(50,50)
		speedbump:SetText("The debugging/testing settings on the rest of this panel can"
			.." seriously bork up the addon if you make a mistake.  If you're okay"
			.." with the possibility of losing data, click this warning to load the panel.")
		speedbump:SetCallback("OnClick", function (_sb)
			adv_lower = adv_real
			return tabs_OnGroupSelected_func(container,"OnGroupSelected","adv")
		end)
		container:AddChild(speedbump)
	end

	tabs_OnGroupSelected["adv"] = function(container,specials)
		container:SetLayout("List")
		local grp, w

		w = mkbutton("ReloadUI", [[Does what you think it does.  Loot information is written out and restored.]])
		w:SetFullWidth(true)
		w:SetCallback("OnClick", ReloadUI)
		specials:AddChild(w)

		return adv_lower (container, specials)
	end
end


-- Simply to avoid recreating the same function over and over
tabs_OnGroupSelected_func = function (tabs,event,group)
	tabs:ReleaseChildren()
	local spec = tabs:GetUserData("special buttons group")
	spec:ReleaseChildren()
	local h = GUI:Create("Heading")
	h:SetFullWidth(true)
	h:SetText(tabtexts[group].title)
	spec:AddChild(h)
	return tabs_OnGroupSelected[group](tabs,spec,group)
	--[====[
	Unfortunately, :GetHeight() called on anything useful out of a TabGroup
	returns the static default size (about 50 pixels) until the refresh
	cycle *after* all the frames are shown.  Trying to fix it up after a
	single OnUpdate doesn't work either.  So for now it's all hardcoded.
	
	Using this to determine the actual height of the usable area.
	366 pixels
	if group == "eoi" then
		local stframe = tabs.children[1].frame
		print(stframe:GetTop(),"-",stframe:GetBottom(),"=",
		      stframe:GetTop()-stframe:GetBottom())
		print(stframe:GetRight(),"-",stframe:GetLeft(),"=",
		      stframe:GetRight()-stframe:GetLeft())
	end
	]====]
end

--[[
mkbutton ("WidgetType", 'display key', "Text On Widget", "the mouseover display text")
mkbutton ( [Button]     'display key', "Text On Widget", "the mouseover display text")
mkbutton ( [Button]      [text]        "Text On Widget", "the mouseover display text")
]]
do
	local replacement_colors = { ["+"]="|cffffffff", ["<"]="|cff00ff00", [">"]="|r" }
	function mkbutton (opt_widget_type, opt_key, label, status)
		if not label then
			opt_widget_type, opt_key, label, status = "Button", opt_widget_type, opt_widget_type, opt_key
		elseif not status then
			opt_widget_type, opt_key, label, status = "Button", opt_widget_type, opt_key, label
		end
		local button = GUI:Create(opt_widget_type)
		if button.SetText then button:SetText(tostring(label)) end
		status = status:gsub("[%+<>]",replacement_colors)
		button:SetCallback("OnEnter", function() setstatus(status) end)
		button:SetCallback("OnLeave", function() setstatus("") end)
		-- retrieval key may be specified as nil if all the parameters are given
		if opt_key then _d:SetUserData (opt_key, button) end
		return button
	end
end

--[[
Creates the main window.
]]
function addon:BuildMainDisplay (opt_tabselect)
	if g_display and g_display:IsVisible() then
		-- try to get everything to update, rebuild, refresh... ugh, no
		g_display:Hide()
	end

	local display = GUI:Create("Frame")
	if _d then
		display:SetUserData("ST",_d)   -- warning! warning! kludge detected!
	end
	_d = display
	g_display = display
	display:SetTitle("Ouro Loot")
	display:SetStatusText(g_status_text)
	display:SetLayout("Flow")
	display:SetStatusTable{width=800}
	-- prevent resizing, also see ace3 ticket #80
	--[[
	display.sizer_se:SetScript("OnMouseDown",nil)
	display.sizer_se:SetScript("OnMouseUp",nil)
	display.sizer_s:SetScript("OnMouseDown",nil)
	display.sizer_s:SetScript("OnMouseUp",nil)
	display.sizer_e:SetScript("OnMouseDown",nil)
	display.sizer_e:SetScript("OnMouseUp",nil)
	]]
	display:SetCallback("OnClose", function(_display)
		_d = _display:GetUserData("ST")
		GUI:Release(_display)
		collectgarbage()
	end)

	----- Right-hand panel
	local rhs_width = 0.20
	local control = GUI:Create("SimpleGroup")
	control:SetLayout("Flow")
	control:SetRelativeWidth(rhs_width)
	control.alignoffset = 25
	control:PauseLayout()
	local h,b

	--- Main ---
	h = GUI:Create("Heading")
	h:SetFullWidth(true)
	h:SetText("Main")
	control:AddChild(h)

	do
		b = mkbutton("Dropdown", nil, "",
			[[Enable full tracking, only rebroadcasting, or disable activity altogether.]])
		b:SetFullWidth(true)
		b:SetLabel("On/Off:")
		b:SetList{"Full Tracking", "Broadcasting", "Disabled"}
		b:SetValue(g_enabled and 1 or (g_rebroadcast and 2 or 3))
		b:SetCallback("OnValueChanged", function(_w,event,choice)
			if choice == 1 then       addon:Activate()
			elseif choice == 2 then   addon:Activate(nil,true)
			else                      addon:Deactivate()
			end
			_w = display:GetUserData('comm_ident')
			if _w and _w:IsVisible() then
				_w:SetDisabled(g_enabled or g_rebroadcast)
			end
			_w = display:GetUserData('eoi_bcast_req')
			if _w and _w:IsVisible() then
				_w:SetDisabled(not g_enabled)
			end
		end)
		control:AddChild(b)
	end

	b = mkbutton("Dropdown", 'threshold', "",
		[[Items greater than or equal to this quality will be tracked/rebroadcast.]])
	b:SetFullWidth(true)
	b:SetLabel("Threshold:")
	b:SetList(thresholds)
	b:SetValue(g_threshold)
	b:SetCallback("OnValueChanged", function(_dd,event,choice)
		addon:SetThreshold(choice)
	end)
	control:AddChild(b)

	b = mkbutton("Clear",
		[[+Erases> all current loot information and generated text (but not saved texts).]])
	b:SetFullWidth(true)
	b:SetCallback("OnClick", function()
		StaticPopup_Show("OUROL_CLEAR").data = addon
	end)
	control:AddChild(b)

	b = GUI:Create("Spacer")
	b:SetFullWidth(true)
	b:SetHeight(15)
	control:AddChild(b)

	--[[
	--- Saved Texts ---
	 [ Save Current As... ]
	   saved1
	   saved2
	   ...
	 [ Load ]  [ Delete ]
	]]
	h = GUI:Create("Heading")
	h:SetFullWidth(true)
	h:SetText("Saved Texts")
	control:AddChild(h)
	b = mkbutton("Save Current As...",
		[[Save forum/attendance/etc texts for later retrieval.  Main loot information not included.]])
	b:SetFullWidth(true)
	b:SetCallback("OnClick", function()
		StaticPopup_Show "OUROL_SAVE_SAVEAS"
		_d:Hide()
	end)
	control:AddChild(b)

	local saved = self:check_saved_table(--[[silent_on_empty=]]true)
	if saved then for i,s in ipairs(saved) do
		local il = GUI:Create("InteractiveLabel")
		il:SetFullWidth(true)
		il:SetText(s.name)
		il:SetUserData("num",i)
		il:SetHighlight(1,1,1,0.4)
		il:SetCallback("OnEnter", function()
			setstatus(("%s    %d entries     %s"):format(s.date,s.count,s.name))
		end)
		il:SetCallback("OnLeave", function() setstatus("") end)
		il:SetCallback("OnClick", function(_il)
			local prev = _d:GetUserData("saved selection")
			if prev then
				prev.highlight:Hide()
				prev:SetColor()
			end
			_il:SetColor(0,1,0)
			_il.highlight:Show()
			_d:SetUserData("saved selection",_il)
			_d:GetUserData("Load"):SetDisabled(false)
			_d:GetUserData("Delete"):SetDisabled(false)
		end)
		control:AddChild(il)
	end end

	b = mkbutton("Load",
		[[Load previously saved text.  +REPLACES> all current loot information!]])
	b:SetRelativeWidth(0.5)
	b:SetCallback("OnClick", function()
		local num = _d:GetUserData("saved selection"):GetUserData("num")
		addon:save_restore(num)
		addon:BuildMainDisplay()
	end)
	b:SetDisabled(true)
	control:AddChild(b)
	b = mkbutton("Delete",
		[[Delete previously saved text.]])
	b:SetRelativeWidth(0.5)
	b:SetCallback("OnClick", function()
		local num = _d:GetUserData("saved selection"):GetUserData("num")
		addon:save_delete(num)
		addon:BuildMainDisplay()
	end)
	b:SetDisabled(true)
	control:AddChild(b)

	b = GUI:Create("Spacer")
	b:SetFullWidth(true)
	b:SetHeight(15)
	control:AddChild(b)

	-- Other stuff on right-hand side
	local tab_specials = GUI:Create("SimpleGroup")
	tab_specials:SetLayout("Flow")
	tab_specials:SetFullWidth(true)
	control:AddChild(tab_specials)
	control:ResumeLayout()

	----- Left-hand group
	local tabs = GUI:Create("TabGroup")
	tabs:SetLayout("Flow")
	tabs.titletext:SetFontObject(GameFontNormalSmall) -- XXX
	do
		local n=0
		for _ in pairs(g_sender_list.active) do n=n+1 end
		tabs.titletext:SetFormattedText("Received broadcast data from %d |4player:players;.",n)
	end
	tabs:SetRelativeWidth(0.99-rhs_width)
	tabs:SetFullHeight(true)
	do
		local t={}
		for _,v in ipairs(taborder) do
			table.insert (t, {value=v, text=tabtexts[v].title})
			-- By default, tabs are editboxes with generated text
			if not tabs_OnGroupSelected[v] then
				tabs_OnGroupSelected[v] = tabs_generated_text_OGS
			end
		end
		tabs:SetTabs(t)
	end
	tabs:SetCallback("OnGroupSelected", tabs_OnGroupSelected_func)
	tabs:SetCallback("OnTabEnter", function(_tabs,event,value,tab)
		setstatus(tabtexts[value].desc)
	end)
	tabs:SetCallback("OnTabLeave", function() setstatus("") end)
	tabs:SetUserData("special buttons group",tab_specials)
	tabs:SelectTab(opt_tabselect or "eoi")

	display:AddChildren (tabs, control)
	display:ApplyStatus()

	display:Show() -- without this, only appears every *other* function call
	return display
end

end -- local 'do' scope


------ Player communication
do
	-- Incoming handler functions.  All take the sender name and the incoming
	-- tag as the first two arguments.  All of these are active even when the
	-- player is not tracking loot, so test for that when appropriate.
	local OCR_funcs = {}

	OCR_funcs.ping = function (sender)
		pprint('comm', "incoming ping from", sender)
		addon:whispercast (sender, 'pong', revision, 
			g_enabled and "tracking" or (g_rebroadcast and "broadcasting" or "disabled"))
	end
	OCR_funcs.pong = function (sender, _, rev, status)
		local s = ("|cff00ff00%s|r v2r%s is |cff00ffff%s|r"):format(sender,rev,status)
		addon:Print("Echo: ", s)
		g_sender_list.names[sender] = s
		g_sender_list.active[sender] = status=="tracking" or status=="broadcasting" or nil
	end

	OCR_funcs.loot = function (sender, _, recip, item, count, extratext)
		dprint('comm', "DOTloot, sender", sender, "recip", recip, "item", item, "count", count)
		if not g_enabled then return end
		g_sender_list.active[sender] = true
		addon:CHAT_MSG_LOOT ("broadcast", recip, item, count, sender, extratext)
	end

	OCR_funcs.boss = function (sender, _, reason, bossname, instancetag)
		dprint('comm', "DOTboss, sender", sender, "reason", reason, "name", bossname, "it", instancetag)
		if not g_enabled then return end
		g_sender_list.active[sender] = true
		addon:on_boss_broadcast (reason, bossname, instancetag)
	end

	OCR_funcs.bcast_req = function (sender)
		if g_debug.comm or ((not g_wafer_thin) and (not g_rebroadcast))
		then
			addon:Print("%s has requested additional broadcasters! Choose %s to enable rebroadcasting, or %s to remain off and also ignore rebroadcast requests for as long as you're logged in. Or do nothing for now to see if other requests arrive.",
				sender,
				format_hypertext('bcaston',"the red pill",'|cffff4040'),
				format_hypertext('waferthin',"the blue pill",'|cff0070dd'))
		end
		g_popped = true
	end

	OCR_funcs.bcast_responder = function (sender)
		if g_debug.comm or g_requesting or
		   ((not g_wafer_thin) and (not g_rebroadcast))
	   then
			addon:Print(sender, "has answered the call and is now broadcasting loot.")
		end
	end
	-- XXX remove this tag once it's all tested
	OCR_funcs.bcast_denied = function (sender)
		if g_requesting then addon:Print(sender, "declines futher broadcast requests.") end
	end

	-- Incoming message dispatcher
	local function dotdotdot (sender, tag, ...)
		local f = OCR_funcs[tag]
		dprint('comm', ":... processing",tag,"from",sender)
		if f then return f(sender,tag,...) end
		dprint('comm', "unknown comm message",tag",from", sender)
	end
	-- Recent message cache
	addon.recent_messages = create_new_cache ('comm', comm_cleanup_ttl)

	function addon:OnCommReceived (prefix, msg, distribution, sender)
		if prefix ~= ident then return end
		if not g_debug.comm then
			if distribution ~= "RAID" and distribution ~= "WHISPER" then return end
			if sender == my_name then return end
		end
		dprint('comm', ":OCR from", sender, "message is", msg)

		if self.recent_messages:test(msg) then
			return dprint('cache', "message <",msg,"> already in cache, skipping")
		end
		self.recent_messages:add(msg)

		-- Nothing is actually returned, just (ab)using tail calls.
		return dotdotdot(sender,strsplit('\a',msg))
	end

	function addon:OnCommReceivedNocache (prefix, msg, distribution, sender)
		if prefix ~= "OuroLoot2Tg" then return end
		if not g_debug.comm then
			if distribution ~= "WHISPER" then return end
			if sender == my_name then return end
		end
		dprint('comm', ":OCRN from", sender, "message is", msg)
		return dotdotdot(sender,strsplit('\a',msg))
	end
end


------ Popup dialogs
-- Callback for each Next/Accept stage of inserting a new loot row via dropdown
local function eoi_st_insert_OnAccept_boss (dialog, data)
	if data.all_done then
		-- It'll probably be the final entry in the table, but there might have
		-- been real loot happening at the same time.
		local boss_index = _addLootEntry{
			kind		= 'boss',
			bosskill	= (sv_OLoot_opts.snarky_boss and addon.boss_abbrev[data.name] or data.name) or data.name,
			reason		= 'kill',
			instance	= data.instance,
			duration	= 0,
		}
		local entry = table.remove(g_loot,boss_index)
		table.insert(g_loot,data.rowindex,entry)
		_mark_boss_kill(addon,data.rowindex)
		data.display:GetUserData("ST"):OuroLoot_Refresh(data.rowindex)
		dialog.data = nil   -- free up memory
		addon:Print("Inserted %s %s (entry %d).", data.kind, data.name, data.rowindex)
		return
	end

	local text = dialog.wideEditBox:GetText()

	-- second click
	if data.name and text then
		data.instance = text
		data.all_done = true
		-- in future do one more thing, for now just jump to the check
		return eoi_st_insert_OnAccept_boss (dialog, data)
	end

	-- first click
	if text then
		data.name = text
		local getinstance = StaticPopup_Show("OUROL_EOI_INSERT","instance")
		getinstance.data = data
		getinstance.wideEditBox:SetText(instance_tag())
		-- This suppresses auto-hide (which would case the getinstance dialog
		-- to go away), but only when mouse clicking.  OnEnter is on its own.
		return true
	end
end

local function eoi_st_insert_OnAccept_loot (dialog, data)
	if data.all_done then
		local real_g_rebroadcast, real_g_enabled = g_rebroadcast, g_enabled
		g_rebroadcast, g_enabled = false, true
		data.display:Hide()
		local loot_index = addon:CHAT_MSG_LOOT ("manual", data.recipient, data.name, data.notes)
		g_rebroadcast, g_enabled = real_g_rebroadcast, real_g_enabled
		local entry = table.remove(g_loot,loot_index)
		table.insert(g_loot,data.rowindex,entry)
		--data.display:GetUserData("ST"):OuroLoot_Refresh(data.rowindex)
		_fill_out_data(data.rowindex)
		addon:BuildMainDisplay()
		dialog.data = nil
		addon:Print("Inserted %s %s (entry %d).", data.kind, data.name, data.rowindex)
		return
	end

	local text = dialog.wideEditBox:GetText()

	-- third click
	if data.name and data.recipient and text then
		data.notes = (text ~= "<none>") and text or nil
		data.all_done = true
		return eoi_st_insert_OnAccept_loot (dialog, data)
	end

	-- second click
	if data.name and text then
		data.recipient = text
		local getnotes = StaticPopup_Show("OUROL_EOI_INSERT","notes")
		getnotes.data = data
		getnotes.wideEditBox:SetText("<none>")
		getnotes.wideEditBox:HighlightText()
		return true
	end

	-- first click
	if text then
		data.name = text
		dialog:Hide()  -- technically a "different" one about to be shown
		local getrecipient = StaticPopup_Show("OUROL_EOI_INSERT","recipient")
		getrecipient.data = data
		getrecipient.wideEditBox:SetText("")
		return true
	end
end

local function eoi_st_insert_OnAccept (dialog, data)
	if data.kind == 'boss' then
		return eoi_st_insert_OnAccept_boss (dialog, data)
	elseif data.kind == 'loot' then
		return eoi_st_insert_OnAccept_loot (dialog, data)
	end
end

StaticPopupDialogs["OUROL_CLEAR"] = {
  text = "Clear current loot information and text?",
  button1 = ACCEPT,
  button2 = CANCEL,
  OnAccept = function(dialog, addon)
	addon:Clear(--[[verbose_p=]]true)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = true,
}

StaticPopupDialogs["OUROL_REMIND"] = {
  text = "Do you wish to activate Ouro Loot?\n\n(Hit the Escape key to close this window without clicking)",
  button1 = "Activate recording",  -- "accept", left
  button3 = "Broadcast only",      -- "alt", middle
  button2 = "Help",                -- "cancel", right
  OnAccept = function(dialog, addon)
	addon:Activate()
  end,
  OnAlt = function(dialog, addon)
	addon:Activate(nil,true)
  end,
  OnCancel = function(dialog, addon)
	-- The 3rd arg would be "clicked" in both cases, not useful here.
	local helpbutton = dialog.button2
	local ismousing = MouseIsOver(helpbutton)
	if ismousing then
		-- they actually clicked the button (or at least the mouse was over "Help"
		-- when they hit escape... sigh)
		addon:BuildMainDisplay('help')
	else
		g_popped = true
	end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,  -- causes OnCancel to be called
}

local not_empty_EditBoxOnTextChanged = function(editbox)
	-- this is also called when first shown
	if editbox:GetText() ~= "" then
		editbox:GetParent().button1:Enable()
	else
		editbox:GetParent().button1:Disable()
	end
end

-- The data member here is a table built with:
-- {rowindex=<GUI row receiving click>, display=_d, kind=<loot/boss>}
StaticPopupDialogs["OUROL_EOI_INSERT"] = {
  text = "Enter name of new %s, then click Next or press Enter:",
  button1 = "Next >",
  button2 = CANCEL,
  hasEditBox = true,
  hasWideEditBox = true,
  maxLetters = 50,
  noCancelOnReuse = true,
  OnShow = function(dialog)
	dialog.wideEditBox:SetText("")
	dialog.wideEditBox:SetFocus()
  end,
  OnAccept = eoi_st_insert_OnAccept,
  EditBoxOnTextChanged = not_empty_EditBoxOnTextChanged,
  EditBoxOnEnterPressed = function(editbox)
	local dialog = editbox:GetParent()
	if not eoi_st_insert_OnAccept (dialog, dialog.data) then
		dialog:Hide()  -- replicate OnAccept click behavior
	end
  end,
  EditBoxOnEscapePressed = StaticPopup_EscapePressed,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  --enterClicksFirstButton = true,  -- no effect with editbox focused
}

-- This seems to be gratuitous use of metatables, really.
do
	local OEIL = {
		text = "Paste the new item into here, then click Next or press Enter:",
		__index = StaticPopupDialogs["OUROL_EOI_INSERT"]
	}
	StaticPopupDialogs["OUROL_EOI_INSERT_LOOT"] = setmetatable(OEIL,OEIL)

	hooksecurefunc("ChatEdit_InsertLink", function (link,...)
		local dialogname = StaticPopup_Visible "OUROL_EOI_INSERT_LOOT"
		if dialogname then
			_G[dialogname.."WideEditBox"]:SetText(link)
			return true
		end
	end)
end

StaticPopupDialogs["OUROL_REASSIGN_ENTER"] = {
  text = "Enter the player name:",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  OnShow = function(dialog)
	dialog.editBox:SetText("")
	dialog.editBox:SetFocus()
  end,
  OnAccept = function(dialog, data)
	local name = dialog.editBox:GetText()
	g_loot[data.index].person = name
	g_loot[data.index].person_class = select(2,UnitClass(name))
	addon:Print("Reassigned entry %d to '%s'.", data.index, name)
	data.display:GetUserData("ST"):OuroLoot_Refresh(data.index)
  end,
  EditBoxOnTextChanged = not_empty_EditBoxOnTextChanged,
  EditBoxOnEscapePressed = StaticPopup_EscapePressed,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = true,
}

StaticPopupDialogs["OUROL_SAVE_SAVEAS"] = {
  text = "Enter a name for the loot collection:",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = 30,
  OnShow = function(dialog)
	dialog.editBox:SetText("")
	dialog.editBox:SetFocus()
  end,
  OnAccept = function(dialog)--, data)
	local name = dialog.editBox:GetText()
	addon:save_saveas(name)
	addon:BuildMainDisplay()
  end,
  OnCancel = function(dialog)--, data, reason)
	addon:BuildMainDisplay()
  end,
  EditBoxOnEnterPressed = function(editbox)
	local dialog = editbox:GetParent()
	StaticPopupDialogs["OUROL_SAVE_SAVEAS"].OnAccept (dialog, dialog.data)
	dialog:Hide()
  end,
  EditBoxOnTextChanged = not_empty_EditBoxOnTextChanged,
  EditBoxOnEscapePressed = StaticPopup_EscapePressed,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = true,
}

-- vim:noet
