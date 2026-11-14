local _, PF = ...

function PF:OpenRaidContextMenu(owner)
    if InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("the raid menu is unavailable on this client build.")
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle("Raid Frames")
        PF.FrameBehaviors:AddContextMenus(rootDescription, PF.frames.raid, "move")
    end)
end
