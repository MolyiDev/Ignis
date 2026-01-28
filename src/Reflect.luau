local Types = require(script.Parent.Types)

local Reflect = {}
Reflect.Enum = table.freeze({
	Priority = 0,
	Dependencies = 1,
	Source = 2,
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

function Reflect.HasMetadata<T>(object: T): boolean
	return Metadata[object] ~= nil
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
