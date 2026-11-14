local _, PF = ...

function PF:CreateAllFrames()
    local targetLayout = self:ThemeFrameLayout("target", "unitFrames")
    local focusLayout = self:ThemeFrameLayout("focus", "unitFrames")
    local targetTargetLayout = self:ThemeFrameLayout("targettarget", "unitFrames")
    local player = self:CreateUnifiedPlayerFrame()
    local pet = self.frames.pet
    if pet then
        self.FrameBehaviors:Attach("outOfRange", pet, {
            getFrames = function() return { pet } end,
            getOptions = function() return PF:GetFrameSetting("pet") end,
            fadeLabel = "Fade Out-of-Range Pet",
        })
    end
    local target = self:CreateOrnateUnitFrame(
        "PrettyFramesTarget", "target",
        targetLayout.targetSize[1], targetLayout.targetSize[2], "target", true
    )
    self.FrameBehaviors:Attach("outOfRange", target, {
        getFrames = function() return { target } end,
        getOptions = function() return PF:GetFrameSetting("target") end,
        fadeLabel = "Fade Out-of-Range Unit",
    })
    if self.CreateClassResourceDisplay then
        self:CreateClassResourceDisplay()
    end
    local focus = self:CreateOrnateUnitFrame(
        "PrettyFramesFocus", "focus",
        focusLayout.focusSize[1], focusLayout.focusSize[2], "focus"
    )
    self.FrameBehaviors:Attach("outOfRange", focus, {
        getFrames = function() return { focus } end,
        getOptions = function() return PF:GetFrameSetting("focus") end,
        fadeLabel = "Fade Out-of-Range Unit",
    })

    self:CreateBossFrames()

    local targetTarget = self:CreateOrnateUnitFrame(
        "PrettyFramesTargetTarget", "targettarget",
        targetTargetLayout.targetOfTargetSize[1], targetTargetLayout.targetOfTargetSize[2],
        nil, true, true
    )
    targetTarget:SetParent(target)
    self:SetThemePoint(targetTarget, target, targetTargetLayout.targetOfTargetAttach)
    self.FrameBehaviors:Attach("attachedPosition", targetTarget, {
        menuStyle = "checkbox",
        checkboxLabel = "Independent Positioning",
        contextMenuScope = "move",
        clampToScreen = false,
        getDragFrame = function() return targetTarget end,
        getDragRegions = function() return { targetTarget } end,
        isIndependent = function()
            return PF:GetFrameSetting("targettarget").independentPositioning == true
        end,
        setIndependent = function(value)
            PF:GetFrameSetting("targettarget").independentPositioning = value == true
        end,
        hasSavedPosition = function()
            return PF.db.positions.targettarget ~= nil
        end,
        savePosition = function() PF:SaveTargetTargetPosition(targetTarget) end,
        applyPosition = function() return PF:ApplyTargetTargetPosition(targetTarget) end,
    })
    self:ApplyTargetTargetPosition(targetTarget)

    self:CreatePartyFrames()
    self:CreateRaidFrames()
    self:RefreshAllFrames()
end
