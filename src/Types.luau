local Signal = require(script.Parent.Signal)
export type Object = { [any]: any }
export type Predicate<T> = (T) -> boolean
export type Metadata = { [string]: unknown }
export type Set<T> = { [T]: true }
export type ListenerAddedEvent = Signal.Signal<Object>
export type ListenerRemovedEvent = Signal.Signal<Object>
export type Listener = {
	EventIds: Set<string>,
	Involvement: { Set<Object> },
}
export type Component<T = any> = {
	Tag: string?,
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

export type Lifecycles = {
	CreateLifecycle: <T...>(name: string, manager: (fire: (T...) -> ()) -> ()) -> () -> (),
	CreateClientLifecycle: (name: string, manager: (fire: () -> ()) -> ()) -> (() -> ())?,
	CreateServerLifecycle: (name: string, manager: (fire: () -> ()) -> ()) -> (() -> ())?,
}

export type PrivateLifecycles = Lifecycles & {
	_PendingManagers: { () -> () },
	_IsIgnited: boolean,
}

return nil
