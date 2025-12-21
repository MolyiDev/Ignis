--!native
--!optimize 2

--[=[
    another luau signal implementation

    author: glaphyre
]=]
local shingo = {}
shingo.__index = shingo

--[=[
    a connection object that represents a relation between a signal and a callback
    ```lua
    local connection = signal:connect(function(...): ()
        --// ...
    end)

    --// disconnect the connection, stops the callback from running when fired
    connection:disconnect()
    ```
]=]
local connection = {}
connection.__index = connection

export type Connection<T... = ()> = typeof(setmetatable(
	{} :: {
		signal: Signal<T...>,
		next: Connection<T...>?,
		previous: Connection<T...>?,
		connected: boolean,
		callback: (T...) -> ()?,
	},
	{} :: typeof(connection)
))

--[=[
    disconnects the given connection from the signal
    ```lua
    -- stops the connected callback from running
    connection:disconnect()
    ```
]=]
function connection.disconnect<T...>(self: Connection<T...>)
	self.connected = false
	self.callback = nil
	if self.previous then self.previous.next = self.next end
	if self.next then self.next.previous = self.previous end
	local signal = self.signal
	if signal.head == self then signal.head = self.next end
end

--[=[
    a signal object to which callbacks can connect to
    ```lua
    --// creates a new signal object
    local my_signal = signal.new()
    ```
]=]
local signal = {}
signal.__index = signal

export type Signal<T... = ()> = typeof(setmetatable(
	{} :: {
		head: Connection<T...>?,
		is_firing: boolean,
		is_processing: boolean,
		firing_queue: { { [number]: unknown } },
		processing_queue: { Connection<T...>? },
	},
	{} :: typeof(signal)
))

local function link_connection_node<T...>(self: Signal<T...>, connection: Connection<T...>)
	local current = self.head
	connection.next = current
	if current then current.previous = connection end
	self.head = connection
end

local function process_fire_queue<T...>(self: Signal<T...>)
	if self.is_processing then return end
	self.is_processing = true

	local queue = self.firing_queue
	while #queue > 0 do
		self.is_firing = true
		local args = table.remove(queue, 1) :: { [number]: unknown }
		local current = self.head
		while current do
			task.spawn(current.callback, table.unpack(args))
			current = current.next
		end
		self.is_firing = false
		for _, connection in self.processing_queue do
			link_connection_node(self, connection)
		end
		table.clear(self.processing_queue)
	end
	table.clear(self.firing_queue)
	self.is_processing = false
end

--[=[
    @within Signal
    fires the signal with the given arguments

    @param ... the arguments to be fired with
]=]
function signal.fire<T...>(self: Signal<T...>, ...: T...)
	assert(self.firing_queue, "signal is destroyed")

	local argument_pack = table.pack(...)
	argument_pack.n = nil
	table.insert(self.firing_queue, argument_pack)
	process_fire_queue(self)
end

--[=[
    @within Signal
    connects a callback to the signal

    ```lua
    --// returns a connection object which can later be disconnected
    signal:connect(function(...): ()
        print("signal was fired!")
    end)

    signal:fire() --// signal was fired!
    signal:fire() --// signal was fired!
    ```

    @param callback the function to be connected
    @return `Connection<T...>`
]=]
function signal.connect<T...>(self: Signal<T...>, callback: (T...) -> ())
	local connection: Connection<T...> = setmetatable({
		signal = self,
		connected = false,
		callback = callback,
	}, connection)
	if self.is_firing then
		table.insert(self.processing_queue, connection)
		return connection
	end
	link_connection_node(self, connection)
	return connection
end

--[=[
    @within Signal
    connects a callback to the signal which will only run once

    ```lua
    signal:once(function(...): ()
        print("this will only run once!")
    end)

    signal:fire() --// this will only run once!
    signal:fire() --// prints nothing
    ```

    @param callback the function to be connected
    @return `Connection<T...>`
]=]
function signal.once<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local connection: Connection<T...>
	connection = signal.connect(self, function(...)
		connection:disconnect()
		callback(...)
	end)
	return connection
end

--[=[
    @within Signal
    
    yields the current thread until the signal is fired.
    ```lua
    local number = my_signal:wait() --// Signal<number>
    print(`i waited and i got {number}!`)
    ```
    
    @return `...: T...`
]=]
function signal.wait<T...>(self: Signal<T...>): T...
	local thread = coroutine.running()
	local connection: Connection<T...>
	connection = signal.connect(self, function(...)
		connection:disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

--[=[
    @within Signal

    disconnects all connections and makes it unusable
    ```lua
    signal:destroy()
    signal:fire() --// error: signal is destroyed
    ```
]=]
function signal.destroy<T...>(self: Signal<T...>): ()
	local current = self.head
	while current do
		current:disconnect()
		current = current.next
	end
	table.clear(self.firing_queue)
	table.clear(self.processing_queue)
	self.head = nil
	self.firing_queue = nil :: any
end

--[=[
    checks whether the given value is a signal

    @param value the value to be checked

    @return true iff value is a signal, false otherwise
]=]
local function is_signal(value: any): boolean
	return (type(value) == "table" and getmetatable(value) == signal)
end

shingo.is_signal = is_signal

--[=[
    checks whether the given value is a connection

    @param value the value to be checked

    @return true iff value is a connection, false otherwise
]=]
local function is_connection(value: any): boolean
	return (type(value) == "table" and getmetatable(value) == connection)
end

shingo.is_connection = is_connection

--[=[
    creates a new signal

    @return `Signal<T...>`
]=]
function shingo.new<T...>(): Signal<T...>
	local self = setmetatable({
		head = nil,
		is_firing = false,
		is_processing = false,
		firing_queue = {},
		processing_queue = {},
	}, signal)
	return self
end

return shingo
