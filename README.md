# PrettyFrames

An ornate unit-frame replacement designed for **World of Warcraft: Forever** (`Interface 16001`). It uses live `PlayerModel` widgets for 3D portraits and secure unit buttons for normal click targeting.

## Included

- A single continuous Player+Pet frame with independent live 3D portraits and unit data
- Target, target-of-target, and focus frames with live 3D portraits; Target and Focus include optional portrait threat glows, Aggro/Raw percentage text, and pet-threat inclusion
- An opt-in five-slot Boss group using the exact Target-of-Target artwork and geometry, with shared movement, growth, scale, visibility, cast-bar, and action settings
- Shared Boss aura modes for important encounter mechanics, player-owned debuffs, or a hidden display, with configurable left/right placement
- Four portrait party frames
- Forty compact raid frames in five vine-linked columns, with bronze, leather, and a fixed alternating eleven-frame perimeter foliage layout
- A 125% physical Raid baseline represented as 100% in the Raid scale control for improved readability
- Leather-and-bronze Raid group headers with autumn leaf clusters above all five columns
- Class/reaction-colored health and power bars
- Per-frame health and power display controls for text format, bar color, background opacity, and bar sparks
- Automatic one-bar artwork for units with no resource, including Forever NPCs whose 0/0 power maximum is protected
- Configurable melee/ranged distance fading and out-of-range opacity for Boss, Party, Raid, and individual unit frames
- Unlocked-frame right-click menus with persistent Always Show, Always Hide, and horizontal-flip controls
- Shared Action Profiles with secure Target, Focus, Menu, spell, item, and Blizzard-macro mouse or hover-keyboard bindings
- Drag-and-drop action setup for spellbook spells, action-bar spells/items/macros, bag items, and macros
- Drag-to-reorder action bindings with spell rank and subtext labels for distinguishing similarly named spells
- All eight Shift/Ctrl/Alt combinations on Left, Right, Middle, Mouse 4–31, and captured keyboard keys
- Persistent 60–160% scale sliders in every frame, Party-group, and Raid-group right-click menu
- Independent Pet visibility controls; Always Hide elements remain visible at half opacity while frames are unlocked
- Compact 3D-portrait Party frames with integrated level, class, health, power, and group-role medallions
- Optional linked Player/Target positioning, horizontally mirrored across the screen with top edges aligned
- Persistent one-bar override for Forever NPCs whose protected power maximum is ambiguous
- Left-aligned full character names, including Forever surnames when available
- Per-frame Max Buffs and Max Debuffs sliders (0–40) for Player, Target, and Focus aura lists, plus Party buff limits
- Native radial cooldown sweeps and countdown numbers on displayed auras
- Optional Masque support for skinning aura icons, borders, cooldowns, and stack counts
- Player, Target, and Focus aura rows with player-owned debuff priority, six-slot/three-slot wrapping that grows upward, orientation-aware placement, and preview samples
- Party buff rows that continue horizontally in their selected left/right direction
- Balanced, Healer, and Minimal Party display profiles with one combat-safe important debuff, optional dispel priority and maintenance effects, clipped heal/absorb prediction, and portrait-ring threat warnings
- Pet buff and debuff rows with independent left/right growth, limits, cooldowns, and countdowns
- Live health and power numbers, including protected values displayed through native widget formatting
- Configurable Raid health text with missing-health, percentage, current/max, and hidden modes, plus an optional incoming-heal-adjusted deficit
- One combat-safe Raid debuff slot with independent dispellable and primary boss/role controls, stacks, duration, and a native dispel-type border
- A compact Raid maintenance strip for two player-cast HoTs or shields and one external role/defensive effect
- Secret-safe live Raid prediction for personal and external incoming heals, damage absorbs, and heal absorbs
- Clipped cyan heal prediction, striped absorbs, inset health fills, larger health text and maintenance icons, and readable faded-state status overlays
- Balanced, Healer, Tank, and Minimal Raid display profiles with separate dispellable-debuff controls; Tank keeps mechanic and heal-absorb warnings while removing maintenance and incoming-heal clutter
- Consistent raid-target markers across Player, Pet, Target, Focus, Target-of-Target, Party, Raid, and world nameplate frames
- Layered Raid presentation with distinct target edges and threat glows, clearer unavailable-state fading, roles, raid markers, leadership, transient group statuses, and important debuffs
- Independent Party and Raid visibility controls for status text, role and leadership icons, target highlights, and raid markers
- One group-level Raid move-handle menu for Always Show, Always Hide, and replacing Party frames with the compact Raid layout
- Independent Party move-handle options to use portrait Party frames in raids of five or fewer and hide them in larger raid groups
- A fixed-width, single-piece autumn frame skin that joins the large leaf-covered portrait ring, leather nameplate, status-bar borders, and corner ornament into one continuous design
- Compact leafless bronze-and-leather level and class medallions
- Fully mirrored target and target-of-target layouts
- Circularly masked near-black snakeskin behind live portraits
- Higher-frequency foliage relief on health and power bars
- Opaque full-slot backing behind partially filled health and power bars
- A fixed-size unified Player+Pet skin whose shared rails, vines, and lower border are one indivisible image, preventing overlay seams or image drift
- Safe handling of Forever's protected/secret combat values
- Movable groups, global scaling, test mode, and optional Blizzard-frame suppression
- Selectable themes whose art, texture crops, frame sizes, and art-aligned positions live together in human-editable configuration
- Named configuration profiles with per-character selection, create, copy, rename, reset, and delete controls

## Commands

- `/pf` or `/pf options` opens the integrated Blizzard Options panel
- `/pf lock` toggles between locked and editable frames
- `/pf edit` is an alias for `/pf lock`
- `/pf testedit` or `/pf edittest` toggles edit and test modes together; if only one is active, both are turned off
- `/pf scale 0.6-1.6`
- `/pf test`
- `/pf test resource [combo|combo6|shards|ammo|totems|mana|druid|next|auto]` previews a specific class-resource layout without changing characters; `druid` shows Target Combo Points and Player Mana together
- `/pf test action <frame> <modifier> <button>` safely previews the matching action without executing it
- `/pf blizzard on|off`
- `/pf reset`

The addon hides Blizzard unit/group frames by default. Boss replacement remains opt-in pending live Forever encounter testing. Use `/pf blizzard on` to keep replaced Blizzard frames visible.

## Notes

Frame movement and test-mode changes are intentionally blocked during combat. Raid frames omit 3D models to avoid maintaining forty live model widgets during large encounters.

Action bindings are prepared outside combat and executed by the unit frames' secure templates. Keyboard bindings temporarily override their normal key only while the pointer is over a PrettyFrames unit frame, and the captured modifier combination is shown separately in the binding row. Party and Raid unit reassignment and sorting are deferred during combat, so the displayed frame and its protected `unit` attribute cannot diverge. Blizzard macros keep their own targeting rules; use `@mouseover`, `@target`, or other macro conditionals when desired. Macro identity is validated by slot/name/body, and a missing or ambiguous macro is left unbound instead of risking execution of a different macro.

## Source layout

- `Core.lua`, `Database.lua`, and `Runtime.lua` initialize the addon, saved settings, and event routing.
- `Actions.lua` owns action profiles, validation, cursor parsing, and protected attributes; `ActionsUI.lua` owns the editor.
- `FrameBehaviors.lua` and the `*Behavior.lua` modules provide reusable frame settings and displays, including movement, visibility, health/power presentation, range fading, threat, indicators, and context-menu behavior.
- `FrameSettings.lua` coordinates saved frame settings, locking, and the shared behavior modules.
- `FrameWidgets.lua`, `Auras.lua`, `CastBars.lua`, and `UnitFrameData.lua` provide shared frame components and data updates.
- `OrnateUnitFrames.lua`, `PlayerFrame.lua`, `BossFrames.lua`, `PartyFrames.lua`, and `RaidFrames.lua` own the individual frame families; `RaidFrameOptions.lua` owns Party and Raid display profiles plus Raid configuration menus.
- `FrameController.lua` constructs the frame families after login.
- `Nameplates.lua` and `Options.lua` remain independent entry points for their respective features.
- `Themes.lua` is the small theme registry. Verdant, Moonlight, and Orgrimmar each provide an editable asset map and layout configuration; Orgrimmar is the independent-geometry example.

## Creating a theme

The complete agent-ready specification is in [`Themes/THEME_AUTHORING_GUIDE.md`](Themes/THEME_AUTHORING_GUIDE.md).

1. Choose either the derivative workflow or the independent-geometry workflow in the authoring guide, then create a plainly named folder under `Themes`.
2. Keep runtime `.tga` files in `Assets` and editable source images in `Sources`. Rename them freely, then update the readable keys in the theme's asset map or art presets.
3. Put reusable art and geometry in `Globals.lua`, frame selections and sparse overrides in `Frames.lua`, and identity in the final `Theme.lua`. Point tables use `{ point, relativePoint, x, y }`; texture crops use `{ left, right, top, bottom }`.
4. Add the new theme files to `PrettyFrames.toc` before `Database.lua`, loading `Theme.lua` last. Existing single-file themes remain compatible.
5. Reload the UI and choose the theme under PrettyFrames > Appearance and layout.

Theme selection is saved in the active profile and requires a UI reload because secure unit frames and their dimensions are constructed at login.
