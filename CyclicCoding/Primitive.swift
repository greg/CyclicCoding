//
//  Primitive.swift
//  CyclicCoding
//
//  Created by Greg Omelaenko on 20/8/18.
//  Copyright © 2018 Greg Omelaenko. All rights reserved.
//

import Foundation

internal typealias Value = FlattenedContainer.Value
internal typealias ValueOrReference = FlattenedContainer.ValueOrReference
internal typealias ReferenceIndex = FlattenedContainer.Index

public struct FlattenedContainer: Equatable, Codable {
    
    public enum Value: Equatable, Codable {
        
        case `nil`
        case boolean(Bool)
        case string(String)
        case float(Float)
        case double(Double)
        case int(Int)
        case int8(Int8)
        case int16(Int16)
        case int32(Int32)
        case int64(Int64)
        case uint(UInt)
        case uint8(UInt8)
        case uint16(UInt16)
        case uint32(UInt32)
        case uint64(UInt64)
        
        case keyed([String : ValueOrReference])
        case unkeyed([ValueOrReference])
        indirect case single(ValueOrReference)
        
        private enum Tag: CodingKey {
            case `nil`
            case boolean
            case string
            case float
            case double
            case int
            case int8
            case int16
            case int32
            case int64
            case uint
            case uint8
            case uint16
            case uint32
            case uint64
            case keyed
            case unkeyed
            case single
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Tag.self)
            guard container.allKeys.count == 1, let tag = container.allKeys.first else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Decoding container for \(FlattenedContainer.Value.self) must contain exactly one key. Instead, there are \(container.allKeys)."))
            }
            switch tag {
            case .nil:
                guard try container.decodeNil(forKey: .nil) else {
                    throw DecodingError.dataCorruptedError(forKey: Tag.nil, in: container, debugDescription: "Failed to decode nil where nil was expected.")
                }
                self = .nil
            case .boolean:  self = .boolean(try container.decode(Bool.self, forKey: .boolean))
            case .string:   self = .string(try container.decode(String.self, forKey: .string))
            case .float:    self = .float(try container.decode(Float.self, forKey: .float))
            case .double:   self = .double(try container.decode(Double.self, forKey: .double))
            case .int:      self = .int(try container.decode(Int.self, forKey: .int))
            case .int8:     self = .int8(try container.decode(Int8.self, forKey: .int8))
            case .int16:    self = .int16(try container.decode(Int16.self, forKey: .int16))
            case .int32:    self = .int32(try container.decode(Int32.self, forKey: .int32))
            case .int64:    self = .int64(try container.decode(Int64.self, forKey: .int64))
            case .uint:     self = .uint(try container.decode(UInt.self, forKey: .uint))
            case .uint8:    self = .uint8(try container.decode(UInt8.self, forKey: .uint8))
            case .uint16:   self = .uint16(try container.decode(UInt16.self, forKey: .uint16))
            case .uint32:   self = .uint32(try container.decode(UInt32.self, forKey: .uint32))
            case .uint64:   self = .uint64(try container.decode(UInt64.self, forKey: .uint64))
            case .keyed:    self = .keyed(try container.decode([String : ValueOrReference].self, forKey: .keyed))
            case .unkeyed:  self = .unkeyed(try container.decode([ValueOrReference].self, forKey: .unkeyed))
            case .single:   self = .single(try container.decode(ValueOrReference.self, forKey: .single))
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            // it would be simpler to encode this with an unkeyed container with the tag followed by the value,
            // but using keys like this gives better usability/readability when encoding to e.g. JSON.
            var container = encoder.container(keyedBy: Tag.self)
            switch self {
            case .nil: try container.encodeNil(forKey: .nil)
            case .boolean(let value):   try container.encode(value, forKey: .boolean)
            case .string(let value):    try container.encode(value, forKey: .string)
            case .float(let value):     try container.encode(value, forKey: .float)
            case .double(let value):    try container.encode(value, forKey: .double)
            case .int(let value):       try container.encode(value, forKey: .int)
            case .int8(let value):      try container.encode(value, forKey: .int8)
            case .int16(let value):     try container.encode(value, forKey: .int16)
            case .int32(let value):     try container.encode(value, forKey: .int32)
            case .int64(let value):     try container.encode(value, forKey: .int64)
            case .uint(let value):      try container.encode(value, forKey: .uint)
            case .uint8(let value):     try container.encode(value, forKey: .uint8)
            case .uint16(let value):    try container.encode(value, forKey: .uint16)
            case .uint32(let value):    try container.encode(value, forKey: .uint32)
            case .uint64(let value):    try container.encode(value, forKey: .uint64)
            case .keyed(let value):     try container.encode(value, forKey: .keyed)
            case .unkeyed(let value):   try container.encode(value, forKey: .unkeyed)
            case .single(let value):    try container.encode(value, forKey: .single)
            }
        }
        
    }
    
    public enum ValueOrReference: Equatable, Codable {
        case value(Value)
        case reference(Index)
        
        private enum Tag: CodingKey {
            case value
            case reference
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Tag.self)
            if container.contains(.value) {
                self = .value(try container.decode(Value.self, forKey: .value))
                guard !container.contains(.reference) else {
                    throw DecodingError.dataCorruptedError(forKey: Tag.reference, in: container, debugDescription: "Container contains values for both value(\(self)) and reference. There should only be one.")
                }
            }
            else if container.contains(.reference) {
                self = .reference(try container.decode(Index.self, forKey: .reference))
            }
            else {
                throw DecodingError.keyNotFound(Tag.value, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Container does not have a key for value or reference. One should be present."))
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Tag.self)
            switch self {
            case .value(let value):
                try container.encode(value, forKey: .value)
            case .reference(let index):
                try container.encode(index, forKey: .reference)
            }
        }
    }
    
    public struct Index: Equatable, Codable {
        let value: Int
        init(_ value: Int) { self.value = value }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            value = try container.decode(Int.self)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
    }
    
    public let referenced: [Value]
    
    public let root: ValueOrReference
    
    /// Initialises a flattened container from a manually crafted payload.
    /// - Warning: A typical user of this library has **no reason** to ever use this initialiser. You only need to use this if for some reason you want to create a container manually (and presumably try to decode from it).
    public init(referenced: [Value], root: ValueOrReference) {
        self.referenced = referenced
        self.root = root
    }
    
}

extension FlattenedContainer.Value: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .nil:
            return "null"
        case .boolean(let b):
            return b ? "true" : "false"
        case .string(let s):
            return "\"" + s.replacingOccurrences(of: "\"", with: "\\\"") + "\""
        case .float(let v):
            return "\(v)"
        case .double(let v):
            return "\(v)"
        case .int(let n):
            return "\(n)"
        case .int8(let n):
            return "\(n)"
        case .int16(let n):
            return "\(n)"
        case .int32(let n):
            return "\(n)"
        case .int64(let n):
            return "\(n)"
        case .uint(let n):
            return "\(n)"
        case .uint8(let n):
            return "\(n)"
        case .uint16(let n):
            return "\(n)"
        case .uint32(let n):
            return "\(n)"
        case .uint64(let n):
            return "\(n)"
        case .keyed(let keyed):
            return "{ " + keyed.sorted(by: { $0.key < $1.key }).map({ "\($0.key): \($0.value)" }).joined(separator: ", ") + " }"
        case .unkeyed(let unkeyed):
            return "[" + unkeyed.map({ $0.description }).joined(separator: ", ") + "]"
        case .single(let wrapped):
            return wrapped.description
        }
    }
    
}

extension FlattenedContainer.ValueOrReference: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .value(let value):
            return value.description
        case .reference(let index):
            return "#\(index.value)"
        }
    }
    
}

extension FlattenedContainer: CustomStringConvertible {
    
    public var description: String {
        return "referenced: \(referenced), root: \(root)"
    }
    
}
