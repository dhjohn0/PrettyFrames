# Orgrimmar art direction

This is an independent-geometry theme, not a recolor or alpha-mask derivative.
Its canonical Player/Pet frame uses a round portrait, a hanging hide name
banner, compact status openings, and a shallow attached Pet dock. The runtime
displays it at 500 x 250 with a full-canvas crop.

Visual language: hammered black iron, oxblood kodo hide, aged bone lashings,
dark leather thongs, muted brass rivets, short practical spikes, axe-like
endcaps, and restrained forge embers. It intentionally avoids faction logos,
skulls, delicate filigree, and woodland foliage.

The canonical `PlayerFrame-WithPet.png` was produced with the built-in
image-generation tool from `Work/PlayerFrame-WithPet-Geometry.png`, using the
earlier Orgrimmar frame as its material reference. The production builder now
uses the +Pet-derived standalone source in
`UnitFrame-BottomGeneration.png`. That edit preserves the Player artwork and
removes only the attached Pet dock. The dedicated one-bar master,
`UnitFrame-OneBar-Generation.png`, preserves the portrait, banner, and health
rail while removing the complete power rail and unused lower body. The builder
crops both masters at a uniform 2.5:1 display ratio, re-clears every live
opening, restores the nameplate's neutral-black health backing, enforces exact
grayscale on `StatusBar`, and writes the runtime TGAs.

## Canonical Player/Pet generation prompt

Render the supplied compact 2:1 Player/Pet geometry as premium hand-painted,
Orgrimmar-inspired Horde UI artwork. Preserve its round Player portrait, name
banner, two compact Player status openings, shallow attached Pet dock, round
Pet portrait, and Pet health opening. Use blackened hammered iron, stitched
oxblood hide, aged bone, leather bindings, rivets, restrained spikes, and tiny
ember cracks. Keep all live openings and the exterior genuinely transparent.
Include no characters, text, numbers, icons, fills, logos, symbols, skulls,
scene, or watermark.

## Supporting prompt set

Each supporting pass used its existing flat geometry PNG as the exact edit
target and `UnitFrame.png` as the style reference. The shared direction was:

- replace every flat surface with premium hand-painted blackened iron,
  stitched oxblood hide, aged bone, leather bindings, muted brass rivets, and
  restrained ember cracks;
- preserve the exact canvas, silhouette, live openings, stretch caps, and
  compact-readability requirements of that role;
- keep exterior and live openings genuinely transparent, except for the native
  nameplate health backing and the fully opaque neutral grayscale status bar;
- include no characters, portraits, text, numbers, icons, fills, faction logos,
  skulls, foliage, scenes, or watermarks.

Separate built-in image-generation edits were produced for the unified
Player/Pet frame, Party frame, nameplate, portrait ring, indicator socket,
cast-bar ornament and glow, raid frame and glow, group header, Party connector,
target clasp, four raid perimeter accents, resting indicator, and status-bar
material. This kept each asset's geometry and transparency contract explicit.

The Raid frame was later replaced with a complete fixed-aspect generation from
`Work/RaidFrame-Full-Geometry.png`, using the earlier Raid frame only as its
material reference. `RaidFrame-FullGeneration.png` is the generated master.
The builder fits it into the runtime canvas, re-clears the exact live health
opening, and writes `RaidFrame.png`. Orgrimmar enables `raid.fullArt`, so the
runtime draws this asset as one complete texture rather than cutting it into
left, middle, and right slices.

The Party frame was subsequently rebuilt on a new 3:1 compact worksheet and is
displayed at 380 x 128 with a dedicated crop band. Portraits use a separate
`PortraitBackground` asset containing only a dark charcoal texture cut to a
faceted shield silhouette; foreground bone and iron remain in the frame art.

The unified Player/Pet frame is displayed at 500 x 250. Standalone Player,
Target, and Focus use the tightly constrained +Pet edit
`UnitFrame-BottomGeneration.png`: Player and Target display at 500 x 200 and
Focus at 400 x 160. All use the circular `PortraitBackgroundRound` dark
backing. The standalone design closely matches the Player portion of the +Pet
frame while retaining its own complete lower edge instead of cropping the Pet
dock away.

Target-of-Target uses a dedicated, less ornate pair displayed at 340 x 114:
`TargetOfTargetFrame-Generation.png` for units with power and
`TargetOfTargetFrame-OneBar-Generation.png` for health-only units. Both were
generated as precise edits of the Party frame, preserving its proven circular
portrait geometry while removing both top spikes and the complete role-icon
socket. The one-bar asset is a direct edit of the two-bar master that removes
the power rail and the unused lower stone slab, finishing the frame immediately
beneath the health rail while retaining the complete portrait surround. The
builder places both in the same uniform 3:1 crop band as Party, re-clears all
live openings, and writes the dedicated runtime TGAs.

Player and full Target aura icons use 24-pixel icons in two rows immediately
above the visible hide banner. Pet aura rows grow beyond the dock endcap rather
than merely beyond the smaller secure Pet button. Player and Target health and
power fills are aligned to their bevels at 19 and 13 pixels high; Pet health is
11 pixels high. The Player cast fill is 440 pixels wide inside a 492-pixel
ornament. Target-of-Target is
attached 56 pixels below Target, reserving the intervening channel for the
Target cast-bar ornament.

## Rebuild

```powershell
& .\tools\BuildOrgrimmarAssets.ps1
& .\tools\ValidateTheme.ps1 -ThemeName Orgrimmar
node .\tools\GenerateThemeGeometryReference.js
```
