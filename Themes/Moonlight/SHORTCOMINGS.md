# Moonlight theme shortcomings

## Authoring-guide reconciliation

The gaps discovered while producing Moonlight are now answered in
`Themes/THEME_AUTHORING_GUIDE.md`:

- the native nameplate health slot is documented as a deliberate exception to
  the general transparency rule, with a nearly opaque neutral-black backing;
- every active role now requires an editable source PNG or a documented,
  deterministic derivation, and the incomplete Verdant source set is called
  out explicitly;
- fixed runtime canvas/export requirements are separated from theme-controlled
  crop ranges and placement geometry;
- `tools/ValidateTheme.ps1` now checks registration, required keys, TGA headers,
  dimensions, source coverage, and TOC order with one command;
- contract-complete static delivery is distinguished from in-game verification;
- bitmap/layout contract completeness is distinguished from a full visual-
  identity skin.

The validator intentionally cannot judge rendered alpha contours, artistic
quality, or protected Blizzard behavior. Those remain manual image inspection
and in-game verification tasks rather than undocumented holes in the guide.

## Theme-system limitations

The current theme contract cannot independently style several values that are
important to a complete Moonlight presentation. They remain shared with every
theme and were intentionally not hard-coded for `moonlight`:

- fonts, font sizes, text colors, shadows, and justification;
- fallback backdrop and bar colors from `PF.colors`;
- aura crops, borders, spacing, and wrapping;
- Raid prediction, absorb, dispel, threat, availability, and status colors;
- the nameplate target-overlay tint and custom cast-bar state colors;
- portrait masks, role sheets, raid markers, spell icons, and custom cast fills;
- options, move handles, context menus, and other editing UI;
- the global Raid baseline scale.

Consequently, the bitmap frames are Moonlight-specific while some live text,
state colors, and Blizzard media may still retain the add-on's shared visual
language. Correcting that cleanly requires generic schema fields added to every
theme and consumed by the runtime; checking for the Moonlight ID would violate
the authoring guide's isolation rule.

## Asset-production limitations

- Generated artwork is normalized into fixed runtime canvases. Extra-wide roles
  such as status bars, cast bars, connectors, and raid art require resampling,
  so the source PNGs retain more detail than the game textures can display.
- Structural alpha masks are restored from the technical reference for the main
  frames. This protects live widgets, but can trim a few painted edge pixels.
- One-bar art was derived from the Moonlight two-bar frames because the reference
  theme does not include editable one-bar source PNGs for every runtime TGA.
- The Raid frame is intentionally plain and the perimeter accents are sparse;
  forty repeated ornate frames otherwise become noisy at the configured size.
- Saved positions and independent cast-bar positions override theme defaults.
  A clean saved-variable state is required to assess the defaults themselves.

## Required in-game verification

Static validation cannot reproduce protected-frame behavior or every Blizzard
rendering path. After selecting Moonlight and reloading the UI, verify:

- Player with and without Pet, plus both orientations;
- Target, Focus, and Target-of-Target in two-bar and one-bar states;
- Party roles and connectors in both orientations;
- Raid groups, cap stretching, threat glow, target clasps, and edge accents;
- native nameplates, their target overlay, and cast bars;
- clean settings and an existing saved-variable profile.

