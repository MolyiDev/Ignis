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

export type AttributeGuard = (value: any) -> boolean

export type ComponentConfig = {
	-- CollectionService Tag
	Tag: string?,
	-- Only attach to instances of this class (IsA check)
	BaseClass: string?,
	-- Custom condition for attachment
	Predicate: ((Instance) -> boolean)?,
	-- Only attach if descendant of one of these
	AncestorWhitelist: { Instance }?,
	-- Do not attach if descendant of one of these
	AncestorBlacklist: { Instance }?,
	-- Default attribute values to apply if missing
	Defaults: { [string]: any }?,
	-- Attribute validation functions (Guards)
	Attributes: { [string]: AttributeGuard }?,
}

export type BaseComponent<T> = {
	Instance: T,
}

export type Component<T = any> = {
	Config: ComponentConfig,
	Instance: Instance?,
	Members: T & Object,
}

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

export type Registry = {
	Signal: Signal.Signal<...any>,
	Listeners: { [any]: { [any]: any } },
	Disconnected: { [any]: { [any]: any } },
}

export type Modding = {
	AddListener: <T>(object: T, ignoreList: { string }?) -> (),
	RemoveListener: (object: Object) -> (),
	GetListeners: (name: string) -> { Object }?,
	OnListenerAdded: (callback: (object: Object) -> (), id: string?) -> Signal.Connection,
	OnListenerRemoved: (callback: (object: Object) -> (), id: string?) -> Signal.Connection,
}

export type PrivateModding = Modding & {
	RegisterLifecycle: (name: string) -> (),
}

export type Components = {
	Component: <T>(members: T & Object, config: ComponentConfig?) -> (),
	AddComponent: (instance: Instance, component: Component) -> (),
	RemoveComponent: (instance: Instance, component: Component) -> (),
	ClearAllComponents: (instance: Instance) -> (),
	GetComponent: <T>(instance: Instance, component: Component<T>) -> (),
	GetComponents: (instance: Instance) -> (),
}

export type PrivateComponents = Components & {
	Start: () -> (),
	Stop: () -> (),
}

return nil
