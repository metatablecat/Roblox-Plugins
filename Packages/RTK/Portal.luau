-- A virtual component that allows rendering of non-Recreate elements

local Recreate = require(script.Parent.Recreate)
local Logica = require(script.Parent.Logica)

type PortalProps = {
	ChildInstance: (Instance | Logica.Any<Instance?>)?,
	Class: { string } | Recreate.Watchable?,
	Parent: nil,
	Name: string?,
	[string | Recreate.SpecialKey]: any,
}

return Recreate.Component("RTK.Portal", function(props: PortalProps)
	local childStateController
	if props.ChildInstance then
		childStateController = props.ChildInstance
	end

	if typeof(childStateController) == "Instance" then
		props.Children = {childStateController}
	end

	local node = Recreate.Create("Frame", props)

	if typeof(childStateController) == "table" then
		-- setup state bindings
		local rendered: Instance?
		local obs = Logica.Observer(function()
			if rendered and rendered.Parent == node.Instance then
				-- if the object was swapped out without us knowing
				-- (also incase the developer swaps out the instance before Logica can update its tree)
				rendered.Parent = nil
			end

			rendered = childStateController:get()
			if rendered then
				rendered.Parent = node.Instance
			end
		end)

		node:SetOnDestroy(function()
			obs:destroy()
		end)
	end

	return node
end)