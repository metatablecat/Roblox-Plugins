-- This provides the main workflow for Form apps
-- This exports both "Form" and "GuiWindow", which will mostly use
-- the same underline event code, but just changes which source the Gui is created
-- from

local Nekotool = require(script.Parent.Parent.Nekotool)
local CoreGui = game:GetService("CoreGui")
local Recreate = require(script.Parent.Parent.RTK.Recreate)
local ToolbarServiceProvider = require(script.Parent.ToolbarService)
local StylingServiceProvider = require(script.Parent.StylingService)
local StylingService
local ToolbarService

type OrState<T> = Recreate.Watchable | T

type ToolbarConfig = {
	ToolbarID: string,
	ButtonID: string,
	Name: string?,
	Image: string?,
	Tooltip: string?,
}

type BasicDesignInfo<T> = {
	ToolbarConfig: ToolbarConfig?,
	Children: OrState<{Recreate.Node}>,
	Opened: (Form<T>) -> ()?,
	Closed: (Form<T>) -> ()?,
	Destroying: (Form<T>) -> ()?,
	Style: {StyleSheet | ModuleScript}? -- not a stateful prop because its expensive :(
}

type DockWidgetFormInfo<T> = BasicDesignInfo<T> & {
	LayerCollectorMode: "PluginGui",
	GuiInfo: DockWidgetPluginGuiInfo,
	Title: OrState<string>?,
	BackgroundColor3: OrState<Color3>?,
	BackgroundTransparency: OrState<number>?,
	InputBegan: (Form<T>, InputObject) -> ()?,
	InputChanged: (Form<T>, InputObject) -> ()?,
	InputEnded: (Form<T>, InputObject) -> ()?,
}

type ScreenGuiFormInfo<T> = BasicDesignInfo<T> & {
	LayerCollectorMode: "ScreenGui"
}

export type Form<T> = {
	ID: string,
	LayerCollectorMode: "PluginGui"|"ScreenGui",
	ToolbarButton: ToolbarServiceProvider.PluginButton?,
	_constructionInfo: ScreenGuiFormInfo<T> | DockWidgetFormInfo<T>,
	_cEventInfo: {
		Loaded: Nekotool.Event<Form<T>>,
		Destroyed: Nekotool.Event<Form<T>>,
		Opened: Nekotool.Event<Form<T>>,
		Closed: Nekotool.Event<Form<T>>,
		ButtonClickSignal: () -> ()?
	},

	LayerCollectorMainObject: LayerCollector,
	LayerCollectorNode: Recreate.Node,
	Opened: boolean,
	State: T,
	Open: (Form<T>) -> (),
	Close: (Form<T>) -> (),
	Destroy: (Form<T>) -> (),
}

-- required for unloading CoreGui elements
local guiComponents: {[ScreenGui]: Form<any>} = {}

local function hydrate<T>(form: Form<T>)
	local n: Recreate.Node
	local dwContentFrame
	
	if form.LayerCollectorMode == "PluginGui" then
		local design = form._constructionInfo :: DockWidgetFormInfo<T>
		-- more advanced: we need to create a child object that acts as the "IO" frame
		dwContentFrame = Recreate.Create("Frame", {
			Active = true,
			Size = UDim2.new(1,0,1,0),
			BorderSizePixel = 0,

			Children = design.Children,
			BackgroundColor3 = if design.BackgroundColor3 then design.BackgroundColor3 else Color3.new(1,1,1),
			BackgroundTransparency = if design.BackgroundTransparency then design.BackgroundTransparency else 1,

			InputBegan = if design.InputBegan then function(senderParams, io) 
				design.InputBegan(form, io)
			end else nil,

			InputChanged = if design.InputChanged then function(senderParams, io) 
				design.InputChanged(form, io)
			end else nil,

			InputEnded = if design.InputEnded then function(senderParams, io) 
				design.InputEnded(form, io)
			end else nil,
		})

		-- now, we can hydrate the main collector

		n = Recreate.FromExisting(form.LayerCollectorMainObject, {
			Name = form.ID,
			Children = {dwContentFrame},
			Title = design.Title or form.ID
		})
	elseif form.LayerCollectorMode == "ScreenGui" then
		-- simple: just hydrate children and return node
		n = Recreate.FromExisting(form.LayerCollectorMainObject, {
			Name = form.ID,
			Children = form._constructionInfo.Children
		})

		n:SetParent(CoreGui)
	end

	-- next, lets connect style refs if they exist
	local styles = form._constructionInfo.Style
	if styles and StylingService then
		for _, sheet in styles do
			Recreate.Create("StyleLink", {
				Name = sheet.Name,
				StyleSheet = StylingService.getStylesheetFromModule(sheet)
			}):SetParent(dwContentFrame or n)
		end
	end

	form.LayerCollectorNode = n
	n:SetOnDestroy(function()
		form:Destroy()
	end)
end

return Nekotool.Service("MCGPluginServices", "Forms", function(service, program)
	ToolbarService = ToolbarServiceProvider:Import()
	StylingService = StylingServiceProvider:Import()
	
	local function makeForm<T, V>(
		id: string,
		events: (Form<T>) -> (T, V),
		design: (Form<T>, state: T, events: V) -> DockWidgetFormInfo<T> | ScreenGuiFormInfo<T>
	): Form<T>
	
		local f = {}::Form<T>
		f._constructionInfo = {}
		f.Opened = false
		f.ID = id
		f._cEventInfo = {
			Opened = Nekotool.Event("Form.Opened"),
			Closed = Nekotool.Event("Form.Closed"),
			Loaded = Nekotool.Event("Form.Loaded"),
			Destroyed = Nekotool.Event("Form.Destroyed"),
		}

		function f:Open()
			if self.Opened then return end
			self.Opened = true
			if not f.LayerCollectorNode then hydrate(self) end
			self.LayerCollectorMainObject.Enabled = true
			self._cEventInfo.Opened:Fire(self)

			if self.ToolbarButton then
				self.ToolbarButton:SetActive(true)
			end
		end

		function f:Close()
			if not self.Opened then return end
			self.Opened = false
			self.LayerCollectorMainObject.Enabled = false
			self._cEventInfo.Closed:Fire(self)

			if self.ToolbarButton then
				self.ToolbarButton:SetActive(false)
			end
		end

		function f:Destroy()
			if not self.LayerCollectorMainObject then return end

			if f.LayerCollectorMode == "ScreenGui" then
				guiComponents[f.LayerCollectorMainObject] = nil
			end

			f.LayerCollectorMainObject:Destroy()
			f.LayerCollectorNode = nil
			f.LayerCollectorMainObject = nil

			if self.ToolbarButton then
				self.ToolbarButton:SetActive(false)
				self.ToolbarButton = nil
			end

			if f._cEventInfo.ButtonClickSignal then
				f._cEventInfo.ButtonClickSignal()
				f._cEventInfo.ButtonClickSignal = nil
			end

			f._cEventInfo.Destroyed:Fire(self)
			f._cEventInfo.Closed:DisconnectAll()
			f._cEventInfo.Destroyed:DisconnectAll()
			f._cEventInfo.Loaded:DisconnectAll()
			f._cEventInfo.Opened:DisconnectAll()
		end

		local localState, eventState = events(f)
		local designInfo = design(f, localState, eventState)
		f.State = localState
		f._constructionInfo = designInfo
		f.LayerCollectorMode = designInfo.LayerCollectorMode

		-- create LayerCollector

		if designInfo.LayerCollectorMode == "PluginGui" then
			if program.Exports.RunContext ~= Enum.RunContext.Plugin then error("Cant create a PluginGui form in non-plugin context") end
			
			local dockwidget = program.Exports.Plugin:CreateDockWidgetPluginGui(id, designInfo.GuiInfo)
			f.LayerCollectorMainObject = dockwidget
			f.Name = id
			
			-- FIX: hydrate name early
			dockwidget.Name = id
			
			if dockwidget.Enabled then
				f:Open()
			end
		elseif designInfo.LayerCollectorMode == "ScreenGui" then
			local sgui = Instance.new("ScreenGui")
			sgui.Enabled = false
			sgui.Name = id
			guiComponents[sgui] = f

			f.LayerCollectorMainObject = sgui
		else
			error(`Unknown layer collector mode: {designInfo.LayerCollectorMode}`)
		end

		f.LayerCollectorMainObject:GetPropertyChangedSignal("Enabled"):Connect(function()
			if f.LayerCollectorMainObject.Enabled then f:Open() else f:Close() end
		end)

		local cfg = designInfo.ToolbarConfig
		if cfg then
			if not ToolbarService then
				warn("ToolbarService is not enabled, but ToolbarConfig was provided")
			else
				cfg.Active = f.LayerCollectorMainObject.Enabled
				local ipb = ToolbarService:GetButton(cfg.ToolbarID, cfg.ButtonID, cfg)
				f._cEventInfo.ButtonClickSignal = ipb.Click(function()
					if f.Opened then f:Close() else f:Open() end
				end)

				f.ToolbarButton = ipb
			end
		end

		return f
	end

	service.OnPostInit = function(self)
		-- load form folder if it hasn't already loaded
		-- its better to normally do this from the MainPlugin

		if not self.LocalConfig.FormItems then return end
		Nekotool.ModuleLoader.loadFromObjects(self.LocalConfig.FormItems)
	end

	program.UnloadingEvent.Signal(function()
		for gui, f in guiComponents do
			f:Destroy()
		end
	end)

	return Nekotool.Result.Ok(makeForm)
end)