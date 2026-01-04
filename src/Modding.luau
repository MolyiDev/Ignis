local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

local Modding = {}

local ListenerAdded = Signal.new() :: Types.ListenerAddedEvent
local ListenerRemoved = Signal.new() :: Types.ListenerRemovedEvent

local ListenerAddedEvents = {} :: { [string]: Types.ListenerAddedEvent }
local ListenerRemovedEvents = {} :: { [string]: Types.ListenerRemovedEvent }

local LifecycleListeners = {} :: { [string]: Types.Set<Types.Object> }
local RegisteredLifecycles = {} :: { [string]: boolean }
local Listeners = setmetatable({}, { __mode = "k" }) :: { [Types.Object]: Types.Listener }

local function registerObjectForLifecycle(object: Types.Object, lifecycleEvent: string)
	if typeof(object[lifecycleEvent]) ~= "function" then return end

	local listener = Listeners[object]
	if not listener then return end

	if listener.EventIds[lifecycleEvent] then return end

	local lifecycleListener = LifecycleListeners[lifecycleEvent]
	if not lifecycleListener then
		lifecycleListener = {}
		LifecycleListeners[lifecycleEvent] = lifecycleListener
	end

	lifecycleListener[object] = true
	listener.EventIds[lifecycleEvent] = true
	listener.Involvement[#listener.Involvement + 1] = lifecycleListener

	local eventSignal = ListenerAddedEvents[lifecycleEvent]
	if eventSignal then eventSignal:Fire(object) end
end

function Modding.AddListener<T>(object: T, ignoreList: { string }?)
	if typeof(object) ~= "table" then error("[Ignis Modding] Object must be a table", 2) end

	if Reflect.GetMetadata(object, Reflect.Enum.Source) == nil then
		Reflect.SetMetadata(object, Reflect.Enum.Source, debug.info(2, "s"))
	end

	local listener: Types.Listener = {
		EventIds = {},
		Involvement = {},
	}

	Listeners[object] = listener

	for lifecycleEvent in RegisteredLifecycles do
		if ignoreList and table.find(ignoreList, lifecycleEvent) then continue end
		registerObjectForLifecycle(object, lifecycleEvent)
	end

	ListenerAdded:Fire(object)
end

function Modding.RemoveListener(object: Types.Object)
	local listener = Listeners[object]
	if not listener then error("[Ignis Modding] Given object is not a listener", 2) end

	for _, set in listener.Involvement do
		set[object] = nil
	end

	for id in listener.EventIds do
		local eventSignal = ListenerRemovedEvents[id]
		if not eventSignal then continue end
		eventSignal:Fire(object)
	end

	Listeners[object] = nil
	ListenerRemoved:Fire(object)
end

function Modding.RegisterLifecycle(name: string)
	if RegisteredLifecycles[name] then return end
	RegisteredLifecycles[name] = true
end

function Modding.GetListeners(name: string): { Types.Object }?
	local listeners = LifecycleListeners[name]
	if not listeners then return nil end

	local results = {}
	for listener in listeners do
		results[#results + 1] = listener
	end

	return results
end

function Modding.OnListenerAdded(callback: (object: Types.Object) -> (), id: string?)
	if id == nil then
		for object in Listeners do
			task.spawn(callback, object)
		end

		return ListenerAdded:Connect(callback)
	end

	local existingListeners = LifecycleListeners[id]
	if existingListeners then
		for existingListener in existingListeners do
			callback(existingListener)
		end
	end

	local event = ListenerAddedEvents[id]
	if not event then
		event = Signal.new()
		ListenerAddedEvents[id] = event
	end

	return event:Connect(callback)
end

function Modding.OnListenerRemoved(callback: (object: Types.Object) -> (), id: string?)
	if id == nil then return ListenerRemoved:Connect(callback) end

	local event = ListenerRemovedEvents[id]
	if not event then
		event = Signal.new()
		ListenerRemovedEvents[id] = event
	end

	return event:Connect(callback)
end

return Modding :: Types.Modding
