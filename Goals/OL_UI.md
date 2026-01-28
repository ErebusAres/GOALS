# Ouro Loot UI Alignment Plan (GOALS)

Goal: reshape GOALS UI to match Ouro Loot's layout and readability while **keeping the current titlebar (minimize + close)** and **keeping class-colored names**.

---

## Current Status (Implemented)

### Layout + Tabs

- Main tabs moved to a **top tab bar** using `OptionsFrameTabButtonTemplate` (OL-style) with a dark strip and thin divider line.
- Wishlist sub-tabs also have a dark strip + divider for OL-style continuity.
- Main content area starts below the tab bar and is taller (tabs no longer consume bottom space).

### Table Layout + Styling

- Shared table widget in place with OL-like header bars, stripes, and column layout.
- Header bar height reduced to 16px for tighter density.
- Column spacing tightened (default spacing 6px).
- Row stripes slightly stronger for readability.
- History rows set to 18px height.
- Loot rows set to 18px (compact) with merged Found/Assign behavior.
- Tables aligned to the scrollbar edge for a cleaner OL-like look.

### Right Options Panels

- Right panels widened to **240px** to fit AceGUI-style 200px controls without clipping.
- Options section headers now use **AceGUI Heading** styling: centered gold text + left/right tooltip-border lines.
- Option controls standardized to **200x24** (buttons, dropdowns, edit boxes) for AceGUI parity.
- Checkbox styling updated to AceGUI defaults: **24px** boxes with `UI-CheckBox` textures and **white** labels.
- Dropdown/edit box labels moved **above** controls (AceGUI `SetLabel` layout); dropdown text now white.
- Options panel buttons switched to `UIPanelButtonTemplate2` and stacked vertically where needed (manual tools + notes).
- Options panel buttons now use **named** frames to avoid `UIPanelButtonTemplate2` OnShow/OnDisable nil-name errors.
- Dropdowns now use AceGUI-style holder frames to match OL sizing/offsets (dropdown anchored -15/ +17 inside a 200px holder).
- Dropdown text insets/texture alignment updated to match AceGUI; edit boxes use AceGUI-style height/insets.
- Notes Apply/Clear buttons now use a paired half-width layout to mirror OL's Load/Delete button row.
- Option tooltips now pop out to the right of the main GUI via a shared side tooltip helper.
- Side tooltips wrap to the options-panel width for readability, and options labels are shortened with beginner-friendly tooltip explanations.
- Options section labels now wrap to the 200px control width for readability.
- Added tooltips for common dropdowns/edit boxes (sort, quality filters, manual amount, etc).
- Help tab removed; guidance now lives in inline tooltips.
- Spacing adjusted to ~6-8px between controls/sections.
- Added per-tab **footer info bar** at the bottom of each tab (status/permissions + tracking/disenchanter summary).
- Footer now includes centered sync status: `Syncing From: <name> | <timer> Last Sync.`

### Combat Log Tracking

- Combat log is **toggleable** (default OFF) via Combat options.
- Combat tab always visible; tracking can be enabled/disabled.
- Filter moved into options panel (top section).
- Incoming damage/heals tracked; optional outgoing damage tracking.
- Combat log arg handling hardened to work whether CLEU passes args directly or via CombatLogGetCurrentEventInfo.
- Debug tab includes Combat Tracker diagnostics + Test Damage/Heal buttons.
- Combat log persists across reloads unless cleared.

### Loot Table Behavior

- Loot rows: **Found + Assign merged** (single row updates on assignment).
- Notes system: auto notes (Found/Looted/Assigned/Disenchanted), manual notes override.
- Notes UI in Loot right panel with Apply/Clear.
- Right-click on Found row assigns loot (same as old Found Loot list).
- Long item names truncate with `...` while preserving item color.
- Item tooltip now only opens when clicking the **item name column**, not the full row.

### Overview + Access Controls

- Overview table now aligned: Player | Points | Actions (buttons under Actions header).
- Admin/dev controls hidden for non-admin users (not just disabled).
- Ask for sync moved into Sync section (visible to all).
- Sync Seen button hidden for now.
- Added `+1 All` button in the Overview table header (top right, aligned with Actions).
- Removed the Manual Adjust section from Overview options (replaced by +1 All header button).
- Footer access text now shows role-aware labels (Dev/Admin/Loot Master/Loot Helper/Raid-Party/Solo).

### Wishlist

- Wishlist layout **kept Wowhead-style** (not a table).
- Options sub-tab is now a scroll frame with always-visible scrollbar.
- Wishlist left panel widened and right panel shrunk; column-3 (mainhand/offhand/relic) row moved down.
- Wishlist slots label removed; refresh button moved to bottom right; columns 1/2 moved up to fill space.

---

## Remaining Work / To-Do

### Options Panel UI Matching (Primary Tabs)

**Mostly done:** right-side options now mimic OL's AceGUI visuals (Heading lines + 200x24 controls + label-above layout).

**Validate / tune**

- Options panel widths/spacing on Overview/Loot/History/Combat after widening to 240px.
- Dropdown/checkbox/button visuals match OL (fonts/colors/spacing).
- Footer info bars do not overlap content and show correct status text.
- Check long labels/values don't clip within the new label-above layout.

### Table Look + Feel

- Verify all tables use consistent header height/spacing across tabs.
- Check column widths for Loot/History/Combat to better match OL proportions.
- Consider subtle separators between major table groups (if needed).

### Scrollbars + Alignment

- Ensure scrollbars are **always visible** (greyed when not scrollable) on relevant panels.
- Confirm no overlap between scrollbars and right-panel controls.

### Access / Roles

- Confirm loot master/raid helper access rules for buttons and actions.
- Decide if any admin sections should remain visible for non-admins (or hidden).

### Settings Cleanup

- Settings tab is removed from main tabs.
- Decide whether to reintroduce a Settings tab later in OL tone.
- If reintroduced, define what belongs there vs per-tab options.

### Combat Broadcast Tool (Implemented)

- OL-styled popout window for broadcasting recent combat log entries.
- Uses currently visible/filtered entries (respects filters + show toggles + big-number threshold).
- Slider: 0–9 (default 9) for how many recent entries to send.
- Channel dropdown: shows only available chat types (no /raid or /rl unless in raid; /rl only if leader; no /party unless in party).
- Whisper + Whisper Target options; selecting Whisper reveals a target input box.
- Send button outputs lines without timestamps (Source -> Target Amount Ability).

### Combat Row Context Menu (Implemented)

- Right-click on a combat row opens a Send To menu.
- Menu shows available channels (same rules as dropdown).
- Whisper opens a prompt for target name.
- Sends only that row’s formatted text.

---

## Testing Checklist (Run Each Session)

- Tabs render correctly in top bar; Help pinned right.
- Main content area doesn't overlap tab bar or titlebar.
- Table headers align with rows; columns line up with scrollbar edge.
- Right panel sections use OL-style Heading (centered text with left/right lines).
- Dropdown labels appear above controls and use gold text.
- Buttons look like OL (UIPanelButtonTemplate2, 200x24).
- Checkboxes are 24px with white labels (AceGUI style).
- Loot item truncation works with `...` and tooltip still opens.
- Found loot assignment via right-click works as before.
- Combat log always active and combat tab always visible.
- Combat broadcast: send button posts correct lines with current filters; right-click Send To menu works per row.
- Wishlist Options tab scrolls with scrollbar always visible.
- Dev/Admin buttons hidden for non-admin players.

---

## Prompt (for next session)

Use this prompt to continue in a new chat:

"I'm working on GOALS (WoW 3.3.5a) UI to match Ouro Loot. Main tabs are a top OL-style bar (OptionsFrameTabButtonTemplate + dark strip + divider), wishlist sub-tabs match. Tables use the shared widget with 16px headers, tighter spacing, stripes, and alignment to scrollbar edge. Right option panels now mimic AceGUI: 240px wide, Heading-style section headers with tooltip-border lines and centered gold text; controls are 200x24; dropdown/edit box labels are above controls (gold); dropdown text is white; checkboxes are 24px with white GameFontHighlight labels; buttons use UIPanelButtonTemplate2 and are stacked vertically. Loot table merges Found+Assign rows, notes system + UI, right-click assign works, long loot names truncate with ..., tooltip only on item name column. Combat log is toggleable; filter in combat options; big number threshold is a single percent slider with a live label; heal/damage display is controlled by Show Healing / Show Damage Dealt / Show Damage Received (still tracks). Combat tracker columns are Time | Source | Target | Amount | Ability. Overview actions align under Actions column; admin controls hidden for non-admins; Ask for sync in Sync section; Sync Seen hidden. Wishlist layout stays Wowhead-style with options scroll.

Please validate the new options panel spacing/alignment (Overview/Loot/History/Combat), check for clipping with the 240px width and label-above layout, confirm scrollbars don't overlap, and then continue any remaining OL-alignment tweaks (table column widths, separators, etc). Combat options now use a single percent slider for big-number thresholds (with a live label); confirm it aligns with OL control spacing. Update `Goals/gui.lua` and **always update `Goals/OL_UI.md` with changes, remaining work, and the next prompt for continuity**."

---

## Open Questions

- Final desired widths for key columns (Loot/History/Combat)?
- Should any admin-only controls remain visible but disabled for regular users?
- Do we want to reintroduce a Settings tab later, or keep all options on their respective tabs?

## Issues found 1/23/2026 AND 1/26/2026

- Combat Tracker still doesnt work at all, damage or healing. **(Attempted fix: added CLEU arg shift fallback + roster name matching + skip reason in debug status.)**
- Combat Tracker boss encounter for Zul'Aman (spelling?) didnt track Zul'jin fight start or end? **(Fixed: added Zul'jin to boss list.)**
- Combat Debug tab should be set to a list mode/multi-line list that i can copy/paste from for testing/debugging. **(Fixed: Debug tab now uses a multi-line scrollable edit box and auto-populates.)**
- The Unassigned changing to assigned in the Loot tab doesnt modify the note nor set the player name, it adds a new line. **(Attempted fix: widen LOOT_FOUND/ASSIGN merge window to 3600s.)**
- The Disenchanter being set to 0 doesnt auto assign the loot to them and doesn't show `Assigned (Reset -#)` note. **(Adjusted: roster “0” on the disenchanter now converts a recent assignment into a loot reset entry when possible; history note updates instead of adding a duplicate line.)**
- Goals thinks you start the Milleniax fight when you attack `Infinite Timereaver`s. **(Fixed: added ignore list for Infinite Timereaver in encounter detection.)**

## Changes / Changelog (1/27/2026)

- Combat tracker parsing: added payload shift handling (older CLEU without raid flags) + roster-name fallback, and debug status now shows “added/skip reason” for the last event.
- Debug tab: restored debug log as a multi-line scrollable edit box for copy/paste; log auto-updates when entries are appended.
- Loot history: increased LOOT_FOUND/ASSIGN merge window to 3600s to reduce duplicate “Assigned” lines.
- Boss detection: added Zul'jin to Zul'Aman list; added ignore rule for Infinite Timereaver to avoid false Milleniax starts.
- Disenchanter reset: clicking roster “0” on the disenchanter now attempts to reset the last assigned loot (within 10 minutes) and updates the existing loot entry to show `Assigned (Reset -#)` when possible.
- Combat log errors: NormalizeName now handles non-string values, and combat log parsing now skips the extra COMBAT_LOG_EVENT header args when present.
- Combat tracker parsing: added payload heuristic to read damage/heal amounts when CLEU is missing raid flag fields (fixes zero-amount drops).
- Combat tracker parsing: added CLEU layout detection (finds GUID positions) to avoid “Not roster dest” skips when offsets shift.
- Combat tracker heals: subtract overheal from heal amount when available; stores `overheal` on entries for debugging.
- Combat tracker UI: renamed “Spell” column to “Ability” and reduced width by ~1/3; added a tracking enable checkbox (default off, remembers choice).
- Version bump: updated display/version strings to v2.17 and updateSeenVersion to 17.
- Version bump: updated `updates.lua` to version 17.
- Combat tracker options: added “Track damage dealt” (outgoing) and “Combine all damage/heal” toggles.
- Combat tracker table: added inbound/outbound arrow column between Player and Amount.
- Combat tracker combine-all: now aggregates existing log entries retroactively (per player + kind), not just new events.
- Combat tracker log: persisted to saved variables and added a Clear button in the Combat options panel.
- Options panels: added a subtle vertical divider on the left edge for OL separation.
- Combat tracker table: flow column header labeled "Dir".
- Wishlist alerts: announcements/popups now scan all wishlists (not just active) and mark found items across every list.
- Wishlist alerts: chat and popup now include the matching wishlist names for each found item.
- Wishlist layout: nudged column 2 slots left slightly to fit within the inset box.

## Changes / Changelog (1/28/2026)

- Combat options: replaced separate big damage/heal sliders with a single percent slider + live label (applies to damage/heal, incoming/outgoing).
- Combat log filtering: now uses per-encounter max damage/heal to apply the shared slider threshold.
- Combat log healing: outgoing heals are now tracked when "Track healing events" is enabled; outgoing heals use the -> flow arrow.
- Combat log healing: outgoing heal rows show `+X (Y)` with `(Y)` as overheal in darker green.
- Combat tracker table: columns reordered to Time | Source | Target | Amount | Ability (no per-row arrows).
- Combat tracker table: source/target names truncate with ellipsis (players capped at 12 chars; NPCs capped longer).
- Combat tracker list: in All view, incoming heals from roster sources are suppressed to avoid duplicate (self-heals and NPC->player heals still show).
- Combat tracker: resurrection entries now try to include revived health amount when available (shows "Revived +X").
- Combat tracker: combine-all now sums overheal values, and overheal display can be toggled on/off.
- Combat tracker options: "Show healing", "Show damage dealt", and "Show damage received" now control visibility (data still tracks).
- Combat tracker: added broadcast popout (channel dropdown + 0–9 slider + whisper target) and right-click Send To menu.
- Update tab: added selectable URL box + quick steps header for a cleaner layout.
- Info bars: added a tab-aware second footer bar with per-tab summary segments.

## OL Parity Recheck (1/27/2026)

### Looks On-Track (Parity Achieved)

- Top tab strip styling and spacing match OL (dark strip + divider, tab buttons sized).
- Shared table headers/stripes/spacing look consistent across tabs.
- Options panel visuals align with OL AceGUI look (200x24 controls, heading lines, label-above).
- Tooltips use right-side popout style and wrap to panel width.
- Paired buttons (notes, etc.) match OL layout.
- Wishlist keeps Wowhead-style layout while overall frame matches OL tone.

### Recheck/Adjust (Parity Validation Needed)

- Combat tab: flow-arrow column alignment and overall width vs OL.
- Options panels: verify no label clipping on Overview/Loot/History/Combat.
- Footer bars: confirm centered sync text and left/right status alignment on all tabs.
- Scrollbars: confirm always-visible scrollbars on all scroll frames (Wishlist options, History, Loot, Debug log box).
- Buttons: confirm remaining buttons use `UIPanelButtonTemplate2` (especially History/Wishlist).
- Combat log section text in plan should reflect tracking toggle (now OFF by default).
- Combat options: confirm the shared big-number slider matches OL spacing and label style.

### Optional OL Polish

- Tighten column widths in Loot/History/Combat for closer OL proportions.
- Add subtle divider between left table and right options on non-Wishlist tabs (if desired).
- Align top padding so headers sit on a consistent baseline across tabs.

---

## UI Wording Review (1/28/2026)

### Obvious Changes Applied

- Overview: clearer toggle labels (e.g. "Show present players", "Pause point gains", "Local-only mode") with tighter tooltips.
- Sync: "Request sync" wording plus clearer tooltip.
- Sync: inline note now appears when Local-only mode is enabled.
- Keybinds: clarified to "main window" and "mini tracker".
- Loot: reset labels now state "to 0"; quality filter and notes tooltips are clearer.
- History: show/hide labels now start with "Show"; clearer quality filter tooltip.
- Combat: updated toggle/tooltips for show/hide logic, combine options, and broadcast panel.
- Wishlist: "Disable popup alert" label; sound tooltip wording improved.
- Wishlist: added tooltips for announce + popup toggles.
- Combat tracker: filter tooltip now says "combat tracker"; roster sort tooltip tightened.
- Settings (legacy): section caption shortened; local-only label aligned with main options wording.

### Non-Obvious Suggestions (Consider)

- Use consistent nouns for items vs entries across all tooltips (continue tightening any remaining “list/row” wording you spot).

---

## Info Bar Expansion (Implemented 1/28/2026)

Goal: add tab-aware info density without clutter. Provide up to 6 short, glanceable metrics per tab while keeping OL-style footer readability.

- Added Info Bar 2 per tab (same inset style + left/center/right segments).
- Bar 2 lives in extra frame height below Bar 1, keeping content size unchanged.
- Bar 1 remains global: access/local-only, sync source + last sync, tracking/disenchanter.
- Per-tab Bar 2 segments:
  - Overview: Top points holder(s) with ties as "+N", sort mode, present-only toggle.
  - Loot: Min quality, reset mode, entries count.
  - History: Filter summary, entries count.
  - Combat: Filter, show toggles (H/D/R), threshold + overheal status.
  - Wishlist: Active list name, active sub-tab, alerts status (Chat/Popup).
