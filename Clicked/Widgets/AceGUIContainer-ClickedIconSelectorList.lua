--[[-----------------------------------------------------------------------------
ScrollFrame Container
Plain container that scrolls its content and doesn't grow in height.
-------------------------------------------------------------------------------]]

--- @class ClickedIconSelectorList : AceGUIContainer
--- @field public SetScroll fun(value:number)
--- @field public MoveScroll fun(value:number)
--- @field public SetSearchHandler fun(handler)
--- @field public SetIcons fun(icons:table<string,string>, order:string[])
--- @field public RefreshIcons fun()
--- @field public FixScroll fun()

--- @class ClickedInternal
local _, Addon = ...

local Type, Version = "ClickedIconSelectorList", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
	return
end

local ICON_SIZE = 32

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function FixScrollOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	frame.obj:FixScroll()
end

local function LoadIconsOverTime(frame)
	local self = frame.obj
	local status = self.status or self.localstatus

	if #self.loadQueue == 0 then
		return
	end

	for _ = 1, math.min(status.numColumns * 9, #self.loadQueue) do
		local next = self.loadQueue[1]
		table.remove(self.loadQueue, 1)

		local button = next.button

		button:SetCallback("OnEnter", function()
			Addon:ShowTooltip(button.frame, next.icon .. "\n" .. next.id)
		end)

		button:SetCallback("OnLeave", function()
			Addon:HideTooltip()
		end)

		button:SetCallback("OnClick", function()
			self:Fire("OnIconSelected", next.icon)
		end)

		button:SetImage(next.icon)
		button.frame:Show()
	end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function ScrollFrame_OnMouseWheel(frame, value)
	frame.obj:MoveScroll(value)
end

local function ScrollFrame_OnSizeChanged(frame)
	frame:SetScript("OnUpdate", FixScrollOnUpdate)
end

local function ScrollBar_OnScrollValueChanged(frame, value)
	frame.obj:SetScroll(value)
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self:SetScroll(0)
		self.scrollframe:SetScript("OnUpdate", FixScrollOnUpdate)
		self.iconLoader:SetScript("OnUpdate", LoadIconsOverTime)
	end,

	["OnRelease"] = function(self)
		self.status = nil

		if self.searchHandler ~= nil then
			self.searchHandler:SetCallback("SearchTermChanged", nil)
		end

		self.searchHandler = nil

		for k in pairs(self.localstatus) do
			self.localstatus[k] = nil
		end

		self.buttons = {}
		self.icons = {}
		self.order = {}
		self.loadQueue = {}
		self.scrollframe:SetPoint("BOTTOMRIGHT")
		self.scrollbar:Hide()
		self.iconLoader:SetScript("OnUpdate", nil)
		self.scrollBarShown = nil
		self.content.height, self.content.width, self.content.original_width = nil, nil, nil
	end,

	["SetScroll"] = function(self, value)
		local status = self.status or self.localstatus
		value = math.floor(value)

		if value ~= status.scrollvalue then
			status.scrollvalue = value
			self:RefreshIcons()
		end
	end,

	["MoveScroll"] = function(self, value)
		local status = self.status or self.localstatus
		local height, viewheight = self.scrollframe:GetHeight(), status.contentHeight

		if self.scrollBarShown then
			local diff = height - viewheight
			local delta = 1
			if value < 0 then
				delta = -1
			end

			self.scrollbar:SetValue(math.min(math.max(status.scrollvalue + delta * (1000 / (diff / 45)), 0), math.ceil(status.numRows / 2)))
		end
	end,

	["SetSearchHandler"] = function(self, handler)
		if handler == self.searchHandler then
			return
		end

		if self.searchHandler ~= nil then
			self.searchHandler:SetCallback("SearchTermChanged", nil)
		end

		self.searchHandler = handler
		self.searchHandler:SetCallback("SearchTermChanged", function()
			self:RefreshIcons()
		end)

		self:RefreshIcons()
	end,

	["SetIcons"] = function(self, icons, order)
		self.icons = icons
		self.order = order

		self:FixScroll()
		self.scrollframe:SetScript("OnUpdate", FixScrollOnUpdate)
	end,

	["RefreshIcons"] = function(self)
		for _, v in ipairs(self.buttons) do
			v.frame:Hide()
		end

		if self.icons == nil or #self.order == 0 then
			return
		end

		if self.content.width == nil or self.content.width < ICON_SIZE then
			return
		end

		local icons = {}
		local order = {}

		if self.searchHandler ~= nil and #self.searchHandler.searchTerm > 0 then
			local searchTerm = string.gsub(string.lower(self.searchHandler.searchTerm), "%s+", "_")

			for k, v in pairs(self.icons) do
				local id = tostring(k)
				local name = string.lower(self.icons[k])

				if string.match(name, searchTerm) or string.match(id, searchTerm) then
					icons[k] = v
					table.insert(order, k)
				end
			end

			table.sort(order)
		else
			icons = self.icons
			order = self.order
		end

		local status = self.status or self.localstatus
		local viewHeight = self.scrollframe:GetHeight()
		local viewRows = math.floor(viewHeight / (ICON_SIZE + 4))

		status.numColumns = math.floor(self.content.width / (ICON_SIZE + 4))
		status.numRows = math.max(math.ceil(#order / status.numColumns) - viewRows, 0)
		status.contentHeight = math.floor(status.numRows * (ICON_SIZE + 4))

		local numIcons = viewRows * status.numColumns
		local offset = (status.scrollvalue * 2) * status.numColumns

		self.loadQueue = {}

		for i = 1, numIcons do
			local button = self.buttons[i]

			if button == nil then
				button = AceGUI:Create("Icon")
				button:SetImageSize(ICON_SIZE, ICON_SIZE)
				button:SetWidth(ICON_SIZE + 4)
				button:SetHeight(ICON_SIZE)

				self.buttons[i] = button

				self:AddChild(button)
			end

			if order[offset + i] ~= nil then
				table.insert(self.loadQueue, {
					button = button,
					id = order[offset + i],
					icon = "Interface\\ICONS\\" .. icons[order[offset + i]]
				})
			end
		end

		self.scrollbar:SetMinMaxValues(0, math.ceil(status.numRows / 2))
	end,

	["FixScroll"] = function(self)
		if self.updateLock then
			return
		end

		self.updateLock = true

		if not self.scrollBarShown then
			self.scrollBarShown = true
			self.scrollbar:Show()
			self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
			if self.content.original_width then
				self.content.width = self.content.original_width - 20
			end
			self:DoLayout()
		end

		self:RefreshIcons()

		local status = self.status or self.localstatus

		self.scrollbar:SetValue(status.scrollvalue)
		self:SetScroll(status.scrollvalue)

		self.updateLock = nil
	end,

	["LayoutFinished"] = function(self, _, height)
		self.content:SetHeight(height or 20)

		-- update the scrollframe
		self:FixScroll()

		-- schedule another update when everything has "settled"
		self.scrollframe:SetScript("OnUpdate", FixScrollOnUpdate)
	end,

	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		if not status.scrollvalue then
			status.scrollvalue = 0
		end
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		content.width = width - (self.scrollBarShown and 20 or 0)
		content.original_width = width
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		content.height = height
	end
}
--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	local num = AceGUI:GetNextWidgetNum(Type)

	local scrollframe = CreateFrame("ScrollFrame", nil, frame)
	scrollframe:SetPoint("TOPLEFT")
	scrollframe:SetPoint("BOTTOMRIGHT")
	scrollframe:EnableMouseWheel(true)
	scrollframe:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel)
	scrollframe:SetScript("OnSizeChanged", ScrollFrame_OnSizeChanged)

	local scrollbar = CreateFrame("Slider", ("AceConfigDialogScrollFrame%dScrollBar"):format(num), scrollframe, "UIPanelScrollBarTemplate")
	scrollbar:SetPoint("TOPLEFT", scrollframe, "TOPRIGHT", 4, -16)
	scrollbar:SetPoint("BOTTOMLEFT", scrollframe, "BOTTOMRIGHT", 4, 16)
	scrollbar:SetMinMaxValues(0, 1000)
	scrollbar:SetValueStep(1)
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)
	scrollbar:Hide()
	-- set the script as the last step, so it doesn't fire yet
	scrollbar:SetScript("OnValueChanged", ScrollBar_OnScrollValueChanged)

	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetColorTexture(0, 0, 0, 0.4)

	--Container Support
	local content = CreateFrame("Frame", nil, scrollframe)
	content:SetPoint("TOPLEFT")
	content:SetPoint("TOPRIGHT")
	content:SetHeight(400)

	local iconLoader = CreateFrame("Frame", nil, UIParent)

	-- Respect ElvUI skinning
	if GetAddOnEnableState(UnitName("player"), "ElvUI") == 2 then
		local E = unpack(ElvUI);

		if E and E.private.skins and E.private.skins.ace3Enable then
			local S = E:GetModule("Skins")
			S:HandleScrollBar(scrollbar)
		end
	end

	local widget = {
		localstatus   = { scrollvalue = 0, contentHeight = 0 },
		scrollframe   = scrollframe,
		buttons       = {},
		icons         = {},
		order         = {},
		loadQueue     = {},
		scrollbar     = scrollbar,
		searchHandler = nil,
		content       = content,
		frame         = frame,
		iconLoader    = iconLoader,
		type          = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	scrollframe.obj, scrollbar.obj, iconLoader.obj = widget, widget, widget

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
