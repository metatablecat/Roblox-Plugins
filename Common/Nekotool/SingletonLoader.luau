-- This should be a one-size fits all launcher that should correctly
-- identify the load context

-- The config files should be in the following locations for each config
-- Server: ServerStorage.Nekotool.config
-- Client: ReplicatedStorage.Nekotool.config
-- Plugin: <SrcFolder>.Nekotool.config

local Plugin = script:FindFirstAncestorWhichIsA("Plugin")

local function canRunInScope(scope: Enum.RunContext): boolean
	if scope == Enum.RunContext.Plugin then return Plugin ~= nil end
	return Plugin == nil
end

return function(scope: Enum.RunContext)
	if not canRunInScope(scope) then return end

	local NEKOTOOL_CONFIG_NAME = "nekotool.config"
	local CommonInit = require(script.Parent.CommonInit)

	local function findConfigModule(path:Instance): ModuleScript
		local m = path:FindFirstChild(NEKOTOOL_CONFIG_NAME)
		if not m or not m:IsA("ModuleScript") then error(`Cant locate a {NEKOTOOL_CONFIG_NAME} module at {path:GetFullName()} `) end
		return m
	end

	if scope == Enum.RunContext.Plugin then
		-- with wally, we need to instead search for it from the plugin root
		-- this assumes the project is structed with a folder at the top level node

		local folder = Plugin:FindFirstChildOfClass("Folder")
		local config = folder and folder:FindFirstChild(NEKOTOOL_CONFIG_NAME)
		if not config or not config:IsA("ModuleScript") then error(`Cant locate a {NEKOTOOL_CONFIG_NAME} module in project root.`) end
		CommonInit(Enum.RunContext.Plugin, config, Plugin)

	elseif scope == Enum.RunContext.Client then
		local config = findConfigModule(game:GetService("ReplicatedStorage"))
		CommonInit(Enum.RunContext.Client, config)
		
	elseif scope == Enum.RunContext.Server then
		local config = findConfigModule(game:GetService("ServerStorage"))
		CommonInit(Enum.RunContext.Server, config)
	end
end