# Errors / Fix Notes

Quick reference of bugs encountered and how they were fixed.

## About / Info (quick reference)
GOALS is a WoW 3.3.5a (Wrath) addon for raid loot/points management with wishlist tracking.
Client build: 12340.
Lua version: 5.1 (WoW 3.3.5a uses Lua 5.1).
Core features include point tracking, loot history, wishlist slots with gem/enchant support, required token tracking, announcements/popups, and sync between players (roster/points only, not wishlists).
Repository: https://github.com/ErebusAres/GOALS/
Author: ErebusAres (Discord: erebusares).

## Wishlist / UI
- Lua 5.1 syntax error: `...: '=' expected near 'continue'`.
  - Fix: remove `continue` usage (Lua 5.1 doesn't support it).
  - File: Core.lua.
- Delete wishlist popup used stale list id, so deleting a newly created list failed (especially names with " 1").
  - Fix: pass list id into StaticPopup data and read it in OnAccept.
  - File: gui.lua (GOALS_DELETE_WISHLIST popup).
- StaticPopup error: `StaticPopup.lua:3072 bad argument #2 to 'SetFormattedText' (string expected, got nil)`.
  - Fix: ensure delete popup uses a valid list name via list id lookup; no nil text args.
  - File: gui.lua (GOALS_DELETE_WISHLIST popup).
- Wishlist enchant tooltip showed only "Enchant ###".
  - Fix: resolve spellId via GetSpellLink/GetSpellInfo and show spell tooltip, fallback to plain text.
  - Files: Core.lua (GetEnchantInfoById / CacheEnchantByEntry), gui.lua (enchant tooltip).
- Import/export box cleared long text or multi-line entries.
  - Fix: remove aggressive wrap/normalize stripping, keep raw text, avoid text truncation.
  - File: gui.lua (wishlist import/export edit box).
- UI template error: `CreateFrame(): Couldn't find inherited node "ScrollingEditBoxTemplate"`.
  - Fix: avoid ScrollingEditBoxTemplate on 3.3.5a; use ScrollFrame + EditBox setup.
  - File: gui.lua (wishlist import/export box).
- Import/export box sizing issues (1-line edit area, selection highlight overflows).
  - Fix: adjust EditBox height/anchors to fill frame; use scroll child + padding.
  - File: gui.lua (wishlist import/export box).
- Socket row render:
  - Filled sockets were hiding gem icons.
  - Fix: show socket frame only for empty sockets, gem icon uses overlay layer; fallback to GetItemIcon.
  - File: gui.lua (wishlist gem button rendering).
- Wishlist layout adjustments:
  - Two-column labels capped at 2 lines with "...", gems positioned under label; bottom row uses matching font size.
  - File: gui.lua (wishlist slot layout).
- Help button error: `<string>:"<unnamed>:OnMouseDown":1: attempt to concatenate a nil value`.
  - Fix: ensure button label/id is defined before concatenating tooltip/help text.
  - File: gui.lua (wishlist help button).
- Help/wishlist tab selection error: `gui.lua:1643 attempt to call method 'SetShown' (a nil value)`.
  - Fix: guard against nil sub-tab frames before toggling visibility.
  - File: gui.lua (selectWishlistTab).
- Socket picker creation error: `UIPanelTemplates.lua:255 attempt to concatenate a nil value`.
  - Fix: ensure UIPanelTemplates have a non-nil frame name when using templates.
  - File: gui.lua (createSocketBlock / socket picker rows).
- Socket picker update error: `UIPanelTemplates.lua:171 attempt to concatenate local 'frameName' (a nil value)`.
  - Fix: ensure template widgets have names or avoid template calls needing frameName.
  - File: gui.lua (UpdateWishlistSocketPickerResults).
- Wishlist layout error: `gui.lua:5223 attempt to perform arithmetic on global 'nameOffset' (a nil value)`.
  - Fix: store and reuse `self.wishlistNameOffset` instead of global.
  - File: gui.lua (wishlist slot layout).

## Sync / Points
- Dev client was awarding boss +1 locally, then also receiving master sync.
  - Fix: only sync master awards boss kill points; non-master receives via sync.
  - File: Core.lua (AwardBossKill).
- Auto-sync: roster/points should update without relying on +/ - points.
  - Fix: sync master sends SYNC_POINTS on a timer (60s).
  - Files: Core.lua (StartAutoSyncPush), comm.lua (SendPointsSync).
- Sync timestamp label:
  - Fix: update "Last sync" time on any inbound sync message type, not just SYNC_POINTS.
  - File: comm.lua (HandleMessage).
- Loot master should control "disable point tracking" and others should see status:
  - Fix: show checkbox only to loot master/sync master; others see label with green/red state.
  - File: gui.lua (Overview header).

## Wishlist Announce / Tokens
- Wishlist announcements didn't trigger on synced loot.
  - Fix: call HandleWishlistLoot in ApplyLootAssignment/ApplyLootReset for incoming sync.
  - File: Core.lua.
- Armor token reset not applying points on client:
  - Fix: ApplyLootReset handles setting points to 0 on synced reset.
  - File: Core.lua.
- Wishlists should not sync between players:
  - Fix: removed SYNC_WISHLIST send/receive.
  - File: comm.lua.

## Keybindings
- Keybindings not appearing in options.
  - Fix: rename file to lowercase bindings.xml and include in .toc; add binding header labels.
  - Files: bindings.xml, Goals.toc, Core.lua/loc.lua.
