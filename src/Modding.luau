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

local Modding = {}
local LifecycleListeners = {} :: { [string]: set<object> }
local ListenerAdded = Signal.new() :: ListenerAddedEvent
local ListenerRemoved = Signal.new() :: ListenerRemovedEvent
local ListenerAddedEvents = {} :: { [string]: ListenerAddedEvent }
local ListenerRemovedEvents = {} :: { [string]: ListenerRemovedEvent }
local Listeners = {} :: { [object]: listener }

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

		local lifecycleListener = LifecycleListeners[lifecycleEvent]
		if not lifecycleListener then
			lifecycleListener = {}
			LifecycleListeners[lifecycleEvent] = lifecycleListener
		end

		lifecycleListener[object] = true
		listener.eventIds[lifecycleEvent] = true
		listener.involvement[#listener.involvement + 1] = lifecycleListener

		local eventSignal = ListenerAddedEvents[lifecycleEvent]
		if eventSignal then eventSignal:fire(object) end
	end

	Listeners[object] = listener
	ListenerAdded:fire(object)
end

function Modding.RemoveListener(object: object)
	local listener = Listeners[object]
	if not listener then error("[Framework.Modding]: given object is not a listener", 2) end

	for _, set in listener.involvement do
		set[object] = nil
	end

	for id in listener.eventIds do
		local eventSignal = ListenerRemovedEvents[id]
		if not eventSignal then continue end
		eventSignal:fire(object)
	end

	Listeners[object] = nil
	ListenerRemoved:fire(object)
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
	local listeners = LifecycleListeners[id]
	if not listeners then return nil end

	local results = {}
	for listener in listeners do
		results[#results + 1] = listener
	end
	return results
end

function Modding.OnListenerAdded(callback: (object: object) -> (), id: string?)
	if id ~= nil then
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

		return event:connect(callback)
	else
		for object in Listeners do
			task.spawn(callback, object)
		end

		return ListenerAdded:connect(callback)
	end
end

function Modding.OnListenerRemoved(callback: (object: object) -> (), id: string?)
	if id ~= nil then
		local event = ListenerRemovedEvents[id]
		if not event then
			event = Signal.new()
			ListenerRemovedEvents[id] = event
		end

		return event:connect(callback)
	else
		return ListenerRemoved:connect(callback)
	end
end

return Modding
