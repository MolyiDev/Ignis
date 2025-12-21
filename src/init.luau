local Core = require(script.Core)
local Modding = require(script.Modding)
local Lifecycles = require(script.Lifecycles)

local main = Core:Extend({
	modding = Modding,
}, Lifecycles)

return main
