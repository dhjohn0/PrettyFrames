local _, PF = ...

local BOSS_COUNT = 5
local BOSS_PREVIEW_CASTS = {
    "Verdant Rupture", "Cinder Breath", "Arcane Decree", "Call of the Hollow", "Dreadwing Buffet",
}

local function BossAuraLimits()
    local mode = PF.db and PF.db.bossLayout and PF.db.bossLayout.auraMode or "mechanics"
    if mode == "personal" then return 0, 3 end
    if mode == "hidden" then return 0, 0 end
    return 3, 0
end

function PF:LayoutBossAuras(frame)
    if not frame then return end
    local buffLimit, debuffLimit = BossAuraLimits()
    frame.buffDisplayLimit = buffLimit
    frame.debuffDisplayLimit = debuffLimit
    local leftSide = not self.db or not self.db.bossLayout
        or self.db.bossLayout.aurasLeft ~= false
    local sideInset = self:ThemeLayout("bossFrames").auraSideInset or 0
    local unitLayout = self:ThemeLayout("unitFrames")
    local compact = unitLayout.targetOfTarget
    local healthHeight = compact.healthHeight or compact.barHeight
    local powerHeight = compact.powerHeight or compact.barHeight
    local healthCenterY = compact.points.healthLeft[4] - healthHeight * 0.5
    local powerCenterY = compact.points.powerLeft[4] - powerHeight * 0.5
    local centerYOffset = (healthCenterY + powerCenterY) * 0.5
        + unitLayout.targetOfTargetSize[2] * 0.5

    local function LayoutFallback(group, limit)
        for index, aura in ipairs(group or {}) do
            aura:ClearAllPoints()
            local offset = (index - 1) * (aura:GetWidth() + 4)
            if leftSide then
                aura:SetPoint("RIGHT", frame, "LEFT", sideInset - offset, centerYOffset)
            else
                aura:SetPoint("LEFT", frame, "RIGHT", -sideInset + offset, centerYOffset)
            end
            if index > limit then aura:SetAlpha(0) end
        end
    end

    local function LayoutNative(holder, limit)
        if not holder then return end
        local iconSize = holder.iconSize
        local width = limit > 0 and limit * iconSize + (limit - 1) * 4 or 1
        holder:SetSize(width, iconSize)
        holder:SetShown(limit > 0)
        holder:ClearAllPoints()
        if leftSide then
            holder:SetPoint("RIGHT", frame, "LEFT", sideInset, centerYOffset)
        else
            holder:SetPoint("LEFT", frame, "RIGHT", -sideInset, centerYOffset)
        end
        holder.container:ClearAllPoints()
        local anchorPoint = leftSide and "TOPRIGHT" or "TOPLEFT"
        holder.container:SetPoint(
            anchorPoint, holder, anchorPoint, 0, 0
        )
        holder.container:SetFlowLayoutAnchorPoint(anchorPoint)
        holder.container:SetFlowLayoutGrowthDirection(
            leftSide and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
            AnchorUtil.FlowDirection.Down
        )
        holder.container:SetFlowLayoutMaximumLineSize(width)
    end

    LayoutFallback(frame.auras, buffLimit)
    LayoutFallback(frame.debuffs, debuffLimit)
    LayoutNative(frame.nativeBuffs, buffLimit)
    LayoutNative(frame.nativeDebuffs, debuffLimit)
end

function PF:ApplyBossAuraOptions()
    local anchor = self.frames and self.frames.boss
    if not anchor or not anchor.bossFrames then return end
    local buffLimit, debuffLimit = BossAuraLimits()
    for _, frame in ipairs(anchor.bossFrames) do
        for _, entry in ipairs({
            { frame.nativeBuffs, buffLimit },
            { frame.nativeDebuffs, debuffLimit },
        }) do
            local holder, limit = entry[1], entry[2]
            local container = holder and holder.container
            if container and holder.groupId and container.SetAuraGroupMaxFrameCount then
                container:SetAuraGroupMaxFrameCount(holder.groupId, limit)
            end
        end
        self:LayoutBossAuras(frame)
        self:UpdateAuras(frame)
        self:RefreshNativeAuras(frame)
    end
end

function PF:SaveBossFramePosition(frame)
    if not frame or not frame.settingKey then return end
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not y or not parentX or not parentY then return end
    x, y = self:ConvertRegionCoordinatesToUIParent(frame, x, y)
    if not x or not y then return end
    self.db.positions[frame.settingKey] = {
        "CENTER", "UIParent", "CENTER", x - parentX, y - parentY,
    }
end

local function SetBossUnitVisibility(frame, showMode, alpha)
    UnregisterUnitWatch(frame)
    frame:SetAlpha(alpha or 1)

    if showMode == "hide" then
        frame:Hide()
    elseif showMode == "show" then
        frame:Show()
    else
        RegisterUnitWatch(frame)
    end
end

local function RegisterBossFramePositioning(frame)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(widget)
        if PF.db.bossLayout.independentPositioning
            and not PF.db.locked and not InCombatLockdown() then
            widget:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget:StopMovingOrSizing()
        if PF.db.bossLayout.independentPositioning then
            PF:SaveBossFramePosition(widget)
        end
    end)
end

function PF:PerformBossFramesVisibility()
    local anchor = self.frames.boss
    if not anchor then return end
    local enabled = self.db.replaceBossFrames == true and anchor.initialized == true
    local setting = self:GetFrameSetting("boss")
    local visibility = setting.visibility or "auto"
    local showMode = "auto"

    local alpha = 1
    if not enabled then
        showMode = "hide"
    elseif not self.db.locked then
        showMode = "show"
        alpha = visibility == "hide" and 0.5 or 1
    elseif visibility == "hide" then
        showMode = "hide"
    elseif self.testMode or visibility == "show" then
        showMode = "show"
    end

    anchor:SetShown(enabled)
    for _, frame in ipairs(anchor.bossFrames) do
        SetBossUnitVisibility(frame, showMode, alpha)
    end
    if self.UpdateBossConnectors then self:UpdateBossConnectors() end
    return true
end

function PF:PerformBossGroupLayout()
    local anchor = self.frames.boss
    if not anchor then return end
    local layout = self:ThemeLayout("bossFrames")
    local growUpwards = self.db.bossLayout.growUpwards == true
    local height = self:ThemeLayout("unitFrames").targetOfTargetSize[2]
    local step = height + (layout.frameGap or 4)
    local cursor = 0
    for _, frame in ipairs(anchor.bossFrames) do
        local setting = self:GetFrameSetting(frame.settingKey)
        if self.db.bossLayout.independentPositioning
            and self.db.positions[frame.settingKey] then
            self:PlaceFrame(frame, frame.settingKey)
        else
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, growUpwards and cursor or -cursor)
            cursor = cursor + step * (setting.scale or 1)
        end
    end

    -- The top Boss frame owns a local OPTIONS plate at its top-left. Keep the
    -- group MOVE plate one row above it so both controls remain clickable.
    local topFrame = growUpwards and anchor.bossFrames[#anchor.bossFrames]
        or anchor.bossFrames[1]
    if anchor.moveHandle and topFrame then
        anchor.moveHandle:ClearAllPoints()
        if topFrame.moveHandle then
            anchor.moveHandle:SetPoint("BOTTOMLEFT", topFrame.moveHandle, "TOPLEFT", 0, 5)
        else
            anchor.moveHandle:SetPoint("BOTTOMLEFT", topFrame, "TOPLEFT", 0, 5)
        end
    end

    local partyLayout = self:ThemeLayout("party")
    local pairs = {}
    for index = 1, BOSS_COUNT - 1 do
        pairs[index] = {
            upper = growUpwards and anchor.bossFrames[index + 1]
                or anchor.bossFrames[index],
            lower = growUpwards and anchor.bossFrames[index]
                or anchor.bossFrames[index + 1],
        }
    end
    self.GroupConnectorBehavior:Relink(anchor, pairs, function(connector)
        local upper = connector.upperFrame
        connector:ClearAllPoints()
        local connectorPoint = upper.isMirrored
            and self:MirrorThemePoint(partyLayout.connectorPoint)
            or partyLayout.connectorPoint
        self:SetThemePoint(connector, upper, connectorPoint)
        connector:SetFrameLevel(upper:GetFrameLevel() + 1)
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())
    end)
    return true
end

function PF:RefreshBossFrames(updateModel)
    local anchor = self.frames.boss
    if not anchor then return end
    self:ApplyBossFramesVisibility()
    for _, frame in ipairs(anchor.bossFrames) do
        self:UpdateUnitFrame(frame, updateModel == true)
    end
end

function PF:CreateBossFrames()
    local bossLayout = self:ThemeLayout("bossFrames")
    local unitFrameLayout = self:ThemeFrameLayout("boss", "unitFrames")
    local width, height = unpack(unitFrameLayout.targetOfTargetSize)
    local anchor = CreateFrame("Frame", "PrettyFramesBossFrames", UIParent)
    anchor:SetSize(width, height)
    anchor:SetClampedToScreen(true)
    anchor.isAnchor = true
    anchor.isBossGroup = true
    anchor.bossFrames = {}
    anchor.settingKey = "boss"
    self.frames.boss = anchor
    self:PlaceFrame(anchor, "boss")
    self:MakeMovable(anchor, "boss")
    anchor.moveHandle.contextTarget = anchor
    anchor.moveHandle:SetScript("OnMouseUp", function(handle, mouseButton)
        if mouseButton == "RightButton" then
            PF:OpenFrameContextMenu(handle)
        end
    end)

    for index = 1, BOSS_COUNT do
        local unit = "boss" .. index
        local frame = self:CreateOrnateUnitFrame(
            "PrettyFramesBoss" .. index, unit, width, height, nil, true, true,
            {
                skipActionBehavior = true,
                settingKey = "boss",
                skipContextMenu = true,
                isBossFrame = true,
                aurasEnabled = true,
                debuffsEnabled = true,
                auraCount = 3,
                manageBossAuras = true,
                auraIconSize = bossLayout.auraIconSize,
                createCastBar = true,
                dynamicPowerLayout = true,
                castBarSize = bossLayout.castBarSize,
                castBarOffset = bossLayout.castBarOffset,
                castBarOrnamentExtraWidth = bossLayout.castBarOrnamentExtraWidth,
            }
        )
        frame:SetParent(anchor)
        frame.isBossFrame = true
        frame.castBarSettingKey = "boss"
        if frame.castBar and frame.castBar.preview then
            frame.castBar.preview.Text:SetText(BOSS_PREVIEW_CASTS[index])
            frame.castBar.preview.Icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
        end
        table.insert(anchor.bossFrames, frame)
        self:RegisterFrameContextMenu(frame, unit)
        RegisterBossFramePositioning(frame)
    end

    local partyLayout = self:ThemeLayout("party")
    anchor.initialized = #anchor.bossFrames == BOSS_COUNT
    self.FrameBehaviors:AttachGroup(anchor, {
        kind = "boss",
        getFrames = function() return anchor.bossFrames end,
        getOptions = function() return PF.db and PF.db.bossLayout end,
        behaviors = {
            actions = {
                category = "boss",
            },
            outOfRange = {
                isActive = function()
                    return PF.db and PF.db.replaceBossFrames == true
                end,
                fadeLabel = "Fade Out-of-Range Bosses",
            },
            scale = {
                getFrames = function() return { anchor } end,
                getScale = function()
                    return PF:GetFrameSetting("boss").scale or 1
                end,
                setScale = function(value)
                    PF:GetFrameSetting("boss").scale = value
                end,
                apply = function() return PF:ApplyFrameScale(anchor) end,
            },
            visibility = {
                getFrames = function() return { anchor } end,
                getVisibility = function()
                    return PF:GetFrameSetting("boss").visibility or "auto"
                end,
                setVisibility = function(value)
                    PF:GetFrameSetting("boss").visibility = value
                end,
                apply = function() return PF:PerformBossFramesVisibility() end,
            },
            healthText = {
                getMode = function() return PF.db.bossLayout.healthTextMode end,
                setMode = function(value) PF.db.bossLayout.healthTextMode = value end,
                getColorMode = function() return PF.db.bossLayout.healthColorMode end,
                setColorMode = function(value) PF.db.bossLayout.healthColorMode = value end,
                getBackgroundAlpha = function()
                    return PF.db.bossLayout.healthBackgroundAlpha
                end,
                setBackgroundAlpha = function(value)
                    PF.db.bossLayout.healthBackgroundAlpha = value
                end,
                getSparkShown = function() return PF.db.bossLayout.healthSpark ~= false end,
                setSparkShown = function(value) PF.db.bossLayout.healthSpark = value == true end,
                refresh = function() return PF:RefreshBossFrames(false) end,
            },
            powerBar = {
                label = "Hide Power Bar",
                getMode = function() return PF.db.bossLayout.powerTextMode end,
                setMode = function(value) PF.db.bossLayout.powerTextMode = value end,
                getColorMode = function() return PF.db.bossLayout.powerColorMode end,
                setColorMode = function(value) PF.db.bossLayout.powerColorMode = value end,
                getBackgroundAlpha = function()
                    return PF.db.bossLayout.powerBackgroundAlpha
                end,
                setBackgroundAlpha = function(value)
                    PF.db.bossLayout.powerBackgroundAlpha = value
                end,
                getSparkShown = function() return PF.db.bossLayout.powerSpark ~= false end,
                setSparkShown = function(value) PF.db.bossLayout.powerSpark = value == true end,
                getOneBar = function() return PF.db.bossLayout.forceOneBar == true end,
                setOneBar = function(value) PF.db.bossLayout.forceOneBar = value == true end,
                apply = function() return PF:RefreshBossFrames(false) end,
            },
            auraIndicators = true,
            groupLayout = {
                beforeOptionChanged = function(key, previous, value)
                    if key ~= "independentPositioning" or previous == true
                        or value ~= true then return end
                    local hasSavedLayout = true
                    for _, bossFrame in ipairs(anchor.bossFrames) do
                        if not PF.db.positions[bossFrame.settingKey] then
                            hasSavedLayout = false
                            break
                        end
                    end
                    if not hasSavedLayout then
                        for _, bossFrame in ipairs(anchor.bossFrames) do
                            PF:SaveBossFramePosition(bossFrame)
                        end
                    end
                end,
                applyOption = function() return PF:ApplyBossGroupLayout() end,
                refresh = function() return PF:PerformBossGroupLayout() end,
            },
            castBar = {
                getBars = function()
                    local castBars = {}
                    for _, bossFrame in ipairs(anchor.bossFrames) do
                        if bossFrame.castBar then
                            table.insert(castBars, bossFrame.castBar)
                        end
                    end
                    return castBars
                end,
                getHidden = function()
                    return PF:GetFrameSetting("boss").hideCastBar == true
                end,
                setHidden = function(value)
                    PF:GetFrameSetting("boss").hideCastBar = value == true
                end,
            },
            groupConnectors = {
                namePrefix = "PrettyFramesBossConnector",
                storageKey = "bossConnectors",
                getVisibility = function()
                    return PF:GetFrameSetting("boss").visibility or "auto"
                end,
                isEnabled = function()
                    return PF.db.replaceBossFrames == true
                        and anchor.initialized == true
                end,
                isConnectorEnabled = function(connector)
                    local mismatchedSides = connector.upperFrame and connector.lowerFrame
                        and connector.upperFrame.isMirrored
                            ~= connector.lowerFrame.isMirrored
                    return PF.db.bossLayout.independentPositioning ~= true
                        and not mismatchedSides
                end,
                getPairs = function()
                    local pairs = {}
                    for index = 1, BOSS_COUNT - 1 do
                        pairs[index] = {
                            upper = anchor.bossFrames[index],
                            lower = anchor.bossFrames[index + 1],
                        }
                    end
                    return pairs
                end,
                initializeConnector = function(connector, _, index)
                    connector:SetSize(unpack(partyLayout.connectorSize))
                    connector.clipper = CreateFrame("Frame", nil, connector)
                    connector.clipper:SetFrameLevel(connector:GetFrameLevel())
                    if index == 1 then
                        connector.clipper:SetPoint(
                            "TOPLEFT", connector, "TOPLEFT", 0,
                            -partyLayout.connectorEndCrop
                        )
                        connector.clipper:SetPoint(
                            "BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, 0
                        )
                    elseif index == BOSS_COUNT - 1 then
                        connector.clipper:SetPoint(
                            "TOPLEFT", connector, "TOPLEFT", 0, 0
                        )
                        connector.clipper:SetPoint(
                            "BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0,
                            partyLayout.connectorEndCrop
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
                        PF:ThemeFrameAsset("boss", "partyConnector", "partyConnector"),
                        "CLAMP", "REPEAT"
                    )
                    local offset = (index - 1) * partyLayout.connectorSampleStep
                    connector.texture:SetTexCoord(0, 1, offset, 1 + offset)
                end,
            },
        },
    })
    self.AuraIndicatorBehavior:RefreshSubject(anchor)
    self:ApplyBossGroupLayout()
    self:ApplyBossFramesVisibility()
end
