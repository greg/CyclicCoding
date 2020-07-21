//
//  Box.swift
//  Gridlock
//
//  Created by Greg Omelaenko on 5/8/18.
//  Copyright © 2018 Greg Omelaenko. All rights reserved.
//

public class Box<Value> {
    
    fileprivate var value: Value
    
    public required init(_ value: Value) {
        self.value = value
    }
    
    public subscript() -> Value {
        return value
    }
    
    public func mutableCopy() -> MutableBox<Value> {
        return MutableBox(self[])
    }
    
}

extension Box: Equatable where Value: Equatable {
    
    public static func == (lhs: Box<Value>, rhs: Box<Value>) -> Bool {
        return lhs[] == rhs[]
    }
    
}

extension Box {
    
    public func map<T>(_ transform: (Value) throws -> T) rethrows -> Box<T> {
        return Box<T>(try transform(self[]))
    }
    
}

public class MutableBox<Value>: Box<Value> {
    
    public override subscript() -> Value {
        get {
            return value
        }
        set {
            value = newValue
        }
    }
    
}
