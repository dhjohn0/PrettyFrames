# Feature request: Class-resource display

## Summary

Ensure that replacing Blizzard Player and Target frames never removes an actionable class resource. Add a theme-aware class-resource display that automatically selects the correct resource for the current character.

## User problem

PrettyFrames displays primary power but does not currently provide dedicated secondary-resource widgets. Depending on the class and Forever UI behavior, hiding Blizzard frames may also hide combo points or another class mechanic.

## Goals

- Audit every playable Forever class and identify resources supplied by suppressed Blizzard frames.
- Show the relevant resource automatically, with no setup required.
- Use protected/secret-safe display paths where required.
- Give themes control over visual geometry without requiring per-theme runtime branches.
- Provide a convincing test-mode preview for the current class.

## Configuration design

Put one option in the **Player Frame** context menu:

- **Class Resource: Automatic / Hidden**

`Automatic` is the default. Do not initially expose per-resource colors, spacing, orientation, individual point sizes, or arbitrary anchors.

If later testing demonstrates a genuine placement need, add one secondary choice:

- **Attach To: Player / Target**

Only show that choice for classes whose resource conventionally relates to the target. The default remains theme-defined.

## Proposed behavior

- Create a small number of reusable point/bar primitives rather than a separate implementation for each class.
- Treat Forever Soul Shards as a carried item count: one enlarged jewel with the exact count, rather than a fixed row of points.
- Show the equipped Hunter ammunition count on a dedicated arrowhead marker.
- Hide the widget when the current class has no applicable resource.
- Update on class-resource, target, specialization, vehicle, and world-entry changes supported by Forever.
- When a resource is target-dependent, clear it immediately when the target becomes invalid.
- Test mode shows a representative partial state rather than a full resource bar. `/pf test resource` can select or cycle through Combo Points, six-jewel spacing, Soul Shards, ammunition, Totems, secondary Mana, and the compound Druid Combo-plus-Mana state without changing characters.
- Continuous secondary-resource bars show a centered `current / maximum` value when those values are safe to format. Their unlocked right-click menu offers Independent Positioning, with dragging enabled while independent.
- Disabling PrettyFrames unit-frame replacement must not affect Blizzard's resource widgets.

## Architecture

- Add a focused `ClassResources.lua` runtime module.
- Define resource geometry beneath each theme's unit-frame layout.
- Store only the user's visibility choice in `frameSettings.player`.
- Keep resource discovery and event routing out of `PlayerFrame.lua` where practical.

## Non-goals

- Arbitrary resource-widget construction.
- Per-point textures, colors, animations, or fonts in user settings.
- Replacing unrelated cooldown or proc displays.
- Supporting resources that Forever does not expose to addons.

## Acceptance criteria

- No supported class loses a class resource when Blizzard unit frames are replaced.
- Automatic mode requires no configuration after install.
- Hidden mode persists in the active profile.
- Resource updates work across target changes, combat transitions, reloads, and profile changes.
- All themes provide valid geometry and a test preview.
- No protected-value comparison or formatting errors occur in restricted combat.

