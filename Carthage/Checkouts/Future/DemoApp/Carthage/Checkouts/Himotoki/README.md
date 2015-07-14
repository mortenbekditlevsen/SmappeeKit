# Himotoki

[![Join the chat at https://gitter.im/ikesyo/Himotoki](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ikesyo/Himotoki?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![Circle CI](https://img.shields.io/circleci/project/ikesyo/Himotoki/master.svg?style=flat)](https://circleci.com/gh/ikesyo/Himotoki)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Himotoki (紐解き) is a type-safe JSON decoding library purely written in Swift. This library is highly inspired by popular JSON parsing libraries in Swift: [Argo](https://github.com/thoughtbot/Argo) and [ObjectMapper](https://github.com/Hearst-DD/ObjectMapper).

_Himotoki_ has the same meaning of 'decoding' in Japanese.

- Just do JSON decoding (deserialization) well. JSON encoding (serialization) would not be supported going forward. :wink:
- Much simpler API.
- Fail-fast conditional model building. This is useful for some `struct`s with non-optional `let` properties.
- No external dependencies.

See a simple example from a test code:

```swift
struct Group: Decodable {
    let name: String
    let floor: Int
    let optional: [String]?

	// MARK: Decodable

    static func decode(e: Extractor) -> Group? {
        // Initializer as a function
        let create = { Group($0) }

        // Create an arguments list which itself is optional,
        // then use it with `Optional.map()`
        return build(
            e <| "name",
            e <| "floor",
            e <||? "optional"
        ).map(create)
    }
}

func testGroup() {
   var JSON: [String: AnyObject] = [ "name": "Himotoki", "floor": 12 ]

   let g: Group? = decode(JSON)
   XCTAssert(g != nil)
   XCTAssert(g?.name == "Himotoki")
   XCTAssert(g?.floor == 12)
   XCTAssert(g?.optional == nil)

   JSON["name"] = nil
   let f: Group? = decode(JSON)
   XCTAssert(f == nil)
}
```

## Requirements

- Swift 1.2 (Xcode 6.3 or later)
- iOS 8.0 or later (by Carthage) / iOS 7 (by coping the source files directly)
- OS X 10.9 or later

## Installation

There are 2 options. If your app support iOS 7, you can only use the latter way.

### [Framework with Carthage](https://github.com/Carthage/Carthage) (preferable)

- Add `github "ikesyo/Himotoki"` to your Cartfile.
- Run `carthage update`.

### Copying the source files directly

- Add this repository as a git submodule:

```swift
$ git submodule add https://github.com/ikesyo/Himotoki.git PATH_TO_SUBMODULE

// or

$ carthage update --use-submodules
```

- Then just add references of `Himotoki/*.swift` to your Xcode project.

## License

Himotoki is released under the [MIT License](LICENSE.md).
