local _, PF = ...

local layout = PF:ThemeLayout("widgets")

PF.Widgets = PF.Widgets or {}
local Widgets = PF.Widgets

local function FindThemeFrameName(region)
    while region do
        if region.themeFrameName then return region.themeFrameName end
        region = region.GetParent and region:GetParent()
    end
end

local function HasFrameAsset(frameName, role)
    local theme = PF:GetTheme()
    local frame = frameName and theme.resolvedFrames and theme.resolvedFrames[frameName]
    return (frame and frame.art and frame.art[role]) or theme.assets[role]
end

local function FrameAsset(region, role)
    local frameName = FindThemeFrameName(region)
    if frameName then return PF:ThemeFrameAsset(frameName, role, role) end
    return PF:ThemeAsset(role)
end

local function ForEachFadedRegion(frame, callback)
    local regions = frame and frame.availabilityFadeRegions
    if not regions then
        if frame then callback(frame) end
        return
    end

    for _, region in pairs(regions) do
        if region then callback(region) end
    end
    for _, group in pairs(frame.availabilityFadeRegionGroups or {}) do
        for _, region in pairs(group) do
            if region then callback(region) end
        end
    end
end

local function SetAvailabilityAlpha(frame, alpha)
    ForEachFadedRegion(frame, function(region)
        region:SetAlpha(alpha)
    end)
    frame.availabilityAlpha = alpha
end

local function SetRangeAlpha(frame, inRange, outOfRangeAlpha)
    if issecretvalue and issecretvalue(inRange) then
        ForEachFadedRegion(frame, function(region)
            if region.SetAlphaFromBoolean then
                region:SetAlphaFromBoolean(inRange, 1, outOfRangeAlpha)
            end
        end)
        frame.availabilityAlpha = nil
    elseif inRange == nil then
        SetAvailabilityAlpha(frame, 1)
    elseif PF:IsDisplaySafe(inRange) then
        SetAvailabilityAlpha(frame, inRange == false and outOfRangeAlpha or 1)
    end
end

local function CreateStatusBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar:SetStatusBarTexture(FrameAsset(parent, "statusBar"))
    bar:SetFrameLevel(parent:GetFrameLevel() + 2)

    bar.background = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar.background:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    bar.background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    bar.background:SetColorTexture(0.025, 0.018, 0.012, 1)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetSize(18, height * 2.2)
    bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.spark:SetAlpha(0.28)

    return bar
end

local function CreatePortrait(parent, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder.themeFrameName = FindThemeFrameName(parent)
    holder:SetSize(size, size)
    holder:SetFrameLevel(parent:GetFrameLevel() + 2)
    holder:EnableMouse(false)

    local background = holder:CreateTexture(nil, "BACKGROUND")
    local hasCustomBackground = HasFrameAsset(holder.themeFrameName, "portraitBackground")
    local defaultBackgroundRole = hasCustomBackground and "portraitBackground" or "portraitFrame"
    local backgroundScaleX = layout.portraitBackgroundScaleX or layout.portraitFrameScale
    local backgroundScaleY = layout.portraitBackgroundScaleY or layout.portraitFrameScale
    local backgroundYOffset = size * (layout.portraitBackgroundYOffset or 0)
    background:SetSize(size * backgroundScaleX, size * backgroundScaleY)
    background:SetPoint("CENTER", holder, "CENTER", 0, backgroundYOffset)
    background:SetTexture(FrameAsset(holder, defaultBackgroundRole))

    local backgroundMask = holder:CreateMaskTexture()
    backgroundMask:SetAllPoints(background)
    backgroundMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not hasCustomBackground then
        background:AddMaskTexture(backgroundMask)
    end

    local fallback = holder:CreateTexture(nil, "ARTWORK")
    fallback:SetAllPoints(holder)
    fallback:SetTexCoord(0.04, 0.96, 0.04, 0.96)

    local fallbackMask = holder:CreateMaskTexture()
    fallbackMask:SetAllPoints(fallback)
    fallbackMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fallback:AddMaskTexture(fallbackMask)

    local model = CreateFrame("PlayerModel", nil, holder)
    model:SetSize(size * layout.portraitModelScale, size * layout.portraitModelScale)
    model:SetPoint("CENTER", holder, "CENTER", 0, size * layout.portraitModelYOffset)
    model:SetFrameLevel(holder:GetFrameLevel() + 1)
    model:EnableMouse(false)
    model:SetPortraitZoom(1)
    if model.SetCamDistanceScale then
        model:SetCamDistanceScale(0.88)
    end

    holder.model = model
    holder.background = background
    holder.backgroundMask = backgroundMask
    holder.fallback = fallback
    holder.fallbackMask = fallbackMask
    holder.modelRequested = false
    holder.modelReady = false
    holder.backgroundScaleX = backgroundScaleX
    holder.backgroundScaleY = backgroundScaleY
    holder.backgroundYOffset = layout.portraitBackgroundYOffset or 0
    holder.backgroundMaskApplied = not hasCustomBackground
    model.prettyFramesPortrait = holder
    model:SetScript("OnModelLoaded", function(widget)
        local portrait = widget.prettyFramesPortrait
        if PF.PortraitBehavior then
            PF.PortraitBehavior:OnModelLoaded(portrait)
        end
    end)
    holder.SetDisplaySize = function(widget, newSize)
        widget:SetSize(newSize, newSize)
        widget.background:SetSize(newSize * widget.backgroundScaleX, newSize * widget.backgroundScaleY)
        widget.background:ClearAllPoints()
        widget.background:SetPoint("CENTER", widget, "CENTER", 0, newSize * widget.backgroundYOffset)
        widget.model:SetSize(newSize * layout.portraitModelScale, newSize * layout.portraitModelScale)
        widget.model:ClearAllPoints()
        widget.model:SetPoint("CENTER", widget, "CENTER", 0, newSize * layout.portraitModelYOffset)
    end
    holder.SetVerticalOffset = function(widget, offset)
        local portraitSize = widget:GetHeight()
        widget.background:ClearAllPoints()
        widget.background:SetPoint("CENTER", widget, "CENTER", 0, offset + portraitSize * widget.backgroundYOffset)
        widget.model:ClearAllPoints()
        widget.model:SetPoint("CENTER", widget, "CENTER", 0, portraitSize * layout.portraitModelYOffset + offset)
    end
    holder.SetBackgroundLayout = function(widget, scaleX, scaleY, yOffset)
        widget.backgroundScaleX = scaleX or layout.portraitBackgroundScaleX or layout.portraitFrameScale
        widget.backgroundScaleY = scaleY or layout.portraitBackgroundScaleY or layout.portraitFrameScale
        if yOffset == nil then yOffset = layout.portraitBackgroundYOffset or 0 end
        widget.backgroundYOffset = yOffset
        local portraitSize = widget:GetHeight()
        widget.background:SetSize(portraitSize * widget.backgroundScaleX, portraitSize * widget.backgroundScaleY)
        widget.background:ClearAllPoints()
        widget.background:SetPoint("CENTER", widget, "CENTER", 0, portraitSize * widget.backgroundYOffset)
    end
    holder.SetBackgroundAsset = function(widget, assetRole)
        local resolvedRole = assetRole
            or (HasFrameAsset(widget.themeFrameName, "portraitBackground")
                and "portraitBackground" or "portraitFrame")
        widget.background:SetTexture(FrameAsset(widget, resolvedRole))
        local needsMask = resolvedRole == "portraitFrame"
        if needsMask and not widget.backgroundMaskApplied then
            widget.background:AddMaskTexture(widget.backgroundMask)
            widget.backgroundMaskApplied = true
        elseif not needsMask and widget.backgroundMaskApplied then
            widget.background:RemoveMaskTexture(widget.backgroundMask)
            widget.backgroundMaskApplied = false
        end
    end
    return holder
end

local function CreatePortraitGlow(portrait, size, texturePath)
    local parent = portrait:GetParent()
    local glow = CreateFrame("Frame", nil, parent)
    glow:SetSize(size, size)
    glow:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    glow:SetFrameLevel((portrait.model and portrait.model:GetFrameLevel() or portrait:GetFrameLevel()) + 1)
    glow:EnableMouse(false)

    glow.texture = glow:CreateTexture(nil, "OVERLAY")
    glow.texture:SetAllPoints(glow)
    glow.texture:SetTexture(texturePath
        or "Interface\\AddOns\\PrettyFrames\\Themes\\Shared\\Assets\\PortraitThreatGlow.tga")
    glow.texture:SetBlendMode("ADD")
    glow:Hide()
    return glow
end

local function CreateIndicator(parent, size, showLevel)
    local indicator = CreateFrame("Frame", nil, parent)
    indicator:SetSize(size, size)
    indicator:SetFrameLevel(parent:GetFrameLevel() + 24)
    indicator:EnableMouse(false)

    indicator.inner = indicator:CreateTexture(nil, "ARTWORK")
    indicator.inner:SetSize(size * layout.indicatorInnerScale, size * layout.indicatorInnerScale)
    indicator.inner:SetPoint("CENTER", 0, size * layout.indicatorInnerYOffset)

    indicator.mask = indicator:CreateMaskTexture()
    indicator.mask:SetAllPoints(indicator.inner)
    indicator.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    indicator.inner:AddMaskTexture(indicator.mask)

    if showLevel then
        indicator.inner:SetColorTexture(0.045, 0.027, 0.014, 1)
        indicator.text = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        indicator.text:SetPoint("CENTER", 0, -1)
        indicator.text:SetTextColor(1, 0.83, 0.35)
        PF:ApplyBoldNumberFont(indicator.text, math.max(9, math.floor(size * 0.31)))
    end

    indicator.ring = indicator:CreateTexture(nil, "OVERLAY", nil, 7)
    indicator.ring:SetAllPoints(indicator)
    indicator.ring:SetTexture(FrameAsset(parent, "indicatorFrame"))
    return indicator
end

local function CreateRoleIndicator(parent, size)
    local indicator = CreateFrame("Frame", nil, parent)
    indicator:SetSize(size, size)
    indicator:SetFrameLevel(parent:GetFrameLevel() + 2)
    indicator:EnableMouse(false)

    indicator.background = indicator:CreateTexture(nil, "BACKGROUND")
    indicator.background:SetAllPoints(indicator)
    indicator.background:SetTexture(FrameAsset(parent, "portraitFrame"))

    indicator.mask = indicator:CreateMaskTexture()
    indicator.mask:SetAllPoints(indicator.background)
    indicator.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    indicator.background:AddMaskTexture(indicator.mask)

    indicator.icon = indicator:CreateTexture(nil, "ARTWORK")
    indicator.icon:SetSize(size * 1.05, size * 1.05)
    indicator.icon:SetPoint("CENTER")
    indicator.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")

    indicator.text = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    indicator.text:SetPoint("CENTER", 0, -1)
    indicator.text:SetTextColor(1, 0.83, 0.35)
    local font, _, flags = indicator.text:GetFont()
    indicator.text:SetFont(font, math.max(11, math.floor(size * 0.42)), flags)
    indicator.text:SetAlpha(0)
    return indicator
end

local partyRoleCoords = {
    TANK = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local function SetPartyRole(indicator, role)
    if not PF:IsDisplaySafe(role) then
        role = "NONE"
    end
    local coordinates = partyRoleCoords[role]
    if coordinates then
        indicator.icon:SetTexCoord(unpack(coordinates))
        indicator.icon:SetAlpha(1)
        indicator.text:SetAlpha(0)
    else
        indicator.icon:SetAlpha(0)
        indicator.text:SetText(role and role ~= "NONE" and role:sub(1, 1) or "")
        indicator.text:SetAlpha(role and role ~= "NONE" and 1 or 0)
    end
end

local raidMarkerCoords = {
    [1] = { 0.00, 0.25, 0.00, 0.25 },
    [2] = { 0.25, 0.50, 0.00, 0.25 },
    [3] = { 0.50, 0.75, 0.00, 0.25 },
    [4] = { 0.75, 1.00, 0.00, 0.25 },
    [5] = { 0.00, 0.25, 0.25, 0.50 },
    [6] = { 0.25, 0.50, 0.25, 0.50 },
    [7] = { 0.50, 0.75, 0.25, 0.50 },
    [8] = { 0.75, 1.00, 0.25, 0.50 },
}

local function SetRaidMarkerTexture(texture, markerIndex)
    if not texture then return false end

    local markerIsSecret = issecretvalue and issecretvalue(markerIndex)
    if markerIsSecret then
        -- Forever protects real marker indices inside instances. They cannot
        -- be compared or used as Lua table keys, but Blizzard explicitly
        -- permits passing the opaque value to this display sink. Pre-setting
        -- the sheet is required because the sink updates only its texcoords.
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        if SetRaidTargetIconTexture then
            local applied = pcall(SetRaidTargetIconTexture, texture, markerIndex)
            if applied then
                texture:SetVertexColor(1, 1, 1, 1)
                texture:SetAlpha(1)
                texture:SetBlendMode("BLEND")
                texture:Show()
                return true
            end
        end
        texture:Hide()
        return false
    end

    if not markerIndex then
        texture:Hide()
        return false
    end

    local coordinates = raidMarkerCoords[markerIndex]
    if not coordinates then
        texture:Hide()
        return false
    end

    -- Plain indices remain available outside restricted instances. Keep the
    -- direct-coordinate fallback for clients without the native display sink.
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    texture:SetTexCoord(unpack(coordinates))
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetAlpha(1)
    texture:SetBlendMode("BLEND")
    texture:Show()
    return true
end

local function CreateUnitMarker(parent, size, relativeTo, point)
    -- A texture created directly on the owning frame can sit behind sibling
    -- child frames (notably portraits and nameplate health containers), even
    -- at OVERLAY. Give markers their own high-level frame so they consistently
    -- render above models, artwork, and Blizzard-managed widgets.
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    holder:SetFrameLevel(parent:GetFrameLevel() + 20)
    holder:EnableMouse(false)
    PF:SetThemePoint(holder, relativeTo or parent, point)

    local marker = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    marker:SetAllPoints(holder)
    SetRaidMarkerTexture(marker)
    return marker, holder
end

local raidTestNames = {
    "Tank Role", "Healer Role", "Leader", "Assistant", "Skull Marker",
    "Star Marker", "Target", "Threat", "Debuff", "Dispellable",
    "Ready", "Resurrection", "Summon", "Out of Phase", "Incoming Heal",
    "Absorb", "AFK", "Offline", "Out of Range", "Dead",
    "Maintenance Effects", "Heal Absorb",
}

local function SetSecureUnit(button, unit)
    button.unit = unit
    button:SetAttribute("unit", unit)
    button:RegisterForClicks("AnyUp")
    if UnitFrame_OnEnter then button:HookScript("OnEnter", UnitFrame_OnEnter) end
    if UnitFrame_OnLeave then button:HookScript("OnLeave", UnitFrame_OnLeave) end
    RegisterUnitWatch(button)
end

Widgets.CreateStatusBar = CreateStatusBar
Widgets.CreatePortrait = CreatePortrait
Widgets.CreatePortraitGlow = CreatePortraitGlow
Widgets.CreateIndicator = CreateIndicator
Widgets.CreateRoleIndicator = CreateRoleIndicator
Widgets.SetPartyRole = SetPartyRole
Widgets.SetSecureUnit = SetSecureUnit
Widgets.raidMarkerCoords = raidMarkerCoords
Widgets.SetRaidMarkerTexture = SetRaidMarkerTexture
Widgets.CreateUnitMarker = CreateUnitMarker
Widgets.raidTestNames = raidTestNames
Widgets.ForEachFadedRegion = ForEachFadedRegion
Widgets.SetAvailabilityAlpha = SetAvailabilityAlpha
Widgets.SetRangeAlpha = SetRangeAlpha

