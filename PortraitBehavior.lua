local _, PF = ...

local PortraitBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame" },
    refreshOnAttach = true,
}
PF.PortraitBehavior = PF.FrameBehaviors:Register("portrait", PortraitBehavior)

function PortraitBehavior:ValidateAttachment(frame, options)
    assert(frame and frame.portrait,
        "portrait behavior requires a frame with a portrait")
    assert(type(options.getUnit) == "function",
        "portrait behavior requires getUnit")
end

function PortraitBehavior:IsEnabled()
    return not PF.db or PF.db.enable3DPortraits ~= false
end

function PortraitBehavior:ShowFallback(portrait)
    if not portrait then return end
    portrait.modelRequested = false
    portrait.modelReady = false
    portrait.modelUnit = nil
    if portrait.model then
        portrait.model:ClearModel()
        portrait.model:Hide()
    end
    if portrait.fallback then portrait.fallback:Show() end
end

function PortraitBehavior:RequestModel(portrait, unit, force)
    if not portrait or not portrait.model or not unit or not self:IsEnabled() then
        self:ShowFallback(portrait)
        return false
    end
    if not force and portrait.modelUnit == unit and portrait.modelRequested
        and portrait.model:IsShown() then return true end

    -- Keep the generated 2D portrait visible until WoW confirms the model.
    portrait.modelRequested = false
    portrait.modelReady = false
    portrait.fallback:Show()
    portrait.model:ClearModel()
    portrait.model:Show()
    portrait.modelRequested = true
    portrait.modelUnit = unit
    portrait.model:SetUnit(unit)
    portrait.model:SetPortraitZoom(1)
    if portrait.model.SetCamDistanceScale then
        portrait.model:SetCamDistanceScale(portrait.cameraDistanceScale or 0.88)
    end
    return true
end

function PortraitBehavior:OnModelLoaded(portrait)
    if not portrait or not portrait.modelRequested or not self:IsEnabled()
        or portrait.modelReady then return end
    portrait.modelReady = true
    portrait.fallback:Hide()
end

function PortraitBehavior:ClearFrame(frame)
    local portrait = frame and frame.portrait
    if not portrait then return end
    self:ShowFallback(portrait)
    if portrait.fallback then portrait.fallback:SetTexture(nil) end
end

function PortraitBehavior:UpdateFrame(frame, exists, testPreview, forceModel)
    local portrait = frame and frame.portrait
    if not portrait then return end
    local attachment = self:GetAttachment(frame)
    local unit = attachment and attachment.options.getUnit() or frame.unit
    if not unit then
        self:ClearFrame(frame)
        return
    end

    if exists then
        SetPortraitTexture(portrait.fallback, unit)
        local visible = UnitIsVisible(unit)
        if self:IsEnabled() and PF:IsDisplaySafe(visible) and visible then
            self:RequestModel(portrait, unit, forceModel)
        else
            self:ShowFallback(portrait)
        end
    elseif testPreview and unit:find("^boss") then
        portrait.fallback:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
        self:ShowFallback(portrait)
    elseif testPreview and unit:find("^party") then
        SetPortraitTexture(portrait.fallback, "player")
        self:RequestModel(portrait, "player", forceModel)
    elseif unit ~= "player" then
        self:ShowFallback(portrait)
    end
end

function PortraitBehavior:ResolveFrameState(frame)
    local unit = frame and frame.unit
    if not unit then return false, false end
    local exists = UnitExists(unit)
    local previewIndex = tonumber(unit:match("%d+")) or 1
    local previewLimit = unit:find("raid") and 22
        or (unit:find("^boss") and 5 or 4)
    local testPreview = PF.testMode == true
        and (unit == "player" or unit == "target" or unit == "focus"
            or previewIndex <= previewLimit)
    return exists, testPreview
end

function PortraitBehavior:Apply(attachment)
    if not attachment then return end
    local exists, testPreview = self:ResolveFrameState(attachment.subject)
    if not exists and not testPreview then
        return self:ClearFrame(attachment.subject)
    end
    return self:UpdateFrame(attachment.subject, exists, testPreview)
end

function PortraitBehavior:SetEnabled(enabled)
    enabled = enabled == true
    if PF.db.enable3DPortraits == enabled then return false end
    PF:SetThemeOption("enable3DPortraits", enabled)
    self:RefreshAll()
    return true
end

function PortraitBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not frame.portrait then return end
    return PF.FrameBehaviors:Attach("portrait", frame, {
        settingKey = settingKey,
        getUnit = function() return frame.unit end,
    })
end

function PortraitBehavior:OnFrameDetached(_, frame)
    self:ClearFrame(frame)
end
