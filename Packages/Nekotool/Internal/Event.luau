local Types = require(script.Parent.Types)

local EVENT_TS_MT = {
	__tostring = function<A...>(self: Types.Event<A...>)
		return `Event<{self.Name}>`
	end,
	__metatable = "The metatable is locked"
}

local function makeSignal<A...>(owner: Types.Event<A...>): Types.Signal<A...>
	return function(fn: (A...) -> ())
		local function disconnector()
			if not owner.Connections[disconnector] then return end
			owner.Connections[disconnector] = nil

			local onDisconnect = owner.OnDisconnect
			if onDisconnect then
				task.defer(onDisconnect, owner, disconnector)
			end
		end
		
		owner.Connections[disconnector] = fn

		local onConnect = owner.OnConnect
		if onConnect then task.defer(onConnect, owner, disconnector) end

		return disconnector
	end
end

return function<A...>(name: string): Types.Event<A...>
	local event = {}::Types.Event<A...>
	event.Name = name
	event.Signal = makeSignal(event)
	event.Connections = {}

	function event:Fire(...)
		for _, connectionEvent in self.Connections do
			task.defer(connectionEvent, ...)
		end
	end

	function event:DisconnectAll()
		local onDisconnect = self.OnDisconnect
		if onDisconnect then
			for _, connection in self.Connections do
				task.defer(onDisconnect, self, connection)
			end
		end
		table.clear(self.Connections)
	end

	return setmetatable(event, EVENT_TS_MT)
end