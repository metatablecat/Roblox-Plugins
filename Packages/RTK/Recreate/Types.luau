--!strict

export type ComponentFactory<T = { [string]: any }> = (T) -> Node

--[=[
	@type Watchable {__RCImplementor: Implementor, [string]: any}
	@tag State
	@within Recreate

	Represents a watchable state object with a bound `__RCImplementor`.
]=]
--
export type Watchable = {
	__RCImplementor: Implementor, -- maybe we should use __index here?
	[string]: any,
}

--[=[
	@interface Implementor
	@within Recreate
	.watch (Watchable, Node, string) -> () -- Invoked when binding a Node and Property to a Watchable
	.unwatch (Watchable, Node, string?) -> () -- Invoked when removing a Property and/or Node from a Watchable
	.get (Watchable) -> () -- Invoked when pulling a value from the Watchable

	Backend logic on the `__RCImplementor` tag for bringing between a Watchable
	and the state engine.
]=]
--
export type Implementor = {
	watch: (Watchable, Node, string) -> (),
	unwatch: (Watchable, Node, string?) -> (),
	can_set: (Watchable) -> boolean,
	get: (Watchable) -> any,
	set: (Watchable, quiet: boolean, any) -> (),
}

export type WatchableState = {
	propName: string,
	connections: {RBXScriptConnection}
}

export type Node = {
	FactoryName: string,
	Name: string,
	ID: string,
	Watched: { [Watchable]: { [string]: WatchableState } },
	Children: { [string]: Node },
	Destructors: { [() -> ()]: (Node) -> () },
	Parent: Node | Instance?,
	Instance: Instance,
	SetParent: (Node, Node | Instance?) -> (),
	Destroy: (Node) -> (),
	SetOnDestroy: (Node, (Node) -> ()) -> () -> (),
	UnbindState: (Node, state: Watchable) -> ()
}

--[=[
	@type SenderParams {Sender: node, Connection: RBXScriptConnection}
	@within Recreate

	A union containing the Sender of an event, and its associated Connection
]=]
--
export type SenderParams = {
	Sender: Node,
	Connection: RBXScriptConnection,
}

export type SpecialKey<T = any> = typeof(setmetatable(
	{} :: {
		__RCSpecialKey: T,
		prop: string,
		IsA: (SpecialKey<T>, a: string) -> boolean,
	},
	{} :: {
		__eq: (a: SpecialKey<T>, b: SpecialKey<T>) -> boolean,
	}
))

--[=[
	@interface RBXProps
	@within Recreate

	The tree of properties passed to `Create` constructors which define how to
	create or bind State to said object

	.Children ({Node}|Watchable)? -- A table or watchable state object representing the direct children of this Node
	.Class ({string}|Watchable)? -- A table or watchable state object representing CollectionService tags, which is used for stylesheets.
	.Name string? -- The name of the object
	@field [string|SpecialKey] any -- Extra definitions not explicitly defined by RBXProps.

]=]
--
export type RBXProps = {
	Children: { Node } | Watchable?,
	Class: { string } | Watchable?,
	Parent: nil,
	Name: string?,
	[string | SpecialKey]: any,
}

return nil
