--!strict

local HttpService = game:GetService("HttpService")
local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

--[=[
	@class Node

	A single unit containing an Instance inside a Gui tree. These are mostly used
	for propegating state engine changes, rather than in your code.
]=]
--
local function Node(factoryName: string, inst: Instance): Types.Node
	local Node = {}

	--[=[
		@prop Class {string}
		@within Node
		@unreleased
		@tag Plugin

		:::note
		This is not currently implemented, but is intended for plugins to read which
		stylesheet keys are defined on the object

		We may just tell plugins to instead read the return from `GetTags()`.
		:::
	]=]
	--
	Node.Class = {}

	--[=[
		@prop Destructors {[() -> ()]: (Node) -> ()}
		@within Node
		@tag State

		Event bindings that are defined through SetOnDestroy, used to broadcast
		destructors to untracked Watchables.
	]=]
	--
	Node.Destructors = {}

	--[=[
		@prop FactoryName string
		@within Node
		
		Indicates which component factory produced this Node, or RBX if none.
	]=]
	--
	Node.FactoryName = factoryName

	--[=[
		@prop ID string
		@within Node
		
		The unique ID of this Node.
	]=]
	--
	Node.ID = HttpService:GenerateGUID(false)

	--[=[
		@prop Watched {[Watchable]: {[string]: true}}
		@within Node
		@tag Plugin
		@tag State
		
		State bindings on this Node. Intended for readonly plugin usage, and to
		correctly destruct states on Destroy.
	]=]
	--
	Node.Watched = {}

	--[=[
		@prop Children {[string]: {Node}
		@within Node
		
		Child nodes directly under this Node. You should use a Watchable to manipulate
		this table in production code.
	]=]
	--
	Node.Children = {}

	--[=[
		@prop Name string
		@within Node
		
		The non-unique name of the Node, this usually matches the Instance name.
	]=]
	--
	Node.Name = Node.ID

	--[=[
		@prop Parent (Node|Instance)?
		@within Node
		
		The current parent, if any, of the Node.
	]=]
	--
	Node.Parent = nil

	--[=[
		@prop Parent Instance
		@within Node
		
		The constructed Instance that this Node is containing.
	]=]
	--
	Node.Instance = inst

	--[=[
		@function SetParent
		@within Node
		@tag State

		Parents the Node to another Node or Instance. Intended for Watchable states
		to manipulate the Children of the Node, should never be used outside of a
		state engine.

		@param self Node
		@param parent (Node | Instance)?
	]=]
	--
	function Node.SetParent(self: Types.Node, parent: Types.Node | Instance?)
		local oldParent = self.Parent
		if oldParent == parent then return end

		if type(oldParent) == "table" then
			assert(
				oldParent.Children[self.ID] == self,
				`[ReCreate]: Internal state bug: {self.ID} is not a child of {oldParent.ID}`
			)
			oldParent.Children[self.ID] = nil
		end

		if not parent then
			self.Parent = nil
			self.Instance.Parent = nil
			return
		end

		if type(parent) == "table" then
			assert(not parent.Children[self.ID], `[ReCreate]: ID {self.ID} is already a child of parent {parent.ID}`)
			parent.Children[self.ID] = self
			self.Parent = parent
			self.Instance.Parent = parent.Instance
		else
			self.Parent = parent
			self.Instance.Parent = parent
		end
	end

	--[=[
		@function SetOnDestroy
		@within Node
		@tag State

		Defines a destructor, mainly intended for signalling untracked Watchables
		that are not directly linked to the Instance

		@param self Node
		@param destructor (Types.Node) -> ()
		@return () -> () -- A function to disconnect the destructor
	]=]
	--
	function Node.SetOnDestroy(self: Types.Node, destructor: (Types.Node) -> ()): () -> ()
		local function connection()
			self.Destructors[connection] = nil
		end

		self.Destructors[connection] = destructor
		return connection
	end

	--[=[
		@function Destroy
		@within Node
		@tag State

		Destroys the Node, disconnects all State watchers, then destroys all Children
		to the Node.

		@param self Node
	]=]
	--
	function Node.Destroy(self: Types.Node)
		if not Common.RuntimeContext.Nodes[self.ID] then return end
		Common.RuntimeContext.Nodes[self.ID] = nil
		Common.RuntimeContext.Instances[self.Instance] = nil

		for _, child in self.Children do
			child:Destroy()
		end
		table.clear(self.Children) -- this should be empty already
		self.Instance:Destroy()
		self:SetParent(nil) -- this might double trigger Destroy

		for RCImpl in self.Watched do
			self:UnbindState(RCImpl)
		end

		for _, destructor in self.Destructors do
			task.defer(destructor, self)
		end

		table.clear(self.Destructors)
		table.clear(self.Watched)
	end

	function Node.UnbindState(self: Types.Node, state: Types.Watchable)
		local stateEntry = self.Watched[state]
		if not stateEntry then return end

		-- clear prop connections
		for _, propData in stateEntry do
			for _, connection in propData.connections do
				connection:Disconnect()
			end
		end

		self.Watched[state] = nil
		state.__RCImplementor.unwatch(state, self)
	end

	Common.RuntimeContext.Nodes[Node.ID] = Node
	Common.RuntimeContext.Instances[inst] = Node

	inst.Destroying:Connect(function()
		Node:Destroy()
	end)

	return Node
end

return Node
