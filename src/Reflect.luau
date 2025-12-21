local HttpService = game:GetService("HttpService")

type object = {}
type metadata = { [string]: unknown }

local internal = {
	metadata = {} :: { [string]: { [string]: unknown } },
	registry = {} :: { [string]: unknown },
}

local Reflect = {}

local function tostring(data: unknown): string
	return HttpService:JSONEncode(data)
end

local function hash(data: unknown): string
	local str = tostring(data)
	local hash = 5381

	for i = 1, #str do
		local c = string.byte(str, i)
		hash = (bit32.lshift(hash, 5) + hash) + c
	end

	return `reflect:{bit32.bxor(hash, 0)}`
end

function Reflect.GetId(object: object): string
	return hash(object)
end

function Reflect.Register(object: object)
	local id = Reflect.GetId(object)
	if internal.registry[id] == nil then
		local data = internal.metadata[id]
		internal.metadata[id] = if typeof(data) == "table" then data else {}

		internal.registry[id] = object
	end
end

function Reflect.GetMetadata(object: object): metadata
	Reflect.Register(object)

	local id = Reflect.GetId(object)
	return internal.metadata[id]
end

function Reflect.ReadMetadata(object: object, key: string): unknown
	local metadata = Reflect.GetMetadata(object)
	return metadata[key]
end

function Reflect.DefineMetadata(object: object, key: string, value: unknown)
	local metadata = Reflect.GetMetadata(object)
	metadata[key] = value
end

return Reflect
