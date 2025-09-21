-- V2 Logica Algo
-- relies on tracking how get is used within dependents to build the tree
--!optimize 2

local RunService = game:GetService("RunService")
local Recreate = require(script.Parent.Recreate)
local TICK, ANALYSIS = 0, false
local TRACE_DEP
local EMPTY = newproxy(false) -- required to discriminate nil from actually nil

type GraphNodeBase<T> = {
	_tag: string,
	__RCImplementor: any,
	__RCNodes: { [Recreate.Node]: { [string]: true } },
	_v: T,
	_u: T?,
	_dependents: { [Dependent<T>]: boolean },
	_consumers: { [GraphNodeBase<T>]: boolean, },
	_lastTick: number,
	_imark: boolean,
	_alive: boolean,
	get: any,
	set: any,
	destroy: (GraphNodeBase<T>) -> (),
}

local IMARK: { [any]: { [Recreate.Node]: { [string]: true } } }

export type Node<T> = GraphNodeBase<T> & {
	_tag: "node",
	set: (Node<T>, T) -> (),
	get: (Node<T>) -> T,
}

export type Dependent<T> = GraphNodeBase<T> & {
	_tag: "dependent",
	_directWrite: boolean,
	_fn: () -> T,
	get: (Dependent<T>) -> T,
	set: (Dependent<T>, T) -> (),
}

export type Any = Node<any> | Dependent<any>

local RCI = {
	watch = function<T>(self: GraphNodeBase<T>, RCNode: Recreate.Node, prop: string)
		local t = self.__RCNodes[RCNode]
		if not t then
			t = {}
			self.__RCNodes[RCNode] = t
		end

		self._imark = true
		t[prop] = true
		RCNode.Instance[prop] = self:get()
	end,

	unwatch = function<T>(self: GraphNodeBase<T>, RCNode: Recreate.Node)
		self.__RCNodes[RCNode] = nil

		if not next(self.__RCNodes) then self._imark = false end
	end,

	can_set = function<T>(self: GraphNodeBase<T>)
		return self.set ~= nil
	end,

	get = function<T>(self: GraphNodeBase<T>)
		return self:get()
	end,

	set = function<T>(self: GraphNodeBase<T>, quiet, T)
		if quiet then
			self._v = T
		else
			self:set(T)
		end
	end,
}

local function GraphNodeBase(): GraphNodeBase<any>
	local node = {}
	node._tag = "untagged"
	node.__RCImplementor = RCI
	node.__RCNodes = {}
	node._v = nil
	node._u = EMPTY
	node._dependents = {}
	node._consumers = {}
	node._lastTick = 0
	node._imark = false
	node._alive = true

	function node.destroy(self: GraphNodeBase<any>)
		-- just unlinks this object from any consumers
		-- it does NOT travel up the tree and disconnect itself from dependents
		node._alive = false

		for consumer in self._consumers do
			consumer._dependents[self] = nil
		end

		table.clear(self._consumers)

		-- TODO: if this node has a Recreate connection, unmark it from the node
	end

	return node
end

local queue: { [GraphNodeBase<any>]: true } = {}

local function Node<T>(T: T?): Node<T>
	local node = GraphNodeBase() :: Node<T>
	node._v = T
	node._tag = "node"

	function node:set(T: T)
		if ANALYSIS then error("Cant set during analysis") end

		if type(self._v) ~= "table" and self._v == T then
			self._u = EMPTY
			queue[self] = nil
			return
		end

		self._u = T
		queue[self] = true
	end

	function node:get()
		if not self._alive then return if self._u ~= EMPTY then self._u else self._v end

		if not ANALYSIS or self._lastTick == TICK then
			if TRACE_DEP then
				TRACE_DEP._consumers[self] = true
				self._dependents[TRACE_DEP] = true
			end

			return if self._u ~= EMPTY then self._u else self._v
		end

		if self._v ~= self._u or type(self._u) == "table" then
			self._v = self._u
			self._u = EMPTY
			if self._imark and IMARK then IMARK[self] = self.__RCNodes end
		end

		self._lastTick = TICK
		return self._v
	end

	return node
end

local function Dependent<T>(fn: () -> T): Dependent<T>
	local dep = GraphNodeBase() :: Dependent<T>
	dep._tag = "dependent"
	dep._fn = fn
	dep._directWrite = false

	function dep:get()
		if not self._alive then return self._v end

		if not ANALYSIS or self._lastTick == TICK then
			if TRACE_DEP then
				TRACE_DEP._consumers[self] = true
				self._dependents[TRACE_DEP] = true
			end
			return self._v
		end

		self._lastTick = TICK
		local _u = if self._directWrite then self._u else self._fn()
		self._directWrite = false

		if self._v ~= _u or type(_u) == "table" then
			self._v = _u
			if self._imark and IMARK then IMARK[self] = self.__RCNodes end
		end

		for dep in self._dependents do
			--if dep._lastTick == TICK then continue end
			dep:get()
		end

		return self._v
	end

	function dep:set(T)
		if ANALYSIS then error("Cant set during analysis") end
		if self._v == T and type(T) ~= "table" then
			self._u = EMPTY
			self._directWrite = false
			queue[self] = nil
			return
		end

		self._u = T
		self._directWrite = true
		queue[self] = true
	end

	TRACE_DEP = dep
	dep._v = fn()
	TRACE_DEP = nil

	return dep
end

export type Observer = {
	_tag: "observer",
	_fn: () -> (),
	get: (Observer) -> (),
	_consumers: { [GraphNodeBase<any>]: boolean, },
	destroy: (Observer) -> (),
}
local function Observer(fn: () -> ()): Observer
	local observer = {
		_tag = "observer",
		_fn = fn,
		_consumers = {},
		get = function(self)
			task.defer(self._fn)
		end,

		destroy = function(self: Observer)
			for consumer in self._consumers do
				consumer._dependents[self] = nil
			end
		end
	}

	TRACE_DEP = observer
	fn()
	TRACE_DEP = nil
	return observer
end

RunService.PreRender:Connect(function()
	TICK = os.clock()
	ANALYSIS = true
	IMARK = {}
	for openNode in queue do
		-- first, update base nodes
		openNode:get()

		-- next, traverse dependents, and resolve them
		for dep in openNode._dependents do
			dep:get()
		end
	end

	for node, rcnodeState in IMARK do
		for rcnode, props in rcnodeState do
			for propName in props do
				rcnode.Instance[propName] = node._v
			end
		end
	end

	ANALYSIS = false
	queue = {}
end)

return {
	Node = Node,
	Dependent = Dependent,
	Observer = Observer,
}
