return function(rc: Enum.RunContext, config: ModuleScript, pluginHandle: Plugin?)
	-- A small streamlined loader
	-- The loading order of Modules is important because they depend on state defined by this script
	
	if rc == Enum.RunContext.Plugin and not pluginHandle then
		error("To run in Plugin context, a Plugin must be provided")
	end
	
	local ConfigLoader = require(script.Parent.Internal.Loaders.ConfigLoader)
	local IS_LOCAL = if pluginHandle then string.sub(pluginHandle.Name, 1, 5) == "user_" else false -- Not a plugin, so it can never be local
	-- we should probably add more intensive benchmarking features

	local function safeModuleLoader(module: ModuleScript, expectedReturnType: string)
		if not module:IsA("ModuleScript") then error(`Module {module} is not a ModuleScript`) end
		local moduleReturn = require(module)
		if typeof(moduleReturn) ~= expectedReturnType then error(`Module {module} did not return a {expectedReturnType}. Got {typeof(moduleReturn)}`) end
		return moduleReturn
	end

	local Config = ConfigLoader.load(safeModuleLoader(config, "table"))
	local DEBUG_FLAGS = Config.Flags or {}

	local name = Config.Name or "UnnamedNekotoolProject"
	local Program = require(script.Parent.Internal.Program)
	local Microservice = require(script.Parent.Internal.MicroserviceCore)
	local ModuleLoader = require(script.Parent.Internal.Loaders.ModuleLoader)

	Program.Name = name
	Program.IsProbablyLocal = IS_LOCAL
	Program.Exports.Name = name
	Program.Exports.Plugin = pluginHandle
	Program.Exports.RunContext = rc
	table.freeze(Program.Exports)

	Program.SourceFolder = Config.SourceFolder
	local EntryPoint = Config.EntryPoint

	Microservice.Config = Config.Services or {}

	if Config.CustomServices then
		local msResult = ModuleLoader.loadFromInstance(Config.CustomServices)
		if DEBUG_FLAGS.DebugMode then
			for obj, result in msResult do
				if result:isOk() then continue end
				warn(`Service module {obj:GetFullName()} didn't load correctly:`, result:unwrapErr())
			end
		end
	end

	Microservice.loadInternal(Program)

	if EntryPoint then
		local fn = safeModuleLoader(EntryPoint, "function")
		fn(Program.Exports)
	end

	Microservice.PostInit()

	Program.InitEvent:Fire(Program.Exports)
	
	if pluginHandle then		
		pluginHandle.Unloading:Connect(function()
			Program.UnloadingEvent:Fire(Program.Exports)
		end)
	end

	if DEBUG_FLAGS.DebugMode then
		print(Config)
		print(Microservice.Services)
	end
end