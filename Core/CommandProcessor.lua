Clicked.COMMAND_ACTION_TARGET = "target"
Clicked.COMMAND_ACTION_MENU = "menu"
Clicked.COMMAND_ACTION_MACRO = "macro"

local macroFrameHandlers = {}

local function GetCommandAttributeIdentifier(command, isClickCastCommand)
	-- separate modifiers from the actual binding
	local prefix, suffix = command.keybind:match("^(.-)([^%-]+)$")
	local buttonIndex = suffix:match("^BUTTON(%d+)$")

	-- convert the parts to lowercase so it fits the attribute naming style
	prefix = prefix:lower()
	suffix = suffix:lower()

	if buttonIndex ~= nil and isClickCastCommand then
		suffix = buttonIndex
	elseif buttonIndex ~= nil then
		suffix = "clicked-mouse-" .. tostring(prefix) .. tostring(buttonIndex)
		prefix = ""
	else
		suffix = "clicked-button-" .. tostring(prefix) .. tostring(suffix)
		prefix = ""
	end

	return prefix, suffix
end

local function GetFrame(index)
	if index > #macroFrameHandlers then
		frame = CreateFrame("Button", "ClickedMacroFrameHandler" .. index, UIParent, "SecureActionButtonTemplate")
		table.insert(macroFrameHandlers, frame)
	end

	return macroFrameHandlers[index]
end

-- Note: This is a secure function and may not be called during combat
function Clicked:ProcessCommands(commands)
	if InCombatLockdown() then
		return
	end

	local newClickCastFrameKeybindings = {}
	local newClickCastFrameAttributes = {}
	local nextMacroFrameHandler = 1

	for _, command in ipairs(commands) do
		local isClickCastCommand = self:StartsWith(command.keybind, "BUTTON")
		local prefix, suffix = GetCommandAttributeIdentifier(command, isClickCastCommand)

		if isClickCastCommand then
			self:CreateCommandAttributes(newClickCastFrameAttributes, command, prefix, suffix)
		end

		if not self:IsRestrictedKeybind(command.keybind) then
			if command.action == self.COMMAND_ACTION_TARGET or command.action == self.COMMAND_ACTION_MENU then
				self:CreateCommandAttributes(newClickCastFrameAttributes, command, prefix, suffix)
				table.insert(newClickCastFrameKeybindings, { key = command.keybind, identifier = suffix })
			else
				local frame = GetFrame(nextMacroFrameHandler)
				local attributes = {}

				nextMacroFrameHandler = nextMacroFrameHandler + 1
				-- TODO: add CreateCommandAttributes(attributes, command, prefix, suffix) when mouseover (frame) is supported
				self:CreateCommandAttributes(attributes, command, "", "")
				self:SetPendingFrameAttributes(frame, attributes)
				self:ApplyAttributesToFrame(frame)

				ClearOverrideBindings(frame)
				-- TODO: add SetOverrideBindingClick(frame, false, command.keybind, frame:GetName(), suffix) when mouseover (frame) is supported
				SetOverrideBindingClick(frame, true, command.keybind, frame:GetName())
			end
		end
	end

	self:UpdateClickCastHeader(newClickCastFrameKeybindings)
	self:UpdateClickCastFrames(newClickCastFrameAttributes)

	for i = nextMacroFrameHandler, #macroFrameHandlers do
		local frame = macroFrameHandlers[i]

		self:ApplyAttributesToFrame(frame)

		ClearOverrideBindings(frame)
	end
end
