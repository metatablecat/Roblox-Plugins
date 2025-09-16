local Types = require(script.Internal.Types)
local Program = require(script.Internal.Program)
local Event = require(script.Internal.Event)
local MicroserviceCore = require(script.Internal.MicroserviceCore)

local Nekotool = {
	Version = script.Version.Value,
	Program = Program.Exports,
	
	-- This just returns the function, its here so Luau properly types the Program item
	-- This should be excalled (although I think it already is when its important?)
	extend = function(handler: (Types.ProgramExports) -> ())
		return handler
	end,
	
	-- this library might be used for microservices
	Service = MicroserviceCore.new,
	ModuleLoader = require(script.Internal.Loaders.ModuleLoader),
	Result = require(script.Internal.Result),
	Event = Event,
}

export type Event<A...> = Types.Event<A...>
export type Signal<A...> = Types.Signal<A...>
export type MicroserviceCore<T> = Types.Microservice<T>
export type Program = Types.Program
export type Result<T, E> = Types.Result<T, E>

setmetatable(Nekotool, {
	__tostring = function(self)
		return `Nekotool {self.Version}`
	end,
})

table.freeze(Nekotool)
return Nekotool