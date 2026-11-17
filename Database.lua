local addonName, PF = ...

local defaults = {
    theme = "verdant",
    scale = 1,
    locked = true,
    replaceUnitFrames = true,
    -- Keep boss replacement opt-in until Forever encounters are combat-tested.
    replaceBossFrames = false,
    replacePartyFrames = true,
    replaceRaidFrames = true,
    replaceNameplates = true,
    replaceExperienceBar = false,
    experienceBar = {
        scale = 1,
        width = 420,
        growUpwards = true,
        showPlayer = true,
        showPet = true,
        showReputation = true,
        showRested = true,
        playerColorMode = "violet",
        petColorMode = "emerald",
        reputationColorMode = "standing",
        playerTextMode = "currentmax",
        petTextMode = "currentmax",
        reputationTextMode = "currentmax",
        customColors = {},
    },
    enable3DPortraits = true,
    mirrorPlayerTarget = false,
    groupLayoutsEnabled = false,
    bossLayout = {
        growUpwards = false,
        independentPositioning = false,
        auraMode = "mechanics",
        aurasLeft = true,
        rangeFade = true,
        rangeDistance = "ranged",
        outOfRangeAlpha = 0.55,
        healthTextMode = "currentmax",
        healthColorMode = "unit",
        healthBackgroundAlpha = 1,
        healthSpark = true,
        forceOneBar = false,
        powerTextMode = "currentmax",
        powerColorMode = "type",
        powerBackgroundAlpha = 1,
        powerSpark = true,
    },
    partyLayout = {
        scale = 1,
        growUpwards = false,
        sort = "index",
        visibility = "auto",
        aurasLeft = false,
        useInSmallRaid = false,
        hideInRaid = true,
        rangeFade = true,
        rangeDistance = "ranged",
        outOfRangeAlpha = 0.55,
        showDebuffs = true,
        showDispellableDebuffs = false,
        showPredictions = true,
        showMaintenance = false,
        showThreat = true,
        showStatusText = true,
        showRoleIcons = true,
        showLeadership = true,
        showTargetHighlight = true,
        showRaidMarkers = true,
        healthTextMode = "currentmax",
        healthColorMode = "unit",
        healthBackgroundAlpha = 1,
        healthSpark = true,
        powerTextMode = "currentmax",
        powerColorMode = "type",
        powerBackgroundAlpha = 1,
        powerSpark = true,
        accountForIncomingHeals = false,
        displayProfile = "balanced",
    },
    raidLayout = {
        scale = 1,
        visibility = "auto",
        useInParty = false,
        showHeaders = true,
        independentPositioning = false,
        sort = "index",
        healthTextMode = "deficit",
        healthColorMode = "unit",
        healthBackgroundAlpha = 1,
        healthSpark = true,
        accountForIncomingHeals = false,
        showDebuffs = true,
        showDispellableDebuffs = true,
        showMaintenance = true,
        showPredictions = true,
        showHealAbsorbs = true,
        showRoleIcons = true,
        showLeadership = true,
        showTargetHighlight = true,
        showStatusText = true,
        showRaidMarkers = true,
        showThreat = true,
        rangeFade = true,
        rangeDistance = "ranged",
        outOfRangeAlpha = 0.55,
        maintenanceDuration = 120,
        displayProfile = "balanced",
    },
}

local function CopyPosition(position)
    return { position[1], position[2], position[3], position[4], position[5] }
end

local function IsValidPosition(position)
    return type(position) == "table"
        and type(position[1]) == "string"
        and type(position[2]) == "string"
        and type(position[3]) == "string"
        and type(position[4]) == "number"
        and type(position[5]) == "number"
end

local function ReadBoolean(value, fallback)
    if type(value) == "boolean" then return value end
    return fallback
end

local function ReadAuraLimit(value)
    if type(value) ~= "number" then return nil end
    return math.max(0, math.min(PF.MAX_AURAS, math.floor(value + 0.5)))
end

local function ReadPartyUseInSmallRaid(layout)
    if type(layout) ~= "table" then return defaults.partyLayout.useInSmallRaid end
    if type(layout.useInSmallRaid) == "boolean" then return layout.useInSmallRaid end
    return defaults.partyLayout.useInSmallRaid
end

local function ReadPartyHideInRaid(layout)
    if type(layout) ~= "table" then return defaults.partyLayout.hideInRaid end
    if type(layout.hideInRaid) == "boolean" then return layout.hideInRaid end
    return defaults.partyLayout.hideInRaid
end

local function ReadOutOfRangeAlpha(options, fallback)
    local alpha = type(options) == "table" and options.outOfRangeAlpha
    if alpha == 0.35 or alpha == 0.55 or alpha == 0.75 then return alpha end
    return fallback or defaults.partyLayout.outOfRangeAlpha
end

local function ReadRangeDistance(options)
    return type(options) == "table" and options.rangeDistance == "melee"
        and "melee" or "ranged"
end

local function ReadProgressTextMode(options, key)
    local mode = type(options) == "table" and options[key]
    if mode == "current" or mode == "maximum" or mode == "currentmax"
        or mode == "percent" or mode == "currentpercent" or mode == "none" then
        return mode
    end
    return "currentmax"
end

local function ReadProgressColorMode(options, key, kind)
    local mode = type(options) == "table" and options[key]
    local valid = kind == "player"
        and (mode == "violet" or mode == "blue" or mode == "gold"
            or mode == "emerald" or mode == "class" or mode == "custom")
        or kind == "pet"
        and (mode == "emerald" or mode == "teal" or mode == "gold"
            or mode == "player" or mode == "custom")
        or kind == "reputation"
        and (mode == "standing" or mode == "blue" or mode == "gold"
            or mode == "player" or mode == "custom")
    if valid then return mode end
    if kind == "player" then return "violet" end
    if kind == "pet" then return "emerald" end
    return "standing"
end

local function ReadProgressCustomColors(options)
    local colors = {}
    local saved = type(options) == "table" and options.customColors
    for _, kind in ipairs({ "player", "pet", "reputation" }) do
        local color = type(saved) == "table" and saved[kind]
        if type(color) == "table" and type(color[1]) == "number"
            and type(color[2]) == "number" and type(color[3]) == "number" then
            colors[kind] = {
                math.max(0, math.min(1, color[1])),
                math.max(0, math.min(1, color[2])),
                math.max(0, math.min(1, color[3])),
            }
        end
    end
    return colors
end

local function ReadPartyDisplayProfile(layout)
    if type(layout) ~= "table" then return defaults.partyLayout.displayProfile end
    local profile = layout.displayProfile
    if profile == "balanced" or profile == "healer" or profile == "minimal"
        or profile == "custom" then
        return profile
    end
    return "custom"
end

local function NormalizeRaidGroupOffsets(savedOffsets)
    local offsets = {}
    for groupIndex = 1, 5 do
        local saved = type(savedOffsets) == "table" and savedOffsets[groupIndex]
        if type(saved) == "table" and type(saved[1]) == "number" and type(saved[2]) == "number" then
            offsets[groupIndex] = { saved[1], saved[2] }
        else
            offsets[groupIndex] = { 0, 0 }
        end
    end
    return offsets
end

local function CopyCastBarPositions(savedPositions)
    local positions = {}
    if type(savedPositions) ~= "table" then return positions end
    for key, saved in pairs(savedPositions) do
        if type(key) == "string" and type(saved) == "table"
            and type(saved[1]) == "number" and type(saved[2]) == "number" then
            positions[key] = { saved[1], saved[2] }
        end
    end
    return positions
end

local function CopyThemePositions(theme, savedPositions)
    local defaultPositions = assert(
        theme.layout and theme.layout.screen and theme.layout.screen.positions,
        "PrettyFrames theme is missing default screen positions"
    )
    local positions = {}
    for key, defaultPosition in pairs(defaultPositions) do
        local savedPosition = type(savedPositions) == "table" and savedPositions[key]
        positions[key] = CopyPosition(IsValidPosition(savedPosition) and savedPosition or defaultPosition)
    end
    -- Independently positioned attached frames, such as Target-of-Target, do
    -- not have a theme default anchor in this table. Preserve those additional
    -- valid positions when copying or seeding a theme placement.
    if type(savedPositions) == "table" then
        for key, savedPosition in pairs(savedPositions) do
            if positions[key] == nil and type(key) == "string" and IsValidPosition(savedPosition) then
                positions[key] = CopyPosition(savedPosition)
            end
        end
    end
    return positions
end

local themeOptionKeys = {
    "scale",
    "locked",
    "replaceUnitFrames",
    "replaceBossFrames",
    "replacePartyFrames",
    "replaceRaidFrames",
    "replaceNameplates",
    "replaceExperienceBar",
    "experienceBar",
    "enable3DPortraits",
    "mirrorPlayerTarget",
    "groupLayoutsEnabled",
    "groupLayouts",
    "bossLayout",
    "partyLayout",
    "raidLayout",
    "positions",
    "frameSettings",
}

local function CopyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[CopyTable(key, seen)] = CopyTable(child, seen)
    end
    return copy
end

local function CaptureThemeOptions(database, copyTables)
    local options = {}
    for _, key in ipairs(themeOptionKeys) do
        local value = database[key]
        if key == "positions" and type(database.groupLayouts) == "table"
            and type(database.groupLayouts.sharedPositions) == "table" then
            value = database.groupLayouts.sharedPositions
        end
        options[key] = copyTables and CopyTable(value) or value
    end
    return options
end

local function ApplyThemeOptions(database, options)
    for _, key in ipairs(themeOptionKeys) do
        database[key] = options[key]
    end
end

local function GetCastBarPositions(frameSettings)
    local positions = {}
    for key, setting in pairs(type(frameSettings) == "table" and frameSettings or {}) do
        local position = type(setting) == "table" and setting.castBarPosition
        if type(key) == "string" and type(position) == "table"
            and type(position[1]) == "number" and type(position[2]) == "number" then
            positions[key] = { position[1], position[2] }
        end
    end
    return positions
end

local function ThemeOptionsProfileSource(themeId, options)
    local source = CaptureThemeOptions(options, true)
    source.theme = themeId
    source.themePlacements = {
        [themeId] = {
            positions = source.positions,
            groupOffsets = source.raidLayout and source.raidLayout.groupOffsets,
            castBarPositions = GetCastBarPositions(source.frameSettings),
        },
    }
    return source
end

local function ReadHealthTextMode(layout, fallback)
    local mode = type(layout) == "table" and layout.healthTextMode
    if mode == "deficit" or mode == "percent" or mode == "current"
        or mode == "maximum" or mode == "currentmax"
        or mode == "currentpercent" or mode == "none" then
        return mode
    end
    return fallback
end

local function ReadHealthColorMode(options, fallback)
    local mode = type(options) == "table" and options.healthColorMode
    if mode == "unit" or mode == "class" or mode == "reaction"
        or mode == "gradient" or mode == "green" then return mode end
    return fallback or "unit"
end

local function ReadHealthBackgroundAlpha(options, fallback)
    local alpha = type(options) == "table" and options.healthBackgroundAlpha
    if alpha == 0 or alpha == 0.25 or alpha == 0.5
        or alpha == 0.75 or alpha == 1 then return alpha end
    return fallback or 1
end

local function ReadPowerTextMode(options, fallback)
    local mode = type(options) == "table" and options.powerTextMode
    if mode == "current" or mode == "maximum" or mode == "currentmax"
        or mode == "percent" or mode == "currentpercent"
        or mode == "none" then return mode end
    return fallback or "currentmax"
end

local function ReadPowerColorMode(options, fallback)
    local mode = type(options) == "table" and options.powerColorMode
    if mode == "type" or mode == "class" or mode == "gradient"
        or mode == "theme" or mode == "red" or mode == "yellow" then
        return mode
    end
    return fallback or "type"
end

local function ReadPowerBackgroundAlpha(options, fallback)
    local alpha = type(options) == "table" and options.powerBackgroundAlpha
    if alpha == 0 or alpha == 0.25 or alpha == 0.5
        or alpha == 0.75 or alpha == 1 then return alpha end
    return fallback or 1
end

local function ReadRaidDisplayProfile(layout)
    if type(layout) ~= "table" then return defaults.raidLayout.displayProfile end
    local profile = layout.displayProfile
    if profile == "balanced" or profile == "healer" or profile == "tank"
        or profile == "minimal" or profile == "custom" then
        return profile
    end
    return "custom"
end

local function ReadMaintenanceDuration(layout)
    local duration = type(layout) == "table" and layout.maintenanceDuration
    if duration == 30 or duration == 60 or duration == 120 then return duration end
    return defaults.raidLayout.maintenanceDuration
end

local function BuildProfile(self, previous, buildingThemeOptions)
    previous = type(previous) == "table" and previous or {}
    local selectedThemeId = type(previous.theme) == "string" and self.themes[previous.theme]
        and previous.theme or defaults.theme
    local selectedTheme = assert(self.themes[selectedThemeId], "PrettyFrames default theme is missing")
    local database = {
        theme = selectedThemeId,
        scale = self:IsValidScale(previous.scale) and previous.scale or defaults.scale,
        locked = type(previous.locked) == "boolean" and previous.locked or defaults.locked,
        replaceUnitFrames = ReadBoolean(previous.replaceUnitFrames, defaults.replaceUnitFrames),
        replaceBossFrames = ReadBoolean(previous.replaceBossFrames, defaults.replaceBossFrames),
        replacePartyFrames = ReadBoolean(previous.replacePartyFrames, defaults.replacePartyFrames),
        replaceRaidFrames = ReadBoolean(previous.replaceRaidFrames, defaults.replaceRaidFrames),
        -- This setting defaults on; an explicit saved false must survive Lua's
        -- `and/or` truthiness when the database is rebuilt.
        replaceNameplates = previous.replaceNameplates ~= false,
        replaceExperienceBar = previous.replaceExperienceBar == true,
        experienceBar = {
            scale = self:IsValidScale(
                type(previous.experienceBar) == "table" and previous.experienceBar.scale
            ) and previous.experienceBar.scale or defaults.experienceBar.scale,
            width = type(previous.experienceBar) == "table"
                and type(previous.experienceBar.width) == "number"
                and math.max(240, math.min(720, math.floor(previous.experienceBar.width + 0.5)))
                or defaults.experienceBar.width,
            growUpwards = type(previous.experienceBar) ~= "table"
                or previous.experienceBar.growUpwards ~= false,
            showPlayer = type(previous.experienceBar) ~= "table"
                or previous.experienceBar.showPlayer ~= false,
            showPet = type(previous.experienceBar) ~= "table"
                or previous.experienceBar.showPet ~= false,
            showReputation = type(previous.experienceBar) ~= "table"
                or previous.experienceBar.showReputation ~= false,
            showRested = type(previous.experienceBar) ~= "table"
                or previous.experienceBar.showRested ~= false,
            playerColorMode = ReadProgressColorMode(
                previous.experienceBar, "playerColorMode", "player"
            ),
            petColorMode = ReadProgressColorMode(
                previous.experienceBar, "petColorMode", "pet"
            ),
            reputationColorMode = ReadProgressColorMode(
                previous.experienceBar, "reputationColorMode", "reputation"
            ),
            playerTextMode = ReadProgressTextMode(previous.experienceBar, "playerTextMode"),
            petTextMode = ReadProgressTextMode(previous.experienceBar, "petTextMode"),
            reputationTextMode = ReadProgressTextMode(
                previous.experienceBar, "reputationTextMode"
            ),
            customColors = ReadProgressCustomColors(previous.experienceBar),
            position = type(previous.experienceBar) == "table"
                and type(previous.experienceBar.position) == "table"
                and type(previous.experienceBar.position[1]) == "number"
                and type(previous.experienceBar.position[2]) == "number"
                and { previous.experienceBar.position[1], previous.experienceBar.position[2] }
                or nil,
        },
        enable3DPortraits = previous.enable3DPortraits ~= false,
        mirrorPlayerTarget = type(previous.mirrorPlayerTarget) == "boolean"
            and previous.mirrorPlayerTarget or defaults.mirrorPlayerTarget,
        groupLayoutsEnabled = previous.groupLayoutsEnabled == true,
        groupLayouts = type(previous.groupLayouts) == "table"
            and CopyTable(previous.groupLayouts) or nil,
        bossLayout = {
            growUpwards = type(previous.bossLayout) == "table"
                and previous.bossLayout.growUpwards == true or defaults.bossLayout.growUpwards,
            independentPositioning = type(previous.bossLayout) == "table"
                and previous.bossLayout.independentPositioning == true,
            auraMode = type(previous.bossLayout) == "table"
                and (previous.bossLayout.auraMode == "personal"
                    or previous.bossLayout.auraMode == "hidden")
                and previous.bossLayout.auraMode or defaults.bossLayout.auraMode,
            aurasLeft = type(previous.bossLayout) ~= "table"
                or previous.bossLayout.aurasLeft ~= false,
            rangeFade = type(previous.bossLayout) ~= "table"
                or previous.bossLayout.rangeFade ~= false,
            rangeDistance = ReadRangeDistance(previous.bossLayout),
            outOfRangeAlpha = ReadOutOfRangeAlpha(
                previous.bossLayout,
                defaults.bossLayout.outOfRangeAlpha
            ),
            healthTextMode = ReadHealthTextMode(
                previous.bossLayout, defaults.bossLayout.healthTextMode
            ),
            healthColorMode = ReadHealthColorMode(
                previous.bossLayout, defaults.bossLayout.healthColorMode
            ),
            healthBackgroundAlpha = ReadHealthBackgroundAlpha(
                previous.bossLayout, defaults.bossLayout.healthBackgroundAlpha
            ),
            healthSpark = type(previous.bossLayout) ~= "table"
                or previous.bossLayout.healthSpark ~= false,
            forceOneBar = type(previous.bossLayout) == "table"
                and previous.bossLayout.forceOneBar == true,
            powerTextMode = ReadPowerTextMode(
                previous.bossLayout, defaults.bossLayout.powerTextMode
            ),
            powerColorMode = ReadPowerColorMode(
                previous.bossLayout, defaults.bossLayout.powerColorMode
            ),
            powerBackgroundAlpha = ReadPowerBackgroundAlpha(
                previous.bossLayout, defaults.bossLayout.powerBackgroundAlpha
            ),
            powerSpark = type(previous.bossLayout) ~= "table"
                or previous.bossLayout.powerSpark ~= false,
        },
        partyLayout = {
            scale = self:IsValidScale(type(previous.partyLayout) == "table" and previous.partyLayout.scale)
                and previous.partyLayout.scale or defaults.partyLayout.scale,
            growUpwards = type(previous.partyLayout) == "table"
                and previous.partyLayout.growUpwards == true or defaults.partyLayout.growUpwards,
            sort = type(previous.partyLayout) == "table"
                and (previous.partyLayout.sort == "role" or previous.partyLayout.sort == "name")
                and previous.partyLayout.sort or defaults.partyLayout.sort,
            visibility = type(previous.partyLayout) == "table"
                and (previous.partyLayout.visibility == "show" or previous.partyLayout.visibility == "hide")
                and previous.partyLayout.visibility or defaults.partyLayout.visibility,
            aurasLeft = type(previous.partyLayout) == "table"
                and previous.partyLayout.aurasLeft == true or defaults.partyLayout.aurasLeft,
            useInSmallRaid = ReadPartyUseInSmallRaid(previous.partyLayout),
            hideInRaid = ReadPartyHideInRaid(previous.partyLayout),
            rangeFade = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.rangeFade ~= false,
            rangeDistance = ReadRangeDistance(previous.partyLayout),
            outOfRangeAlpha = ReadOutOfRangeAlpha(previous.partyLayout),
            showDebuffs = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showDebuffs ~= false,
            showDispellableDebuffs = type(previous.partyLayout) == "table"
                and previous.partyLayout.showDispellableDebuffs == true,
            showPredictions = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showPredictions ~= false,
            showMaintenance = type(previous.partyLayout) == "table"
                and previous.partyLayout.showMaintenance == true,
            showThreat = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showThreat ~= false,
            showStatusText = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showStatusText ~= false,
            showRoleIcons = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showRoleIcons ~= false,
            showLeadership = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showLeadership ~= false,
            showTargetHighlight = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showTargetHighlight ~= false,
            showRaidMarkers = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.showRaidMarkers ~= false,
            healthTextMode = ReadHealthTextMode(
                previous.partyLayout, defaults.partyLayout.healthTextMode
            ),
            healthColorMode = ReadHealthColorMode(
                previous.partyLayout, defaults.partyLayout.healthColorMode
            ),
            healthBackgroundAlpha = ReadHealthBackgroundAlpha(
                previous.partyLayout, defaults.partyLayout.healthBackgroundAlpha
            ),
            healthSpark = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.healthSpark ~= false,
            powerTextMode = ReadPowerTextMode(
                previous.partyLayout, defaults.partyLayout.powerTextMode
            ),
            powerColorMode = ReadPowerColorMode(
                previous.partyLayout, defaults.partyLayout.powerColorMode
            ),
            powerBackgroundAlpha = ReadPowerBackgroundAlpha(
                previous.partyLayout, defaults.partyLayout.powerBackgroundAlpha
            ),
            powerSpark = type(previous.partyLayout) ~= "table"
                or previous.partyLayout.powerSpark ~= false,
            accountForIncomingHeals = type(previous.partyLayout) == "table"
                and previous.partyLayout.accountForIncomingHeals == true,
            displayProfile = ReadPartyDisplayProfile(previous.partyLayout),
        },
        raidLayout = {
            scale = self:IsValidScale(type(previous.raidLayout) == "table" and previous.raidLayout.scale)
                and previous.raidLayout.scale or defaults.raidLayout.scale,
            visibility = type(previous.raidLayout) == "table"
                and (previous.raidLayout.visibility == "show" or previous.raidLayout.visibility == "hide")
                and previous.raidLayout.visibility or defaults.raidLayout.visibility,
            useInParty = type(previous.raidLayout) == "table"
                and previous.raidLayout.useInParty == true or defaults.raidLayout.useInParty,
            showHeaders = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showHeaders ~= false,
            independentPositioning = type(previous.raidLayout) == "table"
                and previous.raidLayout.independentPositioning == true
                or defaults.raidLayout.independentPositioning,
            sort = type(previous.raidLayout) == "table"
                and (previous.raidLayout.sort == "role" or previous.raidLayout.sort == "name")
                and previous.raidLayout.sort or defaults.raidLayout.sort,
            healthTextMode = ReadHealthTextMode(
                previous.raidLayout, defaults.raidLayout.healthTextMode
            ),
            healthColorMode = ReadHealthColorMode(
                previous.raidLayout, defaults.raidLayout.healthColorMode
            ),
            healthBackgroundAlpha = ReadHealthBackgroundAlpha(
                previous.raidLayout, defaults.raidLayout.healthBackgroundAlpha
            ),
            healthSpark = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.healthSpark ~= false,
            accountForIncomingHeals = type(previous.raidLayout) == "table"
                and previous.raidLayout.accountForIncomingHeals == true,
            showDebuffs = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showDebuffs ~= false,
            showDispellableDebuffs = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showDispellableDebuffs ~= false,
            showMaintenance = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showMaintenance ~= false,
            showPredictions = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showPredictions ~= false,
            showHealAbsorbs = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showHealAbsorbs ~= false,
            showRoleIcons = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showRoleIcons ~= false,
            showLeadership = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showLeadership ~= false,
            showTargetHighlight = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showTargetHighlight ~= false,
            showStatusText = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showStatusText ~= false,
            showRaidMarkers = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showRaidMarkers ~= false,
            showThreat = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.showThreat ~= false,
            rangeFade = type(previous.raidLayout) ~= "table"
                or previous.raidLayout.rangeFade ~= false,
            rangeDistance = ReadRangeDistance(previous.raidLayout),
            outOfRangeAlpha = ReadOutOfRangeAlpha(
                previous.raidLayout,
                defaults.raidLayout.outOfRangeAlpha
            ),
            maintenanceDuration = ReadMaintenanceDuration(previous.raidLayout),
            displayProfile = ReadRaidDisplayProfile(previous.raidLayout),
            groupOffsets = {},
        },
        positions = {},
        themePlacements = {},
        themeSettings = {},
        frameSettings = {},
    }

    -- Named profiles are canonical presets. Any user-edited indicator marks
    -- the profile Custom, so it is safe to reapply named profiles here and it
    -- also migrates existing Tank users to the expanded Tank definition.
    if self.ApplyRaidDisplayProfileOptions then
        self:ApplyRaidDisplayProfileOptions(database.raidLayout, database.raidLayout.displayProfile)
    end
    if self.ApplyPartyDisplayProfileOptions then
        self:ApplyPartyDisplayProfileOptions(database.partyLayout, database.partyLayout.displayProfile)
    end

    -- Keep the legacy placement index for migration and for the movement code
    -- that updates cast bars directly. Complete user option sets are scoped in
    -- themeSettings below; existing profiles migrate into the active theme.
    if type(previous.themePlacements) == "table" then
        for themeId, placement in pairs(previous.themePlacements) do
            local theme = type(themeId) == "string" and self.themes[themeId]
            if theme and type(placement) == "table" then
                database.themePlacements[themeId] = {
                    positions = CopyThemePositions(theme, placement.positions),
                    groupOffsets = NormalizeRaidGroupOffsets(placement.groupOffsets),
                    castBarPositions = CopyCastBarPositions(placement.castBarPositions),
                }
            end
        end
    end

    if not database.themePlacements[selectedThemeId] then
        database.themePlacements[selectedThemeId] = {
            positions = CopyThemePositions(selectedTheme, previous.positions),
            groupOffsets = NormalizeRaidGroupOffsets(
                type(previous.raidLayout) == "table" and previous.raidLayout.groupOffsets
            ),
            castBarPositions = {},
        }
    end
    database.positions = database.themePlacements[selectedThemeId].positions
    database.raidLayout.groupOffsets = database.themePlacements[selectedThemeId].groupOffsets

    if type(previous.frameSettings) == "table" then
        for key, setting in pairs(previous.frameSettings) do
            if type(key) == "string" and type(setting) == "table" then
                local visibility = setting.visibility
                if visibility ~= "show" and visibility ~= "hide" then
                    visibility = "auto"
                end
                database.frameSettings[key] = {
                    visibility = visibility,
                    flipped = setting.flipped == true,
                    forceOneBar = setting.forceOneBar == true,
                    showThreatGlow = setting.showThreatGlow ~= false,
                    showPetThreat = setting.showPetThreat == true,
                    threatTextMode = setting.threatTextMode == "aggro"
                        and "aggro" or (setting.threatTextMode == "raw" and "raw" or "none"),
                    healthTextMode = ReadHealthTextMode(setting, "currentmax"),
                    healthColorMode = ReadHealthColorMode(setting, "unit"),
                    healthBackgroundAlpha = ReadHealthBackgroundAlpha(setting, 1),
                    healthSpark = setting.healthSpark ~= false,
                    powerTextMode = ReadPowerTextMode(setting, "currentmax"),
                    powerColorMode = ReadPowerColorMode(setting, "type"),
                    powerBackgroundAlpha = ReadPowerBackgroundAlpha(setting, 1),
                    powerSpark = setting.powerSpark ~= false,
                    buffsAbove = setting.buffsAbove == true,
                    aurasLeft = setting.aurasLeft == true,
                    hideCastBar = setting.hideCastBar == true,
                    hidePetHappiness = setting.hidePetHappiness == true,
                    petBarMode = setting.petBarMode == "healthOnly"
                        and "healthOnly" or "healthPower",
                    rangeFade = setting.rangeFade ~= false,
                    rangeDistance = ReadRangeDistance(setting),
                    outOfRangeAlpha = ReadOutOfRangeAlpha(setting),
                    classResourceVisibility = setting.classResourceVisibility == "hidden"
                        and "hidden" or "automatic",
                    classResourceIndependent = setting.classResourceIndependent == true,
                    classResourcePosition = type(setting.classResourcePosition) == "table"
                        and type(setting.classResourcePosition[1]) == "number"
                        and type(setting.classResourcePosition[2]) == "number"
                        and { setting.classResourcePosition[1], setting.classResourcePosition[2] }
                        or nil,
                    castBarIndependent = setting.castBarIndependent == true,
                    castBarPosition = database.themePlacements[selectedThemeId].castBarPositions[key],
                    independentPositioning = setting.independentPositioning == true,
                    scale = self:IsValidScale(setting.scale) and setting.scale or 1,
                    maxBuffs = ReadAuraLimit(setting.maxBuffs),
                    maxDebuffs = ReadAuraLimit(setting.maxDebuffs),
                }
            end
        end
    end

    if not buildingThemeOptions and self.InitializeActionsDatabase then
        self:InitializeActionsDatabase(previous, database)
    end

    if not buildingThemeOptions then
        -- Older releases kept only placement data per theme. The selected
        -- theme's top-level values remain the migration source of truth, while
        -- complete per-theme option sets from this schema are normalized with
        -- the same validation as an ordinary profile.
        if type(previous.themeSettings) == "table" then
            for themeId, options in pairs(previous.themeSettings) do
                if themeId ~= selectedThemeId and self.themes[themeId]
                    and type(options) == "table" then
                    local normalized = BuildProfile(
                        self,
                        ThemeOptionsProfileSource(themeId, options),
                        true
                    )
                    database.themeSettings[themeId] = CaptureThemeOptions(normalized, false)
                end
            end
        end
        database.themeSettings[selectedThemeId] = CaptureThemeOptions(database, false)
    end

    return database
end

local function TrimProfileName(name)
    if type(name) ~= "string" then return "" end
    return name:match("^%s*(.-)%s*$") or ""
end

local function ProfileNameExists(profiles, name, exceptName)
    local folded = name:lower()
    for existingName in pairs(profiles) do
        if existingName ~= exceptName and existingName:lower() == folded then
            return true
        end
    end
    return false
end

function PF:GetCharacterProfileKey()
    local characterName, characterRealm = UnitName("player")
    characterName = characterName or "Unknown"
    characterRealm = characterRealm or (GetRealmName and GetRealmName()) or "Unknown"
    return characterName .. " - " .. characterRealm
end

function PF:InitializeDatabase()
    local saved = type(PrettyFramesDB) == "table" and PrettyFramesDB or {}
    local database = { profiles = {}, profileKeys = {} }
    local hasProfileSchema = type(saved.profiles) == "table"
        and type(saved.profileKeys) == "table"

    if hasProfileSchema then
        for name, profile in pairs(saved.profiles) do
            if type(name) == "string" and name ~= "" and type(profile) == "table" then
                database.profiles[name] = BuildProfile(self, profile)
            end
        end
        for characterKey, profileName in pairs(saved.profileKeys) do
            if type(characterKey) == "string" and type(profileName) == "string"
                and database.profiles[profileName] then
                database.profileKeys[characterKey] = profileName
            end
        end
    end

    if not database.profiles.Default then
        database.profiles.Default = BuildProfile(self, {})
    end

    local characterKey = self:GetCharacterProfileKey()
    local profileName = database.profileKeys[characterKey]
    if not database.profiles[profileName] then profileName = "Default" end
    database.profileKeys[characterKey] = profileName

    PrettyFramesDB = database
    self.database = database
    self.profileName = profileName
    self.db = database.profiles[profileName]
end

function PF:GetProfileNames()
    local names = {}
    -- Legacy UIDropDownMenu_Initialize can invoke its initializer while Lua
    -- files are still loading, before ADDON_LOADED creates the database.
    if not self.database or type(self.database.profiles) ~= "table" then
        return names
    end
    for name in pairs(self.database.profiles) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return names
end

function PF:GetCurrentProfileName()
    return self.profileName or "Default"
end

function PF:IsProfileNameAvailable(name, exceptName)
    name = TrimProfileName(name)
    return name ~= "" and #name <= 64
        and not ProfileNameExists(self.database.profiles, name, exceptName)
end

function PF:SetProfile(name)
    if not self.database.profiles[name] then return false end
    self.database.profileKeys[self:GetCharacterProfileKey()] = name
    self.profileName = name
    self.db = self.database.profiles[name]
    return true
end

function PF:SetThemeOption(key, value)
    if not self.db then return end
    self.db[key] = value
    local options = self.db.themeSettings and self.db.themeSettings[self.db.theme]
    if options then options[key] = value end
end

function PF:PrepareThemeChange(themeId)
    local theme = type(themeId) == "string" and self.themes[themeId]
    if not theme or not self.db then return false end

    local currentThemeId = self.db.theme
    self.db.themePlacements = self.db.themePlacements or {}
    self.db.themeSettings = self.db.themeSettings or {}

    -- Scalar options (notably global scale) cannot remain linked to a theme
    -- table by reference, so snapshot every active option immediately before
    -- leaving. Nested option tables are intentionally retained as the active
    -- theme's live storage.
    self.db.themeSettings[currentThemeId] = CaptureThemeOptions(self.db, false)
    self.db.themePlacements[currentThemeId] = {
        positions = self.db.groupLayouts and self.db.groupLayouts.sharedPositions
            or self.db.positions,
        groupOffsets = self.db.raidLayout and self.db.raidLayout.groupOffsets,
        castBarPositions = GetCastBarPositions(self.db.frameSettings),
    }

    local options = self.db.themeSettings[themeId]
    if not options then
        -- A theme receives a complete independent copy of the theme being
        -- left on first use. Preserve placement-only data written by older
        -- releases, if present, while migrating it into the complete set.
        options = CaptureThemeOptions(self.db, true)
        local oldPlacement = self.db.themePlacements[themeId]
        options.positions = CopyThemePositions(
            theme,
            oldPlacement and oldPlacement.positions or self.db.positions
        )
        options.raidLayout.groupOffsets = NormalizeRaidGroupOffsets(
            oldPlacement and oldPlacement.groupOffsets
                or (self.db.raidLayout and self.db.raidLayout.groupOffsets)
        )
        local castBarPositions = CopyCastBarPositions(
            oldPlacement and oldPlacement.castBarPositions
                or GetCastBarPositions(self.db.frameSettings)
        )
        for key, setting in pairs(options.frameSettings or {}) do
            setting.castBarPosition = castBarPositions[key]
        end
        self.db.themeSettings[themeId] = options
    end

    ApplyThemeOptions(self.db, options)
    self.db.theme = themeId
    self.db.themePlacements[themeId] = {
        positions = self.db.positions,
        groupOffsets = self.db.raidLayout and self.db.raidLayout.groupOffsets,
        castBarPositions = GetCastBarPositions(self.db.frameSettings),
    }
    return true
end

function PF:CreateProfile(name)
    name = TrimProfileName(name)
    if not self:IsProfileNameAvailable(name) then return false end
    self.database.profiles[name] = BuildProfile(self, {})
    return self:SetProfile(name)
end

function PF:CopyProfile(sourceName)
    local source = self.database.profiles[sourceName]
    if not source or sourceName == self.profileName then return false end
    self.database.profiles[self.profileName] = BuildProfile(self, source)
    self.db = self.database.profiles[self.profileName]
    return true
end

function PF:RenameProfile(name)
    name = TrimProfileName(name)
    local oldName = self.profileName
    if oldName == "Default" or not self:IsProfileNameAvailable(name, oldName) then return false end
    if name == oldName then return true end
    self.database.profiles[name] = self.database.profiles[oldName]
    self.database.profiles[oldName] = nil
    for characterKey, profileName in pairs(self.database.profileKeys) do
        if profileName == oldName then self.database.profileKeys[characterKey] = name end
    end
    self.profileName = name
    return true
end

function PF:ResetProfile()
    self.database.profiles[self.profileName] = BuildProfile(self, {})
    self.db = self.database.profiles[self.profileName]
end

function PF:DeleteProfile(name)
    if name == "Default" or name == self.profileName or not self.database.profiles[name] then
        return false
    end
    self.database.profiles[name] = nil
    for characterKey, profileName in pairs(self.database.profileKeys) do
        if profileName == name then self.database.profileKeys[characterKey] = "Default" end
    end
    return true
end

