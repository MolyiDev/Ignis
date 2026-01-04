local CollectionService = game:GetService("CollectionService")
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

local Components = {}
Components.OnComponentAdded = Signal.new()
Components.OnComponentRemoved = Signal.new()

local Bin = {} :: { [any]: any }
local AttachedTags = {} :: Types.Set<string>
local ComponentsSet = {} :: Types.Set<Types.Component>
local ActiveComponents = {} :: { [Instance]: { [Types.Component]: Types.Object } }

local function constructComponent(instance: Instance, component: Types.Component): Types.Object
	local object = { Instance = instance }
	return setmetatable(object, { __index = component.Members }) :: any
end

local function registerInstance(instance: Instance)
	if not ActiveComponents[instance] then ActiveComponents[instance] = {} end
end

local function shouldConstruct(instance: Instance, config: Types.ComponentConfig): boolean
	-- IsA Check
	if config.BaseClass and not instance:IsA(config.BaseClass) then return false end

	-- Ancestor Check
	if config.AncestorWhitelist and #config.AncestorWhitelist > 0 then
		local isWhitelisted = false
		for _, ancestor in config.AncestorWhitelist do
			if instance:IsDescendantOf(ancestor) then
				isWhitelisted = true
				break
			end
		end
		if not isWhitelisted then return false end
	end

	if config.AncestorBlacklist then
		for _, ancestor in config.AncestorBlacklist do
			if instance:IsDescendantOf(ancestor) then return false end
		end
	end

	-- Attribute Check
	if config.Attributes then
		for attribute, guard in config.Attributes do
			local value = instance:GetAttribute(attribute)
			if not guard(value) then return false end
		end
	end

	-- Predicate Check
	if config.Predicate and not config.Predicate(instance) then return false end

	return true
end

local function applyDefaults(instance: Instance, config: Types.ComponentConfig)
	if not config.Defaults then return end

	for key, value in config.Defaults do
		if instance:GetAttribute(key) == nil then instance:SetAttribute(key, value) end
	end
end

local function attachToTag(tag: string, component: Types.Component)
	if AttachedTags[tag] then error(`[Ignis Components]: Tag already in use: {tag}`, 2) end

	AttachedTags[tag] = true

	local function instanceAdded(instance: Instance)
		Components.AddComponent(instance, component)
	end

	local function instanceRemoved(instance: Instance)
		Components.RemoveComponent(instance, component)
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

function Components.Component<T>(members: T & Types.Object, config: Types.ComponentConfig?)
	local component: Types.Component = {
		Config = config or {},
		Instance = nil,
		Members = members,
	}

	-- Attach to tag if provided
	if component.Config.Tag then Bin[component] = attachToTag(component.Config.Tag, component) end

	ComponentsSet[component] = true
	return component
end

function Components.AddComponent(instance: Instance, component: Types.Component)
	if ActiveComponents[instance] and ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[Ignis Components] Expected Instance, got {typeof(instance)}`)

	applyDefaults(instance, component.Config)

	if not shouldConstruct(instance, component.Config) then return end

	registerInstance(instance)

	local object = constructComponent(instance, component)

	ActiveComponents[instance][component] = object

	Components.OnComponentAdded:Fire(object, instance)

	if object.OnSpawn then task.spawn(object.OnSpawn, object) end
end

function Components.RemoveComponent(instance: Instance, component: Types.Component)
	if not ActiveComponents[instance] or not ActiveComponents[instance][component] then return end
	assert(typeof(instance) == "Instance", `[Ignis Components]: Expected Instance, got {typeof(instance)}`)

	local object = ActiveComponents[instance][component]

	if object.OnDespawn then task.spawn(object.OnDespawn, object) end

	ActiveComponents[instance][component] = nil

	Components.OnComponentRemoved:Fire(object, instance)
end

function Components.ClearAllComponents(instance: Instance)
	if not ActiveComponents[instance] then return end

	for component in ActiveComponents[instance] do
		Components.RemoveComponent(instance, component)
	end
end

function Components.GetComponent<T>(instance: Instance, component: Types.Component<T>)
	return ActiveComponents[instance][component] :: any
end

function Components.GetComponents(instance: Instance)
	return ActiveComponents[instance]
end

return Components
