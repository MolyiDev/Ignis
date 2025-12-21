local RunService = game:GetService("RunService")
local Modding = require("./Modding")

local Lifecycles = {}

function Lifecycles.CreateClientLifecycle(name: string, manager: (fire: () -> ()) -> ())
	if RunService:IsServer() then return end
	return Lifecycles.CreateLifecycle(name, manager)
end

function Lifecycles.CreateServerLifecycle(name: string, manager: (fire: () -> ()) -> ())
	if not RunService:IsServer() then return end
	return Lifecycles.CreateLifecycle(name, manager)
end

function Lifecycles.CreateLifecycle<T...>(name: string, manager: (fire: (T...) -> ()) -> ())
	local listeners = {}

	local addedConnection = Modding.OnListenerAdded(function(listener)
		listeners[listener] = true
	end, name)
	local removedConnection = Modding.OnListenerRemoved(function(listener)
		listeners[listener] = nil
	end, name)

	local function fire(...: T...)
		for listener in listeners do
			task.spawn(listener[name], ...)
		end
	end

	manager(fire)

	return function()
		addedConnection:disconnect()
		removedConnection:disconnect()
	end
end

return Lifecycles
