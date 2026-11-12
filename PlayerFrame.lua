local _, PF = ...

local MAX_AURAS = PF.MAX_AURAS or 40
local COMPACT_AURA_DEFAULT_LIMIT = 5
local CreateStatusBar = PF.Widgets.CreateStatusBar
local CreatePortrait = PF.Widgets.CreatePortrait
local CreateIndicator = PF.Widgets.CreateIndicator
local CreateUnitMarker = PF.Widgets.CreateUnitMarker
local SetSecureUnit = PF.Widgets.SetSecureUnit
local CreateAuraIcons = PF.Auras.CreateAuraIcons
local CreateDebuffIcons = PF.Auras.CreateDebuffIcons
local LayoutAuraGroups = PF.Auras.LayoutAuraGroups
local LayoutCompactAuras = PF.Auras.LayoutCompactAuras
local CreateUnitCastBar = PF.CastBars.CreateUnitCastBar
local themeLayout = PF:ThemeLayout("player")

local function UnifiedSkinTexture(frame)
    if frame.petPowerShown == false and frame.healthOnlyUnifiedSkinTexture then
        return frame.healthOnlyUnifiedSkinTexture
    end
    return frame.unifiedSkinTexture
end

local function ApplyPlayerPoints(frame, points, mirrored)
    PF:SetThemePoint(frame.portrait, frame, points.portrait)
    PF:SetThemePoint(frame.health, frame, points.healthLeft)
    PF:SetThemePoint(frame.health, frame, points.healthRight)
    PF:SetThemePoint(frame.power, frame, points.powerLeft)
    PF:SetThemePoint(frame.power, frame, points.powerRight)
    PF:SetThemePoint(frame.nameText, frame, points.nameLeft)
    PF:SetThemePoint(frame.nameText, frame, points.nameRight)
    PF:SetThemePoint(frame.levelIndicator, frame, points.level)
    PF:SetThemePoint(frame.classIndicator, frame, points.class)
    PF:SetThemePoint(frame.statusText, frame.health, points.status)
    frame.levelIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
    frame.classIndicator.ring:SetTexCoord(mirrored and 1 or 0, mirrored and 0 or 1, 0, 1)
end

local function ApplyAuraSafeHitRect(frame, auraLayout)
    -- Aura icons straddle the top edge of the secure unit button. Keep the
    -- Player hit rect below the deepest aura row so its unit tooltip and click
    -- handling cannot cover an aura button.
    local upperY = auraLayout and auraLayout[3] or 0
    local lowerY = auraLayout and auraLayout[4] or 0
    frame:SetHitRectInsets(0, 0, math.max(0, -upperY, -lowerY), 0)
end

local function FormatRestedXP(value)
    value = math.floor(value + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return tostring(value)
end

local function ShowRestedXPTooltip(indicator)
    GameTooltip:SetOwner(indicator, "ANCHOR_RIGHT")
    GameTooltip:SetText("Resting", 0.45, 0.75, 1.00)

    local restedXP = GetXPExhaustion and GetXPExhaustion()
    local levelXP = UnitXPMax and UnitXPMax("player")
    local restedIsSafe = PF:IsDisplaySafe(restedXP) and type(restedXP) == "number"
    local levelIsSafe = PF:IsDisplaySafe(levelXP) and type(levelXP) == "number"
    if restedIsSafe and restedXP > 0 then
        local restedLine = FormatRestedXP(restedXP) .. " rested XP"
        if levelIsSafe and levelXP > 0 then
            restedLine = restedLine .. (" (%.1f%% of this level)"):format(restedXP / levelXP * 100)
        end
        GameTooltip:AddLine(restedLine, 0.65, 0.85, 1.00)
        GameTooltip:AddLine(
            "Experience gained from killing monsters is increased by 100% until this bonus is consumed.",
            0.82, 0.82, 0.82, true
        )
    elseif levelIsSafe and levelXP <= 0 then
        GameTooltip:AddLine("Rested experience is unavailable at maximum level.", 0.82, 0.82, 0.82, true)
    else
        GameTooltip:AddLine("No rested experience is currently available.", 0.82, 0.82, 0.82, true)
        GameTooltip:AddLine(
            "Remain in an inn or capital city to accumulate rested experience.",
            0.65, 0.75, 0.85, true
        )
    end
    GameTooltip:Show()
end

local function ApplyUnifiedPlayerLayout(frame, flipped)
    local width = themeLayout.size[1]
    local layout = themeLayout.withPet
    frame.skinLayer:SetSize(width, themeLayout.withPetHeight)
    frame.skin:SetTexture(UnifiedSkinTexture(frame))
    local crop = themeLayout.withPetCrop
    frame.skin:SetTexCoord(flipped and crop[2] or crop[1], flipped and crop[1] or crop[2], crop[3], crop[4])
    frame.skin:SetAlpha(1)
    frame.standaloneOverlay:Hide()
    frame.portrait:SetDisplaySize(layout.portraitSize)
    if frame.portrait.SetBackgroundAsset then
        frame.portrait:SetBackgroundAsset(layout.portraitBackgroundAsset)
    end
    if frame.portrait.SetBackgroundLayout then
        frame.portrait:SetBackgroundLayout(
            layout.portraitBackgroundScaleX,
            layout.portraitBackgroundScaleY,
            layout.portraitBackgroundYOffset
        )
    end
    frame.portrait:SetVerticalOffset(0)
    if frame.portrait.SetClipsChildren then
        frame.portrait:SetClipsChildren(false)
    end
    frame.portrait.cameraDistanceScale = layout.cameraDistance
    if frame.portrait.model.SetCamDistanceScale then
        frame.portrait.model:SetCamDistanceScale(frame.portrait.cameraDistanceScale)
    end
    frame.health:SetHeight(layout.healthHeight)
    frame.power:SetHeight(layout.powerHeight)
    frame.moveLabel:ClearAllPoints()
    frame.moveLabel:SetPoint("TOP", frame, "TOP", 0, layout.moveLabelY)
    if frame.castBar then
        frame.castBar:ClearAllPoints()
        frame.castBar:SetPoint("TOP", frame, "TOP", unpack(layout.castBar))
        if PF.ApplyCastBarPosition then PF:ApplyCastBarPosition(frame) end
    end

    frame.portrait:ClearAllPoints()
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.nameText:ClearAllPoints()
    frame.levelIndicator:ClearAllPoints()
    frame.classIndicator:ClearAllPoints()
    frame.statusText:ClearAllPoints()

    local points = PF:ResolveThemePoints(layout, flipped)
    ApplyPlayerPoints(frame, points, flipped)
    frame.health:SetReverseFill(flipped)
    frame.power:SetReverseFill(flipped)

    local auras = PF:ResolveThemeValues(layout.auras, flipped, layout.mirrorAuraCorrections)
    LayoutAuraGroups(frame, flipped, auras[1], auras[2], auras[3], auras[4], auras[5])
    ApplyAuraSafeHitRect(frame, auras)

    local pet = frame.petFrame
    if not pet then return end
    pet:ClearAllPoints()
    pet.portrait:ClearAllPoints()
    if pet.unitMarkerHolder then pet.unitMarkerHolder:ClearAllPoints() end
    pet.health:ClearAllPoints()
    if pet.power then pet.power:ClearAllPoints() end
    pet.nameText:ClearAllPoints()
    pet.statusText:ClearAllPoints()
    if pet.happinessHolder then pet.happinessHolder:ClearAllPoints() end
    local petPoints = PF:ResolveThemePoints(
        layout, flipped, "petPoints", "petMirrorOverrides", "_resolvedPetMirrorPoints"
    )
    PF:SetThemePoint(pet, frame, petPoints.frame)
    PF:SetThemePoint(pet.portrait, pet, petPoints.portrait)
    local petLayout = themeLayout.pet
    pet.health:SetHeight(petLayout.healthHeight)
    if pet.power then pet.power:SetHeight(petLayout.powerHeight) end
    if pet.portrait.SetBackgroundAsset then
        pet.portrait:SetBackgroundAsset(petLayout.portraitBackgroundAsset)
    end
    if pet.portrait.SetBackgroundLayout then
        pet.portrait:SetBackgroundLayout(
            petLayout.portraitBackgroundScaleX,
            petLayout.portraitBackgroundScaleY,
            petLayout.portraitBackgroundYOffset
        )
    end
    pet.portrait.cameraDistanceScale = petLayout.cameraDistance or 0.88
    if pet.portrait.model.SetCamDistanceScale then
        pet.portrait.model:SetCamDistanceScale(pet.portrait.cameraDistanceScale)
    end
    if pet.unitMarkerHolder then
        local markerLayout = themeLayout.pet.marker
        local markerPoint = flipped and (markerLayout.mirrorPoint or PF:MirrorThemePoint(markerLayout.point))
            or markerLayout.point
        PF:SetThemePoint(pet.unitMarkerHolder, pet.portrait, markerPoint)
    end
    PF:SetThemePoint(pet.health, pet, petPoints.healthLeft)
    PF:SetThemePoint(pet.health, pet, petPoints.healthRight)
    if pet.power and petPoints.powerLeft and petPoints.powerRight then
        PF:SetThemePoint(pet.power, pet, petPoints.powerLeft)
        PF:SetThemePoint(pet.power, pet, petPoints.powerRight)
    end
    PF:SetThemePoint(pet.nameText, pet, petPoints.nameLeft)
    PF:SetThemePoint(pet.nameText, pet, petPoints.nameRight)
    PF:SetThemePoint(pet.statusText, pet.health, petPoints.status)
    if pet.happinessHolder then PF:SetThemePoint(pet.happinessHolder, pet.portrait, petPoints.happiness) end
    pet.health:SetReverseFill(flipped)
    if pet.power then pet.power:SetReverseFill(flipped) end
    pet.parentFlipped = flipped == true
    if pet.LayoutAuras then
        pet:LayoutAuras()
    end
end

local function ApplyStandalonePlayerLayout(frame, flipped, hiddenPetPreview)
    local width, height = unpack(themeLayout.size)
    local standaloneHeight = themeLayout.standaloneHeight or height
    local layout = themeLayout.standalone
    local mirrored = flipped == true
    if hiddenPetPreview then
        frame.skinLayer:SetSize(width, themeLayout.withPetHeight)
        frame.skin:SetTexture(UnifiedSkinTexture(frame))
        local crop = themeLayout.withPetCrop
        frame.skin:SetTexCoord(mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2], crop[3], crop[4])
        frame.skin:SetAlpha(0.5)
        local standaloneCrop = themeLayout.standaloneCrop
        frame.standaloneOverlay:SetSize(width, standaloneHeight)
        frame.standaloneOverlay:SetTexCoord(mirrored and standaloneCrop[2] or standaloneCrop[1], mirrored and standaloneCrop[1] or standaloneCrop[2], standaloneCrop[3], standaloneCrop[4])
        frame.standaloneOverlay:Show()
    else
        frame.skinLayer:SetSize(width, standaloneHeight)
        frame.skin:SetTexture(frame.standaloneSkinTexture)
        local crop = themeLayout.standaloneCrop
        frame.skin:SetTexCoord(mirrored and crop[2] or crop[1], mirrored and crop[1] or crop[2], crop[3], crop[4])
        frame.skin:SetAlpha(1)
        frame.standaloneOverlay:Hide()
    end
    frame.portrait:SetDisplaySize(layout.portraitSize)
    if frame.portrait.SetBackgroundAsset then
        frame.portrait:SetBackgroundAsset(layout.portraitBackgroundAsset)
    end
    if frame.portrait.SetBackgroundLayout then
        frame.portrait:SetBackgroundLayout(
            layout.portraitBackgroundScaleX,
            layout.portraitBackgroundScaleY,
            layout.portraitBackgroundYOffset
        )
    end
    frame.portrait:SetVerticalOffset(0)
    -- PlayerModel regions cannot use circular mask textures. Clip only the
    -- standalone Player model; the foreground ring hides the square corners.
    if frame.portrait.SetClipsChildren then
        frame.portrait:SetClipsChildren(true)
    end
    frame.portrait.cameraDistanceScale = layout.cameraDistance
    if frame.portrait.model.SetCamDistanceScale then
        frame.portrait.model:SetCamDistanceScale(frame.portrait.cameraDistanceScale)
    end
    frame.health:SetHeight(layout.healthHeight)
    frame.power:SetHeight(layout.powerHeight)
    frame.moveLabel:ClearAllPoints()
    if hiddenPetPreview then
        frame.moveLabel:SetPoint("TOP", frame, "TOP", 0, themeLayout.withPet.moveLabelY)
    else
        frame.moveLabel:SetPoint("TOP", frame, "TOP", 0, layout.moveLabelY or -standaloneHeight - 3)
    end
    if frame.castBar then
        frame.castBar:ClearAllPoints()
        local castBarOffsetX = hiddenPetPreview and 0 or (mirrored and -layout.castBarX or layout.castBarX)
        local castBarOffsetY = hiddenPetPreview and layout.hiddenPreviewCastBarY or layout.castBarY
        frame.castBar:SetPoint("TOP", frame, "TOP", castBarOffsetX, castBarOffsetY)
        if PF.ApplyCastBarPosition then PF:ApplyCastBarPosition(frame) end
    end

    frame.portrait:ClearAllPoints()
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.nameText:ClearAllPoints()
    frame.levelIndicator:ClearAllPoints()
    frame.classIndicator:ClearAllPoints()
    frame.statusText:ClearAllPoints()

    local points = PF:ResolveThemePoints(layout, mirrored)
    ApplyPlayerPoints(frame, points, mirrored)
    frame.health:SetReverseFill(mirrored)
    frame.power:SetReverseFill(mirrored)

    local auras = PF:ResolveThemeValues(layout.auras, mirrored, layout.mirrorAuraCorrections)
    LayoutAuraGroups(frame, mirrored, auras[1], auras[2], auras[3], auras[4], auras[5])
    ApplyAuraSafeHitRect(frame, auras)
end

function PF:CreateUnifiedPlayerFrame()
    -- This is intentionally one fixed-size Player+Pet composition.  Both units'
    -- live widgets sit beneath the same skin, eliminating overlay seams and drift.
    -- Keep the original 520x173 player anchor so saved positions and player data
    -- do not move; the unified 241px-tall artwork grows downward from its top.
    local width, height = unpack(themeLayout.size)
    local visualHeight = themeLayout.withPetHeight
    local frame = CreateFrame("Button", "PrettyFramesPlayer", UIParent,
        "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate,BackdropTemplate")
    frame.themeFrameName = "player"
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    SetSecureUnit(frame, "player")
    self:RegisterActionFrame(frame, "player")

    frame.isAnchor = true
    self.frames.player = frame
    self:PlaceFrame(frame, "player")
    self:MakeMovable(frame, "player")

    -- All art-aligned coordinates live in the selected theme's Theme.lua.
    local withPet = themeLayout.withPet
    local points = withPet.points
    frame.portrait = CreatePortrait(frame, withPet.portraitSize)
    PF:SetThemePoint(frame.portrait, frame, points.portrait)

    frame.health = CreateStatusBar(frame, withPet.healthHeight)
    PF:SetThemePoint(frame.health, frame, points.healthLeft)
    PF:SetThemePoint(frame.health, frame, points.healthRight)

    frame.power = CreateStatusBar(frame, withPet.powerHeight)
    PF:SetThemePoint(frame.power, frame, points.powerLeft)
    PF:SetThemePoint(frame.power, frame, points.powerRight)

    frame.skinLayer = CreateFrame("Frame", nil, frame)
    frame.skinLayer:SetSize(width, visualHeight)
    frame.skinLayer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.skinLayer:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.skinLayer:EnableMouse(false)
    frame.skin = frame.skinLayer:CreateTexture(nil, "ARTWORK")
    frame.skin:SetAllPoints(frame.skinLayer)
    frame.unifiedSkinTexture = self:ThemeFrameAsset("player", "playerFrameWithPet", "playerFrameWithPet")
    local activeTheme = self:GetTheme()
    local healthOnlyAsset = activeTheme and activeTheme.assets.playerFrameWithPetHealthOnly
    frame.healthOnlyUnifiedSkinTexture = healthOnlyAsset and (activeTheme.path .. healthOnlyAsset) or nil
    frame.standaloneSkinTexture = self:ThemeFrameAsset("player", "unitFrame", "unitFrame")
    frame.skin:SetTexture(frame.unifiedSkinTexture)
    frame.skin:SetTexCoord(unpack(themeLayout.withPetCrop))
    frame.standaloneOverlay = frame.skinLayer:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.standaloneOverlay:SetSize(width, themeLayout.standaloneHeight or height)
    frame.standaloneOverlay:SetPoint("TOPLEFT", frame.skinLayer, "TOPLEFT", 0, 0)
    frame.standaloneOverlay:SetTexture(frame.standaloneSkinTexture)
    frame.standaloneOverlay:SetTexCoord(unpack(themeLayout.standaloneCrop))
    frame.standaloneOverlay:Hide()

    frame.moveLabel:ClearAllPoints()
    frame.moveLabel:SetPoint("TOP", frame, "TOP", 0, -visualHeight - 3)

    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame)
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 21)
    frame.textLayer:EnableMouse(false)

    frame.unitMarker = CreateUnitMarker(
        frame.textLayer, themeLayout.marker.size, frame.portrait, themeLayout.marker.point
    )

    -- Anchor the custom resting emblem to the portrait so it follows both
    -- flipped and pet/no-pet layouts.
    frame.restingIndicator = CreateFrame("Frame", nil, frame.textLayer)
    frame.restingIndicator:SetSize(unpack(themeLayout.restingIndicator.size))
    PF:SetThemePoint(frame.restingIndicator, frame.portrait, themeLayout.restingIndicator.point)
    frame.restingIndicator:SetFrameLevel(frame.textLayer:GetFrameLevel() + 1)
    if frame.restingIndicator.EnableMouseMotion then
        frame.restingIndicator:EnableMouseMotion(true)
        if frame.restingIndicator.EnableMouseClick then
            frame.restingIndicator:EnableMouseClick(false)
        end
    else
        frame.restingIndicator:EnableMouse(true)
    end
    frame.restingIndicator.texture = frame.restingIndicator:CreateTexture(nil, "OVERLAY", nil, 4)
    frame.restingIndicator.texture:SetAllPoints(frame.restingIndicator)
    frame.restingIndicator.texture:SetTexture(
        self:ThemeFrameAsset("player", "restingIndicator", "restingIndicator")
    )
    frame.restingIndicator.texture:SetTexCoord(0, 1, 0, 1)
    frame.restingIndicator:SetScript("OnEnter", ShowRestedXPTooltip)
    frame.restingIndicator:SetScript("OnLeave", function(indicator)
        if not GameTooltip.IsOwned or GameTooltip:IsOwned(indicator) then GameTooltip:Hide() end
    end)
    frame.restingIndicator:Hide()

    frame.nameText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    PF:SetThemePoint(frame.nameText, frame, points.nameLeft)
    PF:SetThemePoint(frame.nameText, frame, points.nameRight)
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetTextColor(1, 0.91, 0.72)
    local nameFont, _, nameFlags = frame.nameText:GetFont()
    frame.nameText:SetFont(nameFont, 17, nameFlags)

    frame.healthText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.healthText:SetAllPoints(frame.health)
    frame.healthText:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(frame.healthText, math.max(9, math.min(12, withPet.healthHeight - 3)))

    frame.powerText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.powerText:SetAllPoints(frame.power)
    PF:ApplyBoldNumberFont(frame.powerText, math.max(8, math.min(11, withPet.powerHeight - 1)))

    frame.statusText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    PF:SetThemePoint(frame.statusText, frame.health, points.status)
    frame.statusText:SetTextColor(1, 0.35, 0.25)

    frame.levelIndicator = CreateIndicator(frame, themeLayout.levelSize or 40, true)
    PF:SetThemePoint(frame.levelIndicator, frame, points.level)
    frame.levelText = frame.levelIndicator.text

    frame.classIndicator = CreateIndicator(frame, themeLayout.classSize or 35, false)
    PF:SetThemePoint(frame.classIndicator, frame, points.class)
    frame.classIcon = frame.classIndicator.inner

    local playerAuraIconSize = themeLayout.auraIconSize or 29
    CreateAuraIcons(frame, MAX_AURAS, playerAuraIconSize, false)
    for index, aura in ipairs(frame.auras) do
        aura:ClearAllPoints()
        aura:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 396 + (index - 1) * 33, -55)
    end
    CreateDebuffIcons(frame, MAX_AURAS, playerAuraIconSize)
    for index, aura in ipairs(frame.debuffs) do
        aura:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 190 + (index - 1) * 33, -35)
    end

    table.insert(self.unitFrames, frame)

    -- The pet is a separate secure unit button for targeting and live data, but
    -- it owns no border art: its portrait and bars are framed by the player skin.
    local petLayout = themeLayout.pet
    local petPoints = themeLayout.withPet.petPoints
    local pet = CreateFrame("Button", "PrettyFramesPet", frame,
        "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate")
    pet.themeFrameName = "pet"
    pet:SetSize(unpack(petLayout.size))
    PF:SetThemePoint(pet, frame, petPoints.frame)
    pet:SetFrameLevel(frame:GetFrameLevel() + 1)
    pet:SetClampedToScreen(true)
    SetSecureUnit(pet, "pet")
    self:RegisterActionFrame(pet, "pet")

    pet.portrait = CreatePortrait(pet, petLayout.portraitSize)
    PF:SetThemePoint(pet.portrait, pet, petPoints.portrait)

    -- Forever exposes hunter-pet happiness through Blizzard's dedicated
    -- template rather than through the pet's helpful aura list. Keeping the
    -- template in its own holder preserves Blizzard's live icon and tooltip
    -- while allowing the user to hide it without affecting aura containers.
    local happinessHolder = CreateFrame("Frame", nil, pet)
    happinessHolder:SetSize(petLayout.happinessSize, petLayout.happinessSize)
    PF:SetThemePoint(happinessHolder, pet.portrait, petPoints.happiness)
    happinessHolder:SetFrameLevel(frame:GetFrameLevel() + 24)
    happinessHolder:EnableMouse(false)
    local happinessCreated, happinessIndicator = pcall(
        CreateFrame, "Frame", nil, happinessHolder, "PetFrameHappinessTemplate"
    )
    if happinessCreated and happinessIndicator then
        happinessIndicator:SetPoint("CENTER")
        happinessIndicator:SetFrameLevel(happinessHolder:GetFrameLevel() + 1)
        happinessHolder.indicator = happinessIndicator
        pet.happinessHolder = happinessHolder
        pet.SetPetHappinessShown = function(widget, shown)
            widget.happinessHolder:SetShown(shown == true)
        end
    else
        happinessHolder:Hide()
    end

    pet.health = CreateStatusBar(pet, petLayout.healthHeight)
    PF:SetThemePoint(pet.health, pet, petPoints.healthLeft)
    PF:SetThemePoint(pet.health, pet, petPoints.healthRight)

    if petLayout.powerHeight and petPoints.powerLeft and petPoints.powerRight then
        pet.power = CreateStatusBar(pet, petLayout.powerHeight)
        PF:SetThemePoint(pet.power, pet, petPoints.powerLeft)
        PF:SetThemePoint(pet.power, pet, petPoints.powerRight)
    end

    pet.textLayer = CreateFrame("Frame", nil, pet)
    pet.textLayer:SetAllPoints(pet)
    pet.textLayer:SetFrameLevel(frame:GetFrameLevel() + 22)
    pet.textLayer:EnableMouse(false)

    pet.unitMarker, pet.unitMarkerHolder = CreateUnitMarker(
        pet.textLayer, petLayout.marker.size, pet.portrait, petLayout.marker.point
    )

    pet.nameText = pet.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PF:SetThemePoint(pet.nameText, pet, petPoints.nameLeft)
    PF:SetThemePoint(pet.nameText, pet, petPoints.nameRight)
    pet.nameText:SetJustifyH("LEFT")
    pet.nameText:SetTextColor(1, 0.91, 0.72)
    local petNameFont, _, petNameFlags = pet.nameText:GetFont()
    pet.nameText:SetFont(petNameFont, 13, petNameFlags)

    pet.healthText = pet.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pet.healthText:SetAllPoints(pet.health)
    pet.healthText:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(pet.healthText, math.max(8, math.min(10, petLayout.healthHeight)))

    if pet.power then
        pet.powerText = pet.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pet.powerText:SetAllPoints(pet.power)
        PF:ApplyBoldNumberFont(pet.powerText, math.max(7, math.min(9, petLayout.powerHeight)))
    end

    pet.statusText = pet.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    PF:SetThemePoint(pet.statusText, pet.health, petPoints.status)
    pet.statusText:SetTextColor(1, 0.35, 0.25)

    CreateAuraIcons(pet, MAX_AURAS, petLayout.auraIconSize, false)
    CreateDebuffIcons(pet, MAX_AURAS, petLayout.auraIconSize)
    -- Keep the two Pet aura rows aligned with the dock while allowing each
    -- theme to place them just inside or fully outside the active edge.
    pet.compactAuraBuffY = petLayout.auraBuffY
    pet.compactAuraDebuffY = petLayout.auraDebuffY
    pet.compactAuraEdgeOverlap = petLayout.auraEdgeOverlap
    pet.compactAuraLeftEdgeOverlap = petLayout.auraLeftEdgeOverlap
    pet.defaultMaxBuffs = COMPACT_AURA_DEFAULT_LIMIT
    pet.defaultMaxDebuffs = COMPACT_AURA_DEFAULT_LIMIT
    pet.configuredAurasLeft = false
    pet.parentFlipped = false
    pet.LayoutAuras = function(widget)
        -- The saved option inverts the automatic mirrored side without being
        -- rewritten by the Player flip. Bar-side auras use the same inset in
        -- either orientation; portrait-side auras sit fully outside the art.
        widget.compactAuraActiveEdgeOverlap = widget.configuredAurasLeft
            and widget.compactAuraLeftEdgeOverlap
            or widget.compactAuraEdgeOverlap
        LayoutCompactAuras(widget, widget.configuredAurasLeft ~= widget.parentFlipped)
    end
    pet.SetAuraLimits = function(widget, maxBuffs, maxDebuffs)
        widget.maxBuffs = math.max(0, math.min(MAX_AURAS, maxBuffs or 0))
        widget.maxDebuffs = math.max(0, math.min(MAX_AURAS, maxDebuffs or 0))
        widget:LayoutAuras()
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
        if PF.RefreshNativeAuras then PF:RefreshNativeAuras(widget) end
    end
    pet.SetAurasLeft = function(widget, leftSide)
        widget.configuredAurasLeft = leftSide == true
        widget:LayoutAuras()
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
    end
    pet:LayoutAuras()

    frame.petFrame = pet
    self.frames.pet = pet
    frame.castBar = CreateUnitCastBar(
        frame, "player", petLayout.castBarSize[1], petLayout.castBarSize[2],
        nil, petLayout.castBarOrnamentExtraWidth, "player"
    )
    frame.petArtworkShown = true
    frame.petDisplayMode = "plus"
    frame.petPowerShown = true
    frame.SetFlipped = function(widget, flipped)
        widget.currentFlipped = flipped == true
        if widget.petDisplayMode == "plus" then
            ApplyUnifiedPlayerLayout(widget, widget.currentFlipped)
        elseif widget.petDisplayMode == "hiddenPreview" then
            ApplyStandalonePlayerLayout(widget, widget.currentFlipped, true)
        else
            ApplyStandalonePlayerLayout(widget, widget.currentFlipped, false)
        end
    end
    frame.SetBuffsAbove = function(widget, buffsAbove)
        widget.buffsAbove = buffsAbove == true
        widget:SetFlipped(widget.currentFlipped)
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
    end
    frame.defaultMaxBuffs = 3
    frame.defaultMaxDebuffs = 6
    frame.SetAuraLimits = function(widget, maxBuffs, maxDebuffs)
        widget.maxBuffs = math.max(0, math.min(MAX_AURAS, maxBuffs or 0))
        widget.maxDebuffs = math.max(0, math.min(MAX_AURAS, maxDebuffs or 0))
        widget:SetFlipped(widget.currentFlipped)
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
        if PF.RefreshNativeAuras then PF:RefreshNativeAuras(widget) end
    end
    frame.SetPetArtworkShown = function(widget, shown, hiddenPreview)
        local mode = hiddenPreview and "hiddenPreview" or (shown and "plus" or "minus")
        if widget.petDisplayMode == mode then
            widget.pendingPetDisplayMode = nil
            return
        end
        if InCombatLockdown() then
            widget.pendingPetDisplayMode = mode
            return
        end
        widget.pendingPetDisplayMode = nil
        widget.petDisplayMode = mode
        widget.petArtworkShown = mode == "plus"
        widget:SetFlipped(widget.currentFlipped)
    end
    if pet.power and frame.healthOnlyUnifiedSkinTexture then
        frame.SetPetPowerDisplay = function(widget, shown)
            widget.petPowerShown = shown == true
            pet.power:SetShown(widget.petPowerShown)
            if pet.powerText then pet.powerText:SetShown(widget.petPowerShown) end
            widget:SetFlipped(widget.currentFlipped)
        end
        pet.SetPetPowerShown = function(_, shown)
            frame:SetPetPowerDisplay(shown)
        end
    end
    ApplyUnifiedPlayerLayout(frame, false)
    self:RegisterFrameContextMenu(frame, "player")
    pet.OnVisibilityApplied = function(_, shown, visibility)
        local hiddenPreview = PF.db and not PF.db.locked and visibility == "hide"
        frame:SetPetArtworkShown(shown, hiddenPreview)
    end
    self:RegisterFrameContextMenu(pet, "pet")

    table.insert(self.unitFrames, pet)
    self:UpdatePlayerRestingIndicator()
    return frame
end

function PF:UpdatePlayerRestingIndicator()
    local frame = self.frames and self.frames.player
    if not frame or not frame.restingIndicator then return end

    local resting = IsResting and IsResting()
    frame.restingIndicator:SetShown(resting == true)
end

