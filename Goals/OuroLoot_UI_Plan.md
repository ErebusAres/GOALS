# Ouro Loot UI Alignment Plan (GOALS)

Goal: reshape GOALS UI to match Ouro Loot’s layout and readability while **keeping the current titlebar (minimize + close)** and **keeping class‑colored names**. No code changes yet—this is a design/implementation plan.

---

## References to Review (OL)
- `workspace/Ouro_Loot/lootgui.lua` — main display layout, table styling, right‑side options panel.
- `workspace/Ouro_Loot/text_tabs.lua` — tab placement and styling.
- `workspace/Ouro_Loot/AceGUIWidget-lib-st.lua` — scrolling table widget behaviors.

---

## Target Layout (High‑Level)
**Frame**
- Keep GOALS titlebar (existing `GoalsFrameTemplate` + minimize/close).
- Main content area becomes a **centered primary table** with **right options column** (like OL).
- Use OL sizing as a reference; slightly larger than current GOALS is OK, but avoid a massive window.

**Tabs**
- Tabs aligned along the top inside the content area (just below title bar).
- Tab placement to mirror OL (left-to-right).
- Keep GOALS tab structure but remove the Settings tab by relocating settings to relevant pages.

**Table**
- Clean, grid-like table with header bar and column labels.
- Alternating row stripes, subtle separators.
- Clear vertical scroll with left/right padding.
- Keep class colors for player names.
- Scrollbar always visible (disabled/greyed when not needed) where appropriate.
- Keep the main table panel layout consistent across tabs (header placement, column title row, scroll area).

**Options Sidebar**
- Right-hand panel with grouped sections (header + controls).
- Leave space for scroll wheel (avoid overlapping scroll bar area).
- Clean, centered control alignment for readability.
- Prefer short labels; use hover tooltips for longer descriptions.
- If settings overflow vertically, the right panel should become scrollable and keep a visible scrollbar.
- Use a consistent right-panel layout template across tabs (spacing, section headers, button/dropdown sizing).

---

## Proposed Tab Order (Draft)
- Overview
- Loot
- History
- Wishlist
- Combat
- Update (if shown)
- Help
- Dev/Debug (if Dev mode)

Notes:
- Settings tab removed. Relevant settings migrate to their tab’s right-side panel.
- If needed, add an “Advanced” sub‑section on the **right panel** rather than a standalone Settings tab.
- Dev/Debug should be combined behind Dev mode so normal players never see it.

---

## Settings Migration Map (Draft)
**Overview tab (right panel)**
- Minimap toggle
- Auto-minimize in combat
- Local only (sync off) — optional here or under History/Sync
- Sync status label (existing)

**Loot tab (right panel)**
- Loot method dropdown (existing)
- Loot history filters
- Reset rules + minimum quality (existing controls moved)

**History tab (right panel)**
- History filters (existing)
- History loot min quality

**Wishlist tab (right panel or subpanel)**
- Wishlist announce settings
- Popup sound/disable
- Template text
Notes:
- Wishlist layout should remain mostly the same as today.
- It has the most options; plan for a scrollable right panel and/or collapsible sections to manage density.

**Combat tab (right panel)**
- Enable Combat Log Tracking
- Enable Healing Tracking
- Filter controls (dropdown aligned with title bar)

**Data Management / Admin**
- Clear points/players/history/all
- Mini tracker controls
- Save tables/auto-load/combined
- Sudo dev & sync request

Placement note: if these feel “global,” consider a dedicated **right panel “Maintenance” section** on the Overview tab or a small “Advanced” tab.

---

## Table Styling Targets (from OL look & feel)
- **Header bar**: darker background strip with column titles.
- **Row height**: consistent 18–20 px, minimal padding.
- **Alternating stripes**: low‑alpha stripe like OL.
- **Font**: keep GameFontHighlightSmall for row text, GameFontNormal for headers.
- **Column widths**: fixed widths for predictable scan patterns.
- **Scroll behavior**: table rows clipped; keep scroll bar right side with inset margin.
- **Scrollbar visibility**: always present (greyed out when no scrolling).
- **Headers/labels/buttons/dropdowns**: standardize to match OL visual density and spacing.

---

## UI Component Plan
1) **Shared Table Widget**
   - A helper to build: header bar, column labels, row pool, stripe effect, and FauxScrollFrame.
   - Each tab can define columns and row renderers.

2) **Right Panel Template**
    - A consistent inset on the right with section headers and controls.
    - Optionally include a thin vertical divider.
    - Dedicated vertical spacing and a margin for scrollbar.
    - Short labels + tooltip helper (for “explain more” text).

3) **Tabs Bar**
   - Relocate existing tab creation to match OL style.
   - Keep `help` pinned right if desired; otherwise inline with other tabs.

4) **Section Titles**
   - Replace generic inset headers with OL‑like header strips (flat bar with text).
   - Reuse existing `applySectionHeader` but adjust spacing and color for OL‑like feel.

---

## Access & Visibility Rules (Draft)
- Dev/Debug combined into a single hidden tab shown only when Dev mode is enabled.
- Keep current loot‑master vs raid‑member logic, but review for:
  - “Raid helper” access (assistant/raid officers) to distribute loot.
  - Clear visual gating of controls (disabled state, tooltip explaining why).

---

## Loot Notes Feature (Draft)
Add a Notes column/field similar to OL:
- Allow adding a short note per loot assignment (e.g., “Disenchanting”).
- Store author + timestamp with the note.
- Tooltip for truncated notes:
  - Line 1: full note (wrapped)
  - Line 2: `Author: <player>`
  - Line 3: `<HH:MM:SS, DD:MM:YYYY>`

---

## Implementation Steps (Phase Plan)
**Phase 1 — Layout scaffolding**
- Add reusable helpers: `CreateTableWidget`, `CreateOptionsPanel`, `CreateSectionHeader`.
- Add a tooltip helper for compact labels.
- Add mock layout to one tab (e.g., History) to validate alignment.

**Phase 2 — Tab-by-tab refactor**
- Overview: table + right panel.
- Loot: table + right panel (move loot options here).
- History: table + right panel (move filters here).
- Wishlist: adopt OL-like table + right options (retain sub-tabs if needed).
- Combat: table + right panel (tracking + filters).

**Phase 3 — Settings migration**
- Remove Settings tab.
- Move all Settings controls into the appropriate tab panels.
- Update `UI:Refresh()` to point to new control locations.

**Phase 4 — Polish**
- Spacing, alignment, and visual adjustments to match OL.
- Confirm scroll bars don’t overlap the right panel.
- Confirm class colors and item link colors remain visible.
- Add Loot Notes column and tooltip behavior.

---

## Testing Checklist
- All tabs render without overlap at default 760x520.
- Table headers align with rows.
- Scroll bars are visible and not overlapping the right panel.
- Scrollbars remain visible (greyed out) when content fits.
- Tooltips show for any compact labels and are not clipped.
- Loot notes can be added/edited and tooltip shows author + timestamp.
- Dev/Debug tab hidden for non‑dev users.
- Options panels are readable and centered.
- Class‑colored player names preserved.
- Settings previously in Settings tab still work and persist.

---

## Open Questions / Decisions Needed
- Which tab should host “Data Management/Admin” actions?
- Do we keep the Help tab pinned right or inline?
- Should Wishlist keep its internal sub‑tabs or be simplified?
