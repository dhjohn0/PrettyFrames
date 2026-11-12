local addonName, PF = ...

function PF:CreateBackdrop(frame, borderSize)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderSize or 2,
    })
    frame:SetBackdropColor(unpack(self.colors.leather))
    frame:SetBackdropBorderColor(unpack(self.colors.bronze))
end

function PF:PlaceFrame(frame, key)
    frame:ClearAllPoints()
    local position = self.db.positions[key]
    local relativeTo = _G[position[2]] or UIParent
    frame:SetPoint(position[1], relativeTo, position[3], position[4], position[5])
end

function PF:SavePosition(frame, key)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName()
    self.db.positions[key] = { point, relativeName or "UIParent", relativePoint, x, y }
end

function PF:RaiseEditHandle(handle)
    if not handle then return end
    -- Unit frames use MEDIUM, so HIGH keeps edit controls above their artwork.
    -- Keep the level modest because MenuUtil builds a context menu relative to
    -- its owner and cannot reliably rise above an owner at an extreme level.
    handle:SetFrameStrata("HIGH")
    handle:SetFrameLevel(100)
end

function PF:MirrorPlayerTargetPosition(sourceKey, savePosition)
    if not self.db.mirrorPlayerTarget or (sourceKey ~= "player" and sourceKey ~= "target") then
        return
    end
    local otherKey = sourceKey == "player" and "target" or "player"
    local source, other = self.frames[sourceKey], self.frames[otherKey]
    if not source or not other then return end

    local sourceX = source:GetCenter()
    local sourceTop = source:GetTop()
    local parentX = UIParent:GetCenter()
    local parentTop = UIParent:GetTop()
    if not sourceX or not sourceTop or not parentX or not parentTop then return end

    other:ClearAllPoints()
    -- Mirror horizontal centers across the screen, but align the top edges.
    -- Player can include a Pet composition below its Player portion and is
    -- therefore taller than Target; center-Y alignment offsets their shared
    -- Player/Target visual through-line by half that height difference.
    other:SetPoint("TOP", UIParent, "TOP", -(sourceX - parentX), sourceTop - parentTop)
    if savePosition ~= false then
        self:SavePosition(other, otherKey)
    end
end

function PF:MakeMovable(frame, key)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(widget)
        if not self.db.locked and not InCombatLockdown() then
            widget:StartMoving()
            widget.mirrorPlayerTargetDragging = true
        end
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget.mirrorPlayerTargetDragging = nil
        widget:StopMovingOrSizing()
        self:SavePosition(widget, key)
        self:MirrorPlayerTargetPosition(key)
    end)
    if key == "player" or key == "target" then
        frame:HookScript("OnUpdate", function(widget)
            if widget.mirrorPlayerTargetDragging then
                self:MirrorPlayerTargetPosition(key, false)
            end
        end)
    end
    frame:HookScript("OnEnter", function(widget)
        if not self.db.locked then
            widget.moveLabel:Show()
        end
    end)
    frame:HookScript("OnLeave", function(widget)
        widget.moveLabel:Hide()
    end)

    frame.moveLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.moveLabel:SetPoint("TOP", frame, "BOTTOM", 0, -3)
    frame.moveLabel:SetText(key:upper() .. " — drag to move")
    frame.moveLabel:SetTextColor(unpack(self.colors.bronzeBright))
    frame.moveLabel:Hide()

    local handle = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    handle:SetSize(128, 22)
    handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 5)
    self:RaiseEditHandle(handle)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    self:CreateBackdrop(handle, 1)
    handle:SetBackdropColor(0.08, 0.045, 0.02, 0.96)
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            frame:StartMoving()
            frame.mirrorPlayerTargetDragging = true
        end
    end)
    handle:SetScript("OnDragStop", function()
        frame.mirrorPlayerTargetDragging = nil
        frame:StopMovingOrSizing()
        self:SavePosition(frame, key)
        self:MirrorPlayerTargetPosition(key)
    end)
    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    handle.text:SetPoint("CENTER")
    handle.text:SetText("MOVE " .. key:upper())
    handle.text:SetTextColor(unpack(self.colors.bronzeBright))
    handle:Hide()
    frame.moveHandle = handle
end

function PF:RefreshScale()
    if InCombatLockdown() then
        self.pendingScaleRefresh = true
        return false
    end

    self.pendingScaleRefresh = nil
    for _, frame in pairs(self.frames) do
        if frame.isAnchor then
            local frameScale = 1
            if frame.settingKey then
                frameScale = self:GetFrameSetting(frame.settingKey).scale or 1
            elseif frame == self.frames.party then
                frameScale = self.db.partyLayout.scale or 1
            elseif frame == self.frames.raid then
                frameScale = (self.db.raidLayout.scale or 1) * (self.RAID_BASE_SCALE or 1)
            end
            frame:SetScale(self.db.scale * frameScale)
        end
    end
    return true
end

function PF:GetFrameSetting(key)
    local setting = self.db.frameSettings[key]
    if not setting then
        setting = {
            visibility = "auto",
            flipped = false,
            forceOneBar = false,
            showThreatGlow = true,
            showPetThreat = false,
            threatTextMode = "none",
            buffsAbove = false,
            aurasLeft = false,
            hideCastBar = false,
            hidePetHappiness = false,
            petBarMode = "healthPower",
            classResourceVisibility = "automatic",
            classResourceIndependent = false,
            classResourcePosition = nil,
            castBarIndependent = false,
            castBarPosition = nil,
            independentPositioning = false,
            scale = 1,
        }
        self.db.frameSettings[key] = setting
    end
    setting.scale = self:IsValidScale(setting.scale) and setting.scale or 1
    setting.showThreatGlow = setting.showThreatGlow ~= false
    setting.showPetThreat = setting.showPetThreat == true
    setting.threatTextMode = setting.threatTextMode == "aggro"
        and "aggro" or (setting.threatTextMode == "raw" and "raw" or "none")
    setting.hideCastBar = setting.hideCastBar == true
    setting.hidePetHappiness = setting.hidePetHappiness == true
    setting.petBarMode = setting.petBarMode == "healthOnly" and "healthOnly" or "healthPower"
    setting.classResourceVisibility = setting.classResourceVisibility == "hidden"
        and "hidden" or "automatic"
    setting.classResourceIndependent = setting.classResourceIndependent == true
    setting.castBarIndependent = setting.castBarIndependent == true
    setting.independentPositioning = setting.independentPositioning == true
    if type(setting.castBarPosition) ~= "table"
        or type(setting.castBarPosition[1]) ~= "number"
        or type(setting.castBarPosition[2]) ~= "number" then
        setting.castBarPosition = nil
    end
    if type(setting.classResourcePosition) ~= "table"
        or type(setting.classResourcePosition[1]) ~= "number"
        or type(setting.classResourcePosition[2]) ~= "number" then
        setting.classResourcePosition = nil
    end
    return setting
end

function PF:SaveCastBarPosition(castBar)
    local owner = castBar and castBar.ownerFrame
    if not owner or not owner.settingKey then return end
    local x, y = castBar:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not y or not parentX or not parentY then return end
    local position = { x - parentX, y - parentY }
    self:GetFrameSetting(owner.settingKey).castBarPosition = position
    local placements = self.db.themePlacements
    local placement = placements and placements[self.db.theme]
    if placement then
        placement.castBarPositions = placement.castBarPositions or {}
        placement.castBarPositions[owner.settingKey] = position
    end
end

function PF:ApplyCastBarPosition(owner)
    local castBar = owner and owner.castBar
    if not castBar or not owner.settingKey then return end
    local setting = self:GetFrameSetting(owner.settingKey)
    if not setting.castBarIndependent or not setting.castBarPosition then return end
    castBar:ClearAllPoints()
    castBar:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        setting.castBarPosition[1],
        setting.castBarPosition[2]
    )
end

function PF:SaveTargetTargetPosition(frame)
    if not frame then return end
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not y or not parentX or not parentY then return end
    self.db.positions.targettarget = {
        "CENTER", "UIParent", "CENTER", x - parentX, y - parentY,
    }
end

function PF:ApplyTargetTargetPosition(frame)
    if not frame then return end
    local setting = self:GetFrameSetting("targettarget")
    frame:ClearAllPoints()
    if setting.independentPositioning and self.db.positions.targettarget then
        self:PlaceFrame(frame, "targettarget")
    else
        local target = self.frames.target
        if target then
            self:SetThemePoint(
                frame,
                target,
                self:ThemeLayout("unitFrames").targetOfTargetAttach
            )
        end
    end
end

function PF:RegisterTargetTargetPositioning(frame)
    if not frame then return end
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(widget)
        local setting = PF:GetFrameSetting("targettarget")
        if setting.independentPositioning and not PF.db.locked and not InCombatLockdown() then
            widget:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(widget)
        widget:StopMovingOrSizing()
        if PF:GetFrameSetting("targettarget").independentPositioning then
            PF:SaveTargetTargetPosition(widget)
            PF:ApplyTargetTargetPosition(widget)
        end
    end)
    self:ApplyTargetTargetPosition(frame)
end

function PF:RegisterCastBarEditing(owner)
    local castBar = owner and owner.castBar
    if not castBar or castBar.editingRegistered then return end
    castBar.editingRegistered = true
    castBar:SetMovable(true)
    castBar:SetClampedToScreen(true)

    local function AttachRegion(region)
        region:EnableMouse(not PF.db.locked)
        region:RegisterForDrag("LeftButton")
        region:SetScript("OnDragStart", function()
            local setting = PF:GetFrameSetting(owner.settingKey)
            if not PF.db.locked and setting.castBarIndependent and not InCombatLockdown() then
                castBar:StartMoving()
            end
        end)
        region:SetScript("OnDragStop", function()
            castBar:StopMovingOrSizing()
            PF:SaveCastBarPosition(castBar)
        end)
        region:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton == "RightButton" and not PF.db.locked then
                PF:OpenCastBarContextMenu(castBar)
            end
        end)
    end

    AttachRegion(castBar)
    if castBar.preview then AttachRegion(castBar.preview) end
end

function PF:OpenCastBarContextMenu(castBar)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the cast-bar menu is unavailable on this client build.")
        return
    end
    local owner = castBar and castBar.ownerFrame
    if not owner or not owner.settingKey then return end
    local setting = self:GetFrameSetting(owner.settingKey)
    local labels = { player = "Player", target = "Target", focus = "Focus" }
    local label = labels[owner.settingKey] or owner.settingKey

    MenuUtil.CreateContextMenu(castBar.preview and castBar.preview:IsShown() and castBar.preview or castBar, function(_, rootDescription)
        rootDescription:CreateTitle(label .. " Cast Bar")
        rootDescription:CreateTitle("Positioning")
        local function IsPositioningSelected(value)
            return (setting.castBarIndependent == true) == (value == "independent")
        end
        local function SetPositioning(value)
            local independent = value == "independent"
            if independent == (setting.castBarIndependent == true) then return end
            if independent then
                if not setting.castBarPosition then
                    PF:SaveCastBarPosition(castBar)
                end
                setting.castBarIndependent = true
                PF:ApplyCastBarPosition(owner)
            else
                PF:SaveCastBarPosition(castBar)
                setting.castBarIndependent = false
                if owner.SetFlipped then
                    owner:SetFlipped(setting.flipped == true)
                end
            end
        end
        rootDescription:CreateRadio("Attached to Frame", IsPositioningSelected, SetPositioning, "attached")
        rootDescription:CreateRadio("Independent", IsPositioningSelected, SetPositioning, "independent")
    end)
end


local function AddMenuSlider(menuDescription, value, minValue, maxValue, onValueChanged, steps, formatter)
    local function Initializer(frame)
        local slider = frame:AttachTemplate("MinimalSliderWithSteppersTemplate")
        local formatters = {
            [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                MinimalSliderWithSteppersMixin.Label.Right,
                function(sliderValue)
                    sliderValue = math.floor(sliderValue + 0.5)
                    return formatter and formatter(sliderValue) or tostring(sliderValue)
                end
            ),
        }
        slider:Init(value, minValue, maxValue, steps or (maxValue - minValue), formatters)
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, sliderValue)
            onValueChanged(math.floor(sliderValue + 0.5))
        end, frame)
        slider:SetPoint("TOPLEFT", 8, -1)
        slider:SetSize(170, 25)

        -- The wider wrapper gives the value label room and owns cleanup for
        -- the template attached to this transient menu element.
        local cleanupFrame = frame:AttachFrame("Frame")
        cleanupFrame:SetPoint("TOPLEFT", slider, "TOPLEFT")
        cleanupFrame:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT")
        cleanupFrame:SetWidth(202)
        cleanupFrame:SetScript("OnHide", function()
            slider:UnregisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, frame)
            slider:Release()
        end)
    end

    local elementDescription = menuDescription:CreateFrame()
    elementDescription:AddInitializer(Initializer)
end

function PF:AddScaleMenuOption(menuDescription, scale, onValueChanged)
    menuDescription:CreateTitle("Scale")
    AddMenuSlider(menuDescription, math.floor(scale * 100 + 0.5), 60, 160, function(value)
        onValueChanged(value / 100)
    end, 20, function(value)
        return value .. "%"
    end)
end

function PF:AddVisibilityMenuOption(menuDescription, getVisibility, setVisibility)
    local visibilityMenu = menuDescription:CreateButton("Visibility")
    local function IsSelected(value)
        return getVisibility() == value
    end
    visibilityMenu:CreateRadio("Automatic", IsSelected, setVisibility, "auto")
    visibilityMenu:CreateRadio("Always Show", IsSelected, setVisibility, "show")
    visibilityMenu:CreateRadio("Always Hide", IsSelected, setVisibility, "hide")
    return visibilityMenu
end

function PF:ApplyFrameScale(frame)
    if not frame or not frame.settingKey then return end
    if InCombatLockdown() then
        self.pendingFrameScales[frame] = true
        return false
    end

    local scale = self:GetFrameSetting(frame.settingKey).scale or 1
    frame:SetScale(frame.isAnchor and self.db.scale * scale or scale)
    self.pendingFrameScales[frame] = nil
    return true
end

function PF:ApplyFrameVisibility(frame)
    if InCombatLockdown() then
        self.pendingVisibilityFrames[frame] = true
        return false
    end

    if (frame.isBossGroup or frame.isBossFrame) and self.ApplyBossFramesVisibility then
        return self:ApplyBossFramesVisibility()
    end

    local setting = frame.settingKey and self:GetFrameSetting(frame.settingKey)
    local featureEnabled = true
    if frame.isRaidFrame then
        featureEnabled = self.db.replaceRaidFrames ~= false
    elseif frame.settingKey and frame.settingKey:match("^party%d+$") then
        featureEnabled = self.db.replacePartyFrames ~= false
    elseif frame.settingKey then
        featureEnabled = self.db.replaceUnitFrames ~= false
    end
    if not featureEnabled then
        UnregisterUnitWatch(frame)
        frame:SetAlpha(1)
        frame:Hide()
        if frame.OnVisibilityApplied then
            frame:OnVisibilityApplied(false, "feature-disabled")
        end
        return true
    end

    local visibility = setting and setting.visibility or "auto"
    if frame.settingKey and frame.settingKey:match("^party%d+$") and self.db.partyLayout then
        visibility = self.db.partyLayout.visibility or "auto"
    elseif frame.isRaidFrame and self.db.raidLayout then
        visibility = self.db.raidLayout.visibility or "auto"
    end

    local displayElement
    if not self.db.locked then
        UnregisterUnitWatch(frame)
        frame:SetAlpha(visibility == "hide" and 0.5 or 1)
        frame:Show()
        displayElement = true
    elseif visibility == "hide" then
        -- Always Hide takes precedence over test/preview mode. Hidden frames
        -- remain available at half alpha only while positions are unlocked.
        UnregisterUnitWatch(frame)
        frame:SetAlpha(1)
        frame:Hide()
        displayElement = false
    elseif self.testMode then
        UnregisterUnitWatch(frame)
        frame:SetAlpha(1)
        frame:Show()
        displayElement = true
    elseif visibility == "show" or frame.alwaysPreview then
        UnregisterUnitWatch(frame)
        frame:SetAlpha(1)
        frame:Show()
        displayElement = true
    else
        frame:SetAlpha(1)
        RegisterUnitWatch(frame)
        if frame.unit then
            displayElement = UnitExists(frame.unit)
        else
            displayElement = true
        end
    end

    if frame.OnVisibilityApplied then
        frame:OnVisibilityApplied(displayElement, visibility)
    end
    return true
end

function PF:ApplyFrameFlip(frame)
    if not frame or not frame.SetFlipped or not frame.settingKey then return end
    if InCombatLockdown() then
        self.pendingFrameFlips[frame] = true
        return false
    end
    frame:SetFlipped(self:GetFrameSetting(frame.settingKey).flipped)
    return true
end

function PF:SetFrameFlipped(frame, flipped)
    if not frame or not frame.settingKey then return end
    local key = frame.settingKey
    self:GetFrameSetting(key).flipped = flipped == true
    self:ApplyFrameFlip(frame)
    if key == "target" and self.UpdateClassResourceDisplay then
        self:UpdateClassResourceDisplay(true)
    end
end

function PF:SetMirrorPlayerTarget(enabled)
    if InCombatLockdown() then
        self:Print("Player/Target position mirroring cannot change during combat.")
        return false
    end
    self.db.mirrorPlayerTarget = enabled == true
    if self.db.mirrorPlayerTarget then
        self:MirrorPlayerTargetPosition("player")
    end
    return true
end

function PF:RegisterFrameContextMenu(clickFrame, key, targetFrame)
    local target = targetFrame or clickFrame
    target.settingKey = key
    clickFrame.contextTarget = target
    table.insert(self.contextFrames, clickFrame)
    if not target.contextRegistered then
        target.contextRegistered = true
        table.insert(self.configurableFrames, target)
    end

    clickFrame:HookScript("OnClick", function(widget, mouseButton)
        if mouseButton == "RightButton" and PF.db and not PF.db.locked then
            PF:OpenFrameContextMenu(widget)
        end
    end)

    if self.ApplyActionsToFrame then self:ApplyActionsToFrame(clickFrame) end
    self:ApplyFrameScale(target)
    self:ApplyFrameFlip(target)
    if target.SetBuffsAbove then
        target:SetBuffsAbove(self:GetFrameSetting(key).buffsAbove)
    end
    if target.SetAuraLimits then
        local setting = self:GetFrameSetting(key)
        setting.maxBuffs = setting.maxBuffs or target.defaultMaxBuffs or 0
        setting.maxDebuffs = setting.maxDebuffs or target.defaultMaxDebuffs or 0
        target:SetAuraLimits(setting.maxBuffs, setting.maxDebuffs)
    end
    if target.SetAurasLeft then
        target:SetAurasLeft(self:GetFrameSetting(key).aurasLeft)
    end
    if target.SetPetHappinessShown then
        target:SetPetHappinessShown(not self:GetFrameSetting(key).hidePetHappiness)
    end
    if target.SetPetPowerShown then
        target:SetPetPowerShown(self:GetFrameSetting(key).petBarMode ~= "healthOnly")
    end
    if target.castBar and not target.isBossFrame and self.RefreshCastBarPreviews then
        self:RegisterCastBarEditing(target)
        self:RefreshCastBarPreviews()
    end
    self:ApplyFrameVisibility(target)
end

function PF:OpenFrameContextMenu(clickFrame)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the frame menu is unavailable on this client build.")
        return
    end

    local frame = clickFrame.contextTarget or clickFrame
    local setting = self:GetFrameSetting(frame.settingKey)
    local labels = {
        player = "Player",
        pet = "Pet",
        target = "Target",
        targettarget = "Target of Target",
        focus = "Focus",
        boss = "Boss Frames",
    }
    local label = labels[frame.settingKey]
        or frame.settingKey:gsub("(%a)(%d+)$", "%1 %2"):gsub("^%l", string.upper)
    MenuUtil.CreateContextMenu(clickFrame, function(_, rootDescription)
        rootDescription:CreateTitle(frame.isBossGroup and label or (label .. " Frame"))
        local isPartyFrame = frame.settingKey and frame.settingKey:match("^party%d+$")
        local isBossFrame = frame.isBossFrame == true

        if not isPartyFrame and not isBossFrame and frame.actionCategory then
            rootDescription:CreateButton("Actions...", function()
                PF:OpenActionsWindow(frame.actionCategory)
            end)
            rootDescription:CreateDivider()
        end

        PF:AddScaleMenuOption(rootDescription, setting.scale, function(value)
            setting.scale = value
            PF:ApplyFrameScale(frame)
            if isPartyFrame and PF.ApplyPartyGroupLayout then
                PF:ApplyPartyGroupLayout()
            elseif isBossFrame and PF.ApplyBossGroupLayout then
                PF:ApplyBossGroupLayout()
            end
        end)

        if not isPartyFrame and not isBossFrame then
            PF:AddVisibilityMenuOption(rootDescription, function()
                return setting.visibility or "auto"
            end, function(value)
                setting.visibility = value
                PF:ApplyFrameVisibility(frame)
                if frame.isBossGroup then
                    for _, bossFrame in ipairs(frame.bossFrames) do
                        PF:UpdateUnitFrame(bossFrame, true)
                    end
                else
                    PF:UpdateUnitFrame(frame, true)
                end
            end)
        end

        local layoutMenu
        local function GetLayoutMenu()
            if not layoutMenu then
                layoutMenu = rootDescription:CreateButton("Layout")
            end
            return layoutMenu
        end

        if frame.isBossGroup then
            local menu = GetLayoutMenu()
            local function IsMoveMode(value)
                return (PF.db.bossLayout.independentPositioning == true)
                    == (value == "independent")
            end
            local function SetMoveMode(value)
                local independent = value == "independent"
                if independent and not PF.db.bossLayout.independentPositioning then
                    local hasSavedLayout = true
                    for _, bossFrame in ipairs(frame.bossFrames) do
                        if not PF.db.positions[bossFrame.settingKey] then
                            hasSavedLayout = false
                            break
                        end
                    end
                    if not hasSavedLayout then
                        for _, bossFrame in ipairs(frame.bossFrames) do
                            PF:SaveBossFramePosition(bossFrame)
                        end
                    end
                end
                PF.db.bossLayout.independentPositioning = independent
                PF:ApplyBossGroupLayout()
            end
            menu:CreateTitle("Positioning")
            menu:CreateRadio("As a Group", IsMoveMode, SetMoveMode, "group")
            menu:CreateRadio("Independent", IsMoveMode, SetMoveMode, "independent")
            if not PF.db.bossLayout.independentPositioning then
                menu:CreateDivider()
                menu:CreateTitle("Growth Direction")
                menu:CreateRadio("Down", function()
                    return PF.db.bossLayout.growUpwards ~= true
                end, function()
                    PF.db.bossLayout.growUpwards = false
                    PF:ApplyBossGroupLayout()
                end)
                menu:CreateRadio("Up", function()
                    return PF.db.bossLayout.growUpwards == true
                end, function()
                    PF.db.bossLayout.growUpwards = true
                    PF:ApplyBossGroupLayout()
                end)
            end
        end

        if frame.isCompactTargetTarget and not isBossFrame then
            GetLayoutMenu():CreateCheckbox("Independent Positioning", function()
                return setting.independentPositioning == true
            end, function()
                if setting.independentPositioning then
                    PF:SaveTargetTargetPosition(frame)
                    setting.independentPositioning = false
                else
                    if not PF.db.positions.targettarget then
                        PF:SaveTargetTargetPosition(frame)
                    end
                    setting.independentPositioning = true
                end
                PF:ApplyTargetTargetPosition(frame)
            end)
        end

        if frame.SetFlipped then
            GetLayoutMenu():CreateCheckbox("Flip Horizontally", function()
                return setting.flipped
            end, function()
                PF:SetFrameFlipped(frame, not setting.flipped)
                if isBossFrame and PF.ApplyBossGroupLayout then
                    PF:ApplyBossGroupLayout()
                end
            end)
        end

        local auraMenu
        local function GetAuraMenu()
            if not auraMenu then
                auraMenu = rootDescription:CreateButton("Auras & Indicators")
            end
            return auraMenu
        end

        if frame.isBossGroup then
            local menu = GetAuraMenu()
            local function IsAuraMode(value)
                return PF.db.bossLayout.auraMode == value
            end
            local function SetAuraMode(value)
                PF.db.bossLayout.auraMode = value
                PF:ApplyBossAuraOptions()
            end
            menu:CreateTitle("Displayed Auras")
            menu:CreateRadio("Mechanics", IsAuraMode, SetAuraMode, "mechanics")
            menu:CreateRadio("Personal Debuffs", IsAuraMode, SetAuraMode, "personal")
            menu:CreateRadio("Hidden", IsAuraMode, SetAuraMode, "hidden")
            menu:CreateDivider()
            menu:CreateTitle("Aura Placement")
            local function IsAuraSide(value)
                return (PF.db.bossLayout.aurasLeft ~= false) == (value == "left")
            end
            local function SetAuraSide(value)
                PF.db.bossLayout.aurasLeft = value == "left"
                PF:ApplyBossAuraOptions()
            end
            menu:CreateRadio("Left", IsAuraSide, SetAuraSide, "left")
            menu:CreateRadio("Right", IsAuraSide, SetAuraSide, "right")
        end

        if frame.SetBuffsAbove then
            GetAuraMenu():CreateCheckbox("Place Buffs Above", function()
                return setting.buffsAbove
            end, function()
                setting.buffsAbove = not setting.buffsAbove
                frame:SetBuffsAbove(setting.buffsAbove)
            end)
        end
        if frame.SetAurasLeft then
            GetAuraMenu():CreateCheckbox("Place Auras on Left", function()
                return setting.aurasLeft == true
            end, function()
                setting.aurasLeft = not setting.aurasLeft
                frame:SetAurasLeft(setting.aurasLeft)
            end)
        end
        if frame.SetAuraLimits then
            local menu = GetAuraMenu()
            menu:CreateTitle("Maximum Buffs")
            AddMenuSlider(menu, setting.maxBuffs, 0, PF.MAX_AURAS, function(value)
                setting.maxBuffs = value
                frame:SetAuraLimits(setting.maxBuffs, setting.maxDebuffs)
            end)
            if not isPartyFrame then
                menu:CreateTitle("Maximum Debuffs")
                AddMenuSlider(menu, setting.maxDebuffs, 0, PF.MAX_AURAS, function(value)
                    setting.maxDebuffs = value
                    frame:SetAuraLimits(setting.maxBuffs, setting.maxDebuffs)
                end)
            end
        end
        if frame.hasThreatDisplay then
            local menu = GetAuraMenu()
            menu:CreateDivider()
            menu:CreateTitle("Threat")
            menu:CreateCheckbox("Portrait Glow", function()
                return setting.showThreatGlow ~= false
            end, function()
                setting.showThreatGlow = setting.showThreatGlow == false
                PF:UpdateTargetThreat(frame)
            end)
            menu:CreateCheckbox("Include Pet Threat", function()
                return setting.showPetThreat == true
            end, function()
                setting.showPetThreat = setting.showPetThreat ~= true
                PF:UpdateTargetThreat(frame)
            end)
            local function IsThreatTextMode(value)
                return setting.threatTextMode == value
            end
            local function SetThreatTextMode(value)
                setting.threatTextMode = value
                PF:UpdateTargetThreat(frame)
            end
            menu:CreateTitle("Threat Text")
            menu:CreateRadio("None", IsThreatTextMode, SetThreatTextMode, "none")
            menu:CreateRadio("Aggro %", IsThreatTextMode, SetThreatTextMode, "aggro")
            menu:CreateRadio("Raw %", IsThreatTextMode, SetThreatTextMode, "raw")
        end

        local behaviorMenu
        local function GetBehaviorMenu()
            if not behaviorMenu then
                behaviorMenu = rootDescription:CreateButton("Frame Behavior")
            end
            return behaviorMenu
        end

        if (frame.castBar and not isBossFrame) or frame.isBossGroup then
            GetBehaviorMenu():CreateCheckbox("Hide Cast Bar", function()
                return setting.hideCastBar == true
            end, function()
                setting.hideCastBar = not setting.hideCastBar
                PF:RefreshCastBarPreviews()
            end)
        end
        if frame.oneBarSkinTexture and not isBossFrame then
            GetBehaviorMenu():CreateCheckbox("Force One-Bar Layout", function()
                return setting.forceOneBar
            end, function()
                setting.forceOneBar = not setting.forceOneBar
                PF:UpdateUnitFrame(frame, true)
            end)
        elseif isBossFrame and frame.oneBarSkinTexture then
            GetBehaviorMenu():CreateCheckbox("Hide Power Bar", function()
                return setting.forceOneBar == true
            end, function()
                setting.forceOneBar = not setting.forceOneBar
                PF:UpdateUnitFrame(frame, true)
            end)
        end
        if frame.SetPetHappinessShown then
            GetBehaviorMenu():CreateCheckbox("Hide Pet Happiness", function()
                return setting.hidePetHappiness == true
            end, function()
                setting.hidePetHappiness = not setting.hidePetHappiness
                frame:SetPetHappinessShown(not setting.hidePetHappiness)
            end)
        end
        if frame.SetPetPowerShown then
            local menu = GetBehaviorMenu()
            local function IsPetBarMode(value)
                return setting.petBarMode == value
            end
            local function SetPetBarMode(value)
                setting.petBarMode = value
                frame:SetPetPowerShown(value ~= "healthOnly")
            end
            menu:CreateTitle("Pet Bars")
            menu:CreateRadio("Health + Power", IsPetBarMode, SetPetBarMode, "healthPower")
            menu:CreateRadio("Health Only", IsPetBarMode, SetPetBarMode, "healthOnly")
        end
        if frame.settingKey == "player" and PF.UpdateClassResourceDisplay then
            local menu = GetBehaviorMenu()
            local function IsResourceMode(value)
                return setting.classResourceVisibility == value
            end
            local function SetResourceMode(value)
                setting.classResourceVisibility = value
                PF:UpdateClassResourceDisplay(true)
            end
            menu:CreateTitle("Class Resource")
            menu:CreateRadio("Automatic", IsResourceMode, SetResourceMode, "automatic")
            menu:CreateRadio("Hidden", IsResourceMode, SetResourceMode, "hidden")
        end
    end)
end

