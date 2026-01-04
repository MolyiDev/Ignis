local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ignis = require(ReplicatedStorage.Shared.Ignis)

--==[ PlayersLifecycle ]==--

-- Create a singleton
local PlayersLifecycle = {}

-- Register the lifecycles
local onPlayerConnected = Ignis.RegisterLifecycle("OnPlayerConnected") :: Ignis.Lifecycle<Player>
local onPlayerDisconnected = Ignis.RegisterLifecycle("OnPlayerDisconnected") :: Ignis.Lifecycle<Player>

--[[ 
The lifecycles can also be registered like this
PlayersLifecycle.OnPlayerConnected = Ignis.RegisterLifecycle("OnPlayerConnected") :: Ignis.Lifecycle<Player>
PlayersLifecycle.OnPlayerDisconnected = Ignis.RegisterLifecycle("OnPlayerDisconnected") :: Ignis.Lifecycle<Player>

And used like this: 

function PlayersLifecycle.OnStart(self)
	Players.PlayerAdded:Connect(function(player)
		self.OnPlayerConnected:Fire(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.OnPlayerDisconnected:Fire(player)
	end)

	for _, player in Players:GetPlayers() do
		self.OnPlayerConnected:Fire(player)
	end
end
]]

function PlayersLifecycle.OnStart()
	Players.PlayerAdded:Connect(function(player)
		onPlayerConnected:Fire(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		onPlayerDisconnected:Fire(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerConnected:Fire(player)
	end
end

-- Register the lifecycle the same way any other singleton is registered in Ignis.
return Ignis.Register(PlayersLifecycle)

--==[ CharactersLifecycle ]==--

-- You can also create custom lifecycles from other lifecycles
local CharactersLifecycle = {}

local onCharacterAdded = Ignis.RegisterLifecycle("OnCharacterAdded") :: Ignis.Lifecycle<Model>
local onCharacterRemoving = Ignis.RegisterLifecycle("OnCharacterRemoving") :: Ignis.Lifecycle<Model>

function CharactersLifecycle.OnPlayerConnected(player: Player)
    -- Usually we would use a memory management library here like
    -- Butler, Trove, Janitor, or Maid, and destroy it when the player disconnects, but for this example, imagine that I'm using one.

    player.CharacterAdded:Connect(function(character: Model)
        -- We can add a tag to the character for a Component here
        -- character:AddTag("Character")
        onCharacterAdded:Fire(character)
    end)

    player.CharacterRemoving:Connect(function(character: Model)
        onCharacterRemoving:Fire(character)
    end)
end

return Ignis.Register(CharactersLifecycle)

-- As you can see for CharactersLifecycle we didn't need to use 'OnStart'.
-- OnStart is only needed if you want your event to fire after Ignis is ignited.
-- For PlayersLifecycle, it was needed because if we fire before Ignis is ignited, the events will go nowhere.
-- But for CharactersLifecycle, 'OnPlayerConnected' is fired only after Ignis has been ignited, so we do not need OnStart.

--==[ Usage of custom lifecycles ]==--

local Example = {}

function Example.OnPlayerConnected(player: Player)
    -- Do something
end

function Example.OnPlayerDisconnected(player: Player)
    -- Do something
end

function Example.OnCharacterAdded(character: Model)
    -- Do something
end

function Example.OnCharacterRemoving(character: Model)
    -- Do something
end

return Ignis.Register(Example)


