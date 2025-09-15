-- This is technically an idle service but exists regardless because it'd be
-- useful to have static-time creation of buttons in the Config file

local DEFAULT_BTN_IMAGE = "rbxassetid://72636898059631"

local Nekotool = require(script.Parent.Parent.Nekotool)
local TranslationServiceProvider = require(script.Parent.TranslatorService)
local TranslationService

export type PluginButton = {
	ID: string,
	ToolbarID: string,
	Click: Nekotool.Signal<PluginButton>,
	SetEnabled: (PluginButton, enabled: boolean) -> (),
	SetActive: (PluginButton, active: boolean) -> (),
}

export type IPluginButton = {
	Instance: PluginToolbarButton,
	Export: PluginButton,
	Event: Nekotool.Event<PluginButton>,
	Enabled: boolean,
	Active: boolean,
	ClickEvents: number,
}

local tree: {
	[string]: {
		ToolbarInstance: PluginToolbar,
		Buttons: {
			[string] : IPluginButton
		}
	}
} = {}

type ButtonCtorParams = {
	Name: string?,
	Image: string?,
	Tooltip: string?,
	Enabled: boolean?,
	Active: boolean?,
}

local function buttonEvent(ipb: IPluginButton): Nekotool.Event<PluginButton>
	local e = Nekotool.Event("ToolbarButton.Click")

	e.OnConnect = function()
		ipb.ClickEvents += 1
		ipb.Instance.Enabled = ipb.Enabled
		ipb.Instance:SetActive(ipb.Active)
	end

	e.OnDisconnect = function()
		ipb.ClickEvents = math.max(ipb.ClickEvents - 1, 0)
		if ipb.ClickEvents <= 0 then
			ipb.Instance.Enabled = false
		end
	end

	return e
end

local function createButton(toolbar: PluginToolbar, toolbarID: string, buttonID: string, ctor: ButtonCtorParams): IPluginButton
	local internal = {} :: IPluginButton

	if TranslationService then
		internal.Instance = toolbar:CreateButton(
			buttonID,
			if ctor.Tooltip then TranslationService:Translate(ctor.Tooltip) else "",
			ctor.Image or DEFAULT_BTN_IMAGE,
			if ctor.Name then TranslationService:Translate(ctor.Name) else buttonID
		)
	else
		internal.Instance = toolbar:CreateButton(
			buttonID,
			ctor.Tooltip or "",
			ctor.Image or DEFAULT_BTN_IMAGE,
			ctor.Name or buttonID
		)
	end

	internal.Instance.ClickableWhenViewportHidden = true
	internal.Instance.Enabled = false

	internal.ClickEvents = 0
	internal.Event = buttonEvent(internal)
		internal.Export = {
		ID = buttonID,
		ToolbarID = toolbarID,
		Click = internal.Event.Signal,
		SetEnabled = function(self, enabled: boolean)
			local btn = tree[self.ToolbarID] and tree[self.ToolbarID].Buttons[self.ID]
			if not btn then return end
			btn.Enabled = enabled

			if btn.ClickEvents > 0 then
				btn.Instance.Enabled = enabled
				btn.Instance:SetActive(btn.Active)
			end
		end,
		SetActive = function(self, active: boolean)
			local btn = tree[self.ToolbarID] and tree[self.ToolbarID].Buttons[self.ID]
			if not btn then return end
			btn.Active = active
			btn.Instance:SetActive(active)
		end

	}
	internal.Enabled = if ctor.Enabled ~= nil then ctor.Enabled else true
	internal.Active = if ctor.Active ~= nil then ctor.Active else false
	
	internal.Instance.Click:Connect(function()
		internal.Event:Fire(internal.Export)
	end)

	table.freeze(internal.Export)
	return internal
end

local function getButton(plugin: Plugin, toolbarID: string, buttonID: string, ctor: ButtonCtorParams): IPluginButton
	local toolbar = tree[toolbarID]
	if not toolbar then
		toolbar = {
			ToolbarInstance = plugin:CreateToolbar(toolbarID),
			Buttons = {}
		}
		tree[toolbarID] = toolbar
	end

	local btn = toolbar.Buttons[buttonID]
	if not btn then
		btn = createButton(toolbar.ToolbarInstance, toolbarID, buttonID, ctor)
		toolbar.Buttons[buttonID] = btn
	end

	return btn
end

return Nekotool.Service("MCGPluginServices", "ToolbarService", function(service, program)
	local ToolbarService = {}

	if service.LocalConfig.UseTranslatorService then
		TranslationService = TranslationServiceProvider:Import()
		if not TranslationService then
			warn(`UseTranslatorService is true, but TranslationService itself is not enabled.`)
		end
	end

	local function InternalGetButton(toolbarID: string, buttonID: string, ctorOverride: ButtonCtorParams?): IPluginButton
		return getButton(program.Exports.Plugin, toolbarID, buttonID, ctorOverride or {})
	end

	function ToolbarService:IsButtonConstructed(toolbarID: string, buttonID: string): boolean
		return tree[toolbarID] and tree[toolbarID].Buttons[buttonID] ~= nil
	end

	function ToolbarService:GetButton(toolbarID: string, buttonID: string, ctorOverride: ButtonCtorParams?): PluginButton
		if ctorOverride and ToolbarService:IsButtonConstructed(toolbarID, buttonID) then
			warn(`Button {toolbarID}.{buttonID} was already constructed, but constructor params were provided.`)
		end

		return InternalGetButton(toolbarID, buttonID, ctorOverride).Export
	end

	function ToolbarService:GetButtonClickedSignal(toolbarID: string, buttonID: string): Nekotool.Signal<PluginButton>
		local button = assert(tree[toolbarID] and tree[toolbarID].Buttons[buttonID], `Button {toolbarID}.{buttonID} is undefined.`)
		return button.Event.Signal
	end

	local toolbars = service.LocalConfig.Toolbars
	if toolbars then
		for _, toolbar in toolbars do
			for _, button in toolbar.Buttons do
				getButton(program.Exports.Plugin, toolbar.ID, button.ID, button)
			end
		end
	end

	return Nekotool.Result.Ok(ToolbarService)
end)