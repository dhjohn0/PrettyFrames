# Moonlight art direction

Moonlight is a Night Elf-inspired forest theme built around midnight blue,
indigo, blue-black wood, desaturated silver, violet, teal, and cyan moonglow.
Its recurring motifs are slim ancient branches, nocturnal leaves, crescents,
stars, and restrained Kaldorei-inspired curves without using faction logos.

The production prompt set used the existing Verdant PNGs only as geometry and
alpha references. Each role was restyled independently with these shared rules:

- preserve the reference canvas proportions, silhouette, live-widget openings,
  safe regions, crops, and attachment points;
- keep the exterior and every live-widget opening genuinely transparent;
- do not bake in text, portraits, levels, icons, status fills, characters,
  faction emblems, logos, or watermarks;
- avoid warm copper, gold, orange, red autumn foliage, and photorealism;
- reduce ornament density for Raid, nameplate, connector, and glow roles;
- keep one-bar variants aligned with their two-bar companions;
- keep Raid middle slices stretch-safe and cast glows mostly translucent.

The editable generated PNGs live in `Sources/`. `tools/BuildMoonlightAssets.ps1`
normalizes them to the runtime contracts, reapplies structural reference alpha
where live content requires exact openings, and writes uncompressed 32-bit TGA
files into `Assets/`.

The portrait backing is intentionally different from the ornamental frame art:
it is a full-bleed, low-contrast midnight leaf-and-bark pattern with no ring,
outline, emblem, or highlight. WoW's circular portrait mask supplies its shape,
while the surrounding unit-frame artwork supplies the visible bezel.

The shared status-bar artwork is strictly neutral grayscale. Health, power,
nameplate, Raid, and cast-bar colors are applied by WoW at runtime; embedding a
blue or violet hue in the source would bias red fills toward purple.

Interruptibility uses a broad exterior cyan-blue halo with bright end-cap
blooms and a restrained translucent wash across the bar. It renders additively
above both the progress fill and silver ornament so neither can occlude the
signal.

