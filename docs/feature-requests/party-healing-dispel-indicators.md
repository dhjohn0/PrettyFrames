# Feature request: Party healing and dispel indicators

## Summary

Bring the most important Raid healing signals to portrait Party frames without turning PrettyFrames into a general-purpose indicator editor.

## User problem

The Raid layout provides prioritized debuffs, dispel information, maintenance effects, heal prediction, absorbs, and threat. The portrait Party layout is visually rich but provides less actionable healer feedback.

## Goals

- Make portrait Party frames viable for dungeon and small-group healing.
- Reuse established Raid filtering and prediction behavior.
- Preserve portraits, names, and ornamental artwork.
- Offer a few understandable display profiles instead of dozens of independent settings.

## Configuration design

Add **Party Display Profile** to the **Party Frames** context menu:

- **Balanced** — default; prominent important debuff, incoming heals/absorbs, compact threat warning.
- **Healer** — adds dispellable priority and maintenance effects.
- **Minimal** — important debuff only; no prediction or maintenance strip.

Below the profile selector, add one **Indicators** submenu for users who want to adjust the preset:

- Important Debuff
- Prioritize Dispellable Debuffs
- Incoming Heals & Absorbs
- Maintenance Effects
- Threat Warning

Changing an individual toggle changes the displayed profile label to `Custom`, mirroring Raid behavior. Do not expose arbitrary indicator positions, spell-ID lists, glow styles, or multiple configurable icon grids.

## Proposed behavior

- Show one primary debuff with stack count, duration, and dispel-type treatment.
- Reuse Blizzard's combat-safe aura prioritization and permitted native containers.
- Add clipped incoming-heal, absorb, and heal-absorb segments to Party health bars.
- Show a compact maintenance strip only in the Healer profile.
- Use the existing ornamental accent/glow language for threat rather than adding a generic icon.
- Test mode should demonstrate each signal across the four Party slots.

## Architecture

- Generalize Raid prediction helpers to accept both Raid and Party frames.
- Reuse the existing aura-container construction functions with Party-specific geometry.
- Add `displayProfile` and the resolved indicator booleans beneath `partyLayout`.
- Put Party profile definitions near the Raid profile definitions, or in a shared `GroupFrameOptions.lua` if that produces a clean boundary.
- Theme layouts define icon, strip, and prediction geometry.

## Non-goals

- A Grid-style arbitrary status/indicator mapping system.
- Encounter-specific custom spell databases maintained by PrettyFrames.
- Multiple simultaneous large debuff icons.
- Automated dispelling or spell recommendations.

## Acceptance criteria

- Balanced, Healer, and Minimal profiles apply immediately and persist.
- Individual changes mark the profile Custom.
- Dispellable and important-debuff filtering remains valid in restricted combat.
- Predictions never extend outside the health bar or cover required text.
- Every theme has readable indicator geometry.
- Test mode previews all supported indicator categories without a live group.

