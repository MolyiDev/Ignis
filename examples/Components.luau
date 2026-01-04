local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Ignis = require(ReplicatedStorage.Shared.Ignis)

-- Optional, only if you have strict types.
type Coin = {
	SpinLoop: RBXScriptConnection,
} & Ignis.Component<BasePart>

local Coin = {}

-- This method fires when a new instance with the specified tag has been created.
-- Or when you use 'Ignis.AddComponent(instance, Coin)' to manually add an instance.
function Coin.OnSpawn(self: Coin)
	self.SpinLoop = RunService.Heartbeat:Connect(function()
		self.Instance.Orientation += Vector3.new(0, 1, 0)
	end)
end

-- This method fires when an instance with the specified tag has been streamed-out.
--  Or when you use 'Ignis.RemoveComponent(instance, Coin)' to manually remove an instance.
function Coin.OnDespawn(self: Coin)
	if self.SpinLoop then self.SpinLoop:Disconnect() end
end

return Ignis.Component(Coin, {
	-- We look for base parts that have the tag 'Coin'
	Tag = "Coin",
	BaseClass = "BasePart",
})
