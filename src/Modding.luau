local Signal = require(script.Parent.Signal)

type object = {}
type set<T> = { [T]: true }
type listener = {
	eventIds: set<string>,
	involvement: { set<object> },
}

type signal<T...> = Signal.Signal<T...>
type ListenerAddedEvent = signal<object>
type ListenerRemovedEvent = signal<object>

local internal = {
	listeners = {} :: { [object]: listener },
	lifecycleListeners = {} :: { [string]: set<object> },

	singletons = {} :: { [string]: object },

	listenerAdded = Signal.new() :: ListenerAddedEvent,
	listenerRemoved = Signal.new() :: ListenerRemovedEvent,
	listenerAddedEvents = {} :: { [string]: ListenerAddedEvent },
	listenerRemovedEvents = {} :: { [string]: ListenerRemovedEvent },
}

local Modding = {}

function Modding.AddListener(object: object, ignoreList: { string }?)
	if typeof(object) ~= "table" then error("[Framework.Modding]: object must be a table", 2) end

	local listener: listener = {
		eventIds = {},
		involvement = {},
	}

	for lifecycleEvent, callback in object do
		if typeof(lifecycleEvent) ~= "string" then continue end
		if typeof(callback) ~= "function" then continue end
		if ignoreList and table.find(ignoreList, lifecycleEvent) then continue end
		if listener.eventIds[lifecycleEvent] then continue end

		local lifecycleListener = internal.lifecycleListeners[lifecycleEvent]
		if not lifecycleListener then
			lifecycleListener = {}
			internal.lifecycleListeners[lifecycleEvent] = lifecycleListener
		end

		lifecycleListener[object] = true
		listener.eventIds[lifecycleEvent] = true
		listener.involvement[#listener.involvement + 1] = lifecycleListener

		local eventSignal = internal.listenerAddedEvents[lifecycleEvent]
		if eventSignal then eventSignal:fire(object) end
	end

	internal.listeners[object] = listener
	internal.listenerAdded:fire(object)
end

function Modding.RemoveListener(object: object)
	local listener = internal.listeners[object]
	if not listener then error("[Framework.Modding]: given object is not a listener", 2) end

	for _, set in listener.involvement do
		set[object] = nil
	end

	for id in listener.eventIds do
		local eventSignal = internal.listenerRemovedEvents[id]
		if not eventSignal then continue end
		eventSignal:fire(object)
	end

	internal.listeners[object] = nil
	internal.listenerRemoved:fire(object)
end

function Modding.AddLifecycleListener(name: string, callback: (...any) -> ())
	local object = {
		[name] = callback,
	}

	Modding.AddListener(object)
	return function()
		Modding.RemoveListener(object)
	end
end

function Modding.GetListeners(id: string): { object }?
	local listeners = internal.lifecycleListeners[id]
	if not listeners then return nil end

	local results = {}
	for listener in listeners do
		results[#results + 1] = listener
	end
	return results
end

function Modding.OnListenerAdded(callback: (object: object) -> (), id: string?)
	if id ~= nil then
		local existingListeners = internal.lifecycleListeners[id]
		if existingListeners then
			for existingListener in existingListeners do
				task.spawn(callback, existingListener)
			end
		end

		local event = internal.listenerAddedEvents[id]
		if not event then
			event = Signal.new()
			internal.listenerAddedEvents[id] = event
		end

		return event:connect(callback)
	else
		for object in internal.listeners do
			task.spawn(callback, object)
		end

		return internal.listenerAdded:connect(callback)
	end
end

function Modding.OnListenerRemoved(callback: (object: object) -> (), id: string?)
	if id ~= nil then
		local event = internal.listenerRemovedEvents[id]
		if not event then
			event = Signal.new()
			internal.listenerRemovedEvents[id] = event
		end

		return event:connect(callback)
	else
		return internal.listenerRemoved:connect(callback)
	end
end

return Modding
