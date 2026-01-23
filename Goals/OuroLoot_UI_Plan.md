# Ouro Loot UI Alignment Plan (GOALS)

Goal: reshape GOALS UI to match Ouro Loot’s layout and readability while **keeping the current titlebar (minimize + close)** and **keeping class‑colored names**.

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
- Right panels reduced to **220px** to give the main table more width (closer to OL proportions).
- Section header bars reduced to 16px with gold header text.
- Labels in option panels are now `GameFontHighlightSmall` for tighter look.
- Checkbox labels standardized: smaller font, lighter color, consistent left spacing.
- Dropdowns now show the WoW dropdown box again (soft alpha), gold-tinted text; options panel dropdowns set to ~156px to align with buttons.
- Spacing tightened across the right panels.
- Options panel buttons standardized to ~156px wide and 18px high; small action buttons sized proportionally.

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
- Admin/dev controls hidden for non‑admin users (not just disabled).
- “Ask for sync” moved into Sync section (visible to all).
- “Sync Seen” button hidden for now.

### Wishlist
- Wishlist layout **kept Wowhead-style** (not a table).
- Options sub-tab is now a scroll frame with always-visible scrollbar.

---

## Remaining Work / To-Do

### Options Panel UI Matching (Primary Tabs)
- Continue tightening spacing where needed (labels, dropdowns, checkbox groups).
- Validate options panel widths/spacing on Overview/Loot/History/Combat.
- Ensure dropdowns/buttons align vertically in neat columns with consistent 156px width.

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
- Main content area doesn’t overlap tab bar or titlebar.
- Table headers align with rows; columns line up with scrollbar edge.
- Right panel sections have consistent header height + label spacing.
- Dropdowns show WoW frame with gold text.
- Checkbox labels are readable and aligned.
- Loot item truncation works with `...` and tooltip still opens.
- Found loot assignment via right-click works as before.
- Combat log always active and combat tab always visible.
- Wishlist Options tab scrolls with scrollbar always visible.
- Dev/Admin buttons hidden for non-admin players.

---

## Prompt (for next session)

Use this prompt to continue in a new chat:

"I’m working on GOALS (WoW 3.3.5a) UI to match Ouro Loot. We already moved main tabs to a top OL-style bar (OptionsFrameTabButtonTemplate + dark strip + divider). Wishlist sub-tabs also have a dark strip + divider. Tables use the shared widget with 16px headers, tighter spacing, stripes, and alignment to scrollbar edge. Right panels are 220px, section headers are 16px with gold text, labels are GameFontHighlightSmall, checkbox labels smaller/lighter, dropdowns now show WoW box again with gold text. Loot table merges Found+Assign rows, supports notes (auto + manual), right-click assign works, long loot names truncate with ..., tooltips only on item name column. Combat log is always on (toggle removed); filter moved into combat options. Overview actions align under Actions column; admin controls hidden for non-admins; Ask for sync moved into Sync section; Sync Seen hidden. Wishlist layout stays Wowhead-style with options scroll. 

Please continue matching the options sections and overall OL look: standardize dropdown/button sizing, spacing/alignment in right panels for Overview/Loot/History/Combat, and further tune table column widths if needed. Provide updates to `Goals/gui.lua` and **always update `Goals/OuroLoot_UI_Plan.md` with changes, remaining work, and the next prompt for continuity**."

---

## Open Questions
- Final desired widths for key columns (Loot/History/Combat)?
- Should any admin-only controls remain visible but disabled for regular users?
- Do we want to reintroduce a Settings tab later, or keep all options on their respective tabs?
