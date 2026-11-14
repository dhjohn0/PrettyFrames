local _, PF = ...

local RangeCheck = LibStub and LibStub("LibRangeCheck-3.0", true)
local SetAvailabilityAlpha = PF.Widgets.SetAvailabilityAlpha
local SetRangeAlpha = PF.Widgets.SetRangeAlpha
local UPDATE_INTERVAL = 0.5
local DEFAULT_UNAVAILABLE_ALPHA = 0.34
local DEFAULT_OUT_OF_RANGE_ALPHA = 0.55

local OutOfRangeBehavior = {
    autoAttach = { groupFrame = true },
    elapsed = 0,
    contextMenuScope = "move",
    contextMenuOrder = 100,
    contextMenuGroup = function(_, attachment)
        local title = attachment.options.menuTitle or "Range"
        return { key = "range", title = title }
    end,
}
PF.OutOfRangeBehavior = PF.FrameBehaviors:Register("outOfRange", OutOfRangeBehavior)

local function NormalizeOptions(options)
    if type(options) ~= "table" then return nil end
    options.rangeFade = options.rangeFade ~= false
    options.rangeDistance = options.rangeDistance == "melee" and "melee" or "ranged"
    if options.outOfRangeAlpha ~= 0.35 and options.outOfRangeAlpha ~= 0.55
        and options.outOfRangeAlpha ~= 0.75 then
        options.outOfRangeAlpha = DEFAULT_OUT_OF_RANGE_ALPHA
    end
    return options
end

function OutOfRangeBehavior:GetRangeBand(unit)
    if not RangeCheck then return nil, nil end
    return RangeCheck:GetRange(unit)
end

function OutOfRangeBehavior:GetRangeState(unit, rangeDistance)
    -- Some range APIs do not regard a unit token resolving to the player as a
    -- valid target. Zero distance is definitive and should never be faded.
    if UnitIsUnit then
        local isPlayer = UnitIsUnit(unit, "player")
        if PF:IsDisplaySafe(isPlayer) and isPlayer == true then return true end
    end

    local minRange, maxRange = self:GetRangeBand(unit)
    if minRange == nil and maxRange == nil then return nil end

    -- The library supplies estimated bands. Only decide when the entire band
    -- lies on one side of the selected cutoff; an overlapping band is unknown
    -- and therefore remains at full opacity.
    local cutoff = rangeDistance == "melee" and 8 or 40
    if maxRange ~= nil and maxRange <= cutoff then return true end
    if minRange ~= nil and minRange >= cutoff then return false end
    return nil
end

function PF:GetUnitRangeState(unit, rangeDistance)
    return OutOfRangeBehavior:GetRangeState(unit, rangeDistance)
end

function PF:GetUnitRangeBand(unit)
    return OutOfRangeBehavior:GetRangeBand(unit)
end

function OutOfRangeBehavior:ValidateAttachment(_, options)
    assert(type(options.getFrames) == "function", "out-of-range behavior requires getFrames")
    assert(type(options.getOptions) == "function", "out-of-range behavior requires getOptions")
end

function OutOfRangeBehavior:SetAvailableAlpha(attachment, frame, alpha)
    local setter = attachment.options.setAvailabilityAlpha or SetAvailabilityAlpha
    setter(frame, alpha)
end

function OutOfRangeBehavior:SetRangeAlpha(attachment, frame, inRange, alpha)
    local setter = attachment.options.setRangeAlpha or SetRangeAlpha
    setter(frame, inRange, alpha)
end

function OutOfRangeBehavior:UpdateFrame(attachment, frame)
    if not frame or not PF.db then return end
    if not PF.db.locked or PF.testMode then
        self:SetAvailableAlpha(attachment, frame, 1)
        return
    end
    if attachment.options.isActive and not attachment.options.isActive() then return end
    if attachment.options.shownOnly ~= false and frame.IsShown and not frame:IsShown() then return end

    local options = NormalizeOptions(attachment.options.getOptions())
    if not options then return end
    local unit = attachment.options.getUnit and attachment.options.getUnit(frame) or frame.unit
    local exists = unit and UnitExists(unit)
    if not (PF:IsDisplaySafe(exists) and exists == true) then
        self:SetAvailableAlpha(attachment, frame, 1)
        return
    end

    local connected = UnitIsConnected(unit)
    local inPhase = UnitInPhase and UnitInPhase(unit)
    local unavailable = (PF:IsDisplaySafe(connected) and connected == false)
        or (PF:IsDisplaySafe(inPhase) and inPhase == false)
    if unavailable then
        self:SetAvailableAlpha(
            attachment,
            frame,
            attachment.options.unavailableAlpha or DEFAULT_UNAVAILABLE_ALPHA
        )
        return
    end

    local dead = UnitIsDeadOrGhost(unit)
    if options.rangeFade ~= false and PF:IsDisplaySafe(dead) and dead ~= true then
        self:SetRangeAlpha(
            attachment,
            frame,
            self:GetRangeState(unit, options.rangeDistance),
            options.outOfRangeAlpha
        )
    else
        self:SetAvailableAlpha(attachment, frame, 1)
    end
end

function OutOfRangeBehavior:Apply(attachment)
    if not attachment then return end
    for _, frame in ipairs(self:SyncFrames(attachment)) do
        self:UpdateFrame(attachment, frame)
    end
end

function OutOfRangeBehavior:RefreshFrame(frame)
    local attachment = self.frameAttachments[frame]
    if attachment then self:UpdateFrame(attachment, frame) end
end

function OutOfRangeBehavior:OnFrameDetached(attachment, frame)
    self:SetAvailableAlpha(attachment, frame, 1)
end

function OutOfRangeBehavior:OnEditModeChanged()
    self:RefreshAll()
end

function OutOfRangeBehavior:RefreshAll()
    for _, attachment in ipairs(self.attachments) do
        self:Refresh(attachment)
    end
end

function OutOfRangeBehavior:OnUpdate(elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    self.elapsed = 0
    self:RefreshAll()
end

function OutOfRangeBehavior:AddContextMenu(rootDescription, attachment)
    local options = NormalizeOptions(attachment.options.getOptions())
    if not options then return end

    local rangeMenu = rootDescription
    rangeMenu:CreateCheckbox(
        attachment.options.fadeLabel or "Fade Out-of-Range Units",
        function() return options.rangeFade ~= false end,
        function()
            options.rangeFade = options.rangeFade == false
            self:Refresh(attachment)
        end
    )
    rangeMenu:CreateTitle("Distance")
    local function IsDistanceSelected(value)
        return options.rangeDistance == value
    end
    local function SetDistanceSelected(value)
        options.rangeDistance = value
        self:Refresh(attachment)
    end
    rangeMenu:CreateRadio("Ranged", IsDistanceSelected, SetDistanceSelected, "ranged")
    rangeMenu:CreateRadio("Melee", IsDistanceSelected, SetDistanceSelected, "melee")

    rangeMenu:CreateTitle("Out-of-Range Opacity")
    local function IsAlphaSelected(value)
        return options.outOfRangeAlpha == value
    end
    local function SetAlphaSelected(value)
        options.outOfRangeAlpha = value
        self:Refresh(attachment)
    end
    rangeMenu:CreateRadio("Dim (35%)", IsAlphaSelected, SetAlphaSelected, 0.35)
    rangeMenu:CreateRadio("Readable (55%)", IsAlphaSelected, SetAlphaSelected, 0.55)
    rangeMenu:CreateRadio("Subtle (75%)", IsAlphaSelected, SetAlphaSelected, 0.75)
end
