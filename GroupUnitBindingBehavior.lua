local _, PF = ...

local GroupUnitBindingBehavior = {
    autoAttach = { groupFrame = true },
}
PF.GroupUnitBindingBehavior = PF.FrameBehaviors:Register(
    "groupUnitBinding", GroupUnitBindingBehavior
)

function GroupUnitBindingBehavior:ValidateAttachment(_, options)
    assert(options.kind == "party" or options.kind == "raid",
        "group unit binding behavior requires a party or raid kind")
    assert(type(options.getFrames) == "function",
        "group unit binding behavior requires getFrames")
    assert(type(options.getUnits) == "function",
        "group unit binding behavior requires getUnits")
end

function GroupUnitBindingBehavior:ConfigureAttachment(attachment)
    attachment.deferredApplyKey = attachment.deferredApplyKey or {}
end

function GroupUnitBindingBehavior:AssignUnit(frame, unit)
    if frame.unit == unit then return false end

    UnregisterUnitWatch(frame)
    frame.unit = unit
    frame:SetAttribute("unit", unit)
    for _, holder in ipairs({
        frame.nativeBuffs, frame.nativeDebuffs, frame.nativeMaintenance,
    }) do
        if holder and holder.container then
            holder.container:SetUnit(unit)
        end
    end
    return true
end

function GroupUnitBindingBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredApplyKey,
        function()
            self:SyncFrames(attachment)
            local frames = attachment.options.getFrames()
            local units = attachment.options.getUnits()
            if type(frames) ~= "table" or type(units) ~= "table" then
                return false
            end

            for index, frame in ipairs(frames) do
                self:AssignUnit(frame, units[index])
                PF:ApplyFrameVisibility(frame)
                PF:UpdateUnitFrame(frame, true)
            end

            local afterApply = attachment.options.afterApply
            if afterApply then
                local result = afterApply()
                if result ~= nil then return result end
            end
            return true
        end,
        attachment
    )
end

local function RefreshGroup(key)
    local subject = PF.frames and PF.frames[key]
    return subject and GroupUnitBindingBehavior:RefreshSubject(subject)
end

function PF:ApplyPartyUnitBindings() return RefreshGroup("party") end
function PF:ApplyRaidUnitBindings() return RefreshGroup("raid") end
