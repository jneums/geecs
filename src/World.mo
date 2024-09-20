import T "Types";
import Map "mo:stable-hash-map/Map/Map";
import Vector "mo:vector";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import TrieSet "mo:base/TrieSet";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Entity "Entity";

module : T.World {
  public func addEntity<T>(ctx : T.Context<T>) : T.EntityId {
    let id = ctx.nextEntityId();
    Map.set(ctx.entities, Map.nhash, id, Entity.new<T>());
    id;
  };

  public func removeEntity<T>(ctx : T.Context<T>, entityId : T.EntityId) : () {
    Map.delete(ctx.entities, Map.nhash, entityId);
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
    Vector.add(ctx.updatedComponents, #Insert({ entityId; component }));
  };

  public func updateComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType, component : T) : () {
    let entity = getEntity(ctx, entityId);

    Entity.add(entity, componentType, component);
    Vector.add(ctx.updatedComponents, #Insert({ entityId; component }));
  };

  public func removeComponent<T>(ctx : T.Context<T>, entityId : T.EntityId, componentType : T.ComponentType) : () {
    let entity = getEntity(ctx, entityId);

    Entity.delete(entity, componentType);
    addOrRemoveToSystems(ctx, entityId);
    Vector.add(ctx.updatedComponents, #Delete({ entityId; componentType }));
  };

  func addOrRemoveToSystems<T>(ctx : T.Context<T>, entityId : T.EntityId) : () {
    for ((systemType, sys) in Map.entries(ctx.registeredSystems)) {
      addEntityToSystem(ctx, entityId, sys);
    };
  };

  func addEntityToSystem<T>(ctx : T.Context<T>, entityId : T.EntityId, sys : T.System<T>) : () {
    let entity = getEntity(ctx, entityId);
    let required = sys.archetype;

    switch (Entity.hasAll(entity, required)) {
      case (true) {
        // If the system is not already in the systems entities array, add it
        let entities = Map.get(ctx.systemsEntities, Map.thash, sys.systemType);
        switch (entities) {
          case (?exists) {
            let set = TrieSet.fromArray(exists, Hash.hash, Nat.equal);
            let updatedSet = TrieSet.put<Nat>(set, entityId, Hash.hash(entityId), Nat.equal);
            Map.set(ctx.systemsEntities, Map.thash, sys.systemType, TrieSet.toArray(updatedSet));
          };
          case (null) {
            Map.set(ctx.systemsEntities, Map.thash, sys.systemType, [entityId]);
          };
        };
      };
      case (false) {
        Map.delete(ctx.systemsEntities, Map.thash, sys.systemType);
      };
    };

  };

  public func addSystem<T>(ctx : T.Context<T>, sys : T.System<T>) : () {
    Map.set(ctx.systemsEntities, Map.thash, sys.systemType, []);
    Map.set(ctx.registeredSystems, Map.thash, sys.systemType, sys);

    for (entityId in Map.keys(ctx.entities)) {
      addEntityToSystem(ctx, entityId, sys);
    };
  };

  public func update<T>(ctx : T.Context<T>, lastTick : Time.Time) : Time.Time {
    let now = Time.now();
    let deltaTime = now - lastTick;

    for ((systemId, entities) in Map.entries(ctx.systemsEntities)) {
      switch (Map.get(ctx.registeredSystems, Map.thash, systemId)) {
        case (?exists) {
          for (entityId in Iter.fromArray(entities)) {
            exists.update(ctx, entityId, deltaTime);
          };
        };
        case (null) { Debug.print("System does not exist!") };
      };
    };

    now;
  };
};
