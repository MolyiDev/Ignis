# Flux

## Installation

```bash
pesde add molyi/flux
```

## Usage

### Creating a Controller/Service/Provider/Singleton/you name it.

```luau
local Flux = require(path.to.Flux)

local Example = {}

-- OnInit goes before OnStart and it's sync.
-- This means that if I do task.wait(1000) in a module with priority 0
-- then the next module will need to wait for that module to finish to initialize
function Example.OnInit()
    print("Initializing...")
end

-- OnStart goes after OnInit and it's async.
function Example.OnStart()
    print("Starting...")
end

-- On some next example you will know when this fires.
function Example.OnStop()
    print("Stopping...")
end

return Flux.Register(Example)
```

### Dependency injection

You can declare dependencies using `Flux.Dependency` before registering.
This will make the module declared as `Dependency` be initialized before the module that was requesting it.

```luau
local Flux = require(path.to.flux)
local OtherSingleton = Flux.Dependency(require(path.to.OtherSingleton))

local ThisSingleton = {}

function ThisSingleton.OnStart()
    OtherSingleton.DoThings()
end

return Flux.Register(ThisSingleton)
```

### Ignition

Start Flux in your entry script (server or client).

```luau
local Flux = require(path.to.flux)

-- Load all the modules
Flux.LoadDescendants(script.Singletons)
Flux.LoadChildren(script.Modding)

-- Then just burn everything
Flux.Ignite()
```

### Lifecycles

Flux supports custom lifecycle events.

```luau
-- HeartbeatEvent.luau
local Flux = require(path.to.flux)

Flux.CreateLifecycle("OnHeartbeat", function(fire)
    game:GetService("RunService").Heartbeat:Connect(fire)
end)

return nil

-- SomeSingleton.luau
local Flux = require(path.to.flux)

local SomeSingleton = {}

function MyService.OnHeartbeat(dt)
    print("Heartbeat:", dt)
end

return Flux.Register(SomeSingleton)
```

---

You can see more examples on the examples folder
