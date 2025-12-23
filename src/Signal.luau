--!native
--!optimize 2

export type Connection = {
	Connected: boolean,

	Disconnect: (self: Connection) -> (),
	Reconnect: (self: Connection) -> (),
}

type PrivateConnection = Connection & {
	VarArgs: { any }?,
	Signal: any,
	Next: PrivateConnection?,
	Previous: PrivateConnection?,
	Callback: (...any) -> (),
}

type PrivatePriorityConnection = Connection & {
	Priority: number,
	VarArgs: { any }?,
	Signal: any,
	Next: PrivatePriorityConnection?,
	Previous: PrivatePriorityConnection?,
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

type PrivateSignal<T...> = Signal<T...> & {
	Head: PrivateConnection?,
	IsFiring: boolean,
	IsProcessing: boolean,
	FiringQueue: { { [number]: unknown } },
	ProcessingQueue: { PrivateConnection },
}

type PrivatePrioritySignal<T...> = PrioritySignal<T...> & {
	Head: PrivatePriorityConnection?,
	IsFiring: boolean,
	IsProcessing: boolean,
	FiringQueue: { { [number]: unknown } },
	ProcessingQueue: { PrivatePriorityConnection },
}

-- Priority is in ascending order.
-- Lower means first fired.
local DEFAULT_PRIORITY = 0

local table_clear = table.clear
local table_unpack = table.unpack
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_running = coroutine.running
local task_spawn = task.spawn

local freeThreads: { thread } = {}

local function runCallback(callback, thread, ...)
	callback(...)
	freeThreads[#freeThreads + 1] = thread
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local function disconnect(self: PrivateConnection)
	if not self.Connected then return end
	self.Connected = false

	local next = self.Next
	local prev = self.Previous

	if next then next.Previous = prev end
	if prev then prev.Next = next end

	local signal = self.Signal
	if signal.Head == self then signal.Head = next end
end

local function linkConnection<T...>(self: PrivateSignal<T...>, cn: PrivateConnection)
	local head = self.Head
	cn.Next = head
	if head then head.Previous = cn end
	self.Head = cn
	cn.Previous = nil
end

local function linkConnectionPriority<T...>(self: PrivatePrioritySignal<T...>, cn: PrivatePriorityConnection)
	local head = self.Head
	local priority = cn.Priority

	if not head or priority <= head.Priority then
		cn.Next = head
		if head then head.Previous = cn end
		self.Head = cn
		cn.Previous = nil
		return
	end

	local current = head
	while current.Next and current.Next.Priority < priority do
		current = current.Next
	end

	local nextNode = current.Next

	current.Next = cn
	cn.Previous = current
	cn.Next = nextNode

	if nextNode then nextNode.Previous = cn end
end

--==[ Connection ]==--
local Connection = {}
Connection.__index = Connection

function Connection:__tostring()
	return "Connection"
end

function Connection.Reconnect(self: PrivatePriorityConnection)
	if self.Connected then return end
	self.Connected = true

	if not (self :: any).Priority then
		-- Standard connection
		linkConnection(self.Signal, self)
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

local function connectStandard<T...>(self: PrivateSignal<T...>, fn: (...any) -> (), ...: any): PrivateConnection
	local varargs = { ... }
	local cn = (
		setmetatable({
			Connected = true,
			VarArgs = if #varargs == 0 then nil else varargs,
			Signal = self,
			Next = false,
			Previous = false,
			Callback = fn,
		}, Connection) :: any
	) :: PrivateConnection

	if self.IsFiring then
		self.ProcessingQueue[#self.ProcessingQueue + 1] = cn
	else
		linkConnection(self, cn)
	end

	return cn
end

Signal.Connect = connectStandard

function Signal.Once<T...>(self: PrivateSignal<T...>, fn: (...any) -> (), ...: any): Connection
	local cn

	cn = connectStandard(self, function(...)
		disconnect(cn)
		fn(...)
	end, ...)

	return cn
end

function Signal.Wait<T...>(self: PrivateSignal<T...>): ...any
	local thread = coroutine_running()
	local cn

	cn = connectStandard(self, function(...)
		disconnect(cn)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

function Signal.Fire<T...>(self: PrivateSignal<T...>, ...: any)
	self.FiringQueue[#self.FiringQueue + 1] = { ... }

	if self.IsProcessing then return end
	self.IsProcessing = true
	local initialFiring = self.IsFiring

	self.IsFiring = true

	while #self.FiringQueue > 0 do
		local queue = self.FiringQueue
		self.FiringQueue = {}

		for i = 1, #queue do
			local args = queue[i] :: { any }
			local cn = self.Head

			while cn do
				if cn.Connected then
					local thread
					if #freeThreads > 0 then
						thread = freeThreads[#freeThreads]
						freeThreads[#freeThreads] = nil
					else
						thread = coroutine_create(yielder)
						coroutine_resume(thread)
					end

					if not cn.VarArgs then
						task_spawn(thread, cn.Callback, thread, table_unpack(args))
					else
						local callArgs = cn.VarArgs
						local len = #callArgs
						local count = len
						for _, value in args do
							count += 1
							callArgs[count] = value
						end

						task_spawn(thread, cn.Callback, thread, table_unpack(callArgs))

						for k = count, len + 1, -1 do
							callArgs[k] = nil
						end
					end
				end
				cn = cn.Next
			end
		end

		if not initialFiring then
			self.IsFiring = false
			local processingQueue = self.ProcessingQueue
			for i = 1, #processingQueue do
				linkConnection(self, processingQueue[i])
			end
			table_clear(processingQueue)
		end
	end

	self.IsProcessing = false
end

function Signal.FireSync<T...>(self: PrivateSignal<T...>, ...: any)
	local oldFiring = self.IsFiring
	self.IsFiring = true

	local cn = self.Head
	while cn do
		if cn.Connected then
			local success, err
			if not cn.VarArgs then
				success, err = pcall(cn.Callback, ...)
			else
				local callArgs = cn.VarArgs
				local len = #callArgs
				local count = len
				for _, value in { ... } do
					count += 1
					callArgs[count] = value
				end

				success, err = pcall(cn.Callback, table_unpack(callArgs))

				for k = count, len + 1, -1 do
					callArgs[k] = nil
				end
			end

			if not success then
				-- Send error without breaking the loop
				task_spawn(error, tostring(err))
			end
		end
		cn = cn.Next
	end

	self.IsFiring = oldFiring

	if not oldFiring then
		local processingQueue = self.ProcessingQueue
		for i = 1, #processingQueue do
			linkConnection(self, processingQueue[i])
		end
		table_clear(processingQueue)
	end
end

function Signal.DisconnectAll<T...>(self: PrivateSignal<T...>)
	local cn = self.Head

	while cn do
		disconnect(cn)
		cn = cn.Next
	end
end

function Signal.Destroy<T...>(self: PrivateSignal<T...>)
	self:DisconnectAll()
	table_clear(self)
	setmetatable(self, nil)
end

--==[ PrioritySignal ]==--
local PrioritySignal = {}
PrioritySignal.__index = PrioritySignal

function PrioritySignal:__tostring()
	return "PrioritySignal"
end

local function connectPriority<T...>(
	self: PrivatePrioritySignal<T...>,
	priority: number,
	fn: (...any) -> (),
	...: any
): PrivatePriorityConnection
	local varargs
	if select("#", ...) > 0 then varargs = { ... } end

	local cn = (
		setmetatable({
			Connected = true,
			Priority = priority,
			VarArgs = varargs,
			Signal = self,
			Next = false,
			Previous = false,
			Callback = fn,
		}, Connection) :: any
	) :: PrivatePriorityConnection

	if self.IsFiring then
		self.ProcessingQueue[#self.ProcessingQueue + 1] = cn
	else
		linkConnectionPriority(self, cn)
	end

	return cn
end

function PrioritySignal.Connect<T...>(self: PrivatePrioritySignal<T...>, fn: (...any) -> (), ...: any): Connection
	return connectPriority(self, DEFAULT_PRIORITY, fn, ...)
end

PrioritySignal.ConnectPriority = connectPriority

function PrioritySignal.Once<T...>(self: PrivatePrioritySignal<T...>, fn: (...any) -> (), ...: any): Connection
	local cn

	cn = connectPriority(self, DEFAULT_PRIORITY, function(...)
		disconnect(cn)
		fn(...)
	end, ...)

	return cn
end

function PrioritySignal.OncePriority<T...>(
	self: PrivatePrioritySignal<T...>,
	priority: number,
	fn: (...any) -> (),
	...: any
): Connection
	local cn

	cn = connectPriority(self, priority, function(...)
		disconnect(cn)
		fn(...)
	end, ...)

	return cn
end

function PrioritySignal.Wait<T...>(self: PrivatePrioritySignal<T...>): ...any
	local thread = coroutine_running()
	local cn

	cn = connectPriority(self, DEFAULT_PRIORITY, function(...)
		disconnect(cn)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

function PrioritySignal.WaitPriority<T...>(self: PrivatePrioritySignal<T...>, priority: number): ...any
	local thread = coroutine_running()
	local cn

	cn = connectPriority(self, priority, function(...)
		disconnect(cn)
		if coroutine_status(thread) == "suspended" then task_spawn(thread, ...) end
	end)

	return coroutine_yield()
end

function PrioritySignal.Fire<T...>(self: PrivatePrioritySignal<T...>, ...: any)
	self.FiringQueue[#self.FiringQueue + 1] = { ... }

	if self.IsProcessing then return end
	self.IsProcessing = true

	while #self.FiringQueue > 0 do
		local queue = self.FiringQueue
		self.FiringQueue = {}

		for i = 1, #queue do
			local args = queue[i] :: { any }
			local cn = self.Head

			while cn do
				if cn.Connected then
					local thread
					if #freeThreads > 0 then
						thread = freeThreads[#freeThreads]
						freeThreads[#freeThreads] = nil
					else
						thread = coroutine_create(yielder)
						coroutine_resume(thread)
					end

					if not cn.VarArgs then
						task_spawn(thread, cn.Callback, thread, table_unpack(args))
					else
						local callArgs = cn.VarArgs
						local len = #callArgs
						local count = len
						for _, value in args do
							count += 1
							callArgs[count] = value
						end

						task_spawn(thread, cn.Callback, thread, table_unpack(callArgs))

						for k = count, len + 1, -1 do
							callArgs[k] = nil
						end
					end
				end
				cn = cn.Next
			end
		end

		local processingQueue = self.ProcessingQueue
		for i = 1, #processingQueue do
			linkConnectionPriority(self, processingQueue[i])
		end
		table_clear(processingQueue)
	end

	self.IsProcessing = false
end

function PrioritySignal.FireSync<T...>(self: PrivatePrioritySignal<T...>, ...: any)
	local oldFiring = self.IsFiring
	self.IsFiring = true

	local cn = self.Head
	while cn do
		if cn.Connected then
			local success, err
			if not cn.VarArgs then
				success, err = pcall(cn.Callback, ...)
			else
				local callArgs = cn.VarArgs
				local len = #callArgs
				local count = len
				for _, value in { ... } do
					count += 1
					callArgs[count] = value
				end

				success, err = pcall(cn.Callback, table_unpack(callArgs))

				for k = count, len + 1, -1 do
					callArgs[k] = nil
				end
			end

			if not success then
				-- Send error without breaking the loop
				task_spawn(error, tostring(err))
			end
		end
		cn = cn.Next
	end

	self.IsFiring = oldFiring

	if not oldFiring then
		local processingQueue = self.ProcessingQueue
		for i = 1, #processingQueue do
			linkConnectionPriority(self, processingQueue[i])
		end
		table_clear(processingQueue)
	end
end

PrioritySignal.DisconnectAll = Signal.DisconnectAll
PrioritySignal.Destroy = Signal.Destroy

--==[ SignalStatic ]==--
local SignalStatic = {}

function SignalStatic.new<T...>(): Signal<T...>
	local self = setmetatable({
		Head = false,
		IsFiring = false,
		IsProcessing = false,
		FiringQueue = {},
		ProcessingQueue = {},
	}, Signal)

	return (self :: any) :: Signal<T...>
end

function SignalStatic.newPriority<T...>(): PrioritySignal<T...>
	local self = setmetatable({
		Head = false,
		IsFiring = false,
		IsProcessing = false,
		FiringQueue = {},
		ProcessingQueue = {},
	}, PrioritySignal)

	return (self :: any) :: PrioritySignal<T...>
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

return SignalStatic
