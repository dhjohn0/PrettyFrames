# PrettyFrames themes

For the complete technical specification and an AI-agent handoff template, see [`THEME_AUTHORING_GUIDE.md`](THEME_AUTHORING_GUIDE.md).

Each theme owns its complete visual contract. New themes should keep that data
in small declarative files:

- `Globals.lua` contains the asset map plus named `globals.art` and
  `globals.layout` presets shared by frame families.
- `Frames.lua` selects those presets for Player, Target, Focus, Boss, Party,
  Raid, Nameplates, and other frame families. A selection may contain sparse
  overrides.
- `Theme.lua` is the small final `PF:RegisterTheme(...)` call containing the
  theme identity. It must load after the fragments.
- `Assets/` contains only the `.tga` files loaded by World of Warcraft.
- `Sources/` contains editable PNG originals and any retired work in `Sources/Legacy/`.

To add a theme, use either the derivative or independent workflow in the
authoring guide, then add all of its Lua files to `PrettyFrames.toc` before
`Database.lua`, with `Theme.lua` last. Orgrimmar is the independent-geometry
example. The theme then appears automatically in the PrettyFrames Appearance
panel. Existing single-file themes remain supported.

Anchor entries use `{ point, relativePoint, x, y }`. Positive X moves right and positive Y moves up. Crop entries use `{ left, right, top, bottom }`, with values from 0 to 1.

Frame geometry is authored once in a canonical portrait-left `points` table. PrettyFrames reflects horizontal anchors and X offsets automatically. Use a sparse `mirrorOverrides` table only for deliberate optical corrections that cannot be expressed as a true reflection.

Independent themes should choose logical sizes, crops, and live-widget
rectangles before painting. Frame families may use different crop/display
aspects; Target-of-Target can override the shared unit-frame crop. Verify the
source-to-display scale before authoring circular openings, and use a
deterministic theme builder to re-clear portraits and bars after generated art
is resampled.

Keep asset keys stable when possible. Filenames are intentionally descriptive
and may be changed as long as the matching value in `assets` or a frame art
preset is updated.
