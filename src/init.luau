local Core = require(script.Core)
local Lifecycles = require(script.Lifecycles)
local Modding = require(script.Modding)
local Types = require(script.Types)

local extend = (
	function(...)
		local result = {}

		for i = 1, select("#", ...) do
			local source = select(i, ...)
			if type(source) ~= "table" then continue end

			for key, value in source do
				-- Ignore private fields
				if type(key) == "string" and string.sub(key, 1, 1) == "_" then continue end
				result[key] = value
			end
		end

		return result
	end :: any
) :: Types.Extended

return extend(Core, Modding, Lifecycles)
