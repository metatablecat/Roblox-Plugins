--!strict
local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

--[=[
	@function Component
	Returns a factory for constructing Components of the given property tree.

	@within Recreate
	@param idName string -- A unique name representing what the factory creates.
	@param factory (props: T) -> Node -- The constructor of the Component itself, must return a Node
	@return (T) -> Node -- The factory to create a Component
]=]
--
local function ComponentFactory<T>(idName: string, factory: (props: T) -> Types.Node): Types.ComponentFactory<T>
	assert(
		not Common.CheckReservedNamespace(idName),
		`[ReCreate]: Cannot use reserved namespace '{Common.RobloxNamespace}' for component name`
	)
	return function(props: any): Types.Node
		-- FIXME: Props.Children wont get tracked as Children
		-- Should this be intentional for passing Children as a state?
		local node = factory(props)
		node.FactoryName = idName
		return node
	end
end

return ComponentFactory
