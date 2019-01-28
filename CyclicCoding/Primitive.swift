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

public struct FlattenedContainer: Equatable {
    
    public enum Value: Equatable {
        
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
        
    }
    
    public enum ValueOrReference: Equatable {
        case value(Value)
        case reference(Index)
    }
    
    public struct Index: Equatable {
        let value: Int
        init(_ value: Int) { self.value = value }
    }
    
    public let referenced: [Value]
    
    public let root: ValueOrReference
    
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
        return "[" + (referenced.map({ $0.description }) + [root.description]).joined(separator: ", ") + "]"
    }
    
}
