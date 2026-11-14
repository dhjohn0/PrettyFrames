local _, PF = ...

local ThreatBehavior = {
    autoAttach = { unitFrame = "AttachUnitFrame", groupFrame = true },
    contextMenuOrder = 85,
    contextMenuGroup = { key = "threat", title = "Threat" },
}
PF.ThreatBehavior = PF.FrameBehaviors:Register("threat", ThreatBehavior)

function ThreatBehavior:ValidateAttachment(_, options)
    assert(options.kind == "unit" or options.kind == "party" or options.kind == "raid",
        "threat behavior requires a unit, party, or raid kind")
    if options.kind == "unit" then
        assert(type(options.getSetting) == "function",
            "unit threat behavior requires getSetting")
    else
        assert(type(options.getOptions) == "function",
            "group threat behavior requires getOptions")
    end
end

function ThreatBehavior:AttachUnitFrame(frame, settingKey)
    if not frame or not frame.hasThreatDisplay or not settingKey then return end
    return PF.FrameBehaviors:Attach("threat", frame, {
        kind = "unit",
        contextMenuScope = "move",
        getSetting = function() return PF:GetFrameSetting(settingKey) end,
    })
end

local function SetTargetThreatColor(frame, status)
    if status >= 2 then
        frame.threatGlow.texture:SetVertexColor(1.00, 0.10, 0.04)
        frame.threatGlow.texture:SetAlpha(0.82)
        frame.threatText:SetTextColor(1.00, 0.25, 0.12)
    elseif status == 1 then
        frame.threatGlow.texture:SetVertexColor(1.00, 0.48, 0.06)
        frame.threatGlow.texture:SetAlpha(0.64)
        frame.threatText:SetTextColor(1.00, 0.62, 0.08)
    else
        frame.threatGlow.texture:SetVertexColor(1.00, 0.88, 0.16)
        frame.threatGlow.texture:SetAlpha(0.16)
        frame.threatText:SetTextColor(1.00, 0.90, 0.28)
    end
end

local function ReadTargetThreat(sourceUnit, targetUnit)
    local status, scaledPercentage, rawPercentage
    if UnitDetailedThreatSituation then
        local _
        _, status, scaledPercentage, rawPercentage =
            UnitDetailedThreatSituation(sourceUnit, targetUnit)
    elseif UnitThreatSituation then
        status = UnitThreatSituation(sourceUnit, targetUnit)
    end

    -- Detailed numeric values are protected more aggressively than the
    -- coarse threat state. Prefer the readable state when Forever exposes it
    -- so bosses still retain the yellow/orange/red fallback.
    local detailedStatusIsSecret = issecretvalue and issecretvalue(status)
    if UnitThreatSituation and (detailedStatusIsSecret or status == nil) then
        local situation = UnitThreatSituation(sourceUnit, targetUnit)
        if PF:IsDisplaySafe(situation) then status = situation end
    end
    return status, scaledPercentage, rawPercentage
end

function ThreatBehavior:UpdateUnitFrame(frame, exists, preview)
    if not frame or not frame.hasThreatDisplay then return end
    local attachment = self:GetAttachment(frame)
    local setting = attachment and attachment.options.getSetting()
        or (frame.settingKey and PF:GetFrameSetting(frame.settingKey))
    if not setting then return end

    if exists == nil then exists = UnitExists(frame.unit) end
    if preview == nil then preview = PF.testMode == true end
    frame.threatGlow:Hide()
    frame.threatText:Hide()
    frame.threatText:SetTextColor(1.00, 0.90, 0.28)

    local status, scaledPercentage, rawPercentage
    local petStatus, petScaledPercentage, petRawPercentage
    if preview then
        if frame.unit == "focus" then
            status, scaledPercentage, rawPercentage = 3, 100, 100
        else
            status, scaledPercentage, rawPercentage = 1, 86, 105
        end
        if setting.showPetThreat and frame.unit == "target" then
            petStatus, petScaledPercentage, petRawPercentage = 2, 100, 100
        end
    elseif exists then
        status, scaledPercentage, rawPercentage = ReadTargetThreat("player", frame.unit)
        if setting.showPetThreat and UnitExists("pet") then
            petStatus, petScaledPercentage, petRawPercentage =
                ReadTargetThreat("pet", frame.unit)
        end
    else
        return
    end

    local usingPet = false
    if setting.showPetThreat and PF:IsDisplaySafe(petStatus) then
        if not PF:IsDisplaySafe(status) or petStatus > status then
            usingPet = true
        elseif petStatus == status
            and PF:IsDisplaySafe(petScaledPercentage)
            and PF:IsDisplaySafe(scaledPercentage)
            and petScaledPercentage > scaledPercentage then
            usingPet = true
        end
    end
    if usingPet then
        status = petStatus
        scaledPercentage = petScaledPercentage
        rawPercentage = petRawPercentage
    end

    local statusIsSecret = issecretvalue and issecretvalue(status)
    if not statusIsSecret and status == nil then return end

    if setting.showThreatGlow ~= false and not statusIsSecret then
        SetTargetThreatColor(frame, status)
        if status == 0 and PF:IsDisplaySafe(scaledPercentage) then
            local progress = math.max(0, math.min(1, scaledPercentage / 50))
            frame.threatGlow.texture:SetAlpha(0.08 + progress * 0.38)
        end
        frame.threatGlow:Show()
    end

    local mode = setting.threatTextMode
    if mode == "none" then return end
    local percentage = mode == "raw" and rawPercentage or scaledPercentage
    local percentageIsSecret = issecretvalue and issecretvalue(percentage)
    if not percentageIsSecret and percentage == nil then return end

    if usingPet then
        -- Preserve the pet label even at 100%, where the player display uses
        -- the shorter AGGRO state instead of a number.
        frame.threatText:SetFormattedText("Pet: %.0f%%", percentage)
    elseif mode == "aggro" and not statusIsSecret and status >= 2 then
        frame.threatText:SetText("AGGRO")
    else
        -- Forever permits protected threat values to flow directly into a
        -- FontString, but addon Lua must not compare or perform math on them.
        frame.threatText:SetFormattedText("%.0f%%", percentage)
    end
    if not statusIsSecret then SetTargetThreatColor(frame, status) end
    frame.threatText:Show()
end

function ThreatBehavior:Apply(attachment)
    if not attachment then return end
    local kind = attachment.options.kind
    if kind == "unit" then
        self:UpdateUnitFrame(attachment.subject)
    elseif kind == "party" then
        PF:RefreshPartyFrames(false)
    elseif kind == "raid" then
        PF:RefreshRaidFrames()
    end
end

function ThreatBehavior:RefreshFrame(frame)
    local attachment = self:GetAttachment(frame)
    if attachment and attachment.options.kind == "unit" then
        self:UpdateUnitFrame(frame)
    end
end

function ThreatBehavior:AddContextMenu(rootDescription, attachment)
    local kind = attachment.options.kind
    if kind == "unit" then
        local setting = attachment.options.getSetting()
        rootDescription:CreateCheckbox("Portrait Glow", function()
            return setting.showThreatGlow ~= false
        end, function()
            setting.showThreatGlow = setting.showThreatGlow == false
            self:Refresh(attachment)
        end)
        rootDescription:CreateCheckbox("Include Pet Threat", function()
            return setting.showPetThreat == true
        end, function()
            setting.showPetThreat = setting.showPetThreat ~= true
            self:Refresh(attachment)
        end)
        local function IsTextMode(value) return setting.threatTextMode == value end
        local function SetTextMode(value)
            setting.threatTextMode = value
            self:Refresh(attachment)
        end
        rootDescription:CreateTitle("Threat Text")
        rootDescription:CreateRadio("None", IsTextMode, SetTextMode, "none")
        rootDescription:CreateRadio("Aggro %", IsTextMode, SetTextMode, "aggro")
        rootDescription:CreateRadio("Raw %", IsTextMode, SetTextMode, "raw")
        return
    end

    local options = attachment.options.getOptions()
    rootDescription:CreateCheckbox("Threat Warning", function()
        return options.showThreat ~= false
    end, function()
        options.showThreat = options.showThreat == false
        if PF.DisplayProfileBehavior then
            PF.DisplayProfileBehavior:MarkCustom(attachment.subject)
        end
        self:Refresh(attachment)
    end)
end

function PF:UpdateTargetThreat(frame, exists, preview)
    return ThreatBehavior:UpdateUnitFrame(frame, exists, preview)
end

function PF:RefreshTargetThreatDisplays()
    for _, key in ipairs({ "target", "focus" }) do
        local frame = self.frames and self.frames[key]
        if frame then ThreatBehavior:UpdateUnitFrame(frame) end
    end
end
