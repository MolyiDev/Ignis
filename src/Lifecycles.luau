local RunService = game:GetService("RunService")
local Modding = require(script.Parent.Modding)
local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

local Lifecycles = {} :: Types.PrivateLifecycles
Lifecycles._PendingManagers = {}
Lifecycles._IsIgnited = false

local Registry: { [string]: Types.Registry } = {}

local function connectListener(name: string, listener: Types.Object, entry: Types.Registry, source: any)
	if not entry.Listeners[source] then entry.Listeners[source] = {} end

	if entry.Listeners[source][listener] then return end

	local connection
	connection = entry.Signal:Connect(function(...)
		listener[name](...)
	end)

	entry.Listeners[source][listener] = connection
end

local function registerLifecycle(name: string)
	local signal = Signal.new()

	Registry[name] = {
		Signal = signal,
		Listeners = {},
		Disconnected = {},
	}

	local addedConnection = Modding.OnListenerAdded(function(listener)
		local source = Reflect.ReadMetadata(listener, Reflect.Enum.Source)
		if not source then return end
		connectListener(name, listener, Registry[name], source)
	end, name)

	local removedConnection = Modding.OnListenerRemoved(function(listener)
		local entry = Registry[name]
		if not entry then return end

		local source = Reflect.ReadMetadata(listener, Reflect.Enum.Source)
		if not source then return end

		if entry.Listeners[source] then
			local connection = entry.Listeners[source][listener]
			if connection then
				connection:Disconnect()
				entry.Listeners[source][listener] = nil
			end
		end

		if entry.Disconnected[source] then entry.Disconnected[source][listener] = nil end
	end, name)

	local function fire(...)
		signal:Fire(...)
	end

	local function fireSync(...)
		signal:FireSync(...)
	end

	local function destroy()
		addedConnection:Disconnect()
		removedConnection:Disconnect()
		signal:Destroy()
		Registry[name] = nil
	end

	return fire, fireSync, destroy
end

function Lifecycles.CreateLifecycle<T...>(name: string, manager: (fire: (T...) -> (), fireSync: (T...) -> ()) -> ())
	local fire, fireSync, destroy = registerLifecycle(name)

	if Lifecycles._IsIgnited then
		manager(fire, fireSync)
	else
		Lifecycles._PendingManagers[#Lifecycles._PendingManagers + 1] = function()
			manager(fire, fireSync)
		end
	end

	return destroy
end

function Lifecycles.CreateClientLifecycle<T...>(name: string, manager: (fire: (T...) -> (), fireSync: (T...) -> ()) -> ())
	if RunService:IsServer() then return nil end
	return Lifecycles.CreateLifecycle(name, manager)
end

function Lifecycles.CreateServerLifecycle<T...>(name: string, manager: (fire: (T...) -> (), fireSync: (T...) -> ()) -> ())
	if not RunService:IsServer() then return nil end
	return Lifecycles.CreateLifecycle(name, manager)
end

function Lifecycles.RegisterLifecycle(name: string)
	return registerLifecycle(name)
end

function Lifecycles.Disconnect(name: string)
	local source = debug.info(2, "s")
	local entry = Registry[name]

	if entry and entry.Listeners[source] then
		local disconnectedTable = entry.Disconnected[source]

		if not disconnectedTable then
			disconnectedTable = {}
			entry.Disconnected[source] = disconnectedTable
		end

		for listener, connection in entry.Listeners[source] do
			connection:Disconnect()
			disconnectedTable[listener] = true
		end

		table.clear(entry.Listeners[source])
	end
end

function Lifecycles.Reconnect(name: string)
	local source = debug.info(2, "s")
	local entry = Registry[name]

	if entry and entry.Disconnected[source] then
		for listener in entry.Disconnected[source] do
			connectListener(name, listener, entry, source)
		end

		table.clear(entry.Disconnected[source])
	end
end

return Lifecycles :: Types.Lifecycles
