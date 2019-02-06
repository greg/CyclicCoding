//
//  CyclicCodingTests.swift
//  CyclicCodingTests
//
//  Created by Greg Omelaenko on 20/8/18.
//  Copyright © 2018 Greg Omelaenko. All rights reserved.
//

import XCTest
@testable import CyclicCoding

class CyclicCodingTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBasicCoding() {
        
        struct A: Codable, Equatable {
            let x: Int
            let y: Int
        }
        
        struct B: Codable, Equatable {
            let a: A
            let s: String
        }
        
        let b = B(a: A(x: 1, y: 2), s: "hi")
        
        let encoded = try! CyclicEncoder().flatten(b)
        
        XCTAssert(encoded.description == "referenced: [], root: { a: { x: 1, y: 2 }, s: \"hi\" }", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode(B.self, from: encoded)
        XCTAssert(decoded == b)
    }
    
    func testDuplicateCoding() {
        
        struct A: Codable {
            let c: C
            let d: C
        }
        
        class C: Codable {
            var x: Int
            
            init(x: Int) { self.x = x }
        }
        
        let c = C(x: 5)
        let a = A(c: c, d: c)
        
        let encoded = try! CyclicEncoder().flatten(a)
        
        XCTAssert(encoded.description == "referenced: [{ x: 5 }], root: { c: #0, d: #0 }", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode(A.self, from: encoded)
        XCTAssert(decoded.c.x == a.c.x && decoded.d.x == a.d.x)
        XCTAssert(decoded.c === decoded.d, "Object should not be duplicated.")
    }
    
    func testNestedDuplicateCoding() {
        
        class C: Codable {
            var x: Int
            
            init(x: Int) { self.x = x }
        }
        
        struct A: Codable {
            let c: C
        }
        
        struct B: Codable {
            let a: A
            let c: C
        }
        
        let c = C(x: 5)
        let a = A(c: c)
        let b = B(a: a, c: c)
        
        let encoded = try! CyclicEncoder().flatten(b)
        XCTAssert(encoded.description == "referenced: [{ x: 5 }], root: { a: { c: #0 }, c: #0 }", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode(B.self, from: encoded)
        XCTAssert(decoded.a.c === decoded.c, "Object should not be duplicated.")
    }
    
    func testSingleValueCoding() {
        
        struct S: Codable, Equatable {
            let x: Int
            
            init(x: Int) {
                self.x = x
            }
            
            init(from decoder: Decoder) throws {
                let container = try! decoder.singleValueContainer()
                x = try container.decode(Int.self)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(x)
            }
        }
        
        let s = S(x: 5)
        
        let encoded = try! CyclicEncoder().flatten(s)
        
        XCTAssert(encoded.description == "referenced: [], root: 5", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode(S.self, from: encoded)
        XCTAssert(decoded == s)
    }
    
    func testSingleValueClass() {
        
        class C: Codable {
            let x: Int
            
            init(x: Int) {
                self.x = x
            }
            
            required init(from decoder: Decoder) throws {
                let container = try! decoder.singleValueContainer()
                x = try container.decode(Int.self)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(x)
            }
        }
        
        struct D: Codable {
            let c: C
            let d: C
        }
        
        let c = C(x: 5)
        let d = D(c: c, d: c)
        
        let encoded = try! CyclicEncoder().flatten(d)
        
        XCTAssert(encoded.description == "referenced: [5], root: { c: #0, d: #0 }", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode(D.self, from: encoded)
        XCTAssert(decoded.c.x == d.c.x && decoded.d.x == d.d.x)
        XCTAssert(decoded.c === decoded.d, "Object should not be duplicated.")
    }
    
    func testUnkeyedCoding() {
        
        struct S: Codable {
            var x: Int
        }
        
        let a = [S(x: 1), S(x: 3), S(x: 2)]
        
        let encoded = try! CyclicEncoder().flatten(a)
        XCTAssert(encoded.description == "referenced: [], root: [{ x: 1 }, { x: 3 }, { x: 2 }]", "Encoded incorrectly: \(encoded).")
        
        let decoded = try! CyclicDecoder().decode([S].self, from: encoded)
        XCTAssert(decoded.elementsEqual(a, by: { $0.x == $1.x }))
    }
    
    func testNestedContainers() {
        
        enum XY: CodingKey {
            case x
            case y
        }
        
        struct K: Codable {
            var x: (Int, String, Bool)
            var y: (Int, Float)
            
            init(x: (Int, String, Bool), y: (Int, Float)) {
                self.x = x
                self.y = y
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: XY.self)
                var xc = try container.nestedUnkeyedContainer(forKey: .x)
                x.0 = try xc.decode(Int.self)
                let yc = try container.nestedContainer(keyedBy: XY.self, forKey: .y)
                y.0 = try yc.decode(Int.self, forKey: .y)
                x.1 = try xc.decode(String.self)
                x.2 = try xc.decode(Bool.self)
                y.1 = try yc.decode(Float.self, forKey: .x)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: XY.self)
                var yc = container.nestedContainer(keyedBy: XY.self, forKey: .y)
                var xc = container.nestedUnkeyedContainer(forKey: .x)
                try xc.encode(x.0)
                try yc.encode(y.0, forKey: .y)
                try yc.encode(y.1, forKey: .x)
                try xc.encode(x.1)
                try xc.encode(x.2)
            }
        }
        
        struct U: Codable {
            var x: (Int, String, Bool)
            var y: (Int, Float)
            
            init(x: (Int, String, Bool), y: (Int, Float)) {
                self.x = x
                self.y = y
            }
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var xc = try container.nestedUnkeyedContainer()
                x.0 = try xc.decode(Int.self)
                x.1 = try xc.decode(String.self)
                let yc = try container.nestedContainer(keyedBy: XY.self)
                x.2 = try xc.decode(Bool.self)
                y.1 = try yc.decode(Float.self, forKey: .x)
                y.0 = try yc.decode(Int.self, forKey: .y)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                var xc = container.nestedUnkeyedContainer()
                var yc = container.nestedContainer(keyedBy: XY.self)
                try yc.encode(y.1, forKey: .x)
                try xc.encode(x.0)
                try xc.encode(x.1)
                try xc.encode(x.2)
                try yc.encode(y.0, forKey: .y)
            }
        }
        
        let k = K(x: (5, "hi", true), y: (6, .pi))
        let encodedk = try! CyclicEncoder().flatten(k)
        XCTAssert(encodedk.description == "referenced: [], root: { x: [5, \"hi\", true], y: { x: 3.1415925, y: 6 } }", "Encoded incorrectly: \(encodedk).")
        let decodedk = try! CyclicDecoder().decode(K.self, from: encodedk)
        XCTAssert(decodedk.x == k.x && decodedk.y == k.y)
        
        let u = U(x: (5, "hi", true), y: (6, .pi))
        let encodedu = try! CyclicEncoder().flatten(u)
        XCTAssert(encodedu.description == "referenced: [], root: [[5, \"hi\", true], { x: 3.1415925, y: 6 }]", "Encoded incorrectly: \(encodedu).")
        let decodedu = try! CyclicDecoder().decode(U.self, from: encodedu)
        XCTAssert(decodedu.x == u.x && decodedu.y == u.y)
    }
    
    func testSingleValueContainer() {
        
        class C: Codable {
            var x: Int
            
            init(x: Int) {
                self.x = x
            }
        }
        
        struct S: Codable {
            var c: C
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(c)
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                self.c = try container.decode(C.self)
            }
            
            init(c: C) {
                self.c = c
            }
        }
        
        struct P: Codable {
            let a, b: S
        }
        
        let c = C(x: 5)
        let s1 = S(c: c)
        let s2 = S(c: c)
        let p = P(a: s1, b: s2)
        
        XCTAssert(p.a.c === p.b.c)
        
        let encoded = try! CyclicEncoder().flatten(p)
        XCTAssert(encoded.description == "referenced: [{ x: 5 }], root: { a: #0, b: #0 }", "Encoded incorrectly: \(encoded).")
        let decoded = try! CyclicDecoder().decode(P.self, from: encoded)
        XCTAssert(decoded.a.c.x == 5 && decoded.b.c.x == 5)
        XCTAssert(decoded.a.c === decoded.b.c, "object was duplicated during decoding")
    }
    
    func testCycleDetection() {
        
        class C: Codable {
            var d: D
            var x: Int
            
            init(d: D, x: Int) {
                self.d = d
                self.x = x
            }
        }
        
        class D: Codable {
            var c: C?
            var y: Int
            
            init(y: Int) {
                self.y = y
            }
        }
        
        let d = D(y: 5)
        let c = C(d: d, x: 4)
        d.c = c
        
        XCTAssertThrowsError(try CyclicEncoder().flatten(c), "Encoding an undecodable cycle should fail.") { error in
            XCTAssert(error is EncodingError)
        }
        
        class O: Codable {
            var o: O
        }
        
        let encoded = FlattenedContainer(referenced: [.keyed(["o": .reference(.init(0))])], root: .reference(.init(0)))
        
        XCTAssertThrowsError(try CyclicDecoder().decode(O.self, from: encoded), "Decoding an undecodable cycle should fail.") { error in
            XCTAssert(error is DecodingError)
        }
        
    }
    
    func testCyclicCoding() {

        class C: Codable {
            var d: D
            var x: Int

            init(d: D, x: Int) {
                self.d = d
                self.x = x
            }
        }

        class D: Codable {
            var c = WeakCycleBreaker<C>()
            var y: Int

            init(y: Int) {
                self.y = y
            }
        }

        let d = D(y: 5)
        let c = C(d: d, x: 4)
        d.c[] = c

        let encoded = try! CyclicEncoder().flatten(c)
        XCTAssert(encoded.description == "referenced: [{ d: { c: #0, y: 5 }, x: 4 }], root: #0", "Encoded incorrectly: \(encoded).")

        let decoded = try! CyclicDecoder().decode(C.self, from: encoded)
        XCTAssert(decoded.x == c.x && decoded.d.y == c.d.y)
        XCTAssert(decoded.d.c[]?.x == c.x && decoded.d.c[]?.d.y == c.d.y)
        XCTAssert(decoded.d.c[] != nil, "Weak reference was already released.")
        XCTAssert(decoded === decoded.d.c[], "Object was duplicated (or weak reference released) instead of establishing a cycle.")
        XCTAssert(decoded.d === decoded.d.c[]?.d, "Object was duplicated instead of establishing a cycle.")
    }
    
    func testEmptyCycleBreaker() {
        
        class C: Codable {
            
        }
        
        let b = WeakCycleBreaker<C>()
        
        do {
            let encoded = try CyclicEncoder().flatten(b)
            
            let decoded = try CyclicDecoder().decode(WeakCycleBreaker<C>.self, from: encoded)
            
            XCTAssert(decoded[] == nil)
        }
        catch {
            XCTFail("Error thrown during encoding or decoding")
        }
    }
    
    func testUnkeyedSuperCoding() {
        
        class A: Codable {
            var x: Int
            
            required init(x: Int) {
                self.x = x
            }
        }
        
        class B: A {
            var y: Int
            
            required init(x: Int) {
                self.y = 0
                super.init(x: x)
            }
            
            required init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                self.y = try container.decode(Int.self)
                try super.init(from: try container.superDecoder())
            }
            
            override func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(y)
                try super.encode(to: container.superEncoder())
            }
        }
        
        let b = B(x: 5)
        b.y = 4
        
        let encoded = try! CyclicEncoder().flatten(b)
        let decoded = try! CyclicDecoder().decode(B.self, from: encoded)
        
        XCTAssert(decoded.x == 5 && decoded.y == 4)
    }
    
    func testKeyedSuperCoding() {
        
        class A: Codable {
            var x: Int
            
            required init(x: Int) {
                self.x = x
            }
        }
        
        class B: A {
            var y: Int
            
            enum CodingKeys: String, CodingKey {
                case y
            }
            
            required init(x: Int) {
                self.y = 0
                super.init(x: x)
            }
            
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.y = try container.decode(Int.self, forKey: .y)
                try super.init(from: try container.superDecoder())
            }
            
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(y, forKey: .y)
                try super.encode(to: container.superEncoder())
            }
        }
        
        let b = B(x: 5)
        b.y = 4
        
        let encoded = try! CyclicEncoder().flatten(b)
        let decoded = try! CyclicDecoder().decode(B.self, from: encoded)
        
        XCTAssert(decoded.x == 5 && decoded.y == 4)
    }
    
    func testCodingPathReporting() {
        
        class A: Codable {
            
            class B: Codable {
                func encode(to encoder: Encoder) throws {
                    XCTAssertEqual(encoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "b")
                    let container = encoder.unkeyedContainer()
                    XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "b")
                }
                
                required init(from decoder: Decoder) throws {
                    XCTAssertEqual(decoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "b")
                    let container = try decoder.unkeyedContainer()
                    XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "b")
                }
                
                init() {}
            }
            
            class C: Codable {
                
                class D: Codable {
                    
                    class E: Codable {
                        func encode(to encoder: Encoder) throws {
                            XCTAssertEqual(encoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d/e")
                            var container = encoder.singleValueContainer()
                            XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d/e")
                            try container.encode(false)
                        }
                        
                        required init(from decoder: Decoder) throws {
                            XCTAssertEqual(decoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d/e")
                            let container = try decoder.singleValueContainer()
                            XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d/e")
                            _ = try container.decode(Bool.self)
                        }
                        
                        init() {}
                    }
                    
                    enum Key: CodingKey {
                        case e
                    }
                    
                    func encode(to encoder: Encoder) throws {
                        XCTAssertEqual(encoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d")
                        var container = encoder.container(keyedBy: Key.self)
                        XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d")
                        try container.encode(E(), forKey: .e)
                    }
                    
                    required init(from decoder: Decoder) throws {
                        XCTAssertEqual(decoder.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d")
                        let container = try decoder.container(keyedBy: Key.self)
                        XCTAssertEqual(container.codingPath.map({ $0.stringValue }).joined(separator: "/"), "c/d")
                        _ = try container.decode(E.self, forKey: .e)
                    }
                    
                    init() {}
                }
                
                let d: D
                
                init() {
                    d = D()
                }
            }
            
            let b: B
            let c: C
            
            init() {
                b = B()
                c = C()
            }
        }
        
        let a = A()
        
        let flattened = try! CyclicEncoder().flatten(a)
        _ = try! CyclicDecoder().decode(A.self, from: flattened)
    }
    
    func testDuplicatesUsageExample() {
        
        class Helper: Codable {
            // ...
        }
        
        struct Thing: Codable {
            var helper: Helper
            // ...
        }
        
        let helga = Helper()
        let helen = Helper()
        
        let things = [Thing(helper: helga), Thing(helper: helen), Thing(helper: helga)]
        
        // Use CyclicCoding's encoder to handle the duplicates for us
        let flattened = try! CyclicEncoder().flatten(things)
        // Encode the intermediate representation it produced to data we can write to a file
        let data = try! JSONEncoder().encode(flattened)
        
        // Decode the intermediate representation from the data
        let decoded = try! JSONDecoder().decode(FlattenedContainer.self, from: data)
        // Use CyclicCoding's decoder to reconstruct our objects correctly
        let unflattened = try! CyclicDecoder().decode([Thing].self, from: decoded)
        
        XCTAssert(unflattened.count == 3) // there are 3 things in the array
        XCTAssert(unflattened[0].helper === unflattened[2].helper) // helga is the helper for both of these
        XCTAssert(unflattened[0].helper !== unflattened[1].helper) // helga is not helen
    }
    
    func testCyclesUsageExample() {
        
        struct Action: Codable {
            // use CyclicCoding's cycle breaker to ensure the cycle can be decoded correctly
            // weak var queue: ActionQueue?
            var queue = WeakCycleBreaker<ActionQueue>()
            // ...
        }
        
        class ActionQueue: Codable {
            var actions: [Action] = []
            // ...
            func add(action: Action) {
                var action = action
                // an empty subscript [] is used to access the object inside the cycle breaker,
                // much like ! after an optional
                action.queue[] = self
                actions.append(action)
            }
        }
        
        let queue = ActionQueue()
        let wasteTime = Action()
        let somethingUseful = Action()
        queue.add(action: wasteTime)
        queue.add(action: somethingUseful)
        
        // Use CyclicCoding's encoder to handle the cycles for us
        let flattened = try! CyclicEncoder().flatten(queue)
        // Encode the intermediate represntation it produced to data we can write to a file
        let data = try! JSONEncoder().encode(flattened)
        
        // Decode the intermediate representation from the data
        let decoded = try! JSONDecoder().decode(FlattenedContainer.self, from: data)
        // Use CyclicCoding's decoder to reconstruct the cycles correctly
        let unflattened = try! CyclicDecoder().decode(ActionQueue.self, from: decoded)
        
        XCTAssert(unflattened.actions.count == 2) // there are 2 actions in the queue
        XCTAssert(unflattened.actions[0].queue[] === unflattened) // each action correctly references the queue, not a copy
        XCTAssert(unflattened.actions[1].queue[] === unflattened)
    }

}
