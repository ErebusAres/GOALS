if UnitName"player" ~= "Farmbuyer" then return end
local addon = select(2,...)

-- We keep some local state bundled up rather than trying to pass it around
-- as paramters (which would have entailed creating a ton of closures).
local state = {}
local tag_lookup_handlers = {}
local do_tag_lookup_handler


--[[
This is taken from CT_RaidTracker 1.7.32, reconstructing the output from
code inspection.  No official format documents are available on the web
without downloading and installing the EQDKP webserver package.  Bah.

Case of tag names shouldn't matter, but is preserved here from CT_RaidTracker
code for comparison of generated output.

There is some waste adding newlines between elements here only to strip them
out later, but it's worth the extra cycles for debugging and verification.

$TIMESTAMP,$ENDTIME MM/DD/YY HH:mm:ss except we don't have seconds available
$REALM              GetRealmName()
$ZONE               raw name, not snarky
$RAIDNOTE           arbitrary text for the raid event
$PHAT_LEWTS         all accumulated loot entries
]]
local XML = ([====[
<RaidInfo>
<Version>1.4</Version>  {In live output, this is missing due to scoping bug in ct_raidtracker.lua:3471}
<key>$TIMESTAMP</key>
<realm>$REALM</realm>
<start>$TIMESTAMP</start>   {Same as the key, apparently?}
<end>$ENDTIME</end>    {Set by the "end the raid" command in the raid tracker, here just the final entry time}
<zone>$ZONE</zone>   {may be optional.  first one on the list in case of multiple zones?}
{<difficulty>$DIFFICULTY</difficulty>   {this scales badly in places like ICC.  may be optional?}}

{<PlayerInfos>... {guh.}}

<BossKills>
  $BOSS_KILLS
</BossKills>

{<Wipes>  bleh}
{<NextBoss>Baron Steamroller</NextBoss>  {only one "next boss" for the whole raid event?  huh?}}

<note><![CDATA[$RAIDNOTE - Zone: $ZONE]]></note>

{<Join>...</Join><Leave>...</Leave>   {specific timestamps per player. meh.}}

<Loot>
  $PHAT_LEWTS
</Loot>
</RaidInfo>]====]):gsub('%b{}', "")

--[[
See the loot markup, next block.
]]
local boss_kills_xml = ([====[
  <key$N>
    <name>$BOSS_NAME</name>
    <time>$BOSS_TIME</time>
    <attendees></attendees>   {this is actually empty in the working example...}
    <difficulty>$DIFFICULTY</difficulty>
  </key$N>
]====]):gsub('%b{}', "")

local function boss_kills_tag_lookup (tag)
	if tag == 'N' then
		return tostring(state.key)
	elseif tag == 'BOSS_NAME' then
		return state.entry.bosskill
	elseif tag == 'BOSS_TIME' then
		return do_tag_lookup_handler (state.index, state.entry, 'TIME')
	else
		return do_tag_lookup_handler (state.index, state.entry, tag) or 'NYI'
	end
end

--[[
$N                  1-based loop variable for key element
$ITEMNAME           Without The Brackets
$ITEMID             Not the ID, actually a full itemstring without the leading "item:"
$ICON               Last component of texture path?
$CLASS,$SUBCLASS    ItemType
$COLOR              GetItemQualityColor, full 8-digit string
$COUNT,$BOSS,$ZONE,
  $PLAYER           all self-explanatory
$COSTS              in DKP points... hmmm
$ITEMNOTE           take the notes field for this one
$TIME               another formatted timestamp
]]
local phat_lewt_xml = ([====[
  <key$N>
$LEWT_GRUNTWORK
    <zone>$ZONE</zone>   {may be optional}
    <difficulty>$DIFFICULTY</difficulty>   {this scales badly in places like ICC.  may be optional?}
    <Note><![CDATA[$ITEMNOTE - Zone: $ZONE - Boss: $BOSS - $COSTS DKP]]></Note> {zone can be followed by difficulty}
  </key$N>
]====]):gsub('%b{}', "")

local function phat_lewt_tag_lookup (tag)
	if tag == 'N' then
		return tostring(state.key)
	elseif tag == 'COSTS'
		then return '1'
	else
		return do_tag_lookup_handler (state.index, state.entry, tag) or 'NYI'
	end
end

do
	local gruntwork_tags = {
		"ItemName", "ItemID", "Icon", "Class", "SubClass", "Color", "Count",
		"Player", "Costs", "Boss", "Time",
	}
	for i,tag in ipairs(gruntwork_tags) do
		gruntwork_tags[i] = ("    <%s>$%s</%s>"):format(tag,tag:upper(),tag)
	end
	phat_lewt_xml = phat_lewt_xml:gsub('$LEWT_GRUNTWORK', table.concat(gruntwork_tags,'\n'))
end


local function format_EQDKP_timestamp (day_entry, time_entry)
	--assert(e.kind == 'time', e.kind .. " passed to MLEQDKP timestamp")
	return ("%.2d/%.2d/%.2d %.2d:%.2d:00"):format(
		day_entry.startday.month, day_entry.startday.day, day_entry.startday.year % 100,
		(time_entry or day_entry).hour, (time_entry or day_entry).minute)
end


-- Look up tag strings for a particular item, given index and entry table.
tag_lookup_handlers.ITEMNAME =
	function (i, e)
		return e.itemname
	end

tag_lookup_handlers.ITEMID =
	function (i, e)
		return e.itemlink:match("^|c%x+|H(item[%d:]+)|h%[")
	end

tag_lookup_handlers.ICON =
	function (i, e)
		local str = e.itexture
		repeat
			local s = str:find('\\')
			if s then str = str:sub(s+1) end
		until not s
		return str
	end

tag_lookup_handlers.CLASS =
	function (i, e)
		return state.class
	end

tag_lookup_handlers.SUBCLASS =
	function (i, e)
		return state.subclass
	end

tag_lookup_handlers.COLOR =
	function (i, e)
		local q = select(4, GetItemQualityColor(e.quality))
		return q:sub(3)  -- skip leading |c
	end

tag_lookup_handlers.COUNT =
	function (i, e)
		return e.count and e.count:sub(2) or "1"   -- skip the leading "x"
	end

-- maybe combine these next two
tag_lookup_handlers.BOSS =
	function (i, e)
		while i > 0 and state.loot[i].kind ~= 'boss' do
			i = i - 1
		end
		if i == 0 then return "No Boss Entry Found, Unknown Boss" end
		return state.loot[i].bosskill
	end

tag_lookup_handlers.ZONE =
	function (i, e)
		while i > 0 and state.loot[i].kind ~= 'boss' do
			i = i - 1
		end
		if i == 0 then return "No Boss Entry Found, Unknown Zone" end
		return state.loot[i].instance
	end

tag_lookup_handlers.DIFFICULTY =
	function (i, e)
		local tag = tag_lookup_handlers.ZONE(i,e)
		local N,h = tag:match("%((%d+)(h?)%)")
		if not N then return "1" end -- maybe signal an error instead?
		N = tonumber(N)
		N = ( (N==10) and 1 or 2 ) + ( (h=='h') and 2 or 0 )
		return tostring(N)
	end

tag_lookup_handlers.PLAYER =
	function (i, e)
		return state.player
	end

tag_lookup_handlers.ITEMNOTE =
	function (i, e)
		return state.itemnote
	end

tag_lookup_handlers.TIME =
	function (i, e)
		local ti,tl = addon:find_previous_time_entry(i)
		return format_EQDKP_timestamp(tl,e)
	end


function do_tag_lookup_handler (index, entry, tag)
	local h = tag_lookup_handlers[tag]
	if h then
		return h(index,entry)
	else
		error(("MLDKP tag lookup (index %d) on tag %s with no handler"):format(index,tag))
	end
end

local function generator (ttype, loot, last_printed, generated, cache)
	-- Because it's XML, generated text is "grown" by shoving more crap into
	-- the middle instead of appending to the end.  Only easy way of doing that
	-- here is regenerating it from scratch each time.
	generated[ttype] = nil

	local _
	local text = XML
	state.loot = loot

	-- TIMESTAMPs
	do
		local f,l  -- first and last timestamps in the table
		for i = 1, #loot do
			if loot[i].kind == 'time' then
				f = format_EQDKP_timestamp(loot[i])
				break
			end
		end
		_,l = addon:find_previous_time_entry(#loot)  -- latest timestamp
		l = format_EQDKP_timestamp(l,loot[#loot])
		text = text:gsub('$TIMESTAMP', f):gsub('$ENDTIME', l)
	end

	-- Loot
	do
		local all_lewts = {}
		local lewt_template = phat_lewt_xml

		state.key = 1
		for i,e in addon:filtered_loot_iter('loot') do
			state.index, state.entry = i, e
			-- no sense doing repeated getiteminfo calls
			state.class, state.subclass = select(6, GetItemInfo(e.id))

			-- similar logic as text_tabs.lua:
			-- assuming nobody names a toon "offspec" or "gvault"
			local P, N
			local disp = e.disposition or e.person
			if disp == 'offspec' then
				P,N = e.person, "offspec"
			elseif disp == 'gvault' then
				P,N = "guild vault", e.person
			else
				P,N = disp, ""
			end
			if e.extratext_byhand then
				N = N .. " -- " .. e.extratext
			end
			state.player, state.itemnote = P, N

			all_lewts[#all_lewts+1] = lewt_template:gsub('%$([%w_]+)',
				phat_lewt_tag_lookup)
			state.key = state.key + 1
		end

		text = text:gsub('$PHAT_LEWTS', table.concat(all_lewts, '\n'))
	end

	-- Bosses
	do
		local all_bosses = {}
		local boss_template = boss_kills_xml

		state.key = 1
		for i,e in addon:filtered_loot_iter('boss') do
			if e.reason == 'kill' then  -- oh, for a 'continue' statement...
				state.index, state.entry = i, e
				all_bosses[#all_bosses+1] = boss_template:gsub('%$([%w_]+)',
					boss_kills_tag_lookup)
				state.key = state.key + 1
			end
		end

		text = text:gsub('$BOSS_KILLS', table.concat(all_bosses, '\n'))
	end

	-- In addition to doing the top-level zone, this will also catch any
	-- leftover $ZONE tags.  There could be multiple places in the raid, so
	-- we default to the first one we saw.
	do
		local iter = addon:filtered_loot_iter()  -- HACK
		local first_boss = iter('boss',0)
		local zone = first_boss and loot[first_boss].instance or "Unknown"
		text = text:gsub('$ZONE', zone)
	end

	-- Misc
	text = text:gsub('$REALM', (GetRealmName()))
	--text = text:gsub('$DIFFICULTY', )
	text = text:gsub('$RAIDNOTE', "")

	cache[#cache+1] = "Formatted version (scroll down for unformatted):"
	cache[#cache+1] = "==========================="
	cache[#cache+1] = text
	cache[#cache+1] = '\n'

	cache[#cache+1] = "Unformatted version:"
	cache[#cache+1] = "==========================="
	text = text:gsub('>%s+<', "><")
	cache[#cache+1] = text
	cache[#cache+1] = '\n'

	wipe(state)
	return true
end

local function specials (_, editbox, container, mkbutton)
	local hl = mkbutton("Highlight",
		[[Highlight the unformatted copy for copy-and-pasting.]])
	hl:SetFullWidth(true)
	hl:SetCallback("OnClick", function(_hl)
		local txt = editbox:GetText()
		local _,start = txt:find("Unformatted version:\n=+\n")
		local _,finish = txt:find("</RaidInfo>", start)
		editbox.editBox:HighlightText(start,finish)
		editbox.editBox:SetCursorPosition(start)
	end)
	container:AddChild(hl)
end

addon:register_text_generator ("mleqdkp", [[ML/EQ-DKP]], [[MLdkp 1.1 EQDKP format]], generator, specials)

-- vim:noet
