local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

local Modding = {}
local LifecycleListeners = {} :: { [string]: Types.Set<Types.Object> }
local ListenerAdded = Signal.new() :: Types.ListenerAddedEvent
local ListenerRemoved = Signal.new() :: Types.ListenerRemovedEvent
local ListenerAddedEvents = {} :: { [string]: Types.ListenerAddedEvent }
local ListenerRemovedEvents = {} :: { [string]: Types.ListenerRemovedEvent }
local Listeners = {} :: { [Types.Object]: Types.Listener }

function Modding.AddListener<T>(object: T, ignoreList: { string }?)
	if typeof(object) ~= "table" then error("[Flux.Modding]: Object must be a table", 2) end

	if Reflect.GetMetadata(object, Reflect.Enum.Source) == nil then
		Reflect.SetMetadata(object, Reflect.Enum.Source, debug.info(2, "s"))
	end

	local listener: Types.Listener = {
		EventIds = {},
		Involvement = {},
	}

	for lifecycleEvent, callback in object do
		if typeof(lifecycleEvent) ~= "string" then continue end
		if typeof(callback) ~= "function" then continue end
		if ignoreList and table.find(ignoreList, lifecycleEvent) then continue end
		if listener.EventIds[lifecycleEvent] then continue end

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

	Listeners[object] = listener
	ListenerAdded:Fire(object)
end

function Modding.RemoveListener(object: Types.Object)
	local listener = Listeners[object]
	if not listener then error("[Flux.Modding]: Given object is not a listener", 2) end

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

function Modding.AddLifecycleListener(name: string, callback: (...any) -> ())
	local source = debug.info(2, "s")
	local object = {
		[name] = callback,
	}

	Reflect.SetMetadata(object, Reflect.Enum.Source, source)

	Modding.AddListener(object)
	return function()
		Modding.RemoveListener(object)
	end
end

function Modding.GetListeners(id: string): { Types.Object }?
	local listeners = LifecycleListeners[id]
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

return Modding
