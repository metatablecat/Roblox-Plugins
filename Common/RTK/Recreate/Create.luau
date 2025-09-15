-- This module is too dynamic to support strict mode :D
local Common = require(script.Parent.Common)
local Node = require(script.Parent.Node)
local Types = require(script.Parent.Types)

local function makeEvent(
	node: Types.Node,
	eventObject: RBXScriptSignal,
	handler: (Types.SenderParams, ...any) -> ()
): RBXScriptConnection
	local sp = {}
	sp.Sender = node
	sp.Connection = eventObject:Connect(function(...)
		handler(sp, ...)
	end)

	table.freeze(sp)
	return sp.Connection
end

local function watchRCI(node: Types.Node, propName: string, watchable: Types.Watchable)
	local implementor = watchable.__RCImplementor
	if not implementor then
		print(watchable)
		warn(`[ReCreate]: Cant use table key {watchable} because it does not have an implementor`)
		return
	end
	if Common.PluginSupressRuntime then
		if implementor.get then node.Instance[propName] = implementor.get(watchable) end
	else
		implementor.watch(watchable, node, propName)
	end

	local watchState = node.Watched[watchable]
	if not watchState then
		watchState = {}
		node.Watched[watchable] = watchState
	end

	watchState[propName] = true
end

local function applyProp(node: Types.Node, propName: string | Types.SpecialKey, prop: any)
	if type(propName) == "table" then
		-- special key
		local sk = propName.__RCSpecialKey
		if sk == "RBXChanged" then
			makeEvent(node, node.Instance:GetPropertyChangedSignal(propName.prop), function(sp)
				local newValue = node.Instance[propName.prop]
				prop(sp, propName.prop, newValue)
			end)
		elseif sk == "WriteState" or sk == "ControlState" then
			assert(prop.__RCImplementor.can_set(prop), `[ReCreate]: __RCImplementor for state {prop} cannot set`)

			if not Common.PluginSupressRuntime then
				node.Instance:GetPropertyChangedSignal(propName.prop):Connect(function()
					local newValue = node.Instance[propName.prop]
					prop.__RCImplementor.set(prop, false, newValue)
				end)
			end

			if sk == "ControlState" then
				prop.__RCImplementor.set(prop, Common.PluginSupressRuntime, node.Instance[propName.prop])
			end

			watchRCI(node, propName.prop, prop)
		else
			error(`[ReCreate]: Unknown special key {sk or propName}`)
		end

		return
	end

	if type(prop) == "table" then -- RCImplementor binding
		watchRCI(node, propName, prop)
	elseif type(prop) == "function" then -- probably an event binding
		local signal = node.Instance[propName]
		assert(typeof(signal) == "RBXScriptSignal", `[ReCreate]: Property {propName} is not an event`)
		if Common.PluginSupressRuntime then return end
		makeEvent(node, signal, prop)
	else -- root prop binding
		node.Instance[propName] = prop
	end
end

local Create = {}

local function commonConstructor(inst: Instance, props: Types.RBXProps): Types.Node
	local node = Node(`{Common.RobloxNamespace}.{inst.ClassName}`, inst)

	local name, children, classes = props.Name, props.Children, props.Class
	props.Name = nil
	props.Children = nil
	props.Class = nil

	node.Name = name or node.Name
	inst.Name = node.Name or node.ID

	if props.Parent then
		warn("[ReCreate]: Detected Parent, skipping. Use the tree or SetParent of the returned component to set the parent")
		props.Parent = nil :: never
	end

	for propName, prop in props do
		applyProp(node, propName, prop)
	end

	if children then
		if children.__RCImplementor then
			-- set as a state key, needs to broadcast to the implementor
			-- this assumes the implementor handles Children keys correctly
			watchRCI(node, "Children", children)
		else
			for _, child in children do
				child:SetParent(node)
			end
		end
	end

	if classes then
		if classes.__RCImplementor then
			watchRCI(node, "Class", classes)
		else
			for _, styleClass in classes do
				inst:AddTag(styleClass)
			end
		end
	end

	return node
end

--[=[
	@function Create
	@within Recreate

	Creates a new Node containing a Roblox `Instance` from the given description

	@param className string -- The class of the `Instance` to create
	@param props RBXProps -- Description of the property table
	@return Node -- A node encapsulating the newly created Instance
]=]
--
function Create.create(className: string, props: Types.RBXProps): Types.Node
	return commonConstructor(Instance.new(className), props)
end

--[=[
	@function FromTemplate
	@within Recreate

	Creates a new Node containing a Roblox `Instance` from the given description,
	using another `Instance` as a base.
	
	:::info
	This constructor uses [`Instance.fromExisting`](https://create.roblox.com/docs/reference/engine/datatypes/Instance#fromExisting),
	and will not copy Children unless explicitly defined in the description table
	:::

	@param instance Instance -- The `Instance` to copy
	@param props RBXProps -- Description of the property table
	@return Node -- A node encapsulating the newly created Instance
]=]
--
function Create.fromTemplate(obj: Instance, props: Types.RBXProps): Types.Node
	-- Uses Instance.fromExisting and copies an existing object instead of using Instance.new
	return commonConstructor(Instance.fromExisting(obj), props)
end

--[=[
	@function FromExisting
	@within Recreate

	Creates a new Node containing an existing Roblox `Instance` without building
	a new one, and applies the description table.

	:::caution
	This constructor exists purely for objects like `DockWidgetPluginGui` that
	cannot be created from other means.

	This function is dangerous and should be used sparingly.
	:::

	@param instance Instance -- The `Instance` to reference
	@param props RBXProps -- Description of the property table
	@return Node -- A node encapsulating the existing instance
]=]
--
function Create.fromExisting(inst: Instance, props: Types.RBXProps): Types.Node
	assert(not Common.RuntimeContext.Instances[inst], `[ReCreate]: Instance {inst} already has a Node member`)
	return commonConstructor(inst, props)
end

return Create
