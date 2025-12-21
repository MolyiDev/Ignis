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
		visited[node] = true

		local object = Singletons[node]
		if not object then return end

		for _, dependency in object do
			if typeof(dependency) ~= "table" then continue end
			if Reflect.ReadMetadata(dependency, "singleton") == nil then continue end

			local name = Reflect.ReadMetadata(dependency, "name") :: string
			visitor(name)
		end

		currentSize += 1
		sorted[node] = currentSize
	end

	for _, node in objects do
		if visited[node] then continue end
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

function Core.Register<T>(members: T & object, isNotListener: boolean?, priority: number?): T
	local id = Reflect.GetId(members)
	local _priority = if typeof(priority) == "number" then priority else DEFAULT_PRIORITY

	Reflect.DefineMetadata(members, "singleton", true)
	Reflect.DefineMetadata(members, "priority", _priority)

	if not isNotListener then Modding.AddListener(members) end

	Singletons[id] = members
	return members
end

function Core.Listen(name: string, listener: (...any) -> ())
	return Modding.AddLifecycleListener(name, listener)
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

	local start = Modding.GetListeners("OnStart") :: { OnStart }
	local init = Modding.GetListeners("OnInit") :: { OnInit }
	local stop = Modding.GetListeners("OnStop") :: { OnStop }

	local sortedProviders = topologicalSort(providerIds)

	local function sort(a, b)
		local a_priority = Reflect.ReadMetadata(a, "priority") :: number
		local b_priority = Reflect.ReadMetadata(b, "priority") :: number

		if a_priority ~= b_priority then return a_priority > b_priority end

		local a_id = Reflect.GetId(a)
		local b_id = Reflect.GetId(b)

		return sortedProviders[a_id] > sortedProviders[b_id]
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
