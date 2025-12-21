local CollectionService = game:GetService("CollectionService")
local Modding = require(script.Parent.Modding)
local Reflect = require(script.Parent.Reflect)
local Signal = require(script.Parent.Signal)

type object = {}
type set<T> = { [T]: true }
type component<T = any> = {
	tag: string?,
	members: T & object,
}

local Component = {}
Component.OnComponentRemoved = Signal.new()
Component.OnComponentAdded = Signal.new()

local Bin = {} :: { [any]: any }
local AttachedTags = {} :: set<string>
local Components = {} :: set<component>
local ActiveComponents = {} :: { [Instance]: { [component]: object } }

local function constructComponent(instance: Instance, component: component): object
	local object = { instance = instance }
	return setmetatable(object, { __index = component.members }) :: any
end

local function registerInstance(instance: Instance)
	if not ActiveComponents[instance] then ActiveComponents[instance] = {} end
end

local function attachToTag(tag: string, component: component)
	if AttachedTags[tag] then error("[artwork.Component]: tag already in use: " .. tag, 2) end

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

function Component.Component<T>(members: T & object, tag: string?): component<T>
	local component = {
		tag = tag,
		members = members,
	}
	local componentId = Reflect.GetId(component)

	if typeof(component.tag) == "string" then Bin[componentId] = attachToTag(component.tag, component) end

	Components[component] = true
	return component
end

function Component.AddComponent(instance: Instance, component: component)
	if ActiveComponents[instance] and ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[artwork.Component]: expected Instance, got {typeof(instance)}`)

	registerInstance(instance)

	local object = constructComponent(instance, component)
	local objectId = Reflect.GetId(object)

	Bin[objectId] = instance.Destroying:Connect(function()
		Component.RemoveComponent(instance, component)
	end)

	ActiveComponents[instance][component] = object
	Modding.AddListener(object, { "onInit", "onStart", "onStop" })

	Component.OnComponentAdded:fire(object, instance)
end

function Component.RemoveComponent(instance: Instance, component: component)
	if not ActiveComponents[instance] or not ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[artwork.Component]: expected Instance, got {typeof(instance)}`)

	local object = ActiveComponents[instance][component]
	local objectId = Reflect.GetId(object)

	local connection = Bin[objectId]
	if connection.Connected then connection:Disconnect() end

	ActiveComponents[instance][component] = nil
	Modding.RemoveListener(object)

	Component.OnComponentRemoved:fire(object, instance)
end

function Component.ClearAllComponents(instance: Instance)
	if not ActiveComponents[instance] then return end

	for component in ActiveComponents[instance] do
		Component.RemoveComponent(instance, component)
	end
end

function Component.GetComponent<T>(instance: Instance, component: component<T>): T & object
	return ActiveComponents[instance][component] :: any
end

function Component.GetComponents(instance: Instance): { [component]: unknown }
	return ActiveComponents[instance]
end

return Component
