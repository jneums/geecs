import T "Types";
import Map "mo:stable-hash-map/Map/Map";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";

module : T.Entity {
  public func new<T>() : T.Components<T> {
    Map.new<T.ComponentType, T>(Map.thash);
  };

  public func add<T>(components : T.Components<T>, componentType : T.ComponentType, component : T) : () {
    Map.set(components, Map.thash, componentType, component);
  };

  public func get<T>(components : T.Components<T>, componentType : Text) : ?T {
    Map.get(components, Map.thash, componentType);
  };

  public func has<T>(components : T.Components<T>, componentType : T.ComponentType) : Bool {
    Map.has(components, Map.thash, componentType);
  };

  public func hasAll<T>(components : T.Components<T>, componentTypes : [T.ComponentType]) : Bool {
    /// Check if all component types are present in the components map
    for (componentType in Iter.fromArray(componentTypes)) {
      if (not Map.has(components, Map.thash, componentType)) {
        return false;
      };
    };
    return true;
  };

  public func delete<T>(components : T.Components<T>, componentType : T.ComponentType) : () {
    Map.delete(components, Map.thash, componentType);
  };
};
