local _, PF = ...

-- Named presets keep shared artwork and geometry in one place. Frame entries
-- select a preset and may add sparse overrides without mutating the preset.
PF:ExtendTheme("moonlight", {
    globals = {
        art = {
            player = {
                playerFrameWithPet = "PlayerFrame-WithPet.tga",
                unitFrame = "UnitFrame.tga",
                restingIndicator = "PlayerRestingIndicator.tga",
            },
            largeUnit = {
                unitFrame = "UnitFrame.tga",
                unitFrameOneBar = "UnitFrame-OneBar.tga",
            },
            compactUnit = {
                targetOfTargetFrame = "TargetOfTargetFrame.tga",
                targetOfTargetFrameOneBar = "TargetOfTargetFrame-OneBar.tga",
            },
            party = {
                partyFrame = "PartyFrame.tga",
                partyConnector = "PartyConnector.tga",
            },
            raid = { raidFrame = "RaidFrame.tga" },
            nameplate = { nameplateFrame = "NameplateFrame.tga" },
            castBar = {
                castBarFrame = "CastBarFrame.tga",
                castBarInterruptGlow = "CastBarInterruptGlow.tga",
            },
        },
    },
    frames = {
        player = { art = "player", layout = "player" },
        pet = { art = "player", layout = "player" },
        target = { art = "largeUnit", layout = "unitFrames" },
        focus = { art = "largeUnit", layout = "unitFrames" },
        targettarget = { art = "compactUnit", layout = "unitFrames" },
        boss = { art = "compactUnit", layout = "unitFrames" },
        party = { art = "party", layout = "party" },
        raid = { art = "raid", layout = "raid" },
        nameplate = { art = "nameplate", layout = "nameplate" },
        castBar = { art = "castBar", layout = "castBar" },
    },
})
