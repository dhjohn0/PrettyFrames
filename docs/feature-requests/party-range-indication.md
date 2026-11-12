# Feature request: Party range indication

## Summary

Add clear, low-noise range fading to portrait Party frames, matching the safety and visual language already used by Raid frames.

## User problem

Party members currently remain fully opaque regardless of range. Healers and support players cannot quickly distinguish reachable units while using the portrait Party layout.

## Goals

- Fade out-of-range Party frames without obscuring identity or status.
- Reuse the Raid range implementation's secret-safe behavior.
- Avoid frequent expensive updates.
- Make the default useful for every role.

## Configuration design

Add a **Range** submenu to the **Party Frames** group-handle context menu:

- **Fade Out-of-Range Members** — on by default.
- **Out-of-Range Opacity** — three radio choices: `Dim (35%)`, `Readable (55%)`, `Subtle (75%)`.

Default to `Readable (55%)`. Do not expose polling frequency, range spell selection, separate alpha values for every region, or per-party-slot controls.

## Proposed behavior

- Fade the complete presentation consistently: artwork, bars, portrait, text, auras, and connector-adjacent content.
- Offline, phased, and otherwise unavailable states take precedence over ordinary range fading.
- Do not fade while frames are unlocked or in test mode.
- Prefer the most reliable Forever range API available. If a class-specific helpful-spell range can be selected safely, do so internally without user configuration.
- Coalesce updates and use a modest cadence rather than checking every frame every render tick.

## Architecture

- Extract or generalize the current Raid faded-region helper so Party and Raid share alpha rules.
- Save `rangeFade` and `outOfRangeAlpha` under `partyLayout`.
- Apply changes immediately from the Party context menu.
- Keep the updater owned by the Party anchor so it can stop when the group is hidden.

## Non-goals

- Exact yardage display.
- User-selected range spells or items.
- Different range opacity for individual Party members.
- Range fading for enemy nameplates as part of this request.

## Acceptance criteria

- Party members visibly fade when out of range and recover promptly when in range.
- Secret range values pass only through permitted display sinks.
- Offline and out-of-phase states remain visually stronger than range fading.
- Unlock and test modes always show frames at their intended preview opacity.
- The feature can be disabled with two clicks from the Party handle.
- No measurable update churn occurs while Party frames are hidden.

