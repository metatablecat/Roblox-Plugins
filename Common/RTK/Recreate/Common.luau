--!strict
local Types = require(script.Parent.Types)
local Common = {}

Common.RobloxNamespace = "RBX"
Common.PluginSupressRuntime = false
Common.RuntimeContext = {
	Nodes = {} :: { [string]: Types.Node },
	Instances = {} :: { [Instance]: Types.Node },
}

function Common.CheckReservedNamespace(str)
	return string.sub(str, 1, string.len(Common.RobloxNamespace)) == Common.RobloxNamespace
end

return Common
