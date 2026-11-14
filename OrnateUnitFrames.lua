local _, PF = ...

local MAX_AURAS = PF.MAX_AURAS or 40
local CreateStatusBar = PF.Widgets.CreateStatusBar
local CreatePortrait = PF.Widgets.CreatePortrait
local CreatePortraitGlow = PF.Widgets.CreatePortraitGlow
local CreateIndicator = PF.Widgets.CreateIndicator
local CreateUnitMarker = PF.Widgets.CreateUnitMarker
local SetSecureUnit = PF.Widgets.SetSecureUnit
local CreateAuraIcons = PF.Auras.CreateAuraIcons
local CreateDebuffIcons = PF.Auras.CreateDebuffIcons
local LayoutAuraGroups = PF.Auras.LayoutAuraGroups
local CreateUnitCastBar = PF.CastBars.CreateUnitCastBar
-- The shared texture's brightest band sits at roughly 81% of its radius.
-- A 1.24 scale places that band on the portrait opening instead of beneath
-- the asymmetric leaves and ornament surrounding it.
local TARGET_THREAT_GLOW_SCALE = 1.24

local function ApplyTargetThreatGlowPoint(frame, mirrored)
    if not frame.threatGlow then return end
    local offsetX = frame.threatGlowOffsetX or 0
    local offsetY = frame.threatGlowOffsetY or 0
    local visualOffsetX = mirrored and -offsetX or offsetX
    frame.threatGlow:ClearAllPoints()
    frame.threatGlow:SetPoint(
        "CENTER",
        frame.portrait,
        "CENTER",
        visualOffsetX,
        offsetY
    )
    if frame.threatText then
        frame.threatText:ClearAllPoints()
        frame.threatText:SetPoint(
            "BOTTOM",
            frame.portrait,
            "BOTTOM",
            visualOffsetX,
            4 + offsetY
        )
    end
end

local function SetScaledNamePoints(region, frame, width, height, scaled, mirrored)
    local corrections = scaled.mirrorCorrections or {}
    local left = mirrored and scaled.nameRight or scaled.nameLeft
    local right = mirrored and scaled.nameLeft or scaled.nameRight
    local leftInset = mirrored
        and scaled.nameRightInset + (corrections.nameLeftInset or 0)
        or scaled.nameLeftInset
    local rightInset = mirrored
        and scaled.nameLeftInset + (corrections.nameRightInset or 0)
        or scaled.nameRightInset
    local y = height * scaled.nameY + scaled.nameYOffset
    if mirrored then y = y + (corrections.nameYOffset or 0) end
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", width * left + leftInset, y)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(width * right + rightInset), y)
end

local function GetScaledBarInsets(scaled, mirrored)
    if mirrored then
        return scaled.healthRight, scaled.healthLeft, scaled.powerRight, scaled.powerLeft
    end
    return scaled.healthLeft, scaled.healthRight, scaled.powerLeft, scaled.powerRight
end

local function ApplyAuraSafeHitRect(frame, auraLayout)
    if frame.unit ~= "target" then return end

    -- The full Target aura rows straddle the frame's top edge. Crop the secure
    -- unit button below their deepest anchor so the Target tooltip and clicks
    -- never win mouse input over an aura button.
    local upperY = auraLayout and auraLayout[3] or 0
    local lowerY = auraLayout and auraLayout[4] or 0
    frame:SetHitRectInsets(0, 0, math.max(0, -upperY, -lowerY), 0)
end

local function ApplyCompactTargetTargetLayout(frame, mirrored)
    local themeLayout = frame.themeLayout
    local showPower = frame.compactShowPower ~= false
    local compact = themeLayout.targetOfTarget
    frame.isMirrored = mirrored

    local crop = compact.artCrop or themeLayout.artCrop
    local leftTexCoord, rightTexCoord = mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2]
    frame.skin:SetTexCoord(leftTexCoord, rightTexCoord, crop[3], crop[4])
    frame.oneBarSkin:SetTexCoord(leftTexCoord, rightTexCoord, crop[3], crop[4])

    frame.portrait:ClearAllPoints()
    frame.nameText:ClearAllPoints()
    frame.levelIndicator:ClearAllPoints()
    frame.classIndicator:ClearAllPoints()
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.statusText:ClearAllPoints()

    local points = PF:ResolveThemePoints(themeLayout.targetOfTarget, mirrored)
    PF:SetThemePoint(frame.portrait, frame, points.portrait)
    PF:SetThemePoint(frame.nameText, frame, points.nameLeft)
    PF:SetThemePoint(frame.nameText, frame, points.nameRight)
    PF:SetThemePoint(frame.levelIndicator, frame, points.level)
    PF:SetThemePoint(frame.classIndicator, frame, points.class)
    PF:SetThemePoint(frame.health, frame, showPower and points.healthLeft or points.healthLeftOneBar)
    PF:SetThemePoint(frame.health, frame, showPower and points.healthRight or points.healthRightOneBar)
    PF:SetThemePoint(frame.power, frame, points.powerLeft)
    PF:SetThemePoint(frame.power, frame, points.powerRight)
    PF:SetThemePoint(frame.statusText, frame.health, points.status)
    frame.levelIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
    frame.classIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)

    frame.health:SetReverseFill(mirrored)
    frame.power:SetReverseFill(mirrored)

    if frame.isBossFrame and PF.LayoutBossAuras then
        PF:LayoutBossAuras(frame)
    elseif compact.auras then
        local resolvedAuras = PF:ResolveThemeValues(
            compact.auras, mirrored, compact.mirrorAuraCorrections
        )
        LayoutAuraGroups(
            frame, mirrored,
            resolvedAuras[1], resolvedAuras[2], resolvedAuras[3],
            resolvedAuras[4], resolvedAuras[5]
        )
    end
end

local function ApplyOrnateLayout(frame, mirrored)
    local themeLayout = frame.themeLayout
    if frame.isCompactTargetTarget then
        ApplyCompactTargetTargetLayout(frame, mirrored)
        return
    end

    local width, height = frame.layoutWidth, frame.layoutHeight
    local fullSize = width == themeLayout.targetSize[1] and height == themeLayout.targetSize[2]
    local scaled = themeLayout.scaled
    local full = themeLayout.full
    local fullPoints = PF:ResolveThemePoints(full, mirrored)
    frame.isMirrored = mirrored

    frame.portrait:ClearAllPoints()
    if fullSize then
        PF:SetThemePoint(frame.portrait, frame, fullPoints.portrait)
    elseif mirrored then
        frame.portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -width * scaled.portraitX, height * scaled.portraitY)
    else
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", width * scaled.portraitX, height * scaled.portraitY)
    end
    ApplyTargetThreatGlowPoint(frame, mirrored)
    local crop = themeLayout.artCrop
    local leftTexCoord, rightTexCoord = mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2]
    frame.skin:SetTexCoord(leftTexCoord, rightTexCoord, crop[3], crop[4])
    frame.oneBarSkin:SetTexCoord(leftTexCoord, rightTexCoord, crop[3], crop[4])

    -- Optical corrections follow the visual orientation, not the unit token.
    frame.nameText:ClearAllPoints()
    if fullSize then
        PF:SetThemePoint(frame.nameText, frame, fullPoints.nameLeft)
        PF:SetThemePoint(frame.nameText, frame, fullPoints.nameRight)
    else
        SetScaledNamePoints(frame.nameText, frame, width, height, scaled, mirrored)
    end

    frame.levelIndicator:ClearAllPoints()
    frame.classIndicator:ClearAllPoints()
    if fullSize then
        PF:SetThemePoint(frame.levelIndicator, frame, fullPoints.level)
        PF:SetThemePoint(frame.classIndicator, frame, fullPoints.class)
        frame.levelIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
        frame.classIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
    elseif mirrored then
        frame.levelIndicator:SetPoint("CENTER", frame, "TOPRIGHT", -width * scaled.levelX, height * scaled.levelY)
        frame.classIndicator:SetPoint("CENTER", frame, "TOPRIGHT", -width * scaled.classX, height * scaled.classY)
        frame.levelIndicator.ring:SetTexCoord(1, 0, 0, 1)
        frame.classIndicator.ring:SetTexCoord(1, 0, 0, 1)
    else
        frame.levelIndicator:SetPoint("CENTER", frame, "TOPLEFT", width * scaled.levelX, height * scaled.levelY)
        frame.classIndicator:SetPoint("CENTER", frame, "TOPLEFT", width * scaled.classX, height * scaled.classY)
        frame.levelIndicator.ring:SetTexCoord(0, 1, 0, 1)
        frame.classIndicator.ring:SetTexCoord(0, 1, 0, 1)
    end

    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.statusText:ClearAllPoints()
    if fullSize then
        local showPower = frame.showPower ~= false
        frame.health:SetHeight(showPower and full.healthHeight
            or (full.healthHeightOneBar or full.healthHeight))
        PF:SetThemePoint(frame.health, frame,
            showPower and fullPoints.healthLeft or (fullPoints.healthLeftOneBar or fullPoints.healthLeft))
        PF:SetThemePoint(frame.health, frame,
            showPower and fullPoints.healthRight or (fullPoints.healthRightOneBar or fullPoints.healthRight))
        frame.power:SetHeight(full.powerHeight)
        PF:SetThemePoint(frame.power, frame, fullPoints.powerLeft)
        PF:SetThemePoint(frame.power, frame, fullPoints.powerRight)
        PF:SetThemePoint(frame.statusText, frame.health, fullPoints.status)
    else
        local healthLeft, healthRight, powerLeft, powerRight = GetScaledBarInsets(scaled, mirrored)
        healthLeft, healthRight = width * healthLeft, width * healthRight
        powerLeft, powerRight = width * powerLeft, width * powerRight
        frame.health:SetPoint("TOPLEFT", healthLeft, height * scaled.healthY)
        frame.health:SetPoint("TOPRIGHT", -healthRight, height * scaled.healthY)
        frame.power:SetPoint("TOPLEFT", powerLeft, height * scaled.powerY)
        frame.power:SetPoint("TOPRIGHT", -powerRight, height * scaled.powerY)
        frame.statusText:SetPoint("BOTTOMLEFT", width * (mirrored and 0.14 or 0.31), height * 0.17)
    end
    frame.health:SetReverseFill(mirrored)
    frame.power:SetReverseFill(mirrored)

    local auraLayout = fullSize and full or scaled
    local resolvedAuras = auraLayout.auras
        and PF:ResolveThemeValues(auraLayout.auras, mirrored, auraLayout.mirrorAuraCorrections)
    LayoutAuraGroups(
        frame,
        mirrored,
        resolvedAuras and resolvedAuras[1] or width * 0.365,
        resolvedAuras and resolvedAuras[2] or width * 0.79 - 15,
        resolvedAuras and resolvedAuras[3] or -height * 0.202,
        resolvedAuras and resolvedAuras[4] or -height * 0.29 - 5,
        resolvedAuras and resolvedAuras[5] or (mirrored and 10 or 0)
    )
    ApplyAuraSafeHitRect(frame, resolvedAuras or {
        nil, nil,
        -height * 0.202,
        -height * 0.29 - 5,
    })

    if frame.castBar then
        frame.castBar:ClearAllPoints()
        local castBarLayout = fullSize and full or scaled
        local castBarOffsetX = mirrored
            and -castBarLayout.castBarOffset[1] or castBarLayout.castBarOffset[1]
        frame.castBar:SetPoint(
            "TOP", frame, "BOTTOM", castBarOffsetX, castBarLayout.castBarOffset[2]
        )
        if PF.ApplyCastBarPosition then PF:ApplyCastBarPosition(frame) end
    end
end

function PF:CreateOrnateUnitFrame(name, unit, width, height, positionKey, mirrored, compactTargetTarget, options)
    options = options or {}
    local themeFrameName = options.themeFrame
        or (options.isBossFrame and "boss")
        or (compactTargetTarget and "targettarget")
        or unit
    local themeLayout = self:ThemeFrameLayout(themeFrameName, "unitFrames")
    local frame = CreateFrame("Button", name, UIParent,
        "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate,BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    SetSecureUnit(frame, unit)
    if not options.skipActionBehavior then
        self.FrameBehaviors:Attach("actions", frame, {
            category = options.actionCategory or positionKey or unit,
        })
    end
    frame.layoutWidth = width
    frame.layoutHeight = height
    frame.defaultMirrored = mirrored == true
    frame.isCompactTargetTarget = compactTargetTarget == true
    frame.isBossFrame = options.isBossFrame == true
    frame.themeFrameName = themeFrameName
    frame.themeLayout = themeLayout

    if positionKey then
        frame.isAnchor = true
        self.frames[positionKey] = frame
        self:PlaceFrame(frame, positionKey)
        self:MakeMovable(frame, positionKey)
    end

    local scaled = themeLayout.scaled
    local compact = themeLayout.targetOfTarget
    local fullSize = width == themeLayout.targetSize[1] and height == themeLayout.targetSize[2]
    local portraitDiameter = frame.isCompactTargetTarget and compact.portraitSize
        or (fullSize and themeLayout.full.portraitSize)
        or themeLayout.scaled.portraitSize
        or math.floor(height * 0.60)
    local contentLeft = width * (mirrored and 0.14 or 0.31)
    local contentRight = width * (mirrored and 0.31 or 0.14)

    frame.portrait = CreatePortrait(frame, portraitDiameter)
    if frame.portrait.SetBackgroundAsset then
        frame.portrait:SetBackgroundAsset(themeLayout.portraitBackgroundAsset)
    end
    if frame.portrait.SetBackgroundLayout then
        local portraitLayout = frame.isCompactTargetTarget and compact or themeLayout
        frame.portrait:SetBackgroundLayout(
            portraitLayout.portraitBackgroundScaleX or themeLayout.portraitBackgroundScaleX,
            portraitLayout.portraitBackgroundScaleY or themeLayout.portraitBackgroundScaleY,
            portraitLayout.portraitBackgroundYOffset
                or themeLayout.portraitBackgroundYOffset
        )
    end
    frame.portrait.cameraDistanceScale = (frame.isCompactTargetTarget
            and compact.portraitCameraDistance)
        or themeLayout.portraitCameraDistance or 0.88
    if frame.portrait.model.SetCamDistanceScale then
        frame.portrait.model:SetCamDistanceScale(frame.portrait.cameraDistanceScale)
    end
    if mirrored then
        frame.portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -width * scaled.portraitX, height * scaled.portraitY)
    else
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", width * scaled.portraitX, height * scaled.portraitY)
    end

    if unit == "target" or unit == "focus" then
        frame.hasThreatDisplay = true
        local threatLayout = fullSize and themeLayout.full or themeLayout.scaled
        frame.threatGlow = CreatePortraitGlow(
            frame.portrait,
            math.floor(
                portraitDiameter * (threatLayout.threatGlowScale or TARGET_THREAT_GLOW_SCALE) + 0.5
            )
        )
        frame.threatGlowOffsetX = threatLayout.threatGlowOffsetX or 0
        frame.threatGlowOffsetY = threatLayout.threatGlowOffsetY or 0
        ApplyTargetThreatGlowPoint(frame, mirrored)
        frame.threatGlow.texture:SetAlpha(0.64)
    end

    frame.skinLayer = CreateFrame("Frame", nil, frame)
    frame.skinLayer:SetAllPoints(frame)
    frame.skinLayer:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.skinLayer:EnableMouse(false)
    frame.skin = frame.skinLayer:CreateTexture(nil, "ARTWORK")
    frame.skin:SetAllPoints(frame.skinLayer)
    local twoBarRole = frame.isCompactTargetTarget and "targetOfTargetFrame" or "unitFrame"
    local oneBarRole = frame.isCompactTargetTarget and "targetOfTargetFrameOneBar" or "unitFrameOneBar"
    frame.twoBarSkinTexture = self:ThemeFrameAsset(themeFrameName, twoBarRole, twoBarRole)
    frame.oneBarSkinTexture = self:ThemeFrameAsset(themeFrameName, oneBarRole, oneBarRole)
    frame.skin:SetTexture(frame.twoBarSkinTexture)
    local crop = frame.isCompactTargetTarget and (compact.artCrop or themeLayout.artCrop)
        or themeLayout.artCrop
    frame.skin:SetTexCoord(mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2], crop[3], crop[4])
    frame.skin:SetAlpha(1)
    frame.oneBarSkin = frame.skinLayer:CreateTexture(nil, "ARTWORK")
    frame.oneBarSkin:SetAllPoints(frame.skinLayer)
    frame.oneBarSkin:SetTexture(frame.oneBarSkinTexture)
    frame.oneBarSkin:SetTexCoord(mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2], crop[3], crop[4])
    frame.oneBarSkin:SetAlpha(0)

    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame)
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 21)
    frame.textLayer:EnableMouse(false)

    if frame.hasThreatDisplay then
        frame.threatText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.threatText:SetJustifyH("CENTER")
        frame.threatText:SetTextColor(1, 0.88, 0.20)
        frame.threatText:SetShadowColor(0, 0, 0, 1)
        frame.threatText:SetShadowOffset(1, -1)
        PF:ApplyBoldNumberFont(frame.threatText, math.max(10, math.floor(portraitDiameter * 0.13)))
        ApplyTargetThreatGlowPoint(frame, mirrored)
        frame.threatText:Hide()
    end

    local markerLayout = frame.isCompactTargetTarget and themeLayout.targetOfTarget.marker
        or (height == themeLayout.targetSize[2] and themeLayout.full.marker or themeLayout.scaled.marker)
    frame.unitMarker = CreateUnitMarker(
        frame.textLayer, markerLayout.size, frame.portrait, markerLayout.point
    )

    frame.nameText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    -- Name corrections follow portrait-right versus portrait-left layout.
    SetScaledNamePoints(frame.nameText, frame, width, height, scaled, mirrored)
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetTextColor(1, 0.91, 0.72)
    local nameFont, _, nameFlags = frame.nameText:GetFont()
    frame.nameText:SetFont(nameFont,
        frame.isCompactTargetTarget and 12 or math.max(10, math.floor(height * 0.10)), nameFlags)

    local levelIndicatorSize = frame.isCompactTargetTarget and compact.levelSize
        or (fullSize and (themeLayout.full.levelSize or math.max(30, math.floor(height * 0.24))))
        or math.max(30, math.floor(height * 0.24))
    local classIndicatorSize = frame.isCompactTargetTarget and compact.classSize
        or (fullSize and (themeLayout.full.classSize or math.max(28, math.floor(height * 0.20))))
        or scaled.classSize
        or math.max(28, math.floor(height * 0.20))
    frame.levelIndicator = CreateIndicator(frame, levelIndicatorSize, true)
    if mirrored then
        frame.levelIndicator:SetPoint("CENTER", frame, "TOPRIGHT", -width * scaled.levelX, height * scaled.levelY)
        frame.levelIndicator.ring:SetTexCoord(1, 0, 0, 1)
    else
        frame.levelIndicator:SetPoint("CENTER", frame, "TOPLEFT", width * scaled.levelX, height * scaled.levelY)
    end
    frame.levelText = frame.levelIndicator.text
    if frame.isCompactTargetTarget then
        -- The compact artwork contains its own level ring.
        frame.levelIndicator.ring:Hide()
        PF:ApplyBoldNumberFont(frame.levelText, 11)
    end

    frame.classIndicator = CreateIndicator(frame, classIndicatorSize, false)
    if mirrored then
        frame.classIndicator:SetPoint("CENTER", frame, "TOPRIGHT", -width * scaled.classX, height * scaled.classY)
        frame.classIndicator.ring:SetTexCoord(1, 0, 0, 1)
    else
        frame.classIndicator:SetPoint("CENTER", frame, "TOPLEFT", width * scaled.classX, height * scaled.classY)
    end
    if frame.isCompactTargetTarget then
        frame.classIndicator.inner:SetSize(20, 20)
    end
    frame.classIcon = frame.classIndicator.inner

    -- Bar coordinates track the selected theme's transparent artwork openings.
    local healthLeft, healthRight, powerLeft, powerRight = GetScaledBarInsets(scaled, mirrored)
    healthLeft, healthRight = width * healthLeft, width * healthRight
    powerLeft, powerRight = width * powerLeft, width * powerRight
    local healthHeight = frame.isCompactTargetTarget and (compact.healthHeight or compact.barHeight)
        or (fullSize and themeLayout.full.healthHeight)
        or scaled.healthHeight
        or math.max(10, math.floor(height * 0.117))
    local powerHeight = frame.isCompactTargetTarget and (compact.powerHeight or compact.barHeight)
        or (fullSize and themeLayout.full.powerHeight)
        or scaled.powerHeight
        or math.max(10, math.floor(height * 0.123))
    frame.health = CreateStatusBar(frame, healthHeight)
    frame.health:SetPoint("TOPLEFT", healthLeft, height * scaled.healthY)
    frame.health:SetPoint("TOPRIGHT", -healthRight, height * scaled.healthY)
    frame.health:SetReverseFill(mirrored or false)

    frame.healthText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.healthText:SetAllPoints(frame.health)
    frame.healthText:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(frame.healthText, math.max(8, math.min(12, healthHeight - 3)))

    frame.power = CreateStatusBar(frame, powerHeight)
    frame.power:SetPoint("TOPLEFT", powerLeft, height * scaled.powerY)
    frame.power:SetPoint("TOPRIGHT", -powerRight, height * scaled.powerY)
    frame.power:SetReverseFill(mirrored or false)

    frame.powerText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.powerText:SetAllPoints(frame.power)
    PF:ApplyBoldNumberFont(frame.powerText, math.max(8, math.min(11, powerHeight - 1)))

    frame.statusText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.statusText:SetPoint("BOTTOMLEFT", contentLeft, height * 0.17)
    frame.statusText:SetTextColor(1, 0.35, 0.25)

    if frame.isCompactTargetTarget then
        frame.ApplyPowerLayout = function(widget, showPower)
            widget.compactShowPower = showPower == true
            ApplyCompactTargetTargetLayout(widget, widget.isMirrored)
        end
    elseif unit == "target" or unit == "focus" or options.dynamicPowerLayout then
        frame.ApplyPowerLayout = function(widget, showPower)
            widget.showPower = showPower == true
            ApplyOrnateLayout(widget, widget.isMirrored)
        end
    end

    local auraLayout = frame.isCompactTargetTarget and compact
        or (fullSize and themeLayout.full or scaled)
    local auraIconSize = options.auraIconSize
        or auraLayout.auraIconSize or math.floor(height * 0.17)
    local aurasEnabled = options.aurasEnabled
    if aurasEnabled == nil then aurasEnabled = auraLayout.aurasEnabled end
    if aurasEnabled == nil then aurasEnabled = height >= 125 end
    local auraCount = options.auraCount or MAX_AURAS
    if aurasEnabled then
        CreateAuraIcons(frame, auraCount, auraIconSize, mirrored)
        if frame.isCompactTargetTarget then
            CreateDebuffIcons(frame, auraCount, auraIconSize)
        end
    end
    if unit == "target" or unit == "focus" or options.createCastBar then
        if options.debuffsEnabled ~= false then
            CreateDebuffIcons(frame, auraCount, auraIconSize)
        end
        local updateEvent = options.castBarUpdateEvent
            or (unit == "target" and "PLAYER_TARGET_CHANGED")
            or (unit == "focus" and "PLAYER_FOCUS_CHANGED")
        local castBarLayout = width == themeLayout.targetSize[1]
            and height == themeLayout.targetSize[2] and themeLayout.full or themeLayout.scaled
        local castBarSize = options.castBarSize or castBarLayout.castBarSize
        frame.castBar = CreateUnitCastBar(
            frame,
            unit,
            castBarSize[1],
            castBarSize[2],
            updateEvent,
            options.castBarOrnamentExtraWidth or castBarLayout.castBarOrnamentExtraWidth,
            frame.themeFrameName
        )
        local castBarOffset = options.castBarOffset or castBarLayout.castBarOffset
        local castBarOffsetX = mirrored and -castBarOffset[1] or castBarOffset[1]
        frame.castBar:SetPoint(
            "TOP", frame, "BOTTOM", castBarOffsetX, castBarOffset[2]
        )
    end

    frame.SetFlipped = function(widget, flipped)
        ApplyOrnateLayout(widget, widget.defaultMirrored ~= flipped)
    end
    frame.SetBuffsAbove = frame.debuffs and not options.manageBossAuras and function(widget, buffsAbove)
        widget.buffsAbove = buffsAbove == true
        ApplyOrnateLayout(widget, widget.isMirrored)
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
    end or nil
    if (frame.auras or frame.debuffs) and not options.manageBossAuras then
        frame.defaultMaxBuffs = auraLayout.defaultMaxBuffs
            or (frame.auras and 3 or 0)
        frame.defaultMaxDebuffs = auraLayout.defaultMaxDebuffs
            or (frame.debuffs and 6 or 0)
        frame.SetAuraLimits = function(widget, maxBuffs, maxDebuffs)
            widget.maxBuffs = math.max(0, math.min(MAX_AURAS, maxBuffs or 0))
            widget.maxDebuffs = math.max(0, math.min(MAX_AURAS, maxDebuffs or 0))
            ApplyOrnateLayout(widget, widget.isMirrored)
            if PF.UpdateAuras then PF:UpdateAuras(widget) end
            if PF.RefreshNativeAuras then PF:RefreshNativeAuras(widget) end
        end
    end
    ApplyOrnateLayout(frame, frame.defaultMirrored)
    if options.settingKey then frame.settingKey = options.settingKey end
    if not options.skipContextMenu then
        self:RegisterFrameContextMenu(frame, options.settingKey or positionKey or unit)
    end

    table.insert(self.unitFrames, frame)
    return frame
end
