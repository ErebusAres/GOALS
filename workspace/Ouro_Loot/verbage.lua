
local todo = [[
- broadcasted entries triggering auto-shard don't have "shard" text

- [DONE,TEST,comm] releasing before DBM signals wipe results in outdoor location

- implement ack, then fallback to recording if not ack'd

- special treatment for recipes / BoE items?  default to guild vault?

- rebroadcasting entire boss sections, entire days.  maybe only whisper
to specific people rather than broadcast.

- signpost a potential boss kill, pipeline loot until the cache clears

- preserve auto-sharder name [DONE], threshold [DONE,TEST], and...?

- Being able to drag rows up and down the main loot grid would be awesome.  Coding
that would be likely to drive me batshiat insane.
]]

local addon = select(2,...)

addon.helptree = {
	{
		value = "about",
		text = "About",
	},
	{
		value = "basic",
		text = "Basics",
		children = {
			{
				value = "loot",
				text = "Loot Entries",
			},
			{
				value = "boss",
				text = "Boss Entries",
			},
		},
	},
	{
		value = "tracking",
		text = "Tracking Loot",
		children = {
			{
				value = "enabled",
				text = "Full Tracking",
			},
			{
				value = "bcast",
				text = "Rebroadcasting",
			},
		},
	},
	{
		value = "texts",
		text = "Generated Texts",
		children = {
			{
				value = "forum",
				text = "Forum Markup",
			},
			{
				value = "other",
				text = "Other Texts",
			},
			{
				value = "saved",
				text = "Saved Texts",
			},
		},
	},
	{
		value = "tips",
		text = "Handy Tips",
		children = {
			{
				value = "slashies",
				text = "Slash Commands",
			},
		},
	},
	{
		value = "todo",
		text = "TODOs, Bugs, etc",
		children = {
			{
				value = "gotchas",
				text = "Gotchas",
			},
			{
				value = "todolist",
				text = "TODO/knownbugs",
			},
        },
	},
}

-- Help text.  Formatting doesn't matter, but use a blank line to split
-- paragraphs.  This file needs to be edited with a text editor that doesn't
-- do anything stupid with extra spaces at the end of lines.
do
local replacement_colors = { ["+"]="|cff30adff", ["<"]="|cff00ff00", [">"]="|r" }
local T={}
T.about = [[
Ouro Loot is the fault of Farmbuyer of Ouroboros on US-Kilrogg.  Bug reports,
comments, and suggestions are welcome at the project page at curse.com or send
them to <farmbuyer@gmail.com>.
]]

T.basic = [[
The </ouroloot> (and </loot> by default) command opens this display.  The buttons
on the right side control operation and are mostly self-explanatory.  Hovering over
things will usually display some additional text in the gray line at the bottom.

Each tab on the left side can additionally create extra contols in the lower-right
section of the display.

The first tab on the left side, <Loot>, is where everything goes to and comes
from.  Looting events and Deadly Boss Mods notifications go to the <Loot> tab; the
other tabs are all generated from the information in the <Loot> tab.
]]

T.basic_loot = [[
A "loot row" in the first tab has three columns:  the item, the recipient, and any
extra notes.  The recipient's class icon is displayed by their names, if class
information is available at the time.

<Mouse Hover>

Hovering the mouse over the first column will display the item in a tooltip.

Hovering over the second column will display a tooltip with the loot that person
has received.  If they've won more than 10 items, the list is cut off with '...'
at the end; to see the full list, use the right-click +Show only this player> option
instead.

<Right-Click>

Right-clicking a loot row shows a dropdown menu.

Right-clicking in the first or third columns will display options for special
treatment of that loot entry (marking as offspec, etcetera).  Using any of those
options will change the text in the third column (which will then affect the text
in the generated tabs, such as forum markup).

Right-clicking in the second column allows you to temporarily remove all other
players from the loot display.  Use the reset button in the lower-right corner to
restore the display to normal.  The menu also allows you to +reassign> loot from
one player to another; if the new recipient is not in the raid group at the time,
use the +Enter name...> option at the bottom of the list of names to type the
name into a text box.  If your raid takes advantage of the new ability to trade
soulbound items, you will need to reassign the item here for the generated text
to be factually correct.

See the help screen on "Boss Entries" for the +Insert new boss kill event> option.

<Double-Click>

Double-clicking a loot row in the third ("Notes") column allows you to edit that
field directly.  The color of the text will still depend on any +Mark as ___>
actions done to that loot row, whether automatically or by hand.
]]

T.basic_boss = [[
Boss wipe/kill entries are entirely dependant on Deadly Boss Mods being enabled and
up-to-date.  The typical sequence of events for our usual raids goes like this:

We make four or five attempts on Baron Steamroller.  As DBM registers that combat
ends, a <wipe> event is entered on the loot display along with the duration of the
fight.  If the loot display is opened, the wipes will be visible with a light gray
background.

After reminding the dps classes to watch the threat meters, we manage to kill
Steamroller.  When DBM registers the win, a <kill> event is entered on the display
with a dark gray background.
All previous <wipe>s are removed and collapsed into the <kill> event.  The final
<kill> event shows the duration of the successful fight and the number of attempts
needed (or "one-shot" if we manage to be competent).

Sometimes this goes wrong, when DBM misses its own triggers.  If DBM does not catch
the start of the boss fight, it can't register the end, so nothing at all is
recorded.  If the fight was a win but DBM does not catch the victory conditions,
then DBM will (after several seconds) decide that it was a wipe instead.  And
sometimes useful loot will drop from trash mobs, which DBM knows nothing about.

For all those reasons, right-clicking on a "boss row" will display options for
+Insert new boss kill event>, and for toggling a <wipe> into a <kill>.  We often
insert bosses named "trash" to break up the display and correct the forum markup
listing.
]]

T.tracking = [[
The first button underneath +Main> in the right-hand column displays the current
status of the addon.  If it is disabled, then no recording, rebroadcasting, or
listening for rebroadcasts is performed.  Any loot already recorded will be restored
across login sessions no matter the status.

You can turn on tracking/broadcasting before joining a raid.  If you join a raid
and the addon has not been turned on, then (by default) a popup dialog will ask for
instructions.  (This can be turned off in the <Advanced> options.)

The addon tries to be smart about logging on during a raid (due to a disconnect or
relog).  If you log in, are already in a raid group, and loot has already been
stored from tracking, it will re-enable itself automatically.  It will not (as of
this writing) restore ancillary settings such as the tracking threshold.

The intent of the addon design is that, after the end of a raid, all the generated
markup text is done, optionally saved (see "Generated Texts - Saved Texts"), and
then cleared from
storage altogether.  As a result, if you login with restored loot information but
are not in a raid, the addon will do nothing on its own -- but will assume that
you've forgotten to finish those steps and will yammer about it in the chat window
as a reminder.

The +Threshold> drop-down has no connection at all with any current loot threshold
set by you or a master looter.
]]

T.tracking_enabled = [[
Full tracking records all loot events that fulfill these criteria:

1)  The loot quality is equal to or better than what you have selected in the
+Threshold> drop-down.

2)  The loot is not one of the few items hardcoded to not be tracked (badges,
emblems, Stone Keeper Shards, etc).

3)  <You can see the loot event.>  More precisely, you need to be close enough
to the recipient of the loot to be able to see "So-And-So receives loot: [Stuff]"
in your chat window, even if you have those actual loot messages turned off.

It is (3) that causes complications.  A master looter can assign loot to anybody
anywhere in a raid instance, but the range on detecting loot events is much
smaller.  If your raid does not use master looting then you merely need to be
close enough to the boss corpse, presuming that the winners will need to walk
over to get their phat epix.

If you do use master looter, then you have two options:  first, you can
require players
who might get loot to stay near the boss.  You would then also need to stay near
the boss to detect the loot event.  (This can be less hassle if you are also
the loot master.)  The downside is that other players moving on to fight to the
next boss are doing so without the help of their teammates.

The other option is to ask other players to also install Ouro Loot, and for
them to turn on the "Rebroadcasting" feature.  Any loot events which they can
see will be communicated to you.  Then it only becomes necessary for at least
one person to be close enough to the loot recipient to see the item awarded,
and you will record it no matter how far away you are -- even back in Dalaran.

If you have Full Tracking enabled, then you are also automatically rebroadcasting.
Having more than one player with Full Tracking turned on is probably a good
idea, in case one of the trackers experiences a game crash or is suddenly kidnapped
by robot ninja monkeys.
]]

T.tracking_bcast = [[
The simplest method of operation is only rebroadcasting the loot events that you
see, as you see them.  Nothing is recorded in your local copy of the addon.

If you logout for any reason, the addon will not reactivate when you log back in.

You can use </loot bcast> or </loot broadcast> to turn on rebroadcasting without
opening the GUI.
]]

T.texts = [[
The middle tabs are just large editboxes.  Their text is initially generated from
the information stored on the main <Loot> tab, at the time you click on the tab.
Not every bit of information that
we want in the generated text is always available, or depends on things that the
game itself can't know.  So you can edit the text in the tabs and your edits will
be preserved.

Each time you click one of the text tabs, every new entry on the <Loot> tab
since the last time this tab was shown will be turned into text.

Clicking the +Regenerate> button will throw away all the text on that tab, including
any edits you've made, and recreate all of it from scratch.  If you've accidentally
deleted the text from the editbox, or you've made manual changes to the <Loot> tab,
you can use this button to start over.

You can click in an editbox and use Control-A to select all text, then Control-C
to copy it to the system clipboard for subsequent pasting into a web browser or
whatever.  If you're on a Mac, you probably already know the equivalent keys.
]]

T.texts_forum = [[
The <Forum Markup> tab creates text as used by the guild forums for Ouroboros
of Kilrogg.  By default this is fairly standard BBcode.  The format of the
individual loot items can be adjusted via the dropdown menu on the lower right
of the tab.

The [url] choice defaults to using Wowhead.  If you have the [item] extension
for your BBcode installed, you can use either of those choices too.  The "by ID"
variant is good for heroic ToC/ICC items that share names with nonheroic items,
but is harder to read in the text tab.

You can also specify a custom string.  Formatting is done with these replacements:

+$N>:  item name|r

+$I>:  (capital "eye", not "ell") numeric item ID|r

+$T>:  loot recipient and any additional notes|r

+$X>:  if more than one of the item was looted, this is the "x2", "x3", etc


Pro tip #1:  if something has happened on the main <Loot> tab which cannot be
changed directly but would generate incorrect text, you can click this tab to
generate the text right away.  Then edit/move the text as needed.  When you
close the display or click back on the <Loot> tab, your edited text will be
preserved for later.

Pro tip #2:  Barring things like pro tip #1, the author typically does not
generate any text until the end of the raid.
]]

T.texts_other = [[
So far the only other generated text is the <Attendance> tab, an alphabetized list
on a per-boss basis.

Other addons can register their own text tabs and corresponding generation
functions.  If you want to be able to feed text into an offline program (for
example, a spreadsheet or DKP tracker), then this may be of use to you.

Ideas for more tabs?  Tell me!
]]

T.texts_saved = [[
The contents of the <Forum Markup> and <Attendance> tabs can be saved, so that they
will not be lost when you use the +Clear> button.

Do any edits you want to the generated text tabs, then click the +Save Current As...>
button on the right-hand side.  Enter a short descriptive reminder (for example,
"thursday hardmodes") in the popup dialog.  The texts will remain in their tabs,
but clearing loot information will not lose them now.

All saved texts are listed on the right-hand side.  There is no technical limit to
the number of saved texts, but the graphical display will begin to overflow after
about half a dozen saved sets.  (And I don't care.)

Clicking a saved text name lets you +Load> or +Delete> that saved set.  The primary
<Loot> tab is not saved and restored by this process, only the generated texts.
This also means you cannot +Regenerate> the texts.
]]

T.tips = [[
Shift-clicking an item in the <Loot> display will paste it into an open chat editbox.

The |cffff8000[Ouro Loot]|r "legendary item" link displayed at the start of all
chat messages is a clickable link.  Clicking opens the main display.  An option
on the <Advanced> tab will cause a message to be printed after a boss kill,
mostly for lazy loot trackers who don't like typing slash commands to open windows.

If you are broadcasting to somebody else who is tracking, you should probably be
using the same threshold.  If yours is lower, then some of the loot you broadcast
to him will be ignored.  If yours is higher, then you will not be sending information
that he would have recorded.  The "correct" setting depends on what your guild wants
to track.

Ticking the "notraid" box in <Advanced> debugging options, before enabling tracking,
will make the tracking work outside of a raid group.  Communication functions
will behave a little strangely when doing this.  Be sure to check the threshold!
You can also use <"/ouroloot debug notraid"> instead.

Using the "Saved Texts" feature plus the +Clear> button is a great way of putting
off pasting loot into your guild's website until a more convenient time.
]]

T.tips_slashies = [[
The </ouroloot> command can take arguments to do things without going through
the UI.  Parts given in *(angle brackets)* are required, parts in [square brackets]
are optional:

+broadcast>/+bcast>:  turns on rebroadcasting|r

+on [T]>:  turns on full tracking, optionally setting threshold to T|r

+off>:  turns off everything|r

+thre[shold] T>:  sets tracking threshold to T|r

+list>:  prints saved text names and numbers|r

+save *(your set name)*>:  saves texts as "your set name"|r

+restore *(N)*>:  restores set number N|r

+delete *(N)*>:  deletes set number N|r

+help>:  opens the UI to the help tab|r

+toggle>:  opens or closes the UI (used mostly in automated wrappers)|r


If you use the slash commands to enable tracking or set loot thresholds, you can
give numbers or common names for the threshold.  For example, "0", "poor", "trash",
"gray"/"grey" are all the same, "4", "epic", "purple" are the same, and so on.

If you give an unrecognized argument to the </ouroloot> slash command, it will
search the tab titles left to right for a title beginning with the same letters as
the argument, and open the display to that tab.  For example, <"/loot a"> would
open the <Attendance> tab, and <"/loot ad"> would open the <Advanced> tab.  If
you had added a theoretical <EQDKP> tab, then <"/loot eq"> would be the fastest
way to see it.
]]

T.todo = [[
If you have ideas or complaints or bug reports, first check the Bugs subcategories
to see if they're already being worked on.  Bug reports are especially helpful
if you can include a screenshot (in whatever image format you find convenient).

Click the "About" line on the left for contact information.
]]

T.todo_gotchas = [[
<Things Which Might Surprise You> (and things I'm not sure I like in the
current design):

If you relog (or get disconnected) while in a raid group, behavior when you log
back in can be surprising.  If you have already recorded loot (and therefore
the loot list is restored), then OL assumes it's from the current raid and should
reactivate automatically in full tracking mode.  If you were tracking but no
loot had dropped yet (and therefore there was nothing *to* restore), then OL
will pop up its reminder and ask again.  Either way, if you were only broadcasting
then OL will *not* go back to only broadcasting.  This is probably a bug.

The saved texts feature does exactly that: only saves the generated texts, not
the full loot list.  Restoring will get you a blank first tab and whatever you
previously had in the various generated text tabs.

Using the right-click menu to change an item's treatment (shard, offspec, etc)
does not broadcast that change to anyone else who is also tracking.  Changing
the item and then selecting "rebroadcast this item" *does* include that extra
info.  Doing that on the initial "mark as xxx" action is... tricky.

The generated text tries to only list the name of the instance if it has not
already been listed, or if it is different than the instance of the previous
boss.  If you relog, the "last printed instance name" will be lost, and you'll
see redundant raid instance names appearing in the text.

After a boss wipe, multiple broadcasting players releasing spirit more than
several seconds apart can cause spurious "wipe" entries (of zero duration) on
the loot grid.  The surefire way to avoid this is to not release spirit until
DBM announces the wipe, but the problem isn't serious enough to really worry
about.  (Right-click the spurious entries and delete them.)
]]

T.todo_todolist = todo


-- Fill out the table that will actually be used.  Join adjacent lines here so
-- that they'll wrap properly.
addon.helptext = {}
for k,text in pairs(T) do
	local funkykey = k:gsub('_','\001')  -- this is how TreeGroup makes unique keys
	local wrapped = text
	wrapped = wrapped:gsub ("[%+<>]", replacement_colors)
	wrapped = wrapped:gsub ("([^\n])\n([^\n])", "%1 %2")
	wrapped = wrapped:gsub ("|r\n\n", "|r\n")
	wrapped = wrapped:gsub ("Ouroboros", "|cffa335ee<Ouroboros>|r")
	wrapped = wrapped:gsub ("%*%(", "<") :gsub("%)%*", ">")
	addon.helptext[funkykey] = wrapped
end
end -- do scope
todo = nil


-- Don't bother recording any of this loot:
addon.default_itemfilter = {
	[29434]		= true, -- Badge of Justice
	[40752]		= true, -- Emblem of Heroism
	[40753]		= true, -- Emblem of Valor
	[45624]		= true, -- Emblem of Conquest
	-- could probably remove the above now
	[43228]		= true, -- Stone Keeper's Shard
	[47241]		= true, -- Emblem of Triumph
	[49426]		= true, -- Emblem of Frost
}

-- vim:noet
