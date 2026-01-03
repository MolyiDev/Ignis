local Modding = require(script.Parent.Modding)
local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

type PrivateLifecycle = {
	Name: string,
	Signal: Signal.Signal<>,
	AddedConnection: Signal.Connection,
	RemovedConnection: Signal.Connection,
}

local Registry: { [string]: Types.Registry } = {}

local function connectListener(
	name: string,
	listener: Types.Object,
	entry: Types.Registry,
	source: any,
	sendSelf: boolean?
)
	if not entry.Listeners[source] then entry.Listeners[source] = {} end

	if entry.Listeners[source][listener] then return end

	local connection
	if sendSelf then
		connection = entry.Signal:Connect(function(...)
			listener[name](listener, ...)
		end)
	else
		connection = entry.Signal:Connect(function(...)
			listener[name](...)
		end)
	end

	entry.Listeners[source][listener] = connection
end

--==[ Lifecycle ]==--
local Lifecycle = {}
Lifecycle.__index = Lifecycle

function Lifecycle.Fire(self: PrivateLifecycle, ...)
	self.Signal:Fire(...)
end

function Lifecycle.FireSync(self: PrivateLifecycle, ...)
	self.Signal:FireSync(...)
end

function Lifecycle.Destroy(self: PrivateLifecycle)
	self.Signal:Destroy()
	self.AddedConnection:Disconnect()
	self.RemovedConnection:Disconnect()
	Registry[self.Name] = nil
end

--==[ Lifecycles ]==--
local Lifecycles = {} :: Types.PrivateLifecycles
Lifecycles._PendingManagers = {}
Lifecycles._IsIgnited = false

function Lifecycles.RegisterLifecycle<T...>(name: string, sendSelf: boolean?)
	local signal = Signal.new()

	Registry[name] = {
		Signal = signal,
		Listeners = {},
		Disconnected = {},
	}

	local addedConnection = Modding.OnListenerAdded(function(listener)
		local source = Reflect.ReadMetadata(listener, Reflect.Enum.Source)
		if not source then return end
		connectListener(name, listener, Registry[name], source, sendSelf)
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

	local lifecycle = (
		setmetatable({
			Name = name,
			Signal = signal,
			AddedConnection = addedConnection,
			RemovedConnection = removedConnection,
		}, Lifecycle) :: any
	) :: Types.Lifecycle<T...>

	return lifecycle
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
