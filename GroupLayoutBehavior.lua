local _, PF = ...

local GroupLayoutBehavior = {
    autoAttach = { groupFrame = true },
    contextMenuScope = "move",
    contextMenuOrder = 70,
    contextMenuGroup = { key = "layout", title = "Layout" },
}
PF.GroupLayoutBehavior = PF.FrameBehaviors:Register("groupLayout", GroupLayoutBehavior)

function GroupLayoutBehavior:ValidateAttachment(_, options)
    assert(options.kind == "party" or options.kind == "raid" or options.kind == "boss",
        "unknown group layout kind: " .. tostring(options.kind))
    assert(type(options.getOptions) == "function",
        "group layout behavior requires getOptions")
    assert(type(options.refresh) == "function",
        "group layout behavior requires refresh")
    assert(type(options.applyOption) == "function",
        "group layout behavior requires applyOption")
end

function GroupLayoutBehavior:ConfigureAttachment(attachment)
    attachment.deferredRefreshKey = attachment.deferredRefreshKey or {}
    attachment.deferredOptionKeys = attachment.deferredOptionKeys or {}
end

function GroupLayoutBehavior:GetDeferredOptionKey(attachment, key)
    local deferredKey = attachment.deferredOptionKeys[key]
    if not deferredKey then
        deferredKey = {}
        attachment.deferredOptionKeys[key] = deferredKey
    end
    return deferredKey
end

function GroupLayoutBehavior:Apply(attachment)
    if not attachment then return end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        attachment.deferredRefreshKey,
        function() return attachment.options.refresh() end,
        attachment
    )
end

function GroupLayoutBehavior:SetOption(attachment, key, value)
    local options = attachment and attachment.options.getOptions()
    if not options or options[key] == value then return false end

    if InCombatLockdown() then
        PF:Print("group layout changes will apply after combat.")
    end
    return PF.FrameBehaviors:RunOutOfCombat(
        self,
        self:GetDeferredOptionKey(attachment, key),
        function()
            local currentOptions = attachment.options.getOptions()
            if not currentOptions then return false end
            local previous = currentOptions[key]
            if previous == value then return true end
            if attachment.options.beforeOptionChanged then
                attachment.options.beforeOptionChanged(key, previous, value)
            end
            currentOptions[key] = value
            return attachment.options.applyOption(key, previous, value)
        end,
        attachment
    )
end

function GroupLayoutBehavior:OnEditModeChanged()
    for _, attachment in ipairs(self.attachments) do
        self:Refresh(attachment)
        if attachment.options.afterEditModeChanged then
            attachment.options.afterEditModeChanged()
        end
    end
end

local function AddGrowthMenu(menu, behavior, attachment, options)
    menu:CreateTitle("Growth Direction")
    menu:CreateRadio("Down", function()
        return options.growUpwards ~= true
    end, function()
        behavior:SetOption(attachment, "growUpwards", false)
    end)
    menu:CreateRadio("Up", function()
        return options.growUpwards == true
    end, function()
        behavior:SetOption(attachment, "growUpwards", true)
    end)
end

local function AddSortMenu(menu, behavior, attachment, options, defaultLabel)
    menu:CreateTitle("Sort Order")
    local function IsSelected(value) return options.sort == value end
    local function SetSelected(value)
        behavior:SetOption(attachment, "sort", value)
    end
    menu:CreateRadio(defaultLabel, IsSelected, SetSelected, "index")
    menu:CreateRadio("Role", IsSelected, SetSelected, "role")
    menu:CreateRadio("Name", IsSelected, SetSelected, "name")
end

local function AddPartyMenu(menu, behavior, attachment, options)
    AddGrowthMenu(menu, behavior, attachment, options)
    menu:CreateDivider()
    AddSortMenu(menu, behavior, attachment, options, "Party Order")
end

local function AddRaidMenu(menu, behavior, attachment, options)
    menu:CreateCheckbox("Show Group Headers", function()
        return options.showHeaders ~= false
    end, function()
        behavior:SetOption(attachment, "showHeaders", options.showHeaders == false)
    end)
    menu:CreateCheckbox("Independent Positioning", function()
        return options.independentPositioning == true
    end, function()
        behavior:SetOption(
            attachment, "independentPositioning",
            options.independentPositioning ~= true
        )
    end)
    menu:CreateDivider()
    AddSortMenu(menu, behavior, attachment, options, "Raid Order")
end

local function AddBossMenu(menu, behavior, attachment, options)
    menu:CreateTitle("Positioning")
    local function IsSelected(value)
        return (options.independentPositioning == true) == (value == "independent")
    end
    local function SetSelected(value)
        behavior:SetOption(
            attachment, "independentPositioning", value == "independent"
        )
    end
    menu:CreateRadio("As a Group", IsSelected, SetSelected, "group")
    menu:CreateRadio("Independent", IsSelected, SetSelected, "independent")
    if options.independentPositioning ~= true then
        menu:CreateDivider()
        AddGrowthMenu(menu, behavior, attachment, options)
    end
end

function GroupLayoutBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    if not options then return end
    local builders = {
        party = AddPartyMenu,
        raid = AddRaidMenu,
        boss = AddBossMenu,
    }
    builders[attachment.options.kind](rootDescription, self, attachment, options)
end

local function RefreshGroup(key)
    local subject = PF.frames and PF.frames[key]
    return subject and GroupLayoutBehavior:RefreshSubject(subject)
end

function PF:ApplyPartyGroupLayout() return RefreshGroup("party") end
function PF:ApplyRaidGroupLayout() return RefreshGroup("raid") end
function PF:ApplyBossGroupLayout() return RefreshGroup("boss") end
