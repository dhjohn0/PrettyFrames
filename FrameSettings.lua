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

    -- Region geometry is reported in the region's effective coordinate
    -- space. Convert the source geometry into UIParent units before deriving
    -- offsets; subtracting the raw values makes a globally scaled frame
    -- (notably 60% on handheld layouts) mirror too high and too far inward.
    sourceX, sourceTop = self:ConvertRegionCoordinatesToUIParent(source, sourceX, sourceTop)
    if not sourceX or not sourceTop then return end

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
    local protected = frame.IsProtected and frame:IsProtected()
    if not protected then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(widget)
            if not self.db.locked and not InCombatLockdown() then
                widget:StartMoving()
                widget.mirrorPlayerTargetDragging = true
            end
        end)
        frame:SetScript("OnDragStop", function(widget)
            if not widget.mirrorPlayerTargetDragging then return end
            widget.mirrorPlayerTargetDragging = nil
            if InCombatLockdown() then return end
            widget:StopMovingOrSizing()
            self:SavePosition(widget, key)
            self:MirrorPlayerTargetPosition(key)
        end)
    end
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
    handle.contextMenuLevel = "move"
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            frame:StartMoving()
            frame.mirrorPlayerTargetDragging = true
        end
    end)
    handle:SetScript("OnDragStop", function()
        if not frame.mirrorPlayerTargetDragging then return end
        frame.mirrorPlayerTargetDragging = nil
        if InCombatLockdown() then return end
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
    self.EditModeBehavior:AttachMovableFrame(frame)
end

function PF:PerformScaleRefresh()
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

function PF:RefreshScale()
    return self.ScaleBehavior:RefreshGlobal()
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
            healthTextMode = "currentmax",
            healthColorMode = "unit",
            healthBackgroundAlpha = 1,
            healthSpark = true,
            powerTextMode = "currentmax",
            powerColorMode = "type",
            powerBackgroundAlpha = 1,
            powerSpark = true,
            buffsAbove = false,
            aurasLeft = false,
            hideCastBar = false,
            hidePetHappiness = false,
            petBarMode = "healthPower",
            rangeFade = true,
            rangeDistance = "ranged",
            outOfRangeAlpha = 0.55,
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
    if setting.healthTextMode ~= "deficit" and setting.healthTextMode ~= "percent"
        and setting.healthTextMode ~= "current"
        and setting.healthTextMode ~= "maximum"
        and setting.healthTextMode ~= "currentpercent"
        and setting.healthTextMode ~= "none" then
        setting.healthTextMode = "currentmax"
    end
    if setting.healthColorMode ~= "class" and setting.healthColorMode ~= "reaction"
        and setting.healthColorMode ~= "gradient"
        and setting.healthColorMode ~= "green" then
        setting.healthColorMode = "unit"
    end
    if setting.healthBackgroundAlpha ~= 0 and setting.healthBackgroundAlpha ~= 0.25
        and setting.healthBackgroundAlpha ~= 0.5
        and setting.healthBackgroundAlpha ~= 0.75
        and setting.healthBackgroundAlpha ~= 1 then
        setting.healthBackgroundAlpha = 1
    end
    setting.healthSpark = setting.healthSpark ~= false
    if setting.powerTextMode ~= "current" and setting.powerTextMode ~= "maximum"
        and setting.powerTextMode ~= "percent"
        and setting.powerTextMode ~= "currentpercent"
        and setting.powerTextMode ~= "none" then
        setting.powerTextMode = "currentmax"
    end
    if setting.powerColorMode ~= "class" and setting.powerColorMode ~= "gradient"
        and setting.powerColorMode ~= "theme" and setting.powerColorMode ~= "red"
        and setting.powerColorMode ~= "yellow" then
        setting.powerColorMode = "type"
    end
    if setting.powerBackgroundAlpha ~= 0 and setting.powerBackgroundAlpha ~= 0.25
        and setting.powerBackgroundAlpha ~= 0.5
        and setting.powerBackgroundAlpha ~= 0.75
        and setting.powerBackgroundAlpha ~= 1 then
        setting.powerBackgroundAlpha = 1
    end
    setting.powerSpark = setting.powerSpark ~= false
    setting.hideCastBar = setting.hideCastBar == true
    setting.hidePetHappiness = setting.hidePetHappiness == true
    setting.petBarMode = setting.petBarMode == "healthOnly" and "healthOnly" or "healthPower"
    setting.rangeFade = setting.rangeFade ~= false
    setting.rangeDistance = setting.rangeDistance == "melee" and "melee" or "ranged"
    if setting.outOfRangeAlpha ~= 0.35 and setting.outOfRangeAlpha ~= 0.55
        and setting.outOfRangeAlpha ~= 0.75 then
        setting.outOfRangeAlpha = 0.55
    end
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
    x, y = self:ConvertRegionCoordinatesToUIParent(castBar, x, y)
    if not x or not y then return end
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
    x, y = self:ConvertRegionCoordinatesToUIParent(frame, x, y)
    if not x or not y then return end
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

function PF:AddMenuSlider(menuDescription, value, minValue, maxValue, onValueChanged, steps, formatter)
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

function PF:PerformFrameScale(frame)
    if not frame or not frame.settingKey then return end
    local scale = self:GetFrameSetting(frame.settingKey).scale or 1
    frame:SetScale(frame.isAnchor and self.db.scale * scale or scale)
    return true
end

function PF:ApplyFrameScale(frame)
    return self.ScaleBehavior:ApplyFrame(frame)
end

function PF:PerformFrameVisibility(frame)
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

function PF:ApplyFrameVisibility(frame)
    return self.VisibilityBehavior:ApplyFrame(frame)
end

function PF:SetMirrorPlayerTarget(enabled)
    if InCombatLockdown() then
        self:Print("Player/Target position mirroring cannot change during combat.")
        return false
    end
    self:SetThemeOption("mirrorPlayerTarget", enabled == true)
    if self.db.mirrorPlayerTarget then
        self:MirrorPlayerTargetPosition("player")
    end
    return true
end

function PF:RegisterFrameContextMenu(clickFrame, key, targetFrame)
    local target = targetFrame or clickFrame
    target.settingKey = key
    -- Never open an insecure configuration menu from a secure unit button's
    -- click handler. Forever can treat the rest of that hardware click as an
    -- addon-owned protected unit action, producing the generic "only
    -- available to the Blizzard UI" popup. Existing anchor frames already
    -- have a plain MOVE plate; attached/individual frames receive a matching
    -- OPTIONS plate while edit mode is active.
    local menuHandle = clickFrame.moveHandle
    if not menuHandle then
        menuHandle = CreateFrame("Frame", nil, clickFrame, "BackdropTemplate")
        menuHandle:SetSize(148, 22)
        menuHandle:SetPoint("BOTTOMLEFT", clickFrame, "TOPLEFT", 0, 5)
        self:RaiseEditHandle(menuHandle)
        menuHandle:EnableMouse(true)
        self:CreateBackdrop(menuHandle, 1)
        menuHandle:SetBackdropColor(0.08, 0.045, 0.02, 0.96)
        menuHandle.text = menuHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        menuHandle.text:SetPoint("CENTER")
        menuHandle.text:SetText("OPTIONS " .. key:upper())
        menuHandle.text:SetTextColor(unpack(self.colors.bronzeBright))
        menuHandle:Hide()
        clickFrame.moveHandle = menuHandle
        self.EditModeBehavior:AttachMovableFrame(clickFrame)
    end
    menuHandle.contextTarget = target
    menuHandle.contextMenuLevel = menuHandle.contextMenuLevel or "move"
    menuHandle.prettyFramesContextActive = true
    menuHandle:SetScript("OnMouseUp", function(widget, mouseButton)
        if widget.prettyFramesContextActive and mouseButton == "RightButton"
            and PF.db and not PF.db.locked then
            PF:OpenFrameContextMenu(widget)
        end
    end)
    clickFrame.prettyFramesContextHandle = menuHandle
    if not menuHandle.prettyFramesContextListed then
        menuHandle.prettyFramesContextListed = true
        table.insert(self.contextFrames, menuHandle)
    end
    if not target.contextRegistered then
        target.contextRegistered = true
        table.insert(self.configurableFrames, target)
    end

    self:ApplyFrameScale(target)
    self.FrameBehaviors:AttachDefaults("unitFrame", target, {
        settingKey = key,
        clickFrame = clickFrame,
    })
    self:ApplyFrameVisibility(target)
end

function PF:UnregisterFrameContextMenu(clickFrame, reason)
    if not clickFrame then return false end
    local menuHandle = clickFrame.prettyFramesContextHandle or clickFrame
    local target = menuHandle.contextTarget or clickFrame
    menuHandle.prettyFramesContextActive = nil
    menuHandle.prettyFramesContextListed = nil
    menuHandle.contextTarget = nil
    clickFrame.prettyFramesContextHandle = nil
    for index = #self.contextFrames, 1, -1 do
        if self.contextFrames[index] == menuHandle then
            table.remove(self.contextFrames, index)
            break
        end
    end
    if target.contextRegistered then
        target.contextRegistered = nil
        for index = #self.configurableFrames, 1, -1 do
            if self.configurableFrames[index] == target then
                table.remove(self.configurableFrames, index)
                break
            end
        end
    end
    return self.FrameBehaviors:DetachAll(target, reason or "context unregistered")
end

function PF:OpenFrameContextMenu(clickFrame)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the frame menu is unavailable on this client build.")
        return
    end

    local frame = clickFrame.contextTarget or clickFrame
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

        local contextMenuLevel = clickFrame.contextMenuLevel
            or ((isPartyFrame or isBossFrame) and "individual" or "move")
        PF.FrameBehaviors:AddContextMenus(
            rootDescription, frame, contextMenuLevel
        )
    end)
end

