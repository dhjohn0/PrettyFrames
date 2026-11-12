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

function PF:ApplyBossFramesVisibility()
    local anchor = self.frames.boss
    if not anchor then return end
    if InCombatLockdown() then
        self.pendingBossVisibility = true
        return false
    end

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
    self.pendingBossVisibility = nil
    return true
end

function PF:ApplyBossGroupLayout()
    local anchor = self.frames.boss
    if not anchor then return end
    if InCombatLockdown() then
        self.pendingBossLayout = true
        return false
    end

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

    local partyLayout = self:ThemeLayout("party")
    for index, connector in ipairs(anchor.bossConnectors or {}) do
        local upper = growUpwards and anchor.bossFrames[index + 1] or anchor.bossFrames[index]
        local lower = growUpwards and anchor.bossFrames[index] or anchor.bossFrames[index + 1]
        connector:SetParent(upper)
        connector:ClearAllPoints()
        local connectorPoint = upper.isMirrored
            and self:MirrorThemePoint(partyLayout.connectorPoint)
            or partyLayout.connectorPoint
        self:SetThemePoint(connector, upper, connectorPoint)
        connector:SetFrameLevel(upper:GetFrameLevel() + 1)
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())
        connector:SetAttribute("unit", lower.unit)
        connector.upperFrame = upper
        connector.lowerFrame = lower
    end
    if self.UpdateBossConnectors then self:UpdateBossConnectors() end
    self.pendingBossLayout = nil
    return true
end

function PF:UpdateBossConnectors()
    local anchor = self.frames.boss
    if not anchor or not anchor.bossConnectors or InCombatLockdown() then return end

    local setting = self:GetFrameSetting("boss")
    local enabled = self.db.replaceBossFrames == true and anchor.initialized == true
    for _, connector in ipairs(anchor.bossConnectors) do
        UnregisterUnitWatch(connector)
        connector:SetAlpha(1)
        local mismatchedSides = connector.upperFrame and connector.lowerFrame
            and connector.upperFrame.isMirrored ~= connector.lowerFrame.isMirrored
        if self.db.bossLayout.independentPositioning or mismatchedSides or not enabled
            or (self.db.locked and setting.visibility == "hide") then
            connector:Hide()
        elseif not self.db.locked then
            connector:SetAlpha(setting.visibility == "hide" and 0.5 or 1)
            connector:Show()
        elseif self.testMode or setting.visibility == "show" then
            connector:Show()
        else
            RegisterUnitWatch(connector)
        end
    end
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
    anchor.actionCategory = "boss"
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
                actionCategory = "boss",
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
    anchor.bossConnectors = {}
    for index = 1, BOSS_COUNT - 1 do
        local connector = CreateFrame(
            "Button", "PrettyFramesBossConnector" .. index, anchor,
            "SecureUnitButtonTemplate"
        )
        connector:SetSize(unpack(partyLayout.connectorSize))
        connector:EnableMouse(false)

        connector.clipper = CreateFrame("Frame", nil, connector)
        connector.clipper:SetFrameLevel(connector:GetFrameLevel())
        if index == 1 then
            connector.clipper:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, -partyLayout.connectorEndCrop)
            connector.clipper:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, 0)
        elseif index == BOSS_COUNT - 1 then
            connector.clipper:SetPoint("TOPLEFT", connector, "TOPLEFT", 0, 0)
            connector.clipper:SetPoint("BOTTOMRIGHT", connector, "BOTTOMRIGHT", 0, partyLayout.connectorEndCrop)
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
            self:ThemeFrameAsset("boss", "partyConnector", "partyConnector"), "CLAMP", "REPEAT"
        )
        local verticalOffset = (index - 1) * partyLayout.connectorSampleStep
        connector.texture:SetTexCoord(0, 1, verticalOffset, 1 + verticalOffset)
        anchor.bossConnectors[index] = connector
    end

    anchor.initialized = #anchor.bossFrames == BOSS_COUNT
    self:ApplyBossAuraOptions()
    self:ApplyBossGroupLayout()
    self:ApplyBossFramesVisibility()
end
