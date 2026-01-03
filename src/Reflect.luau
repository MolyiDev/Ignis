local Types = require(script.Parent.Types)

local Reflect = {}
Reflect.Enum = table.freeze({
	IsSingleton = 0,
	Priority = 1,
	Dependencies = 2,
	Source = 3,
})

local Metadata: { [any]: Types.Metadata } = setmetatable({}, { __mode = "k" }) :: any

function Reflect.GetMetadata<T>(object: T): Types.Metadata
	local data = Metadata[object]

	if not data then
		data = {}
		Metadata[object] = data
	end

	return data
end

function Reflect.ReadMetadata<T>(object: T, key: number): unknown
	local data = Metadata[object]
	return if data then data[key] else nil
end

function Reflect.SetMetadata<T>(object: T, key: number, value: unknown)
	local data = Reflect.GetMetadata(object)
	data[key] = value
end

return Reflect
