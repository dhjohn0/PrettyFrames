# CurseForge release guide

## Build the upload

From the PrettyFrames addon directory, run:

```powershell
./tools/Package-CurseForge.ps1
```

The script reads the release version from `PrettyFrames.toc` and creates:

- `dist/PrettyFrames-<version>.zip` — upload this file to CurseForge.
- `dist/PrettyFrames-<version>.zip.sha256` — optional local integrity record; do not upload it as the addon file.

The ZIP contains one top-level `PrettyFrames` folder. It includes the TOC-listed Lua files, compiled `.tga` assets, README, and changelog. Development-only source art, previews, docs, and tools are excluded. The build fails if a TOC file is missing or an excluded path enters the package.

To place the artifacts elsewhere:

```powershell
./tools/Package-CurseForge.ps1 -OutputDirectory C:\path\to\releases
```

## Before each release

1. Update `## Version:` in `PrettyFrames.toc`.
2. Add a matching dated section to `CHANGELOG.md`.
3. Test that version in the Forever client with a clean or backed-up `PrettyFramesDB`.
4. Run the packager and inspect the ZIP before uploading it.

## Create the CurseForge project

Suggested project metadata:

- **Name:** PrettyFrames
- **Game:** World of Warcraft
- **Primary category:** Unit Frames
- **Summary:** Ornate, portrait-forward unit, party, raid, boss, and nameplate frames for World of Warcraft: Forever.
- **Supported game version:** Forever 1.60.1 (Interface 16001)
- **Required dependencies:** None
- **Optional integrations:** Masque and Clique

Use the main `README.md` as the starting point for the project description. Add screenshots showing the Player/Target layout, Party frames, Raid frames, and the three included themes; images inside the ZIP are not used as the project gallery.

Choose a license in the CurseForge project settings before publishing. If you want recipients to have explicit reuse rights outside CurseForge, also add the corresponding `LICENSE` file at the addon root; the packager includes it automatically.

## Upload a release file

On the project's **Files** tab, select **Upload File**, then use:

- **File:** `dist/PrettyFrames-<version>.zip`
- **Display name:** `PrettyFrames <version>`
- **Release type:** Alpha for an untested preview, Beta for a broadly testable build, or Release for a stable public build
- **Supported version:** Forever 1.60.1
- **Changelog:** Copy the matching version section from `CHANGELOG.md`
- **Related projects:** Add Masque and Clique as optional dependencies if their CurseForge project pages are available for Forever

After moderation, install the file through the CurseForge app into a clean Forever profile and confirm that the resulting path is `Interface/AddOns/PrettyFrames/PrettyFrames.toc` (not a nested second `PrettyFrames` directory).
