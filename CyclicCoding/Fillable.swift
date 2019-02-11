//
//  Fillable.swift
//  CyclicCoding iOS
//
//  Created by Greg Omelaenko on 12/2/19.
//  Copyright © 2019 Greg Omelaenko. All rights reserved.
//

final class WeakFillable<Object: AnyObject> {
    
    weak var object: Object?
    
    init(filledWith object: Object?) {
        self.object = object
    }
    
}

protocol DelayedDecoder {
    
    func delayableDecode<T: Decodable>(_ type: T.Type, completion: @escaping (T) -> Void) throws
    
}

struct WeakFillableMaker {
    
    private let delayedDecoder: DelayedDecoder
    
    init(delayedDecoder: DelayedDecoder) {
        self.delayedDecoder = delayedDecoder
    }
    
    func request<T: Decodable & AnyObject>(_ type: T.Type) throws -> WeakFillable<T> {
        let fillable = WeakFillable<T>(filledWith: nil)
        try delayedDecoder.delayableDecode(type) { (decoded) in
            fillable.object = decoded
        }
        return fillable
    }
    
}
