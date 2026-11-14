local _, PF = ...

local predictionCalculator
if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
    local ok, calculator = pcall(CreateUnitHealPredictionCalculator)
    if ok and calculator then
        predictionCalculator = calculator
        if Enum and Enum.UnitMaximumHealthMode then
            calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
            calculator:SetIncomingHealClampMode(
                Enum.UnitIncomingHealClampMode.MissingHealth
            )
            calculator:SetIncomingHealOverflowPercent(1)
            calculator:SetDamageAbsorbClampMode(
                Enum.UnitDamageAbsorbClampMode.MissingHealth
            )
            calculator:SetHealAbsorbClampMode(
                Enum.UnitHealAbsorbClampMode.CurrentHealth
            )
            calculator:SetHealAbsorbMode(
                Enum.UnitHealAbsorbMode.ReducedByIncomingHeals
            )
        end
    end
end

local HealPredictionBehavior = {
    autoAttach = { groupFrame = true },
    refreshOnAttach = true,
    contextMenuScope = "move",
    contextMenuOrder = 52,
    contextMenuGroup = { key = "health", title = "Health" },
}
PF.HealPredictionBehavior = PF.FrameBehaviors:Register(
    "healPrediction", HealPredictionBehavior
)

function HealPredictionBehavior:ValidateAttachment(_, options)
    assert(options.kind == "party" or options.kind == "raid",
        "heal prediction behavior requires a party or raid kind")
    assert(type(options.getOptions) == "function",
        "heal prediction behavior requires getOptions")
end

local function CreatePredictionSegment(
    parent, healthBar, red, green, blue, alpha, texturePath
)
    local segment = CreateFrame("StatusBar", nil, parent)
    if segment.SetUsingParentLevel then segment:SetUsingParentLevel(true) end
    segment:SetStatusBarTexture(
        texturePath or PF:ThemeFrameAsset("raid", "statusBar", "statusBar")
    )
    segment:SetStatusBarColor(red, green, blue, alpha)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)
    segment:SetWidth(math.max(1, healthBar:GetWidth()))
    local texture = segment:GetStatusBarTexture()
    if texture and texture.SetDrawLayer then texture:SetDrawLayer("ARTWORK", 2) end
    segment.fill = texture
    segment:Hide()
    return segment
end

local function AttachPredictionSegment(segment, relative, relativeSide, reverse)
    local side = reverse and "RIGHT" or "LEFT"
    segment:ClearAllPoints()
    segment:SetPoint("TOP" .. side, relative, "TOP" .. relativeSide)
    segment:SetPoint("BOTTOM" .. side, relative, "BOTTOM" .. relativeSide)
    segment:SetReverseFill(reverse == true)
end

function HealPredictionBehavior:LayoutFrame(frame, reversed)
    local prediction = frame and frame.groupPrediction
    if not prediction then return end
    local fill = prediction.healthFill
    if reversed then
        AttachPredictionSegment(prediction.myHeals, fill, "LEFT", true)
        AttachPredictionSegment(
            prediction.otherHeals, prediction.myHeals.fill, "LEFT", true
        )
        AttachPredictionSegment(
            prediction.absorbs, prediction.otherHeals.fill, "LEFT", true
        )
        AttachPredictionSegment(prediction.healAbsorbs, fill, "LEFT", false)
    else
        AttachPredictionSegment(prediction.myHeals, fill, "RIGHT", false)
        AttachPredictionSegment(
            prediction.otherHeals, prediction.myHeals.fill, "RIGHT", false
        )
        AttachPredictionSegment(
            prediction.absorbs, prediction.otherHeals.fill, "RIGHT", false
        )
        AttachPredictionSegment(prediction.healAbsorbs, fill, "RIGHT", true)
    end
end

function HealPredictionBehavior:CreateFrame(frame, geometry)
    if not frame or not frame.health then return end
    if frame.groupPrediction then return frame.groupPrediction end
    local health = frame.health
    local insets = geometry and geometry.predictionInsets or { 0, 0, 0, 0 }
    local clip = CreateFrame("Frame", nil, health)
    clip:SetPoint("TOPLEFT", health, "TOPLEFT", insets[1] or 0, -(insets[3] or 0))
    clip:SetPoint(
        "BOTTOMRIGHT", health, "BOTTOMRIGHT", -(insets[2] or 0), insets[4] or 0
    )
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:EnableMouse(false)

    local prediction = {
        clip = clip,
        healthFill = health:GetStatusBarTexture(),
        myHeals = CreatePredictionSegment(clip, health, 0.08, 0.95, 1.00, 0.90),
        otherHeals = CreatePredictionSegment(clip, health, 0.02, 0.68, 0.82, 0.85),
        absorbs = CreatePredictionSegment(clip, health, 0.30, 0.70, 1.00, 0.82),
        healAbsorbs = CreatePredictionSegment(clip, health, 0.72, 0.04, 0.22, 0.92),
    }
    prediction.segments = {
        prediction.myHeals,
        prediction.otherHeals,
        prediction.absorbs,
        prediction.healAbsorbs,
    }
    local stripes = prediction.absorbs:CreateTexture(nil, "ARTWORK", nil, 3)
    stripes:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    stripes:SetAllPoints(prediction.absorbs.fill)
    prediction.absorbStripes = stripes

    clip:HookScript("OnSizeChanged", function(_, width)
        for _, segment in ipairs(prediction.segments) do
            segment:SetWidth(math.max(1, width))
        end
    end)
    frame.groupPrediction = prediction
    self:LayoutFrame(frame, frame.isMirrored == true)
    return prediction
end

function HealPredictionBehavior:HideFrame(frame)
    local prediction = frame and frame.groupPrediction
    if not prediction then return end
    for _, segment in ipairs(prediction.segments) do
        segment:SetMinMaxValues(0, 1)
        segment:SetValue(0)
        segment:Hide()
    end
end

local function ShowSegment(segment, maximum, value)
    segment:SetMinMaxValues(0, maximum)
    segment:SetValue(value)
    segment:Show()
end

function HealPredictionBehavior:UpdatePreview(frame, kind, options)
    local prediction = frame.groupPrediction
    local index = tonumber(frame.unit and frame.unit:match("%d+")) or 1
    if kind == "party" then
        if index == 3 and options.showPredictions ~= false then
            ShowSegment(prediction.myHeals, 100, 16)
            ShowSegment(prediction.otherHeals, 100, 10)
            ShowSegment(prediction.absorbs, 100, 18)
            ShowSegment(prediction.healAbsorbs, 100, 12)
        end
    elseif index == 15 and options.showPredictions ~= false then
        ShowSegment(prediction.myHeals, 100, 22)
    elseif index == 16 and options.showPredictions ~= false then
        ShowSegment(prediction.myHeals, 100, 0)
        ShowSegment(prediction.otherHeals, 100, 0)
        ShowSegment(prediction.absorbs, 100, 20)
    elseif index == 22 and options.showHealAbsorbs ~= false then
        ShowSegment(prediction.healAbsorbs, 100, 24)
    end
end

function HealPredictionBehavior:UpdateFrame(frame, attachment)
    attachment = attachment or self:GetAttachment(frame)
    if not frame or not attachment then return end
    local prediction = frame.groupPrediction
    local options = attachment.options.getOptions()
    self:HideFrame(frame)
    if not prediction or not options then return end
    if PF.testMode then
        return self:UpdatePreview(frame, attachment.options.kind, options)
    end

    local showHealAbsorbs = options.showHealAbsorbs
    if showHealAbsorbs == nil then showHealAbsorbs = options.showPredictions end
    local exists = UnitExists(frame.unit)
    if not predictionCalculator
        or (options.showPredictions == false and showHealAbsorbs == false)
        or not (PF:IsDisplaySafe(exists) and exists == true) then return end

    UnitGetDetailedHealPrediction(frame.unit, "player", predictionCalculator)
    local healthMax = predictionCalculator:GetMaximumHealth()
    local _, mine, others = predictionCalculator:GetIncomingHeals()
    local absorbs = predictionCalculator:GetDamageAbsorbs()
    local healAbsorbs = predictionCalculator:GetHealAbsorbs()
    if options.showPredictions ~= false then
        ShowSegment(prediction.myHeals, healthMax, mine)
        ShowSegment(prediction.otherHeals, healthMax, others)
        ShowSegment(prediction.absorbs, healthMax, absorbs)
    end
    if showHealAbsorbs ~= false then
        ShowSegment(prediction.healAbsorbs, healthMax, healAbsorbs)
    end
end

function HealPredictionBehavior:GetIncomingHeals(frame, healthMax, testMode)
    if testMode then
        local index = tonumber(frame.unit and frame.unit:match("%d+"))
        local previewHasHeals = (frame.isRaidFrame and index == 15)
            or (frame.isPartyFrame and index == 3)
        return previewHasHeals and healthMax * 0.22 or 0
    end
    local exists = frame and frame.unit and UnitExists(frame.unit)
    if predictionCalculator and PF:IsDisplaySafe(exists) and exists == true then
        UnitGetDetailedHealPrediction(frame.unit, "player", predictionCalculator)
        return predictionCalculator:GetIncomingHeals()
    end
end

function HealPredictionBehavior:RefreshFrame(frame)
    local attachment = self:GetAttachment(frame)
    if attachment then self:UpdateFrame(frame, attachment) end
end

function HealPredictionBehavior:Apply(attachment)
    if not attachment then return end
    self:SyncFrames(attachment)
    for frame in pairs(attachment.frames or {}) do
        self:UpdateFrame(frame, attachment)
    end
end

function HealPredictionBehavior:OnFrameDetached(_, frame)
    self:HideFrame(frame)
end

function HealPredictionBehavior:AddContextMenu(rootDescription, attachment)
    local options = attachment.options.getOptions()
    local function Toggle(key)
        options[key] = options[key] == false
        if PF.DisplayProfileBehavior then
            PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
        end
        self:Refresh(attachment)
    end
    rootDescription:CreateCheckbox("Incoming Heals & Absorbs", function()
        return options.showPredictions ~= false
    end, function() Toggle("showPredictions") end)
    if attachment.options.kind == "raid" then
        rootDescription:CreateCheckbox("Heal Absorbs", function()
            return options.showHealAbsorbs ~= false
        end, function() Toggle("showHealAbsorbs") end)
    end
end

function PF:GetGroupIncomingHeals(frame, healthMax, testMode)
    return HealPredictionBehavior:GetIncomingHeals(frame, healthMax, testMode)
end
