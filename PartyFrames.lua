local _, PF = ...

local MAX_AURAS = PF.MAX_AURAS or 40
local COMPACT_AURA_DEFAULT_LIMIT = 5
local COMPACT_AURA_ICON_SIZE = 24
local CreateStatusBar = PF.Widgets.CreateStatusBar
local CreatePortrait = PF.Widgets.CreatePortrait
local CreatePortraitGlow = PF.Widgets.CreatePortraitGlow
local CreateIndicator = PF.Widgets.CreateIndicator
local CreateRoleIndicator = PF.Widgets.CreateRoleIndicator
local CreateUnitMarker = PF.Widgets.CreateUnitMarker
local SetSecureUnit = PF.Widgets.SetSecureUnit
local CreateAuraIcons = PF.Auras.CreateAuraIcons
local CreateRaidDebuffContainer = PF.Auras.CreateRaidDebuffContainer
local CreateRaidMaintenanceContainer = PF.Auras.CreateRaidMaintenanceContainer
local LayoutCompactAuras = PF.Auras.LayoutCompactAuras
local themeLayout = PF:ThemeLayout("party")
local PARTY_ALPHA_UNAVAILABLE = 0.34
local SetAvailabilityAlpha = PF.Widgets.SetAvailabilityAlpha
local SetRangeAlpha = PF.Widgets.SetRangeAlpha

local function SetPartyThreat(frame, red, green, blue)
    if red then
        frame.partyThreatGlow.texture:SetVertexColor(red, green, blue)
        frame.partyThreatGlow:Show()
    else
        frame.partyThreatGlow:Hide()
    end
end

local function ApplyPartyIndicatorLayout(frame, flipped)
    local function Point(value)
        return flipped and PF:MirrorThemePoint(value) or value
    end
    local function Anchor(region, value)
        if not region then return end
        region:ClearAllPoints()
        PF:SetThemePoint(region, frame, Point(value))
    end

    Anchor(frame.nativeDebuffs, themeLayout.debuffPoint)
    Anchor(frame.partyDebuffPreview, themeLayout.debuffPoint)
    Anchor(frame.nativeMaintenance, themeLayout.maintenancePoint)

    local maintenance = frame.nativeMaintenance
    if maintenance and maintenance.container then
        maintenance.container:ClearAllPoints()
        maintenance.container:SetPoint(flipped and "BOTTOMRIGHT" or "BOTTOMLEFT",
            maintenance, flipped and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
        maintenance.container:SetFlowLayoutAnchorPoint(flipped and "BOTTOMRIGHT" or "BOTTOMLEFT")
        maintenance.container:SetFlowLayoutGrowthDirection(
            flipped and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
            AnchorUtil.FlowDirection.Up
        )
    end

    for index, indicator in ipairs(frame.partyMaintenancePreview or {}) do
        indicator:ClearAllPoints()
        if index == 1 then
            PF:SetThemePoint(indicator, frame, Point(themeLayout.maintenancePoint))
        else
            indicator:SetPoint(flipped and "RIGHT" or "LEFT",
                frame.partyMaintenancePreview[index - 1], flipped and "LEFT" or "RIGHT",
                flipped and -1 or 1, 0)
        end
    end
end

local function SetPartyRangeState(frame)
    local options = PF.db and PF.db.partyLayout
    -- ApplyFrameVisibility owns the root alpha while arranging or previewing
    -- frames (including the half-alpha Always Hide preview). Range fading is
    -- suspended in those modes, so leave that preview alpha untouched.
    if not options or not PF.db.locked or PF.testMode then return end

    local exists = UnitExists(frame.unit)
    if not (PF:IsDisplaySafe(exists) and exists == true) then
        SetAvailabilityAlpha(frame, 1)
        return
    end

    local connected = UnitIsConnected(frame.unit)
    local inPhase = UnitInPhase and UnitInPhase(frame.unit)
    local unavailable = (PF:IsDisplaySafe(connected) and connected == false)
        or (PF:IsDisplaySafe(inPhase) and inPhase == false)
    if unavailable then
        SetAvailabilityAlpha(frame, PARTY_ALPHA_UNAVAILABLE)
        return
    end

    local dead = UnitIsDeadOrGhost(frame.unit)
    if options.rangeFade ~= false and UnitInRange
        and PF:IsDisplaySafe(dead) and dead ~= true then
        SetRangeAlpha(frame, UnitInRange(frame.unit), options.outOfRangeAlpha or 0.55)
    else
        SetAvailabilityAlpha(frame, 1)
    end
end

function PF:RefreshPartyRangeStates()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
    for _, frame in ipairs(anchor.partyFrames) do
        SetPartyRangeState(frame)
    end
end

local function ApplyPartyLayout(frame, flipped)
    frame.isMirrored = flipped == true
    local crop = themeLayout.artCrop
    frame.skin:SetTexCoord(flipped and crop[2] or crop[1], flipped and crop[1] or crop[2], crop[3], crop[4])

    frame.portrait:ClearAllPoints()
    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.nameText:ClearAllPoints()
    frame.levelIndicator:ClearAllPoints()
    frame.classIndicator:ClearAllPoints()
    frame.roleIndicator:ClearAllPoints()
    frame.statusText:ClearAllPoints()

    local points = PF:ResolveThemePoints(themeLayout, flipped)
    PF:SetThemePoint(frame.portrait, frame, points.portrait)
    PF:SetThemePoint(frame.nameText, frame, points.nameLeft)
    PF:SetThemePoint(frame.nameText, frame, points.nameRight)
    PF:SetThemePoint(frame.health, frame, points.healthLeft)
    PF:SetThemePoint(frame.health, frame, points.healthRight)
    PF:SetThemePoint(frame.power, frame, points.powerLeft)
    PF:SetThemePoint(frame.power, frame, points.powerRight)
    PF:SetThemePoint(frame.levelIndicator, frame, points.level)
    PF:SetThemePoint(frame.classIndicator, frame, points.class)
    frame.classIndicator.inner:ClearAllPoints()
    frame.classIndicator.inner:SetPoint("CENTER", frame.classIndicator, "CENTER", 0, 0)
    frame.classIndicator.ring:SetTexCoord(flipped and 1 or 0, flipped and 0 or 1, 0, 1)
    PF:SetThemePoint(frame.roleIndicator, frame, points.role)
    PF:SetThemePoint(frame.statusText, frame.health, points.status)

    frame.health:SetReverseFill(flipped == true)
    frame.power:SetReverseFill(flipped == true)
    if PF.LayoutGroupHealPrediction then
        PF:LayoutGroupHealPrediction(frame, flipped == true)
    end
    ApplyPartyIndicatorLayout(frame, flipped == true)
end

local function LayoutPartyAuras(frame, leftSide)
    frame.partyAurasLeft = leftSide == true
    frame.compactAuraActiveEdgeOverlap = frame.partyAurasLeft
        and frame.compactAuraLeftEdgeOverlap or frame.compactAuraEdgeOverlap
    LayoutCompactAuras(frame, frame.partyAurasLeft)
end

function PF:CreatePartyUnitFrame(name, unit)
    local width, height = unpack(themeLayout.size)
    local frame = CreateFrame("Button", name, UIParent,
        "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate,BackdropTemplate")
    frame.themeFrameName = "party"
    frame:SetSize(width, height)
    frame:SetHitRectInsets(0, 0, 0, 16)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    SetSecureUnit(frame, unit)
    self:RegisterActionFrame(frame, "party")

    frame.portrait = CreatePortrait(frame, themeLayout.portraitSize)
    PF:SetThemePoint(frame.portrait, frame, themeLayout.points.portrait)
    if frame.portrait.SetBackgroundLayout then
        frame.portrait:SetBackgroundLayout(
            themeLayout.portraitBackgroundScaleX,
            themeLayout.portraitBackgroundScaleY,
            themeLayout.portraitBackgroundYOffset
        )
    end
    if frame.portrait.SetClipsChildren then
        frame.portrait:SetClipsChildren(true)
    end

    frame.health = CreateStatusBar(frame, themeLayout.healthHeight)
    PF:SetThemePoint(frame.health, frame, themeLayout.points.healthLeft)
    PF:SetThemePoint(frame.health, frame, themeLayout.points.healthRight)

    frame.power = CreateStatusBar(frame, themeLayout.powerHeight)
    PF:SetThemePoint(frame.power, frame, themeLayout.points.powerLeft)
    PF:SetThemePoint(frame.power, frame, themeLayout.points.powerRight)

    frame.roleIndicator = CreateRoleIndicator(frame, themeLayout.roleSize)
    PF:SetThemePoint(frame.roleIndicator, frame, themeLayout.points.role)

    frame.skinLayer = CreateFrame("Frame", nil, frame)
    frame.skinLayer:SetAllPoints(frame)
    frame.skinLayer:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.skinLayer:EnableMouse(false)
    frame.skin = frame.skinLayer:CreateTexture(nil, "ARTWORK")
    frame.skin:SetAllPoints(frame.skinLayer)
    frame.skin:SetTexture(self:ThemeFrameAsset("party", "partyFrame", "partyFrame"))
    frame.skin:SetTexCoord(unpack(themeLayout.artCrop))

    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame)
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 21)
    frame.textLayer:EnableMouse(false)

    frame.unitMarker = CreateUnitMarker(
        frame.textLayer, themeLayout.marker.size, frame.portrait, themeLayout.marker.point
    )

    frame.nameText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 100, -32)
    frame.nameText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -96, -32)
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetTextColor(1, 0.91, 0.72)
    local nameFont, _, nameFlags = frame.nameText:GetFont()
    frame.nameText:SetFont(nameFont, 13, nameFlags)

    frame.healthText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.healthText:SetAllPoints(frame.health)
    frame.healthText:SetTextColor(1, 0.96, 0.84)
    PF:ApplyBoldNumberFont(frame.healthText)

    frame.powerText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.powerText:SetAllPoints(frame.power)
    PF:ApplyBoldNumberFont(frame.powerText)

    frame.statusText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.statusText:SetPoint("RIGHT", frame.health, "RIGHT", -4, 0)
    frame.statusText:SetTextColor(1, 0.35, 0.25)

    frame.levelIndicator = CreateIndicator(frame, themeLayout.levelSize, true)
    PF:SetThemePoint(frame.levelIndicator, frame, themeLayout.points.level)
    frame.levelIndicator:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.levelIndicator.ring:Hide()
    frame.levelIndicator.inner:SetSize(20, 20)
    frame.levelIndicator.inner:ClearAllPoints()
    frame.levelIndicator.inner:SetPoint("CENTER", frame.levelIndicator, "CENTER", 0, 0)
    PF:ApplyBoldNumberFont(frame.levelIndicator.text, 11)
    frame.levelIndicator.text:ClearAllPoints()
    frame.levelIndicator.text:SetPoint("CENTER", frame.levelIndicator, "CENTER", 0, 3)
    frame.levelText = frame.levelIndicator.text

    frame.classIndicator = CreateIndicator(frame, themeLayout.classSize, false)
    PF:SetThemePoint(frame.classIndicator, frame, themeLayout.points.class)
    frame.classIndicator:SetFrameLevel(frame:GetFrameLevel() + 24)
    frame.classIndicator.ring:Show()
    frame.classIndicator.inner:SetSize(20, 20)
    frame.classIndicator.inner:ClearAllPoints()
    frame.classIndicator.inner:SetPoint("CENTER", frame.classIndicator, "CENTER", 0, 0)
    frame.classIcon = frame.classIndicator.inner

    frame.isPartyFrame = true
    frame.usePrimaryDebuffIndicator = true
    -- Ordinary helpful effects retain the established compact Party row. The
    -- healing display replaces the old general debuff row with one securely
    -- prioritized primary debuff inside the portrait frame.
    CreateAuraIcons(frame, MAX_AURAS, COMPACT_AURA_ICON_SIZE, false)
    frame.compactAuraBuffY = themeLayout.auraBuffY
    frame.compactAuraDebuffY = themeLayout.auraDebuffY
    frame.compactAuraEdgeOverlap = themeLayout.auraEdgeOverlap
    frame.compactAuraLeftEdgeOverlap = themeLayout.auraLeftEdgeOverlap
    LayoutPartyAuras(frame, self.db.partyLayout.aurasLeft)

    frame.partyThreatGlow = CreatePortraitGlow(frame.portrait, themeLayout.threatGlowSize)
    frame.partyThreatGlow.texture:SetAlpha(0.92)
    SetPartyThreat(frame)

    self:CreateGroupHealPrediction(frame, themeLayout)

    frame.nativeDebuffs = CreateRaidDebuffContainer(frame, themeLayout.debuffIconSize)
    if frame.nativeDebuffs then
        local holder = frame.nativeDebuffs
        if holder.SetClipsChildren then holder:SetClipsChildren(false) end
    end

    frame.nativeMaintenance = CreateRaidMaintenanceContainer(frame, themeLayout.maintenanceIconSize)
    if frame.nativeMaintenance then
        local holder = frame.nativeMaintenance
    end

    frame.partyDebuffPreview = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.partyDebuffPreview:SetSize(themeLayout.debuffIconSize, themeLayout.debuffIconSize)
    frame.partyDebuffPreview:SetFrameLevel(frame.textLayer:GetFrameLevel() + 3)
    frame.partyDebuffPreview:EnableMouse(false)
    self:CreateBackdrop(frame.partyDebuffPreview, 1)
    frame.partyDebuffPreview.icon = frame.partyDebuffPreview:CreateTexture(nil, "ARTWORK")
    frame.partyDebuffPreview.icon:SetPoint("TOPLEFT", 2, -2)
    frame.partyDebuffPreview.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.partyDebuffPreview.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.partyDebuffPreview.count = frame.partyDebuffPreview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.partyDebuffPreview.count:SetPoint("BOTTOMRIGHT", -2, 2)
    self:ApplyBoldNumberFont(frame.partyDebuffPreview.count)
    frame.partyDebuffPreview:Hide()

    frame.partyMaintenancePreview = {}
    local maintenanceIcons = {
        "Interface\\Icons\\Spell_Nature_Rejuvenation",
        "Interface\\Icons\\Spell_Holy_PowerWordShield",
        "Interface\\Icons\\Spell_Holy_DevotionAura",
    }
    for index, texturePath in ipairs(maintenanceIcons) do
        local indicator = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        indicator:SetSize(themeLayout.maintenanceIconSize, themeLayout.maintenanceIconSize)
        indicator:SetFrameLevel(frame.textLayer:GetFrameLevel() + 3)
        indicator:EnableMouse(false)
        self:CreateBackdrop(indicator, 1)
        indicator:SetBackdropBorderColor(index == 3 and 0.30 or 0.30,
            index == 3 and 0.62 or 0.82, index == 3 and 1.00 or 0.38, 0.9)
        indicator.icon = indicator:CreateTexture(nil, "ARTWORK")
        indicator.icon:SetPoint("TOPLEFT", 1, -1)
        indicator.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        indicator.icon:SetTexture(texturePath)
        indicator.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        indicator:Hide()
        frame.partyMaintenancePreview[index] = indicator
    end

    frame.defaultMaxBuffs = COMPACT_AURA_DEFAULT_LIMIT
    frame.defaultMaxDebuffs = COMPACT_AURA_DEFAULT_LIMIT
    frame.SetAuraLimits = function(widget, maxBuffs, maxDebuffs)
        widget.maxBuffs = math.max(0, math.min(MAX_AURAS, maxBuffs or 0))
        widget.maxDebuffs = math.max(0, math.min(MAX_AURAS, maxDebuffs or 0))
        LayoutPartyAuras(widget, widget.partyAurasLeft)
        if PF.UpdateAuras then PF:UpdateAuras(widget) end
        if PF.RefreshNativeAuras then PF:RefreshNativeAuras(widget) end
    end

    frame.SetFlipped = function(widget, flipped)
        ApplyPartyLayout(widget, flipped)
    end
    ApplyPartyLayout(frame, false)
    self:RegisterFrameContextMenu(frame, unit)
    table.insert(self.unitFrames, frame)
    return frame
end

function PF:UpdatePartyPresentation(frame, exists, previewIndex)
    if not frame.isPartyFrame then return end
    local options = self.db and self.db.partyLayout
    self:HideGroupHealPrediction(frame)
    SetPartyThreat(frame)
    frame.partyDebuffPreview:Hide()
    for _, indicator in ipairs(frame.partyMaintenancePreview or {}) do indicator:Hide() end

    if self.testMode then
        if previewIndex == 1 and options.showDebuffs ~= false then
            frame.partyDebuffPreview.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
            frame.partyDebuffPreview.count:SetText("3")
            frame.partyDebuffPreview:SetBackdropBorderColor(0.82, 0.20, 0.12, 1)
            frame.partyDebuffPreview:Show()
        elseif previewIndex == 2 and options.showDispellableDebuffs ~= false then
            frame.partyDebuffPreview.icon:SetTexture("Interface\\Icons\\Spell_Nature_NullifyDisease")
            frame.partyDebuffPreview.count:SetText("")
            frame.partyDebuffPreview:SetBackdropBorderColor(0.25, 0.72, 1.00, 1)
            frame.partyDebuffPreview:Show()
        elseif previewIndex == 3 and options.showPredictions ~= false then
            local prediction = frame.groupPrediction
            for _, segment in ipairs(prediction.segments) do segment:SetMinMaxValues(0, 100) end
            prediction.myHeals:SetValue(16)
            prediction.otherHeals:SetValue(10)
            prediction.absorbs:SetValue(18)
            prediction.healAbsorbs:SetValue(12)
            for _, segment in ipairs(prediction.segments) do segment:Show() end
        elseif previewIndex == 4 then
            if options.showMaintenance ~= false then
                for _, indicator in ipairs(frame.partyMaintenancePreview or {}) do indicator:Show() end
            end
            if options.showThreat ~= false then SetPartyThreat(frame, 1.00, 0.18, 0.10) end
        end
        return
    end

    if not exists then return end
    if options.showThreat ~= false and UnitThreatSituation then
        local threat = UnitThreatSituation(frame.unit)
        if self:IsDisplaySafe(threat) and threat and threat >= 2 then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit)
            local isTank = self:IsDisplaySafe(role) and role == "TANK"
            if threat == 2 then
                SetPartyThreat(frame, 1.00, 0.48, 0.08)
            elseif not isTank then
                SetPartyThreat(frame, 1.00, 0.18, 0.10)
            end
        end
    end
    self:UpdateGroupHealPrediction(frame, options)
end

function PF:CreatePartyFrames()
    local anchor = CreateFrame("Frame", "PrettyFramesPartyAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(themeLayout.size[1], 1)
    anchor.isAnchor = true
    self.frames.party = anchor
    self:PlaceFrame(anchor, "party")
    self:MakeMovable(anchor, "party")
    RegisterStateDriver(anchor, "visibility", "[group:raid] hide; show")

    anchor.partyFrames = {}
    for index = 1, 4 do
        local frame = self:CreatePartyUnitFrame("PrettyFramesParty" .. index, "party" .. index)
        frame:SetParent(anchor)
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(index - 1) * themeLayout.frameStep)
        anchor.partyFrames[index] = frame
    end

    anchor.rangeUpdateElapsed = 0
    anchor:SetScript("OnUpdate", function(widget, elapsed)
        local options = PF.db and PF.db.partyLayout
        if not options or not widget:IsShown() or not PF.db.locked or PF.testMode
            or options.visibility == "hide" or (widget.partyActiveCount or 0) == 0 then
            widget.rangeUpdateElapsed = 0
            return
        end
        widget.rangeUpdateElapsed = widget.rangeUpdateElapsed + elapsed
        if widget.rangeUpdateElapsed < 0.5 then return end
        widget.rangeUpdateElapsed = 0
        PF:RefreshPartyRangeStates()
    end)

    -- Each connector is parented to the upper party frame and unit-watches the
    -- lower one. The parent/child relationship plus the second unit watch means
    -- it can only render when both adjacent frames are present, including combat.
    anchor.partyConnectors = {}
    for index = 1, 3 do
        local upper = anchor.partyFrames[index]
        local lower = anchor.partyFrames[index + 1]
        local connector = CreateFrame("Button", "PrettyFramesPartyConnector" .. index, upper, "SecureUnitButtonTemplate")
        -- Keep the texture's native 1:2 aspect ratio so its leaves and bronze
        -- curls are not distorted. The overlap is hidden behind the frame art
        -- and helps adjacent sections read as one continuous vine.
        connector:SetSize(unpack(themeLayout.connectorSize))
        PF:SetThemePoint(connector, upper, themeLayout.connectorPoint)
        connector:SetFrameLevel(upper:GetFrameLevel() + 1)
        connector:EnableMouse(false)
        connector:SetAttribute("unit", lower.unit)

        -- Crop the exposed ends at the first and last portrait centerlines. The
        -- actual texture remains full-sized inside this clipping frame, so the
        -- artwork is cut rather than rescaled or distorted.
        connector.clipper = CreateFrame("Frame", nil, connector)
        -- Child frames normally rise one frame level above their parent. Keep
        -- this wrapper at the connector's level so the vine remains beneath
        -- the portraits and foreground frame artwork.
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())
        if index == 1 then
            connector.clipper:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, -themeLayout.connectorEndCrop)
            connector.clipper:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, 0)
        elseif index == 3 then
            connector.clipper:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, 0)
            connector.clipper:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, themeLayout.connectorEndCrop)
        else
            connector.clipper:SetAllPoints(connector)
        end
        if connector.clipper.SetClipsChildren then
            connector.clipper:SetClipsChildren(true)
        end

        connector.texture = connector.clipper:CreateTexture(nil, "BACKGROUND")
        connector.texture:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, 0)
        connector.texture:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, 0)
        connector.texture:SetTexture(
            self:ThemeFrameAsset("party", "partyConnector", "partyConnector"), "CLAMP", "REPEAT"
        )
        -- Sample a different wrapped section for every gap. Each window remains
        -- exactly one texture-height tall, preserving the artwork's aspect ratio.
        local verticalOffset = (index - 1) * themeLayout.connectorSampleStep
        connector.texture:SetTexCoord(0, 1, verticalOffset, 1 + verticalOffset)

        connector.upperFrame = upper
        connector.lowerFrame = lower
        RegisterUnitWatch(connector)
        anchor.partyConnectors[index] = connector
    end

    for _, frame in ipairs(anchor.partyFrames) do
        frame.OnVisibilityApplied = function()
            PF:UpdatePartyConnectors()
        end
    end

    anchor.moveHandle:SetScript("OnMouseUp", function(handle, mouseButton)
        if mouseButton == "RightButton" then
            PF:OpenPartyContextMenu(handle)
        end
    end)

    self:ApplyPartyUnitBindings()
    self:ApplyPartyAuraLayout()
end

function PF:ApplyPartyAuraLayout()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
    if InCombatLockdown() then
        self.pendingPartyAuraLayout = true
        return false
    end

    self.pendingPartyAuraLayout = nil
    local leftSide = self.db.partyLayout.aurasLeft == true
    for _, frame in ipairs(anchor.partyFrames) do
        LayoutPartyAuras(frame, leftSide)
    end
    return true
end

local partyRoleSortOrder = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

local function PartyFrameIndex(frame)
    return tonumber(frame.unit and frame.unit:match("%d+")) or 99
end

local function PartyFrameExists(frame)
    local exists = UnitExists(frame.unit)
    return PF:IsDisplaySafe(exists) and exists == true
end

local function PartyFrameRole(frame)
    if not PartyFrameExists(frame) or not UnitGroupRolesAssigned then return "NONE" end
    local role = UnitGroupRolesAssigned(frame.unit)
    return PF:IsDisplaySafe(role) and role or "NONE"
end

local function PartyFrameName(frame)
    if not PartyFrameExists(frame) then return "" end
    local name = UnitName(frame.unit)
    return PF:IsDisplaySafe(name) and name:lower() or ""
end

function PF:ApplyPartyGroupLayout()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
    if InCombatLockdown() then
        self.pendingPartyLayout = true
        return false
    end

    self.pendingPartyLayout = nil
    local options = self.db.partyLayout
    local ordered = {}
    for _, frame in ipairs(anchor.partyFrames) do
        table.insert(ordered, frame)
    end

    if options.sort == "role" then
        table.sort(ordered, function(left, right)
            local leftExists, rightExists = PartyFrameExists(left), PartyFrameExists(right)
            if leftExists ~= rightExists then return leftExists end
            local leftRole = partyRoleSortOrder[PartyFrameRole(left)] or partyRoleSortOrder.NONE
            local rightRole = partyRoleSortOrder[PartyFrameRole(right)] or partyRoleSortOrder.NONE
            if leftRole ~= rightRole then return leftRole < rightRole end
            local leftName, rightName = PartyFrameName(left), PartyFrameName(right)
            if leftName ~= rightName then return leftName < rightName end
            return PartyFrameIndex(left) < PartyFrameIndex(right)
        end)
    elseif options.sort == "name" then
        table.sort(ordered, function(left, right)
            local leftExists, rightExists = PartyFrameExists(left), PartyFrameExists(right)
            if leftExists ~= rightExists then return leftExists end
            local leftName, rightName = PartyFrameName(left), PartyFrameName(right)
            if leftName ~= rightName then return leftName < rightName end
            return PartyFrameIndex(left) < PartyFrameIndex(right)
        end)
    end

    anchor.partyDisplayOrder = ordered
    local showAllFrames = self.testMode or not self.db.locked or options.visibility == "show"
    local activeCount = 0
    for _, frame in ipairs(ordered) do
        if showAllFrames or PartyFrameExists(frame) then
            activeCount = activeCount + 1
        end
    end
    anchor.partyActiveCount = activeCount

    local offsets = {}
    local frameStep = themeLayout.frameStep
    local function FrameScale(frame)
        return frame.settingKey and PF:GetFrameSetting(frame.settingKey).scale or 1
    end

    if options.growUpwards then
        local cursor = 0
        -- Keep the last active member attached to the saved anchor and stack
        -- earlier members upward using their actual scaled spacing.
        for index = #ordered, 1, -1 do
            local frame = ordered[index]
            if showAllFrames or PartyFrameExists(frame) then
                offsets[frame] = cursor
                cursor = cursor + frameStep * FrameScale(frame)
            end
        end
        -- Hidden secure slots remain beyond the active stack so a member can
        -- appear safely during combat without colliding with a visible frame.
        for _, frame in ipairs(ordered) do
            if offsets[frame] == nil then
                offsets[frame] = cursor
                cursor = cursor + frameStep * FrameScale(frame)
            end
        end
    else
        local cursor = 0
        for _, frame in ipairs(ordered) do
            offsets[frame] = -cursor
            cursor = cursor + frameStep * FrameScale(frame)
        end
    end

    for _, frame in ipairs(ordered) do
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, offsets[frame])
    end

    anchor.moveHandle:ClearAllPoints()
    -- `ordered[1]` is always the visual top frame after the growth offsets are
    -- applied. Anchor the handle to that frame instead of reconstructing its
    -- position from the Party anchor and a possibly stale active count.
    anchor.moveHandle:SetPoint("BOTTOMLEFT", ordered[1], "TOPLEFT", 0, 5)

    for index, connector in ipairs(anchor.partyConnectors or {}) do
        local first = ordered[index]
        local second = ordered[index + 1]
        UnregisterUnitWatch(connector)
        connector:SetParent(first)
        connector:ClearAllPoints()
        PF:SetThemePoint(connector, first, themeLayout.connectorPoint)
        connector:SetFrameLevel(first:GetFrameLevel() + 1)
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())
        connector:SetAttribute("unit", second.unit)
        connector.upperFrame = first
        connector.lowerFrame = second

        connector.clipper:ClearAllPoints()
        local cropTop = index == 1
        local cropBottom = index == math.max(activeCount - 1, 1)
        local endCrop = themeLayout.connectorEndCrop
        connector.clipper:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, cropTop and -endCrop or 0)
        connector.clipper:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, cropBottom and endCrop or 0)
    end

    self:UpdatePartyConnectors()
    return true
end

function PF:OpenPartyContextMenu(owner)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the party menu is unavailable on this client build.")
        return
    end

    local options = self.db.partyLayout
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Party Frames")
        rootDescription:CreateButton("Actions...", function()
            PF:OpenActionsWindow("party")
        end)
        rootDescription:CreateDivider()
        PF:AddScaleMenuOption(rootDescription, options.scale or 1, function(value)
            options.scale = value
            PF:RefreshScale()
        end)
        local profileMenu = rootDescription:CreateButton("Display Profile")
        local function IsProfileSelected(value)
            return options.displayProfile == value
        end
        local function SetProfileSelected(value)
            PF:ApplyPartyDisplayProfile(value)
        end
        profileMenu:CreateRadio("Balanced", IsProfileSelected, SetProfileSelected, "balanced")
        profileMenu:CreateRadio("Healer", IsProfileSelected, SetProfileSelected, "healer")
        profileMenu:CreateRadio("Minimal", IsProfileSelected, SetProfileSelected, "minimal")
        if options.displayProfile == "custom" then
            profileMenu:CreateRadio("Custom", IsProfileSelected, function() end, "custom")
        end

        PF:AddVisibilityMenuOption(rootDescription, function()
            return options.visibility or "auto"
        end, function(value)
            options.visibility = value
            PF:ApplyPartyGroupVisibility()
        end)
        local layoutMenu = rootDescription:CreateButton("Layout")
        local indicatorMenu = rootDescription:CreateButton("Auras & Indicators")
        local rangeMenu = rootDescription:CreateButton("Range")
        local groupMenu = rootDescription:CreateButton("Group Usage")

        local function ToggleIndicator(key)
            options[key] = options[key] == false
            options.displayProfile = "custom"
            PF:ApplyPartyIndicatorFilters()
            PF:RefreshPartyFrames(false)
        end
        indicatorMenu:CreateCheckbox("Primary Debuff", function()
            return options.showDebuffs ~= false
        end, function()
            ToggleIndicator("showDebuffs")
        end)
        indicatorMenu:CreateCheckbox("Prioritize Dispellable Debuffs", function()
            return options.showDispellableDebuffs ~= false
        end, function()
            ToggleIndicator("showDispellableDebuffs")
        end)
        indicatorMenu:CreateCheckbox("Incoming Heals & Absorbs", function()
            return options.showPredictions ~= false
        end, function()
            ToggleIndicator("showPredictions")
        end)
        indicatorMenu:CreateCheckbox("Maintenance Effects", function()
            return options.showMaintenance ~= false
        end, function()
            ToggleIndicator("showMaintenance")
        end)
        indicatorMenu:CreateCheckbox("Threat Warning", function()
            return options.showThreat ~= false
        end, function()
            ToggleIndicator("showThreat")
        end)
        indicatorMenu:CreateDivider()
        indicatorMenu:CreateTitle("Aura Placement")
        indicatorMenu:CreateRadio("Left", function()
            return options.aurasLeft == true
        end, function()
            options.aurasLeft = true
            PF:ApplyPartyAuraLayout()
        end)
        indicatorMenu:CreateRadio("Right", function()
            return options.aurasLeft ~= true
        end, function()
            options.aurasLeft = false
            PF:ApplyPartyAuraLayout()
        end)

        groupMenu:CreateCheckbox("Use in Small Raids", function()
            return options.useInSmallRaid == true
        end, function()
            if InCombatLockdown() then
                PF:Print("party raid behavior cannot change during combat.")
                return
            end
            options.useInSmallRaid = not options.useInSmallRaid
            PF:ApplyPartyUnitBindings()
            PF:ApplyGroupStateDrivers()
        end)
        groupMenu:CreateCheckbox("Hide in Raid Groups", function()
            return options.hideInRaid == true
        end, function()
            if InCombatLockdown() then
                PF:Print("party raid behavior cannot change during combat.")
                return
            end
            options.hideInRaid = not options.hideInRaid
            PF:ApplyPartyUnitBindings()
            PF:ApplyGroupStateDrivers()
        end)
        layoutMenu:CreateTitle("Growth Direction")
        layoutMenu:CreateRadio("Down", function()
            return options.growUpwards ~= true
        end, function()
            options.growUpwards = false
            PF:ApplyPartyGroupLayout()
        end)
        layoutMenu:CreateRadio("Up", function()
            return options.growUpwards == true
        end, function()
            options.growUpwards = true
            PF:ApplyPartyGroupLayout()
        end)

        rangeMenu:CreateCheckbox("Fade Out-of-Range Members", function()
            return options.rangeFade ~= false
        end, function()
            options.rangeFade = options.rangeFade == false
            PF:RefreshPartyRangeStates()
        end)
        local function IsRangeAlphaSelected(value)
            return options.outOfRangeAlpha == value
        end
        local function SetRangeAlphaSelected(value)
            options.outOfRangeAlpha = value
            PF:RefreshPartyRangeStates()
        end
        rangeMenu:CreateRadio("Dim (35%)", IsRangeAlphaSelected, SetRangeAlphaSelected, 0.35)
        rangeMenu:CreateRadio("Readable (55%)", IsRangeAlphaSelected, SetRangeAlphaSelected, 0.55)
        rangeMenu:CreateRadio("Subtle (75%)", IsRangeAlphaSelected, SetRangeAlphaSelected, 0.75)

        layoutMenu:CreateDivider()
        layoutMenu:CreateTitle("Sort Order")
        local function IsSelected(value)
            return options.sort == value
        end
        local function SetSelected(value)
            options.sort = value
            PF:ApplyPartyGroupLayout()
        end
        layoutMenu:CreateRadio("Party Order", IsSelected, SetSelected, "index")
        layoutMenu:CreateRadio("Role", IsSelected, SetSelected, "role")
        layoutMenu:CreateRadio("Name", IsSelected, SetSelected, "name")
    end)
end

function PF:ApplyPartyGroupVisibility()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
    for _, frame in ipairs(anchor.partyFrames) do
        self:ApplyFrameVisibility(frame)
        self:UpdateUnitFrame(frame, true)
    end
    self:ApplyPartyGroupLayout()
    self:RefreshPartyRangeStates()
end

function PF:ShouldUsePartyFramesForSmallRaid()
    local options = self.db and self.db.partyLayout
    if not options or options.useInSmallRaid ~= true then return false end
    if not (IsInRaid and IsInRaid()) then return false end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
    return groupSize > 0 and groupSize <= 5
end

function PF:ApplyPartyUnitBindings()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
    if InCombatLockdown() then
        self.pendingPartyUnitBindings = true
        return false
    end

    local desiredUnits = {}
    if IsInRaid and IsInRaid() then
        local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
        for raidIndex = 1, groupSize do
            local raidUnit = "raid" .. raidIndex
            local isPlayer = UnitIsUnit and UnitIsUnit(raidUnit, "player")
            if not (self:IsDisplaySafe(isPlayer) and isPlayer == true) then
                table.insert(desiredUnits, raidUnit)
                if #desiredUnits == 4 then break end
            end
        end
    end

    for index, frame in ipairs(anchor.partyFrames) do
        local unit = desiredUnits[index] or ("party" .. index)
        if frame.unit ~= unit then
            UnregisterUnitWatch(frame)
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            for _, holder in ipairs({ frame.nativeBuffs, frame.nativeDebuffs, frame.nativeMaintenance }) do
                if holder and holder.container then
                    holder.container:SetUnit(unit)
                end
            end
        end
        self:ApplyFrameVisibility(frame)
        self:UpdateUnitFrame(frame, true)
    end

    self.pendingPartyUnitBindings = nil
    self:ApplyPartyGroupLayout()
    self:RefreshPartyRangeStates()
    return true
end

function PF:UpdatePartyConnectors()
    local anchor = self.frames.party
    if not anchor or not anchor.partyConnectors or InCombatLockdown() then return end

    for _, connector in ipairs(anchor.partyConnectors) do
        local partyVisibility = self.db.partyLayout and self.db.partyLayout.visibility or "auto"
        local upperSetting = { visibility = partyVisibility }
        local lowerSetting = upperSetting
        local editing = self.db and not self.db.locked

        if editing then
            UnregisterUnitWatch(connector)
            local hiddenPreview = (upperSetting and upperSetting.visibility == "hide")
                or (lowerSetting and lowerSetting.visibility == "hide")
            connector:SetAlpha(hiddenPreview and 0.5 or 1)
            connector:Show()
        elseif lowerSetting and lowerSetting.visibility == "hide" then
            UnregisterUnitWatch(connector)
            connector:SetAlpha(1)
            connector:Hide()
        elseif self.testMode then
            UnregisterUnitWatch(connector)
            connector:SetAlpha(1)
            connector:Show()
        elseif lowerSetting and lowerSetting.visibility == "show" then
            UnregisterUnitWatch(connector)
            connector:SetAlpha(1)
            connector:Show()
        else
            connector:SetAlpha(1)
            RegisterUnitWatch(connector)
        end
    end
end

