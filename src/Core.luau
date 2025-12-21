local Modding = require("./Modding")
local Reflect = require("./Reflect")

type object = { [any]: any }
type set<T> = { [T]: true }
type predicate<T> = (T) -> boolean

type OnStart = object & { OnStart: (self: OnStart) -> () }
type OnInit = object & { OnInit: (self: OnInit) -> () }
type OnStop = object & { OnStop: (self: OnStop) -> () }

type extender =
	& (<A>(A) -> A)
	& (<A, B>(A, B) -> A & B)
	& (<A, B, C>(A, B, C) -> A & B & C)
	& (<A, B, C, D>(A, B, C, D) -> A & B & C & D)
	& (<A, B, C, D, E>(A, B, C, D, E) -> A & B & C & D & E)
	& (<A, B, C, D, E, F>(A, B, C, D, E, F) -> A & B & C & D & E & F)
	& (<A, B, C, D, E, F, G>(A, B, C, D, E, F, G) -> A & B & C & D & E & F & G)
	& (<A, B, C, D, E, F, G, H>(A, B, C, D, E, F, G, H) -> A & B & C & D & E & F & G & H)
	& (<A, B, C, D, E, F, G, H, I>(A, B, C, D, E, F, G, H, I) -> A & B & C & D & E & F & G & H & I)
	& (<A, B, C, D, E, F, G, H, I, J>(A, B, C, D, E, F, G, H, I, J) -> A & B & C & D & E & F & G & H & I & J)
	& (<A, B, C, D, E, F, G, H, I, J, K>(A, B, C, D, E, F, G, H, I, J, K) -> A & B & C & D & E & F & G & H & I & J & K)
	& (<A, B, C, D, E, F, G, H, I, J, K, L>(
		A,
		B,
		C,
		D,
		E,
		F,
		G,
		H,
		I,
		J,
		K,
		L
	) -> A & B & C & D & E & F & G & H & I & J & K & L)

local DEFAULT_PRIORITY = 1
local Core = {}

local Singletons: { [string]: object } = {}
local PendingDependencies: { [string]: object } = {}
local IsIgnited = false
local HasShutdown = false

local function saferequire(module: ModuleScript): unknown
	local success, result = pcall(require, module)
	return success and result
end

local function extend(...)
	local result = {}

	for i = 1, select("#", ...) do
		local source = select(i, ...)
		for key, value in source do
			result[key] = value
		end
	end

	return result
end

local function topologicalSort(objects: { string }): { [string]: number }
	local currentSize = 0
	local sorted: { [string]: number } = {}
	local visited: { [string]: true } = {}

	local function visitor(node: string)
		if visited[node] then return end
		visited[node] = true

		local object = Singletons[node]
		if not object then return end

		local function processDependency(dependency: any)
			if typeof(dependency) ~= "table" then return end
			if Reflect.ReadMetadata(dependency, "singleton") == nil then return end

			local id = Reflect.GetId(dependency)
			visitor(id)
		end

		local dependencies = Reflect.ReadMetadata(object, "dependencies") :: { object }
		if dependencies then
			for _, dependency in dependencies do
				processDependency(dependency)
			end
		end

		for _, dependency in object do
			processDependency(dependency)
		end

		currentSize += 1
		sorted[node] = currentSize
	end

	for _, node in objects do
		visitor(node)
	end

	return sorted
end

function Core.LoadDescendants(parent: Instance, predicate: predicate<Instance>?)
	for _, descendant in parent:GetDescendants() do
		if predicate and not predicate(descendant) then continue end
		if not descendant:IsA("ModuleScript") then continue end

		saferequire(descendant)
	end
end

function Core.LoadChildren(parent: Instance, predicate: predicate<Instance>?)
	Core.LoadDescendants(parent, function(descendant: Instance)
		local isChild = descendant.Parent == parent
		return isChild and (not predicate or predicate(descendant))
	end)
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

function Core.Register<T>(members: T & object, dependencies: { object }?, priority: number?): T
	local id = Reflect.GetId(members)
	local _priority = if typeof(priority) == "number" then priority else DEFAULT_PRIORITY
	local _dependencies = if typeof(dependencies) == "table" then dependencies else {}

	local source = debug.info(2, "s")
	local pending = PendingDependencies[source]
	if pending then
		for _, dep in pending do
			_dependencies[#_dependencies + 1] = dep
		end

		PendingDependencies[source] = nil
	end

	Reflect.DefineMetadata(members, "singleton", true)
	Reflect.DefineMetadata(members, "priority", _priority)
	Reflect.DefineMetadata(members, "dependencies", _dependencies)

	Modding.AddListener(members)

	Singletons[id] = members
	return members
end

function Core.IsIgnited()
	return IsIgnited
end

function Core.HasShutdown()
	return HasShutdown
end

function Core.Ignite()
	if IsIgnited or HasShutdown then return end

	local providerIds: { string } = {}
	local metadata: { [string]: { id: string, priority: number, provider: object } } = {}
	for _, provider in Singletons do
		local id = Reflect.GetId(provider)
		local priority = Reflect.ReadMetadata(provider, "priority") :: number

		metadata[id] = { id = id, priority = priority, provider = provider }
		providerIds[#providerIds + 1] = id
	end

	local start = Modding.GetListeners("OnStart") :: { OnStart }?
	local init = Modding.GetListeners("OnInit") :: { OnInit }?
	local stop = Modding.GetListeners("OnStop") :: { OnStop }?

	local sortedProviders = topologicalSort(providerIds)

	local function sort(a, b)
		local aPriority = Reflect.ReadMetadata(a, "priority") :: number
		local bPriority = Reflect.ReadMetadata(b, "priority") :: number

		if aPriority ~= bPriority then return aPriority > bPriority end

		local aId = Reflect.GetId(a)
		local bId = Reflect.GetId(b)

		return sortedProviders[aId] > sortedProviders[bId]
	end

	if start then table.sort(start, sort) end

	if stop then table.sort(stop, sort) end

	if init then
		table.sort(init, sort)

		for _, listener in init do
			xpcall(listener.OnInit, function(result)
				warn(`[Flux]: Error in onInit listener: {result}`)
			end, listener)
		end
	end

	IsIgnited = true

	if start then
		for _, listener in start do
			task.spawn(listener.OnStart, listener)
		end
	end

	return function()
		if HasShutdown then return end

		if stop then
			for _, listener in stop do
				task.spawn(listener.OnStop, listener)
			end
		end

		HasShutdown = true
	end
end

Core.Extend = extend :: extender

return Core
