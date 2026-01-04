# Ignis

## Installation

```bash
pesde add molyi/ignis
```

## Usage

### Creating a Controller/Service/Provider/Singleton/you name it.

```luau
local Ignis = require(path.to.ignis)

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

return Ignis.Register(Example)
```

### Dependency injection

You can declare dependencies using `Ignis.Dependency` before registering.
This will make the module declared as `Dependency` be initialized before the module that was requesting it.

```luau
local Ignis = require(path.to.ignis)
local OtherSingleton = Ignis.Dependency(require(path.to.OtherSingleton))

local ThisSingleton = {}

function ThisSingleton.OnStart()
    OtherSingleton.DoThings()
end

return Ignis.Register(ThisSingleton)
```

### Ignition

Start Ignis in your entry script (server or client).

```luau
local Ignis = require(path.to.ignis)

-- Load all the modules
Ignis.LoadDescendants(script.Singletons)
Ignis.LoadChildren(script.Modding)

-- Then just burn everything
Ignis.Ignite()
```

### Lifecycles

Ignis supports custom lifecycle events.

```luau
-- HeartbeatEvent.luau
local Ignis = require(path.to.ignis)

Ignis.CreateLifecycle("OnHeartbeat", function(fire)
    game:GetService("RunService").Heartbeat:Connect(fire)
end)

return nil

-- SomeSingleton.luau
local Ignis = require(path.to.ignis)

local SomeSingleton = {}

function MyService.OnHeartbeat(dt)
    print("Heartbeat:", dt)
end

return Ignis.Register(SomeSingleton)
```

---

You can see more examples on the examples folder
