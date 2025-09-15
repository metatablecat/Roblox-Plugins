local Recreate = require(script.Parent.Recreate)

export type ChildrenState = {
	__RCImplementor: any,
	__node: Recreate.Node?,
	__list: {[Recreate.Node]: () -> ()},
	__tag: "ChildrenState",

	get: (ChildrenState) -> {Recreate.Node},
	set: (ChildrenState, {Recreate.Node}) -> (),
	is_in: (ChildrenState, Recreate.Node) -> boolean,
	clear: (ChildrenState) -> (),
	insert: (ChildrenState, Recreate.Node) -> (),
	remove: (ChildrenState, Recreate.Node) -> ()
}

export type TagState = {
	__RCImplementor: any,
	__nodes: {[Recreate.Node]: true},
	__list: {[string]: true},
	__tag: "TagState",

	get: (TagState) -> {string},
	set: (TagState, {string}) -> (),
	is_in: (TagState, string) -> boolean,
	clear: (TagState) -> (),
	insert: (TagState, string) -> (),
	remove: (TagState, string) -> ()
}

type List = TagState | ChildrenState

local WatchedList = {}

local function keys<T>(T: {[T]: any}): {T}
	local out = {}
	for K in T do
		table.insert(out, K)
	end
	return out
end

local RCI = {
	watch = function(self: List, node: Recreate.Node, propName: string)
		if self.__tag == "ChildrenState" then
			assert(propName == "Children", "Can only bind ChildStates to Children")
			assert(not self.__node, "ChildState is already watching another Node")

			self.__node = node
			for children in self.__list do
				children:SetParent(node)
			end
		elseif self.__tag == "TagState" then
			assert(propName == "Class", "Can only bind TagState to Class")
			self.__nodes[node] = true
			for tags in self.__list do
				node.Instance:AddTag(tags)
			end
		end
	end,

	unwatch = function(self: List, node: Recreate.Node)
		if self.__tag == "ChildrenState" then
			if self.__node == node then
				self.__node = nil
			end
		elseif self.__tag == "TagState" then
			self.__nodes[node] = nil
		end
	end,

	can_set = function()
		return false
	end,

	get = function(self)
		return self:get()
	end,

	set = function()
		error("WatchedList objects cannot set. This is probably an internal bug from Recreate.")
	end
}

function WatchedList.TagState(obj: {string}): TagState
	local list = {}
	list.__RCImplementor = RCI
	list.__nodes = {}
	list.__list = {}
	list.__tag = "TagState"

	function list.get(self: TagState): {string}
		return keys(self.__list)
	end

	function list.set(self: TagState, e: {string})
		self:clear()
		for _, K in e do
			self:insert(K)
		end
	end

	function list.is_in(self: TagState, e: string): boolean
		return self.__list[e] ~= nil
	end

	function list.clear(self: TagState)
		for K in self.__list do
			self:remove(K)
		end
	end

	function list.insert(self: TagState, T:string)
		if self.__list[T] then return end
		self.__list[T] = true
		
		for nodes in self.__nodes do
			nodes.Instance:AddTag(T)
		end
	end

	function list.remove(self: TagState, T:string)
		if not self.__list[T] then return end
		self.__list[T] = nil
		
		for nodes in self.__nodes do
			nodes.Instance:RemoveTag(T)
		end
	end
	
	list:set(obj)
	return list
end

function WatchedList.ChildrenState(obj: {Recreate.Node}): ChildrenState
	local list = {}
	list.__RCImplementor = RCI
	list.__nodes = {}
	list.__list = {}
	list.__tag = "ChildrenState"

	function list.get(self: ChildrenState): {Recreate.Node}
		return keys(self.__list)
	end

	function list.set(self: ChildrenState, e: {Recreate.Node})
		self:clear()
		for _, K in e do
			self:insert(K)
		end
	end

	function list.is_in(self: ChildrenState, e: Recreate.Node): boolean
		return self.__list[e] ~= nil
	end

	function list.clear(self: ChildrenState)
		for K in self.__list do
			self:remove(K)
		end
	end

	function list.insert(self: ChildrenState, T:Recreate.Node)
		if self.__list[T] then return end
		self.__list[T] = T:SetOnDestroy(function(node)
			self:remove(node)
		end)
		
		if self.__node then
			T:SetParent(self.__node)
		end
	end

	function list.remove(self: ChildrenState, T:Recreate.Node)
		if not self.__list[T] then return end
		self.__list[T] = self.__list[T]()
		
		T:SetParent(nil)
	end
	
	list:set(obj)
	return list
end

return WatchedList