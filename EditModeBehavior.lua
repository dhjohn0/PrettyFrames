local _, PF = ...

local EditModeBehavior = {
    refreshOnAttach = true,
}
PF.EditModeBehavior = PF.FrameBehaviors:Register("editMode", EditModeBehavior)

function EditModeBehavior:ValidateAttachment(_, options)
    assert(type(options.apply) == "function",
        "edit mode behavior requires apply")
end

function EditModeBehavior:Apply(attachment)
    if not attachment then return end
    return attachment.options.apply(PF.db and not PF.db.locked or false)
end

function EditModeBehavior:OnEditModeChanged()
    self:RefreshAll()
end

function EditModeBehavior:AttachMovableFrame(frame)
    if not frame then return end
    return PF.FrameBehaviors:Attach("editMode", frame, {
        apply = function(editing)
            if frame.moveLabel then frame.moveLabel:SetShown(editing) end
            if frame.moveHandle then frame.moveHandle:SetShown(editing) end
            return true
        end,
    })
end
