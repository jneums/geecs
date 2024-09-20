import { test; suite; expect } "mo:test";

import Time "mo:base/Time";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Map "mo:stable-hash-map/Map/Map";
import Vector "mo:vector";

import ECS "../src";

suite(
  "Ghost Engine ECS (GEECS)",
  func() {

    // Define a simple 3D vector type to represent positions and velocities:
    type Vector3 = {
      x : Nat;
      y : Nat;
      z : Nat;
    };

    // Define components required for movement:
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

    // Show and equal functions for comparing components
    func showComponent(a : Component) : Text {
      debug_show (a);
    };

    func equalComponent(a : Component, b : Component) : Bool {
      a == b;
    };

    let movementArchetype = ["PositionComponent", "VelocityComponent"];

    // Test cases
    test(
      "Can create and register a system",
      func() {

        // Check for registered systems
        expect.nat(Map.size(ctx.registeredSystems)).equal(0);

        // Create a system that moves entities that have both a position and velocity component
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

        // Register the system
        ECS.World.addSystem<Component>(ctx, MovementSystem);

        // Check if the system was registered
        expect.nat(Map.size(ctx.registeredSystems)).equal(1);
        expect.bool(Map.has(ctx.registeredSystems, Map.thash, "MovementSystem")).equal(true);
      },
    );

    test(
      "Can add and remove components from entities",
      func() {

        // Create a new entity with a position and velocity component (movement archetype)
        let entityId = ECS.World.addEntity<Component>(ctx);
        let position = #PositionComponent({ position = { x = 0; y = 0; z = 0 } });
        ECS.World.addComponent<Component>(ctx, entityId, "PositionComponent", position);

        // Check if the component was added
        let addedPosition = ECS.World.getComponent<Component>(ctx, entityId, "PositionComponent");
        expect.option(addedPosition, showComponent, equalComponent).equal(?position);

        // Remove the component
        ECS.World.removeComponent<Component>(ctx, entityId, "PositionComponent");

        // Check if the component was removed
        let removedPosition = ECS.World.getComponent<Component>(ctx, entityId, "PositionComponent");
        expect.option(removedPosition, showComponent, equalComponent).equal(null);
      },
    );

    test(
      "Can view a list of updates for the current tick",
      func() {
        let updated = Vector.toArray(ctx.updatedComponents);

        let updates = [
          #Insert({
            component = #PositionComponent({
              position = { x = 0; y = 0; z = 0 };
            });
            entityId = 1;
          }),
          #Delete({ componentType = "PositionComponent"; entityId = 1 }),
        ];

        assert (updated == updates);
      },
    );

    test(
      "Can query entities by archetype",
      func() {

        // Check for any entities that have the requirements for the move system (movement archetype)
        let empty = ECS.World.getEntitiesByArchetype<Component>(ctx, movementArchetype);
        expect.array(empty, Nat.toText, Nat.equal).equal([]);

        // Create a new entity with a position and velocity component (movement archetype)
        let entityId = ECS.World.addEntity<Component>(ctx);
        let position = #PositionComponent({ position = { x = 0; y = 0; z = 0 } });
        ECS.World.addComponent<Component>(ctx, entityId, "PositionComponent", position);

        let velocity = #VelocityComponent({ velocity = { x = 1; y = 1; z = 1 } });
        ECS.World.addComponent<Component>(ctx, entityId, "VelocityComponent", velocity);

        // Query by archetype again and check if the entity is returned
        let entities = ECS.World.getEntitiesByArchetype<Component>(ctx, movementArchetype);
        expect.array(entities, Nat.toText, Nat.equal).equal([entityId]);
      },
    );

    test(
      "Can run the systems to update entities (game tick)",
      func() {

        // Check the entities position before updating
        let entityId = ECS.World.getEntitiesByArchetype<Component>(ctx, movementArchetype)[0];
        let component = ECS.World.getComponent<Component>(ctx, entityId, "PositionComponent");
        let position = #PositionComponent({ position = { x = 0; y = 0; z = 0 } });
        expect.option(component, showComponent, equalComponent).equal(?position);

        // Update the world, which will run all systems
        let lastTick = 0;
        let nextTick = ECS.World.update(ctx, 0);

        expect.int(nextTick).notEqual(lastTick);

        // Check the entities position after updating
        let updatedPosition = ECS.World.getComponent<Component>(ctx, entityId, "PositionComponent");
        let expectedPosition = #PositionComponent({
          position = { x = 1; y = 1; z = 1 };
        });
        expect.option(updatedPosition, showComponent, equalComponent).equal(?expectedPosition);
      },
    );

    test(
      "Can empty the list of updates after a tick",
      func() {
        /// Clear the updatedComponents vector
        Vector.clear(ctx.updatedComponents);

        let updated = Vector.toArray(ctx.updatedComponents);
        let updates = [];

        assert (updated == updates);
      },
    );

  },
);
