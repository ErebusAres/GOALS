# GOALS - Gen2

## Short Description

GOALS is a DKP-style boss, loot, and wishlist tracker for Wrath of the Lich King 3.3.5a. It logs boss kills, point awards, loot assignments, and wishlist drops, with optional build imports and raid sync.

## Installation

1. Download or clone this repository.
2. Copy the `Goals` folder into `World of Warcraft/Interface/AddOns/`.
3. Confirm the folder structure is `Interface/AddOns/Goals/Goals.toc`.
4. Enable the addon from the character select AddOns menu.
5. Use `/goals`, or click the minimap button to open the UI in game.

## Long Description

GOALS provides a raid-focused workflow for DKP-style points, loot distribution, and wishlist management. It tracks boss kills and wipes, keeps a detailed history of point changes and loot assignments, and syncs data to your party or raid unless you enable local-only mode.

### Core DKP + Loot Tracking

- Overview tab: roster points, present-only filtering, sorting, manual awards, add/subtract/reset/undo, and "add all present" for fast post-kill rewards.
- Loot tab: set loot method, review loot history, and assign found items with optional point resets (configurable by item quality and type).
- History tab: boss kills, wipes, points, loot assignments, wishlist actions, and sync activity with filters.
- Update tab: shows available updates and download instructions.

### Wishlist System

- Create multiple wishlists and choose the active list.
- Add items by search, by slot, or by importing a build.
- Store enchants, gems, and notes per slot; track required tier tokens automatically.
- Alerts: chat announcements and on-screen wishlist popups when a wishlist item drops.
- Optional DBM integration for wishlist loot detection and boss banner alerts.

### Wishlist Builds and Imports

- Build library supports Classic, TBC, and WotLK tiers with multiple sources.
- Import from:
  - Built-in build library (class/spec/tier filters).
  - Wishlist strings (WL1).
  - Wowhead gear planner links or data strings.
  - AtlasLoot wishlist (if detected).
- Build sharing: send builds to other players via whisper from the Wishlist UI.

### Sync and Permissions

- Sync master is the raid leader (or party leader); others request sync automatically.
- Auto-sync broadcasts points at intervals when you are the sync master.
- Local-only mode disables all addon message traffic.

### UI and Quality-of-Life

- Minimap button and optional floating button to open the UI.
- Mini viewer for quick points during raids; can auto-hide during combat.
- Optional combat log tracker for damage/healing events with filters and combines.

### Slash Commands and Keybinds

- `/goals`, `/dkp`, `/goalsui`: open the main UI.
- `/goals mini`: toggle the mini viewer.
- Keybinds are available for toggling the main UI and mini viewer.
