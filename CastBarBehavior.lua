local _, PF = ...

local CastBarBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuScope = "move",
    contextMenuOrder = 80,
    contextMenuGroup = { key = "frameBehavior", title = "Frame Behavior" },
    refreshOnAttach = true,
}
PF.CastBarBehavior = PF.FrameBehaviors:Register("castBar", CastBarBehavior)

function CastBarBehavior:ValidateAttachment(_, options)
    assert(type(options.getBars) == "function",
        "cast bar behavior requires getBars")
    assert(type(options.getHidden) == "function",
        "cast bar behavior requires getHidden")
    assert(type(options.setHidden) == "function",
        "cast bar behavior requires setHidden")
end

function CastBarBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredChangeKey = attachment.deferredChangeKey or {}
end

function CastBarBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            for _, castBar in ipairs(attachment.options.getBars() or {}) do
                PF:RefreshCastBarDisplay(castBar)
            end
            return true
        end
    )
end

function CastBarBehavior:SetHidden(attachment, hidden)
    if not attachment or attachment.options.getHidden() == hidden then return false end
    if InCombatLockdown() then
        PF:Print("cast bar visibility changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredChangeKey,
        function()
            if attachment.options.getHidden() == hidden then return true end
            attachment.options.setHidden(hidden)
            return self:Apply(attachment)
        end
    )
end

function CastBarBehavior:AddContextMenu(rootDescription, attachment)
    rootDescription:CreateCheckbox("Hide Cast Bar", function()
        return attachment.options.getHidden() == true
    end, function()
        self:SetHidden(attachment, attachment.options.getHidden() ~= true)
    end)
end

function CastBarBehavior:AttachUnitFrame(frame, settingKey)
    local castBar = frame and frame.castBar
    if not castBar or frame.isBossFrame or not settingKey
        or not PF.RefreshCastBarPreviews then return end
    local labels = { player = "Player", target = "Target", focus = "Focus" }
    local label = labels[settingKey] or settingKey
    PF.FrameBehaviors:Attach("attachedPosition", castBar, {
        directContextMenu = true,
        manageRegionMouse = true,
        menuTitle = label .. " Cast Bar",
        getDragFrame = function() return castBar end,
        getDragRegions = function()
            return castBar.preview and { castBar, castBar.preview } or { castBar }
        end,
        isIndependent = function()
            return PF:GetFrameSetting(settingKey).castBarIndependent == true
        end,
        setIndependent = function(value)
            PF:GetFrameSetting(settingKey).castBarIndependent = value == true
        end,
        hasSavedPosition = function()
            return PF:GetFrameSetting(settingKey).castBarPosition ~= nil
        end,
        savePosition = function() PF:SaveCastBarPosition(castBar) end,
        applyPosition = function()
            local setting = PF:GetFrameSetting(settingKey)
            if setting.castBarIndependent then
                return PF:ApplyCastBarPosition(frame)
            elseif frame.SetFlipped then
                return frame:SetFlipped(setting.flipped == true)
            end
        end,
    })
    return PF.FrameBehaviors:Attach("castBar", frame, {
        contextMenuScope = "move",
        getBars = function() return { castBar } end,
        getHidden = function()
            return PF:GetFrameSetting(settingKey).hideCastBar == true
        end,
        setHidden = function(value)
            PF:GetFrameSetting(settingKey).hideCastBar = value == true
        end,
    })
end

function CastBarBehavior:OnDetached(attachment, reason)
    for _, castBar in ipairs(attachment.options.getBars() or {}) do
        PF.FrameBehaviors:Detach("attachedPosition", castBar, reason)
    end
end

function CastBarBehavior:OnEditModeChanged()
    self:RefreshAll()
end
