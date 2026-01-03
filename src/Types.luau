local Signal = require(script.Parent.Signal)

export type Object = { [any]: any }
export type Predicate<T> = (T) -> boolean
export type Metadata = { [number]: unknown }
export type Set<T> = { [T]: true }
export type ListenerAddedEvent = Signal.Signal<Object>
export type ListenerRemovedEvent = Signal.Signal<Object>
export type Listener = {
	EventIds: Set<string>,
	Involvement: { Set<Object> },
}
export type Component<T = any> = {
	Tag: string?,
	Instance: Instance?,
	Members: T & Object,
}

export type OnStart = Object & { OnStart: (self: OnStart) -> () }
export type OnInit = Object & { OnInit: (self: OnInit) -> () }
export type OnStop = Object & { OnStop: (self: OnStop) -> () }

export type Extended =
	& (<A, B>(self: A, B) -> A & B)
	& (<A, B, C>(self: A, B, C) -> A & B & C)
	& (<A, B, C, D>(self: A, B, C, D) -> A & B & C & D)
	& (<A, B, C, D, E>(self: A, B, C, D, E) -> A & B & C & D & E)
	& (<A, B, C, D, E, F>(self: A, B, C, D, E, F) -> A & B & C & D & E & F)

export type Lifecycle<T...> = {
	Fire: (self: Lifecycle<T...>, T...) -> (),
	FireSync: (self: Lifecycle<T...>, T...) -> (),
	Destroy: (self: Lifecycle<T...>) -> (),
}

export type Lifecycles = {
	RegisterLifecycle: <T...>(name: string, sendSelf: boolean?) -> Lifecycle<T...>,
	Disconnect: (name: string) -> (),
	Reconnect: (name: string) -> (),
}

export type PrivateLifecycles = Lifecycles & {
	_PendingManagers: { () -> () },
	_IsIgnited: boolean,
}

export type Registry = {
	Signal: Signal.Signal<...any>,
	Listeners: { [any]: { [any]: any } },
	Disconnected: { [any]: { [any]: any } },
}

return nil
