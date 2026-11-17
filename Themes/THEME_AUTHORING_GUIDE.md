# PrettyFrames Theme Authoring Guide

## Purpose

This document is the complete bitmap-and-layout integration contract for
creating a PrettyFrames theme. It is intended to be handed to an AI coding/art
agent together with a separate art-direction brief. The art-direction brief
decides appearance; this guide defines file structure, geometry, transparency,
naming, registration, configuration, validation, and integration. It does not
claim that every visual value in PrettyFrames is theme-controlled; the explicit
boundary below defines what “theme complete” means.

The desired outcome is a self-contained theme that:

- appears automatically in the PrettyFrames theme selector;
- changes no unrelated add-on behavior;
- requires no hand-editing after the agent finishes;
- supports portrait-left and reflected frame orientations; two-bar and one-bar modes for Target, Focus, and Target-of-Target; Player-with-Pet and standalone Player modes; and Party, Raid, nameplates, cast bars, indicators, and accents;
- preserves secure-frame behavior and protected World of Warcraft data paths;
- can be reviewed through source PNGs and used in game through runtime TGAs.

This guide deliberately contains no visual style direction. Supply that separately.

## Design freedom and technical references

Treat this guide as the contract. Treat existing themes as examples of one
solution, not as geometry references for an unrelated design. Existing themes
are useful for confirming runtime behavior and schema completeness, but their
silhouettes, opening shapes, proportions, ornament placement, and visual rhythm
are artistic decisions.

In particular:

- Do not use `Themes/Verdant/ART_PROMPTS.md` as input to a new theme. It is historical documentation for that theme only.
- Do not infer required colors, materials, rendering techniques, motifs, ornament density, lighting, or mood from existing assets.
- Reuse an existing theme's PNG masks, widget coordinates, crops, or proportions
  only when the creator explicitly asks for a derivative or family variant.
- Names such as `raidLeavesMaple`, `raidLeavesGolden`, `raidLeavesOak`, `raidLeavesAspen`, `raidTargetClasp`, and `castBarEndCap` are stable API role identifiers. They do not require those depicted objects or any associated appearance.
- Technical words such as “frame,” “accent,” “ornament,” “clasp,” and “glow” describe placement or blending roles, not a required visual vocabulary.

When the art-direction brief conflicts with an existing theme, follow the art
direction. Preserve hard runtime contracts, then express the new composition
through the theme-controlled sizes, crops, and points.

### Three kinds of constraint

Do not confuse these layers:

1. **Hard runtime contracts** are not artistic choices: asset keys, file
   registration, supported modes, texture formats/canvases, secure-frame
   behavior, required live widgets, mirroring semantics, and declarative theme
   data.
2. **Theme-controlled geometry** is design space: logical frame sizes, art
   crops, portrait and bar placement, text/icon anchors, marker placement,
   cast-bar ornaments, connectors, and most attachment offsets. These values
   belong in `Theme.lua` and may differ substantially between themes.
3. **Shared runtime values** are outside the present theme boundary and are
   listed later in this guide. A theme cannot change these without a generic
   schema extension.

Passing the hard contract does not require matching any existing theme's
silhouette or composition. Transparent openings are required where live widgets are placed,
but their shapes and locations follow the new theme's own layout plan.

### Independent-geometry principles

An independent theme should begin with logical rectangles and attachment
relationships, not with an existing bitmap. The most reliable order is:

1. choose each root frame's logical display size;
2. place every live portrait, bar, label, indicator, aura origin, cast bar, and
   attachment in that logical space;
3. choose a source crop whose aspect ratio supports that composition;
4. map the logical rectangles back into source pixels;
5. create neutral geometry worksheets from those mapped rectangles;
6. create or edit artwork against the worksheets;
7. normalize generated art deterministically and re-clear live openings;
8. inspect the final cropped runtime image at its actual display size.

Different frame families do not need to share one visual proportion. Player,
Target/Focus, Target-of-Target, Party, and Raid may each use different crops,
silhouettes, ornament density, and internal rhythm. Share an asset only when
the resulting composition is genuinely compatible. A dedicated compact asset
is preferable to forcing a large frame through unsuitable scaling.

Treat source art, crop, display size, and live-widget points as one geometry
system. A change to any one of them can invalidate the others. In particular,
a circular source opening remains circular only when horizontal and vertical
display scale are equal. The crop/aspect calculations later in this guide are
part of authoring, not post-production cleanup.

Generative image tools are useful painters, not exact geometry solvers. Use a
flat worksheet as the edit target and existing art only as a material/style
reference. After generation, a theme-specific builder should place the result
on the required power-of-two canvas and deterministically restore portrait,
bar, and exterior transparency. Do not rely on prompt wording alone to keep a
live opening exact.

## Minimal information the creator should provide

An agent should need only:

1. The art-direction brief.
2. A display name for the theme. If omitted, derive one from the brief.
3. Optional instructions that the theme should deliberately remain in an
   existing theme family.

The agent should derive the remaining implementation details:

- a lowercase stable theme ID, such as `example_theme`;
- a filesystem-safe folder name, such as `ExampleTheme`;
- readable filenames;
- all source and runtime assets;
- all necessary theme layout values;
- the TOC registration line;
- validation results and an in-game test checklist.

When no family relationship is requested, assume independent composition is
allowed. Keep hard runtime contracts, but design the silhouette, live-widget
openings, crops, sizes, and `Theme.lua` points from the art direction. Use the
derivative workflow only when the creator explicitly asks for a reskin,
variant, or matching family.

## Non-negotiable implementation rules

1. Do not add theme-ID conditionals or one-off runtime branches merely to
   accommodate a theme. Use the asset and layout contracts in `Theme.lua`. If
   the contract cannot represent a legitimate independent composition, add a
   generic, backward-compatible schema field, consume it for every theme, and
   document it here.
2. Do not overwrite another theme. Create a new folder and register a unique ID.
3. Keep all theme files under `Themes/<ThemeName>/`.
4. Keep game-loaded `.tga` files in `Assets/` and editable PNGs in `Sources/`.
5. Keep retired experiments in `Sources/Legacy/`, never in `Assets/`.
6. Preserve structural transparency. Decorative frame art must not paint over
   live portraits, bars, names, icons, or the exterior transparent canvas. The
   native nameplate health slot is the documented exception: it requires a
   nearly opaque neutral-black backing because the Blizzard health fill shrinks
   on damage and would otherwise expose the 3D world.
7. Do not bake live text, unit names, levels, roles, portraits, health/power fills, aura icons, or gameplay-state icons into artwork.
8. Do not create separate left-facing artwork unless a contract explicitly asks for it. PrettyFrames mirrors most art with texture coordinates.
9. Runtime TGAs must be uncompressed 32-bit images with alpha and power-of-two canvases matching their configured contracts.
10. Register every theme file before `Database.lua` in `PrettyFrames.toc`.
11. A theme change requires a UI reload. Do not attempt to rebuild secure frames live.
12. Validate both clean/default settings and existing saved settings. Saved positions and independent cast-bar positions can override theme defaults.
13. Keep every loaded theme file declarative. Use `PF:ExtendTheme(...)` for
    fragments and one final `PF:RegisterTheme(...)` call. Do not add database
    reads, frame creation, events, runtime conditionals, or other side effects.

## Architecture and load order

The theme system has four layers:

1. `Core.lua` creates the shared `PF` add-on table.
2. `Themes.lua` creates the registry and helper functions.
3. Optional theme fragments call `PF:ExtendTheme(id, data)` in TOC order.
4. Each theme's final `Theme.lua` calls `PF:RegisterTheme(id, data)`.
5. Frame modules request legacy data with `PF:ThemeAsset(key)` and
   `PF:ThemeLayout(section)`, or frame-specific data with
   `PF:ThemeFrameAsset(frame, role)` and `PF:ThemeFrameLayout(frame)`.

The relevant registry functions are:

- `PF:RegisterTheme(id, theme)` adds or replaces a registered theme and adds a new ID to the selector order.
- `PF:ExtendTheme(id, fragment)` deep-merges a declarative fragment before the
  final registration call. Arrays such as points, sizes, crops, and colors are
  replaced as complete values; dictionaries merge recursively.
- `PF:GetTheme(id)` returns the requested theme, the saved theme, or the built-in fallback.
- `PF:ThemeAsset(key)` joins the selected theme's `path` with the filename mapped by `assets[key]`.
- `PF:ThemeLayout(section)` returns a stable lazy proxy for a named layout
  section. Field reads and mirrored-cache writes resolve against the currently
  selected theme after database initialization.
- `PF:ThemeFrameAsset(frame, role, fallbackRole)` resolves a role from the
  frame's selected art preset, with an optional legacy asset fallback.
- `PF:ThemeFrameLayout(frame, fallbackSection)` returns the frame's private,
  resolved layout copy, with an optional legacy layout fallback.
- `PF:SetThemePoint(region, relativeTo, point)` applies a standard point tuple.
- `PF:MirrorThemePoint(point)` reflects one canonical point horizontally.
- `PF:ResolveThemePoints(layout, mirrored, ...)` returns canonical points or their automatically reflected equivalents plus sparse overrides.
- `PF:ResolveThemeValues(values, mirrored, corrections)` adds optional mirrored-only deltas to an ordered value list.

Frame modules may retain the proxy returned by `PF:ThemeLayout` while Lua files
load, but they must not capture a concrete theme layout before `ADDON_LOADED`
initializes the database. The proxy prevents the built-in fallback layout from
becoming permanently paired with assets from a later-selected theme. Selecting
a theme still triggers `ReloadUI()` because secure frames and most geometry are
created once, and every theme must still be registered before frame modules
load.

The database validates the saved ID. If a theme was removed or renamed, PrettyFrames falls back to `PF.defaultTheme` rather than failing to load.

## Current theme boundary

The theme contract controls the listed bitmap assets and the layout fields documented below. It does not currently control every visual value in the add-on.

The following remain shared runtime behavior:

- `PF.colors` in `Core.lua`, including shared backdrop and bar fallback colors;
- most font objects, font sizes, text colors, shadows, and justification;
- aura icon crops, borders, spacing rules, and rows-per-line in `Auras.lua`;
- Blizzard-provided portrait masks, role-icon sheets, raid markers, spell icons, custom cast-bar fill/spark textures, and similar shared media;
- Raid prediction, absorb, dispel, threat, availability, and status colors;
- the nameplate target-overlay tint and custom cast-bar state colors;
- move handles, options panels, context menus, and other editing UI;
- the global Raid baseline scale in `PF.RAID_BASE_SCALE`.

Use these completeness terms consistently:

- **Contract-complete theme:** every required asset and layout role in this
  guide is implemented, registered, and validated.
- **Full visual-identity skin:** fonts, shared state colors, Blizzard media,
  editing UI, and other values outside the current boundary are also themed.
  PrettyFrames does not currently promise this level through `Theme.lua` alone.

An art-direction brief may be satisfied entirely through the existing asset/layout contract. If it explicitly requires one of the shared values to vary per theme, do not hard-code a check for the new theme ID and do not change the shared value for every theme. Extend the generic theme schema, add the new field to every existing theme, consume it through `PF:ThemeLayout(...)` or equivalent theme data, and update this guide. That preserves theme isolation and keeps future themes data-driven.

## Required directory structure

```text
Themes/
  ThemeName/
    Globals.lua
    Frames.lua
    Theme.lua
    Assets/
      RuntimeAsset.tga
      ...
    Sources/
      EditableSource.png
      ...
      Legacy/
        RetiredOrIntermediateAsset.png
        ...
```

`Globals.lua` and `Frames.lua` are recommended names, not magic filenames. A
large family may instead use `Player.lua`, `UnitFrames.lua`, `Raid.lua`, and so
on. Load every fragment before `Theme.lua`. Optional theme-specific notes may
be kept beside these files; they are not loaded by the game.

Never place source PNGs in `Assets/`. Never reference `Sources/` from `Theme.lua`.

## Creating and registering the theme

### 1. Create the theme structure

Create a new plainly named theme folder with `Assets/`, `Sources/`,
`Globals.lua`, `Frames.lua`, and `Theme.lua`. An existing theme may be copied
as a schema checklist, but
its numeric layout values are provisional—not recommended defaults. Inventory
every required field, then replace sizes, crops, and points from the new
theme's geometry plan.

Do not copy finished source art, alpha masks, `ART_PROMPTS.md`, `Sources/Legacy/`,
or other historical material for an independent theme. Copying those artifacts
is appropriate only for an explicitly derivative theme. Retain all required
asset roles regardless of workflow.

### 2. Change theme identity

Keep `Theme.lua` small and load it last:

```lua
local _, PF = ...

PF:RegisterTheme("example_theme", {
    name = "Example Theme",
    description = "A short factual description.",
    path = "Interface\\AddOns\\PrettyFrames\\Themes\\ExampleTheme\\Assets\\",
})
```

Store reusable definitions in `Globals.lua`:

```lua
local _, PF = ...

PF:ExtendTheme("example_theme", {
    assets = {
        statusBar = "StatusBar.tga",
        -- Legacy/shared roles remain valid during migration.
    },
    globals = {
        art = {
            largeUnit = {
                unitFrame = "UnitFrame.tga",
                unitFrameOneBar = "UnitFrame-OneBar.tga",
                portraitFrame = "PortraitFrame.tga",
                indicatorFrame = "IndicatorFrame.tga",
                statusBar = "StatusBar.tga",
            },
        },
        layout = {
            largeUnit = {
                targetSize = { 520, 173 },
                focusSize = { 390, 130 },
                -- full/scaled/targetOfTarget geometry continues here.
            },
        },
    },
})
```

Select presets and add only intentional differences in `Frames.lua`:

```lua
local _, PF = ...

PF:ExtendTheme("example_theme", {
    frames = {
        target = {
            art = "largeUnit",
            layout = "largeUnit",
            layoutSection = "unitFrames", -- legacy runtime bridge
        },
        focus = {
            art = "largeUnit",
            layout = {
                use = "largeUnit",
                overrides = { focusSize = { 410, 136 } },
            },
        },
    },
})
```

Each resolved frame receives private copies. Runtime mirror caches or other
derived values therefore cannot modify a global preset or another frame. A
plain string selects a preset; `{ use = "name", overrides = { ... } }` selects
it with sparse overrides. Tuple-like arrays are replaced whole, while keyed
dictionaries merge recursively.

Identity requirements:

- ID: lowercase, stable, unique, and safe as a saved-variable value. Prefer letters, numbers, and underscores.
- `name`: user-facing selector label.
- `description`: brief metadata; it is not currently rendered in the selector.
- `path`: WoW interface path using doubled backslashes in Lua and ending in `\\`.
- Folder name and path capitalization must match.

Do not rename a released ID casually. The ID is stored in `PrettyFramesDB.theme`.

### 3. Register in the TOC

Add the theme beside the other themes and before `Database.lua`:

```text
Core.lua
Themes.lua
Themes\ExampleTheme\Globals.lua
Themes\ExampleTheme\Frames.lua
Themes\ExampleTheme\Theme.lua
Database.lua
```

The selector is built from registration order, so TOC order is selector order.

### 4. Reload and select

Open PrettyFrames options, choose the theme, accept the reload prompt, and verify that the saved theme remains selected after another reload.

## Coordinate and sizing conventions

Unless a field explicitly says otherwise, layout values are logical UI pixels.

### Point tuples

A point tuple is:

```lua
{ point, relativePoint, x, y }
```

It becomes:

```lua
region:SetPoint(point, relativeTo, relativePoint, x, y)
```

The calling module supplies `relativeTo`. For example, a Player portrait point is relative to the Player frame, while a status-text point is relative to its health bar.

- Positive X moves right.
- Negative X moves left.
- Positive Y moves up.
- Negative Y moves down.
- Common anchors are `TOPLEFT`, `TOPRIGHT`, `BOTTOMLEFT`, `BOTTOMRIGHT`, `TOP`, `BOTTOM`, `LEFT`, `RIGHT`, and `CENTER`.

Two point tuples on the same bar normally define its left and right edges. Changing only one edge changes both width and alignment.

### Automatic horizontal reflection

All orientation-aware geometry is authored from the portrait-left orientation. The canonical table is named `points`. When a frame is flipped, PrettyFrames derives its geometry with this exact transformation:

| Canonical value | Reflected value |
| --- | --- |
| `LEFT` | `RIGHT` |
| `RIGHT` | `LEFT` |
| `TOPLEFT` | `TOPRIGHT` |
| `TOPRIGHT` | `TOPLEFT` |
| `BOTTOMLEFT` | `BOTTOMRIGHT` |
| `BOTTOMRIGHT` | `BOTTOMLEFT` |
| `TOP`, `BOTTOM`, `CENTER` | unchanged |
| X offset | sign reversed |
| Y offset | unchanged |

The transformation is applied to both anchors in every point tuple. For example:

```lua
portrait = { "TOPLEFT", "TOPLEFT", 47, -30 }
```

becomes:

```lua
portrait = { "TOPRIGHT", "TOPRIGHT", -47, -30 }
```

Most layouts need no mirrored numbers at all. If exact reflection is technically correct but visually needs a small asymmetric adjustment, add only that role to `mirrorOverrides`:

```lua
points = {
    nameLeft = { "TOPLEFT", "TOPLEFT", 181, -57 },
    nameRight = { "TOPRIGHT", "TOPRIGHT", -169, -57 },
},
mirrorOverrides = {
    nameLeft = { "TOPRIGHT", "TOPRIGHT", -170, -55 },
    nameRight = { "TOPLEFT", "TOPLEFT", 172, -55 },
},
```

An override is the complete final tuple in the reflected orientation; it is not a delta. Its key keeps the canonical role name even when that role lands on the opposite physical edge. Every override key must also exist in `points`. Do not create a full override table merely to restate derived values.

### Screen-position tuples

Default screen positions use five values:

```lua
{ point, "UIParent", relativePoint, x, y }
```

These defaults are copied only when no valid saved position exists. Existing user positions take precedence. To evaluate changed screen defaults, use a clean saved-variable state or reset settings knowingly.

### Attachment model and geometry planning

PrettyFrames does not need a finished-art placement template. Such a template
would encode one theme's composition and encourage accidental derivatives.
`Theme.lua` is the placement system. Before creating art, make a geometry plan
that records each live region's logical rectangle, parent, anchors, and intended
transparent opening.

The important attachment spaces are:

| Layout area | Region being placed | `relativeTo` supplied by runtime |
|---|---|---|
| `screen.positions` | Player, Target, Focus, Party, Raid roots | `UIParent` |
| `widgets` | portrait background and indicator decoration | the live portrait or indicator widget |
| `castBar` | icon, ornament, interrupt glow | the live cast bar |
| `nameplate` | art, level, native health position | Blizzard's health container |
| `nameplate` cast fields | icon and cast ornament | Blizzard's native cast bar |
| `party.points` | portrait, name, bars, level, class, role | the secure Party frame; `status` is relative to its health bar |
| `party.connectorPoint` | connector below a member | the upper Party frame |
| `player.points` | Player portrait, bars, text, indicators | the secure Player frame; `status` is relative to its health bar |
| `player.petPoints.frame` | Pet root | the Player frame |
| `player.petPoints` children | Pet portrait, bar, name, status | the Pet frame; status is relative to Pet health and happiness to Pet portrait |
| `unitFrames.full.points` | Target/Focus widgets | the secure unit frame; `status` is relative to health |
| `unitFrames.targetOfTargetAttach` | Target-of-Target root | Target |
| `unitFrames.targetOfTarget.points` | Target-of-Target widgets | its own frame; `status` is relative to health |
| `unitFrames.targetOfTarget.artCrop` | Target-of-Target artwork only | overrides the shared unit-frame crop for both compact art states |
| `raid` health and marker fields | Raid health and marker | the secure Raid frame |

For every role, record at minimum:

```text
root logical size:
art display size and crop:
live region:
relativeTo:
point tuple(s):
transparent or backed opening:
mirrored behavior:
paired state or shared consumer:
maximum-content clearance:
```

This is a constraint worksheet, not a coordinate preset. Two valid themes may
place the portrait on opposite sides, stack bars vertically or horizontally,
use different negative space, and have unrelated silhouettes while satisfying
the same runtime contract. If the desired composition cannot be represented by
the documented fields, treat that as a schema gap; do not fall back to another
theme's placement merely because it already works.

Do not add universal PNG frame templates with decorative contours or fixed
opening positions. A safe optional diagnostic template would be generated from
the theme being authored and show only neutral rectangles for the root,
portraits, bars, text bounds, icons, and click regions. It must contain no
silhouette, ornament, material, motif, or inherited alpha mask, and it must be
regenerated when `Theme.lua` geometry changes. Until such a generator exists,
the measured worksheet plus in-game edit previews are the authoritative
planning tools. (The current generator produces measurements, not a visual
overlay.)

`Themes/THEME_GEOMETRY_REFERENCE.md` is the generated measured worksheet for
implemented themes. It combines every resolved theme layout leaf with runtime TGA
dimensions, alpha bounds, derived widget rectangles, crop-to-source mappings,
and alpha coverage inside live regions. Regenerate it after changing theme art
or layout data:

```powershell
node .\tools\GenerateThemeGeometryReference.js
```

Use its blank independent-theme table to plan a new composition. Use all
implemented-theme measurements to understand relationships and failure modes,
not as coordinate recommendations. A theme that differs most from the others
is often the more useful proof that a value is a design choice rather than a
contract.

### Texture crops

A crop is:

```lua
{ left, right, top, bottom }
```

Values range from 0 to 1 and are passed to `SetTexCoord`. For an image `W x H`, a crop selecting source pixels `(x1, y1)` through `(x2, y2)` is approximately:

```text
left   = x1 / W
right  = x2 / W
top    = y1 / H
bottom = y2 / H
```

Texture mirroring swaps `left` and `right`; the agent should test canonical and reflected layouts independently.

For a canvas `W x H`, crop `{ l, r, t, b }`, and logical display `Dw x Dh`:

```text
sampled source width  = W * (r - l)
sampled source height = H * (b - t)
horizontal scale      = Dw / sampled source width
vertical scale        = Dh / sampled source height
```

For a source-space portrait opening to display as a circle:

```text
source opening width / source opening height = vertical scale / horizontal scale
```

If the two scales are equal, author a source-space circle. If they differ,
either compensate the source opening deliberately or choose a crop/display
aspect that scales uniformly. Reusing a circular opening from another family
without checking this equation is a common cause of oval portraits.

### Canvas size versus display size

Runtime assets use power-of-two TGA canvases. The whole canvas is not
necessarily displayed. A crop may select a horizontal strip, which is then
scaled to the logical frame size. Choose the crop from the new composition;
do not inherit a vertical band simply because another theme uses it.

As an aspect check, a `1024 x 512` canvas cropped to a `1024 x 342` band and
displayed at `340 x 114` has equal horizontal and vertical scale. A full
`1024 x 512` canvas displayed at `340 x 136` does not: an uncompensated source
circle would become wider on screen. Artwork authored without accounting for
crop and display scaling will be displaced or distorted.

## Asset manifest and contracts

Every active key is required unless the runtime code is deliberately extended. Filenames may differ, but keys are code contracts and should remain unchanged. Historical or object-specific wording in a key identifies its runtime slot, not what the new asset must depict.

A theme may add auxiliary asset roles when an existing generic layout field
selects an asset by key—for example, a second portrait backing with a different
alpha shape. Give the role a descriptive, theme-agnostic name, map it in
`assets`, and reference that role from the corresponding
`portraitBackgroundAsset` field. Do not replace or omit the required roles.

| Asset key | Reference canvas | Runtime use and coupling |
|---|---:|---|
| `statusBar` | 512 x 64 | Shared health/power texture for Player, Pet, Target, Focus, Target-of-Target, Party, and Raid; also used for native nameplate health and cast bars. Custom unit cast bars use a separate Blizzard fill texture. It is stretched by WoW StatusBars to many widths and heights. Author it in strict neutral grayscale because WoW multiplies it by live colors; embedded blue or violet makes red health appear purple. Must remain readable at very small Raid and nameplate sizes. |
| `portraitBackground` | theme-defined; 256 x 256 recommended | Optional alpha-shaped texture behind live portrait models. When present, runtime uses its own alpha instead of applying the shared circular mask. Use it to prevent the 3D world from showing through a non-circular artwork opening; keep it to a dark background texture with no foreground rim or ornament. |
| `portraitFrame` | 256 x 256 | Centered behind portraits at `portraitFrameScale`; circularly masked. Also reused as the background of Party role indicators. Keep important content centered and safe under a circular mask. |
| `indicatorFrame` | 128 x 128 | Overlay ring for class and level indicators. It may be horizontally mirrored. The live icon or level field occupies the center. |
| `castBarEndCap` | 128 x 128 | One isolated left end cap for custom cast bars and their previews. Runtime places it at the left edge of the ornament holder and horizontally flips the same texture at the right edge. The canvas and all space around the cap require alpha. Never include rails, a center ornament, or a second cap. |
| `castBarInterruptGlow` | 1024 x 128 | Additively blended interruptibility signal rendered above the live/preview StatusBar and end caps. It uses the complete ornament-holder dimensions and per-frame ornament extension, with its own `interruptGlowPoint`, `interruptGlowCrop`, and `interruptGlowAlpha`. Prefer an unmistakable exterior halo and cap blooms over thin internal rails that compete with the fill. Avoid opaque plates. |
| `playerFrameWithPet` | 1024 x 512 | Unified Player-and-Pet artwork. Cropped by `player.withPetCrop`, displayed at `player.size[1] x player.withPetHeight`, and horizontally mirrored. Openings must align with Player and Pet widgets together. |
| `playerFrameWithPetHealthOnly` | 1024 x 512 | Optional alternate unified artwork without a Pet-power opening. When supplied alongside Pet power geometry, the Pet right-click menu offers Health + Power and Health Only modes. It uses the same crop and geometry as `playerFrameWithPet`. |
| `unitFrame` | 1024 x 512 | Shared two-bar art for standalone Player, Target, and Focus. Full frames use the same source; Focus scales it to a smaller logical size. Horizontally mirrored. |
| `unitFrameOneBar` | 1024 x 512 | One-bar counterpart used by Target and Focus. Shown automatically when power is absent or when the user forces one-bar mode. Standalone Player reuses `unitFrame` but does not currently swap to this asset. Shared portrait, name, health, level, and class geometry must align with `unitFrame`; the unused lower power region may have a deliberately different transparent silhouette. |
| `targetOfTargetFrame` | 1024 x 512 | Two-bar Target-of-Target art. Uses `unitFrames.targetOfTarget.artCrop` when present, otherwise the shared `unitFrames.artCrop`, and displays at `targetOfTargetSize`. It may be a dedicated compact composition rather than a scaled copy of `unitFrame`. Horizontally mirrored. |
| `targetOfTargetFrameOneBar` | 1024 x 512 | One-bar counterpart to `targetOfTargetFrame`. Preserve canvas, crop, portrait, name, level/class, and health geometry. The power rail and unused lower body may be removed as long as the fixed root rectangle and all shared openings remain compatible. |
| `partyFrame` | 1024 x 512 | Party unit art. Cropped by `party.artCrop`, displayed at `party.size`, and horizontally mirrored. Aligns portrait, name, bars, class, level, and role widgets. |
| `partyConnector` | 128 x 256 | Shared connector sheet. Party uses the full width with vertically offset/repeating samples; Raid samples two narrow strands from it. It must tolerate vertical wrapping and mirrored horizontal sampling without visible seams. |
| `raidFrame` | 1024 x 256 | Raid frame art. With `raid.fullArt = true`, rendered as one complete fixed-aspect texture. Otherwise rendered as fixed left cap, stretchable middle, and fixed right cap; keep that middle stretch-safe and non-stretchable detail inside cap regions. |
| `raidThreatGlow` | 256 x 128 | Additive threat halo centered on a Raid frame and tinted at runtime. Transparent padding is allowed but must agree with `raid.glowSize`. |
| `raidTargetClasp` | 32 x 128 | Target highlight attached to both Raid edges. The right instance is a horizontal mirror of the left. Must work in both orientations. |
| `raidGroupHeader` | 512 x 128 | Scaled to `raid.headerSize` above each Raid group. The live group label is drawn separately over it. Do not bake text into the asset. |
| `raidLeavesMaple` | 256 x 256 | Perimeter accent role A. Displayed at `raid.leavesSize` and optionally flipped horizontally or vertically by `edgeLeaves`. The key name is historical; a new theme may map it to any appropriate technical accent while retaining the key. |
| `raidLeavesGolden` | 256 x 256 | Perimeter accent role B, with the same rendering contract. Its historical name does not prescribe appearance. |
| `raidLeavesOak` | 256 x 256 | Perimeter accent role C, with the same rendering contract. Its historical name does not prescribe appearance. |
| `raidLeavesAspen` | 256 x 256 | Perimeter accent role D, with the same rendering contract. Its historical name does not prescribe appearance. |
| `nameplateFrame` | 1024 x 256 | Scaled to `nameplate.artSize` around Blizzard's native nameplate health container. Reused as an additively blended target glow, so its alpha and silhouette affect both normal and targeted states. The native health slot must retain a nearly opaque neutral-black backing; an actually transparent slot exposes the 3D world as health decreases. |
| `restingIndicator` | 512 x 256 | Player resting marker. Scaled to `player.restingIndicator.size` and anchored to the Player portrait. Must remain legible at its small display size. |
| `classResourcePointFrame` | 128 x 128 | Optional overlay for point resources and runes when `layout.classResources` is present. The center must remain transparent; runtime masks and colors the live fill beneath it. |
| `classResourceBarFrame` | 1024 x 128 | Optional surround for continuous secondary-resource bars. The central channel must remain transparent and align with `classResources.barSize`; ornament dimensions use `barArtSize`. |
| `classResourceTotemFrame` | 128 x 128 | Optional overlay around live totem icons and cooldown sweeps. Keep the icon opening transparent and readable at `totemSize`. |
| `classResourceJewelActive` | 128 x 128 | Grayscale active jewel shared by discrete point resources and tinted by each resource's semantic color at runtime. Keep the visible jewel inside a circular mask. |
| `classResourceJewelEmpty` | 128 x 128 | Neutral grayscale empty jewel shown beneath the active layer. It should remain visibly dull without relying on runtime tint. |
| `classResourceAmmoActive` | 128 x 128 | Bright grayscale Hunter ammunition marker, tinted by runtime. Verdant uses a faceted arrowhead. |
| `classResourceAmmoEmpty` | 128 x 128 | Dark empty-state version of the Hunter ammunition marker. |

### Shared-asset dependency map

The most important reuse relationships are:

```text
statusBar
  -> custom unit health and power bars
  -> Raid health
  -> native nameplate health and cast bars

portraitFrame
  -> portrait backgrounds
  -> Party role-indicator backgrounds

unitFrame
  -> standalone Player
  -> Target
  -> Focus (scaled)

unitFrameOneBar
  -> Target one-bar state
  -> Focus one-bar state (scaled)

partyConnector
  -> Party vertical connectors
  -> Raid connector strands and UV samples

nameplateFrame
  -> normal nameplate art
  -> additive target overlay
```

An agent must review every consumer after changing a shared asset. A change that looks correct in one consumer is not accepted until the others are checked.

## Alpha and opening rules

The visual assets sit over or around live UI objects. Transparent openings are structural, not optional decoration.

The following normally require transparent regions:

- frame exterior outside the intended silhouette;
- portrait/model opening;
- health and power fill openings;
- class/level/role icon centers where applicable;
- cast-bar interior;
- empty space around the exterior of the nameplate health backing;
- one-bar power area when it should disappear;
- empty space around accents, glows, clasps, headers, and resting markers.

Use straight alpha in source PNGs and retain alpha in the TGA. Check edge pixels against both light and dark backgrounds. Hidden RGB in fully transparent pixels can create fringes after scaling, additive blending, or filtering.

Artwork is layered above live bars and portraits. If a supposed opening is opaque, gameplay information is covered even if the source image itself looks complete.

Portrait backing and foreground frame art are separate responsibilities. A
`portraitBackground` should contain only a dark, low-contrast interior texture
cut to the intended backing shape. Do not include a rim, bolts, bone, leaves,
or other foreground ornament in the backing: those details will sit behind the
3D model and become visibly doubled when the foreground frame is drawn.
Increase the holder and background scale when the world shows around their
edges; do not paint over the leak in the foreground art.

After any generated or resampled art pass, re-clear required live regions from
the geometry worksheet in the deterministic builder. Inspect the final runtime
PNG/TGA rather than trusting black-looking pixels in a generation preview to be
transparent. Generated black, faint pseudo-text, and antialiased debris inside
an opening are still opaque gameplay defects.

The nameplate health slot is intentionally different. The live Blizzard fill
shrinks horizontally as health decreases, so the frame asset supplies the dark
empty-health backing. Keep that backing neutral black and nearly opaque. Do not
apply this exception to custom unit, Party, or Raid health openings.

## Theme layout reference

### `layout.screen`

`positions` supplies default anchors for `player`, `target`, `focus`, `party`, and `raid`.

These values do not continuously control frames. `Database.lua` copies them into saved variables, after which user dragging owns the position. Changing a theme does not discard saved positions.

### `layout.widgets`

- `portraitFrameScale`: background-art size divided by logical portrait-holder size.
- `portraitBackgroundScaleX` and `portraitBackgroundScaleY`: optional independent width/height scales for `portraitBackground`; fall back to `portraitFrameScale`.
- `portraitBackgroundYOffset`: optional vertical backing offset as a fraction of portrait-holder size.
- `portraitModelScale`: live 3D model size divided by holder size.
- `portraitModelYOffset`: vertical model offset as a fraction of portrait size.
- `indicatorInnerScale`: live class/level center size divided by indicator size.
- `indicatorInnerYOffset`: vertical center offset as a fraction of indicator size.

These are theme-wide defaults. Frame-family overrides documented below take
precedence where supported. Use the global values for a coherent baseline, but
do not distort one compact or non-circular composition merely to preserve a
single universal portrait setting.

### `layout.castBar`

- `iconExtraSize`: icon width/height added to the cast-bar height.
- `iconPoint`: icon anchor relative to the cast bar.
- `textLeft`: gap between icon and cast text.
- `textRight`: right text inset from the cast bar.
- `ornamentExtraWidth`: total width added around the live bar.
- `ornamentMinHeight`: minimum ornament display height.
- `ornamentAspect`: ornament width divided by computed height when larger than the minimum.
- `ornamentPoint`: decorative-frame anchor relative to the live bar. Its X/Y values move the complete ornament, including its caps.
- `endCapScale`: optional multiplier applied to both square end-cap textures around their fixed outer-edge anchors.
- `endCapBarScale`: optional cap-size multiplier based on the live bar height. It takes precedence over `endCapScale` and keeps the cap-to-bar proportion consistent across differently sized consumers.
- `endCapOffsetX`: shared horizontal adjustment expressed as a fraction of final cap size. Positive values move caps outward; negative values pull them inward.
- `endCapOffsetY`: optional vertical adjustment expressed as a fraction of the final cap size. Positive values move both caps upward while preserving their outer-edge anchors.
- `castEndCapOffsetX`: optional cast-only override for `endCapOffsetX`.
- `castEndCapOffsetY`: optional cast-only vertical adjustment expressed as a fraction of final cap size. It overrides `endCapOffsetY` for casting bars.
- `progressEndCapBarScale`: optional progress-bar-only override for `endCapBarScale`, allowing XP, Pet XP, and reputation caps to retain a different proportion from casting bars.
- `progressEndCapOffsetX`: optional progress-bar-only override for `endCapOffsetX`.
- `interruptGlowPoint`: interrupt-glow anchor relative to the live bar, independent of the decorative frame. Negative Y moves the glow downward.
- `interruptGlowCrop`: UV crop applied to the glow asset.
- `interruptGlowAlpha`: additive opacity used for interruptible live casts and
  unlocked previews. Player previews display the glow for validation even
  though live Player casts suppress the interruptibility signal.
- `interruptGlowColor`: optional RGB vertex tint shared by full-size and
  nameplate interrupt glows.

The custom cast-bar width and height come from the owning frame. This section controls only the shared internal composition.

#### Cast-bar sizing and placement pipeline

Treat the live bar, ornament, and interrupt glow as connected but independently adjustable layers:

1. The owning frame chooses the live bar's `castBarSize`.
   - Player uses `player.pet.castBarSize` because the unified Player/Pet composition determines its span.
   - Target uses `unitFrames.full.castBarSize`.
   - Focus uses `unitFrames.scaled.castBarSize`.
2. The owning frame places the live bar.
   - Target and Focus use `castBarOffset = { x, y }` relative to the owning frame's bottom. Reflection negates X automatically and preserves Y.
   - Player-with-Pet uses `player.withPet.castBar`; standalone Player uses `castBarX` and `castBarY`.
   - A saved independent cast-bar position takes precedence over these defaults.
3. The ornament extension is selected. Target and Focus use their `castBarOrnamentExtraWidth` when present; all other bars fall back to `layout.castBar.ornamentExtraWidth`.
4. Runtime calculates the decoration size:

```text
ornament width  = live bar width + effective ornament extension
ornament height = max(ornamentMinHeight, ornament width / ornamentAspect)
```

`castBarOrnamentExtraWidth` is the total extension across both ends, not an amount added to each end. With centered art, reducing it by `20` pulls each cap inward by approximately `10` pixels without changing the live bar. Changing `castBarSize[1]` changes both the bar and the decoration together.

5. `ornamentPoint` positions the complete decorative frame relative to the live bar. It moves both caps together; it does not change their separation.
6. The interrupt glow receives the same calculated width and height, including the Target/Focus override, then uses `interruptGlowPoint` instead of `ornamentPoint`. This permits small glow-only alignment changes. Positive Y moves up and negative Y moves down.
7. `interruptGlowCrop = { left, right, top, bottom }` changes the UV region sampled from `castBarInterruptGlow`; it does not move or resize the glow frame. For a `1024 x 128` source, `{ 0.13, 0.87, 0, 1 }` removes approximately 133 source pixels from each horizontal side and keeps the full height. Including more transparent source padding generally makes the visible glow appear more inset; cropping away that padding makes it occupy more of the same display rectangle.

Custom live and preview bars share one ornament tree on a sibling overlay frame rather than maintaining parallel copies. Nameplate ornaments likewise remain on sibling overlays, never as textures created directly on a `StatusBar`. Forever clips or remaps direct StatusBar child textures to animated progress, which makes end caps move with the fill. Sharing the custom-bar ornament guarantees identical geometry, frame levels, and visibility behavior between live and test presentation.

Place each end-cap texture inside an explicitly sized child frame and constrain it with `SetAllPoints`. Do not rely on sizing the texture region directly: some Forever clients preserve native texture dimensions, making theme scale or offset changes appear ineffective.

The preview StatusBar renders one frame level above the live bar. When the live
interrupt glow is reused for preview validation, raise it above both the
preview fill and ornament. Restore the corresponding live glow level when
preview mode ends. Additive blending preserves the underlying art while making
the interruptibility state unambiguous.

### `layout.nameplate`

- `artSize`: displayed artwork width and height.
- `artPoint`: artwork anchor relative to Blizzard's health container.
- `levelPoint`: live level-text anchor relative to the health container.
- `healthSize`: native Blizzard health-bar size after skinning.
- `healthPoint`: native health-bar anchor relative to its unchanged container.
- `castYOffset`: vertical displacement applied to Blizzard's native cast bar.
- `castHeight`: explicit native cast-bar height after skinning.
- `castIconExtraSize`: amount by which the compact spell icon exceeds the bar height.
- `castTextSize`: compact cast-label font size.
- `castOrnamentExtraWidth`: compact ornament extension around the native cast bar.
- `castOrnamentMinHeight`: compact ornament minimum height; unlike the full-size
  cast bar this should normally preserve `ornamentAspect` at nameplate width.
- `castOrnamentPoint`: compact ornament anchor relative to the native cast bar.
  Its Y value moves only the ornament; negative values move it downward.
- `castInterruptGlowExtraWidth`: independent compact interrupt-glow extension.
- `castInterruptGlowMinHeight`: independent compact interrupt-glow minimum height.
- `marker`: raid-target marker `size` and `point`, relative to the health container. Anchor the marker's `BOTTOM` above the artwork's `TOP` to keep it clear of the decoration.

The native bar reuses `layout.castBar` ornament geometry and the theme's
`castBarEndCap` and `castBarInterruptGlow` assets while Blizzard continues to
drive its combat state.

The artwork and level text stay anchored to the health container, not the moved health bar. Name text and aura offsets currently remain runtime behavior rather than theme data; verify them visually if `artSize` changes substantially.

### `layout.party`

- `size`: logical width and height of every Party frame.
- `artCrop`: UV crop for `partyFrame`.
- `portraitSize`: logical portrait-holder diameter.
- `portraitBackgroundScaleX`, `portraitBackgroundScaleY`, `portraitBackgroundYOffset`: optional Party-only background sizing and vertical placement behind the live portrait; omitted values retain the shared widget defaults.
- `healthHeight`, `powerHeight`: bar heights.
- `roleSize`, `levelSize`, `classSize`: indicator dimensions.
- `auraBuffY`, `auraDebuffY`: optional compact aura-row offsets from the Party frame top.
- `auraEdgeOverlap`, `auraLeftEdgeOverlap`: optional right- and left-growth overlap with the active Party frame edge.
- `marker`: raid-target marker `size` and `point`, relative to the portrait. Its point is fully theme-controlled; `BOTTOM` to `TOP` places the icon above the decoration.
- `points`: canonical portrait-left art-aligned anchors.
- `mirrorOverrides`: optional sparse final tuples for reflected-only optical corrections. Party currently requires none.
- `frameStep`: vertical distance between Party frame origins. It may be smaller than frame height to create overlap.
- `connectorSize`: connector frame width and height.
- `connectorPoint`: connector anchor relative to the upper Party frame.
- `connectorEndCrop`: amount clipped from the first connector's top and last connector's bottom.
- `connectorSampleStep`: vertical UV offset applied between Party gaps.

The canonical `points` table contains:

- `portrait`;
- `nameLeft`, `nameRight`;
- `healthLeft`, `healthRight`;
- `powerLeft`, `powerRight`;
- `level`, `class`, `role`;
- `status`, relative to the health bar rather than the Party frame.

PrettyFrames reflects the canonical table automatically. Add a sparse override only when visual testing demonstrates that strict reflection does not provide the intended optical alignment.

### `layout.classResources` (optional)

Omitting this section makes PrettyFrames try the corresponding Blizzard class-resource widget. A theme that provides it must map the documented class-resource assets used by its handled primitive kinds.

- `handled`: primitive kinds supplied by the theme: `points`, `itemCount`, `runes`, `bar`, and `totems`.
- `playerPoint`, `targetPoint`: resource-holder anchors relative to the respective unit frame. Target-dependent combo points use `targetPoint`.
- `pointSize`, `pointSpacing`: point/rune socket dimensions and horizontal gap.
- `pointResourceSize`, `pointResourceArcRadius`, `pointResourceArcRadiusX`, `pointResourceArcAngle`, `pointResourceArcSpacing`: optional portrait-arc geometry shared by discrete point resources. The angle is measured in degrees from the portrait's horizontal axis and mirrors with its owning frame. `pointResourceArcRadiusX` optionally creates an elliptical arc; omitting the main radius retains the standard horizontal point row.
- `sixPointArcAngle`: optional center-angle override for point layouts with six or more sockets, allowing the longer arc to clear the level medallion without rotating five-point layouts.
- `pointResourceOffset`: optional `{ x, y }` optical offset applied to point-resource arcs around the Player portrait.
- `comboPointOffset`: optional `{ x, y }` override for the combo-point arc around the Target portrait.
- `itemCountSize`, `itemCountArcAngle`, `itemCountOffset`: geometry for a single counted inventory-resource marker. Forever Warlocks use this for carried Soul Shards and Hunters use it for equipped ammunition; the count is drawn over the marker and has no fixed maximum.
- `itemCountTextOffsetY`: vertical offset for the numeric count inside a counted-resource marker.
- A counted resource may provide a runtime `layoutKey`; matching `<layoutKey>Size`, `<layoutKey>ArcAngle`, and `<layoutKey>Offset` fields override the shared item-count geometry. Verdant uses `ammo*` overrides for its larger Hunter arrowhead.
- `barPoint`: optional secondary-bar center anchor relative to its owning frame. It mirrors automatically unless `barMirrorPoint` supplies an optical override. Without it, bars use `playerPoint`.
- `barSize`: live colored StatusBar dimensions; it may be narrower than the ornamental opening to provide safe fill insets.
- `barArtSize`: independent ornamental surround dimensions.
- `totemArcPositions`: optional list of four `{ x, y }` token centers relative to the owning portrait. X coordinates are authored for the canonical portrait-left layout and mirror automatically with the Player frame.
- `totemPoint`: optional horizontal Totem-holder anchor relative to the owning portrait when `totemArcPositions` is omitted. Without either field, Totems use `playerPoint`.
- `totemSize`, `totemSpacing`, `totemIconInset`: timed icon socket dimensions, horizontal gap, and live-icon inset.
- `showTotemFrame`: set to `false` to omit the decorative `classResourceTotemFrame` overlay while retaining the live icon and cooldown.

Resource colors remain semantic runtime data. Theme art should therefore use neutral materials and preserve transparent openings over every colored fill or icon.

### `layout.player`

Top-level fields:

- `size`: logical Player anchor width and height. The secure Player frame retains this size in every display mode.
- `auraIconSize`: optional Player buff/debuff icon size; defaults to 29.
- `levelSize`, `classSize`: optional Player indicator sizes; default to 40 and 35.
- `withPetHeight`: visual artwork height when unified Player-and-Pet art extends below the secure Player anchor.
- `standaloneHeight`: optional visual artwork height for `unitFrame` when it is shorter than the logical Player anchor. Omit it to use `size[2]`.
- `withPetCrop`: UV crop for `playerFrameWithPet`.
- `standaloneCrop`: UV crop for `unitFrame` when used by Player.
- `marker`: Player raid-target marker `size` and `point`, relative to the portrait. Use a `BOTTOM` to `TOP` anchor with enough Y clearance for the upper frame decoration.

`restingIndicator` contains:

- `size`: displayed marker size;
- `point`: anchor relative to the Player portrait.

`pet` contains:

- `size`: secure Pet-button dimensions;
- `portraitSize`, optional `cameraDistance`, `healthHeight`, `powerHeight`, `happinessSize`; omit `powerHeight` and the corresponding `petPoints.power*` anchors when the theme has no Pet-power opening;
- optional `portraitBackgroundAsset`, `portraitBackgroundScaleX`,
  `portraitBackgroundScaleY`, and `portraitBackgroundYOffset` overrides;
- `auraIconSize`;
- `auraBuffY`, `auraDebuffY`: compact row offsets;
- `auraEdgeOverlap`, `auraLeftEdgeOverlap`: how far aura rows overlap or separate from the frame edge in each growth mode;
- `castBarSize`: Player cast-bar width and height. It is stored here because the unified composition determines its span.
- `castBarOrnamentExtraWidth`: optional horizontal ornament margin beyond the Player cast fill.
- `marker`: Pet raid-target marker `size`, `point`, and optional `mirrorPoint`, relative to the Pet portrait. Treat this as a composition-specific override: unified artwork may require side anchors when Player bars occupy the space above the Pet.

`withPet` controls the unified mode:

- `portraitSize`, `cameraDistance`, `healthHeight`, `powerHeight`;
- optional `portraitBackgroundAsset`, `portraitBackgroundScaleX`,
  `portraitBackgroundScaleY`, and `portraitBackgroundYOffset` overrides;
- `moveLabelY`;
- `castBar = { x, y }`, relative to the Player frame's top;
- `auras = { wideStart, compactStart, upperY, lowerY, upperShift }`;
- `mirrorAuraCorrections`: optional five-value deltas added to `auras` only when reflected;
- `points`, with optional sparse `mirrorOverrides`: Player widget anchors;
- `petPoints`, with optional sparse `petMirrorOverrides`: Pet widget anchors.

Player `points` contain portrait, health/power edges, name edges, level, class, and status. `petPoints` contain the Pet-frame anchor, portrait, health and power edges, name edges, status, and happiness indicator.

`standalone` controls Player when Pet artwork is hidden:

- `portraitSize`, `cameraDistance`, `healthHeight`, `powerHeight`;
- optional `portraitBackgroundAsset`, `portraitBackgroundScaleX`,
  `portraitBackgroundScaleY`, and `portraitBackgroundYOffset` overrides;
- `castBarX`, `castBarY`;
- `hiddenPreviewCastBarY`, used while unlocked when hidden Pet artwork is previewed;
- `auras = { wideStart, compactStart, upperY, lowerY, upperShift }`;
- `mirrorAuraCorrections`: optional reflected-only deltas in the same positional order;
- `points`, with optional sparse `mirrorOverrides`: standalone Player anchors.

For aura arrays, the reflected result at each index is `auras[index] + mirrorAuraCorrections[index]`. Use zero for an unchanged position and keep the arrays contiguous. Unlike point overrides, these entries are deltas because aura growth direction is already handled by runtime logic.

The Player has three effective states that all require testing:

1. unified Player with visible Pet art;
2. standalone Player without Pet art;
3. unlocked hidden-Pet preview, where the unified art remains at reduced opacity to aid configuration.

### `layout.unitFrames`

Top-level fields:

- `targetSize`, `focusSize`, `targetOfTargetSize`;
- `targetOfTargetAttach`: Target-of-Target anchor relative to Target;
- `artCrop`: shared UV crop for standalone Player, Target, and Focus art;
- optional `portraitBackgroundAsset`, `portraitBackgroundScaleX`,
  `portraitBackgroundScaleY`, `portraitBackgroundYOffset`, and
  `portraitCameraDistance`: defaults for Target, Focus, and Target-of-Target
  portraits. The compact Target-of-Target overrides documented below take
  precedence.

`full` controls the full-size Target geometry:

- `auraIconSize`: Target buff/debuff icon size; defaults to `floor(target height * 0.17)` when omitted;
- `healthHeight`, `healthHeightOneBar`, `powerHeight`;
- `castBarSize` is `{ width, height }`; `castBarOffset` is `{ x, y }`, and reflected frames negate its X value automatically; `castBarOrnamentExtraWidth` overrides the shared total ornament extension for Target;
- `marker`: raid-target marker `size` and `point`, relative to the portrait; the theme should anchor its `BOTTOM` above the decoration;
- `auras = { wideStart, compactStart, upperY, lowerY, upperShift }`;
- `mirrorAuraCorrections`: optional reflected-only deltas in the same positional order;
- `points`, with optional sparse `mirrorOverrides`, containing portrait, name edges, level, class, health/power edges, and status. Full Target uses `healthLeft`/`healthRight` in two-bar mode and `healthLeftOneBar`/`healthRightOneBar` in one-bar mode. `healthHeightOneBar` independently controls the one-bar height.

`scaled` controls Focus and any non-full unit frame created by the same runtime module through proportions:

- `auraIconSize`: Focus buff/debuff icon size; defaults to `floor(frame height * 0.17)` when omitted;
- `castBarSize` is `{ width, height }`; `castBarOffset` is `{ x, y }`, and reflected frames negate its X value automatically; `castBarOrnamentExtraWidth` overrides the shared total ornament extension for Focus;
- `marker`: raid-target marker `size` and `point`, relative to the portrait; the theme should anchor its `BOTTOM` above the decoration;
- `portraitX`, `portraitY`;
- `nameY`, `nameLeft`, `nameRight`;
- `nameLeftInset`, `nameRightInset`, `nameYOffset`;
- `mirrorCorrections`, containing optional `nameLeftInset`, `nameRightInset`, and `nameYOffset` deltas for the reflected layout;
- `levelX`, `levelY`;
- `classX`, `classY`;
- `healthY`, `powerY`;
- `healthLeft`, `healthRight`;
- `powerLeft`, `powerRight`;

Fractional fields multiply the logical frame width or height. Negative Y fractions place elements below the frame top. Reflection moves portrait, level, and class to the opposite edge and exchanges the left/right name and bar insets. `mirrorCorrections` then applies only the small name-region differences that strict exchange cannot reproduce. Some scaled aura and status formulas remain in runtime code; changing `focusSize` drastically requires explicit visual review.

`targetOfTarget` contains:

- `artCrop`: optional compact-only UV crop for both Target-of-Target art
  states. When omitted, `unitFrames.artCrop` is used;
- `aurasEnabled`: explicit compact aura support. When true, Max Buffs and Max Debuffs are exposed for Target-of-Target.
- `auraIconSize`: compact aura icon size; defaults to `floor(frame height * 0.17)` when omitted;
- `defaultMaxBuffs`, `defaultMaxDebuffs`: initial display limits. Zero keeps optional auras hidden until enabled by the user.
- `auras` and `mirrorAuraCorrections`: compact aura placement using the same five-value format as full unit frames.
- `portraitSize`, `levelSize`, and `classSize`;
- `healthHeight` and `powerHeight`; legacy themes may use `barHeight` as the
  shared fallback;
- optional `portraitBackgroundScaleX`, `portraitBackgroundScaleY`,
  `portraitBackgroundYOffset`, and `portraitCameraDistance` compact overrides;
- `marker`: raid-target marker `size` and `point`, relative to the portrait. An explicit optical size override is preferred for compact artwork; a proportional full-frame calculation is a useful starting point, not a runtime requirement;
- `points`, with optional sparse `mirrorOverrides`.

The Target-of-Target canonical table contains widget anchors plus both `healthLeft`/`healthRight` for two-bar mode and `healthLeftOneBar`/`healthRightOneBar` for one-bar mode. All reflected roles are derived automatically unless visual testing justifies a sparse `mirrorOverrides` entry.

### `layout.raid`

- `frameSize`: logical Raid unit size.
- `marker`: raid-target marker `size` and `point`, relative to the Raid frame. Compact stacked layouts may keep this inside the frame to avoid covering the preceding row.
- `roleSize`, `rolePoint`: optional role-indicator size and anchor; omitted values retain the shared 20px top-left default.
- `columnStep`: horizontal distance between group origins.
- `rowStep`: vertical distance between members.
- `healthTopLeft`, `healthBottomRight`: opposing health-bar anchors.
- `fullArt`: optional boolean selecting one complete texture instead of the legacy left/middle/right three-slice renderer.
- `artCrop`: Raid-frame UV crop.
- `artCapPixels`: source width of each non-stretched cap.
- `artTextureWidth`: source texture width used to normalize cap UVs.
- `artCapDisplayWidth`: logical display width of each cap.
- `glowSize`: threat-glow display size.
- `targetClaspSize`, `targetClaspOffset`.
- `headerSize`, `headerGap`.
- `leavesSize`: shared display size for every perimeter accent.
- `edgeLeaves`: placement list for perimeter accents.
- connector geometry and sampling fields. `connectorSize` is the clipping window; `connectorStrandSize` controls each texture inside it, so reducing the window can hide artwork that would otherwise extend beneath neighboring frames.

An `edgeLeaves` entry is:

```lua
{ frameIndex, assetKey, anchor, x, y, flipHorizontal, flipVertical }
```

Raid indices run down each eight-member column before moving right:

```text
Group 1:  1-8
Group 2:  9-16
Group 3: 17-24
Group 4: 25-32
Group 5: 33-40
```

An asset key in `edgeLeaves` must exist in the theme's `assets` table.

Connector fields:

- `connectorSize`: secure connector-frame size;
- `connectorYOffset`: connector center relative to the upper member;
- `connectorStrandSize`: displayed size of each sampled strand;
- `connectorLeftX`, `connectorRightX`: strand centers inside the connector;
- `connectorSourceLeft`, `connectorSourceRight`: normalized horizontal UV boundaries in `partyConnector`;
- `connectorSampleHeight`: normalized vertical sample height;
- `connectorSampleStep`: vertical sample offset between Raid rows;
- `connectorRightSampleOffset`: additional offset preventing both strands from sampling the same segment.

When `fullArt` is false or omitted, `raidFrame` is split into left cap,
stretchable middle, and right cap textures. Details placed in the middle source
region will stretch across the variable middle width. When `fullArt` is true,
runtime draws one complete texture across `frameSize`; use this for a
fixed-aspect frame whose edges should never be cut into slices. In full-art
mode, `artCapPixels`, `artTextureWidth`, and `artCapDisplayWidth` are not part
of rendering, though keeping sensible values eases later mode changes.

## One-bar and reflected-orientation dependencies

### One-bar art

Target, Focus, and Target-of-Target crossfade between two-bar and one-bar
artwork based on unit power state and user override. The unified/standalone
Player implementation does not currently use a separate one-bar asset. Paired
files must match in:

- canvas size;
- crop;
- portrait opening;
- name area;
- health area unless its configured one-bar anchor intentionally differs;
- level/class locations;
- transparent exterior registration.

The outer silhouette may differ specifically where the power region disappears.
A one-bar frame may remove the unused lower rail, plate, or stone body and end
directly beneath the health opening. Preserve the root rectangle, crop,
portrait center, upper/name geometry, and health geometry so crossfading does
not shift shared content. Do not leave a large inert panel merely because the
two-bar asset occupied that area.

Force One-Bar Layout is a persistent per-frame user setting, not a theme field.
Test it with a live powered unit, a unit with no power, unlocked/test previews,
and an empty Target/Focus/Target-of-Target frame. The one-bar skin, hidden power
widget, and one-bar health anchors must agree in all four states.

### Mirroring

Large unit, Target-of-Target, Party, indicator, and certain Raid assets are mirrored at runtime by reversing U coordinates. Test for:

- directional symbols or asymmetric details that become semantically wrong;
- unequal transparent padding that shifts the mirrored silhouette;
- canonical anchors or sparse reflected overrides that fail to follow the artwork;
- text-like marks that reverse.

Live text and icons are repositioned, not mirrored. Artwork should leave appropriate openings in both orientations.

## Derivative-theme workflow

Use this workflow only when the creator explicitly requests a reskin, close
variant, or member of an existing theme family. State the source theme and the
intended degree of similarity in the deliverable notes.

1. Copy the source theme's directory structure, configuration, and only the active sources needed as geometry/alpha templates. Exclude historical prompts and legacy work.
2. Change theme ID, name, description, and path.
3. Keep every reference TGA canvas size unchanged.
4. Keep theme layout and crop values unchanged initially.
5. Use each source PNG as a geometry/alpha template.
6. Replace visual pixels while preserving transparent openings and exterior alpha.
7. Produce matching one-bar variants from the same base geometry.
8. Convert/export the final runtime TGAs.
9. Register the theme in the TOC.
10. Run static validation.
11. Select the theme, reload, and run the full visual matrix.
12. Adjust `Theme.lua` only for small optical corrections revealed in game.

This workflow minimizes manual edits because the runtime geometry remains
known-good. It also preserves the source theme's silhouette and composition;
that similarity is an intentional tradeoff, not the normal definition of a new
theme.

## Independent-theme workflow

Use this by default for a new visual concept.

1. Inventory the hard contracts and shared runtime limits; do not begin from an
   existing theme's alpha mask.
2. Sketch the composition and silhouette from the art direction.
3. Decide logical root and display dimensions before generating final art.
4. Complete the attachment/geometry worksheet for every live opening and overlay.
5. Choose crops that suit the new composition within the required runtime
   canvases, and calculate horizontal/vertical scale before deciding portrait
   and indicator source shapes.
6. Author `Theme.lua` sizes, crops, and points together with the art, not afterward.
7. Create neutral family-specific geometry worksheets; do not reuse another
   theme's decorative mask as the worksheet for an independent theme.
8. Normalize all generated or edited sources with a deterministic theme build
   script and re-clear every live opening after resampling.
9. Update canonical `points` and add only genuinely necessary reflected roles to `mirrorOverrides`.
10. Maintain two-bar/one-bar pairing and verify every shared-asset consumer.
11. Re-evaluate aura origins and icon sizes, cast-bar locations and ornament
    extensions, move handles, Party/Raid spacing, connectors, and scaled Focus behavior.
12. Confirm that secure button hit regions still cover intended interactive areas.
13. Inspect normalized runtime art at actual logical display sizes on both
    light and dark backgrounds.
14. Test at 60%, 100%, and 160% scale.
15. Test long names, maximum-level text, class/role icons, full/empty bars,
    auras, dead/offline states, one-bar overrides, and edit previews.

A major geometry redesign can expose values that are still runtime constants rather than theme fields. If a new field is genuinely required:

- add it to the runtime code with a clear name;
- add it to every registered theme;
- keep behavior compatible with existing themes;
- document it here;
- avoid theme-ID conditionals in runtime modules.

## Source generation and conversion

### Source images

Deliver a final editable PNG for every active runtime role. Preserve layers in
an external working format if used, but deliver a flattened PNG in `Sources/`
so future agents have a portable input. If an inherited theme lacks a source
for an active TGA, that is a reference-theme gap, not permission to omit the new
theme's source: reconstruct or derive the role, save the resulting PNG, and
document its deterministic origin.

The current Verdant reference is incomplete as a source set. In particular,
do not expect a directly reusable editable PNG for every cast-bar, resting, or
one-bar production asset. Use the paired two-bar geometry, runtime TGA contract,
and its own documented crop values to reconstruct missing roles when producing
a Verdant-family derivative. Those crop values are not defaults for an
independent theme.

Source images should be generated or edited at sufficient resolution to produce clean downscaled runtime art. Final runtime geometry must be deterministic even if generative tools were used earlier.

### Technical prompt template for an image agent

Append the separate art direction to a technical request shaped like this:

```text
Create <asset role> for a PrettyFrames theme.

Technical contract:
- final source/canvas: <dimensions>;
- transparent background outside the intended silhouette;
- preserve these transparent live-UI openings: <list>;
- no baked text, numbers, portraits, icons, health/power fills, or gameplay state;
- live-region rectangles and attachment plan: <geometry worksheet>;
- derivative geometry reference, only when explicitly requested: <path or none>;
- important content must remain inside: <safe region>;
- asset is horizontally mirrored at runtime: <yes/no>;
- paired asset that must align exactly: <path or none>;
- runtime blend mode: <normal/additive>;
- final deliverables: transparent PNG plus 32-bit alpha TGA.

Art direction:
<separate creator-provided brief>
```

The technical constraints must remain distinct from art direction so an image agent does not trade away geometry for appearance.

### Runtime canvas and export contracts

Editable sources may be larger than runtime assets, but export must be
deterministic. The destination canvas sizes below are compatibility contracts
for the current runtime and validator. They do **not** prescribe where art or
live openings sit inside those canvases. Cropped roles use the corresponding
theme field; an independent theme may select a different crop and matching
layout geometry.

| Runtime roles | Destination canvas | Hard export behavior | Theme-controlled composition |
|---|---:|---|---|
| `statusBar` | `512 x 64` | Fill the canvas; enforce exact neutral grayscale after resampling. | Pattern/detail only; live bar sizes are controlled by consuming layouts. |
| optional `portraitBackground` | theme-defined; `256 x 256` recommended | Preserve alpha and keep the visible interior dark and free of foreground ornament. | Theme-wide `widgets.portraitBackgroundScaleX/Y/YOffset` plus supported Player, Pet, Party, unit-frame, and compact Target-of-Target overrides. |
| `portraitFrame` | `256 x 256` | Preserve alpha; WoW applies the shared circular portrait mask. | Decoration inside the circular footprint and `widgets.portraitFrameScale`. |
| `indicatorFrame` | `128 x 128` | Preserve a readable live center. | Decoration and `widgets.indicatorFrameScale`. |
| `castBarEndCap` | `128 x 128` | Preserve alpha and the square canvas. Store only the left cap; runtime mirrors it for the right. | Useful-alpha footprint, points, aspect, minimum height, and extension fields. |
| `castBarInterruptGlow` | `1024 x 128` | Preserve alpha and the 8:1 canvas. | Useful-alpha footprint, UV crops, points, aspect, minimum height, alpha, and extension fields. |
| `playerFrameWithPet` | `1024 x 512` | Preserve alpha and mirror-safe content. | `player.withPetCrop`, `size`, `withPetHeight`, and all Player/Pet points. |
| `unitFrame`, `unitFrameOneBar` | `1024 x 512` | Paired states share a compatible canvas and transition. | `unitFrames.artCrop`, full/scaled sizes, one-bar heights, and widget points. |
| `targetOfTargetFrame`, `targetOfTargetFrameOneBar` | `1024 x 512` | Paired states share a compatible canvas and stable shared openings; the one-bar lower silhouette may be more compact. | `unitFrames.targetOfTarget.artCrop` when present, otherwise `unitFrames.artCrop`; `targetOfTargetSize`, attachment, portrait/background overrides, bar heights, aura icon size, and widget points. |
| `partyFrame` | `1024 x 512` | Preserve alpha and mirror-safe content. | `party.artCrop`, `size`, connector placement, and widget points. |
| `partyConnector` | `128 x 256` | Must tolerate Party repetition and Raid UV sampling. | Party connector size/point plus Raid sample boundaries, steps, offsets, and strand geometry. |
| `raidFrame` | `1024 x 256` | In sliced mode, fixed caps and the middle must obey stretch boundaries. In `fullArt` mode, preserve one complete fixed-aspect frame. | `raid.fullArt`, `artCrop`, texture/cap fields when sliced, frame size, and health points. |
| `raidThreatGlow` | `256 x 128` | Additive alpha texture. | Useful-alpha padding and `raid.glowSize`. |
| `raidTargetClasp` | `32 x 128` | Must survive horizontal mirroring. | Clasp size and edge placement fields. |
| `raidGroupHeader` | `512 x 128` | Preserve the live-label region. | `raid.headerSize` and group layout. |
| Raid perimeter accents | `256 x 256` | Must survive configured horizontal/vertical flips. | `raid.leavesSize` and each `edgeLeaves` placement tuple. |
| `nameplateFrame` | `1024 x 256` | Preserve exterior alpha and the neutral-black native-health backing. | `nameplate.artSize`, `artPoint`, health geometry, level/marker geometry, and cast fields. |
| `restingIndicator` | `512 x 256` | Preserve alpha and small-scale legibility. | `player.restingIndicator.size` and `point`. |

Verdant and Moonlight currently use legacy vertical bands such as `85/512 ..
426/512` for several unit assets, `18/512 .. 493/512` for unified Player/Pet,
and `32/256 .. 224/256` for Raid. These are documented examples of those
themes' configured crops, not universal art-placement rules.

Resampling can remove small edge pixels and high-frequency detail. Inspect the
normalized runtime image, not only the high-resolution source. In a derivative
workflow, structural alpha masks may be reapplied from the named source theme
after painting; document that operation because it preserves the source
silhouette and can trim generated edges. Do not use that technique for an
independent theme.

### Existing conversion tools

The `tools/` directory contains PowerShell utilities created for specific existing assets:

- `ConvertPartyFrame.ps1`: places a source into a `1024 x 512` canvas with the `85..426` vertical art band and writes a TGA.
- `ConvertRaidFrame.ps1`: normalizes visible source content into the Raid art band, writes PNG and TGA.
- `ConvertCastInterruptGlow.ps1`: performs a specialized extraction for the existing glow source; do not assume its source rectangles fit new generated art.
- `ConvertAccent.ps1`: normalizes visible accent content into a padded `256 x 256` canvas.
- `CleanPartyFrame.ps1` and `RestorePartyLevelRing.ps1`: repair scripts tied to historical geometry; do not use them blindly for a new theme.
- `BuildMoonlightAssets.ps1`: a complete worked example covering all runtime
  roles, structural alpha restoration, grayscale enforcement, specialized
  cast-glow normalization, and uncompressed TGA export. It is theme-specific;
  copy and adapt its declared assumptions rather than pointing another theme at
  Moonlight's sources.
- `BuildOrgrimmarAssets.ps1`: an independent-geometry worked example covering
  multiple frame-family crops, dedicated two-/one-bar Target-of-Target assets,
  deterministic portrait and bar clearing, a complete full-art Raid frame,
  custom portrait backings, and uncompressed TGA export. Its coordinates are
  theme-specific; reuse the workflow, not the numbers or silhouettes.
- `ValidateTheme.ps1`: reusable structural validation for required asset keys,
  TGA headers/dimensions, TOC order, unique IDs, unreferenced TGAs, and missing
  same-name editable sources.
- `GenerateThemeGeometryReference.js`: parses declarative theme data, measures
  runtime TGA alpha, derives live-region rectangles and source-pixel mappings,
  compares themes, and regenerates `Themes/THEME_GEOMETRY_REFERENCE.md`.

Read a script completely before using it. Prefer deterministic conversion, but do not force a theme through a script whose source assumptions do not match.

### Runtime TGA requirements

The current assets use:

- uncompressed true-color TGA;
- 32 bits per pixel;
- alpha channel;
- top-origin orientation;
- power-of-two dimensions.

After conversion, inspect TGA headers and rendered alpha rather than trusting the file extension.

## Static validation

An agent should complete all of these without creator involvement.

Run the canonical structural validator first:

```powershell
& .\tools\ValidateTheme.ps1 -ThemeName ThemeName
```

It fails on missing required keys/files, invalid TGA encoding or dimensions,
duplicate IDs, and incorrect TOC registration order. It warns about
unreferenced TGAs and missing same-name source PNGs. A passing command does not
replace rendered-alpha inspection, Lua semantic review, or the in-game matrix.

### File and registration checks

- Every `Theme.lua` filename exists under its declared `Assets` path.
- Every filename mapped by an asset key exists in `Assets`.
- Every active TGA in `Assets` is intentionally referenced; multiple keys may deliberately share one file.
- No active runtime asset remains in `Sources` only.
- No source PNG is referenced by runtime Lua.
- Every runtime role has a same-name editable PNG or a documented deterministic
  origin and reconstruction procedure.
- The new `Theme.lua` exists in `PrettyFrames.toc` before `Database.lua`.
- The registered ID is unique.
- The declared path uses WoW backslashes and ends with a separator.
- No copied source-theme ID, folder, or asset path remains in the new file.
- The deliverable identifies itself as independent or names the source theme
  from which it is intentionally derived.
- An independent theme has its own geometry worksheet; its masks, crops, and
  point tables are not wholesale copies of an existing theme.

### Image checks

- Canvas dimensions exactly match the current runtime canvas/export contract.
- Every TGA is 32-bit and has alpha.
- Transparent exterior regions are actually transparent.
- Live portrait/bar/icon openings are transparent, except for the documented
  opaque native-nameplate health backing.
- `statusBar` is exact neutral grayscale (`R == G == B`) so runtime tinting is
  color-accurate.
- Paired one-bar/two-bar assets overlay without silhouette drift.
- Mirrored assets remain valid when flipped horizontally.
- Three-slice Raid cap boundaries do not contain seams.
- Connector sampling remains continuous through vertical wrapping.
- Additive assets contain no unintended opaque plate.

### Lua/configuration checks

- Lua syntax parses.
- Delimiters and table nesting balance.
- All required layout sections exist: `screen`, `widgets`, `castBar`, `nameplate`, `party`, `player`, `unitFrames`, and `raid`.
- Every dynamic asset key in `raid.edgeLeaves` exists.
- All point tuples contain four values.
- All screen positions contain five values.
- Crop values are numeric and normally within `0..1`.
- Dimensions are positive.
- Every owning-frame `castBarSize` contains positive width and height values, and every `castBarOffset` contains exactly two numeric values.
- `ornamentAspect` is greater than zero; ornament extensions do not make the calculated display width non-positive.
- `ornamentPoint` and `interruptGlowPoint` are complete four-value point tuples.
- `interruptGlowAlpha` is numeric and within `0..1`.
- Source denominators such as `artTextureWidth` match actual texture dimensions.
- Every canonical `points` table contains all required roles.
- Every `mirrorOverrides` or `petMirrorOverrides` key also exists in its canonical points table, and every override is a complete four-value tuple.
- Aura correction arrays use the same positional meaning as their canonical aura arrays.

### Useful PowerShell checks

List all art outside the theme system:

```powershell
rg --files -g '*.tga' -g '*.png' | Where-Object { $_ -notlike 'Themes\*' }
```

Inspect TGA dimensions and bit depth:

```powershell
Get-ChildItem 'Themes\ThemeName\Assets\*.tga' | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    [pscustomobject]@{
        Name = $_.Name
        Width = $bytes[12] + 256 * $bytes[13]
        Height = $bytes[14] + 256 * $bytes[15]
        BitsPerPixel = $bytes[16]
    }
} | Format-Table -AutoSize
```

Find stale paths or IDs after copying:

```powershell
rg -n 'SourceTheme|source_theme|Themes\\SourceTheme' 'Themes\ThemeName'
```

The agent should interpret findings; these commands are not substitutes for visual inspection.

### What static validation cannot prove

Static validation cannot certify protected-frame behavior, Blizzard
nameplate rendering, live secret-value paths, texture-cache behavior, optical
mirroring, saved-position overrides, or the readability of forty repeated Raid
frames. Record static validation and in-game validation as separate statuses;
never imply that a passing TGA/header check proves the in-game matrix.

## In-game validation matrix

Static checks cannot verify WoW texture rendering, secure-frame behavior, or optical alignment. Complete this matrix after selecting the new theme and reloading.

### Global

- Theme appears in the selector with the correct name.
- Selection survives two reloads.
- No Lua errors occur during login or reload.
- Lock/unlock and preview mode still work.
- Global scale looks correct at 60%, 100%, and 160%.
- Default screen positions are checked with clean settings.
- Existing saved positions remain intact when switching themes.
- Player/Target position mirroring compares horizontal centers but aligns the
  top edges of the Player portions; a visible Pet extension must not pull the
  shared visual through-line downward.

### Player and Pet

- Player with visible Pet, portrait-left and reflected.
- Pet hidden, portrait-left and reflected.
- Pet hidden while unlocked, including reduced-opacity preview.
- Player/Pet portraits, names, health, power, status, level, class, happiness, resting marker, and auras.
- Player cast bar attached and independently positioned.

### Target, Focus, and Target-of-Target

- Target in portrait-left and reflected orientations.
- Two-bar and one-bar Target.
- Focus at its scaled size in both orientations and both bar modes.
- Target-of-Target attached correctly, both orientations and both bar modes.
- Force One-Bar Layout with live units, empty unlocked frames, and test-mode
  previews; the power widget stays hidden and the selected skin/layout persists.
- Every portrait opening is checked for circularity or its intentionally
  designed shape after crop/display scaling.
- Portrait background fills the opening on bright and dark world backgrounds
  without foreground ornament or world leakage.
- Long names, level/class centers, aura rows, cast bars, dead/offline/status text.

### Party

- All four slots in unlocked preview.
- Actual frame-origin spacing matches `frameStep`; changing that field visibly
  changes the stack without requiring an unrelated runtime constant.
- Portrait-left and reflected individual Party frames.
- Portrait, name, bars, class, level, and role indicators.
- Buff/debuff growth on both sides.
- First, middle, and last connector crops.
- Live roster visibility and sorting after leaving preview mode.

### Raid

- Full forty-frame preview.
- Five headers and all group labels.
- Three-slice art without cap seams, or complete fixed-aspect art when
  `fullArt` is enabled.
- Health inset and text readability.
- Perimeter accent placement and flips.
- Connector strands across all seven row gaps.
- Target clasps, threat glow, roles, raid markers, leadership, status icons, debuffs, maintenance icons, predictions, absorbs, and faded states.
- Independent group positioning and standard grouped positioning.

### Nameplates and cast bars

- Friendly and hostile nameplates where supported.
- Targeted and untargeted nameplates.
- Health at empty, partial, and full values.
- Long name and level text.
- Native nameplate buffs/debuffs.
- Native nameplate cast bar.
- Player, Target, and Focus custom cast bars at their configured widths, heights, and offsets.
- Live and preview ornaments with caps fixed at the complete bar edges while progress is empty, partial, and nearly full.
- Target and Focus ornament spacing checked independently when `castBarOrnamentExtraWidth` differs.
- Interruptible glow at the configured `interruptGlowPoint`, aligned under the caps and checked against both dark and light backgrounds.
- Interruptible and non-interruptible state transitions without stale glow or ornament layers.

### Combat safety

- Enter and leave combat without Lua errors.
- Target changes and group updates still work.
- No secure-action or blocked-action warnings are caused by theme code.
- Theme selection remains a reload-time operation and is not attempted in combat.

## Common failure modes and diagnosis

### Art is vertically compressed or displaced

Cause: the art was authored for the full TGA rather than the configured vertical crop.

Check the source canvas, crop tuple, and logical display size as one system.

### A portrait opening becomes oval in game

Cause: the sampled source crop and logical display rectangle use different
horizontal and vertical scale, but the source opening was authored as an
uncompensated circle.

Calculate both scale factors from the crop. Either compensate the source
opening using `source width / source height = vertical scale / horizontal
scale`, or choose a crop/display aspect that scales uniformly. Do not fix an
art-ring distortion by changing only the live portrait widget.

### The 3D world leaks around a portrait

Cause: the live portrait holder or backing texture is smaller than the artwork
opening, the background has the wrong alpha shape, or a family needs an
override instead of the theme-wide widget default.

Adjust the owning `portraitSize` and supported
`portraitBackgroundScaleX/Y/YOffset` values. Keep the background asset dark
and unornamented; foreground rims belong in the frame art.

### Generated debris appears inside a live opening

Cause: a generation/edit pass painted nearly black pixels, pseudo-text, or
antialiased fragments into an area that merely looked transparent in preview.

Re-clear the opening from measured geometry after final resampling, then
inspect the runtime PNG/TGA alpha. Prompting is not a substitute for this build step.

### Mirrored art aligns but live widgets do not

Cause: the art was flipped successfully, but the canonical geometry does not match the art or a necessary optical exception is missing.

First verify the canonical point. Then compute its documented reflection and inspect only the affected role; add a sparse `mirrorOverrides` entry if strict reflection is unsuitable.

### One-bar mode shows doubled or missing structure

Cause: one-bar and two-bar assets do not share the same silhouette/openings, or health one-bar anchors do not match the new opening.

Overlay paired sources and inspect alpha differences.

If shared portrait/name/health geometry aligns but a large inert lower panel
remains, the one-bar art may be technically compatible yet compositionally
unfinished. Remove the unused power body and finish a compact lower edge while
preserving the fixed canvas/crop and shared widget registration.

### Focus looks different from Target

Cause: Focus uses `unitFrames.scaled`, including its own cast-bar size, offset, and optional ornament extension, rather than the full Target configuration.

Adjust `unitFrames.scaled` and test the full Target again because both use the same source art.

### Cast-bar caps move with progress

Cause: the `castBarEndCap` textures were created directly on a `StatusBar`, so Forever clipped or remapped them to the animated fill.

Keep both live and preview ornaments on sibling overlay frames anchored to their bars. Do not move the ornament texture back onto the StatusBar to simplify layering.

### Preview caps collapse toward the center but live caps are correct

Cause: the preview ornament read `GetWidth()` before a `SetAllPoints` layout had resolved, leaving only the configured ornament extension as its effective width.

Create preview ornament geometry from the owning theme's known `castBarSize[1]`. Validate live and preview paths separately.

### Cast-bar caps are uniformly too far out or too far in

Cause: the effective ornament extension does not place the two `castBarEndCap` textures at the intended distance from the live bar.

Adjust the owning frame's `castBarOrnamentExtraWidth` for Target or Focus. Adjust shared `layout.castBar.ornamentExtraWidth` for Player and other consumers. Do not change `castBarSize` unless the live bar itself also needs a different width.

### Interrupt glow has the correct size but is vertically misaligned

Cause: glow placement, UV sampling, and display dimensions were treated as the same control.

Use `interruptGlowPoint` for position, `interruptGlowCrop` for the sampled source rectangle, and ornament extension/size fields for display dimensions. Changing a crop does not move the glow frame.

### Raid end caps are distorted

Cause: fixed details crossed into the stretchable middle, cap source/display
widths disagree, or sliced rendering was selected for art designed as one
complete fixed-aspect frame.

Review `fullArt`, `artCapPixels`, `artTextureWidth`,
`artCapDisplayWidth`, and the source boundaries.

### Party connectors work but Raid connectors do not

Cause: the shared connector was designed only for full-width Party display. Raid uses narrow UV bands and vertical offsets.

Review all connector consumers and sampling values.

### New default positions do not appear

Cause: saved positions override theme defaults.

Test with clean/reset positions without treating persistent user data as a theme failure.

### A documented layout value appears to do nothing

Cause: saved data overrides the default, the value belongs to a different frame
family/state, or runtime still uses a hard-coded/shared value instead of the
declared field.

First test with clean saved variables and confirm the active theme/state. Then
trace the field to its consumer. If the runtime does not consume a legitimate
theme-controlled value, add a generic schema path and update every theme and
this guide; do not add a theme-ID special case.

### Theme selection changes assets but not geometry

Cause: the selected theme was changed without a reload, the theme loaded after
frame modules in the TOC, or runtime code captured a concrete layout table
before `ADDON_LOADED` initialized the selected-theme database.

Use the options reload flow and correct TOC order. File-local module variables
may retain the stable proxy returned by `PF:ThemeLayout(section)`; they must not
replace it with a concrete theme table during Lua file loading.

### Transparent edges show dark or colored fringes

Cause: contaminated RGB in transparent pixels, incorrect alpha export, or scaling against a mismatched matte.

Inspect against multiple backgrounds and clean transparent-edge RGB before TGA export.

## Acceptance criteria

### Contract-complete deliverable

A theme is contract-complete only when:

- it is fully contained under its theme folder;
- it has a unique registered ID and correct TOC entry;
- all required asset keys and layout sections exist;
- every runtime asset has a corresponding editable source or documented deterministic origin;
- asset dimensions, alpha, crops, mirrored behavior, and paired variants validate;
- every portrait and bar opening has a measured logical-to-source mapping, and
  crop/display aspect has been checked for unintended distortion;
- generated/resampled assets are normalized by a reproducible builder that
  restores structural transparency after the final resample;
- no copied theme identity/path remains;
- `tools\ValidateTheme.ps1` passes and all remaining manual static checks pass;
- rendered alpha and normalized runtime images have been inspected;
- no runtime module was changed solely for theme-specific branching;
- the creator can install/select the theme without manually editing paths, filenames, Lua values, or images.

### In-game-verified release

A contract-complete theme becomes in-game verified only when the full matrix has
passed in World of Warcraft. If the authoring environment cannot launch WoW,
deliver the complete static artifact, label the release **in-game validation
pending**, and list every remaining matrix item. Do not call untested behavior
verified, but do not leave known source, conversion, registration, schema, or
static-validation work unfinished merely because game access is unavailable.

Neither status means “full visual-identity skin.” Values listed under Current
theme boundary remain shared until the generic schema is deliberately extended
for every registered theme and this guide is updated.

## Agent handoff template

The creator can hand the following task to an AI agent and append an art-direction brief:

```text
Create a complete new PrettyFrames theme.

Read and follow Themes/THEME_AUTHORING_GUIDE.md in full before making changes.

Theme display name: <name or “derive from art direction”>
Theme ID/folder: <values or “derive safe values”>
Design relationship: <independent / derivative of ThemeName>

Requirements:
- create a new self-contained theme; do not overwrite existing themes;
- for an independent theme, design a new silhouette and geometry plan rather
  than copying an existing theme's masks, crops, or layout coordinates;
- choose each frame family's crop and display aspect from its own composition,
  and verify portrait/bar geometry with measured source mappings;
- produce editable PNG sources and final game-ready TGA assets;
- provide a deterministic theme build step that normalizes sources and
  re-clears all live openings after resampling;
- preserve every required live-UI opening and asset dependency;
- create and fully configure the declarative theme files;
- register the theme in PrettyFrames.toc before Database.lua;
- do not add theme-ID conditionals to runtime modules;
- perform all static validation in the guide;
- perform available visual/in-game validation;
- report generated files, configuration changes, validation results, and any item that could not be tested;
- leave no manual path, filename, conversion, or configuration edits for the creator.

Art direction:
<append separate style brief here>
```

If the environment cannot launch World of Warcraft, the agent should still finish the theme, complete static and rendered-image validation, and provide the exact in-game checklist remaining. Lack of game access is not a reason to leave known file or configuration work unfinished.
