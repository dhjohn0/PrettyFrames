# Feature request: Boss frames

## Implementation status

Implemented as an opt-in five-slot `boss1`–`boss5` group. Live Forever encounter validation is still required before enabling replacement by default.

## Summary

Give PrettyFrames an explicit, reliable boss-frame policy: either provide themed boss frames or deliberately preserve Blizzard's boss frames. The preferred implementation is a compact PrettyFrames boss group.

## User problem

PrettyFrames replaces the primary unit-frame families but has no boss frames. Users should never discover during an encounter that a required unit frame was hidden, duplicated, or visually inconsistent.

## Goals

- Confirm which boss unit tokens and encounters exist in Forever.
- Provide readable boss health, power, cast, target-marker, and status information.
- Keep Blizzard boss frames available whenever PrettyFrames boss replacement is disabled.
- Make the group easy to position and configure as one unit.

## Configuration design

Add **Replace Blizzard Boss Frames** to the existing **Features** options page. Because this changes protected frame construction/suppression, it may require reload and should use the existing reload notice.

When enabled, expose a single **Boss Frames** move handle with this context menu:

- Scale
- Always Show / Always Hide
- Grow: Down / Up
- Cast Bars: Shown / Hidden

Defaults: replacement enabled only after the implementation has completed encounter testing, automatic visibility, grow down, cast bars shown. Avoid per-boss-slot settings.

## Proposed behavior

- Use one compact themed layout repeated for the supported boss-unit count.
- Show health, power when meaningful, name, level/classification, target marker, and cast bar.
- Use test mode to populate all supported slots with representative bosses and casts.
- Register secure unit attributes before combat and use unit watches/state drivers for visibility.
- Suppress Blizzard boss frames only when PrettyFrames boss replacement is enabled and successfully initialized.
- If Forever does not expose stable boss unit tokens, ship the explicit preservation policy instead of a partial replacement.

## Architecture

- Add `BossFrames.lua` and a `bossFrames` theme-layout section.
- Reuse compact ornate widgets and `CreateUnitCastBar` where appropriate.
- Add a group anchor to `PF.frames` and integrate it with global scale, lock, test mode, and feature replacement.
- Keep boss event routing targeted; avoid refreshing all unit frames for boss-only events.

## Non-goals

- Encounter timers or boss-mod functionality.
- Main-tank, main-assist, arena, or enemy-roster frames.
- Per-encounter layouts.
- Per-slot styling or positioning.

## Acceptance criteria

- Required boss units remain visible in every tested Forever encounter.
- Disabling replacement leaves Blizzard boss frames untouched.
- No duplicate Blizzard/PrettyFrames boss frames appear when replacement is enabled.
- Cast bars correctly distinguish interruptible and non-interruptible casts.
- Test mode accurately previews the complete group.
- Visibility and protected attributes remain correct across combat and encounter transitions.

