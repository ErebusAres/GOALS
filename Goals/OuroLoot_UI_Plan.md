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
- Combat log is **always enabled** right now.
- Toggle removed; combat tab always visible.
- Filter moved into options panel (top section).

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
- Wishlist Options tab scrolls with scrollbar always visible.
- Dev/Admin buttons hidden for non-admin players.

---

## Prompt (for next session)

Use this prompt to continue in a new chat:

"I'm working on GOALS (WoW 3.3.5a) UI to match Ouro Loot. Main tabs are a top OL-style bar (OptionsFrameTabButtonTemplate + dark strip + divider), wishlist sub-tabs match. Tables use the shared widget with 16px headers, tighter spacing, stripes, and alignment to scrollbar edge. Right option panels now mimic AceGUI: 240px wide, Heading-style section headers with tooltip-border lines and centered gold text; controls are 200x24; dropdown/edit box labels are above controls (gold); dropdown text is white; checkboxes are 24px with white GameFontHighlight labels; buttons use UIPanelButtonTemplate2 and are stacked vertically. Loot table merges Found+Assign rows, notes system + UI, right-click assign works, long loot names truncate with ..., tooltip only on item name column. Combat log always on; filter in combat options. Overview actions align under Actions column; admin controls hidden for non-admins; Ask for sync in Sync section; Sync Seen hidden. Wishlist layout stays Wowhead-style with options scroll.

Please validate the new options panel spacing/alignment (Overview/Loot/History/Combat), check for clipping with the 240px width and label-above layout, confirm scrollbars don't overlap, and then continue any remaining OL-alignment tweaks (table column widths, separators, etc). Update `Goals/gui.lua` and **always update `Goals/OuroLoot_UI_Plan.md` with changes, remaining work, and the next prompt for continuity**."

---

## Open Questions
- Final desired widths for key columns (Loot/History/Combat)?
- Should any admin-only controls remain visible but disabled for regular users?
- Do we want to reintroduce a Settings tab later, or keep all options on their respective tabs?
