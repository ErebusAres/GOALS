local addon = select(2,...)

--[[ Generator:
boolean FUNC (ttype, loot, last_printed, generated, cache)
in      TTYPE:  the registered text type as passed to register_text_generator
in      LOOT:  pointer to g_loot table
in      LAST_PRINTED:  index into loot most recently formatted by this routine
in      GENERATED.TTYPE:  (string) FIFO buffer for text created by this routine;
           other parts of the GUI copy and nil out this string.  Do not change
           this string, only examine it if needed.  If the generator is called
           more than once between GUI updates, text will build up here.
in/out  GENERATED.TTYPE_pos:  if non-nil, this is the saved cursor position in
           the text window (so that it stays where the user last left it).
           Move it if you're doing something strange with the displayed text.
tmp     GENERATED.loc_TTYPE_*:  Use as needed.
out     CACHE:  Empty output table.  Accumulate generated lines here, one entry
           per visible line.  Do not terminate with a newline unless you want
           an extra blank line there.

Preconditions:
  + LAST_PRINTED < #LOOT
  + all "display-relevant" information for the main Loot tab has been filled
    out (e.g., LOOT[i].cols[3] might have extra text, etc)
  + LOOT.TTYPE is a non-nil string containing all text in the text box (and
    if the user has edited the text box, this string will be updated).  Do not
    change this, but like GENERATED.TTYPE it is available for examination.

Return true if text was created, false if nothing was done.
]]

--[[ Optional special widgets:
FUNC (ttype, editbox, container, mkbutton)
    TTYPE:  see above
    EDITBOX:  the MultiLineEditBox widget
    CONTAINER:  widget container (already has 'Regenerate' button in it)
    MKBUTTON:  function to create more AceGUI widgets, as follows:

mkbutton ("WidgetType", 'display key', "Text On Widget", "the mouseover display text")
mkbutton ( [Button]     'display key', "Text On Widget", "the mouseover display text")
mkbutton ( [Button]      [text]        "Text On Widget", "the mouseover display text")

The 'display key' parameter will almost certainly be specified as nil for these functions.
]]

local forum_warned_heroic
local warning_text = [[|cffff0505WARNING:|r  Heroic items sharing the same name as normal items often display incorrectly on forums that use the item name as the identifier.  Recommend you turn on 'Use item IDs' and regenerate this loot.]]

local function forum (_, loot, last_printed, generated, cache)
	local fmt = sv_OLoot_opts.forum[sv_OLoot_opts.forum_current] or ""
	-- if it's capable of handling heroic items, consider them warned already
	forum_warned_heroic = forum_warned_heroic or fmt:find'%$I'

	for i = last_printed+1, #loot do
		local e = loot[i]

		if e.kind == 'loot' then
			-- assuming nobody names a toon "offspec" or "gvault"
			local disp = e.disposition or e.person
			if disp == 'offspec' then
				disp = e.person .. " " .. 'offspec'
			elseif disp == 'gvault' then
				--disp = "guild vault (".. e.person .. ")"
				disp = "guild vault"
			end
			if e.extratext_byhand then
				disp = disp .. " -- " .. e.extratext
			end
			if e.is_heroic and not forum_warned_heroic then
				forum_warned_heroic = true
				addon:Print(warning_text)
			end
			local t = fmt:gsub('%$I', e.id)
			             :gsub('%$N', e.itemname)
			             :gsub('%$X', e.count or "")
			             :gsub('%$T', disp)
			cache[#cache+1] = t

		elseif e.kind == 'boss' and e.reason == 'kill' then
			-- first boss in an instance gets an instance tag, others get a blank line
			if generated.last_instance == e.instance then
				cache[#cache+1] = ""
			else
				cache[#cache+1] = "\n[b]" .. e.instance .. "[/b]"
				generated.last_instance = e.instance
			end
			cache[#cache+1] = "[i]" .. e.bosskill .. "[/i]"

		elseif e.kind == 'time' then
			cache[#cache+1] = "[b]" .. e.startday.text .. "[/b]"

		end
	end
	return true
end

local function forum_specials (_,_, container, mkbutton)
	local map,current = {}
	for label,format in pairs(sv_OLoot_opts.forum) do
		table.insert(map,label)
		if label == sv_OLoot_opts.forum_current then
			current = #map
		end
	end

	local dd, editbox
	dd = mkbutton("Dropdown", nil, "",
		[[Chose specific formatting of loot items.  See Help tab for more.  Regenerate to take effect.]])
	dd:SetFullWidth(true)
	dd:SetLabel("Item markup")
	dd:SetList(map)
	dd:SetValue(current)
	dd:SetCallback("OnValueChanged", function(_dd,event,choice)
		sv_OLoot_opts.forum_current = map[choice]
		forum_warned_heroic = nil
		editbox:SetDisabled(map[choice] ~= "Custom...")
	end)
	container:AddChild(dd)

	editbox = mkbutton("EditBox", nil, sv_OLoot_opts.forum["Custom..."],
		[[Format described in Help tab (Generated Text -> Forum Markup).]])
	editbox:SetFullWidth(true)
	editbox:SetLabel("Custom:")
	editbox:SetCallback("OnEnterPressed", function(_e,event,value)
		sv_OLoot_opts.forum["Custom..."] = value
		_e.editbox:ClearFocus()
	end)
	editbox:SetDisabled(sv_OLoot_opts.forum_current ~= "Custom...")
	container:AddChild(editbox)
end

addon:register_text_generator ("forum", [[Forum Markup]], [[BBcode ready for Ouroboros forums]], forum, forum_specials)


local function att (_, loot, last_printed, _, cache)
	for i = last_printed+1, #loot do
		local e = loot[i]

		if e.kind == 'boss' and e.reason == 'kill' then
			cache[#cache+1] = ("\n%s -- %s\n%s"):format(e.instance, e.bosskill, e.raiderlist or '<none recorded>')

		elseif e.kind == 'time' then
			cache[#cache+1] = e.startday.text

		end
	end
	return true
end

local function att_specials (_, editbox, container, mkbutton)
	local w = mkbutton("Take Attendance",
		[[Take attendance now (will continue to take attendance on each boss kill).]])
	w:SetFullWidth(true)
	w:SetCallback("OnClick", function(_w)
		local raiders = {}
		for i = 1, GetNumRaidMembers() do
			table.insert(raiders, (GetRaidRosterInfo(i)))
		end
		table.sort(raiders)
		local h, m = GetGameTime()
		local additional = ("Attendance at %s:%s:\n%s"):format(h,m,table.concat(raiders, ", "))
		editbox:SetText(editbox:GetText() .. '\n' .. additional)
	end)
	container:AddChild(w)
end

addon:register_text_generator ("attend", [[Attendance]], [[Attendance list for each kill]], att, att_specials)

-- vim:noet
