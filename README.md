# Ghost Engine ECS (GEECS)

## Overview

GEECS is a simple Entity Component System (ECS) library for Motoko. It is designed to be simple to use and easy to integrate into your existing projects.

You can use GEECS to create entities with components, and run systems that update the components of those entities. This allows you to create complex systems with minimal boilerplate.

It was created as part of the Ghost Engine project, a simple game engine for the Internet Computer. Ghost Engine uses an authoritative server model, where the server runs the game simulation and sends updates to clients. GEECS is used to manage the game state and run the game simulation on the Internet Computer.


## Usage

## Install with mops

You can install GEECS using the mops package manager. To install GEECS, run the following command:

```sh
mops add geecs
```


## Full Example

Here is a full example of how to use GEECS to create a simple 3D movement system. In this example, we define a simple 3D vector type to represent positions and velocities, and create components for positions and velocities. We then create a system that moves entities that have both a position and velocity component.

Check out the [tests](./test/lib.test.mo) to see an example of how to use GEECS.

```motoko
// main.mo
import ECS "mo:ecs";

// Define a simple 3D vector type to represent positions and velocities:
type Vector3 = {
  x : Nat;
  y : Nat;
  z : Nat;
};

// Define components required for movement (plain data types):
type PositionComponent = {
  position : Vector3;
};

type VelocityComponent = {
  velocity : Vector3;
};

// Add the components to the ECS component type:
type Component = {
  #PositionComponent : PositionComponent;
  #VelocityComponent : VelocityComponent;
};

// Initialize the entity counter:
var entityCounter : Nat = 0;

// Initialize the required ECS data structures:
let ctx : ECS.Types.Context<Component> = {
  entities = ECS.State.Entities.new<Component>();
  registeredSystems = ECS.State.SystemRegistry.new<Component>();
  systemsEntities = ECS.State.SystemsEntities.new();
  updatedComponents = ECS.State.UpdatedComponents.new<Component>();

  // Incrementing entity counter for ids.
  nextEntityId = func() : Nat {
    entityCounter += 1;
    entityCounter;
  };
};

// Create a system that moves entities that have both a position and velocity component:
let movementArchetype = ["PositionComponent", "VelocityComponent"];
let MovementSystem : ECS.Types.System<Component> = {
  systemType = "MovementSystem";
  archetype = movementArchetype;
  update = func(ctx : ECS.Types.Context<Component>, entityId : Nat, deltaTime : Time.Time) : () {
    let position = ECS.World.getComponent<Component>(ctx, entityId, "PositionComponent");
    let velocity = ECS.World.getComponent<Component>(ctx, entityId, "VelocityComponent");

    switch (position, velocity) {
      case (? #PositionComponent({ position }), ? #VelocityComponent({ velocity })) {
        // Update the position based on the velocity
        let updated = {
          x = position.x + velocity.x;
          y = position.y + velocity.y;
          z = position.z + velocity.z;
        };

        let updatedComponent = #PositionComponent({ position = updated });
        ECS.World.addComponent<Component>(ctx, entityId, "PositionComponent", updatedComponent);
      };
      case (_) ();
    };
  };
};

// Register the system to enable it to be run:
ECS.World.addSystem<Component>(ctx, MovementSystem);


// Create an entity with a position and velocity component:
let entityId = ECS.World.addEntity<Component>(ctx);
let position = #PositionComponent({ position = { x = 0; y = 0; z = 0 } });
ECS.World.addComponent<Component>(ctx, entityId, "PositionComponent", position);
let velocity = #VelocityComponent({ velocity = { x = 1; y = 1; z = 1 } });
ECS.World.addComponent<Component>(ctx, entityId, "VelocityComponent", velocity);

// Run the ECS systems and provide a delta time:
let lastTick = Time.now();
lastTick := ECS.World.update(ctx, lastTick);
```

Updates will be stored in the updatedComponents field of the context, and can be used to sync with clients or other systems.

## Game Loop:

Here is an example of how to create a game loop that runs the simulation and sends updates to clients:

```motoko
// Game loop runs all the systems
func gameLoop() : async () {
  // Process all the systems
  lastTick := ECS.World.update(ctx, lastTick);

  // Iterate through the players and send them the updates
  let updates = #Updates(Vector.toArray(updatedComponents));

  if (Vector.size(updatedComponents) < 1) return;

  for ((client, lastUpdate) in Map.entries(clients)) {
    ignore Messages.Client.send(ctx, client, updates);
  };

  // Clear the updatedComponents vector
  Vector.clear(updatedComponents);
};

// Set the game loop to run at an optimistic 60fps even though it will cap at the current block rate which is closer to 1-2fps:
let gameTick = #nanoseconds(1_000_000_000 / 60);
ignore Timer.recurringTimer<system>(gameTick, gameLoop);
```