local _, PF = ...

local WINDOW_WIDTH, WINDOW_HEIGHT = 760, 700
local ROW_WIDTH, ROW_BASE_HEIGHT, ROW_CUSTOM_HEIGHT = 690, 42, 86
local MODIFIER_WIDTH, INPUT_WIDTH, TRIGGER_WIDTH, ACTION_WIDTH = 125, 105, 145, 135

local function SetButtonText(button, text)
    button:SetText(text or "")
    local label = button:GetFontString()
    if label then label:SetJustifyH("LEFT") end
end

local function CreateButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    SetButtonText(button, text)
    return button
end

local function CreateDropdown(parent, width, height, text, title, values, getSelected, onSelect)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(width, height)
    dropdown:SetDefaultText(text or "")
    dropdown:OverrideText(text or "")
    dropdown:SetupMenu(function(_, rootDescription)
        if title then rootDescription:CreateTitle(title) end
        local entries = type(values) == "function" and values() or values
        for _, value in ipairs(entries) do
            rootDescription:CreateRadio(value.label, function(id)
                return getSelected() == id
            end, function(id)
                onSelect(id)
            end, value.id)
        end
    end)
    return dropdown
end

local function FindValue(values, id)
    for _, value in ipairs(values) do
        if value.id == id then return value end
    end
end

local modifierKeyNames = {
    LSHIFT = true, RSHIFT = true, SHIFT = true,
    LCTRL = true, RCTRL = true, CTRL = true,
    LALT = true, RALT = true, ALT = true,
    LMETA = true, RMETA = true, META = true, UNKNOWN = true,
}

local function PressedModifier()
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    local alt = IsAltKeyDown and IsAltKeyDown()
    if shift and ctrl and alt then return "SHIFT_CTRL_ALT" end
    if shift and ctrl then return "SHIFT_CTRL" end
    if shift and alt then return "SHIFT_ALT" end
    if ctrl and alt then return "CTRL_ALT" end
    if shift then return "SHIFT" end
    if ctrl then return "CTRL" end
    if alt then return "ALT" end
    return "NONE"
end

local function KeyboardBindingText(binding)
    local chord = PF:GetActionKeyboardChord(binding)
    if not chord then return "Set key..." end
    local text = GetBindingText and GetBindingText(chord, "KEY_")
    return text and text ~= "" and text or chord
end

local function MarkProfileChanged(profileName)
    PF:ApplyActionProfile(profileName)
    PF:RefreshActionsWindow()
end

local function GetDialogEditBox(dialog)
    return dialog and ((dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox)
end

local function GetDialogData(dialog, data)
    if type(data) == "table" then return data end
    if dialog and type(dialog.prettyFramesData) == "table" then return dialog.prettyFramesData end
    if dialog and type(dialog.data) == "table" then return dialog.data end
    return {}
end

local function PromptName(dialogKey, text, initialText, data)
    local dialog = StaticPopup_Show(dialogKey, text, nil, data)
    if dialog then
        dialog.prettyFramesData = data
    end
    local editBox = GetDialogEditBox(dialog)
    if editBox then
        editBox:SetText(initialText or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end
end

StaticPopupDialogs.PRETTYFRAMES_ACTION_NEW = {
    text = "Enter a name for the new action profile:",
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, whileDead = true,
    hideOnEscape = true, preferredIndex = 3, timeout = 0, maxLetters = 64,
    OnAccept = function(dialog, data)
        local editBox = GetDialogEditBox(dialog)
        data = GetDialogData(dialog, data)
        local name = editBox and editBox:GetText():match("^%s*(.-)%s*$") or ""
        if PF:CreateActionProfile(name) then
            PF:AssignActionProfile(data.category or PF.actionsWindow.category, name)
            PF.actionsWindow.profileName = name
            PF:RefreshActionsWindow()
        else
            PF:Print("that profile name is empty or already in use.")
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        dialog.button1:Click()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

StaticPopupDialogs.PRETTYFRAMES_ACTION_RENAME = {
    text = "Rename action profile %s:",
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, whileDead = true,
    hideOnEscape = true, preferredIndex = 3, timeout = 0, maxLetters = 64,
    OnAccept = function(dialog, data)
        local editBox = GetDialogEditBox(dialog)
        data = GetDialogData(dialog, data)
        local name = editBox and editBox:GetText():match("^%s*(.-)%s*$") or ""
        if PF:RenameActionProfile(data.oldName or PF.actionsWindow.profileName, name) then
            PF.actionsWindow.profileName = name
            PF:RefreshActionsWindow()
        else
            PF:Print("Default cannot be renamed, or that name is already in use.")
        end
    end,
    EditBoxOnEnterPressed = function(editBox) editBox:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

StaticPopupDialogs.PRETTYFRAMES_ACTION_DUPLICATE = {
    text = "Name the copy of %s:",
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, whileDead = true,
    hideOnEscape = true, preferredIndex = 3, timeout = 0, maxLetters = 64,
    OnAccept = function(dialog, data)
        local editBox = GetDialogEditBox(dialog)
        data = GetDialogData(dialog, data)
        local name = editBox and editBox:GetText():match("^%s*(.-)%s*$") or ""
        if PF:CreateActionProfile(name, data.sourceName or PF.actionsWindow.profileName) then
            PF:AssignActionProfile(data.category or PF.actionsWindow.category, name)
            PF.actionsWindow.profileName = name
            PF:RefreshActionsWindow()
        else
            PF:Print("that profile name is empty or already in use.")
        end
    end,
    EditBoxOnEnterPressed = function(editBox) editBox:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}

StaticPopupDialogs.PRETTYFRAMES_ACTION_DELETE = {
    text = "Delete action profile %s? Frames using it will be assigned to Default.",
    button1 = DELETE, button2 = CANCEL, whileDead = true, showAlert = true,
    hideOnEscape = true, preferredIndex = 3, timeout = 0,
    OnAccept = function(dialog, data)
        data = GetDialogData(dialog, data)
        if PF:DeleteActionProfile(data.name) then
            PF.actionsWindow.profileName = PF.db.actionAssignments[data.category] or "Default"
            PF:RefreshActionsWindow()
        end
    end,
}

local function ShowCustomTooltip(slot, custom)
    if not custom then return end
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    if custom.kind == "spell" then
        if GameTooltip.SetSpellByID then
            -- Request the client's normal spell subtext, then backfill the
            -- tooltip title for Forever builds that ignore that argument.
            GameTooltip:SetSpellByID(custom.id, false, true)
            local subtext = PF:GetSpellSubtext(custom.id)
            local tooltipName = GameTooltip.GetName and GameTooltip:GetName()
            local title = tooltipName and _G[tooltipName .. "TextLeft1"]
            local titleRight = tooltipName and _G[tooltipName .. "TextRight1"]
            local titleText = title and title:GetText()
            local titleRightText = titleRight and titleRight:GetText()
            local hasSubtext = subtext and ((titleText and titleText:find(subtext, 1, true))
                or (titleRightText and titleRightText:find(subtext, 1, true)))
            if subtext and titleText and not hasSubtext then
                title:SetText(titleText .. " (" .. subtext .. ")")
            end
        end
    elseif custom.kind == "item" then
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(custom.id)
        else
            GameTooltip:SetHyperlink("item:" .. custom.id)
        end
    elseif custom.kind == "macro" then
        local _, name, _, body = PF:ResolveMacro(custom, false)
        GameTooltip:SetText(name or "Missing macro", 1, 0.82, 0.2)
        if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, true) end
        GameTooltip:AddLine("Macros keep their normal targeting behavior.", 0.65, 0.8, 1, true)
    end
    GameTooltip:Show()
end

local function ReceiveCustomAction(profileName, binding)
    if InCombatLockdown() then return end
    local custom = PF:ParseCursorAction()
    if not custom then
        PF:Print("drop a spell, action-bar spell, bag item, or Blizzard macro here.")
        return
    end
    binding.custom = custom
    ClearCursor()
    MarkProfileChanged(profileName)
end

local function CreateActionSlot(row, profileName, binding)
    local slot = CreateFrame("Button", nil, row, "BackdropTemplate")
    slot:SetSize(420, 36)
    slot:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -43)
    slot:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    slot:SetBackdropColor(0.035, 0.025, 0.015, 1)
    slot:SetBackdropBorderColor(unpack(PF.colors.bronze))
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(32, 32)
    slot.icon:SetPoint("LEFT", 2, 0)
    slot.icon:SetTexture(134400)
    slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slot.text:SetPoint("LEFT", slot.icon, "RIGHT", 8, 0)
    slot.text:SetPoint("RIGHT", -8, 0)
    slot.text:SetJustifyH("LEFT")

    local name, icon = PF:GetCustomActionDisplay(binding.custom)
    slot.text:SetText(name)
    slot.icon:SetTexture(icon)
    slot:SetScript("OnReceiveDrag", function() ReceiveCustomAction(profileName, binding) end)
    slot:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            binding.custom = nil
            MarkProfileChanged(profileName)
        elseif GetCursorInfo and GetCursorInfo() then
            ReceiveCustomAction(profileName, binding)
        end
    end)
    slot:SetScript("OnEnter", function(self) ShowCustomTooltip(self, binding.custom) end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", slot, "RIGHT", 10, 0)
    hint:SetText("Drop to set • Right-click to clear")
    return slot
end

local function SelectBindingValue(window, profileName, profile, index, field, value)
    local binding = profile.bindings[index]
    if not binding then return end
    if field == "input" or field == "modifier" or field == "button" or field == "key" then
        local input = field == "input" and value or (binding.input == "keyboard" and "keyboard" or "mouse")
        local modifier = field == "modifier" and value or binding.modifier
        local bindingValue
        if input == "keyboard" then
            bindingValue = field == "key" and value or binding.key
        else
            bindingValue = field == "button" and value or binding.button or "LeftButton"
        end
        local conflict = PF:FindActionBindingConflict(profile, index, input, modifier, bindingValue)
        if conflict then
            window.message:SetText("Conflict: that modifier and "
                .. (input == "keyboard" and "key" or "mouse button")
                .. " are already used by row " .. conflict .. ".")
            window.message:SetTextColor(1, 0.28, 0.2)
            return
        end
    end
    binding[field] = value
    if field == "input" and value == "mouse" and not binding.button then
        binding.button = "LeftButton"
    end
    if field == "action" and value ~= "custom" then binding.custom = nil end
    MarkProfileChanged(profileName)
end


local function CreateKeyCaptureButton(row, window, profileName, profile, index, binding)
    local button = CreateButton(row, TRIGGER_WIDTH, 25, KeyboardBindingText(binding))
    local capturing, deadline

    local function StopCapture()
        local wasCapturing = capturing
        -- Forever can leave keyboard propagation disabled after a capture.
        -- Restore it on the next frame so the key just captured stays consumed.
        button:EnableKeyboard(false)
        button:SetScript("OnKeyDown", nil)
        if wasCapturing and button.SetPropagateKeyboardInput and C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not InCombatLockdown() then button:SetPropagateKeyboardInput(true) end
            end)
        end
        if window.activeKeyCapture == StopCapture then
            window.activeKeyCapture = nil
        end
        if not wasCapturing then return end
        capturing = nil
        deadline = nil
        button:SetScript("OnUpdate", nil)
        SetButtonText(button, KeyboardBindingText(binding))
    end

    local function UpdateCapture(self)
        local remaining = math.ceil((deadline or 0) - GetTime())
        if remaining <= 0 then
            StopCapture()
        else
            SetButtonText(self, "Press a key... " .. remaining)
        end
    end

    local function CaptureKey(self, key)
        if not capturing or type(key) ~= "string" then
            if self.SetPropagateKeyboardInput and not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
            return
        end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        key = key:upper()
        if modifierKeyNames[key] then return end

        local modifier = PressedModifier()
        local conflict = PF:FindActionBindingConflict(profile, index, "keyboard", modifier, key)
        if conflict then
            StopCapture()
            window.message:SetText("Conflict: that modifier and key are already used by row " .. conflict .. ".")
            window.message:SetTextColor(1, 0.28, 0.2)
            return
        end

        StopCapture()
        binding.modifier = modifier
        binding.key = key
        MarkProfileChanged(profileName)
    end

    -- Setting OnKeyDown enables keyboard ownership on this client, so keep
    -- both the handler and keyboard input absent until capture actually starts.
    if button.SetPropagateKeyboardInput and not InCombatLockdown() then
        button:SetPropagateKeyboardInput(true)
    end
    button:EnableKeyboard(false)
    button:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        if window.activeKeyCapture and window.activeKeyCapture ~= StopCapture then
            window.activeKeyCapture()
        end
        capturing = true
        deadline = GetTime() + 5
        window.activeKeyCapture = StopCapture
        self:SetScript("OnKeyDown", CaptureKey)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        self:SetScript("OnUpdate", UpdateCapture)
        UpdateCapture(self)
    end)
    row:HookScript("OnHide", StopCapture)
    return button
end

local function GetActionDropIndex(window)
    local rows = window.actionRows or {}
    if #rows == 0 then return 1 end
    local _, cursorY = GetCursorPosition()
    local scale = window.content:GetEffectiveScale()
    cursorY = cursorY / (scale > 0 and scale or 1)
    for index, actionRow in ipairs(rows) do
        local top, bottom = actionRow:GetTop(), actionRow:GetBottom()
        if top and bottom and cursorY > (top + bottom) / 2 then
            return index
        end
    end
    return #rows + 1
end

local function ShowActionDropIndicator(window, dropIndex)
    local rows = window.actionRows or {}
    local indicator = window.actionDropIndicator
    indicator:ClearAllPoints()
    if rows[dropIndex] then
        indicator:SetPoint("CENTER", rows[dropIndex], "TOP", 0, 0)
    elseif rows[#rows] then
        indicator:SetPoint("CENTER", rows[#rows], "BOTTOM", 0, 0)
    else
        indicator:SetPoint("TOP", window.content, "TOP", 0, 0)
    end
    indicator:Show()
end

local function CreateRow(window, profileName, profile, index, binding, y)
    local custom = binding.action == "custom"
    local height = custom and ROW_CUSTOM_HEIGHT or ROW_BASE_HEIGHT
    local row = CreateFrame("Frame", nil, window.content, "BackdropTemplate")
    row:SetSize(ROW_WIDTH, height)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    row:SetBackdropColor(0.08, 0.05, 0.025, 0.92)
    row:SetBackdropBorderColor(0.34, 0.2, 0.08, 1)
    window.actionRows[index] = row

    local modifierValue = FindValue(PF.ACTION_MODIFIERS, binding.modifier)
    local modifier = CreateDropdown(
        row, MODIFIER_WIDTH, 25, modifierValue and modifierValue.label, "Modifier", PF.ACTION_MODIFIERS,
        function() return binding.modifier end,
        function(value) SelectBindingValue(window, profileName, profile, index, "modifier", value) end
    )
    modifier:SetPoint("TOPLEFT", 34, -8)

    local inputID = binding.input == "keyboard" and "keyboard" or "mouse"
    local inputValue = FindValue(PF.ACTION_INPUT_TYPES, inputID)
    local input = CreateDropdown(
        row, INPUT_WIDTH, 25, inputValue and inputValue.label, "Input", PF.ACTION_INPUT_TYPES,
        function() return inputID end,
        function(value) SelectBindingValue(window, profileName, profile, index, "input", value) end
    )
    input:SetPoint("LEFT", modifier, "RIGHT", 8, 0)

    local trigger
    if inputID == "keyboard" then
        trigger = CreateKeyCaptureButton(row, window, profileName, profile, index, binding)
    else
        local buttonValue = FindValue(PF.ACTION_BUTTONS, binding.button)
        trigger = CreateDropdown(
            row, TRIGGER_WIDTH, 25, buttonValue and buttonValue.label, "Mouse Button", PF.ACTION_BUTTONS,
            function() return binding.button end,
            function(value) SelectBindingValue(window, profileName, profile, index, "button", value) end
        )
    end
    trigger:SetPoint("LEFT", input, "RIGHT", 8, 0)

    local actionValue = FindValue(PF.ACTION_TYPES, binding.action)
    local action = CreateDropdown(
        row, ACTION_WIDTH, 25, actionValue and actionValue.label, "Action", PF.ACTION_TYPES,
        function() return binding.action end,
        function(value) SelectBindingValue(window, profileName, profile, index, "action", value) end
    )
    action:SetPoint("LEFT", trigger, "RIGHT", 8, 0)

    local trash = CreateButton(row, 34, 25, "×")
    trash:SetPoint("RIGHT", -10, 0)
    trash:SetScript("OnClick", function()
        table.remove(profile.bindings, index)
        MarkProfileChanged(profileName)
    end)
    trash:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove binding")
        GameTooltip:Show()
    end)
    trash:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The grip is a generated, hand-painted asset rather than a font glyph;
    -- Forever's UI font does not contain the usual drag-handle character.
    local handle = CreateFrame("Button", nil, row)
    handle:SetSize(22, 25)
    handle:SetPoint("TOPLEFT", 5, -8)
    handle:RegisterForDrag("LeftButton")
    local grip = handle:CreateTexture(nil, "ARTWORK")
    grip:SetTexture("Interface\\AddOns\\PrettyFrames\\Themes\\Shared\\Assets\\ActionDragGrip")
    grip:SetSize(20, 20)
    grip:SetPoint("CENTER")
    local function SetGripHighlight(highlighted)
        if highlighted then
            grip:SetVertexColor(1, 1, 1, 1)
        else
            grip:SetVertexColor(0.68, 0.62, 0.52, 1)
        end
    end
    SetGripHighlight(false)
    local dragging

    local function StopDrag(reorder)
        if not dragging then return end
        dragging = nil
        handle:SetScript("OnUpdate", nil)
        SetGripHighlight(handle:IsMouseOver())
        row:SetAlpha(1)
        window.actionDropIndicator:Hide()
        if not reorder then return end

        local sourceIndex
        for bindingIndex, candidate in ipairs(profile.bindings) do
            if candidate == binding then
                sourceIndex = bindingIndex
                break
            end
        end
        if not sourceIndex then return end
        local destinationIndex = GetActionDropIndex(window)
        if destinationIndex > sourceIndex then destinationIndex = destinationIndex - 1 end
        destinationIndex = math.max(1, math.min(destinationIndex, #profile.bindings))
        if destinationIndex == sourceIndex then return end

        table.remove(profile.bindings, sourceIndex)
        table.insert(profile.bindings, destinationIndex, binding)
        MarkProfileChanged(profileName)
    end

    handle:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if window.activeKeyCapture then window.activeKeyCapture() end
        dragging = true
        SetGripHighlight(true)
        row:SetAlpha(0.55)
        self:SetScript("OnUpdate", function()
            ShowActionDropIndicator(window, GetActionDropIndex(window))
        end)
        ShowActionDropIndicator(window, GetActionDropIndex(window))
    end)
    handle:SetScript("OnDragStop", function() StopDrag(true) end)
    handle:SetScript("OnEnter", function(self)
        SetGripHighlight(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to reorder")
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function()
        if not dragging then SetGripHighlight(false) end
        GameTooltip:Hide()
    end)
    row:HookScript("OnHide", function() StopDrag(false) end)

    if custom then CreateActionSlot(row, profileName, binding) end
    return height
end

local function NextFreeCombination(profile)
    local used = {}
    for _, binding in ipairs(profile.bindings) do used[PF:GetActionBindingKey(binding)] = true end
    for _, modifier in ipairs(PF.ACTION_MODIFIERS) do
        for _, button in ipairs(PF.ACTION_BUTTONS) do
            if not used["mouse:" .. modifier.id .. ":" .. button.id] then
                return modifier.id, button.id
            end
        end
    end
end

function PF:CreateActionsWindow()
    if self.actionsWindow then return self.actionsWindow end
    local window = CreateFrame("Frame", "PrettyFramesActionsWindow", UIParent, "BackdropTemplate")
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })

    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.title:SetPoint("TOPLEFT", 22, -18)
    window.title:SetText("PrettyFrames Actions")
    local close = CreateButton(window, 32, 24, "×")
    close:SetPoint("TOPRIGHT", -15, -14)
    close:SetScript("OnClick", function() window:Hide() end)

    window.assignment = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.assignment:SetPoint("TOPLEFT", 22, -50)

    local sourceLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceLabel:SetPoint("TOPLEFT", 22, -79)
    sourceLabel:SetText("Binding Source")
    window.sourceButton = CreateDropdown(
        window, 260, 26, "", "Binding Source", PF.ACTION_BINDING_SOURCES,
        function() return PF:GetActionBindingSource(window.category) end,
        function(source)
            if PF:SetActionBindingSource(window.category, source) then
                PF:RefreshActionsWindow()
            end
        end
    )
    window.sourceButton:SetPoint("TOPLEFT", 126, -72)

    window.providerStatus = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.providerStatus:SetPoint("TOPLEFT", 126, -103)

    local profileLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", 22, -134)
    profileLabel:SetText("Profile")

    window.profileButton = CreateDropdown(
        window, 210, 26, "", "Assign Profile",
        function()
            local values = {}
            for _, name in ipairs(PF:GetActionProfileNames()) do
                table.insert(values, { id = name, label = name })
            end
            return values
        end,
        function() return window.profileName end,
        function(name)
            if PF:AssignActionProfile(window.category, name) then
                window.profileName = name
                PF:RefreshActionsWindow()
            end
        end
    )
    window.profileButton:SetPoint("TOPLEFT", 78, -127)

    window.newButton = CreateButton(window, 70, 26, "New")
    window.newButton:SetPoint("LEFT", window.profileButton, "RIGHT", 8, 0)
    window.newButton:SetScript("OnClick", function()
        PromptName("PRETTYFRAMES_ACTION_NEW", nil, "", { category = window.category })
    end)
    window.renameButton = CreateButton(window, 75, 26, "Rename")
    window.renameButton:SetPoint("LEFT", window.newButton, "RIGHT", 5, 0)
    window.renameButton:SetScript("OnClick", function()
        PromptName("PRETTYFRAMES_ACTION_RENAME", window.profileName, window.profileName,
            { oldName = window.profileName })
    end)
    window.duplicateButton = CreateButton(window, 80, 26, "Duplicate")
    window.duplicateButton:SetPoint("LEFT", window.renameButton, "RIGHT", 5, 0)
    window.duplicateButton:SetScript("OnClick", function()
        PromptName("PRETTYFRAMES_ACTION_DUPLICATE", window.profileName, window.profileName .. " Copy",
            { sourceName = window.profileName, category = window.category })
    end)
    window.deleteButton = CreateButton(window, 70, 26, "Delete")
    window.deleteButton:SetPoint("LEFT", window.duplicateButton, "RIGHT", 5, 0)
    window.deleteButton:SetScript("OnClick", function()
        if window.profileName == "Default" then
            PF:Print("the Default action profile cannot be deleted.")
            return
        end
        StaticPopup_Show("PRETTYFRAMES_ACTION_DELETE", window.profileName, nil,
            { name = window.profileName, category = window.category })
    end)

    local header = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", 37, -167)
    header:SetText("MODIFIER                 INPUT               BUTTON / KEY                    ACTION")

    window.scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    window.scroll:SetPoint("TOPLEFT", 22, -183)
    window.scroll:SetPoint("BOTTOMRIGHT", -42, 58)
    window.content = CreateFrame("Frame", nil, window.scroll)
    window.content:SetSize(ROW_WIDTH, 1)
    window.scroll:SetScrollChild(window.content)
    window.actionDropIndicator = window.content:CreateTexture(nil, "OVERLAY")
    window.actionDropIndicator:SetColorTexture(1, 0.72, 0.18, 1)
    window.actionDropIndicator:SetSize(ROW_WIDTH - 4, 3)
    window.actionDropIndicator:Hide()

    window.message = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.message:SetPoint("BOTTOMLEFT", 24, 28)
    window.message:SetPoint("BOTTOMRIGHT", -24, 28)
    window.message:SetJustifyH("LEFT")
    window:Hide()
    self.actionsWindow = window
    return window
end

function PF:RefreshActionsWindow()
    local window = self.actionsWindow
    if not window or not window:IsShown() then return end
    local profile = self.db.actionProfiles[window.profileName]
    if not profile then
        window.profileName = self.db.actionAssignments[window.category] or "Default"
        profile = self.db.actionProfiles[window.profileName]
    end
    local source = self:GetActionBindingSource(window.category)
    if source == "external" then
        window.assignment:SetText((self.ACTION_CATEGORIES[window.category] or window.category)
            .. " frames defer click bindings to the external/native provider.")
    else
        window.assignment:SetText((self.ACTION_CATEGORIES[window.category] or window.category)
            .. " frames use this profile. Shared-profile edits apply everywhere it is assigned.")
    end
    local sourceValue = FindValue(self.ACTION_BINDING_SOURCES, source)
    window.sourceButton:OverrideText(sourceValue and sourceValue.label or source)
    local _, providerStatus = self:GetClickCastingProvider()
    window.providerStatus:SetText(providerStatus)
    window.providerStatus:SetTextColor(source == "external" and 1 or 0.65,
        source == "external" and 0.82 or 0.72, source == "external" and 0.3 or 0.65)
    window.profileButton:OverrideText(window.profileName)
    window.renameButton:SetEnabled(window.profileName ~= "Default")
    window.deleteButton:SetEnabled(window.profileName ~= "Default")
    local conflict = self:GetActionConflictText(window.category)
    if conflict then
        window.message:SetText(conflict)
        window.message:SetTextColor(1, 0.28, 0.2)
    elseif source == "external" then
        window.message:SetText("PrettyFrames attributes are cleared; configure bindings in the selected provider's UI.")
        window.message:SetTextColor(0.95, 0.74, 0.3)
    else
        window.message:SetText("Changes apply immediately. Keyboard actions work while hovering a unit frame.")
        window.message:SetTextColor(0.75, 0.8, 0.68)
    end

    for _, child in ipairs({ window.content:GetChildren() }) do child:Hide(); child:SetParent(nil) end
    window.actionRows = {}
    window.actionDropIndicator:Hide()
    local y = 0
    for index, binding in ipairs(profile.bindings) do
        y = y + CreateRow(window, window.profileName, profile, index, binding, y) + 6
    end
    local plus = CreateButton(window.content, 38, 27, "+")
    plus:SetPoint("TOPLEFT", 0, -y)
    plus:SetScript("OnClick", function()
        local modifier, button = NextFreeCombination(profile)
        if not modifier then
            window.message:SetText("All supported modifier and mouse-button combinations are already assigned.")
            window.message:SetTextColor(1, 0.28, 0.2)
            return
        end
        table.insert(profile.bindings, {
            input = "mouse", modifier = modifier, button = button, action = "target",
        })
        MarkProfileChanged(window.profileName)
    end)
    local plusHint = plus:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plusHint:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    plusHint:SetText("Add binding • Drag the grip to reorder")
    window.content:SetHeight(math.max(1, y + 35))
end

function PF:OpenActionsWindow(category)
    if InCombatLockdown() then
        self:Print("actions cannot be configured during combat.")
        return
    end
    if self.db.locked then
        self:Print("enable PrettyFrames Edit Mode before configuring actions.")
        return
    end
    if not self.ACTION_CATEGORIES[category] then return end
    local window = self:CreateActionsWindow()
    window.category = category
    window.profileName = self.db.actionAssignments[category] or "Default"
    window:Show()
    window:Raise()
    self:RefreshActionsWindow()
end
