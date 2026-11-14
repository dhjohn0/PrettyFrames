local _, PF = ...

local AttachedPositionBehavior = {
    contextMenuScope = "move",
    contextMenuOrder = 70,
    contextMenuGroup = { key = "layout", title = "Layout" },
}
PF.AttachedPositionBehavior = PF.FrameBehaviors:Register(
    "attachedPosition", AttachedPositionBehavior
)

function AttachedPositionBehavior:ValidateAttachment(_, options)
    assert(type(options.isIndependent) == "function",
        "attached position behavior requires isIndependent")
    assert(type(options.setIndependent) == "function",
        "attached position behavior requires setIndependent")
    assert(type(options.hasSavedPosition) == "function",
        "attached position behavior requires hasSavedPosition")
    assert(type(options.savePosition) == "function",
        "attached position behavior requires savePosition")
    assert(type(options.applyPosition) == "function",
        "attached position behavior requires applyPosition")
end

function AttachedPositionBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
    attachment.deferredModeKey = attachment.deferredModeKey or {}
    attachment.deferredRegisterKey = attachment.deferredRegisterKey or {}
    attachment.registeredRegions = attachment.registeredRegions
        or setmetatable({}, { __mode = "k" })
    attachment.cleanupKey = attachment.cleanupKey or {}
end

function AttachedPositionBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function() return attachment.options.applyPosition() end
    )
end

function AttachedPositionBehavior:SetIndependent(attachment, independent)
    if not attachment or attachment.options.isIndependent() == independent then return false end
    if InCombatLockdown() then
        PF:Print("positioning changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredModeKey,
        function()
            if attachment.options.isIndependent() == independent then return true end
            if independent then
                if not attachment.options.hasSavedPosition() then
                    attachment.options.savePosition()
                end
            else
                attachment.options.savePosition()
            end
            attachment.options.setIndependent(independent)
            return attachment.options.applyPosition()
        end
    )
end

function AttachedPositionBehavior:AddPositioningChoices(menu, attachment)
    local function IsSelected(value)
        return attachment.options.isIndependent() == (value == "independent")
    end
    local function SetSelected(value)
        self:SetIndependent(attachment, value == "independent")
    end
    menu:CreateRadio("Attached to Frame", IsSelected, SetSelected, "attached")
    menu:CreateRadio("Independent", IsSelected, SetSelected, "independent")
end

function AttachedPositionBehavior:AddContextMenu(rootDescription, attachment)
    if attachment.options.menuStyle == "checkbox" then
        rootDescription:CreateCheckbox(
            attachment.options.checkboxLabel or "Independent Positioning",
            function() return attachment.options.isIndependent() end,
            function()
                self:SetIndependent(attachment, not attachment.options.isIndependent())
            end
        )
    else
        self:AddPositioningChoices(rootDescription, attachment)
    end
end

function AttachedPositionBehavior:OpenContextMenu(attachment, owner)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        PF:Print("the positioning menu is unavailable on this client build.")
        return
    end
    if attachment.options.isMenuAvailable
        and not attachment.options.isMenuAvailable() then return end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(attachment.options.menuTitle or "Positioning")
        rootDescription:CreateTitle("Positioning")
        self:AddPositioningChoices(rootDescription, attachment)
    end)
end

function AttachedPositionBehavior:RegisterEditing(attachment)
    local dragFrame = attachment.options.getDragFrame
        and attachment.options.getDragFrame() or attachment.subject
    if not dragFrame then return end
    dragFrame:SetMovable(true)
    if attachment.options.clampToScreen ~= false then dragFrame:SetClampedToScreen(true) end

    local regions = attachment.options.getDragRegions
        and attachment.options.getDragRegions() or { attachment.subject }
    for _, region in ipairs(regions or {}) do
        if region and not attachment.registeredRegions[region] then
            attachment.registeredRegions[region] = true
            if attachment.options.manageRegionMouse then
                region:EnableMouse(not PF.db.locked)
            end
            region:RegisterForDrag("LeftButton")
            region:SetScript("OnDragStart", function()
                if attachment.options.isIndependent() and not PF.db.locked
                    and not InCombatLockdown() then
                    dragFrame:StartMoving()
                end
            end)
            region:SetScript("OnDragStop", function()
                dragFrame:StopMovingOrSizing()
                if attachment.options.isIndependent() then
                    attachment.options.savePosition()
                    attachment.options.applyPosition()
                end
            end)
            if attachment.options.directContextMenu then
                region:SetScript("OnMouseUp", function(widget, mouseButton)
                    if mouseButton == "RightButton" and not PF.db.locked then
                        self:OpenContextMenu(attachment, widget)
                    end
                end)
            end
        end
    end
end

function AttachedPositionBehavior:OnAttached(attachment)
    if InCombatLockdown() then
        return PF.FrameBehaviors:RunOutOfCombat(
            self,
            attachment.deferredRegisterKey,
            function()
                if attachment.detached then return false end
                self:RegisterEditing(attachment)
                return true
            end
        )
    end
    self:RegisterEditing(attachment)
end

function AttachedPositionBehavior:OnEditModeChanged(state)
    for _, attachment in ipairs(self.attachments) do
        if attachment.options.manageRegionMouse then
            for region in pairs(attachment.registeredRegions or {}) do
                region:EnableMouse(state.editing)
            end
        end
    end
end

function AttachedPositionBehavior:OnDetached(attachment)
    local function Cleanup()
        if self:GetAttachment(attachment.subject) then return false end
        local dragFrame = attachment.options.getDragFrame
            and attachment.options.getDragFrame() or attachment.subject
        if dragFrame and dragFrame.StopMovingOrSizing then
            dragFrame:StopMovingOrSizing()
        end
        for region in pairs(attachment.registeredRegions or {}) do
            region:SetScript("OnDragStart", nil)
            region:SetScript("OnDragStop", nil)
            if attachment.options.directContextMenu then
                region:SetScript("OnMouseUp", nil)
            end
            if region.RegisterForDrag then region:RegisterForDrag() end
            if attachment.options.manageRegionMouse and region.EnableMouse then
                region:EnableMouse(false)
            end
        end
        attachment.registeredRegions = setmetatable({}, { __mode = "k" })
        return true
    end
    if InCombatLockdown() then
        return PF.FrameBehaviors:RunOutOfCombat(self, attachment.cleanupKey, Cleanup)
    end
    return Cleanup()
end
