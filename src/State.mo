import T "./Types";
import Map "mo:stable-hash-map";
import Vector "mo:vector";

module {
  func initialEntities<T>() : T.Entities<T> {
    Map.new<T.EntityId, T.Components<T>>(Map.nhash);
  };

  public let Entities = {
    new = initialEntities;
  };

  func initialSystemsEntities() : T.SystemsEntities {
    Map.new<Text, [T.EntityId]>(Map.thash);
  };

  public let SystemsEntities = {
    new = initialSystemsEntities;
  };

  func initialSystemRegistry<T>() : T.SystemRegistry<T> {
    Map.new<Text, T.System<T>>(Map.thash);
  };

  public let SystemRegistry = {
    new = initialSystemRegistry;
  };

  func initialUpdatedComponents<T>() : T.UpdatedComponents<T> {
    Vector.new<T.Update<T>>();
  };

  public let UpdatedComponents = {
    new = initialUpdatedComponents;
  };
};
