local _, PF = ...

local SetPartyRole = PF.Widgets.SetPartyRole
local SetRaidMarkerTexture = PF.Widgets.SetRaidMarkerTexture
local raidTestNames = PF.Widgets.raidTestNames

local function SetBarValue(bar, current, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(current)
end

local function UnitColor(unit)
    local isPlayer = UnitIsPlayer(unit)
    if PF:IsDisplaySafe(isPlayer) and isPlayer == true then
        local _, class = UnitClass(unit)
        local color = PF:IsDisplaySafe(class) and class and RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end
    local r, g, b = PF.HealthTextBehavior:ResolveReactionColor(unit)
    if r then return r, g, b end
    return unpack(PF.colors.health)
end
local function SetUnitNameToFit(frame, name, surname)
    local text = frame.nameText
    if not text then return end

    -- Never let a surname wrap into the health bar. Forever's native fitting
    -- path scales the complete string only when its bounded name region needs
    -- it, preserving the configured font size for ordinary names.
    if text.SetMaxLines then text:SetMaxLines(1) end
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end

    if surname then
        if PF:IsDisplaySafe(name) and PF:IsDisplaySafe(surname) then
            local fullName = surname ~= "" and (name .. " " .. surname) or name
            if text.SetTextToFit then
                text:SetTextToFit(fullName)
            else
                text:SetText(fullName)
            end
        else
            -- Protected identity values cannot be joined in addon Lua. Keep
            -- the secure formatter and rely on the one-line bounded region.
            if text.SetTextScale then text:SetTextScale(1) end
            text:SetFormattedText("%s %s", name, surname)
        end
    elseif text.SetTextToFit then
        text:SetTextToFit(name)
    else
        text:SetText(name)
    end
end

function PF:ClearUnitFrameData(frame)
    if frame.nameText then frame.nameText:SetText("") end
    if frame.healthText then frame.healthText:SetText("") end
    if frame.isRaidFrame then
        frame.raidHealthTextHasValue = false
    end
    if frame.powerText then frame.powerText:SetText("") end
    if frame.statusText and not frame.isPartyFrame and not frame.isRaidFrame then
        frame.statusText:SetText("")
    end
    if frame.levelText then frame.levelText:SetText("") end
    if frame.unitMarker and not frame.isPartyFrame and not frame.isRaidFrame then
        SetRaidMarkerTexture(frame.unitMarker)
    end
    if frame.health then
        frame.health:SetMinMaxValues(0, 1)
        frame.health:SetValue(0)
        if self.HealthTextBehavior then
            self.HealthTextBehavior:ApplyBar(
                frame, 0, 1, self.colors.health, false
            )
        else
            frame.health:SetStatusBarColor(unpack(self.colors.health))
        end
    end
    if frame.power then
        frame.power:SetMinMaxValues(0, 1)
        frame.power:SetValue(0)
        if self.PowerBarBehavior then
            self.PowerBarBehavior:ClearFrame(frame)
        else
            frame.power:SetStatusBarColor(unpack(self.colors.power))
        end
    end

    if frame.classIndicator then
        frame.classIndicator:SetAlpha(0)
    end
    if frame.roleIndicator and not frame.isPartyFrame and not frame.isRaidFrame then
        SetPartyRole(frame.roleIndicator, "NONE")
        frame.roleIndicator:SetAlpha(0)
    end

    if frame.oneBarSkinTexture and not self.PowerBarBehavior then
        local setting = frame.settingKey and self:GetFrameSetting(frame.settingKey)
        local showPower = not (setting and setting.forceOneBar)
        frame.skin:SetAlpha(showPower and 1 or 0)
        frame.oneBarSkin:SetAlpha(showPower and 0 or 1)
        if frame.power then frame.power:SetShown(showPower) end
        if frame.power and frame.power.background then
            frame.power.background:SetShown(showPower)
        end
        if frame.powerText then frame.powerText:SetShown(showPower) end
        if frame.ApplyPowerLayout then
            frame:ApplyPowerLayout(showPower)
        end
    end

    if frame.portrait then
        self.PortraitBehavior:ClearFrame(frame)
    end

    for _, auraFrame in ipairs(frame.auras or {}) do
        auraFrame:SetAlpha(0)
    end
    for _, auraFrame in ipairs(frame.debuffs or {}) do
        auraFrame:SetAlpha(0)
    end
    for _, holder in ipairs({ frame.nativeBuffs, frame.nativeDebuffs, frame.nativeMaintenance }) do
        if holder and holder.container and holder.container.prettyFramesEnabled then
            holder.container:SetEnabled(false)
            holder.container.prettyFramesEnabled = false
        end
    end

    if frame.isRaidFrame then
        self:UpdateRaidPresentation(frame, false, tonumber(frame.unit and frame.unit:match("%d+")) or 1, false, false)
    elseif frame.isPartyFrame and self.UpdatePartyPresentation then
        self:UpdatePartyPresentation(frame, false, tonumber(frame.unit and frame.unit:match("%d+")) or 1)
    end
end

function PF:UpdateUnitFramePower(frame)
    if not frame or not frame.power or not frame.unit then return end
    local exists = UnitExists(frame.unit)
    if not (self:IsDisplaySafe(exists) and exists == true) then return end

    local powerType = UnitPowerType(frame.unit)
    local power = UnitPower(frame.unit, powerType)
    local powerMax = UnitPowerMax(frame.unit, powerType)
    SetBarValue(frame.power, power, powerMax)
    if self.PowerBarBehavior then
        self.PowerBarBehavior:UpdateFrame(frame, power, powerMax, powerType)
    else
        frame.power:SetStatusBarColor(unpack(self.colors.power))
        if frame.powerText then
            local currentText = self:FormatNumber(power)
            local maxText = self:FormatNumber(powerMax)
            if currentText and maxText then
                frame.powerText:SetText(currentText .. " / " .. maxText)
            else
                frame.powerText:SetFormattedText("%s / %s", power, powerMax)
            end
        end
    end
end

function PF:UpdateUnitFrameHealth(frame)
    if not frame or not frame.health or not frame.unit then return end
    local exists = UnitExists(frame.unit)
    if not (self:IsDisplaySafe(exists) and exists == true) then
        self:ClearUnitFrameData(frame)
        self.FrameBehaviors:RefreshFrame(frame)
        return
    end

    local health = UnitHealth(frame.unit)
    local healthMax = UnitHealthMax(frame.unit)
    local r, g, b = UnitColor(frame.unit)
    local dead = UnitIsDeadOrGhost(frame.unit)
    dead = self:IsDisplaySafe(dead) and dead == true
    SetBarValue(frame.health, health, healthMax)
    frame.health:SetStatusBarColor(r, g, b)
    if self.HealthTextBehavior then
        self.HealthTextBehavior:UpdateFrame(
            frame, health, healthMax, { r, g, b }, dead
        )
    elseif frame.healthText then
        local currentText = self:FormatNumber(health)
        local maxText = self:FormatNumber(healthMax)
        if currentText and maxText then
            frame.healthText:SetText(currentText .. " / " .. maxText)
        else
            frame.healthText:SetFormattedText("%s / %s", health, healthMax)
        end
    end
    if self.HealPredictionBehavior then
        self.HealPredictionBehavior:RefreshFrame(frame)
    end
end

function PF:UpdateUnitFrame(frame, updateModel)
    if frame.isBossFrame and self.db and self.db.replaceBossFrames ~= true then
        self:ClearUnitFrameData(frame)
        return
    end
    local unit = frame.unit
    local exists = UnitExists(unit)
    local previewIndex = tonumber(unit:match("%d+")) or 1
    local previewLimit = unit:find("raid") and 22 or (unit:find("^boss") and 5 or 4)
    local testPreview = self.testMode
        and (unit == "player" or unit == "target" or unit == "focus" or previewIndex <= previewLimit)
    if not exists and not testPreview then
        self:ClearUnitFrameData(frame)
        self.FrameBehaviors:RefreshFrame(frame)
        return
    end

    local name, surname, health, healthMax, powerType, power, powerMax
    if exists then
        -- Forever uses UnitName's second return for a character surname.  On
        -- clients without surnames this remains nil (or is the remote realm).
        name, surname = UnitName(unit)
        health = UnitHealth(unit)
        healthMax = UnitHealthMax(unit)
        powerType = UnitPowerType(unit)
        power = UnitPower(unit, powerType)
        powerMax = UnitPowerMax(unit, powerType)
    else
        if unit:find("raid") then
            name = raidTestNames[previewIndex] or "Raid Member " .. previewIndex
        elseif unit:find("^boss") then
            local bossTestNames = { "The Verdant Warden", "Ashmaw", "High Sage Lyris", "The Hollow King", "Dreadwing" }
            name = bossTestNames[previewIndex] or "Boss " .. previewIndex
        else
            name = unit:gsub("^%l", string.upper)
        end
        health = 78 - previewIndex * 3
        healthMax = 100
        powerType = 0
        power = 67
        powerMax = 100
    end
    local r, g, b
    if exists then
        r, g, b = UnitColor(unit)
    else
        if unit:find("^boss") then
            r, g, b = 0.72, 0.12, 0.10
        else
            r, g, b = 0.24, 0.64, 0.12
        end
    end

    SetBarValue(frame.health, health, healthMax)
    frame.health:SetStatusBarColor(r, g, b)
    SetUnitNameToFit(frame, name, surname)

    if frame.classIndicator then
        local classFile
        if exists then
            local isPlayer = UnitIsPlayer(unit)
            if self:IsDisplaySafe(isPlayer) and isPlayer == true then
                _, classFile = UnitClass(unit)
            end
        elseif testPreview then
            _, classFile = UnitClass("player")
        end
        if not self:IsDisplaySafe(classFile) then
            classFile = nil
        end
        local coordinates = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if coordinates then
            frame.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            frame.classIcon:SetTexCoord(coordinates[1], coordinates[2], coordinates[3], coordinates[4])
            frame.classIndicator:SetAlpha(1)
        elseif frame.isBossFrame then
            local classification = exists and UnitClassification and UnitClassification(unit)
            if testPreview or (self:IsDisplaySafe(classification)
                and (classification == "worldboss" or classification == "elite"
                    or classification == "rareelite")) then
                frame.classIcon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
                frame.classIcon:SetTexCoord(0, 1, 0, 1)
                frame.classIndicator:SetAlpha(1)
            else
                frame.classIndicator:SetAlpha(0)
            end
        else
            frame.classIndicator:SetAlpha(0)
        end
    end

    if frame.roleIndicator and not frame.isPartyFrame and not frame.isRaidFrame then
        frame.roleIndicator:SetAlpha(1)
        local role = "NONE"
        if exists and UnitGroupRolesAssigned then
            role = UnitGroupRolesAssigned(unit)
        elseif testPreview then
            local previewRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER" }
            role = previewRoles[previewIndex] or "DAMAGER"
        end
        if not self:IsDisplaySafe(role) then
            role = "NONE"
        end
        SetPartyRole(frame.roleIndicator, role)
    end

    if frame.power then
        SetBarValue(frame.power, power, powerMax)
        if self.PowerBarBehavior then
            self.PowerBarBehavior:UpdateFrame(frame, power, powerMax, powerType)
        else
            local color = PF.colors.power
            frame.power:SetStatusBarColor(color[1], color[2], color[3])
        end
    end

    local connected = exists and UnitIsConnected(unit)
    local dead = exists and UnitIsDeadOrGhost(unit)
    local afk = exists and UnitIsAFK and UnitIsAFK(unit)
    local disconnected = self:IsDisplaySafe(connected) and connected == false
    dead = self:IsDisplaySafe(dead) and dead == true
    afk = self:IsDisplaySafe(afk) and afk == true
    if not frame.isPartyFrame and not frame.isRaidFrame then
        local function SetStatusText(text)
            frame.statusText:SetText(text)
        end
        if disconnected then
            SetStatusText("OFFLINE")
        elseif dead then
            local ghost = UnitIsGhost(unit)
            SetStatusText(self:IsDisplaySafe(ghost) and ghost and "GHOST" or "DEAD")
            frame.health:SetStatusBarColor(unpack(self.colors.dead))
        elseif afk then
            SetStatusText("AFK")
        else
            SetStatusText("")
        end
    end

    if frame.levelText then
        local level = exists and UnitLevel(unit)
        if not exists then
            level = 60
        end
        if self:IsDisplaySafe(level) then
            frame.levelText:SetText(level > 0 and level or "??")
        else
            frame.levelText:SetText("")
        end
    end

    if self.HealthTextBehavior then
        self.HealthTextBehavior:UpdateFrame(
            frame, health, healthMax, { r, g, b }, dead
        )
    elseif frame.healthText then
            local currentText = self:FormatNumber(health)
            local maxText = self:FormatNumber(healthMax)
            if currentText and maxText then
                frame.healthText:SetText(currentText .. " / " .. maxText)
            else
                -- FontString's native formatter accepts Forever's protected values;
                -- Lua string.format/tostring and arithmetic intentionally do not.
                frame.healthText:SetFormattedText("%s / %s", health, healthMax)
            end
    end
    if frame.powerText and not self.PowerBarBehavior then
        local currentText = self:FormatNumber(power)
        local maxText = self:FormatNumber(powerMax)
        if currentText and maxText then
            frame.powerText:SetText(currentText .. " / " .. maxText)
        else
            frame.powerText:SetFormattedText("%s / %s", power, powerMax)
        end
    end

    if frame.unitMarker and not frame.isRaidFrame and not frame.isPartyFrame then
        local markerIndex = exists and GetRaidTargetIndex and GetRaidTargetIndex(unit)
        local markerIsSecret = issecretvalue and issecretvalue(markerIndex)
        if not markerIsSecret and not markerIndex and testPreview then
            if unit == "target" then
                markerIndex = 8
            elseif unit == "focus" then
                markerIndex = 1
            elseif unit:find("^boss") and previewIndex == 1 then
                markerIndex = 8
            elseif unit:find("^party") and previewIndex == 1 then
                markerIndex = 6
            end
        end
        SetRaidMarkerTexture(frame.unitMarker, markerIndex)
    end

    if frame.isRaidFrame then
        self:UpdateRaidPresentation(frame, exists, previewIndex, disconnected, dead)
    elseif frame.isPartyFrame and self.UpdatePartyPresentation then
        self:UpdatePartyPresentation(frame, exists, previewIndex)
    end
    if frame.portrait and updateModel then
        self.PortraitBehavior:UpdateFrame(frame, exists, testPreview, true)
    end

    self:UpdateAuras(frame)
    self.FrameBehaviors:RefreshFrame(frame)
end
