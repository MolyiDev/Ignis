local Types = require(script.Parent.Types)
local Lifecycles = require(script.Parent.Lifecycles)
local Modding = require(script.Parent.Modding)
local Reflect = require(script.Parent.Reflect)
local Components = require(script.Parent.Components) :: Types.PrivateComponents

local DEFAULT_PRIORITY = 0

local Core = {}
Core.DefaultLifecycles = {
	OnInit = "OnInit",
	OnStart = "OnStart",
	OnStop = "OnStop",
}

local onInit = Lifecycles.RegisterLifecycle(Core.DefaultLifecycles.OnInit, true)
local onStart = Lifecycles.RegisterLifecycle(Core.DefaultLifecycles.OnStart, true)
local onStop = Lifecycles.RegisterLifecycle(Core.DefaultLifecycles.OnStop, true)

local Singletons: { any } = {}
local Priorities: { [number]: number } = {}
local PendingDependencies: { [string]: Types.Object } = {}
local IsIgnited = false
local HasShutdown = false

local function safeRequire(module: ModuleScript)
	local success, err = pcall(require, module)
	if not success then error(`[Ignis] Failed to load module '{module:GetFullName()}': {err}`, 0) end
end

local function topologicalSort(objects: { any }): { any }
	local sorted = {}
	local visited = {}

	local function visitor(node: any)
		if visited[node] then return end
		visited[node] = true

		local dependencies = Reflect.ReadMetadata(node, Reflect.Enum.Dependencies) :: { Types.Object }

		if dependencies then
			for _, dependency in dependencies do
				if Reflect.ReadMetadata(dependency, Reflect.Enum.IsSingleton) then visitor(dependency) end
			end
		end

		for _, dependency in node do
			if typeof(dependency) == "table" and Reflect.ReadMetadata(dependency, Reflect.Enum.IsSingleton) then
				visitor(dependency)
			end
		end

		sorted[#sorted + 1] = node
	end

	for _, node in objects do
		visitor(node)
	end

	return sorted
end

function Core.LoadDescendants(parent: Instance, predicate: Types.Predicate<Instance>?)
	for _, descendant in parent:GetDescendants() do
		if not descendant:IsA("ModuleScript") then continue end
		if predicate and not predicate(descendant) then continue end

		safeRequire(descendant)
	end
end

function Core.LoadChildren(parent: Instance, predicate: Types.Predicate<Instance>?)
	for _, child in parent:GetChildren() do
		if not child:IsA("ModuleScript") then continue end
		if predicate and not predicate(child) then continue end

		safeRequire(child)
	end
end

function Core.Dependency<T>(dependency: T)
	local source = debug.info(2, "s")

	local list = PendingDependencies[source]
	if not list then
		list = {}
		PendingDependencies[source] = list
	end

	list[#list + 1] = dependency
	return dependency
end

function Core.Register<T>(members: T, dependencies: { any }?, priority: number?): T
	priority = if typeof(priority) == "number" then priority else nil
	dependencies = if typeof(dependencies) == "table" then dependencies else {}

	local source = debug.info(2, "s")
	local pending = PendingDependencies[source]
	if pending then
		for _, dep in pending do
			dependencies[#dependencies + 1] = dep
		end

		PendingDependencies[source] = nil
	end

	Reflect.SetMetadata(members, Reflect.Enum.IsSingleton, true)
	Reflect.SetMetadata(members, Reflect.Enum.Priority, priority)
	Reflect.SetMetadata(members, Reflect.Enum.Dependencies, dependencies)
	Reflect.SetMetadata(members, Reflect.Enum.Source, source)

	Singletons[#Singletons + 1] = members
	return members
end

function Core.IsIgnited()
	return IsIgnited
end

function Core.HasShutdown()
	return HasShutdown
end

function Core.GetPriority(): number
	local source = debug.info(2, "s")
	return Priorities[source] or DEFAULT_PRIORITY
end

function Core.Ignite()
	if IsIgnited then error("[Ignis] Cannot ignite framework twice.", 2) end
	if HasShutdown then error("[Ignis] Framework is shutdown; cannot re-ignite.", 2) end

	local sortedSingletons = topologicalSort(Singletons)

	for i = #sortedSingletons, 1, -1 do
		local singleton = sortedSingletons[i]

		-- Topological sort index is the priority.
		local priority = i
		Reflect.SetMetadata(singleton, Reflect.Enum.Priority, priority)

		local source = Reflect.ReadMetadata(singleton, Reflect.Enum.Source) :: number
		if source then Priorities[source] = priority end

		Modding.AddListener(singleton)
	end

	onInit:FireSync()

	onStart:Fire()

	Components.Start()

	IsIgnited = true

	return function()
		if HasShutdown then return end

		onStop:Fire()

		onInit:Destroy()
		onStart:Destroy()
		onStop:Destroy()

		Components.Stop()

		HasShutdown = true
	end
end

return Core
