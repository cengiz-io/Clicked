--[[-----------------------------------------------------------------------------
Clicked Keybinding Widget
Set Keybindings in the Config UI.
-------------------------------------------------------------------------------]]
local Type, Version = "ClickedKeybinding", 2
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- WoW APIs
local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMetaKeyDown = IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMetaKeyDown

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function UpdateText(frame)
	local key = frame.key
	local hasMarker = frame.hasMarker
	local button = frame.button

	if (key or "") == "" then
		button:SetText(NOT_BOUND)
		button:SetNormalFontObject("GameFontNormal")
	else
		button:SetText(hasMarker and (key .. "*") or key)
		button:SetNormalFontObject("GameFontHighlight")
	end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Keybinding_OnClick(frame, button)
	if button == "LeftButton" then
		local self = frame.obj
		local passed = GetTime() - (self.lastClickTime or 0)

		if not self.waitingForKey and passed > 0.01 then
			frame:EnableKeyboard(true)
			frame:EnableMouseWheel(true)
			frame:LockHighlight()
			self.waitingForKey = true
		end
	end
	AceGUI:ClearFocus()
end

local ignoreKeys = {
	["UNKNOWN"] = true,
	["LSHIFT"] = true, ["LCTRL"] = true, ["LALT"] = true, ["LMETA"] = true,
	["RSHIFT"] = true, ["RCTRL"] = true, ["RALT"] = true, ["RMETA"] = true
}

local function Keybinding_OnKeyDown(frame, key)
	local self = frame.obj

	if self.waitingForKey then
		local keyPressed = key

		if keyPressed == "ESCAPE" then
			keyPressed = ""
		else
			if ignoreKeys[keyPressed] then
				return
			end

			if IsMetaKeyDown ~= nil and IsMetaKeyDown() then
				keyPressed = "META-" .. keyPressed
			end

			if IsShiftKeyDown() then
				keyPressed = "SHIFT-" .. keyPressed
			end

			if IsControlKeyDown() then
				keyPressed = "CTRL-" .. keyPressed
			end

			if IsAltKeyDown() then
				keyPressed = "ALT-" .. keyPressed
			end
		end

		frame:EnableKeyboard(false)
		frame:EnableMouseWheel(false)
		frame:UnlockHighlight()
		self.waitingForKey = nil
		self.lastClickTime = GetTime()

		if not self.disabled then
			self:SetKey(keyPressed)
			self:Fire("OnKeyChanged", keyPressed)
		end
	end
end

local function Keybinding_OnMouseDown(frame, button)
	if button == "LeftButton" then
		button = "BUTTON1"
	elseif button == "RightButton" then
        button = "BUTTON2"
    elseif button == "MiddleButton" then
		button = "BUTTON3"
	elseif string.match(button, "Button%d") then
		button = string.upper(button)
	end

	Keybinding_OnKeyDown(frame, button)
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]

local methods = {
	["OnAcquire"] = function(self)
		self:OriginalOnAcquire()
		self.key = ""
		self.hasMarker = false
	end,

	["SetKey"] = function(self, key)
		self.key = key
		UpdateText(self)
	end,

	["GetKey"] = function(self)
		return self.key
	end,

	["SetMarker"] = function(self, marker)
		self.hasMarker = marker
		UpdateText(self)
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]

local function Constructor()
	local widget = AceGUI:Create("Keybinding")
	widget.type = Type

	local button = widget.button
	button:SetScript("OnClick", Keybinding_OnClick)
	button:SetScript("OnKeyDown", Keybinding_OnKeyDown)
	button:SetScript("OnMouseDown", Keybinding_OnMouseDown)

	widget.OriginalOnAcquire = widget.OnAcquire

	for method, func in pairs(methods) do
		widget[method] = func
	end

	return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
