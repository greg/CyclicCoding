# CyclicCoding

[![Build Status](https://travis-ci.com/greg/CyclicCoding.svg?token=j2mxyGDSpdggCDnpjKs3&branch=master)](https://travis-ci.com/greg/CyclicCoding)

## What is this?

With [`Codable`](https://developer.apple.com/documentation/swift/codable), Swift provides the ability to [de]serialise objects to and from files with little to no boilerplate or extra code.
However, no special handling is done for more complex object graphs referencing the same object multiple times, or containing cycles --- this is left up to the encoders and decoders, and the default ones also do not handle these cases.

`CyclicCoding` fills this gap, providing an [encoder](CyclicCoding/CyclicEncoder.swift) and [decoder](CyclicCoding/CyclicDecoder.swift) which code _any_ objects conforming to `Codable` to and from an [intermediate representation](CyclicCoding/Primitive.swift) which itself conforms to `Codable`.

## Who is this for?

If you have:

- A data model in which objects are referenced more than once, or contains cycles (see [usage](#usage) example); and
- You don't care too much about the structure of your encoded data and are happy to treat it as an opaque file (see [how does it work?](#how-does-it-work) for info)

then `CyclicCoding` will probably help you.

## Usage

`CyclicCoding` supports [Carthage](https://github.com/Carthage/Carthage). Follow [these instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add `CyclicCoding` to your project.

Consider the following simple data model:

```swift
class TreeNode: Codable {
    weak var parent: TreeNode?
    var children: [TreeNode] = []
    
    init(parent: TreeNode?) {
        self.parent = parent
        parent?.children.append(self)
    }
}

let root = TreeNode(parent: nil)
let a = TreeNode(parent: root)
let b = TreeNode(parent: root)
let aa = TreeNode(parent: a)
root.children.append(a) // the root now has the same child twice!
```

If we tried to encode this directly with [`JSONEncoder`](https://developer.apple.com/documentation/foundation/jsonencoder), we'd hit an infinite loop.

To work with `CyclicCoding`, we need to add a [cycle breaker](CyclicCoding/CycleBreaker.swift):

```swift
class TreeNode: Codable {
    var parent = WeakCycleBreaker<TreeNode>()
    var children: [TreeNode] = []
    
    init(parent: TreeNode?) {
        self.parent[] = parent
        parent?.children.append(self)
    }
}
```

Now, we can encode with:

```swift
let flattened = try! CyclicEncoder().flatten(root)
let json = try! JSONEncoder().encode(flattened)
```

and decode with:

```swift
let decoded = try! JSONDecoder().decode(FlattenedContainer.self, from: json)
let unflattened = try! CyclicDecoder().decode(TreeNode.self, from: decoded)
```

All cycles and duplicates will be correctly restored:

```swift
// the cycle between child and parent nodes is restored
unflattened.children[0].parent[] === unflattened // true
// the duplicated child is decoded once, not copied
unflattened.children[0] === unflattened.children[2] // true
```

**Note: no extra work is required to deduplicate objects; this is done automatically**. Cycle breakers are only needed to prevent the encoder from reaching an infinite loop (even though this would be possible to encode, there is no way to decode one in Swift).

## How does it work?

If we print `flattened` from the example above, we see the following (the JSON is similar, but longer):

```
[
  {
    children: [
      #1,
      { children: [], parent: #0 },
      #1
    ],
    parent: null
  },
  {
    children: [
      { children: [], parent: #1 }
    ],
    parent: #0
  },
  #0
]
```

The last element in the array, `#0`, is the root element. `#0` indicates a reference to the first element in the array, which describes the root node.
Inside that, we can see that it has 3 children, of which the first and last are `#1`, the duplicated child, which was encoded as a reference to avoid duplication. The middle child is encoded in place as it is not duplicated.

