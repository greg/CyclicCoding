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
        
        XCTAssert(encoded.description == "[{ a: { x: 1, y: 2 }, s: \"hi\" }]", "Encoded incorrectly: \(encoded).")
        
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
        
        XCTAssert(encoded.description == "[{ x: 5 }, { c: #0, d: #0 }]", "Encoded incorrectly: \(encoded).")
        
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
        XCTAssert(encoded.description == "[{ x: 5 }, { a: { c: #0 }, c: #0 }]", "Encoded incorrectly: \(encoded).")
        
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
        
        XCTAssert(encoded.description == "[5]", "Encoded incorrectly: \(encoded).")
        
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
        
        XCTAssert(encoded.description == "[5, { c: #0, d: #0 }]", "Encoded incorrectly: \(encoded).")
        
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
        XCTAssert(encoded.description == "[[{ x: 1 }, { x: 3 }, { x: 2 }]]", "Encoded incorrectly: \(encoded).")
        
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
        XCTAssert(encodedk.description == "[{ x: [5, \"hi\", true], y: { x: 3.1415925, y: 6 } }]", "Encoded incorrectly: \(encodedk).")
        let decodedk = try! CyclicDecoder().decode(K.self, from: encodedk)
        XCTAssert(decodedk.x == k.x && decodedk.y == k.y)
        
        let u = U(x: (5, "hi", true), y: (6, .pi))
        let encodedu = try! CyclicEncoder().flatten(u)
        XCTAssert(encodedu.description == "[[[5, \"hi\", true], { x: 3.1415925, y: 6 }]]", "Encoded incorrectly: \(encodedu).")
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
        XCTAssert(encoded.description == "[{ x: 5 }, { a: #0, b: #0 }]", "Encoded incorrectly: \(encoded).")
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
        XCTAssert(encoded.description == "[{ d: { c: #0, y: 5 }, x: 4 }, #0]", "Encoded incorrectly: \(encoded).")

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
    
    func testUsageExample() {
        
        class TreeNode: Codable {
            var parent = WeakCycleBreaker<TreeNode>()
            var children: [TreeNode] = []
            
            init(parent: TreeNode?) {
                self.parent[] = parent
                parent?.children.append(self)
            }
        }
        
        let root = TreeNode(parent: nil)
        let a = TreeNode(parent: root)
        let _ = TreeNode(parent: root)
        let _ = TreeNode(parent: a)
        root.children.append(a)
        
        let flattened = try! CyclicEncoder().flatten(root)
        let json = try! JSONEncoder().encode(flattened)
        
        let decoded = try! JSONDecoder().decode(FlattenedContainer.self, from: json)
        let unflattened = try! CyclicDecoder().decode(TreeNode.self, from: decoded)
        
        XCTAssert(flattened == decoded)
        
        XCTAssert(unflattened.parent[] == nil)
        XCTAssert(unflattened.children.count == 3)
        XCTAssert(unflattened.children[0].parent[] === unflattened)
        XCTAssert(unflattened.children[0] !== unflattened.children[1])
        XCTAssert(unflattened.children[0] === unflattened.children[2])
        XCTAssert(unflattened.children[1].children.isEmpty)
        XCTAssert(unflattened.children[0].children.count == 1)
        XCTAssert(unflattened.children[0].children[0].children.isEmpty)
        
        print(flattened)
    }

}
