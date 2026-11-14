local _, PF = ...

local DEFAULT_MODES = {
    { id = "deficit", label = "Missing Health" },
    { id = "percent", label = "Percentage" },
    { id = "current", label = "Current" },
    { id = "maximum", label = "Maximum" },
    { id = "currentmax", label = "Current / Maximum" },
    { id = "currentpercent", label = "Current + Percentage" },
    { id = "none", label = "Hidden" },
}

local COLOR_MODES = {
    { id = "unit", label = "Unit Color" },
    { id = "class", label = "Class Color" },
    { id = "reaction", label = "Reaction Color" },
    { id = "gradient", label = "Health Gradient" },
    { id = "green", label = "Always Green" },
}

local BACKGROUND_ALPHAS = {
    { id = 0, label = "Hidden" },
    { id = 0.25, label = "25%" },
    { id = 0.5, label = "50%" },
    { id = 0.75, label = "75%" },
    { id = 1, label = "Opaque" },
}

local percentCurve
if C_CurveUtil and C_CurveUtil.CreateCurve then
    percentCurve = C_CurveUtil.CreateCurve()
    percentCurve:AddPoint(0, 0)
    percentCurve:AddPoint(1, 100)
end

local HealthTextBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuScope = "move",
    contextMenuOrder = 50,
    contextMenuGroup = { key = "health", title = "Health" },
}
PF.HealthTextBehavior = PF.FrameBehaviors:Register("healthText", HealthTextBehavior)
PF.HealthBehavior = HealthTextBehavior
HealthTextBehavior.textModes = DEFAULT_MODES
HealthTextBehavior.colorModes = COLOR_MODES
HealthTextBehavior.backgroundAlphas = BACKGROUND_ALPHAS

function HealthTextBehavior:ValidateAttachment(_, options)
    assert(type(options.getMode) == "function",
        "health text behavior requires getMode")
    assert(type(options.setMode) == "function",
        "health text behavior requires setMode")
    assert(type(options.refresh) == "function",
        "health text behavior requires refresh")
    if options.getIncomingHeals ~= nil or options.setIncomingHeals ~= nil then
        assert(type(options.getIncomingHeals) == "function",
            "health text behavior requires getIncomingHeals")
        assert(type(options.setIncomingHeals) == "function",
            "health text behavior requires setIncomingHeals")
    end
    for _, pair in ipairs({
        { "getColorMode", "setColorMode" },
        { "getBackgroundAlpha", "setBackgroundAlpha" },
        { "getSparkShown", "setSparkShown" },
    }) do
        if options[pair[1]] ~= nil or options[pair[2]] ~= nil then
            assert(type(options[pair[1]]) == "function",
                "health behavior requires " .. pair[1])
            assert(type(options[pair[2]]) == "function",
                "health behavior requires " .. pair[2])
        end
    end
end

function HealthTextBehavior:ResolveReactionColor(unit)
    if not unit then return end

    -- A neutral faction member can become an active enemy without its base
    -- faction reaction changing. Check the live relationship before mapping
    -- the numeric reaction.
    local isEnemy = UnitIsEnemy and UnitIsEnemy("player", unit)
    if PF:IsDisplaySafe(isEnemy) and isEnemy == true then
        return 0.72, 0.12, 0.10
    end

    -- Attackability is not the same as reaction: passive neutral mobs are
    -- attackable too. UnitReaction keeps those mobs yellow, then changes them
    -- to a hostile reaction on clients that expose the live relationship.
    local reaction = UnitReaction and UnitReaction("player", unit)
    if PF:IsDisplaySafe(reaction) then
        if reaction <= 3 then return 0.72, 0.12, 0.10 end
        if reaction == 4 then
            -- Some clients retain reaction 4 after engagement. Presence on the
            -- player's threat table distinguishes that case from an untouched
            -- neutral mob; status 0 is still an active threat-table entry.
            local threat = UnitThreatSituation
                and UnitThreatSituation("player", unit)
            if PF:IsDisplaySafe(threat) then
                return 0.72, 0.12, 0.10
            end
            -- Forever can protect or omit threat values in combat. The paired
            -- combat flags provide a non-numeric fallback without turning a
            -- neutral mob red merely because somebody else engaged it.
            local playerInCombat = UnitAffectingCombat
                and UnitAffectingCombat("player")
            local unitInCombat = UnitAffectingCombat
                and UnitAffectingCombat(unit)
            if PF:IsDisplaySafe(playerInCombat) and playerInCombat == true
                and PF:IsDisplaySafe(unitInCombat) and unitInCombat == true then
                return 0.72, 0.12, 0.10
            end
            return 0.78, 0.58, 0.12
        end
        return unpack(PF.colors.health)
    end

    -- Fall back to the boolean relationship APIs when reaction values are
    -- unavailable or protected. Unlike UnitCanAttack, UnitIsEnemy does not
    -- classify an unprovoked neutral unit as hostile.
    local isFriend = UnitIsFriend("player", unit)
    if PF:IsDisplaySafe(isFriend) and isFriend == true then
        return unpack(PF.colors.health)
    elseif PF:IsDisplaySafe(isEnemy) and PF:IsDisplaySafe(isFriend) then
        return 0.78, 0.58, 0.12
    end
end

function HealthTextBehavior:ResolveColor(unit, health, healthMax, mode, fallback)
    fallback = fallback or PF.colors.health
    if mode == "green" then return unpack(PF.colors.health) end
    if mode == "class" and unit then
        local isPlayer = UnitIsPlayer(unit)
        if PF:IsDisplaySafe(isPlayer) and isPlayer == true then
            local _, classFile = UnitClass(unit)
            local color = PF:IsDisplaySafe(classFile) and RAID_CLASS_COLORS
                and RAID_CLASS_COLORS[classFile]
            if color then return color.r, color.g, color.b end
        end
    elseif mode == "reaction" and unit then
        local r, g, b = self:ResolveReactionColor(unit)
        if r then return r, g, b end
    elseif mode == "gradient" and PF:IsDisplaySafe(health)
        and PF:IsDisplaySafe(healthMax) and healthMax > 0 then
        local ratio = math.max(0, math.min(1, health / healthMax))
        return math.min(1, 2 - ratio * 2), math.min(1, ratio * 2), 0.08
    end
    return fallback[1], fallback[2], fallback[3]
end

function HealthTextBehavior:ApplyBar(
    frame, health, healthMax, fallbackColor, dead, overrideOptions
)
    if not frame then return end
    local attachment = self:GetAttachment(frame)
    local options = overrideOptions or (attachment and attachment.options)
    local healthBar = options and options.getBar and options.getBar(frame) or frame.health
    if not healthBar then return end
    local unit = options and options.getUnit and options.getUnit(frame) or frame.unit
    local r, g, b
    if dead then
        r, g, b = unpack(PF.colors.dead)
    else
        r, g, b = self:ResolveColor(
            unit, health, healthMax,
            options and options.getColorMode and options.getColorMode() or "unit",
            fallbackColor
        )
    end
    healthBar:SetStatusBarColor(r, g, b)
    local background = options and options.getBackground
        and options.getBackground(frame) or healthBar.background
    if background and options and options.getBackgroundAlpha then
        background:SetAlpha(options.getBackgroundAlpha())
    end
    if healthBar.spark and options and options.getSparkShown then
        healthBar.spark:SetShown(options.getSparkShown() == true)
    end
end

function HealthTextBehavior:UpdateFrame(
    frame, health, healthMax, fallbackColor, dead, overrideOptions
)
    if not frame then return end
    local attachment = self:GetAttachment(frame)
    local options = overrideOptions or (attachment and attachment.options)
    local healthText = options and options.getText and options.getText(frame) or frame.healthText
    local unit = options and options.getUnit and options.getUnit(frame) or frame.unit
    local mode = options and options.getMode() or "currentmax"
    local accountForIncomingHeals = options and options.getIncomingHeals
        and options.getIncomingHeals() == true
    local text

    self:ApplyBar(frame, health, healthMax, fallbackColor, dead, options)

    if not healthText then return end

    local function GetIncomingHeals()
        if accountForIncomingHeals and options.getIncomingHealAmount then
            return options.getIncomingHealAmount(frame, healthMax, PF.testMode == true)
        end
    end

    if mode == "deficit" then
        local accountedForIncomingHeals = false
        if accountForIncomingHeals and PF:IsDisplaySafe(health)
            and PF:IsDisplaySafe(healthMax) then
            local incomingHeals = GetIncomingHeals()
            if PF:IsDisplaySafe(incomingHeals) then
                local missingHealth = math.max(0, healthMax - health - incomingHeals)
                text = missingHealth > 0 and "-" .. PF:FormatNumber(missingHealth) or nil
                accountedForIncomingHeals = true
            end
        end

        if accountedForIncomingHeals then
            -- A fully covered deficit intentionally leaves the text blank.
        elseif not PF.testMode and UnitHealthMissing and C_StringUtil
            and C_StringUtil.WrapString and C_StringUtil.TruncateWhenZero then
            healthText:SetText(C_StringUtil.WrapString(
                C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)), "-"
            ))
            if options and options.afterTextUpdated then
                options.afterTextUpdated(frame, true)
            end
            return
        elseif PF:IsDisplaySafe(health) and PF:IsDisplaySafe(healthMax)
            and healthMax > health then
            text = "-" .. PF:FormatNumber(healthMax - health)
        end
    elseif mode == "percent" then
        if not PF.testMode and UnitHealthPercent and percentCurve and C_StringUtil
            and C_StringUtil.RoundToNearestString then
            healthText:SetText(C_StringUtil.RoundToNearestString(
                UnitHealthPercent(unit, true, percentCurve)
            ) .. "%")
            if options and options.afterTextUpdated then
                options.afterTextUpdated(frame, true)
            end
            return
        elseif PF:IsDisplaySafe(health) and PF:IsDisplaySafe(healthMax)
            and healthMax > 0 then
            text = math.floor((health / healthMax) * 100 + 0.5) .. "%"
        end
    elseif mode == "current" or mode == "maximum" then
        local value = mode == "current" and health or healthMax
        local valueText = PF:FormatNumber(value)
        if valueText then
            text = valueText
        else
            healthText:SetFormattedText("%s", value)
            if options and options.afterTextUpdated then
                options.afterTextUpdated(frame, true)
            end
            return
        end
    elseif mode == "currentmax" then
        local currentText = PF:FormatNumber(health)
        local maxText = PF:FormatNumber(healthMax)
        if currentText and maxText then
            local incomingText
            local incomingHeals = GetIncomingHeals()
            if PF:IsDisplaySafe(incomingHeals) and incomingHeals > 0 then
                incomingText = PF:FormatNumber(incomingHeals)
            end
            text = currentText .. (incomingText and " (+" .. incomingText .. ")" or "")
                .. " / " .. maxText
        else
            healthText:SetFormattedText("%s / %s", health, healthMax)
            if options and options.afterTextUpdated then
                options.afterTextUpdated(frame, true)
            end
            return
        end
    elseif mode == "currentpercent" then
        local currentText = PF:FormatNumber(health)
        if currentText and PF:IsDisplaySafe(healthMax) and healthMax > 0 then
            text = currentText .. " ("
                .. math.floor((health / healthMax) * 100 + 0.5) .. "%)"
        elseif not PF.testMode and UnitHealthPercent and percentCurve then
            healthText:SetFormattedText(
                "%s (%s%%)", health, UnitHealthPercent(unit, true, percentCurve)
            )
            if options and options.afterTextUpdated then
                options.afterTextUpdated(frame, true)
            end
            return
        end
    end

    healthText:SetText(text or "")
    if options and options.afterTextUpdated then
        options.afterTextUpdated(frame, text ~= nil and text ~= "")
    end
end

function HealthTextBehavior:Apply(attachment)
    if attachment then return attachment.options.refresh() end
end

function HealthTextBehavior:MarkChanged(attachment)
    if attachment.options.markChanged then attachment.options.markChanged() end
end

function HealthTextBehavior:SetMode(attachment, mode)
    if not attachment then return false end
    local modes = attachment.options.modes or DEFAULT_MODES
    local supported = false
    for _, choice in ipairs(modes) do
        if choice.id == mode then
            supported = true
            break
        end
    end
    if not supported or attachment.options.getMode() == mode then return false end
    attachment.options.setMode(mode)
    self:MarkChanged(attachment)
    self:Refresh(attachment)
    return true
end

function HealthTextBehavior:SetIncomingHeals(attachment, enabled)
    if not attachment or not attachment.options.setIncomingHeals
        or attachment.options.getIncomingHeals() == enabled then return false end
    attachment.options.setIncomingHeals(enabled)
    self:MarkChanged(attachment)
    self:Refresh(attachment)
    return true
end

local function IsChoiceSupported(choices, value)
    for _, choice in ipairs(choices) do
        if choice.id == value then return true end
    end
    return false
end

function HealthTextBehavior:SetVisualOption(
    attachment, getter, setter, choices, value
)
    if not attachment or not attachment.options[getter]
        or not IsChoiceSupported(choices, value)
        or attachment.options[getter]() == value then return false end
    attachment.options[setter](value)
    self:Refresh(attachment)
    return true
end

function HealthTextBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options
    rootDescription:CreateTitle("Text")
    local function IsSelected(value) return options.getMode() == value end
    local function SetSelected(value) self:SetMode(attachment, value) end
    for _, choice in ipairs(options.modes or DEFAULT_MODES) do
        rootDescription:CreateRadio(
            choice.label, IsSelected, SetSelected, choice.id
        )
    end

    if options.getIncomingHeals then
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(
            options.incomingHealsLabel or "Account for Incoming Heals",
            function() return options.getIncomingHeals() == true end,
            function()
                self:SetIncomingHeals(
                    attachment, options.getIncomingHeals() ~= true
                )
            end
        )
    end

    if options.getColorMode then
        rootDescription:CreateDivider()
        rootDescription:CreateTitle("Bar Color")
        local function IsColorSelected(value)
            return options.getColorMode() == value
        end
        local function SetColorSelected(value)
            self:SetVisualOption(
                attachment, "getColorMode", "setColorMode", COLOR_MODES, value
            )
        end
        for _, choice in ipairs(COLOR_MODES) do
            rootDescription:CreateRadio(
                choice.label, IsColorSelected, SetColorSelected, choice.id
            )
        end
    end

    if options.getBackgroundAlpha then
        local backgroundMenu = rootDescription:CreateButton("Background Opacity")
        local function IsAlphaSelected(value)
            return options.getBackgroundAlpha() == value
        end
        local function SetAlphaSelected(value)
            self:SetVisualOption(
                attachment, "getBackgroundAlpha", "setBackgroundAlpha",
                BACKGROUND_ALPHAS, value
            )
        end
        for _, choice in ipairs(BACKGROUND_ALPHAS) do
            backgroundMenu:CreateRadio(
                choice.label, IsAlphaSelected, SetAlphaSelected, choice.id
            )
        end
    end

    if options.getSparkShown then
        rootDescription:CreateCheckbox("Show Bar Spark", function()
            return options.getSparkShown() == true
        end, function()
            options.setSparkShown(options.getSparkShown() ~= true)
            self:Refresh(attachment)
        end)
    end
end

function HealthTextBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not frame.health or not frame.healthText or not settingKey then return end
    return PF.FrameBehaviors:Attach("healthText", frame, {
        contextMenuScope = (settingKey:match("^party%d+$") or frame.isBossFrame)
            and "individual" or "move",
        getMode = function()
            return PF:GetFrameSetting(settingKey).healthTextMode
        end,
        setMode = function(value)
            PF:GetFrameSetting(settingKey).healthTextMode = value
        end,
        getColorMode = function()
            return PF:GetFrameSetting(settingKey).healthColorMode
        end,
        setColorMode = function(value)
            PF:GetFrameSetting(settingKey).healthColorMode = value
        end,
        getBackgroundAlpha = function()
            return PF:GetFrameSetting(settingKey).healthBackgroundAlpha
        end,
        setBackgroundAlpha = function(value)
            PF:GetFrameSetting(settingKey).healthBackgroundAlpha = value
        end,
        getSparkShown = frame.health.spark and function()
            return PF:GetFrameSetting(settingKey).healthSpark ~= false
        end or nil,
        setSparkShown = frame.health.spark and function(value)
            PF:GetFrameSetting(settingKey).healthSpark = value == true
        end or nil,
        refresh = function() return PF:UpdateUnitFrame(frame, false) end,
    })
end
