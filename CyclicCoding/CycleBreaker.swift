//
//  CycleBreaker.swift
//  CyclicCoding
//
//  Created by Greg Omelaenko on 18/1/19.
//  Copyright © 2019 Greg Omelaenko. All rights reserved.
//

import CodableInterception

protocol EncodableCycleBreaker: Encodable {
    
    var objectIdentifier: ObjectIdentifier? { get }
    
}

protocol DecodableCycleBreaker: Decodable {
    
    init(requestFrom maker: WeakFillableMaker) throws
    
}

/// Stores a **weak** reference to an `Object` instance.
/// Use this class to break cycles in a data model to be encoded with `CyclicEncoder`.
/// - Note: `Encodable` and `Decodable` conformance is implemented in extensions to allow storing objects which are only one of those. Storing an object which conforms to neither is therefore possible but not useful.
public struct WeakCycleBreaker<Object: AnyObject> {
    
    private let storage: WeakFillable<Object>
    
    public init(object: Object? = nil) {
        self.storage = WeakFillable(filledWith: object)
    }
    
    /// Use the subscript to access the object weakly referenced by the cycle breaker.
    public subscript() -> Object? {
        get {
            return storage.object
        }
        mutating set {
            storage.object = newValue
        }
    }
    
}

extension WeakCycleBreaker: Encodable, EncodableCycleBreaker where Object: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let object = storage.object {
            try container.encode(object)
        }
        else {
            try container.encodeNil()
        }
    }
    
    var objectIdentifier: ObjectIdentifier? {
        return self[].map({ ObjectIdentifier($0) })
    }
    
}

extension WeakCycleBreaker: Decodable, DecodableCycleBreaker where Object: Decodable {
    
    public init(from decoder: Decoder) throws {
        // _Decoder will *never* call this function, it should just decode normally
        let container = try decoder.singleValueContainer()
        let object: Object?
        if container.decodeNil() {
            object = nil
        }
        else {
            object = try container.decode(Object.self)
        }
        self.storage = WeakFillable(filledWith: object)
    }
    
    init(requestFrom maker: WeakFillableMaker) throws {
        self.storage = try maker.request(Object.self)
    }
    
}

/// Stores an **unowned** reference to an `Object` instance.
/// Use this class to break cycles in a data model to be encoded with `CyclicEncoder`.
/// - Note: `Encodable` and `Decodable` conformance is implemented in extensions to allow storing objects which are only one of those. Storing an object which conforms to neither is therefore possible but not useful.
public struct UnownedCycleBreaker<Object: AnyObject> {
    
    private var breaker: WeakCycleBreaker<Object>
    
    public init(object: Object) {
        self.breaker = WeakCycleBreaker(object: object)
    }
    
    /// Use the subscript to access the unowned object referenced by the cycle breaker.
    public subscript() -> Object {
        get {
            return breaker[]!
        }
        set {
            breaker[] = newValue
        }
    }
    
}

extension UnownedCycleBreaker: Encodable, EncodableCycleBreaker where Object: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        try breaker.encode(to: encoder)
    }
    
    var objectIdentifier: ObjectIdentifier? {
        return breaker.objectIdentifier
    }
    
}

extension UnownedCycleBreaker: Decodable, DecodableCycleBreaker where Object: Decodable {
    
    public init(from decoder: Decoder) throws {
        self.breaker = try WeakCycleBreaker(from: decoder)
    }
    
    init(requestFrom maker: WeakFillableMaker) throws {
        self.breaker = try WeakCycleBreaker(requestFrom: maker)
    }
    
}
