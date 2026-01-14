# TODO - Wishlist Tab & Gear Planner

## Planning Notes
- Goal: Add a dedicated Wishlist tab with a clean two-column layout, plus support for multiple wishlists per character.
- Keep wishlist display compact (icons + tooltip), while moving detailed controls to the right column or a popout panel.
- C-menu layout reference: slot icons with labels in two vertical columns, plus a bottom row for main hand/off hand/relic; empty state shows slot icons and labels.
- Visual target: match the WoW C-menu paperdoll look/feel as closely as possible (frame art, icon size, label font/placement, spacing, and color treatment) using the provided screenshots as the reference.

## Tasks
- [ ] UI: Add a new "Wishlist" tab and move Settings/Update/Dev-Debug to the right to make space.
- [ ] UI: Implement a two-column layout (left: wishlist/build; right: search, filters, options, actions).
- [ ] UI: Add item icons with hover tooltips; keep left panel minimal/clean.
- [ ] UI: Provide add/remove controls and a clear empty-slot placeholder (slot icon when blank).
- [ ] UX: Add a "C menu"-style slot list/grid to place wishlist items and build out a gear set.
- [ ] Data: Define wishlist schema (itemId, slot, enchantId, gemIds, notes, source) with versioning.
- [ ] Data: Support multiple wishlists per character (create, rename, copy, delete, select active).
- [ ] UI: Add a wishlist manager list with delete-by-name and confirmation.
- [ ] Data: Persist wishlists via the existing character save/load system.
- [ ] Data: Add GOALS-to-GOALS export/import (shareable file/string) for wishlist data.
- [ ] Sync: Implement database sync with server updates; add manual load/save buttons.
- [ ] Search: Add item search with filters (slot, phase/ilvl, stats, source) and result list.
- [ ] Search: Cache item lookups to avoid repeated queries; handle missing item info gracefully.
- [ ] Notifications: Detect looted items that match wishlist entries.
- [ ] Notifications: Add a configurable chat announce (say/party/raid) with message template like "[item] is on my wishlist".
- [ ] Import: Add Wowhead gear planner import (URL + JSON string) for Classic/TBC/Wrath.
- [ ] Import: For TBC, parse gear planner URLs that do not expose a JSON import string.
- [ ] Import: Parse slots, enchants, and socket choices; map to wishlist schema.
- [ ] Import: Provide a validation/report summary (missing items, unknown enchants/gems).
- [ ] QA: Backward compatibility for existing saved data.
- [ ] QA: Edge cases (empty wishlists, missing item icons, item upgrades/duplicates).

## Decisions
- TBC gear planner: no JSON import string spotted; parse from URL if needed.
- Item database: look at addons like Ludwig and Atlas for inspiration.
- Announcements: message is "[item] is Wishlisted"; channel priority raid > party > say; 1-3 items combined per line; 4+ items split into extra lines; announce once.
- Wishlist scope: optionally sync across account.
