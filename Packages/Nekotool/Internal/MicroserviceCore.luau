local Types = require(script.Parent.Types)
local Result = require(script.Parent.Result)
local Config = require(script.Parent.Loaders.ConfigLoader)

local function exceptionTable(id)
	return setmetatable({}, {
		__index = function()
			error(`Service {id} is not enabled and cannot be used.`)
		end,

		__newindex = function()
			error(`Service {id} is not enabled and cannot be used.`)
		end,

		__call = function()
			error(`Service {id} is not enabled and cannot be used.`)
		end,
	})
end

local SERVICE_MT = {
	__tostring = function<A>(self: Types.Microservice<A>)
		return `{self.Namespace}::{self.ID}`
	end,
	__metatable = "The metatable is locked"
}

local Services = {}
local Namespaces = {}
Services.Services = {} :: {[string]: Types.Microservice<any>}
Services.Config = {}::{
	-- [namespace]: {[Service]: config}
	[string]: {[string]: Types.MicroserviceConfigItem}
}

local function ASSERT_PROBABLY_RESULT(r: Result.Result<any,any>, id)
	if type(r) == "table" and r._ok ~= nil then return r end
	return Result.Err(`Service {id} init function does not return a Result object`)
end

local function makeNamespaceService<T>(namespace: string, serviceID: string, fn: (Types.Microservice<T>, Types.Program) -> Types.Result<T, string>): Types.Microservice<T>
	local DebugMode = Config:GetDebugFlag("DebugMode")
	
	local namespaceServicePair = `{namespace}::{serviceID}`
	assert(not Services.Services[namespaceServicePair], `Duplicate Microservice definition: {namespaceServicePair}`)
	
	local service = {} :: Types.Microservice<T>
	service.Namespace = namespace
	service.ID = serviceID
	service._rtState = {
		initFn = fn,
		state = "Idle",
		yielding = {},
	}
	
	local configItem = Services.Config[namespace] and Services.Config[namespace][serviceID]
	
	service.LocalConfig = configItem or { Enabled = false }
	service.Enabled = service.LocalConfig.Enabled
	
	function service:AwaitIfEnabled()
		if not self.Enabled then return end
		
		if self._rtState.state ~= "Spawned" then
			table.insert(self._rtState.yielding, coroutine.running())
			coroutine.yield()
		end
		
		return self.Export
	end
	
	function service:Publish()
		local obj = service:AwaitIfEnabled()
		if not obj then
			-- not enabled!!
			return exceptionTable(self.ID)
		end
		
		return obj:unwrap()
	end
	
	function service:Import()
		-- almost identical to publish but just
		-- returns a nil instead of exception table
		local obj = self:AwaitIfEnabled()
		if not obj then return end
		if obj:isOk() then return obj:unwrap() end
		warn(obj:unwrapErr())
		return
	end
	
	function service:Spawn(program: Types.Program)
		-- TODO: should this throw?
		if not self.Enabled then return Result.Err("Service is not enabled") end
		if self._rtState.state ~= "Idle" then return end

		self._rtState.state = "Spawning"
		self.Export = Result.try(self._rtState.initFn, self, program):andThen(function(T)
			return ASSERT_PROBABLY_RESULT(T, self.ID)
		end)
		
		self._rtState.state = "Spawned"

		for _, thread in self._rtState.yielding do
			-- resuming a thread doesn't need to be logged
			-- we could probably have an explicit method for this in the future
			task.defer(thread)
		end
		
		table.clear(self._rtState.yielding)
		return
	end
	
	Services.Services[namespaceServicePair] = service
	return if not DebugMode then setmetatable(service, SERVICE_MT) else service
end

local function ASSERT_COLON_CHAR(entry, itemType)
	assert(not string.match(entry, ":"), `{itemType} {entry} contains prohibited character ':'`)	
end

function Services.new<T, E>(
	namespace: string,
	serviceID: string,
	fn: (Types.Microservice<T>, Types.Program) -> Types.Result<T, string>
): Types.Microservice<T>
	
	ASSERT_COLON_CHAR(namespace, "Namespace")
	ASSERT_COLON_CHAR(serviceID, "Service ID")
	
	-- namespaces are implicit from namespaces
	local ns = Namespaces[namespace]
	if not ns then
		ns = {}
		Namespaces[namespace] = ns
	end
	
	assert(not ns[serviceID], `{serviceID} is already a member of {namespace}`)
	local service = makeNamespaceService(namespace, serviceID, fn)
	ns[serviceID] = service
	return service
end

function Services.loadInternal(program: Types.Program)
	for id, service in Services.Services do
		if service.Enabled then
			task.defer(service.Spawn, service, program)
		end
	end

	-- wait for all services to publish
	for _, service in Services.Services do
		service:AwaitIfEnabled()
	end
end

function Services.PostInit()
	for id, service in Services.Services do
		local f = service.OnPostInit
		if f and service.Enabled then
			f(service)
		end
	end
end

return Services