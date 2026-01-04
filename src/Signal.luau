--!native
--!optimize 2

export type Connection = {
	Connected: boolean,

	Disconnect: (self: Connection) -> (),
	Reconnect: (self: Connection) -> (),
}

type PrivateConnection = Connection & {
	Priority: number,
	BoundArgs: { any }?,
	Signal: any,
	Next: PrivateConnection?,
	Previous: PrivateConnection?,
	Callback: (...any) -> (),
}

export type Signal<T...> = {
	Connect: <U...>(self: Signal<T...>, fn: (T...) -> (), U...) -> Connection,
	Once: <U...>(self: Signal<T...>, fn: (T...) -> (), U...) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	FireSync: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type PrioritySignal<T...> = Signal<T...> & {
	ConnectPriority: <U...>(self: PrioritySignal<T...>, priority: number, fn: (T...) -> (), U...) -> Connection,
	OncePriority: <U...>(self: PrioritySignal<T...>, priority: number, fn: (T...) -> (), U...) -> Connection,
	WaitPriority: (self: PrioritySignal<T...>, priority: number) -> T...,
}

type PrivateSignal = {
	Head: PrivateConnection?,
}

export type SignalStatic = {
	new: <T...>() -> Signal<T...>,
	newPriority: <T...>() -> PrioritySignal<T...>,
	IsSignal: (object: any) -> boolean,
	IsConnection: (object: any) -> boolean,
}

-- Priority is in ascending order.
-- Lower means first fired.
local DEFAULT_PRIORITY = 0

local table_unpack = table.unpack
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_running = coroutine.running
local task_spawn = task.spawn

local freeRunnerThread: thread?

local function runCallback(callback, ...)
	callback(...)
	freeRunnerThread = coroutine_running()
end

local function yielder()
	while true do
		runCallback(coroutine_yield())
	end
end

local function errorHandler(err)
	local message = tostring(err)
	local trace = debug.traceback(nil, 2)

	return string.format("\n[Signal] Error: %s\n%s", message, trace)
end

local function linkConnectionPriority(self: PrivateSignal, connection: PrivateConnection)
	local head = self.Head
	local priority = connection.Priority

	if not head or priority <= head.Priority then
		connection.Next = head
		if head then head.Previous = connection end
		self.Head = connection
		connection.Previous = nil
		return
	end

	local current = head
	while current.Next and current.Next.Priority < priority do
		current = current.Next
	end

	local nextNode = current.Next

	current.Next = connection
	connection.Previous = current
	connection.Next = nextNode

	if nextNode then nextNode.Previous = connection end
end

local function fire(self: PrivateSignal, ...: any)
	local connection = self.Head

	while connection do
		local thread = freeRunnerThread :: any
		if thread then
			freeRunnerThread = nil
		else
			thread = coroutine_create(yielder)
			coroutine_resume(thread)
		end

		if not connection.BoundArgs then
			task_spawn(thread, connection.Callback, ...)
		else
			local boundArgs = connection.BoundArgs
			local len = #boundArgs
			local count = len

			local argCount = select("#", ...)
			for i = 1, argCount do
				count += 1
				boundArgs[count] = select(i, ...)
			end

			task_spawn(thread, connection.Callback, table_unpack(boundArgs))

			for j = count, len + 1, -1 do
				boundArgs[j] = nil
			end
		end

		connection = connection.Next
	end
end

local function fireSync(self: PrivateSignal, ...: any)
	local connection = self.Head

	while connection do
		local success, err

		if not connection.BoundArgs then
			success, err = xpcall(connection.Callback, errorHandler, ...)
		else
			local boundArgs = connection.BoundArgs
			local len = #boundArgs
			local count = len

			local argCount = select("#", ...)
			for i = 1, argCount do
				count += 1
				boundArgs[count] = select(i, ...)
			end

			success, err = xpcall(connection.Callback, errorHandler, table_unpack(boundArgs))

			for j = count, len + 1, -1 do
				boundArgs[j] = nil
			end
		end

		if not success then task_spawn(error, err :: any, 0) end

		connection = connection.Next
	end
end

local function disconnect(self: PrivateConnection)
	if not self.Connected then return end
	self.Connected = false

	local nextNode = self.Next
	local prevNode = self.Previous
	local signal = self.Signal

	if nextNode then nextNode.Previous = prevNode end
	if prevNode then
		prevNode.Next = nextNode
	elseif signal.Head == self then
		signal.Head = nextNode
	end
end

local function disconnectAll(self: PrivateSignal)
	local connection = self.Head

	while connection do
		local nextConnection = connection.Next

		connection.Connected = false
		connection.Next = nil
		connection.Previous = nil

		connection = nextConnection
	end

	self.Head = nil
end

local function destroy(self: PrivateSignal)
	disconnectAll(self)
	setmetatable(self :: any, nil)
end

--==[ Connection ]==--
local Connection = {}
Connection.__index = Connection

function Connection:__tostring()
	return "Connection"
end

function Connection.Reconnect(self: PrivateConnection)
	if self.Connected then return end
	self.Connected = true

	if not (self :: any).Priority then
		-- Standard connection
		local signal = self.Signal
		local head = signal.Head
		self.Next = head
		if head then head.Previous = self end
		signal.Head = self
		self.Previous = nil

		return
	end

	-- Priority connection
	linkConnectionPriority(self.Signal, self)
end

Connection.Disconnect = disconnect

--==[ Signal ]==--
local Signal = {}
Signal.__index = Signal

function Signal:__tostring()
	return "Signal"
end

local function connectStandard(self: PrivateSignal, fn: (...any) -> (), ...: any): PrivateConnection
	local head = self.Head
	local boundArgs = if select("#", ...) > 0 then { ... } else nil

	local connection = (
		setmetatable({
			Callback = fn,
			Next = head,
			Signal = self,
			Connected = true,
			BoundArgs = boundArgs,
			Previous = nil,
		}, Connection) :: any
	) :: PrivateConnection

	if head then head.Previous = connection end
	self.Head = connection

	return connection
end

Signal.Connect = connectStandard

function Signal.Once(self: PrivateSignal, fn: (...any) -> (), ...: any): Connection
	local connection: PrivateConnection

	connection = connectStandard(self, function(...)
		disconnect(connection)
		fn(...)
	end, ...)

	return connection
end

function Signal.Wait(self: PrivateSignal): ...any
	local thread = coroutine_running()
	local connection: PrivateConnection

	connection = connectStandard(self, function(...)
		disconnect(connection)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

Signal.Fire = fire
Signal.FireSync = fireSync
Signal.DisconnectAll = disconnectAll
Signal.Destroy = destroy

--==[ PrioritySignal ]==--
local PrioritySignal = {}
PrioritySignal.__index = PrioritySignal

function PrioritySignal:__tostring()
	return "PrioritySignal"
end

local function connectPriority(self: PrivateSignal, priority: number, fn: (...any) -> (), ...: any): PrivateConnection
	local varargs = if select("#", ...) > 0 then { ... } else nil

	local connection = (
		setmetatable({
			Connected = true,
			Priority = priority,
			BoundArgs = varargs,
			Signal = self,
			Next = nil,
			Previous = nil,
			Callback = fn,
		}, Connection) :: any
	) :: PrivateConnection

	linkConnectionPriority(self, connection)

	return connection
end

function PrioritySignal.Connect(self: PrivateSignal, fn: (...any) -> (), ...: any): Connection
	return connectPriority(self, DEFAULT_PRIORITY, fn, ...)
end

PrioritySignal.ConnectPriority = connectPriority

function PrioritySignal.Once(self: PrivateSignal, fn: (...any) -> (), ...: any): Connection
	local connection: PrivateConnection

	connection = connectPriority(self, DEFAULT_PRIORITY, function(...)
		disconnect(connection)
		fn(...)
	end, ...)

	return connection
end

function PrioritySignal.OncePriority(self: PrivateSignal, priority: number, fn: (...any) -> (), ...: any): Connection
	local connection: PrivateConnection

	connection = connectPriority(self, priority, function(...)
		disconnect(connection)
		fn(...)
	end, ...)

	return connection
end

function PrioritySignal.Wait(self: PrivateSignal): ...any
	local thread = coroutine_running()
	local connection: PrivateConnection

	connection = connectPriority(self, DEFAULT_PRIORITY, function(...)
		disconnect(connection)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

function PrioritySignal.WaitPriority(self: PrivateSignal, priority: number): ...any
	local thread = coroutine_running()
	local connection: PrivateConnection

	connection = connectPriority(self, priority, function(...)
		disconnect(connection)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

PrioritySignal.Fire = fire
PrioritySignal.FireSync = fireSync
PrioritySignal.DisconnectAll = disconnectAll
PrioritySignal.Destroy = destroy

--==[ SignalStatic ]==--
local SignalStatic = {}

function SignalStatic.new<T...>(): Signal<T...>
	return (setmetatable({ Head = nil }, Signal) :: any) :: Signal<T...>
end

function SignalStatic.newPriority<T...>(): PrioritySignal<T...>
	return (setmetatable({ Head = nil }, PrioritySignal) :: any) :: PrioritySignal<T...>
end

function SignalStatic.IsConnection(obj: any): boolean
	return (type(obj) == "table" and getmetatable(obj) == Connection)
end

function SignalStatic.IsSignal(obj: any): boolean
	if not (type(obj) == "table") then return false end
	local metatable = getmetatable(obj)
	if metatable == Signal or metatable == PrioritySignal then return true end
	return false
end

return SignalStatic :: SignalStatic
