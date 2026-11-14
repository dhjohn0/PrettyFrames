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
    frame.unitLeadershipIndicator:ClearAllPoints()

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
    frame.unitLeadershipIndicator:SetPoint(
        "CENTER", frame, flipped and "TOPLEFT" or "TOPRIGHT",
        flipped and 52 or -52, -20
    )

    frame.health:SetReverseFill(flipped == true)
    frame.power:SetReverseFill(flipped == true)
    PF.HealPredictionBehavior:LayoutFrame(frame, flipped == true)
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

    frame.unitLeadershipIndicator = frame.textLayer:CreateTexture(
        nil, "OVERLAY", nil, 7
    )
    frame.unitLeadershipIndicator:SetSize(20, 20)
    frame.unitLeadershipIndicator:SetPoint("CENTER", frame, "TOPRIGHT", -52, -20)
    frame.unitLeadershipIndicator:Hide()

    frame.unitTargetHighlight = CreateFrame("Frame", nil, frame.textLayer)
    frame.unitTargetHighlight:SetAllPoints(frame)
    frame.unitTargetHighlight:EnableMouse(false)
    frame.unitTargetHighlight:Hide()
    local claspWidth = math.max(16, math.floor(width * 0.055))
    local claspHeight = math.max(40, math.floor(height * 0.62))
    frame.unitTargetOrnamentLeft = frame.unitTargetHighlight:CreateTexture(
        nil, "OVERLAY", nil, 6
    )
    frame.unitTargetOrnamentLeft:SetSize(claspWidth, claspHeight)
    frame.unitTargetOrnamentLeft:SetPoint("LEFT", frame, "LEFT", -3, 0)
    frame.unitTargetOrnamentLeft:SetTexture(
        self:ThemeFrameAsset("raid", "raidTargetClasp", "raidTargetClasp")
    )
    frame.unitTargetOrnamentRight = frame.unitTargetHighlight:CreateTexture(
        nil, "OVERLAY", nil, 6
    )
    frame.unitTargetOrnamentRight:SetSize(claspWidth, claspHeight)
    frame.unitTargetOrnamentRight:SetPoint("RIGHT", frame, "RIGHT", 3, 0)
    frame.unitTargetOrnamentRight:SetTexture(
        self:ThemeFrameAsset("raid", "raidTargetClasp", "raidTargetClasp")
    )
    frame.unitTargetOrnamentRight:SetTexCoord(1, 0, 0, 1)

    frame.unitRoleIndicator = frame.roleIndicator
    frame.unitRaidMarker = frame.unitMarker

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

    self.HealPredictionBehavior:CreateFrame(frame, themeLayout)

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
end

local function BuildPartyUnitOrder()
    local units = {}
    if IsInRaid and IsInRaid() then
        local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
        for raidIndex = 1, groupSize do
            local raidUnit = "raid" .. raidIndex
            local isPlayer = UnitIsUnit and UnitIsUnit(raidUnit, "player")
            if not (PF:IsDisplaySafe(isPlayer) and isPlayer == true) then
                table.insert(units, raidUnit)
                if #units == 4 then break end
            end
        end
    end
    for index = 1, 4 do
        units[index] = units[index] or ("party" .. index)
    end
    return units
end

function PF:CreatePartyFrames()
    local anchor = CreateFrame("Frame", "PrettyFramesPartyAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(themeLayout.size[1], 1)
    anchor.isAnchor = true
    self.frames.party = anchor
    self:PlaceFrame(anchor, "party")
    self:MakeMovable(anchor, "party")

    anchor.partyFrames = {}
    for index = 1, 4 do
        local frame = self:CreatePartyUnitFrame("PrettyFramesParty" .. index, "party" .. index)
        frame:SetParent(anchor)
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(index - 1) * themeLayout.frameStep)
        anchor.partyFrames[index] = frame
    end

    self.FrameBehaviors:AttachGroup(anchor, {
        kind = "party",
        getFrames = function() return anchor.partyFrames end,
        getOptions = function() return PF.db and PF.db.partyLayout end,
        behaviors = {
            outOfRange = {
                fadeLabel = "Fade Out-of-Range Members",
            },
            actions = {
                category = "party",
            },
            healthText = {
                getMode = function() return PF.db.partyLayout.healthTextMode end,
                setMode = function(value) PF.db.partyLayout.healthTextMode = value end,
                getColorMode = function() return PF.db.partyLayout.healthColorMode end,
                setColorMode = function(value) PF.db.partyLayout.healthColorMode = value end,
                getBackgroundAlpha = function()
                    return PF.db.partyLayout.healthBackgroundAlpha
                end,
                setBackgroundAlpha = function(value)
                    PF.db.partyLayout.healthBackgroundAlpha = value
                end,
                getSparkShown = function() return PF.db.partyLayout.healthSpark ~= false end,
                setSparkShown = function(value) PF.db.partyLayout.healthSpark = value == true end,
                getIncomingHeals = function()
                    return PF.db.partyLayout.accountForIncomingHeals == true
                end,
                setIncomingHeals = function(value)
                    PF.db.partyLayout.accountForIncomingHeals = value == true
                end,
                getIncomingHealAmount = function(frame, healthMax, testMode)
                    return PF:GetGroupIncomingHeals(frame, healthMax, testMode)
                end,
                markChanged = function()
                    PF.DisplayProfileBehavior:MarkCustom(anchor)
                end,
                refresh = function() return PF:RefreshPartyFrames(false) end,
            },
            healPrediction = true,
            powerBar = {
                getMode = function() return PF.db.partyLayout.powerTextMode end,
                setMode = function(value) PF.db.partyLayout.powerTextMode = value end,
                getColorMode = function() return PF.db.partyLayout.powerColorMode end,
                setColorMode = function(value) PF.db.partyLayout.powerColorMode = value end,
                getBackgroundAlpha = function()
                    return PF.db.partyLayout.powerBackgroundAlpha
                end,
                setBackgroundAlpha = function(value)
                    PF.db.partyLayout.powerBackgroundAlpha = value
                end,
                getSparkShown = function() return PF.db.partyLayout.powerSpark ~= false end,
                setSparkShown = function(value) PF.db.partyLayout.powerSpark = value == true end,
                apply = function() return PF:RefreshPartyFrames(false) end,
            },
            scale = {
                getScale = function() return PF.db.partyLayout.scale or 1 end,
                setScale = function(value) PF.db.partyLayout.scale = value end,
                apply = function() PF:RefreshScale() end,
            },
            visibility = {
                getVisibility = function()
                    return PF.db.partyLayout.visibility or "auto"
                end,
                setVisibility = function(value) PF.db.partyLayout.visibility = value end,
                apply = function() PF:ApplyPartyGroupVisibility() end,
                isEnabled = function()
                    return PF.db.replacePartyFrames ~= false
                end,
                getStateVisibility = function()
                    local raidOptions = PF.db.raidLayout
                    local inGroup = IsInGroup and IsInGroup()
                    local inRaid = IsInRaid and IsInRaid()
                    local useSmallRaidParty = PF:ShouldUsePartyFramesForSmallRaid()
                    local showParty
                    if inRaid then
                        showParty = useSmallRaidParty
                            or PF.db.partyLayout.hideInRaid ~= true
                    else
                        showParty = not (raidOptions.useInParty and inGroup)
                    end
                    return showParty and "show" or "hide"
                end,
                getStateDriver = function()
                    local partyOptions = PF.db.partyLayout
                    local raidOptions = PF.db.raidLayout
                    local raidState = PF:ShouldUsePartyFramesForSmallRaid()
                        or partyOptions.hideInRaid ~= true
                    local partyState = raidOptions.useInParty and "hide" or "show"
                    if anchor.prettyFramesBindingMode == "raid" then
                        -- These secure buttons currently target raidN. Keep
                        -- them hidden if combat changes the group back to a
                        -- party; protected unit attributes update at regen.
                        return ("[group:raid] %s; hide"):format(
                            raidState and "show" or "hide"
                        )
                    end
                    -- partyN bindings are safe to keep through party state
                    -- changes, but must never be exposed as raid-member rows.
                    return ("[group:raid] hide; [group] %s; show"):format(partyState)
                end,
            },
            auraIndicators = {
                applyLayout = function() return PF:PerformPartyAuraLayout() end,
            },
            threat = true,
            unitIndicators = {
                showDamageRole = true,
                setStatusText = function(frame, text)
                    frame.statusText:SetText(text)
                end,
            },
            displayProfile = {
                profileSet = "party",
                refresh = function()
                    PF.AuraIndicatorBehavior:RefreshSubject(anchor)
                end,
            },
            groupUsage = {
                apply = function()
                    PF:ApplyPartyUnitBindings()
                    return PF:ApplyGroupStateDrivers()
                end,
            },
            groupUnitBinding = {
                getUnits = function()
                    anchor.prettyFramesBindingMode = IsInRaid and IsInRaid()
                        and "raid" or "party"
                    return BuildPartyUnitOrder()
                end,
                afterApply = function()
                    local result = PF:ApplyPartyGroupLayout()
                    PF:ApplyGroupStateDrivers()
                    return result
                end,
            },
            groupLayout = {
                refresh = function() return PF:PerformPartyGroupLayout() end,
                applyOption = function() return PF:ApplyPartyGroupLayout() end,
            },
            groupConnectors = {
                namePrefix = "PrettyFramesPartyConnector",
                storageKey = "partyConnectors",
                getVisibility = function()
                    return PF.db.partyLayout.visibility or "auto"
                end,
                isEnabled = function()
                    return PF.db.replacePartyFrames ~= false
                end,
                getPairs = function()
                    local pairs = {}
                    for index = 1, 3 do
                        pairs[index] = {
                            upper = anchor.partyFrames[index],
                            lower = anchor.partyFrames[index + 1],
                        }
                    end
                    return pairs
                end,
                initializeConnector = function(connector, _, index)
                    local upper = connector.upperFrame
                    connector:SetSize(unpack(themeLayout.connectorSize))
                    PF:SetThemePoint(connector, upper, themeLayout.connectorPoint)
                    connector:SetFrameLevel(upper:GetFrameLevel() + 1)

                    connector.clipper = CreateFrame("Frame", nil, connector)
                    connector.clipper:SetFrameLevel(connector:GetFrameLevel())
                    if index == 1 then
                        connector.clipper:SetPoint(
                            "TOPLEFT", connector, "TOPLEFT", 0,
                            -themeLayout.connectorEndCrop
                        )
                        connector.clipper:SetPoint(
                            "BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, 0
                        )
                    elseif index == 3 then
                        connector.clipper:SetPoint(
                            "TOPLEFT", connector, "TOPLEFT", 0, 0
                        )
                        connector.clipper:SetPoint(
                            "BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0,
                            themeLayout.connectorEndCrop
                        )
                    else
                        connector.clipper:SetAllPoints(connector)
                    end
                    if connector.clipper.SetClipsChildren then
                        connector.clipper:SetClipsChildren(true)
                    end

                    connector.texture = connector.clipper:CreateTexture(nil, "BACKGROUND")
                    connector.texture:SetAllPoints(connector)
                    connector.texture:SetTexture(
                        PF:ThemeFrameAsset("party", "partyConnector", "partyConnector"),
                        "CLAMP", "REPEAT"
                    )
                    local offset = (index - 1) * themeLayout.connectorSampleStep
                    connector.texture:SetTexCoord(0, 1, offset, 1 + offset)
                end,
            },
        },
    })

    anchor.moveHandle:SetScript("OnMouseUp", function(handle, mouseButton)
        if mouseButton == "RightButton" then
            PF:OpenPartyContextMenu(handle)
        end
    end)

    self:ApplyPartyUnitBindings()
    self.AuraIndicatorBehavior:RefreshSubject(anchor)
end

function PF:PerformPartyAuraLayout()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
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

function PF:PerformPartyGroupLayout()
    local anchor = self.frames.party
    if not anchor or not anchor.partyFrames then return end
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

    local pairs = {}
    for index = 1, #ordered - 1 do
        pairs[index] = { upper = ordered[index], lower = ordered[index + 1] }
    end
    return self.GroupConnectorBehavior:Relink(anchor, pairs, function(connector, _, index)
        local first = connector.upperFrame
        connector:ClearAllPoints()
        PF:SetThemePoint(connector, first, themeLayout.connectorPoint)
        connector:SetFrameLevel(first:GetFrameLevel() + 1)
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())

        connector.clipper:ClearAllPoints()
        local cropTop = index == 1
        local cropBottom = index == math.max(activeCount - 1, 1)
        local endCrop = themeLayout.connectorEndCrop
        connector.clipper:SetPoint(
            "TOPLEFT", connector, "TOPLEFT", 0, cropTop and -endCrop or 0
        )
        connector.clipper:SetPoint(
            "BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0,
            cropBottom and endCrop or 0
        )
    end)
end

function PF:OpenPartyContextMenu(owner)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the party menu is unavailable on this client build.")
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Party Frames")
        PF.FrameBehaviors:AddContextMenus(rootDescription, PF.frames.party, "move")
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
end

function PF:ShouldUsePartyFramesForSmallRaid()
    local options = self.db and self.db.partyLayout
    if not options or options.useInSmallRaid ~= true then return false end
    if not (IsInRaid and IsInRaid()) then return false end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
    return groupSize > 0 and groupSize <= 5
end

