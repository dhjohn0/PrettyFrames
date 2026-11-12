local _, PF = ...

function PF:CreateAllFrames()
    local targetLayout = self:ThemeFrameLayout("target", "unitFrames")
    local focusLayout = self:ThemeFrameLayout("focus", "unitFrames")
    local targetTargetLayout = self:ThemeFrameLayout("targettarget", "unitFrames")
    local player = self:CreateUnifiedPlayerFrame()
    local target = self:CreateOrnateUnitFrame(
        "PrettyFramesTarget", "target",
        targetLayout.targetSize[1], targetLayout.targetSize[2], "target", true
    )
    if self.CreateClassResourceDisplay then
        self:CreateClassResourceDisplay()
    end
    self:CreateOrnateUnitFrame(
        "PrettyFramesFocus", "focus",
        focusLayout.focusSize[1], focusLayout.focusSize[2], "focus"
    )

    self:CreateBossFrames()

    local targetTarget = self:CreateOrnateUnitFrame(
        "PrettyFramesTargetTarget", "targettarget",
        targetTargetLayout.targetOfTargetSize[1], targetTargetLayout.targetOfTargetSize[2],
        nil, true, true
    )
    targetTarget:SetParent(target)
    self:SetThemePoint(targetTarget, target, targetTargetLayout.targetOfTargetAttach)
    self:RegisterTargetTargetPositioning(targetTarget)

    self:CreatePartyFrames()
    self:CreateRaidFrames()
    self:RefreshAllFrames()
end
