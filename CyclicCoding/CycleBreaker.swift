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

/// We store the encoder in a user info key in case another library wraps the encoder and hides the type info so we can't cast.
let cycleBreakerEncoderUserInfoKey = CodingUserInfoKey(rawValue: "CyclicCoding.cycleBreakerEncoder")!

/// An internal protocol used to identify _Decoder instances and use a private decoding method.
protocol CycleBreakerDecoder: SingleValueDecodingContainer {
    
    func decode<T: Decodable>(_ type: T.Type, completion: @escaping (T) -> Void) throws
    
}

let cycleBreakerDecoderUserInfoKey = CodingUserInfoKey(rawValue: "CyclicCoding.cycleBreakerDecoder")!

/// Stores a **weak** reference to an `Object` instance.
/// Use this class to break cycles in a data model to be encoded with `CyclicEncoder`.
/// - Note: `Encodable` and `Decodable` conformance is implemented in extensions to allow storing objects which are only one of those. Storing an object which conforms to neither is therefore possible but not useful.
public struct WeakCycleBreaker<Object: AnyObject> {
    
    /// An implementation detail to allow delayed filling during decoding
    private final class Fillable {
        
        weak var object: Object?
        
        init() {}
        
    }
    
    private let storage = Fillable()
    
    public init(object: Object? = nil) {
        self.storage.object = object
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

extension WeakCycleBreaker: Encodable where Object: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let object = storage.object {
            if let encoder = encoder.userInfo[cycleBreakerEncoderUserInfoKey] as? CycleBreakerEncoder {
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
    
}

extension WeakCycleBreaker: Decodable where Object: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            if let decoder = decoder.userInfo[cycleBreakerDecoderUserInfoKey] as? CycleBreakerDecoder {
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

extension UnownedCycleBreaker: Encodable where Object: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        try breaker.encode(to: encoder)
    }
    
}

extension UnownedCycleBreaker: Decodable where Object: Decodable {
    
    public init(from decoder: Decoder) throws {
        self.breaker = try WeakCycleBreaker(from: decoder)
    }
    
}
