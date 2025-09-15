local Types = require(script.Parent.Types)
local Event = require(script.Parent.Event)
local Program = {
	Connections = {},
	Configs = {},
	InitEvent = Event("Program.Init"),
	UnloadingEvent = Event("Program.Unloading"),
} :: Types.Program

local Exports = {
	Plugin = nil,
	Init = Program.InitEvent.Signal,
	Unloading = Program.UnloadingEvent.Signal,
}

function Exports:IsRunningLocally()
	return Program.IsProbablyLocal
end

Program.Exports = Exports

setmetatable(Program, {
	__tostring = function(self: Types.Program)
		return `NekotoolProgram<{self.Name}>`
	end,
	__metatable = "The metatable is locked"
})
return Program::Types.Program