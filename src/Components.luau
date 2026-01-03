local CollectionService = game:GetService("CollectionService")
local Core = require(script.Parent.Core)
local Modding = require(script.Parent.Modding)
local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

local Component = {}
Component.OnComponentRemoved = Signal.new()
Component.OnComponentAdded = Signal.new()

local Bin = {} :: { [any]: any }
local AttachedTags = {} :: Types.Set<string>
local Components = {} :: Types.Set<Types.Component>
local ActiveComponents = {} :: { [Instance]: { [Types.Component]: Types.Object } }

local function constructComponent(instance: Instance, component: Types.Component): Types.Object
	local object = { instance = instance }
	return setmetatable(object, { __index = component.Members }) :: any
end

local function registerInstance(instance: Instance)
	if not ActiveComponents[instance] then ActiveComponents[instance] = {} end
end

local function attachToTag(tag: string, component: Types.Component)
	if AttachedTags[tag] then error(`[Flux Components]: Tag already in use: {tag}`, 2) end

	AttachedTags[tag] = true

	local function instanceAdded(instance: Instance)
		Component.AddComponent(instance, component)
	end

	local function instanceRemoved(instance: Instance)
		Component.RemoveComponent(instance, component)
	end

	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(instanceAdded)
	local removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(instanceRemoved)

	for _, instance in CollectionService:GetTagged(tag) do
		instanceAdded(instance)
	end

	return function()
		addedConnection:Disconnect()
		removedConnection:Disconnect()
	end
end

function Component.Component<T>(members: T & Types.Object, tag: string?)
	local component: Types.Component = {
		Tag = tag,
		Members = members,
	}

	if typeof(component.Tag) == "string" then Bin[component] = attachToTag(component.Tag, component) end

	Components[component] = true
	return component
end

function Component.AddComponent(instance: Instance, component: Types.Component)
	if ActiveComponents[instance] and ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[Flux Components] Expected Instance, got {typeof(instance)}`)

	registerInstance(instance)

	local object = constructComponent(instance, component)

	Bin[object] = instance.Destroying:Connect(function()
		Component.RemoveComponent(instance, component)
	end)

	ActiveComponents[instance][component] = object
	Modding.AddListener(object, { "OnInit", "OnStart", "OnStop" })

	Component.OnComponentAdded:Fire(object, instance)
end

function Component.RemoveComponent(instance: Instance, component: Types.Component)
	if not ActiveComponents[instance] or not ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[Flux Components]: Expected Instance, got {typeof(instance)}`)

	local object = ActiveComponents[instance][component]

	local connection = Bin[object]
	if connection and connection.Connected then connection:Disconnect() end
	Bin[object] = nil

	ActiveComponents[instance][component] = nil
	Modding.RemoveListener(object)

	Component.OnComponentRemoved:Fire(object, instance)
end

function Component.ClearAllComponents(instance: Instance)
	if not ActiveComponents[instance] then return end

	for component in ActiveComponents[instance] do
		Component.RemoveComponent(instance, component)
	end
end

function Component.GetComponent<T>(instance: Instance, component: Types.Component<T>)
	return ActiveComponents[instance][component] :: any
end

function Component.GetComponents(instance: Instance)
	return ActiveComponents[instance]
end

return Component
