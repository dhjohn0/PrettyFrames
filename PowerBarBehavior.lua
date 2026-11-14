local _, PF = ...

local TEXT_MODES = {
    { id = "current", label = "Current" },
    { id = "maximum", label = "Maximum" },
    { id = "currentmax", label = "Current / Maximum" },
    { id = "percent", label = "Percentage" },
    { id = "currentpercent", label = "Current + Percentage" },
    { id = "none", label = "Hidden" },
}

local COLOR_MODES = {
    { id = "type", label = "Power Type" },
    { id = "class", label = "Class Color" },
    { id = "gradient", label = "Power Gradient" },
    { id = "theme", label = "Theme Blue" },
    { id = "red", label = "Rage Red" },
    { id = "yellow", label = "Energy Yellow" },
}

local BACKGROUND_ALPHAS = {
    { id = 0, label = "Hidden" },
    { id = 0.25, label = "25%" },
    { id = 0.5, label = "50%" },
    { id = 0.75, label = "75%" },
    { id = 1, label = "Opaque" },
}

local TYPE_COLORS = {
    [0] = { 0.05, 0.35, 0.82 },
    [1] = { 0.82, 0.10, 0.08 },
    [2] = { 0.90, 0.45, 0.08 },
    [3] = { 0.92, 0.82, 0.12 },
    [6] = { 0.00, 0.82, 1.00 },
    [11] = { 0.15, 0.58, 1.00 },
    [13] = { 0.30, 0.52, 0.90 },
    [17] = { 0.78, 0.20, 0.92 },
    [18] = { 0.25, 0.78, 0.52 },
}

local PowerBarBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuOrder = 55,
    contextMenuGroup = { key = "power", title = "Power" },
}
PF.PowerBarBehavior = PF.FrameBehaviors:Register("powerBar", PowerBarBehavior)
PowerBarBehavior.textModes = TEXT_MODES
PowerBarBehavior.colorModes = COLOR_MODES
PowerBarBehavior.backgroundAlphas = BACKGROUND_ALPHAS

local function ValidatePair(options, getter, setter)
    if options[getter] == nil and options[setter] == nil then return end
    assert(type(options[getter]) == "function",
        "power bar behavior requires " .. getter)
    assert(type(options[setter]) == "function",
        "power bar behavior requires " .. setter)
end

function PowerBarBehavior:ValidateAttachment(_, options)
    assert(type(options.getMode) == "function",
        "power bar behavior requires getMode")
    assert(type(options.setMode) == "function",
        "power bar behavior requires setMode")
    assert(type(options.getColorMode) == "function",
        "power bar behavior requires getColorMode")
    assert(type(options.setColorMode) == "function",
        "power bar behavior requires setColorMode")
    assert(type(options.getBackgroundAlpha) == "function",
        "power bar behavior requires getBackgroundAlpha")
    assert(type(options.setBackgroundAlpha) == "function",
        "power bar behavior requires setBackgroundAlpha")
    assert(type(options.apply) == "function",
        "power bar behavior requires apply")
    ValidatePair(options, "getSparkShown", "setSparkShown")
    ValidatePair(options, "getOneBar", "setOneBar")
end

function PowerBarBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredChangeKey = attachment.deferredChangeKey or {}
end

function PowerBarBehavior:GetTypeColor(powerType)
    if PF:IsDisplaySafe(powerType) then
        return TYPE_COLORS[powerType] or PF.colors.power
    end
    return PF.colors.power
end

function PowerBarBehavior:ResolveColor(
    frame, power, powerMax, powerType, mode, fallback
)
    fallback = fallback or self:GetTypeColor(powerType)
    if mode == "theme" then return unpack(PF.colors.power) end
    if mode == "red" then return 0.82, 0.10, 0.08 end
    if mode == "yellow" then return 0.92, 0.82, 0.12 end
    if mode == "class" and frame and frame.unit then
        local isPlayer = UnitIsPlayer(frame.unit)
        if PF:IsDisplaySafe(isPlayer) and isPlayer == true then
            local _, classFile = UnitClass(frame.unit)
            local color = PF:IsDisplaySafe(classFile) and RAID_CLASS_COLORS
                and RAID_CLASS_COLORS[classFile]
            if color then return color.r, color.g, color.b end
        end
    elseif mode == "gradient" and PF:IsDisplaySafe(power)
        and PF:IsDisplaySafe(powerMax) and powerMax > 0 then
        local ratio = math.max(0, math.min(1, power / powerMax))
        return 1 - ratio * 0.85, 0.18 + ratio * 0.62, 0.10 + ratio * 0.72
    end
    return fallback[1], fallback[2], fallback[3]
end

function PowerBarBehavior:ApplyBar(
    frame, power, powerMax, powerType, fallbackColor
)
    if not frame or not frame.power then return end
    local attachment = self:GetAttachment(frame)
    local options = attachment and attachment.options
    local r, g, b = self:ResolveColor(
        frame, power, powerMax, powerType,
        options and options.getColorMode() or "type", fallbackColor
    )
    frame.power:SetStatusBarColor(r, g, b)
    if frame.power.background and options then
        frame.power.background:SetAlpha(options.getBackgroundAlpha())
    end
    if frame.power.spark and options and options.getSparkShown then
        frame.power.spark:SetShown(options.getSparkShown() == true)
    end
end

function PowerBarBehavior:UpdateText(frame, power, powerMax)
    if not frame or not frame.powerText then return end
    local attachment = self:GetAttachment(frame)
    local options = attachment and attachment.options
    local mode = options and options.getMode() or "currentmax"
    local text
    if mode == "current" or mode == "maximum" then
        local value = mode == "current" and power or powerMax
        text = PF:FormatNumber(value)
        if not text then
            frame.powerText:SetFormattedText("%s", value)
            return
        end
    elseif mode == "currentmax" then
        local currentText = PF:FormatNumber(power)
        local maxText = PF:FormatNumber(powerMax)
        if currentText and maxText then
            text = currentText .. " / " .. maxText
        else
            frame.powerText:SetFormattedText("%s / %s", power, powerMax)
            return
        end
    elseif mode == "percent" and PF:IsDisplaySafe(power)
        and PF:IsDisplaySafe(powerMax) and powerMax > 0 then
        text = math.floor((power / powerMax) * 100 + 0.5) .. "%"
    elseif mode == "currentpercent" and PF:IsDisplaySafe(power)
        and PF:IsDisplaySafe(powerMax) and powerMax > 0 then
        text = PF:FormatNumber(power) .. " ("
            .. math.floor((power / powerMax) * 100 + 0.5) .. "%)"
    end
    frame.powerText:SetText(text or "")
end

function PowerBarBehavior:ResolveShown(frame, powerMax, powerType)
    local attachment = self:GetAttachment(frame)
    local options = attachment and attachment.options
    if not options or not options.getOneBar then return nil end
    local shown = options.getOneBar() ~= true
    if shown and PF:IsDisplaySafe(powerMax) then
        shown = powerMax > 0
    elseif shown and UnitHasPowerType and PF:IsDisplaySafe(powerType) then
        local hasPower = UnitHasPowerType(frame.unit, powerType)
        if PF:IsDisplaySafe(hasPower) then
            if not hasPower then
                shown = false
            else
                local isPlayer = UnitIsPlayer(frame.unit)
                shown = not PF:IsDisplaySafe(isPlayer) or isPlayer == true
            end
        end
    end
    return shown
end

function PowerBarBehavior:ApplyShown(frame, shown)
    if shown == nil or not frame or not frame.power then return end
    frame.skin:SetAlpha(shown and 1 or 0)
    frame.oneBarSkin:SetAlpha(shown and 0 or 1)
    frame.power:SetShown(shown)
    if frame.power.background then frame.power.background:SetShown(shown) end
    if frame.powerText then frame.powerText:SetShown(shown) end
    frame.power:SetAlpha(1)
    if frame.power.background then frame.power.background:SetAlpha(1) end
    if frame.powerText then frame.powerText:SetAlpha(1) end
    if frame.ApplyPowerLayout then frame:ApplyPowerLayout(shown) end
end

function PowerBarBehavior:UpdateFrame(frame, power, powerMax, powerType)
    if not frame or not frame.power then return end
    local color = self:GetTypeColor(powerType)
    self:ApplyShown(frame, self:ResolveShown(frame, powerMax, powerType))
    self:ApplyBar(frame, power, powerMax, powerType, color)
    self:UpdateText(frame, power, powerMax)
end

function PowerBarBehavior:ClearFrame(frame)
    if not frame or not frame.power then return end
    local attachment = self:GetAttachment(frame)
    local options = attachment and attachment.options
    if options and options.getOneBar then
        self:ApplyShown(frame, options.getOneBar() ~= true)
    end
    self:ApplyBar(frame, 0, 1, 0, PF.colors.power)
    if frame.powerText then frame.powerText:SetText("") end
end

function PowerBarBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function() return attachment.options.apply() end,
        attachment
    )
end

function PowerBarBehavior:SetOneBar(attachment, enabled)
    local options = attachment and attachment.options
    if not options or not options.getOneBar
        or options.getOneBar() == enabled then return false end
    if InCombatLockdown() then
        PF:Print("power bar layout changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredChangeKey,
        function()
            if options.getOneBar() == enabled then return true end
            options.setOneBar(enabled)
            return options.apply()
        end,
        attachment
    )
end

local function IsChoiceSupported(choices, value)
    for _, choice in ipairs(choices) do
        if choice.id == value then return true end
    end
    return false
end

function PowerBarBehavior:SetVisualOption(
    attachment, getter, setter, choices, value
)
    local options = attachment and attachment.options
    if not options or not IsChoiceSupported(choices, value)
        or options[getter]() == value then return false end
    options[setter](value)
    self:Refresh(attachment)
    return true
end

function PowerBarBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options
    rootDescription:CreateTitle("Text")
    local function IsTextSelected(value) return options.getMode() == value end
    local function SetTextSelected(value)
        self:SetVisualOption(attachment, "getMode", "setMode", TEXT_MODES, value)
    end
    for _, choice in ipairs(TEXT_MODES) do
        rootDescription:CreateRadio(
            choice.label, IsTextSelected, SetTextSelected, choice.id
        )
    end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle("Bar Color")
    local function IsColorSelected(value) return options.getColorMode() == value end
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

    if options.getSparkShown then
        rootDescription:CreateCheckbox("Show Bar Spark", function()
            return options.getSparkShown() == true
        end, function()
            options.setSparkShown(options.getSparkShown() ~= true)
            self:Refresh(attachment)
        end)
    end

    if options.getOneBar then
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(
            options.label or "Force One-Bar Layout",
            function() return options.getOneBar() == true end,
            function()
                self:SetOneBar(attachment, options.getOneBar() ~= true)
            end
        )
    end
end

function PowerBarBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not frame.power or not frame.powerText or not settingKey then return end
    local isMember = settingKey:match("^party%d+$") or frame.isBossFrame
    local options = {
        contextMenuScope = isMember and "individual" or "move",
        getMode = function()
            return PF:GetFrameSetting(settingKey).powerTextMode
        end,
        setMode = function(value)
            PF:GetFrameSetting(settingKey).powerTextMode = value
        end,
        getColorMode = function()
            return PF:GetFrameSetting(settingKey).powerColorMode
        end,
        setColorMode = function(value)
            PF:GetFrameSetting(settingKey).powerColorMode = value
        end,
        getBackgroundAlpha = function()
            return PF:GetFrameSetting(settingKey).powerBackgroundAlpha
        end,
        setBackgroundAlpha = function(value)
            PF:GetFrameSetting(settingKey).powerBackgroundAlpha = value
        end,
        getSparkShown = frame.power.spark and function()
            return PF:GetFrameSetting(settingKey).powerSpark ~= false
        end or nil,
        setSparkShown = frame.power.spark and function(value)
            PF:GetFrameSetting(settingKey).powerSpark = value == true
        end or nil,
        apply = function() return PF:UpdateUnitFrame(frame, true) end,
    }
    if frame.oneBarSkinTexture then
        options.label = frame.isBossFrame and "Hide Power Bar"
            or "Force One-Bar Layout"
        options.getOneBar = function()
            return PF:GetFrameSetting(settingKey).forceOneBar == true
        end
        options.setOneBar = function(value)
            PF:GetFrameSetting(settingKey).forceOneBar = value == true
        end
    end
    return PF.FrameBehaviors:Attach("powerBar", frame, options)
end
