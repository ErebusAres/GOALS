# Issue Tracker

- Romulo and Julianne failed to end correctly:
  - Status: Fixed. Pair revive now completes on the first simultaneous kill.

- Sharing build button worked in party/raid but not solo/target. Note: Test target was opposite faction
  - Status: Updated. Enemy targets now prompt for a manual target instead of failing; cross-faction whispers still aren't supported.

- If you kill a boss, and the raid/party roster changes, it messes with the assign loot functions from found loot.
  - Status: Needs repro. I added itemId-based cleanup and master-looter sync fallback, but I still need a concrete case of the “out of range” message to target.

- Assigned loot isn't properly being synced to be removed from found loot list, lingering even after it's been assigned.
  - Status: Fixed (needs verify). Master-looter sync fallback and itemId-based cleanup added.

- Consider token turn-ins / quest rewards for resets.
  - Status: Added. Token turn-ins no longer reset points (only the token does), and added a “Reset only for loot in window” toggle to avoid quest reward resets.

- The announcement options were removed during a recent update.
  - Status: Fixed. Announcement checkbox and sound toggle are anchored again.

- Wishlist help icon overlaps the tabs; move it to the top-right corner under the close button.
  - Status: Fixed. Help icon is anchored under the main close button.

- Check for potential memory leaks, or anything that would cause slowdown extra pc memory usage and report your finding.
  - Status: Reviewed. No obvious leaks; history grows unbounded and wishlist announce cache can grow over long sessions.

- We also need to add the ability to pop out History Options, like Loot Options, but on this page will be Filter Options for the History tab, adding new history (where required) and including filtering for the following:
  - Status: Fixed. Added History Options popout, filters, min-quality dropdown, and history events for builds + wishlist actions.
  - Filters: Points assigned/reset, build sent/accepted, wishlist found/claimed, wishlist add/remove/socket/enchant, loot assigned/found.

- When exporting a wishlist build the Neck, Relic, Ring1, and Ring2 are displayed without their `|N` or `|R`
  - Status: Fixed. Export display now escapes pipes and import accepts `||`-escaped strings.

- When exporting can we sort the export like...
  - Status: Fixed. Export order is now deterministic and `RANGED` is accepted as `RELIC` on import.
  - Assumption: Neck is placed right after Head; confirm if you want a different order.
