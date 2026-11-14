local _, PF = ...

local themeLayout = PF:ThemeLayout("raid")

local CreateRoleIndicator = PF.Widgets.CreateRoleIndicator
local SetSecureUnit = PF.Widgets.SetSecureUnit
local CreateRaidDebuffContainer = PF.Auras.CreateRaidDebuffContainer
local CreateRaidMaintenanceContainer = PF.Auras.CreateRaidMaintenanceContainer
local RAID_ALPHA_UNAVAILABLE = 0.34
local SetAvailabilityAlpha = PF.Widgets.SetAvailabilityAlpha
local SetRangeAlpha = PF.Widgets.SetRangeAlpha

local function SetRaidAvailabilityAlpha(frame, alpha)
    SetAvailabilityAlpha(frame, alpha)
    -- Names, health text, and central status indicators intentionally remain
    -- at full opacity so the reason for fading never becomes unreadable.
    frame.raidAvailabilityAlpha = alpha
end

local function SetRaidRangeAlpha(frame, inRange, outOfRangeAlpha)
    SetRangeAlpha(frame, inRange, outOfRangeAlpha)
    frame.raidAvailabilityAlpha = frame.availabilityAlpha
end

local partyRoleSortOrder = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

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

        frame.unitRoleIndicator = frame.raidRole
        frame.unitLeadershipIndicator = frame.groupBadge
        frame.unitTargetHighlight = frame.raidTargetHighlight
        frame.unitRaidMarker = frame.raidMarker

        self.HealPredictionBehavior:CreateFrame(frame)

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

    self.FrameBehaviors:AttachGroup(anchor, {
        kind = "raid",
        getFrames = function() return anchor.raidFrames end,
        getOptions = function() return PF.db and PF.db.raidLayout end,
        behaviors = {
            outOfRange = {
                fadeLabel = "Fade Out-of-Range Members",
                setAvailabilityAlpha = SetRaidAvailabilityAlpha,
                setRangeAlpha = SetRaidRangeAlpha,
            },
            actions = {
                category = "raid",
            },
            healthText = {
                getMode = function() return PF.db.raidLayout.healthTextMode end,
                setMode = function(value) PF.db.raidLayout.healthTextMode = value end,
                getColorMode = function() return PF.db.raidLayout.healthColorMode end,
                setColorMode = function(value) PF.db.raidLayout.healthColorMode = value end,
                getBackgroundAlpha = function()
                    return PF.db.raidLayout.healthBackgroundAlpha
                end,
                setBackgroundAlpha = function(value)
                    PF.db.raidLayout.healthBackgroundAlpha = value
                end,
                getIncomingHeals = function()
                    return PF.db.raidLayout.accountForIncomingHeals == true
                end,
                setIncomingHeals = function(value)
                    PF.db.raidLayout.accountForIncomingHeals = value == true
                end,
                getIncomingHealAmount = function(frame, healthMax, testMode)
                    return PF:GetGroupIncomingHeals(frame, healthMax, testMode)
                end,
                afterTextUpdated = function(frame, hasValue)
                    frame.raidHealthTextHasValue = hasValue == true
                    UpdateRaidTextVisibility(frame)
                end,
                markChanged = function()
                    PF.DisplayProfileBehavior:MarkCustom(anchor)
                end,
                refresh = function() return PF:RefreshRaidFrames() end,
            },
            healPrediction = true,
            scale = {
                getScale = function() return PF.db.raidLayout.scale or 1 end,
                setScale = function(value) PF.db.raidLayout.scale = value end,
                apply = function() PF:RefreshScale() end,
            },
            visibility = {
                getVisibility = function()
                    return PF.db.raidLayout.visibility or "auto"
                end,
                setVisibility = function(value) PF.db.raidLayout.visibility = value end,
                apply = function() PF:ApplyRaidGroupVisibility() end,
                isEnabled = function()
                    return PF.db.replaceRaidFrames ~= false
                end,
                getStateVisibility = function()
                    local options = PF.db.raidLayout
                    if options.visibility == "show" then return "show" end
                    if options.visibility == "hide" then return "hide" end

                    local inGroup = IsInGroup and IsInGroup()
                    local inRaid = IsInRaid and IsInRaid()
                    local useSmallRaidParty = PF:ShouldUsePartyFramesForSmallRaid()
                    local showRaid = (inRaid and not useSmallRaidParty)
                        or (not inRaid and options.useInParty and inGroup)
                    return showRaid and "show" or "hide"
                end,
                getStateDriver = function()
                    local options = PF.db.raidLayout
                    if options.visibility == "hide" then return "hide" end

                    if options.visibility == "show" then
                        return anchor.prettyFramesBindingMode == "party"
                            and "[group:raid] hide; show"
                            or "[group:raid] show; hide"
                    end

                    local raidState = "show"
                    if PF.db.partyLayout.useInSmallRaid == true
                        and PF:ShouldUsePartyFramesForSmallRaid() then
                        -- Raid-size thresholds are not expressible in secure
                        -- macro conditions; retain the current threshold result.
                        raidState = "hide"
                    end
                    local partyState = options.useInParty and "show" or "hide"
                    if anchor.prettyFramesBindingMode == "party" then
                        -- The first rows currently target player/partyN and
                        -- cannot safely become raid rows until combat ends.
                        return ("[group:raid] hide; [group] %s; hide"):format(
                            partyState
                        )
                    end
                    return ("[group:raid] %s; hide"):format(raidState)
                end,
            },
            auraIndicators = true,
            threat = true,
            unitIndicators = {
                showDamageRole = false,
                setStatusText = function(frame, text)
                    PF:SetRaidStatusText(frame, text)
                end,
                afterApply = function(frame, state)
                    frame.raidHasRole = state.roleShown == true
                    LayoutRaidName(frame)
                end,
            },
            displayProfile = {
                profileSet = "raid",
                refresh = function()
                    PF.AuraIndicatorBehavior:RefreshSubject(anchor)
                end,
            },
            groupUsage = {
                apply = function()
                    PF:ApplyRaidUnitBindings()
                    return PF:ApplyGroupStateDrivers()
                end,
            },
            groupUnitBinding = {
                getUnits = function()
                    local options = PF.db.raidLayout
                    local inGroup = IsInGroup and IsInGroup()
                    local inRaid = IsInRaid and IsInRaid()
                    local usePartyUnits = options.useInParty and inGroup and not inRaid
                    anchor.prettyFramesBindingMode = usePartyUnits and "party" or "raid"
                    return BuildRaidUnitOrder(usePartyUnits, options.sort)
                end,
                afterApply = function()
                    local result = PF.GroupConnectorBehavior:SyncUnits(anchor)
                    PF:ApplyGroupStateDrivers()
                    return result
                end,
            },
            groupLayout = {
                beforeOptionChanged = function(key, previous)
                    if key == "independentPositioning" and previous == true then
                        PF:SaveRaidGroupOffsets()
                    end
                end,
                applyOption = function(key)
                    if key == "showHeaders" then
                        return PF:ApplyRaidHeaderDisplay()
                    elseif key == "sort" then
                        return PF:ApplyRaidUnitBindings()
                    end
                    return PF:ApplyRaidGroupLayout()
                end,
                refresh = function() return PF:PerformRaidGroupLayout() end,
                afterEditModeChanged = function()
                    return PF:ApplyRaidUnitBindings()
                end,
            },
            groupConnectors = {
                namePrefix = "PrettyFramesRaidConnector",
                storageKey = "raidConnectors",
                previewHiddenWhileEditing = false,
                getVisibility = function()
                    return PF.db.raidLayout.visibility or "auto"
                end,
                isEnabled = function()
                    return PF.db.replaceRaidFrames ~= false
                end,
                getPairs = function()
                    local pairs = {}
                    for column = 0, 4 do
                        for row = 1, 7 do
                            local upperIndex = column * 8 + row
                            table.insert(pairs, {
                                upper = anchor.raidFrames[upperIndex],
                                lower = anchor.raidFrames[upperIndex + 1],
                                row = row,
                            })
                        end
                    end
                    return pairs
                end,
                initializeConnector = function(connector, pair)
                    local upper = pair.upper
                    connector:SetSize(unpack(themeLayout.connectorSize))
                    connector:SetPoint(
                        "CENTER", upper, "TOPLEFT", frameWidth / 2,
                        themeLayout.connectorYOffset
                    )
                    connector:SetFrameLevel(upper:GetFrameLevel())
                    if connector.SetClipsChildren then
                        connector:SetClipsChildren(true)
                    end

                    local offset = (pair.row - 1) * themeLayout.connectorSampleStep
                    connector.leftTexture = connector:CreateTexture(nil, "BACKGROUND")
                    connector.leftTexture:SetSize(unpack(themeLayout.connectorStrandSize))
                    connector.leftTexture:SetPoint(
                        "CENTER", connector, "LEFT", themeLayout.connectorLeftX, 0
                    )
                    connector.leftTexture:SetTexture(
                        PF:ThemeFrameAsset("raid", "partyConnector", "partyConnector"),
                        "CLAMP", "REPEAT"
                    )
                    connector.leftTexture:SetTexCoord(
                        themeLayout.connectorSourceLeft,
                        themeLayout.connectorSourceRight,
                        offset,
                        offset + themeLayout.connectorSampleHeight
                    )

                    local rightOffset = offset + themeLayout.connectorRightSampleOffset
                    connector.rightTexture = connector:CreateTexture(nil, "BACKGROUND")
                    connector.rightTexture:SetSize(unpack(themeLayout.connectorStrandSize))
                    connector.rightTexture:SetPoint(
                        "CENTER", connector, "LEFT", themeLayout.connectorRightX, 0
                    )
                    connector.rightTexture:SetTexture(
                        PF:ThemeFrameAsset("raid", "partyConnector", "partyConnector"),
                        "CLAMP", "REPEAT"
                    )
                    connector.rightTexture:SetTexCoord(
                        themeLayout.connectorSourceRight,
                        themeLayout.connectorSourceLeft,
                        rightOffset,
                        rightOffset + themeLayout.connectorSampleHeight
                    )
                end,
            },
        },
    })

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

    anchor.moveHandle:SetScript("OnMouseUp", function(handle, mouseButton)
        if mouseButton == "RightButton" then
            PF:OpenRaidContextMenu(handle)
        end
    end)

    self:ApplyRaidUnitBindings()
    self.AuraIndicatorBehavior:RefreshSubject(anchor)
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

function PF:PerformRaidGroupLayout()
    local anchor = self.frames.raid
    if not anchor or not anchor.raidGroups then return end
    local options = self.db.raidLayout
    for groupIndex, group in ipairs(anchor.raidGroups) do
        local offset = options.groupOffsets and options.groupOffsets[groupIndex] or { 0, 0 }
        local offsetX = options.independentPositioning and offset[1] or 0
        local offsetY = options.independentPositioning and offset[2] or 0
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", anchor, "TOPLEFT", group.defaultX + offsetX, offsetY)
    end

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

    SetRaidStatusIcon(frame)
    SetRaidAccent(frame)
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
        if self.db.raidLayout.showThreat ~= false and previewIndex == 8 then
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

        if previewIndex == 14 or previewIndex == 18 then
            SetRaidAvailabilityAlpha(frame, RAID_ALPHA_UNAVAILABLE)
        elseif previewIndex == 19 then
            SetRaidAvailabilityAlpha(frame, self.db.raidLayout.outOfRangeAlpha or 0.55)
        else
            SetRaidAvailabilityAlpha(frame, 1)
        end
        return
    end

    if not exists then return end
    local unit = frame.unit

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

    local threat = UnitThreatSituation and UnitThreatSituation(unit)
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

end

