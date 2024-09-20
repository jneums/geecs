import Map "mo:stable-hash-map";
import Vector "mo:vector";
import Time "mo:base/Time";

module {
  public type EntityId = Nat;
  public type ComponentType = Text;

  public type Context<T> = {
    entities : Entities<T>;
    systemsEntities : SystemsEntities;
    registeredSystems : SystemRegistry<T>;
    updatedComponents : UpdatedComponents<T>;
    nextEntityId : () -> EntityId;
  };

  public type Entities<T> = Map.Map<EntityId, Components<T>>;
  public type SystemsEntities = Map.Map<SystemType, [EntityId]>;
  public type SystemRegistry<T> = Map.Map<SystemType, System<T>>;
  public type UpdatedComponents<T> = Vector.Vector<Update<T>>;
  public type Components<T> = Map.Map<ComponentType, T>;

  public type Update<T> = {
    #Insert : {
      entityId : EntityId;
      component : T;
    };
    #Delete : {
      entityId : EntityId;
      componentType : ComponentType;
    };
  };

  public type SystemType = Text;
  public type System<T> = {
    systemType : SystemType;
    archetype : [ComponentType];
    update : (Context<T>, EntityId, Time.Time) -> ();
  };

  public type World = module {
    // Entity API
    addEntity : <T>(Context<T>) -> EntityId;
    removeEntity : <T>(Context<T>, EntityId) -> ();
    getEntity : <T>(Context<T>, EntityId) -> Components<T>;
    getEntitiesByArchetype : <T>(Context<T>, [ComponentType]) -> [EntityId];
    // Component API
    addComponent : <T>(Context<T>, EntityId, ComponentType, T) -> ();
    getComponent : <T>(Context<T>, EntityId, ComponentType) -> ?T;
    updateComponent : <T>(Context<T>, EntityId, ComponentType, T) -> ();
    removeComponent : <T>(Context<T>, EntityId, ComponentType) -> ();
    // System API
    addSystem : <T>(Context<T>, System<T>) -> ();
    update : <T>(Context<T>, Time.Time) -> Time.Time;
  };

  public type Entity = module {
    new : <T>() -> Components<T>;
    add : <T>(Components<T>, ComponentType, T) -> ();
    get : <T>(Components<T>, ComponentType) -> ?T;
    has : <T>(Components<T>, ComponentType) -> Bool;
    hasAll : <T>(Components<T>, [ComponentType]) -> Bool;
    delete : <T>(Components<T>, ComponentType) -> ();
  };
};
