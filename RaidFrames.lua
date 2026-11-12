local _, PF = ...

local themeLayout = PF:ThemeLayout("raid")

local CreateRoleIndicator = PF.Widgets.CreateRoleIndicator
local SetPartyRole = PF.Widgets.SetPartyRole
local SetSecureUnit = PF.Widgets.SetSecureUnit
local CreateRaidDebuffContainer = PF.Auras.CreateRaidDebuffContainer
local CreateRaidMaintenanceContainer = PF.Auras.CreateRaidMaintenanceContainer
local RAID_ALPHA_OUT_OF_RANGE = 0.58
local RAID_ALPHA_UNAVAILABLE = 0.34
local SetAvailabilityAlpha = PF.Widgets.SetAvailabilityAlpha
local SetRangeAlpha = PF.Widgets.SetRangeAlpha

local raidPercentCurve
if C_CurveUtil and C_CurveUtil.CreateCurve then
    raidPercentCurve = C_CurveUtil.CreateCurve()
    raidPercentCurve:AddPoint(0, 0)
    raidPercentCurve:AddPoint(1, 100)
end

local predictionCalculator
if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
    local ok, calculator = pcall(CreateUnitHealPredictionCalculator)
    if ok and calculator then
        predictionCalculator = calculator
        if Enum and Enum.UnitMaximumHealthMode then
            calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
            calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
            calculator:SetIncomingHealOverflowPercent(1)
            calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
            calculator:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.CurrentHealth)
            calculator:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)
        end
    end
end

local function CreatePredictionSegment(parent, healthBar, red, green, blue, alpha, texturePath)
    local segment = CreateFrame("StatusBar", nil, parent)
    if segment.SetUsingParentLevel then segment:SetUsingParentLevel(true) end
    segment:SetStatusBarTexture(
        texturePath or PF:ThemeFrameAsset("raid", "statusBar", "statusBar")
    )
    segment:SetStatusBarColor(red, green, blue, alpha)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)
    segment:SetWidth(math.max(1, healthBar:GetWidth()))
    local texture = segment:GetStatusBarTexture()
    if texture and texture.SetDrawLayer then texture:SetDrawLayer("ARTWORK", 2) end
    segment.fill = texture
    segment:Hide()
    return segment
end

local function AttachPredictionSegment(segment, relative, relativeSide, reverse)
    local side = reverse and "RIGHT" or "LEFT"
    segment:ClearAllPoints()
    segment:SetPoint("TOP" .. side, relative, "TOP" .. relativeSide)
    segment:SetPoint("BOTTOM" .. side, relative, "BOTTOM" .. relativeSide)
    segment:SetReverseFill(reverse == true)
end

local function LayoutGroupHealPrediction(frame, reversed)
    local prediction = frame and frame.groupPrediction
    if not prediction then return end
    local fill = prediction.healthFill
    if reversed then
        AttachPredictionSegment(prediction.myHeals, fill, "LEFT", true)
        AttachPredictionSegment(prediction.otherHeals, prediction.myHeals.fill, "LEFT", true)
        AttachPredictionSegment(prediction.absorbs, prediction.otherHeals.fill, "LEFT", true)
        AttachPredictionSegment(prediction.healAbsorbs, fill, "LEFT", false)
    else
        AttachPredictionSegment(prediction.myHeals, fill, "RIGHT", false)
        AttachPredictionSegment(prediction.otherHeals, prediction.myHeals.fill, "RIGHT", false)
        AttachPredictionSegment(prediction.absorbs, prediction.otherHeals.fill, "RIGHT", false)
        AttachPredictionSegment(prediction.healAbsorbs, fill, "RIGHT", true)
    end
end

local function CreateGroupHealPrediction(frame, geometry)
    local health = frame.health
    local fill = health:GetStatusBarTexture()
    local insets = geometry and geometry.predictionInsets or { 0, 0, 0, 0 }
    local clip = CreateFrame("Frame", nil, health)
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", insets[1] or 0, -(insets[3] or 0))
    clip:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -(insets[2] or 0), insets[4] or 0)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:EnableMouse(false)
    local prediction = {
        clip = clip,
        healthFill = fill,
        myHeals = CreatePredictionSegment(clip, health, 0.08, 0.95, 1.00, 0.90),
        otherHeals = CreatePredictionSegment(clip, health, 0.02, 0.68, 0.82, 0.85),
        absorbs = CreatePredictionSegment(clip, health, 0.30, 0.70, 1.00, 0.82),
        healAbsorbs = CreatePredictionSegment(clip, health, 0.72, 0.04, 0.22, 0.92),
    }
    prediction.segments = {
        prediction.myHeals, prediction.otherHeals, prediction.absorbs, prediction.healAbsorbs,
    }

    local stripes = prediction.absorbs:CreateTexture(nil, "ARTWORK", nil, 3)
    stripes:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    stripes:SetAllPoints(prediction.absorbs.fill)
    prediction.absorbStripes = stripes

    clip:HookScript("OnSizeChanged", function(_, width)
        for _, segment in ipairs(prediction.segments) do
            segment:SetWidth(math.max(1, width))
        end
    end)
    frame.groupPrediction = prediction
    LayoutGroupHealPrediction(frame, frame.isMirrored == true)
    return prediction
end

local function HideGroupHealPrediction(frame)
    local prediction = frame and frame.groupPrediction
    if not prediction then return end
    for _, segment in ipairs(prediction.segments) do
        segment:SetMinMaxValues(0, 1)
        segment:SetValue(0)
        segment:Hide()
    end
end

function PF:CreateGroupHealPrediction(frame, geometry)
    return CreateGroupHealPrediction(frame, geometry)
end

function PF:LayoutGroupHealPrediction(frame, reversed)
    LayoutGroupHealPrediction(frame, reversed)
end

function PF:HideGroupHealPrediction(frame)
    HideGroupHealPrediction(frame)
end

local function SetRaidAvailabilityAlpha(frame, alpha)
    SetAvailabilityAlpha(frame, alpha)
    -- Names, health text, and central status indicators intentionally remain
    -- at full opacity so the reason for fading never becomes unreadable.
    frame.raidAvailabilityAlpha = alpha
end

local function SetRaidRangeAlpha(frame, inRange)
    SetRangeAlpha(frame, inRange, RAID_ALPHA_OUT_OF_RANGE)
    frame.raidAvailabilityAlpha = frame.availabilityAlpha
end

local partyRoleSortOrder = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

local SetRaidMarkerTexture = PF.Widgets.SetRaidMarkerTexture

local function SetRaidAccent(frame, red, green, blue, alpha)
    local shown = red ~= nil
    if shown then
        frame.raidGlow:SetVertexColor(red, green, blue)
        frame.raidGlow:SetAlpha((alpha or 1) * 0.95)
        frame.raidGlow:Show()
    else
        frame.raidGlow:Hide()
    end
end

local function UpdateRaidTextVisibility(frame)
    if not frame.healthText then return end
    local hasIcon = frame.raidStatusIcon and frame.raidStatusIcon:IsShown()
    frame.healthText:SetShown(frame.raidHealthTextHasValue == true
        and frame.raidStatusTextActive ~= true
        and not hasIcon)
end

function PF:SetRaidStatusText(frame, text)
    if not frame or not frame.statusText then return end
    text = text or ""
    frame.statusText:SetText(text)
    frame.raidStatusTextActive = text ~= ""
    UpdateRaidTextVisibility(frame)
end

local function GetRaidIncomingHeals(frame, healthMax, testMode)
    if testMode then
        local previewIndex = tonumber(frame.unit and frame.unit:match("%d+"))
        return previewIndex == 15 and healthMax * 0.22 or 0
    end
    if predictionCalculator and UnitExists(frame.unit) then
        UnitGetDetailedHealPrediction(frame.unit, "player", predictionCalculator)
        return predictionCalculator:GetIncomingHeals()
    end
end

function PF:UpdateRaidHealthText(frame, health, healthMax)
    if not frame or not frame.healthText then return end
    local options = self.db and self.db.raidLayout
    local mode = options and options.healthTextMode or "deficit"
    local text

    if mode == "deficit" then
        local accountedForIncomingHeals = false
        if options and options.accountForIncomingHeals == true
            and self:IsDisplaySafe(health) and self:IsDisplaySafe(healthMax) then
            local incomingHeals = GetRaidIncomingHeals(frame, healthMax, self.testMode)
            if self:IsDisplaySafe(incomingHeals) then
                local missingHealth = math.max(0, healthMax - health - incomingHeals)
                text = missingHealth > 0 and "-" .. self:FormatNumber(missingHealth) or nil
                accountedForIncomingHeals = true
            end
        end

        if accountedForIncomingHeals then
            -- The projected deficit was calculated above. A fully covered
            -- deficit intentionally leaves the text blank.
        elseif not self.testMode and UnitHealthMissing and C_StringUtil and C_StringUtil.WrapString
            and C_StringUtil.TruncateWhenZero then
            frame.healthText:SetText(C_StringUtil.WrapString(
                C_StringUtil.TruncateWhenZero(UnitHealthMissing(frame.unit)), "-"
            ))
            frame.raidHealthTextHasValue = true
            UpdateRaidTextVisibility(frame)
            return
        elseif self:IsDisplaySafe(health) and self:IsDisplaySafe(healthMax) and healthMax > health then
            text = "-" .. self:FormatNumber(healthMax - health)
        end
    elseif mode == "percent" then
        if not self.testMode and UnitHealthPercent and raidPercentCurve and C_StringUtil
            and C_StringUtil.RoundToNearestString then
            frame.healthText:SetText(C_StringUtil.RoundToNearestString(
                UnitHealthPercent(frame.unit, true, raidPercentCurve)
            ) .. "%")
            frame.raidHealthTextHasValue = true
            UpdateRaidTextVisibility(frame)
            return
        elseif self:IsDisplaySafe(health) and self:IsDisplaySafe(healthMax) and healthMax > 0 then
            text = math.floor((health / healthMax) * 100 + 0.5) .. "%"
        end
    elseif mode == "currentmax" then
        local currentText = self:FormatNumber(health)
        local maxText = self:FormatNumber(healthMax)
        if currentText and maxText then
            local incomingText
            if options and options.accountForIncomingHeals == true then
                local incomingHeals = GetRaidIncomingHeals(frame, healthMax, self.testMode)
                if self:IsDisplaySafe(incomingHeals) and incomingHeals > 0 then
                    incomingText = self:FormatNumber(incomingHeals)
                end
            end
            text = currentText .. (incomingText and " (+" .. incomingText .. ")" or "")
                .. " / " .. maxText
        else
            frame.healthText:SetFormattedText("%s / %s", health, healthMax)
            frame.raidHealthTextHasValue = true
            UpdateRaidTextVisibility(frame)
            return
        end
    end

    frame.healthText:SetText(text or "")
    frame.raidHealthTextHasValue = text ~= nil and text ~= ""
    UpdateRaidTextVisibility(frame)
end

function PF:UpdateRaidHealPrediction(frame)
    local options = self.db and self.db.raidLayout
    self:UpdateGroupHealPrediction(frame, options)
end

function PF:UpdateGroupHealPrediction(frame, options)
    local prediction = frame and frame.groupPrediction
    HideGroupHealPrediction(frame)
    local showHealAbsorbs = options and options.showHealAbsorbs
    if showHealAbsorbs == nil and options then
        showHealAbsorbs = options.showPredictions
    end
    if not prediction or not predictionCalculator or not options
        or (options.showPredictions == false and showHealAbsorbs == false)
        or self.testMode or not UnitExists(frame.unit) then
        return
    end

    UnitGetDetailedHealPrediction(frame.unit, "player", predictionCalculator)
    local healthMax = predictionCalculator:GetMaximumHealth()
    local _, mine, others = predictionCalculator:GetIncomingHeals()
    local absorbs = predictionCalculator:GetDamageAbsorbs()
    local healAbsorbs = predictionCalculator:GetHealAbsorbs()

    if options.showPredictions ~= false then
        prediction.myHeals:SetMinMaxValues(0, healthMax)
        prediction.myHeals:SetValue(mine)
        prediction.myHeals:Show()
        prediction.otherHeals:SetMinMaxValues(0, healthMax)
        prediction.otherHeals:SetValue(others)
        prediction.otherHeals:Show()
        prediction.absorbs:SetMinMaxValues(0, healthMax)
        prediction.absorbs:SetValue(absorbs)
        prediction.absorbs:Show()
    end

    if showHealAbsorbs ~= false then
        prediction.healAbsorbs:SetMinMaxValues(0, healthMax)
        prediction.healAbsorbs:SetValue(healAbsorbs)
        prediction.healAbsorbs:Show()
    end
end

local function SetRaidStatusIcon(frame, texturePath)
    if texturePath then
        frame.raidStatusIcon:SetTexture(texturePath)
        frame.raidStatusBackground:Show()
        frame.raidStatusIcon:Show()
    else
        frame.raidStatusBackground:Hide()
        frame.raidStatusIcon:Hide()
    end
    UpdateRaidTextVisibility(frame)
end

local function SetRaidTargetHighlight(frame, shown)
    if frame.raidTargetHighlight then
        frame.raidTargetHighlight:SetShown(shown == true)
    end
end

local function LayoutRaidName(frame)
    frame.nameText:ClearAllPoints()
    frame.nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.raidHasRole and 18 or 9, -6)
    frame.nameText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", frame.raidHasDebuff and -31 or -9, -6)
end
local function RaidUnitIndex(unit)
    if unit == "player" then return 0 end
    return tonumber(unit and unit:match("%d+")) or 99
end

local function RaidUnitExists(unit)
    local exists = UnitExists(unit)
    return PF:IsDisplaySafe(exists) and exists == true
end

local function RaidUnitRole(unit)
    if not RaidUnitExists(unit) or not UnitGroupRolesAssigned then return "NONE" end
    local role = UnitGroupRolesAssigned(unit)
    return PF:IsDisplaySafe(role) and role or "NONE"
end

local function RaidUnitName(unit)
    if not RaidUnitExists(unit) then return "" end
    local name = UnitName(unit)
    return PF:IsDisplaySafe(name) and name:lower() or ""
end

local function SortRaidGroupUnits(units, sortMethod)
    if sortMethod ~= "role" and sortMethod ~= "name" then return end
    table.sort(units, function(left, right)
        local leftExists, rightExists = RaidUnitExists(left), RaidUnitExists(right)
        if leftExists ~= rightExists then return leftExists end
        if sortMethod == "role" then
            local leftRole = partyRoleSortOrder[RaidUnitRole(left)] or partyRoleSortOrder.NONE
            local rightRole = partyRoleSortOrder[RaidUnitRole(right)] or partyRoleSortOrder.NONE
            if leftRole ~= rightRole then return leftRole < rightRole end
        end
        local leftName, rightName = RaidUnitName(left), RaidUnitName(right)
        if leftName ~= rightName then return leftName < rightName end
        return RaidUnitIndex(left) < RaidUnitIndex(right)
    end)
end

local function BuildRaidUnitOrder(usePartyUnits, sortMethod)
    local ordered = {}
    for index = 1, 40 do
        if usePartyUnits and index == 1 then
            ordered[index] = "player"
        elseif usePartyUnits and index <= 5 then
            ordered[index] = "party" .. (index - 1)
        else
            ordered[index] = "raid" .. index
        end
    end

    for groupIndex = 1, 5 do
        local groupUnits = {}
        local firstIndex = (groupIndex - 1) * 8 + 1
        for row = 0, 7 do
            groupUnits[row + 1] = ordered[firstIndex + row]
        end
        SortRaidGroupUnits(groupUnits, sortMethod)
        for row = 0, 7 do
            ordered[firstIndex + row] = groupUnits[row + 1]
        end
    end
    return ordered
end

function PF:CreateRaidFrames()
    local anchor = CreateFrame("Frame", "PrettyFramesRaidAnchor", UIParent, "BackdropTemplate")
    local frameWidth, frameHeight = unpack(themeLayout.frameSize)
    local columnSpacing, rowSpacing = themeLayout.columnStep, themeLayout.rowStep
    anchor:SetSize(columnSpacing * 4 + frameWidth, rowSpacing * 7 + frameHeight)
    anchor.isAnchor = true
    self.frames.raid = anchor
    self:PlaceFrame(anchor, "raid")
    self:MakeMovable(anchor, "raid")
    RegisterStateDriver(anchor, "visibility", "[group:raid] show; hide")

    anchor.raidGroups = {}
    for groupIndex = 1, 5 do
        local group = CreateFrame("Frame", nil, anchor)
        group:SetSize(frameWidth, rowSpacing * 7 + frameHeight)
        group:SetPoint("TOPLEFT", anchor, "TOPLEFT", (groupIndex - 1) * columnSpacing, 0)
        group:SetMovable(true)
        -- These groups move relative to the global Raid anchor. Clamping each
        -- child separately makes WoW rewrite its offset when the global anchor
        -- approaches a screen edge, causing independently placed columns to
        -- jump during a whole-layout drag.
        group:SetClampedToScreen(false)
        group.raidGroupIndex = groupIndex
        group.defaultX = (groupIndex - 1) * columnSpacing
        anchor.raidGroups[groupIndex] = group
    end

    anchor.rangeUpdateElapsed = 0
    anchor:SetScript("OnUpdate", function(widget, elapsed)
        if not PF.db or not PF.db.locked or PF.testMode or not UnitInRange then return end
        widget.rangeUpdateElapsed = widget.rangeUpdateElapsed + elapsed
        if widget.rangeUpdateElapsed < 0.5 then return end
        widget.rangeUpdateElapsed = 0

        for _, raidFrame in ipairs(widget.raidFrames or {}) do
            if raidFrame:IsShown() then
                local exists = UnitExists(raidFrame.unit)
                local connected = exists and UnitIsConnected(raidFrame.unit)
                local dead = exists and UnitIsDeadOrGhost(raidFrame.unit)
                local inPhase = exists and UnitInPhase and UnitInPhase(raidFrame.unit)
                local unavailable = (PF:IsDisplaySafe(connected) and connected == false)
                    or (PF:IsDisplaySafe(inPhase) and inPhase == false)
                if PF:IsDisplaySafe(exists) and exists == true and unavailable then
                    SetRaidAvailabilityAlpha(raidFrame, RAID_ALPHA_UNAVAILABLE)
                elseif PF:IsDisplaySafe(exists) and exists == true
                    and PF:IsDisplaySafe(dead) and dead ~= true then
                    SetRaidRangeAlpha(raidFrame, UnitInRange(raidFrame.unit))
                else
                    SetRaidAvailabilityAlpha(raidFrame, 1)
                end
            end
        end
    end)

    anchor.raidFrames = {}
    for index = 1, 40 do
        local column = math.floor((index - 1) / 8)
        local group = anchor.raidGroups[column + 1]
        local frame = CreateFrame("Button", "PrettyFramesRaid" .. index, group,
            "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate,BackdropTemplate")
        frame.themeFrameName = "raid"
        frame:SetSize(frameWidth, frameHeight)
        local row = (index - 1) % 8
        frame:SetPoint("TOPLEFT", group, "TOPLEFT", 0, -row * rowSpacing)
        SetSecureUnit(frame, "raid" .. index)
        self:RegisterActionFrame(frame, "raid")
        frame.isRaidFrame = true
        table.insert(self.configurableFrames, frame)

        frame.health = CreateFrame("StatusBar", nil, frame)
        frame.health:SetStatusBarTexture(self:ThemeFrameAsset("raid", "statusBar", "statusBar"))
        frame.health:SetMinMaxValues(0, 1)
        frame.health:SetValue(0)
        PF:SetThemePoint(frame.health, frame, themeLayout.healthTopLeft)
        PF:SetThemePoint(frame.health, frame, themeLayout.healthBottomRight)
        if frame.health.SetClipsChildren then frame.health:SetClipsChildren(true) end

        frame.health.background = frame.health:CreateTexture(nil, "BACKGROUND")
        frame.health.background:SetAllPoints(frame.health)
        frame.health.background:SetColorTexture(0.025, 0.018, 0.012, 1)

        -- Preserve the compact skin's rounded ends at this much narrower width.
        -- Stretch only its nearly uniform middle section instead of squeezing
        -- the complete frame and turning the end caps into thin vertical lines.
        frame.skinLayer = CreateFrame("Frame", nil, frame)
        frame.skinLayer:SetAllPoints(frame)
        frame.skinLayer:SetFrameLevel(frame:GetFrameLevel() + 20)
        frame.skinLayer:EnableMouse(false)

        local artCrop = themeLayout.artCrop
        if themeLayout.fullArt then
            frame.skin = frame.skinLayer:CreateTexture(nil, "ARTWORK")
            frame.skin:SetAllPoints(frame.skinLayer)
            frame.skin:SetTexture(self:ThemeFrameAsset("raid", "raidFrame", "raidFrame"))
            frame.skin:SetTexCoord(unpack(artCrop))
        else
            local capWidth = themeLayout.artCapDisplayWidth
            frame.skinLeft = frame.skinLayer:CreateTexture(nil, "ARTWORK")
            frame.skinLeft:SetPoint("TOPLEFT", frame.skinLayer, "TOPLEFT", 0, 0)
            frame.skinLeft:SetPoint("BOTTOMRIGHT", frame.skinLayer, "BOTTOMLEFT", capWidth, 0)
            frame.skinLeft:SetTexture(self:ThemeFrameAsset("raid", "raidFrame", "raidFrame"))
            frame.skinLeft:SetTexCoord(artCrop[1], themeLayout.artCapPixels / themeLayout.artTextureWidth, artCrop[3], artCrop[4])

            frame.skinMiddle = frame.skinLayer:CreateTexture(nil, "ARTWORK")
            frame.skinMiddle:SetPoint("TOPLEFT", frame.skinLeft, "TOPRIGHT", 0, 0)
            frame.skinMiddle:SetPoint("BOTTOMRIGHT", frame.skinLayer, "BOTTOMRIGHT", -capWidth, 0)
            frame.skinMiddle:SetTexture(self:ThemeFrameAsset("raid", "raidFrame", "raidFrame"))
            frame.skinMiddle:SetTexCoord(themeLayout.artCapPixels / themeLayout.artTextureWidth, 1 - themeLayout.artCapPixels / themeLayout.artTextureWidth, artCrop[3], artCrop[4])

            frame.skinRight = frame.skinLayer:CreateTexture(nil, "ARTWORK")
            frame.skinRight:SetPoint("TOPLEFT", frame.skinLayer, "TOPRIGHT", -capWidth, 0)
            frame.skinRight:SetPoint("BOTTOMRIGHT", frame.skinLayer, "BOTTOMRIGHT", 0, 0)
            frame.skinRight:SetTexture(self:ThemeFrameAsset("raid", "raidFrame", "raidFrame"))
            frame.skinRight:SetTexCoord(1 - themeLayout.artCapPixels / themeLayout.artTextureWidth, artCrop[2], artCrop[3], artCrop[4])
        end

        frame.textLayer = CreateFrame("Frame", nil, frame)
        frame.textLayer:SetAllPoints(frame)
        frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 21)
        frame.textLayer:EnableMouse(false)

        frame.nameText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
        frame.nameText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -6)
        frame.nameText:SetHeight(12)
        frame.nameText:SetJustifyH("LEFT")
        frame.nameText:SetTextColor(1, 0.91, 0.72)
        local nameFont, _, nameFlags = frame.nameText:GetFont()
        frame.nameText:SetFont(nameFont, 8, nameFlags)

        frame.healthText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.healthText:SetAllPoints(frame.health)
        frame.healthText:SetJustifyH("CENTER")
        frame.healthText:SetTextColor(1, 0.96, 0.84)
        PF:ApplyBoldNumberFont(frame.healthText, 9)
        frame.healthText:SetShadowColor(0.02, 0.01, 0, 1)
        frame.healthText:SetShadowOffset(1, -1)

        frame.statusText = frame.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.statusText:SetAllPoints(frame.health)
        frame.statusText:SetJustifyH("CENTER")
        frame.statusText:SetTextColor(1, 0.35, 0.25)
        local statusFont, _, statusFlags = frame.statusText:GetFont()
        frame.statusText:SetFont(statusFont, 8, statusFlags)

        -- All Raid presentation indicators float over the existing art. None
        -- reserve permanent name or health space when their state is absent.
        frame.raidRole = CreateRoleIndicator(frame, themeLayout.roleSize or 20)
        PF:SetThemePoint(
            frame.raidRole,
            frame,
            themeLayout.rolePoint or { "CENTER", "TOPLEFT", 5, -9 }
        )
        frame.raidRole:SetFrameLevel(frame.textLayer:GetFrameLevel() + 2)
        frame.raidRole:Hide()

        frame.raidMarkerLayer = CreateFrame("Frame", nil, frame)
        frame.raidMarkerLayer:SetAllPoints(frame)
        frame.raidMarkerLayer:SetFrameLevel(frame.textLayer:GetFrameLevel() + 5)
        frame.raidMarkerLayer:EnableMouse(false)

        frame.raidMarker = frame.raidMarkerLayer:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.raidMarker:SetSize(themeLayout.marker.size, themeLayout.marker.size)
        PF:SetThemePoint(frame.raidMarker, frame, themeLayout.marker.point)
        frame.raidMarker:Hide()

        frame.groupBadge = frame.textLayer:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.groupBadge:SetSize(16, 16)
        frame.groupBadge:SetPoint("CENTER", frame, "TOPRIGHT", -5, -8)
        frame.groupBadge:Hide()

        frame.raidStatusBackground = frame.textLayer:CreateTexture(nil, "OVERLAY", nil, 6)
        frame.raidStatusBackground:SetSize(20, 20)
        frame.raidStatusBackground:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        frame.raidStatusBackground:SetColorTexture(0.025, 0.018, 0.012, 0.82)
        frame.raidStatusBackground:Hide()

        frame.raidStatusIcon = frame.textLayer:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.raidStatusIcon:SetSize(18, 18)
        frame.raidStatusIcon:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        frame.raidStatusIcon:Hide()

        frame.raidGlow = frame.skinLayer:CreateTexture(nil, "OVERLAY", nil, 7)
        -- The generated 256x128 texture's useful alpha occupies roughly
        -- 200x96 pixels. Compensate for that transparent padding so the
        -- visible halo, rather than its canvas, follows the 100x40 border.
        frame.raidGlow:SetSize(unpack(themeLayout.glowSize))
        frame.raidGlow:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.raidGlow:SetTexture(
            self:ThemeFrameAsset("raid", "raidThreatGlow", "raidThreatGlow")
        )
        frame.raidGlow:SetBlendMode("ADD")
        SetRaidAccent(frame)

        -- Targeting uses paired foliage clasps, leaving the red/orange outer
        -- glow exclusively for threat so both states remain distinct.
        frame.raidTargetHighlight = CreateFrame("Frame", nil, frame.raidMarkerLayer)
        frame.raidTargetHighlight:SetAllPoints(frame)
        frame.raidTargetHighlight:EnableMouse(false)
        frame.raidTargetHighlight:Hide()

        frame.raidTargetOrnamentLeft = frame.raidTargetHighlight:CreateTexture(nil, "OVERLAY", nil, 6)
        frame.raidTargetOrnamentLeft:SetSize(unpack(themeLayout.targetClaspSize))
        frame.raidTargetOrnamentLeft:SetPoint("LEFT", frame, "LEFT", -themeLayout.targetClaspOffset, 0)
        frame.raidTargetOrnamentLeft:SetTexture(
            self:ThemeFrameAsset("raid", "raidTargetClasp", "raidTargetClasp")
        )
        frame.raidTargetOrnamentLeft:SetBlendMode("BLEND")
        frame.raidTargetOrnamentLeft:SetAlpha(1)

        frame.raidTargetOrnamentRight = frame.raidTargetHighlight:CreateTexture(nil, "OVERLAY", nil, 6)
        frame.raidTargetOrnamentRight:SetSize(unpack(themeLayout.targetClaspSize))
        frame.raidTargetOrnamentRight:SetPoint("RIGHT", frame, "RIGHT", themeLayout.targetClaspOffset, 0)
        frame.raidTargetOrnamentRight:SetTexture(
            self:ThemeFrameAsset("raid", "raidTargetClasp", "raidTargetClasp")
        )
        frame.raidTargetOrnamentRight:SetTexCoord(1, 0, 0, 1)
        frame.raidTargetOrnamentRight:SetBlendMode("BLEND")
        frame.raidTargetOrnamentRight:SetAlpha(1)

        CreateGroupHealPrediction(frame)

        frame.nativeDebuffs = CreateRaidDebuffContainer(frame, 20)
        if frame.nativeDebuffs then
            local holder = frame.nativeDebuffs
            if holder.SetClipsChildren then holder:SetClipsChildren(false) end
            holder:SetSize(20, 20)
            holder:ClearAllPoints()
            holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 3)
            holder.container:ClearAllPoints()
            holder.container:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
            holder.container:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
            holder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
            holder.container:SetFlowLayoutMaximumLineSize(20)
        end

        frame.nativeMaintenance = CreateRaidMaintenanceContainer(frame, 13)
        if frame.nativeMaintenance then
            local holder = frame.nativeMaintenance
            holder:SetSize(41, 13)
            holder:ClearAllPoints()
            holder:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, -2)
            holder.container:ClearAllPoints()
            holder.container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
            holder.container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            holder.container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
            holder.container:SetFlowLayoutMaximumLineSize(41)
        end

        frame.raidMaintenancePreview = {}
        local maintenancePreviewIcons = {
            "Interface\\Icons\\Spell_Nature_Rejuvenation",
            "Interface\\Icons\\Spell_Holy_PowerWordShield",
            "Interface\\Icons\\Spell_Holy_DevotionAura",
        }
        for maintenanceIndex, texturePath in ipairs(maintenancePreviewIcons) do
            local indicator = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            indicator:SetSize(13, 13)
            indicator:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5 + (maintenanceIndex - 1) * 14, -2)
            indicator:SetFrameLevel(frame.textLayer:GetFrameLevel() + 3)
            indicator:EnableMouse(false)
            self:CreateBackdrop(indicator, 1)
            if maintenanceIndex == 3 then
                indicator:SetBackdropBorderColor(0.30, 0.62, 1.00, 0.78)
            else
                indicator:SetBackdropBorderColor(0.30, 0.82, 0.38, 0.78)
            end
            indicator.icon = indicator:CreateTexture(nil, "ARTWORK")
            indicator.icon:SetPoint("TOPLEFT", 1, -1)
            indicator.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            indicator.icon:SetTexture(texturePath)
            indicator.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            indicator:Hide()
            frame.raidMaintenancePreview[maintenanceIndex] = indicator
        end

        frame.raidDebuffs = {}
        for debuffIndex = 1, 1 do
            local debuff = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            debuff:SetSize(20, 20)
            debuff:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 3)
            debuff:SetFrameLevel(frame.textLayer:GetFrameLevel() + 3)
            debuff:EnableMouse(false)
            self:CreateBackdrop(debuff, 1)
            debuff:SetBackdropBorderColor(0.82, 0.20, 0.12, 1)
            debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
            debuff.icon:SetPoint("TOPLEFT", 2, -2)
            debuff.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            debuff.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            debuff:Hide()
            frame.raidDebuffs[debuffIndex] = debuff
        end

        frame.availabilityFadeRegions = {
            frame.health,
            frame.skinLayer,
            frame.raidMarkerLayer,
            frame.nativeDebuffs,
            frame.nativeMaintenance,
            frame.raidRole,
            frame.groupBadge,
        }
        frame.availabilityFadeRegionGroups = {
            frame.raidDebuffs,
            frame.raidMaintenancePreview,
        }

        table.insert(self.unitFrames, frame)
        anchor.raidFrames[index] = frame
    end

    anchor.raidHeaders = {}
    for column = 0, 4 do
        local firstFrame = anchor.raidFrames[column * 8 + 1]
        local groupIndex = column + 1
        local raidGroup = anchor.raidGroups[groupIndex]
        local header = CreateFrame("Frame", nil, raidGroup)
        header:SetSize(unpack(themeLayout.headerSize))
        header:SetPoint("BOTTOM", firstFrame, "TOP", 0, themeLayout.headerGap)
        -- Keep the header above the frame artwork and its outward-facing leaf accents.
        header:SetFrameLevel(firstFrame:GetFrameLevel() + 30)
        header.editBaseStrata = header:GetFrameStrata()
        header.editBaseLevel = header:GetFrameLevel()
        header:EnableMouse(false)

        header.art = header:CreateTexture(nil, "ARTWORK")
        header.art:SetAllPoints(header)
        header.art:SetTexture(
            self:ThemeFrameAsset("raid", "raidGroupHeader", "raidGroupHeader")
        )

        header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.text:SetPoint("CENTER", header, "CENTER", 0, 0)
        header.text:SetText("GROUP " .. (column + 1))
        header.text:SetTextColor(1, 0.91, 0.72)
        header.text:SetShadowColor(0.02, 0.01, 0, 1)
        header.text:SetShadowOffset(1, -1)
        local headerFont, _, headerFlags = header.text:GetFont()
        header.text:SetFont(headerFont, 9, headerFlags)

        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function()
            local options = PF.db and PF.db.raidLayout
            if options and options.independentPositioning and not PF.db.locked and not InCombatLockdown() then
                raidGroup:StartMoving()
            end
        end)
        header:SetScript("OnDragStop", function()
            raidGroup:StopMovingOrSizing()
            PF:SaveRaidGroupOffset(groupIndex)
        end)

        anchor.raidHeaders[column + 1] = header
    end

    -- Leave the generated headers unobstructed while editing the Raid group.
    anchor.moveHandle:ClearAllPoints()
    anchor.moveHandle:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 37)

    local function AddEdgeLeaves(frame, texturePath, relativePoint, x, y, flipHorizontal, flipVertical)
        local leaves = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        leaves:SetSize(unpack(themeLayout.leavesSize))
        leaves:SetPoint("CENTER", frame, relativePoint, x, y)
        leaves:SetTexture(texturePath)
        leaves:SetTexCoord(
            flipHorizontal and 1 or 0,
            flipHorizontal and 0 or 1,
            flipVertical and 1 or 0,
            flipVertical and 0 or 1
        )
        frame.edgeLeaves = frame.edgeLeaves or {}
        table.insert(frame.edgeLeaves, leaves)
    end

    -- This fixed selection alternates around the twenty-two-frame perimeter,
    -- preventing runs of neighboring decorated frames. Only top/bottom frames
    -- may receive a second accent; side-edge frames always receive exactly one.
    for _, leaf in ipairs(themeLayout.edgeLeaves) do
        AddEdgeLeaves(
            anchor.raidFrames[leaf[1]], self:ThemeFrameAsset("raid", leaf[2], leaf[2]),
            leaf[3], leaf[4], leaf[5], leaf[6], leaf[7]
        )
    end

    -- Reuse the Party-frame vine as a vertical link between neighboring raid
    -- members. Each secure connector watches the lower unit and is parented to
    -- the upper frame, so it naturally disappears unless both frames exist.
    anchor.raidConnectors = {}
    for column = 0, 4 do
        for row = 1, 7 do
            local upperIndex = column * 8 + row
            local upper = anchor.raidFrames[upperIndex]
            local lower = anchor.raidFrames[upperIndex + 1]
            local connectorIndex = column * 7 + row
            local connector = CreateFrame(
                "Button",
                "PrettyFramesRaidConnector" .. connectorIndex,
                upper,
                "SecureUnitButtonTemplate"
            )
            connector:SetSize(unpack(themeLayout.connectorSize))
            connector:SetPoint("CENTER", upper, "TOPLEFT", frameWidth / 2, themeLayout.connectorYOffset)
            connector:SetFrameLevel(upper:GetFrameLevel())
            connector:EnableMouse(false)
            if connector.SetClipsChildren then
                connector:SetClipsChildren(true)
            end
            connector:SetAttribute("unit", lower.unit)

            -- Display a 28x36 window while sampling a smaller 22x29 region of
            -- the Party connector. This enlarges the vine by roughly 25%
            -- without letting either strand occupy more of the health bar.
            local verticalOffset = (row - 1) * themeLayout.connectorSampleStep
            connector.leftTexture = connector:CreateTexture(nil, "BACKGROUND")
            connector.leftTexture:SetSize(unpack(themeLayout.connectorStrandSize))
            connector.leftTexture:SetPoint("CENTER", connector, "LEFT", themeLayout.connectorLeftX, 0)
            connector.leftTexture:SetTexture(
                self:ThemeFrameAsset("raid", "partyConnector", "partyConnector"),
                "CLAMP", "REPEAT"
            )
            connector.leftTexture:SetTexCoord(
                themeLayout.connectorSourceLeft, themeLayout.connectorSourceRight,
                verticalOffset, verticalOffset + themeLayout.connectorSampleHeight
            )

            -- A second, mirrored strand sits toward the right side. Offset its
            -- vertical sample so adjacent leaves and curls do not line up with
            -- the left strand even though both reuse the same source texture.
            local rightVerticalOffset = verticalOffset + themeLayout.connectorRightSampleOffset
            connector.rightTexture = connector:CreateTexture(nil, "BACKGROUND")
            connector.rightTexture:SetSize(unpack(themeLayout.connectorStrandSize))
            connector.rightTexture:SetPoint("CENTER", connector, "LEFT", themeLayout.connectorRightX, 0)
            connector.rightTexture:SetTexture(
                self:ThemeFrameAsset("raid", "partyConnector", "partyConnector"),
                "CLAMP", "REPEAT"
            )
            connector.rightTexture:SetTexCoord(
                themeLayout.connectorSourceRight, themeLayout.connectorSourceLeft,
                rightVerticalOffset, rightVerticalOffset + themeLayout.connectorSampleHeight
            )

            connector.upperFrame = upper
            connector.lowerFrame = lower
            RegisterUnitWatch(connector)
            anchor.raidConnectors[connectorIndex] = connector
        end
    end

    for _, frame in ipairs(anchor.raidFrames) do
        frame.OnVisibilityApplied = function()
            PF:UpdateRaidConnectors()
        end
    end

    anchor.moveHandle:SetScript("OnMouseUp", function(handle, mouseButton)
        if mouseButton == "RightButton" then
            PF:OpenRaidContextMenu(handle)
        end
    end)

    self:ApplyRaidUnitBindings()
    self:ApplyRaidGroupLayout()
    self:ApplyRaidGroupVisibility()
end

function PF:ApplyRaidHeaderDisplay()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidHeaders then return end

    local options = self.db.raidLayout
    local showHeaders = options.showHeaders ~= false
    local editing = not self.db.locked
    local hidden = options.visibility == "hide"
    local positioning = options.independentPositioning == true and editing
    local displayHeaders = showHeaders and (not hidden or editing)
    for _, header in ipairs(anchor.raidHeaders) do
        -- A dimmed header remains available as the group drag handle while
        -- editing an independently positioned layout. Always Hide takes
        -- precedence over test mode, matching the Raid unit frames, but leaves
        -- the header visible at half alpha while the layout is unlocked.
        header:SetShown(displayHeaders or positioning)
        header:SetAlpha(showHeaders and not hidden and 1 or 0.5)
        header:EnableMouse(positioning)
        if positioning then
            self:RaiseEditHandle(header)
        else
            header:SetFrameStrata(header.editBaseStrata or "MEDIUM")
            header:SetFrameLevel(header.editBaseLevel or 30)
        end
    end
end

function PF:ApplyRaidGroupLayout()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidGroups then return end
    if InCombatLockdown() then
        self.pendingRaidLayout = true
        return false
    end

    local options = self.db.raidLayout
    for groupIndex, group in ipairs(anchor.raidGroups) do
        local offset = options.groupOffsets and options.groupOffsets[groupIndex] or { 0, 0 }
        local offsetX = options.independentPositioning and offset[1] or 0
        local offsetY = options.independentPositioning and offset[2] or 0
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", anchor, "TOPLEFT", group.defaultX + offsetX, offsetY)
    end

    self.pendingRaidLayout = nil
    self:ApplyRaidHeaderDisplay()
    return true
end

function PF:SaveRaidGroupOffset(groupIndex)
    local anchor = self.frames.raid
    local group = anchor and anchor.raidGroups and anchor.raidGroups[groupIndex]
    local options = self.db and self.db.raidLayout
    if not group or not options or not options.independentPositioning or InCombatLockdown() then return end

    local groupLeft, groupTop = group:GetLeft(), group:GetTop()
    local anchorLeft, anchorTop = anchor:GetLeft(), anchor:GetTop()
    if not groupLeft or not groupTop or not anchorLeft or not anchorTop then return end

    options.groupOffsets = options.groupOffsets or {}
    options.groupOffsets[groupIndex] = {
        groupLeft - anchorLeft - group.defaultX,
        groupTop - anchorTop,
    }
    self:ApplyRaidGroupLayout()
end

function PF:SaveRaidGroupOffsets()
    local anchor = self.frames.raid
    local options = self.db and self.db.raidLayout
    if not anchor or not anchor.raidGroups or not options
        or not options.independentPositioning or InCombatLockdown() then return end

    local anchorLeft, anchorTop = anchor:GetLeft(), anchor:GetTop()
    if not anchorLeft or not anchorTop then return end

    options.groupOffsets = options.groupOffsets or {}
    for groupIndex, group in ipairs(anchor.raidGroups) do
        local groupLeft, groupTop = group:GetLeft(), group:GetTop()
        if groupLeft and groupTop then
            options.groupOffsets[groupIndex] = {
                groupLeft - anchorLeft - group.defaultX,
                groupTop - anchorTop,
            }
        end
    end
end


function PF:ApplyRaidGroupVisibility()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidFrames then return end

    for _, frame in ipairs(anchor.raidFrames) do
        self:ApplyFrameVisibility(frame)
        self:UpdateUnitFrame(frame, true)
    end
    self:UpdateRaidConnectors()
    self:ApplyRaidHeaderDisplay()
    self:ApplyGroupStateDrivers()
end

function PF:ApplyRaidUnitBindings()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidFrames then return end
    if InCombatLockdown() then
        self.pendingRaidUnitBindings = true
        return false
    end

    local options = self.db.raidLayout
    local inGroup = IsInGroup and IsInGroup()
    local inRaid = IsInRaid and IsInRaid()
    local usePartyUnits = options.useInParty and inGroup and not inRaid
    local orderedUnits = BuildRaidUnitOrder(usePartyUnits, options.sort)
    for index, frame in ipairs(anchor.raidFrames) do
        local unit = orderedUnits[index]

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

    for _, connector in ipairs(anchor.raidConnectors or {}) do
        UnregisterUnitWatch(connector)
        connector:SetAttribute("unit", connector.lowerFrame.unit)
    end

    self.pendingRaidUnitBindings = nil
    self:UpdateRaidConnectors()
    return true
end

function PF:UpdateRaidConnectors()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidConnectors or InCombatLockdown() then return end

    local visibility = self.db.raidLayout and self.db.raidLayout.visibility or "auto"
    local editing = self.db and not self.db.locked
    for _, connector in ipairs(anchor.raidConnectors) do
        if visibility == "hide" then
            UnregisterUnitWatch(connector)
            connector:Hide()
        elseif editing or self.testMode or visibility == "show" then
            UnregisterUnitWatch(connector)
            connector:Show()
        else
            RegisterUnitWatch(connector)
        end
    end
end

function PF:UpdateRaidPresentation(frame, exists, previewIndex, disconnected, dead)
    if not frame.isRaidFrame then return end

    -- Presentation refreshes run after ApplyFrameVisibility and used to undo
    -- the half-alpha Always Hide preview whenever test mode was also active.
    local hiddenPreview = not self.db.locked
        and self.db.raidLayout
        and self.db.raidLayout.visibility == "hide"
    frame:SetAlpha(hiddenPreview and 0.5 or 1)
    SetRaidAvailabilityAlpha(frame, 1)

    frame.raidRole:Hide()
    SetRaidMarkerTexture(frame.raidMarker)
    SetRaidTargetHighlight(frame, false)
    frame.groupBadge:Hide()
    SetRaidStatusIcon(frame)
    SetRaidAccent(frame)
    HideGroupHealPrediction(frame)
    for _, debuff in ipairs(frame.raidDebuffs or {}) do
        debuff:Hide()
    end
    for _, indicator in ipairs(frame.raidMaintenancePreview or {}) do
        indicator:Hide()
    end
    frame.raidHasRole = false
    frame.raidHasDebuff = false
    LayoutRaidName(frame)

    if self.testMode then
        if previewIndex == 17 then
            self:SetRaidStatusText(frame, "AFK")
        elseif previewIndex == 18 then
            self:SetRaidStatusText(frame, "OFFLINE")
        elseif previewIndex == 20 then
            self:SetRaidStatusText(frame, "DEAD")
            frame.health:SetStatusBarColor(unpack(self.colors.dead))
        else
            self:SetRaidStatusText(frame, "")
        end

        local previewRoles = { [1] = "TANK", [2] = "HEALER" }
        local role = previewRoles[previewIndex]
        if self.db.raidLayout.showRoleIcons ~= false and role then
            SetPartyRole(frame.raidRole, role)
            frame.raidRole:Show()
            frame.raidHasRole = true
            LayoutRaidName(frame)
        end

        if self.db.raidLayout.showLeadership ~= false and previewIndex == 3 then
            frame.groupBadge:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            frame.groupBadge:Show()
        elseif self.db.raidLayout.showLeadership ~= false and previewIndex == 4 then
            frame.groupBadge:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            frame.groupBadge:Show()
        elseif previewIndex == 5 then
            SetRaidMarkerTexture(frame.raidMarker, 8)
        elseif previewIndex == 6 then
            SetRaidMarkerTexture(frame.raidMarker, 1)
        elseif self.db.raidLayout.showTargetHighlight ~= false and previewIndex == 7 then
            SetRaidTargetHighlight(frame, true)
        elseif self.db.raidLayout.showThreat ~= false and previewIndex == 8 then
            SetRaidAccent(frame, 1.00, 0.18, 0.10, 1)
        end

        local previewStatusIcons = {
            [11] = "Interface\\RaidFrame\\ReadyCheck-Ready",
            [12] = "Interface\\Icons\\Spell_Holy_Resurrection",
            [13] = "Interface\\Icons\\Spell_Shadow_Twilight",
            [14] = "Interface\\Icons\\Spell_Arcane_Blink",
        }
        SetRaidStatusIcon(frame, previewStatusIcons[previewIndex])

        local showPreviewDebuff = previewIndex == 9
            and self.db.raidLayout.showDebuffs ~= false
        local showPreviewDispellable = previewIndex == 10
            and self.db.raidLayout.showDispellableDebuffs ~= false
        if showPreviewDebuff or showPreviewDispellable then
            local debuff = frame.raidDebuffs[1]
            debuff.icon:SetTexture(previewIndex == 9
                and "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
                or "Interface\\Icons\\Spell_Nature_NullifyDisease")
            if previewIndex == 10 then
                debuff:SetBackdropBorderColor(0.25, 0.72, 1.00, 1)
            else
                debuff:SetBackdropBorderColor(0.82, 0.20, 0.12, 1)
            end
            debuff:Show()
            frame.raidHasDebuff = true
            LayoutRaidName(frame)
        end

        if self.db.raidLayout.showMaintenance ~= false and previewIndex == 21 then
            for _, indicator in ipairs(frame.raidMaintenancePreview or {}) do
                indicator:Show()
            end
        end

        local prediction = frame.groupPrediction
        if prediction and self.db.raidLayout.showPredictions ~= false and previewIndex == 15 then
            prediction.myHeals:SetMinMaxValues(0, 100)
            prediction.myHeals:SetValue(22)
            prediction.myHeals:Show()
        end
        if prediction and self.db.raidLayout.showPredictions ~= false and previewIndex == 16 then
            prediction.myHeals:SetMinMaxValues(0, 100)
            prediction.myHeals:SetValue(0)
            prediction.myHeals:Show()
            prediction.otherHeals:SetMinMaxValues(0, 100)
            prediction.otherHeals:SetValue(0)
            prediction.otherHeals:Show()
            prediction.absorbs:SetMinMaxValues(0, 100)
            prediction.absorbs:SetValue(20)
            prediction.absorbs:Show()
        end
        if prediction and self.db.raidLayout.showHealAbsorbs ~= false and previewIndex == 22 then
            prediction.healAbsorbs:SetMinMaxValues(0, 100)
            prediction.healAbsorbs:SetValue(24)
            prediction.healAbsorbs:Show()
        end

        if previewIndex == 14 or previewIndex == 18 then
            SetRaidAvailabilityAlpha(frame, RAID_ALPHA_UNAVAILABLE)
        elseif previewIndex == 19 then
            SetRaidAvailabilityAlpha(frame, RAID_ALPHA_OUT_OF_RANGE)
        else
            SetRaidAvailabilityAlpha(frame, 1)
        end
        return
    end

    if not exists then return end
    local unit = frame.unit
    if self.db.raidLayout.showRoleIcons ~= false and UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if self:IsDisplaySafe(role) and (role == "TANK" or role == "HEALER") then
            SetPartyRole(frame.raidRole, role)
            frame.raidRole:Show()
            frame.raidHasRole = true
            LayoutRaidName(frame)
        end
    end

    if GetRaidTargetIndex then
        local markerIndex = GetRaidTargetIndex(unit)
        SetRaidMarkerTexture(frame.raidMarker, markerIndex)
    end

    local isLeader = UnitIsGroupLeader and UnitIsGroupLeader(unit)
    local isAssistant = UnitIsGroupAssistant and UnitIsGroupAssistant(unit)
    if self.db.raidLayout.showLeadership ~= false
        and self:IsDisplaySafe(isLeader) and isLeader == true then
        frame.groupBadge:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        frame.groupBadge:Show()
    elseif self.db.raidLayout.showLeadership ~= false
        and self:IsDisplaySafe(isAssistant) and isAssistant == true then
        frame.groupBadge:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        frame.groupBadge:Show()
    end

    local statusTexture
    local hasResurrection = UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit)
    if self:IsDisplaySafe(hasResurrection) and hasResurrection == true then
        statusTexture = "Interface\\Icons\\Spell_Holy_Resurrection"
    elseif C_IncomingSummon and C_IncomingSummon.HasIncomingSummon then
        local hasSummon = C_IncomingSummon.HasIncomingSummon(unit)
        if self:IsDisplaySafe(hasSummon) and hasSummon == true then
            statusTexture = "Interface\\Icons\\Spell_Shadow_Twilight"
        end
    end
    if not statusTexture and GetReadyCheckStatus then
        local readyStatus = GetReadyCheckStatus(unit)
        if self:IsDisplaySafe(readyStatus) and readyStatus then
            if readyStatus == "ready" then
                statusTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
            elseif readyStatus == "notready" then
                statusTexture = "Interface\\RaidFrame\\ReadyCheck-NotReady"
            elseif readyStatus == "waiting" then
                statusTexture = "Interface\\RaidFrame\\ReadyCheck-Waiting"
            end
        end
    end
    local outOfPhase = false
    if UnitInPhase then
        local inPhase = UnitInPhase(unit)
        if self:IsDisplaySafe(inPhase) and inPhase == false then
            outOfPhase = true
            if not statusTexture then
                statusTexture = "Interface\\Icons\\Spell_Arcane_Blink"
            end
        end
    end
    SetRaidStatusIcon(frame, statusTexture)

    local isTarget = UnitIsUnit and UnitIsUnit(unit, "target")
    local threat = UnitThreatSituation and UnitThreatSituation(unit)
    if self.db.raidLayout.showTargetHighlight ~= false
        and self:IsDisplaySafe(isTarget) and isTarget == true then
        SetRaidTargetHighlight(frame, true)
    end
    if self.db.raidLayout.showThreat ~= false
        and self:IsDisplaySafe(threat) and threat and threat >= 2 then
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        local isTank = self:IsDisplaySafe(role) and role == "TANK"
        if threat == 2 then
            SetRaidAccent(frame, 1.00, 0.48, 0.08, 1)
        elseif not isTank then
            SetRaidAccent(frame, 1.00, 0.18, 0.10, 1)
        end
    end

    if self.db.locked then
        if disconnected or outOfPhase then
            SetRaidAvailabilityAlpha(frame, RAID_ALPHA_UNAVAILABLE)
        elseif not dead and UnitInRange then
            SetRaidRangeAlpha(frame, UnitInRange(unit))
        end
    end
    self:UpdateRaidHealPrediction(frame)
end

