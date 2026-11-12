# PrettyFrames feature requests

These outlines cover the remaining pre-release feature gaps identified by comparison with established unit-frame addons.

## Configuration principles

PrettyFrames should remain usable without studying an options guide. New features must follow these rules:

1. **Useful defaults first.** A feature should work well when enabled without further configuration.
2. **Configure where you see it.** Frame-specific behavior belongs in that frame or group handle's right-click menu. The main Options panel remains for addon-wide features, themes, profiles, and replacement choices.
3. **Prefer a few meaningful choices.** Use named presets or plain-language toggles instead of exposing implementation details.
4. **Progressive disclosure.** Put secondary controls in a single clearly named submenu. Avoid menus deeper than two levels.
5. **Immediate preview.** Changes should be visible in unlocked or test mode without requiring a reload unless protected frame construction makes one unavoidable.
6. **One source of truth.** Do not expose the same setting in several unrelated places.
7. **Safe in combat.** Defer protected changes and clearly explain when a change cannot be applied immediately.
8. **Theme-owned geometry.** Themes decide exact artwork, attachment points, and dimensions. Profiles save behavior and user choices.

## Requests

- [Class-resource display](class-resource-display.md)
- [Party range indication](party-range-indication.md)
- [Party healing and dispel indicators](party-healing-dispel-indicators.md)
- [Boss frames](boss-frames.md)
- [Click-casting interoperability](click-casting-interoperability.md)

