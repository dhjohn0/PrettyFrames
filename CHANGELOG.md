# Changelog

All notable changes to PrettyFrames are documented here.

## 1.0.1 - 2026-11-15

### Added

- Added drag handles for reordering bindings in the Action Profiles editor.
- Added spell rank and subtext labels to action slots and spell tooltips, making similarly named spell variants easier to distinguish.

### Fixed

- Fixed keyboard binding capture sometimes continuing to consume keyboard input after a key was selected or capture ended.
- Fixed low-threat portrait glows being reset to a fixed opacity instead of brightening as threat rises.

## 1.0.0 - 2026-11-14

### Added

- Added per-frame health text modes, health color choices, background opacity, and bar-spark controls.
- Added power text modes, power color choices, background opacity, bar-spark controls, and manual one-bar layouts where supported.
- Added configurable melee or ranged distance checks and out-of-range opacity for Boss, Party, Raid, and individual unit frames.
- Added Party and Raid controls for status text, role and leadership icons, target highlights, and raid markers.

### Improved

- Made yellow portrait threat warnings appear earlier so rising threat is easier to notice before aggro.
- Improved action-binding conflict reporting and compatibility with other click-casting providers.
- Made frame option behavior more consistent across individual, Boss, Party, Raid, and nameplate frames.

## 0.31.0 - 2026-11-12

### Added

- Ornate Player, Pet, Target, Target-of-Target, Focus, Boss, Party, Raid, and nameplate frames for World of Warcraft: Forever.
- Verdant, Moonlight, and Orgrimmar themes with selectable layouts and compiled in-game artwork.
- Secure mouse and hover-key action profiles with spell, item, macro, targeting, focus, and menu actions.
- Configurable aura, cast-bar, class-resource, threat, raid-target, healing-prediction, and absorb displays.
- Named configuration profiles, frame movement, per-frame scaling and visibility, test mode, and Blizzard-frame suppression.
- Optional Masque and Clique interoperability.

### Packaging

- Added a validated CurseForge release archive workflow.
