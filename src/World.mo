import T "Types";
import Map "mo:stable-hash-map/Map/Map";
import Vector "mo:vector";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import TrieSet "mo:base/TrieSet";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Entity "Entity";

module : T.World {
  private let Nhash = Map.hashInt;

  public func addEntity<T>(ctx : T.Context<T>) : T.EntityId {
    let id = ctx.nextEntityId();
    Map.set(ctx.entities, Map.nhash, id, Entity.new<T>());
    id;
  };

  public func removeEntity<T>(ctx : T.Context<T>, entityId : T.EntityId) : () {
    // Mark the entity for deletion instead of deleting immediately
    Map.set(ctx.entitiesToDelete, Map.nhash, entityId, Time.now());
  };

  public func getEntity<T>(ctx : T.Context<T>, entityId : T.EntityId) : T.Components<T> {
    Option.get(Map.get(ctx.entities, Map.nhash, entityId), Entity.new<T>());
  };

  public func getEntitiesByArchetype<T>(ctx : T.Context<T>, archetype : [T.ComponentType]) : [T.EntityId] {
    let results = Vector.new<T.EntityId>();
    for ((entityId, entity) in Map.entries(ctx.entities)) {
      if (Entity.hasAll(entity, archetype)) {
        Vector.add(results, entityId);
      };
    };
    Vector.toArray(results);
  };

  public func getComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType) : ?T {
    let entity = getEntity(ctx, entityId);

    Entity.get<T>(entity, componentType);
  };

  public func addComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType, component : T) : () {
    let entity = getEntity(ctx, entityId);

    Entity.add(entity, componentType, component);
    addOrRemoveToSystems(ctx, entityId);
    Vector.add(ctx.updatedComponents, #Insert({ entityId; component; timestamp = Time.now() }));
  };

  public func updateComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType, component : T) : () {
    let entity = getEntity(ctx, entityId);

    Entity.add(entity, componentType, component);
    Vector.add(ctx.updatedComponents, #Insert({ entityId; component; timestamp = Time.now() }));
  };

  public func removeComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType) : () {
    let entity = getEntity(ctx, entityId);

    Entity.delete(entity, componentType);
    addOrRemoveToSystems(ctx, entityId);
    Vector.add(ctx.updatedComponents, #Delete({ entityId; componentType; timestamp = Time.now() }));
  };

  func addOrRemoveToSystems<T>(ctx : T.Context<T>, entityId : T.EntityId) : () {
    for ((systemType, sys) in Map.entries(ctx.registeredSystems)) {
      addEntityToSystem(ctx, entityId, sys);
    };
  };

  func addEntityToSystem<T>(ctx : T.Context<T>, entityId : T.EntityId, sys : T.System<T>) : () {
    let entity = getEntity(ctx, entityId);
    let currentEntities = Map.get(ctx.systemsEntities, Map.thash, sys.systemType);

    switch (Entity.hasAll(entity, sys.archetype), currentEntities) {
      case (true, ?exists) {
        // If the system exists already, add the entity to the system
        let set = TrieSet.fromArray(exists, Nhash, Nat.equal);
        let updatedSet = TrieSet.put<Nat>(set, entityId, Nhash(entityId), Nat.equal);
        Map.set(ctx.systemsEntities, Map.thash, sys.systemType, TrieSet.toArray(updatedSet));
      };
      case (false, ?exists) {
        // If the entity is not valid for the existing system, remove it
        let set = TrieSet.fromArray(exists, Nhash, Nat.equal);
        let updatedSet = TrieSet.delete<Nat>(set, entityId, Nhash(entityId), Nat.equal);
        Map.set(ctx.systemsEntities, Map.thash, sys.systemType, TrieSet.toArray(updatedSet));
      };
      case (true, null) {
        // If the entity is valid for the system and the system does not exist, create it
        Map.set(ctx.systemsEntities, Map.thash, sys.systemType, [entityId]);
      };
      case (false, null) {
        // If the entity is not valid for the system and the system does not exist, do nothing
      };
    };
  };

  public func addSystem<T>(ctx : T.Context<T>, sys : T.System<T>) : () {
    Map.set(ctx.registeredSystems, Map.thash, sys.systemType, sys);
    Map.set(ctx.systemsEntities, Map.thash, sys.systemType, []);

    for (entityId in Map.keys(ctx.entities)) {
      addEntityToSystem(ctx, entityId, sys);
    };
  };

  public func update<T>(ctx : T.Context<T>, deltaTime : Time.Time) : async () {
    // Regular update process
    for ((systemId, entities) in Map.entries(ctx.systemsEntities)) {
      switch (Map.get(ctx.registeredSystems, Map.thash, systemId)) {
        case (?exists) {
          for (entityId in Iter.fromArray(entities)) {
            ignore exists.update(ctx, entityId, deltaTime);
          };
        };
        case (null) { Debug.print("System does not exist!") };
      };
    };

    // Process entities marked for deletion
    for (entityId in Map.keys(ctx.entitiesToDelete)) {
      // Get the entity's components
      let entity = Map.get(ctx.entities, Map.nhash, entityId);

      switch (entity) {
        case (?components) {
          // Iterate through each component and notify clients of its deletion
          for ((componentType, _) in Map.entries(components)) {
            Vector.add(ctx.updatedComponents, #Delete({ entityId; componentType; timestamp = Time.now() }));
          };
        };
        case (null) {
          Debug.print("Entity not found for deletion!");
        };
      };

      // Remove the entity and its components
      Map.delete(ctx.entities, Map.nhash, entityId);
      // Remove the entity from all systems
      for ((systemType, entities) in Map.entries(ctx.systemsEntities)) {
        let set = TrieSet.fromArray(entities, Nhash, Nat.equal);
        let updatedSet = TrieSet.delete<Nat>(set, entityId, Nhash(entityId), Nat.equal);
        Map.set(ctx.systemsEntities, Map.thash, systemType, TrieSet.toArray(updatedSet));
      };
      // Remove the entity from the list of entities to delete
      Map.delete(ctx.entitiesToDelete, Map.nhash, entityId);
    };
  };
};
