--[[-----------------------------------------------------------------------------
EditBox Widget
-------------------------------------------------------------------------------]]

--- @class ClickedAutoFillEditBox : AceGUIEditBox
--- @field public autoCompleteBox Frame
--- @field public SetValues fun(values:ClickedAutoFillEditBoxEntry[])
--- @field public GetValues fun():ClickedAutoFillEditBoxEntry[]
--- @field public SetMaxVisibleValues fun(count:integer)
--- @field public GetMaxVisibleValues fun():integer
--- @field public SetTextHighlight fun(enabled:boolean)
--- @field public HasTextHighlight fun():boolean
--- @field public SetSelectedIndex fun(index:integer)
--- @field public GetSelectedIndex fun():integer

--- @class ClickedAutoFillEditBoxEntry
--- @field public text string
--- @field public icon string|integer

local Type, Version = "ClickedAutoFillEditBox", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
	return
end

local ATTACH_ABOVE = "above"
local ATTACH_BELOW = "below"

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]

local function ScoreMatch(text1, text2)
	local len1 = strlenutf8(text1)
	local len2 = strlenutf8(text2)
	local matrix = {}
	local cost = 1
	local min = math.min

	if len1 == 0 then
		return len2
	elseif len2 == 0 then
		return len1
	elseif text1 == text2 then
		return 0
	end

	for i = 0, len1 do
		matrix[i] = {}
		matrix[i][0] = i
	end

	for j = 0, len2 do
		matrix[0][j] = j
	end

	for i = 1, len1 do
		for j = 1, len2 do
			if text1:byte(i) == text2:byte(j) then
				cost = 0
			end

			matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end

	return matrix[len1][len2]
end

--- Find and sort matches of the input string.
---
--- @param text string
--- @param values ClickedAutoFillEditBoxEntry[]
--- @param count integer
--- @return ClickedAutoFillEditBoxEntry[]
local function FindMatches(text, values, count)
	if text == nil or text == "" or #values == 0 then
		return {}
	end

	local matches = {}
	local result = {}

	for _, value in ipairs(values) do
		table.insert(matches, {
			value = value,
			score = ScoreMatch(text, value.text)
		})
	end

	local function SortFunc(l, r)
		if l.score < r.score then
			return true
		end

		if l.score > r.score then
			return false
		end

		return l.value.text < r.value.text
	end

	table.sort(matches, SortFunc)

	for i, match in ipairs(matches) do
		table.insert(result, match.value)

		-- Only return the first entry if the score is 0 (we have a full match)
		if match.score == 0 then
			break
		end

		-- Only return `count` number of matches
		if i >= count then
			break
		end
	end

	return result
end

--- Check if the auto-complete box is currently visible.
---
--- @param self ClickedAutoFillEditBox
--- @return boolean
local function IsAutoCompleteBoxVisible(self)
	local box = self.autoCompleteBox
	return box:IsShown()
end

--- Get the index of the last visible button.
---
--- @param self ClickedAutoFillEditBox
--- @return integer
local function GetLastVisibleButtonIndex(self)
	for i = #self.buttons, 1, -1 do
		if self.buttons[i]:IsShown() and self.buttons[i]:IsEnabled() then
			return i
		end
	end

	return 0
end

--- Get the currently selected button.
---
--- @param self ClickedAutoFillEditBox
--- @return Button
local function GetSelectedButton(self)
	local selected = self:GetSelectedIndex()

	if selected > 0 and selected <= GetLastVisibleButtonIndex(self) then
		return self.buttons[selected]
	end

	return self.buttons[1]
end

--- Move the cursor in the given direction.
---
--- @param self ClickedAutoFillEditBox
--- @param direction integer
local function MoveCursor(self, direction)
	if IsAutoCompleteBoxVisible(self) then
		local next = self:GetSelectedIndex() + direction
		local last = GetLastVisibleButtonIndex(self)

		if next <= 0 then
			next = last
		elseif next > last then
			next = 1
		end

		self:SetSelectedIndex(next)
	end
end

--- Update the highlight state of the buttons.
---
--- @param self ClickedAutoFillEditBox
local function UpdateHighlight(self)
	for i = 1, #self.buttons do
		self.buttons[i]:UnlockHighlight()
	end

	if self:HasTextHighlight() and GetSelectedButton(self) ~= nil then
		GetSelectedButton(self):LockHighlight()
	end
end

--- Select the specified text.
---
--- @param self ClickedAutoFillEditBox
--- @param button Button?
local function Select(self, button)
	if button == nil then
		return
	end

	local text = button:GetText()

	self.editbox:SetText(text)
	self.editbox:SetCursorPosition(strlen(text))

	self:Fire("OnSelect", text)
	self.originalText = text

	AceGUI:ClearFocus(self)
end

--- Hide the auto-complete box.
---
--- @param self ClickedAutoFillEditBox
local function HideAutoCompleteBox(self)
	if not IsAutoCompleteBoxVisible(self) then
		return
	end

	self.autoCompleteBox:Hide()
end

--- Hide the auto-complete box.
---
--- @param self ClickedAutoFillEditBox
--- @param height integer
--- @return string
local function FindAttachmentPoint(self, height)
	if self.frame:GetBottom() - height <= AUTOCOMPLETE_DEFAULT_Y_OFFSET + 10 then
		return ATTACH_ABOVE
	end

	return ATTACH_BELOW
end

local function CreateButton(self)
	local type = Type .. "Button"
	local num = AceGUI:GetNextWidgetNum(type)

	local button = CreateFrame("Button", type .. num, self.autoCompleteBox, "AutoCompleteButtonTemplate")
	button.obj = self

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("LEFT", 12, 1)
	icon:SetSize(12, 12)
	button.icon = icon

	button:GetFontString():SetPoint("LEFT", 28, 0)
	button:GetFontString():SetHeight(14)

	button:SetScript("OnClick", function()
		HideAutoCompleteBox(self)
		Select(self, button)
	end)

	button:SetScript("OnEnter",function()
		for i, current in ipairs(self.buttons) do
			if button == current then
				self:SetSelectedIndex(i)
				break
			end
		end
	end)

	return button
end

--- comment
---
--- @param self ClickedAutoFillEditBox
--- @param matches ClickedAutoFillEditBoxEntry[]
local function UpdateButtons(self, matches)
	local count = math.min(self:GetMaxVisibleValues(), #matches)

	for i = 1, count do
		local button = self.buttons[i]

		if button == nil then
			button = CreateButton(self)

			self.buttons[i] = button
			button:SetParent(self.autoCompleteBox)
			button:SetFrameLevel(self.autoCompleteBox:GetFrameLevel() + 1)
			button:ClearAllPoints()

			if i == 1 then
				button:SetPoint("TOPRIGHT", 0, -10)
				button:SetPoint("TOPLEFT", 0, -10)
			else
				button:SetPoint("TOPRIGHT", self.buttons[i - 1], "BOTTOMRIGHT", 0, 0)
				button:SetPoint("TOPLEFT", self.buttons[i - 1], "BOTTOMLEFT", 0, 0)
			end
		end

		button:SetText(matches[i].text)

		button.icon:SetTexture(matches[i].icon)
		button.icon:SetTexCoord(0, 1, 0, 1)

		button:Show()
	end

	for i = count + 1, #self.buttons do
		self.buttons[i]:Hide()
	end

	if #matches > self:GetMaxVisibleValues() then
		local button = self.buttons[self:GetMaxVisibleValues()]

		button:SetText("...")
		button:Disable()

		button.icon:SetTexture(nil)
	end
end

--- Update the state of the auto-complete box.
---
--- @param self ClickedAutoFillEditBox
local function Rebuild(self)
	if strlenutf8(self:GetText()) == 0 then
		HideAutoCompleteBox(self)
		return
	end

	local text = self:GetText()
	local box = self.autoCompleteBox

	if self.editbox:GetUTF8CursorPosition() > strlenutf8(text) then
		HideAutoCompleteBox(self)
		return
	end

	local matches = FindMatches(text, self:GetValues(), self:GetMaxVisibleValues() + 1)
	UpdateButtons(self, matches)

	local buttonHeight = self.buttons[1]:GetHeight()
	local baseHeight = 32

	local height = baseHeight + math.max(buttonHeight * math.min(#matches, self:GetMaxVisibleValues()), 14)
	local attachTo = FindAttachmentPoint(self, height)

	if box.attachTo ~= attachTo then
		if attachTo == ATTACH_ABOVE then
			box:ClearAllPoints();
			box:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT")
		elseif attachTo == ATTACH_BELOW then
			box:ClearAllPoints();
			box:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT")
		end

		box.attachTo = attachTo
	end

	if not IsAutoCompleteBoxVisible(self) then
		self.selected = 1
	end

	box:SetHeight(height)
	box:Show()
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function EditBox_OnTabPressed(frame)
	local self = frame.obj

	MoveCursor(self, IsShiftKeyDown() and -1 or 1)
end

local function EditBox_OnArrowPressed(frame)
	local self = frame.obj

	if key == "UP" then
		return MoveCursor(self, -1);
	elseif key == "DOWN" then
		return MoveCursor(self, 1);
	end
end

local function EditBox_OnEnterPressed(frame)
	local self = frame.obj

	if IsAutoCompleteBoxVisible(self) then
		HideAutoCompleteBox(self)
		Select(self, GetSelectedButton(self))
	end

	self.BaseOnTextChanged(frame)
end

local function EditBox_OnTextChanged(frame, userInput)
	local self = frame.obj

	self.BaseOnTextChanged(frame)

	if userInput then
		Rebuild(self)
	end

	UpdateHighlight(self)
end

local function EditBox_OnEscapePressed(frame)
	local self = frame.obj

	if IsAutoCompleteBoxVisible(self) then
		self:SetText(self.originalText)
		HideAutoCompleteBox(self)
	end
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self:BaseOnAcquire()

		self.values = {}
		self.selected = 1
		self.numButtons = 10
		self.originalText = ""
		self.highlight = true

		self:DisableButton(true)
		Rebuild(self)
	end,

	["SetValues"] = function(self, values)
		self.values = values
		Rebuild(self)
	end,

	["GetValues"] = function(self)
		return self.values
	end,

	["SetMaxVisibleValues"] = function(self, count)
		self.numButtons = count
		Rebuild(self)
	end,

	["GetMaxVisibleValues"] = function(self)
		return self.numButtons
	end,

	["SetTextHighlight"] = function(self, enabled)
		self.highlight = enabled
		UpdateHighlight(self)
	end,

	["HasTextHighlight"] = function(self)
		return self.highlight
	end,

	["SetSelectedIndex"] = function(self, index)
		if index <= 0 or index > GetLastVisibleButtonIndex(self) then
			return
		end

		self.selected = index
		UpdateHighlight(self)
	end,

	["GetSelectedIndex"] = function(self)
		return self.selected
	end,

	["ClearFocus"] = function(self)
		if IsAutoCompleteBoxVisible(self) then
			self:SetText(self.originalText)
			HideAutoCompleteBox(self)
		end
	end,

	["SetWidth"] = function(self, width)
		self:BaseSetWidth(width)
		self.autoCompleteBox:SetWidth(width)
	end,

	["SetText"] = function(self, text, isOriginal)
		if isOriginal then
			self.originalText = text
		end

		self:BaseSetText(text)
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local widget = AceGUI:Create("EditBox")
	widget.type = Type
	widget.values = {}
	widget.buttons = {}
	widget.selected = 1
	widget.numButtons = 10
	widget.originalText = ""
	widget.highlight = true

	widget.BaseOnAcquire = widget.OnAcquire
	widget.BaseSetWidth = widget.SetWidth
	widget.BaseSetText = widget.SetText
	widget.BaseOnEnterPressed = widget.editbox:GetScript("OnEnterPressed")
	widget.BaseOnTextChanged = widget.editbox:GetScript("OnTextChanged")

	widget.editbox:SetScript("OnTabPressed", EditBox_OnTabPressed)
	widget.editbox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
	widget.editbox:SetScript("OnTextChanged", EditBox_OnTextChanged)
	widget.editbox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)
	widget.editbox:SetScript("OnArrowPressed", EditBox_OnArrowPressed)
	widget.editbox:SetAltArrowKeyMode(false)

	local box = CreateFrame("Frame", nil, widget.frame, "TooltipBackdropTemplate")
	box:SetFrameStrata("FULLSCREEN_DIALOG")
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	widget.autoCompleteBox = box

	local helpText = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	helpText:SetPoint("BOTTOMLEFT", 28, 10)
	helpText:SetText("Press Tab")

	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
