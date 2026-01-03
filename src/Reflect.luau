local Types = require(script.Parent.Types)

local HASH_PRIME = 5381

local Reflect = {}
Reflect.Enum = table.freeze({
	IsSingleton = 0,
	Priority = 1,
	Dependencies = 2,
	Source = 3,
})
local Metadata: { [number]: Types.Metadata } = {}
local Registry: { [number]: unknown } = {}

local function hash(data: unknown): number
	local str = tostring(data)
	local hashFinal = HASH_PRIME

	for i = 1, #str do
		local c = string.byte(str, i)
		hashFinal = (bit32.lshift(hashFinal, 5) + hashFinal) + c
	end

	return bit32.bxor(hashFinal, 0)
end

function Reflect.GetId<T>(object: T): number
	return hash(object)
end

function Reflect.Register<T>(object: T)
	local id = Reflect.GetId(object)
	if Registry[id] == nil then
		local data = Metadata[id]
		Metadata[id] = if typeof(data) == "table" then data else {}

		Registry[id] = object
	end
end

function Reflect.GetMetadata<T>(object: T): Types.Metadata
	Reflect.Register(object)

	local id = Reflect.GetId(object)
	return Metadata[id]
end

function Reflect.ReadMetadata<T>(object: T, key: number): unknown
	local metadata = Reflect.GetMetadata(object)
	return metadata[key]
end

function Reflect.SetMetadata<T>(object: T, key: number, value: unknown)
	local metadata = Reflect.GetMetadata(object)
	metadata[key] = value
end

return Reflect
