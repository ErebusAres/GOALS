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
- Options headers/labels now use shared styling helpers (consistent gold header bar + light label color).
- Dropdowns aligned to a consistent left edge (all options panel dropdowns use the same offset).
- Spacing tightened across the right panels.
- Options panel buttons standardized to ~156px wide and 18px high; small action buttons sized proportionally.
- Options panel checkboxes now use smaller 18px boxes; labels aligned consistently.
- Options section headers now include a subtle bottom divider line (OL-like separation).
- Added per-tab **footer info bar** at the bottom of each tab (status/permissions + tracking/disenchanter summary).

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
**High priority:** rework right-side options to match OL’s **AceGUI** styling (Heading lines + full-width controls).

Key findings from OL code:
- OL options panel is built via AceGUI in `workspace/Ouro_Loot/lootgui.lua` under `BuildMainDisplay` (look for `--- Main ---`).
- OL section headers are AceGUI **Heading** widgets (`AceGUIWidget-Heading.lua`), which draw **centered text with left/right lines** using `Interface\\Tooltips\\UI-Tooltip-Border` and texcoord `0.81–0.94, 0.5–1`.
- OL controls use AceGUI widgets:
  - Button: `UIPanelButtonTemplate2` (defaults to 200x24) in `AceGUIWidget-Button.lua`.
  - CheckBox: size 24, `GameFontHighlight` label (white) in `AceGUIWidget-CheckBox.lua`.
  - DropDown: label **above** dropdown; dropdown offset `(-15,-18)`; label gold `SetLabel` in `AceGUIWidget-DropDown.lua`.

**Options to match OL exactly:**
1) **Integrate AceGUI-3.0** from OL and use AceGUI widgets for the right panel only.
   - Pros: matches OL look precisely.
   - Cons: adds libs + changes how options are laid out (SimpleGroup/Flow layout).
2) **Mimic AceGUI styles in our custom UI** (recommended if avoiding new deps).
   - Implement Heading style in our options panels using the tooltip-border line textures and centered text.
   - Use `UIPanelButtonTemplate2`, 200x24 size for action buttons.
   - Increase checkbox size to 24, label font `GameFontHighlight` (white).
   - Switch dropdowns to **label-above-control** layout and update spacing to match AceGUI’s `SetLabel` positioning.

**Specific tasks (if mimicking AceGUI):**
- Replace current black section bars with AceGUI-style **Heading** (centered gold text + left/right lines).
- Standardize option controls to 200px width, 24px height (match AceGUI defaults).
- Move labels above dropdowns and edit boxes (left aligned, gold).
- Increase checkbox size to 24 with `UI-CheckBox-Up/Check/Highlight` textures (white label).
- Match vertical spacing to AceGUI Flow defaults (roughly 6–8px between controls).

**Validate**
- Options panel widths/spacing on Overview/Loot/History/Combat.
- Dropdown/checkbox/button visuals align with OL.
- Footer info bars do not overlap content and show correct status text.

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

"I’m working on GOALS (WoW 3.3.5a) UI to match Ouro Loot. We already moved main tabs to a top OL-style bar (OptionsFrameTabButtonTemplate + dark strip + divider). Wishlist sub-tabs also have a dark strip + divider. Tables use the shared widget with 16px headers, tighter spacing, stripes, and alignment to scrollbar edge. Right panels are 220px, section headers are 16px with gold text, labels are GameFontHighlightSmall, checkbox labels smaller/lighter, dropdowns now show WoW box again with gold text. Loot table merges Found+Assign rows, supports notes (auto + manual), right-click assign works, long loot names truncate with ..., tooltips only on item name column. Combat log is always on (toggle removed); filter moved into combat options. Overview actions align under Actions column; admin controls hidden for non-admins; Ask for sync moved into Sync section; Sync Seen hidden. Wishlist layout stays Wowhead-style with options scroll. 

Please continue matching the **options panel** to OL exactly. In OL, the right panel uses AceGUI: `BuildMainDisplay` in `workspace/Ouro_Loot/lootgui.lua` with Heading widgets (`AceGUIWidget-Heading.lua`) and default AceGUI Button/CheckBox/DropDown styling. You can either integrate AceGUI-3.0 widgets (preferred for 1:1 match) or mimic their visuals: heading with left/right tooltip-border lines and centered gold text, buttons using `UIPanelButtonTemplate2` at 200x24, checkboxes at 24px with white labels, and dropdown labels above controls (AceGUI-style `SetLabel`). Use the OL libs for reference and port textures/spacing as needed. Provide updates to `Goals/gui.lua` and **always update `Goals/OuroLoot_UI_Plan.md` with changes, remaining work, and the next prompt for continuity**."

---

## Open Questions
- Final desired widths for key columns (Loot/History/Combat)?
- Should any admin-only controls remain visible but disabled for regular users?
- Do we want to reintroduce a Settings tab later, or keep all options on their respective tabs?
