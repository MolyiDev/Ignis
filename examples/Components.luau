local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Ignis = require(ReplicatedStorage.Shared.Ignis)

type Coin = {
	SpinLoop: RBXScriptConnection,
} & Ignis.Component<BasePart>

local Coin = {}
Coin.__index = Coin

function Coin.OnSpawn(self: Coin)
	self.SpinLoop = RunService.Heartbeat:Connect(function()
		self.Instance.Orientation += Vector3.new(0, 1, 0)
	end)
end

function Coin.OnDespawn(self: Coin)
	if self.SpinLoop then self.SpinLoop:Disconnect() end
end

return Ignis.Component(Coin, {
	Tag = "Coin",
	BaseClass = "BasePart",
})
