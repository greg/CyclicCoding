# CyclicCoding

[![codecov](https://codecov.io/gh/greg/CyclicCoding/branch/master/graph/badge.svg)](https://codecov.io/gh/greg/CyclicCoding)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

[`Codable`](https://developer.apple.com/documentation/swift/codable) lets you encode object trees to files with almost no boilerplate. But what if the object graph you want to encode has cycles or duplicates?

CyclicCoding handles both of these cases with little to no changes to your data model.

## Object DAGs: objects referenced multiple times

If your data model is a [DAG](https://en.wikipedia.org/wiki/Directed_acyclic_graph), containing objects referenced multiple times, but no cycles, you don't need to change anything about your data model.
Just an extra line of code when you encode or decode, and you're good to go.

```swift
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

unflattened.count == 3                          // true; there are 3 things in the array
unflattened[0].helper === unflattened[2].helper // true; helga is the helper for both of these
unflattened[0].helper !== unflattened[1].helper // true; helga is not helen
```

Notice that if we'd simply used `JSONEncoder` directly, encoding and decoding would've succeeded, but all 3 things in the array would've had different helper objects when decoded — this is a waste of space when encoding, and decodes incorrectly.

## Object graphs with cycles: an object (eventually) references itself

If your data model contains cycles (e.g. an object that references itself; an object which has a delegate which references it), a small change must be made to the data model:

```swift
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

unflattened.actions.count == 2                  // there are 2 actions in the queue
unflattened.actions[0].queue[] === unflattened  // each action correctly references the queue, not a copy
unflattened.actions[1].queue[] === unflattened
```

A [cycle breaker](CyclicCoding/CycleBreaker.swift) is used to "break" the cycle between an action and action queue, otherwise it would not be possible to reconstruct it correctly when decoding.
The only code changes needed are to replace a `weak var x: T` with `var x: WeakCycleBreaker<T>` and to use `x[]` instead of `x` when accessing the variable.

If you have an `unowned` variable instead of a `weak` one, [`UnownedCycleBreaker`](CyclicCoding/CycleBreaker.swift) is also available.

### When to use a cycle breaker

Imagine the relevant part of your object graph as a chain of references which eventually leads back to the same object:

    a → b → c → a → ...

The cycle needs to be "broken" just once between the two occurrences of `a`, e.g. on `a`'s reference to `b`, `b`'s reference to `c`, or `c`'s reference to `a`:

    a |→ b → c → a |→ ...
    a → b |→ c → a → b |→ ...
    a → b → c |→ a → b → c |→ ...

Any of those 3 options will work fine, just choose the one which seems most logical for your data model (e.g. the link in the chain which is a weak reference).

Adding more cycle breakers than necessary is also fine, but ensure your objects don't get inadvertently released due to a lack of strong references to them.

`CyclicEncoder` _will_ throw an error if you try to encode a data model containing a cycle which can't be decoded, which should assist in debugging if you forget to use a cycle breaker where one is needed.

### Why is there no cycle breaker for strong references?

A strong reference is a `var` or `let` of a class type which is not `unowned` or `weak`.

Since any data model containing cycles must have a weak/unowned reference in one direction to avoid a retain cycle, a cycle breaker can simply be used on that reference, so there is no need for a cycle breaker type which can hold strong references.

## Installation

`CyclicCoding` supports [Carthage](https://github.com/Carthage/Carthage). Follow [these instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add `CyclicCoding` to your project.

## Limitations & caveats

- Cycle breakers [must be used to break up cycles in the object graph](#when-to-use-a-cycle-breaker).

  Even though it would be possible to encode an object graph containing a cycle, it would be impossible to decode it successfully because of how Swift initialisers work: suppose we start decoding `a`, which starts decoding `b`, which asks to start decoding `a`. We can't start decoding `a` again because this would lead to an infinite loop, and we can't return an already-decoded instance of `a` because we haven't finished decoding it.

  Cycle breakers get around this issue by initialising empty during decoding and then obtaining a reference to the correct object once it has been decoded.
  This leads to the next caveat:

- **Cycle breakers should _not_ be accessed during [`init(from:)`](https://developer.apple.com/documentation/swift/decodable/2894081-init)** as they might not yet contain a value. `WeakCycleBreaker`s will return `nil` when accessed, and `UnownedCycleBreaker`s will throw a fatal error.

  After an object's decoding initialiser has completed, cycle breakers will be safe to access.

- The [intermediate representation](CyclicCoding/Primitive.swift) may not resemble the structure of your original data model. This will be problematic if you rely on the structure of the encoded data (e.g. in JSON form) for processing done by other code which does not use `CyclicCoding` (e.g. non-Swift server backend for an iOS app).

  The intermediate representation is a property list-style data type which exists to avoid creating yet another proprietary file format.
  `FlattenedContainer` conforms to `Codable` and can be encoded to a file using `JSONEncoder` `PropertyListEncoder`, or any other method you prefer.

## How does it work?

If we print `flattened` from the first example above, we see the following (the JSON is similar, but longer):

```
referenced: [{  }],
root: [
  { helper: #0 },
  { helper: {  } },
  { helper: #0 }
]
```

The root element is the array of things that we encoded. The only referenced object, `#0`, is helga.
The first and third things in the array reference `#0` as their helper, reflecting the fact that both are the same object.

The second element encodes its helper directly with no reference, because that object is only referenced once in the encoded object graph.

`flattened` from the second example looks like this:

```
referenced: [
  { actions: [
      { queue: #0 },
      { queue: #0 }
    ]
  }
],
root: #0
```

There is one referenced element, the action queue. It is also the root element, and so the root element is encoded as a reference `#0`.

Each of the actions also references `#0` as its queue. Thus the cycle is correctly encoded and can be reconstructed.

# Contributing

Contributions are welcome! Just fork the repo and open a pull request to the master branch when you're done. Please try to write a comprehensive description of what you're contributing.

The [issues](https://github.com/greg/CyclicCoding/issues) page is a good place to start, and the [discuss tag](https://github.com/greg/CyclicCoding/labels/discuss) has issues which are open for discussion — a good place to contribute without writing any code :)

