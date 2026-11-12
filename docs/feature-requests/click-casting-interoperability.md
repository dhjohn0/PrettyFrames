# Feature request: Click-casting interoperability

## Summary

Make PrettyFrames Action Profiles coexist predictably with Forever's native click-casting facilities and common external click-casting addons, without adding another dense binding system.

## User problem

PrettyFrames supports secure mouse bindings through Action Profiles, but compatibility with native or external click-casting systems is not documented. Users need to know which system owns a binding and must not discover conflicts during combat.

## Goals

- Test native click-casting and the most relevant Forever-compatible external addon.
- Prevent two systems from silently claiming the same mouse combination.
- Preserve PrettyFrames' simple default target/menu bindings.
- Support users who prefer an external system without forcing them to recreate bindings in PrettyFrames.

## Configuration design

Keep the existing **Actions...** entry in each applicable frame context menu. Add a compact **Binding Source** control at the top of the Actions window:

- **PrettyFrames Actions** — default.
- **External / Native Click Casting** — PrettyFrames does not apply custom action attributes to that category.

Show a short detected-status line beneath it, for example:

- `Native click casting detected.`
- `Clique detected.`
- `No external click-casting provider detected.`

Do not add provider-specific settings, duplicated spell books, keyboard assignment grids, or automatic imports. Configuration remains in the selected provider's own UI.

If secure coexistence allows both systems safely, prefer a single option named **Allow External Click Casting** and document precedence. Only use the mutually exclusive source choice if testing shows that coexistence is ambiguous.

## Proposed behavior

- Apply the source choice per action category: Player, Pet, Target, Target-of-Target, Focus, Party, and Raid.
- When external/native ownership is selected, clear only PrettyFrames-owned secure attributes.
- Never remove or rewrite attributes owned by another addon/provider.
- Detect conflicts outside combat and present a clear warning naming the button combination.
- Defer source changes requested during combat.
- Provide a non-executing binding test similar to the existing `/pf test action` path.

## Architecture

- Add provider detection and ownership rules to `Actions.lua`, not individual frame modules.
- Store `bindingSource` alongside each action-category assignment.
- Track exactly which secure attributes PrettyFrames owns so cleanup is surgical.
- Keep provider-specific integration behind small adapters if native and external APIs differ.

## Non-goals

- Rebuilding Clique or the native click-casting configuration UI.
- Importing external bindings into Action Profiles.
- General keyboard keybinding management in the first release.
- Spell recommendation, smart-cast, or automated target selection.

## Acceptance criteria

- PrettyFrames default target/menu actions continue to work unchanged.
- Selecting external/native ownership prevents PrettyFrames from claiming that category's click bindings.
- Switching sources outside combat cleans up only PrettyFrames-owned attributes.
- Combat lockdown never produces taint or partially applied bindings.
- Party and Raid frames work with the chosen supported provider in a live group.
- The Actions window communicates the active source without requiring documentation.

