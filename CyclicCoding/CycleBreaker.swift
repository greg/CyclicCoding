//
//  CycleBreaker.swift
//  CyclicCoding
//
//  Created by Greg Omelaenko on 18/1/19.
//  Copyright © 2019 Greg Omelaenko. All rights reserved.
//

/// An internal protocol used to identify _Encoder instances and notify them of cycle breakers.
protocol CycleBreakerEncoder: SingleValueEncodingContainer {
    
    func encodeBreakingCycle<T: Encodable & AnyObject>(_ value: T) throws
    
}

/// An internal protocol used to identify _Decoder instances and use a private decoding method.
protocol CycleBreakerDecoder: SingleValueDecodingContainer {
    
    func decode<T: Decodable>(_ type: T.Type, completion: @escaping (T) -> Void) throws
    
}

/// Stores a **weak** reference to an `Object` instance.
/// Use this class to break cycles in a data model to be encoded with `CyclicEncoder`.
public struct WeakCycleBreaker<Object: AnyObject & Codable>: Codable {
    
    /// An implementation detail to allow delayed filling during decoding
    private final class Fillable {
        
        weak var object: Object?
        
        init() {}
        
    }
    
    private let storage = Fillable()
    
    public init(object: Object? = nil) {
        self.storage.object = object
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            if let decoder = container as? CycleBreakerDecoder {
                let storage = self.storage
                try decoder.decode(Object.self, completion: {
                    storage.object = $0
                })
            }
            else {
                // this decoder isn't our cycle-aware one, decode normally
                self.storage.object = try container.decode(Object.self)
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let object = storage.object {
            if let encoder = container as? CycleBreakerEncoder {
                try encoder.encodeBreakingCycle(object)
            }
            else {
                try container.encode(object)
            }
        }
        else {
            try container.encodeNil()
        }
    }
    
    /// Use the subscript to access the object weakly referenced by the cycle breaker.
    public subscript() -> Object? {
        get {
            return storage.object
        }
        set {
            storage.object = newValue
        }
    }
    
}

/// Stores an **unowned** reference to an `Object` instance.
/// Use this class to break cycles in a data model to be encoded with `CyclicEncoder`.
public struct UnownedCycleBreaker<Object: AnyObject & Codable>: Codable {
    
    private var breaker: WeakCycleBreaker<Object>
    
    public init(object: Object) {
        self.breaker = WeakCycleBreaker(object: object)
    }
    
    public init(from decoder: Decoder) throws {
        self.breaker = try WeakCycleBreaker(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try breaker.encode(to: encoder)
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
