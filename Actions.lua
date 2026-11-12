local _, PF = ...

-- SecureActionButtonTemplate resolves combined modifiers in alt/ctrl/shift
-- order (the order returned by SecureButton_GetModifierPrefix).
PF.ACTION_MODIFIERS = {
    { id = "NONE", label = "None", prefix = "" },
    { id = "SHIFT", label = "Shift", prefix = "shift-" },
    { id = "CTRL", label = "Ctrl", prefix = "ctrl-" },
    { id = "ALT", label = "Alt", prefix = "alt-" },
    { id = "SHIFT_CTRL", label = "Shift + Ctrl", prefix = "ctrl-shift-" },
    { id = "SHIFT_ALT", label = "Shift + Alt", prefix = "alt-shift-" },
    { id = "CTRL_ALT", label = "Ctrl + Alt", prefix = "alt-ctrl-" },
    { id = "SHIFT_CTRL_ALT", label = "Shift + Ctrl + Alt", prefix = "alt-ctrl-shift-" },
}

PF.ACTION_BUTTONS = {
    { id = "LeftButton", label = "Left Click", suffix = "1" },
    { id = "RightButton", label = "Right Click", suffix = "2" },
    { id = "MiddleButton", label = "Middle Click", suffix = "3" },
}
for button = 4, 31 do
    table.insert(PF.ACTION_BUTTONS, {
        id = "Button" .. button,
        label = "Mouse Button " .. button,
        suffix = tostring(button),
    })
end

PF.ACTION_INPUT_TYPES = {
    { id = "mouse", label = "Mouse" },
    { id = "keyboard", label = "Keyboard" },
}

PF.ACTION_TYPES = {
    { id = "target", label = "Target" },
    { id = "focus", label = "Focus" },
    { id = "menu", label = "Menu" },
    { id = "custom", label = "Custom" },
}

PF.ACTION_CATEGORIES = {
    player = "Player", pet = "Pet", target = "Target",
    targettarget = "Target of Target", focus = "Focus",
    boss = "Boss", party = "Party", raid = "Raid",
}

PF.ACTION_BINDING_SOURCES = {
    { id = "prettyframes", label = "PrettyFrames Actions" },
    { id = "external", label = "External / Native Click Casting" },
}

local validModifiers, validButtons, validTypes = {}, {}, {}
local modifierPrefixes, buttonSuffixes = {}, {}
for _, value in ipairs(PF.ACTION_MODIFIERS) do
    validModifiers[value.id], modifierPrefixes[value.id] = true, value.prefix
end
for _, value in ipairs(PF.ACTION_BUTTONS) do
    validButtons[value.id], buttonSuffixes[value.id] = true, value.suffix
end
for _, value in ipairs(PF.ACTION_TYPES) do validTypes[value.id] = true end
local secureCombatSnippet = [[
    if newstate == "combat" then
        self:ClearBindings()
        local attributeCount = self:GetAttribute("prettyframes-action-attribute-count") or 0
        for index = 1, attributeCount do
            local attribute = self:GetAttribute("prettyframes-action-attribute-" .. index)
            if attribute then
                local prepared = self:GetAttribute("prettyframes-" .. attribute)
                local current = self:GetAttribute(attribute)
                if current == nil or current == prepared then
                    self:SetAttribute(attribute, prepared)
                    self:SetAttribute("prettyframes-live-" .. attribute, prepared)
                end
            end
        end
        local enabled = self:GetAttribute("prettyframes-shadow-keyboard-enabled")
        self:SetAttribute("prettyframes-keyboard-enabled", enabled)
        if enabled and self:IsUnderMouse() then
            local keyCount = self:GetAttribute("prettyframes-key-count") or 0
            local target = self:GetAttribute("prettyframes-key-target")
            for index = 1, keyCount do
                local key = self:GetAttribute("prettyframes-key-" .. index)
                local button = self:GetAttribute("prettyframes-key-button-" .. index)
                if key and button and target then
                    self:SetBindingClick(true, key, target, button)
                end
            end
        end
    end
]]

local secureHoverEnterSnippet = [[
    self:ClearBindings()
    if self:GetAttribute("prettyframes-keyboard-enabled") then
        local keyCount = self:GetAttribute("prettyframes-key-count") or 0
        local target = self:GetAttribute("prettyframes-key-target")
        for index = 1, keyCount do
            local key = self:GetAttribute("prettyframes-key-" .. index)
            local button = self:GetAttribute("prettyframes-key-button-" .. index)
            if key and button and target then
                self:SetBindingClick(true, key, target, button)
            end
        end
    end
]]

local secureHoverLeaveSnippet = [[
    self:ClearBindings()
]]

local function CopyAction(action)
    if type(action) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(action) do copy[key] = value end
    return copy
end

local function CopyBinding(binding)
    return {
        input = binding.input,
        modifier = binding.modifier,
        button = binding.button,
        key = binding.key,
        action = binding.action,
        custom = CopyAction(binding.custom),
    }
end

local function CopyProfile(profile)
    local copy = { bindings = {} }
    for _, binding in ipairs(profile.bindings or {}) do
        table.insert(copy.bindings, CopyBinding(binding))
    end
    return copy
end

local function DefaultProfile()
    return { bindings = {
        { input = "mouse", modifier = "NONE", button = "LeftButton", action = "target" },
        { input = "mouse", modifier = "NONE", button = "RightButton", action = "menu" },
    } }
end

local modifierKeys = {
    LSHIFT = true, RSHIFT = true, SHIFT = true,
    LCTRL = true, RCTRL = true, CTRL = true,
    LALT = true, RALT = true, ALT = true,
    LMETA = true, RMETA = true, META = true, UNKNOWN = true,
}

local function ValidKeyboardKey(key)
    return type(key) == "string" and key ~= "" and #key <= 32
        and not key:find("[%c%s]") and not modifierKeys[key:upper()]
end

local function ValidCustom(custom)
    if type(custom) ~= "table" then return nil end
    if custom.kind == "spell" and type(custom.id) == "number" then
        return CopyAction(custom)
    elseif custom.kind == "item" and type(custom.id) == "number" then
        return CopyAction(custom)
    elseif custom.kind == "macro" and (type(custom.index) == "number" or type(custom.name) == "string") then
        return CopyAction(custom)
    end
end

local function SanitizeProfile(profile)
    local clean, used = { bindings = {} }, {}
    for _, binding in ipairs(type(profile) == "table" and type(profile.bindings) == "table" and profile.bindings or {}) do
        local input = binding.input == "keyboard" and "keyboard" or "mouse"
        local modifier = validModifiers[binding.modifier] and binding.modifier or nil
        local button = input == "mouse" and validButtons[binding.button] and binding.button or nil
        local key = input == "keyboard" and ValidKeyboardKey(binding.key) and binding.key:upper() or nil
        local action = validTypes[binding.action] and binding.action or nil
        local bindingKey = modifier and (button or key) and (input .. ":" .. modifier .. ":" .. (button or key))
        if modifier and action and (input == "keyboard" or button) and (not bindingKey or not used[bindingKey]) then
            if bindingKey then used[bindingKey] = true end
            table.insert(clean.bindings, {
                input = input,
                modifier = modifier,
                button = button,
                key = key,
                action = action,
                custom = action == "custom" and ValidCustom(binding.custom) or nil,
            })
        end
    end
    return clean
end

function PF:InitializeActionsDatabase(previous, database)
    local savedProfiles = type(previous.actionProfiles) == "table" and previous.actionProfiles or {}
    database.actionProfiles = {}
    for name, profile in pairs(savedProfiles) do
        if type(name) == "string" and name ~= "" and type(profile) == "table" then
            database.actionProfiles[name] = SanitizeProfile(profile)
        end
    end
    if not database.actionProfiles.Default then
        database.actionProfiles.Default = DefaultProfile()
    end

    database.actionAssignments = {}
    local savedAssignments = type(previous.actionAssignments) == "table" and previous.actionAssignments or {}
    for category in pairs(self.ACTION_CATEGORIES) do
        local profileName = savedAssignments[category]
        database.actionAssignments[category] = type(profileName) == "string"
            and database.actionProfiles[profileName] and profileName or "Default"
    end

    database.actionBindingSources = {}
    local savedSources = type(previous.actionBindingSources) == "table"
        and previous.actionBindingSources or {}
    for category in pairs(self.ACTION_CATEGORIES) do
        database.actionBindingSources[category] = savedSources[category] == "external"
            and "external" or "prettyframes"
    end
end

local function AddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

function PF:GetClickCastingProvider()
    if AddOnLoaded("Clique") or type(_G.Clique) == "table" then
        return "clique", "Clique detected."
    end
    if type(_G.ClickCastFrames) == "table" or type(_G.C_ClickBindings) == "table"
        or _G.ClickBindingFrame then
        return "native", "Native click casting detected."
    end
    return nil, "No external click-casting provider detected."
end

function PF:GetActionBindingSource(category)
    local sources = self.db and self.db.actionBindingSources
    return sources and sources[category] == "external" and "external" or "prettyframes"
end

function PF:SetActionBindingSource(category, source)
    if not self.ACTION_CATEGORIES[category]
        or (source ~= "prettyframes" and source ~= "external") then return false end
    if InCombatLockdown() then
        self.pendingActionSources = self.pendingActionSources or {}
        self.pendingActionSources[category] = source
        self:Print(("%s binding source will change after combat."):format(self.ACTION_CATEGORIES[category]))
        return "pending"
    end
    self.db.actionBindingSources[category] = source
    self:ApplyActionCategory(category)
    return true
end

function PF:ApplyPendingActionSources()
    if InCombatLockdown() or not self.pendingActionSources then return false end
    local pending = self.pendingActionSources
    self.pendingActionSources = nil
    for category, source in pairs(pending) do
        if self.ACTION_CATEGORIES[category] then
            self.db.actionBindingSources[category] = source
        end
    end
    self:ApplyAllActionBindings()
    return true
end

function PF:GetActionProfileNames()
    local names = {}
    for name in pairs(self.db.actionProfiles) do table.insert(names, name) end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return names
end

function PF:GetActionProfile(name)
    return self.db.actionProfiles[name]
end

function PF:IsActionProfileNameAvailable(name, exceptName)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return false end
    return name == exceptName or self.db.actionProfiles[name] == nil
end

function PF:CreateActionProfile(name, sourceName)
    if InCombatLockdown() or not self:IsActionProfileNameAvailable(name) then return false end
    local source = sourceName and self.db.actionProfiles[sourceName]
    self.db.actionProfiles[name] = source and CopyProfile(source) or { bindings = {} }
    return true
end

function PF:RenameActionProfile(oldName, newName)
    if InCombatLockdown() or oldName == "Default" or not self.db.actionProfiles[oldName]
        or not self:IsActionProfileNameAvailable(newName, oldName) then return false end
    if oldName == newName then return true end
    self.db.actionProfiles[newName] = self.db.actionProfiles[oldName]
    self.db.actionProfiles[oldName] = nil
    for category, profileName in pairs(self.db.actionAssignments) do
        if profileName == oldName then self.db.actionAssignments[category] = newName end
    end
    self:ApplyAllActionBindings()
    return true
end

function PF:DeleteActionProfile(name)
    if InCombatLockdown() or name == "Default" or not self.db.actionProfiles[name] then return false end
    self.db.actionProfiles[name] = nil
    for category, profileName in pairs(self.db.actionAssignments) do
        if profileName == name then self.db.actionAssignments[category] = "Default" end
    end
    self:ApplyAllActionBindings()
    return true
end

function PF:AssignActionProfile(category, profileName)
    if InCombatLockdown() or not self.ACTION_CATEGORIES[category]
        or not self.db.actionProfiles[profileName] then return false end
    self.db.actionAssignments[category] = profileName
    self:ApplyActionCategory(category)
    return true
end

function PF:GetActionBindingKey(binding)
    local input = binding.input == "keyboard" and "keyboard" or "mouse"
    return input .. ":" .. binding.modifier .. ":" .. (input == "keyboard" and (binding.key or "") or binding.button)
end

function PF:FindActionBindingConflict(profile, rowIndex, input, modifier, value)
    if not value then return end
    for index, binding in ipairs(profile.bindings) do
        local bindingInput = binding.input == "keyboard" and "keyboard" or "mouse"
        local bindingValue = bindingInput == "keyboard" and binding.key or binding.button
        if index ~= rowIndex and bindingInput == input
            and binding.modifier == modifier and bindingValue == value then
            return index
        end
    end
end

function PF:GetActionKeyboardChord(binding)
    if binding.input ~= "keyboard" or not ValidKeyboardKey(binding.key) then return nil end
    local prefix = modifierPrefixes[binding.modifier]
    return prefix and (prefix:upper() .. binding.key:upper()) or nil
end

local function GetMacroInfoSafe(index)
    if type(index) ~= "number" or not GetMacroInfo then return nil end
    local name, icon, body = GetMacroInfo(index)
    if not name then return nil end
    return name, icon, body or ""
end

function PF:ResolveMacro(custom, updateIdentity)
    if type(custom) ~= "table" then return nil end
    local name, icon, body = GetMacroInfoSafe(custom.index)
    local currentMatches = custom.invalid and body == custom.body
        or not custom.invalid and (name == custom.name or body == custom.body)
    if name and currentMatches then
        if updateIdentity then
            custom.name, custom.body, custom.invalid = name, body, nil
        end
        return custom.index, name, icon, body
    end

    local match
    local maximum = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
    for index = 1, maximum do
        local candidateName, candidateIcon, candidateBody = GetMacroInfoSafe(index)
        local candidateMatches = custom.invalid and candidateBody == custom.body
            or not custom.invalid and (candidateName == custom.name or candidateBody == custom.body)
        if candidateName and candidateMatches then
            if match then return nil end -- ambiguous identities never execute
            match = { index, candidateName, candidateIcon, candidateBody }
        end
    end
    if match and updateIdentity then
        custom.index, custom.name, custom.body, custom.invalid = match[1], match[2], match[4], nil
    elseif not match and updateIdentity then
        -- Once a macro disappears, a later unrelated macro with the same name
        -- is not accepted. An exact-body match can still recover a moved macro.
        custom.invalid = true
    end
    return match and unpack(match)
end

function PF:GetCustomActionDisplay(custom)
    if type(custom) ~= "table" then return "Drop a spell, item, or macro", 134400 end
    if custom.kind == "spell" then
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(custom.id)
        local name = info and info.name or (GetSpellInfo and GetSpellInfo(custom.id)) or custom.name
        local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(custom.id)
            or (GetSpellTexture and GetSpellTexture(custom.id)) or custom.icon
        return name or ("Spell " .. custom.id), icon or 134400
    elseif custom.kind == "item" then
        local name, _, _, _, _, _, _, _, _, icon = GetItemInfo and GetItemInfo(custom.id)
        icon = icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(custom.id))
        return name or custom.name or ("Item " .. custom.id), icon or custom.icon or 134400
    elseif custom.kind == "macro" then
        local _, name, icon = self:ResolveMacro(custom, false)
        return name or (custom.name and (custom.name .. " (missing)") or "Missing macro"), icon or custom.icon or 134400
    end
    return "Invalid action", 134400
end

function PF:ParseCursorAction()
    if not GetCursorInfo then return nil end
    local kind, value, subType, extra = GetCursorInfo()
    if kind == "spell" then
        -- Forever's spellbook cursor retains the legacy fourth return as the
        -- stable spell ID; the second return can be only a spellbook slot.
        local spellID = tonumber(extra) or tonumber(value)
        if spellID then return { kind = "spell", id = spellID } end
    elseif kind == "item" then
        local itemID = tonumber(value)
        if not itemID and type(value) == "string" then itemID = tonumber(value:match("item:(%d+)")) end
        if itemID then return { kind = "item", id = itemID } end
    elseif kind == "macro" then
        local index = tonumber(value)
        local name, icon, body = GetMacroInfoSafe(index)
        if name then return { kind = "macro", index = index, name = name, body = body, icon = icon } end
    elseif kind == "action" and GetActionInfo then
        local actionType, id = GetActionInfo(value)
        if actionType == "spell" and tonumber(id) then
            return { kind = "spell", id = tonumber(id) }
        elseif actionType == "item" then
            local itemID = tonumber(id) or (type(id) == "string" and tonumber(id:match("item:(%d+)")))
            if itemID then return { kind = "item", id = itemID } end
        elseif actionType == "macro" and tonumber(id) then
            local name, icon, body = GetMacroInfoSafe(tonumber(id))
            if name then return { kind = "macro", index = tonumber(id), name = name, body = body, icon = icon } end
        end
    end
    return nil
end

local function AttributeBase(binding, keyboardIndex)
    local prefix = modifierPrefixes[binding.modifier]
    local suffix
    if binding.input == "keyboard" then
        suffix = keyboardIndex and ("-PrettyFramesKey" .. keyboardIndex) or nil
    else
        suffix = buttonSuffixes[binding.button]
    end
    return prefix and suffix and (prefix .. "type" .. suffix), prefix, suffix
end

local function ClearAppliedAttributes(frame)
    for attribute in pairs(frame.prettyFramesActionAttributes or {}) do
        local ownedValue = frame:GetAttribute("prettyframes-live-" .. attribute)
        -- A provider may have replaced an attribute after PrettyFrames set it.
        -- Only erase the live value when it is still exactly the value we own.
        if ownedValue ~= nil and frame:GetAttribute(attribute) == ownedValue then
            frame:SetAttribute(attribute, nil)
        end
        frame:SetAttribute("prettyframes-live-" .. attribute, nil)
        frame:SetAttribute("prettyframes-" .. attribute, nil)
    end
    frame.prettyFramesLiveActionAttributes = {}
    frame.prettyFramesActionAttributes = {}
    local attributeCount = frame:GetAttribute("prettyframes-action-attribute-count") or 0
    for index = 1, attributeCount do
        frame:SetAttribute("prettyframes-action-attribute-" .. index, nil)
    end
    local keyCount = frame:GetAttribute("prettyframes-key-count") or 0
    for index = 1, keyCount do
        frame:SetAttribute("prettyframes-key-" .. index, nil)
        frame:SetAttribute("prettyframes-key-button-" .. index, nil)
    end
    frame:SetAttribute("prettyframes-action-attribute-count", nil)
    frame:SetAttribute("prettyframes-key-count", nil)
end

local function SetActionAttribute(frame, key, value, live)
    frame:SetAttribute("prettyframes-" .. key, value)
    if live then
        local current = frame:GetAttribute(key)
        if current ~= nil and frame.prettyFramesPreviousLiveAttributes
            and frame.prettyFramesPreviousLiveAttributes[key] ~= current then
            frame.prettyFramesActionConflicts[key] = current
            return false
        end
        frame:SetAttribute(key, value)
        frame:SetAttribute("prettyframes-live-" .. key, value)
        frame.prettyFramesLiveActionAttributes[key] = value
    end
    frame.prettyFramesActionAttributes[key] = value
    return true
end

local function FinalizeActionAttributes(frame)
    local names = {}
    for attribute in pairs(frame.prettyFramesActionAttributes) do table.insert(names, attribute) end
    table.sort(names)
    frame:SetAttribute("prettyframes-action-attribute-count", #names)
    for index, attribute in ipairs(names) do
        frame:SetAttribute("prettyframes-action-attribute-" .. index, attribute)
    end
end

local function RefreshHoveredKeyboardBindings(frame, live)
    ClearOverrideBindings(frame)
    if not live or not frame.IsMouseOver or not frame:IsMouseOver() then return end
    local keyCount = frame:GetAttribute("prettyframes-key-count") or 0
    local target = frame:GetName()
    for index = 1, keyCount do
        local key = frame:GetAttribute("prettyframes-key-" .. index)
        local button = frame:GetAttribute("prettyframes-key-button-" .. index)
        if key and button and target then
            SetOverrideBindingClick(frame, true, key, target, button)
        end
    end
end

local function SetExternalFrameRegistration(frame, enabled)
    if enabled then
        if type(_G.ClickCastFrames) == "table" then
            if _G.ClickCastFrames[frame] == nil then
                _G.ClickCastFrames[frame] = true
                frame.prettyFramesClickCastRegistryOwned = true
            end
            return
        end
        local clique = _G.Clique
        if type(clique) == "table" and type(clique.RegisterFrame) == "function" then
            clique:RegisterFrame(frame)
            frame.prettyFramesCliqueRegistrationOwned = true
        end
    else
        if frame.prettyFramesClickCastRegistryOwned and type(_G.ClickCastFrames) == "table"
            and _G.ClickCastFrames[frame] == true then
            _G.ClickCastFrames[frame] = nil
        end
        frame.prettyFramesClickCastRegistryOwned = nil
        local clique = _G.Clique
        if frame.prettyFramesCliqueRegistrationOwned and type(clique) == "table"
            and type(clique.UnregisterFrame) == "function" then
            clique:UnregisterFrame(frame)
        end
        frame.prettyFramesCliqueRegistrationOwned = nil
    end
end

function PF:ApplyActionsToFrame(frame)
    if not frame or not frame.actionCategory then return end
    if InCombatLockdown() then
        self.pendingActionBindings = true
        return false
    end
    ClearOverrideBindings(frame)
    frame.prettyFramesPreviousLiveAttributes = {}
    for attribute in pairs(frame.prettyFramesActionAttributes or {}) do
        local ownedValue = frame:GetAttribute("prettyframes-live-" .. attribute)
        if ownedValue ~= nil then
            frame.prettyFramesPreviousLiveAttributes[attribute] = ownedValue
        end
    end
    ClearAppliedAttributes(frame)
    frame.prettyFramesActionConflicts = {}
    local live = self.db.locked == true and self.testMode ~= true

    if self:GetActionBindingSource(frame.actionCategory) == "external" then
        SetExternalFrameRegistration(frame, true)
        frame:SetAttribute("prettyframes-shadow-keyboard-enabled", nil)
        frame:SetAttribute("prettyframes-keyboard-enabled", nil)
        frame.prettyFramesPreviousLiveAttributes = nil
        return true
    end
    SetExternalFrameRegistration(frame, false)

    local profileName = self.db.actionAssignments[frame.actionCategory] or "Default"
    local profile = self.db.actionProfiles[profileName] or self.db.actionProfiles.Default
    local used = {}
    local keyboardCount = 0
    for _, binding in ipairs(profile.bindings or {}) do
        local keyboardChord = self:GetActionKeyboardChord(binding)
        local keyboardIndex
        if keyboardChord then
            keyboardCount = keyboardCount + 1
            keyboardIndex = keyboardCount
        end
        local key, prefix, suffix = AttributeBase(binding, keyboardIndex)
        local combination = self:GetActionBindingKey(binding)
        if key and not used[combination] then
            used[combination] = true
            if keyboardChord then
                frame:SetAttribute("prettyframes-key-" .. keyboardIndex, keyboardChord)
                frame:SetAttribute("prettyframes-key-button-" .. keyboardIndex, "PrettyFramesKey" .. keyboardIndex)
            end
            if binding.action == "target" then
                SetActionAttribute(frame, key, "target", live)
            elseif binding.action == "focus" then
                SetActionAttribute(frame, key, "focus", live)
            elseif binding.action == "menu" then
                SetActionAttribute(frame, key, "togglemenu", live)
            elseif binding.action == "custom" and binding.custom then
                local custom = binding.custom
                if custom.kind == "spell" then
                    SetActionAttribute(frame, key, "spell", live)
                    SetActionAttribute(frame, prefix .. "spell" .. suffix, custom.id, live)
                elseif custom.kind == "item" then
                    SetActionAttribute(frame, key, "item", live)
                    SetActionAttribute(frame, prefix .. "item" .. suffix, "item:" .. custom.id, live)
                elseif custom.kind == "macro" then
                    local macroIndex = self:ResolveMacro(custom, true)
                    if macroIndex then
                        SetActionAttribute(frame, key, "macro", live)
                        SetActionAttribute(frame, prefix .. "macro" .. suffix, macroIndex, live)
                        if frame.actionCategory == "pet" then
                            -- Forever suppresses a secure Pet-button click when
                            -- its base `unit=pet` token is absent, even though
                            -- macros do not use the button's implicit unit. A
                            -- binding-specific valid unit lets the secure macro
                            -- handler run; the macro's own targeting is intact.
                            SetActionAttribute(frame, prefix .. "unit" .. suffix, "player", live)
                        end
                    end
                end
            end
        end
    end
    FinalizeActionAttributes(frame)
    frame:SetAttribute("prettyframes-key-count", keyboardCount)
    frame:SetAttribute("prettyframes-shadow-keyboard-enabled", keyboardCount > 0)
    frame:SetAttribute("prettyframes-keyboard-enabled", live and keyboardCount > 0 or nil)
    RefreshHoveredKeyboardBindings(frame, live)
    frame.prettyFramesPreviousLiveAttributes = nil
    return true
end

function PF:RegisterActionFrame(frame, category)
    if not frame or not self.ACTION_CATEGORIES[category] then return end
    frame.actionCategory = category
    self.actionFrames[frame] = true
    frame:SetAttribute("prettyframes-key-target", frame:GetName())
    frame:SetAttribute("_onenter", secureHoverEnterSnippet)
    frame:SetAttribute("_onleave", secureHoverLeaveSnippet)
    frame:SetAttribute("_onstate-prettyframescombat", secureCombatSnippet)
    RegisterStateDriver(frame, "prettyframescombat", "[combat] combat; nocombat")
    self:ApplyActionsToFrame(frame)
end

function PF:ApplyActionCategory(category)
    for frame in pairs(self.actionFrames) do
        if frame.actionCategory == category then self:ApplyActionsToFrame(frame) end
    end
end

function PF:ApplyActionProfile(profileName)
    for category, assignedName in pairs(self.db.actionAssignments) do
        if assignedName == profileName then self:ApplyActionCategory(category) end
    end
end

function PF:ApplyAllActionBindings()
    if InCombatLockdown() then
        self.pendingActionBindings = true
        return false
    end
    self.pendingActionBindings = nil
    for frame in pairs(self.actionFrames) do self:ApplyActionsToFrame(frame) end
    return true
end

function PF:DescribeActionBinding(binding)
    local action = binding.action
    if action == "custom" then
        action = self:GetCustomActionDisplay(binding.custom)
    else
        action = action:gsub("^%l", string.upper)
    end
    return action
end

function PF:PrintActionTest(category, modifier, button)
    if self:GetActionBindingSource(category) == "external" then
        local _, status = self:GetClickCastingProvider()
        self:Print(self.ACTION_CATEGORIES[category] .. ": owned by External / Native Click Casting. "
            .. status .. " (simulation only; nothing executed).")
        return
    end
    local conflict = self:GetActionConflictText(category)
    if conflict then self:Print(conflict .. " (simulation only; nothing executed).") end
    local profileName = self.db.actionAssignments[category] or "Default"
    local profile = self.db.actionProfiles[profileName]
    for _, binding in ipairs(profile and profile.bindings or {}) do
        if binding.input ~= "keyboard" and binding.modifier == modifier and binding.button == button then
            self:Print(self.ACTION_CATEGORIES[category] .. " / " .. profileName .. ": "
                .. self:DescribeActionBinding(binding) .. " (simulation only; nothing executed).")
            return binding
        end
    end
    self:Print(self.ACTION_CATEGORIES[category] .. " / " .. profileName .. ": unbound (simulation only).")
end

local function BindingCombinationLabel(binding)
    local modifierValue
    for _, value in ipairs(PF.ACTION_MODIFIERS) do
        if value.id == binding.modifier then modifierValue = value break end
    end
    local buttonValue
    for _, value in ipairs(PF.ACTION_BUTTONS) do
        if value.id == binding.button then buttonValue = value break end
    end
    return ((modifierValue and modifierValue.label ~= "None")
        and (modifierValue.label .. " + ") or "")
        .. (buttonValue and buttonValue.label or binding.button)
end

local nativeModifierFlags = {
    NONE = 0, SHIFT = 1, CTRL = 2, ALT = 4,
    SHIFT_CTRL = 3, SHIFT_ALT = 5, CTRL_ALT = 6, SHIFT_CTRL_ALT = 7,
}

local function NativeBindingConflicts(binding)
    if binding.input == "keyboard" or not C_ClickBindings
        or type(C_ClickBindings.GetBindingType) ~= "function" then return false end
    local modifiers = nativeModifierFlags[binding.modifier]
    if modifiers == nil then return false end
    local ok, bindingType = pcall(C_ClickBindings.GetBindingType, binding.button, modifiers)
    if not ok or not Enum or not Enum.ClickBindingType then return false end
    local types = Enum.ClickBindingType
    if binding.action == "target" or binding.action == "menu" then
        return bindingType ~= types.Interaction
    end
    return bindingType ~= types.None
end

function PF:GetActionConflictText(category)
    if self:GetActionBindingSource(category) ~= "prettyframes" then return end
    local profileName = self.db.actionAssignments[category] or "Default"
    local profile = self.db.actionProfiles[profileName] or self.db.actionProfiles.Default
    for _, binding in ipairs(profile.bindings or {}) do
        if NativeBindingConflicts(binding) then
            return "Conflict: " .. BindingCombinationLabel(binding)
                .. " is already owned by native click casting."
        end
    end
    for frame in pairs(self.actionFrames) do
        if frame.actionCategory == category then
            for _, binding in ipairs(profile.bindings or {}) do
                if binding.input ~= "keyboard" then
                    local attribute = AttributeBase(binding)
                    local current = attribute and frame:GetAttribute(attribute)
                    local owned = attribute and frame:GetAttribute("prettyframes-live-" .. attribute)
                    if current ~= nil and current ~= owned then
                        return "Conflict: " .. BindingCombinationLabel(binding)
                            .. " is already owned by another click-casting provider."
                    end
                end
            end
            for attribute in pairs(frame.prettyFramesActionConflicts or {}) do
                local prefix, suffix = attribute:match("^(.-)type(%d+)$")
                if suffix then
                    local modifier = prefix == "" and ""
                        or prefix:gsub("%-", "+"):gsub("%+$", "") .. "+"
                    local label = suffix == "1" and "Left Click" or suffix == "2" and "Right Click"
                        or suffix == "3" and "Middle Click" or ("Mouse Button " .. suffix)
                    return "Conflict: " .. modifier:gsub("^%l", string.upper) .. label
                        .. " is already owned by another click-casting provider."
                end
            end
        end
    end
end
