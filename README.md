# Ignis

> [!WARNING]
> **Ignis is very early in development.** But it is being used in production, so any bug will be fixed in no time.

## Installation

### Pesde

```bash
pesde add molyidev/ignis
```

### Wally

```toml
Ignis = "molyidev/ignis@^0.1.2"
```

## Why use Ignis?

* **Fully Typed:** Designed to work with the new Luau type solver.
* **Minimal Boilerplate:** Ignis was carefully crafted to be simple and require minimal boilerplate code.

## Usage

### Creating a Controller/Service/Provider/Singleton/you name it

```luau
local Ignis = require(path.to.Ignis)

local Example = {}

-- OnInit goes before OnStart and it's sync.
-- This means that if you do task.wait(1000) in a module with priority 0
-- then the next module will need to wait for that module to finish initializing
function Example.OnInit()
    print("Initializing...")
end

-- OnStart goes after OnInit and it's async.
function Example.OnStart()
    print("Starting...")
end

-- This fires when Ignis shuts down.
function Example.OnStop()
    print("Stopping...")
end

return Ignis.Register(Example)
```

### Dependency injection

You can declare dependencies using `Ignis.Dependency` before registering.
This will make the module declared as `Dependency` be initialized before the module that was requesting it.

```luau
local Ignis = require(path.to.Ignis)
local OtherSingleton = Ignis.Dependency(require(path.to.OtherSingleton))

local ThisSingleton = {}

function ThisSingleton.OnStart()
    OtherSingleton.DoThings()
end

return Ignis.Register(ThisSingleton)
```

Or you can define all the dependencies in `Ignis.Register`.

```luau
local Ignis = require(path.to.Ignis)
local OtherSingleton = require(path.to.OtherSingleton)

local ThisSingleton = {}

function ThisSingleton.OnStart()
    OtherSingleton.DoThings()
end

return Ignis.Register(ThisSingleton, { OtherSingleton })
```

Or if you're a psycho, you can define your dependencies like this:

```luau
local Ignis = require(path.to.Ignis)
local OtherSingleton = require(path.to.OtherSingleton)

local ThisSingleton = {
    OtherSingleton = OtherSingleton
}

function ThisSingleton.OnStart(self)
    self.OtherSingleton.DoThings()
    -- You can also use it like in the other examples
    -- OtherSingleton.DoThings()
    -- But if you do it like this then it doesn't make sense to add it to the table.
    -- That will make you really look like a psycho, but hey, I don't judge, I was the one that kept the feature for you <3.
end

return Ignis.Register(ThisSingleton)
```


### Ignition

Start Ignis in your entry script (server or client).

```luau
local Ignis = require(path.to.Ignis)

-- Load all the modules
Ignis.LoadDescendants(script.Singletons)
Ignis.LoadChildren(script.Modding)

-- Then just burn everything
Ignis.Ignite()
```

### Lifecycles

Ignis supports custom lifecycle events.

```luau
-- HeartbeatLifecycle.luau
local Ignis = require(path.to.Ignis)
local RunService = game:GetService("RunService")

local onHeartbeat = Ignis.RegisterLifecycle("OnHeartbeat") :: Ignis.Lifecycle<number>

RunService.Heartbeat:Connect(function(dt)
    onHeartbeat:Fire(dt)
    -- Or maybe you want to do it sync
    -- onHeartbeat:FireSync(dt)
end)

return nil

-- SomeSingleton.luau
local Ignis = require(path.to.Ignis)

local SomeSingleton = {}

function SomeSingleton.OnHeartbeat(dt)
    print("Heartbeat:", dt)
end

return Ignis.Register(SomeSingleton)
```

### Components

Ignis creates components by binding them to `CollectionService` tags (or manually). They have `OnSpawn` and `OnDespawn` methods.

```luau
local RunService = game:GetService("RunService")
local Ignis = require(path.to.Ignis)

-- Optional: Define types for strict typing
type Coin = {
    SpinLoop: RBXScriptConnection,
} & Ignis.Component<BasePart>

local Coin = {}

-- Fires when a "Coin" tag is added or when the instance streams in
function Coin.OnSpawn(self: Coin)
    self.SpinLoop = RunService.Heartbeat:Connect(function()
        self.Instance.Orientation += Vector3.new(0, 1, 0)
    end)
end

-- Fires when a "Coin" tag is removed, the instance is destroyed, or streams out
function Coin.OnDespawn(self: Coin)
    if self.SpinLoop then self.SpinLoop:Disconnect() end
end

return Ignis.Component(Coin, {
    Tag = "Coin",
    BaseClass = "BasePart",
})

```

---

You can see more examples in `./examples/`.

## Inspiration

**Ignis** takes inspiration from **[Flamework](https://github.com/rbxts-flamework/core)** and **[artwork](https://github.com/ratplier/artwork)**
