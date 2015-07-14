# SmappeeKit

[![Language](http://img.shields.io/badge/language-swift-brightgreen.svg?style=flat
)](https://developer.apple.com/swift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)]
(https://github.com/Carthage/Carthage)
[![License](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat
)](http://mit-license.org)
[![Issues](https://img.shields.io/github/issues/nghialv/Future.svg?style=flat
)](https://github.com/nghialv/Future/issues?state=open)


SmappeeKit is an implementation of the [Smappee API](https://smappee.atlassian.net/wiki/display/DEVAPI/SmappeeDevAPI+Home) in Swift.
This project is dependent on the [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) library and on my own development fork of [LlamaKit](https://github.com/mortenbekditlevsen/LlamaKit) (until the LlamaKit developers hopefully accept my pull requests! :-)

The implementation focuses on ease of use of the API. This means that you can call any API method - and SmappeeKit handles calling the API webservice, handles any OAuth refreshing of access token if that is necessary, calling the API webservice again, parsing the resulting JSON and calling a single completion closure with the result.

SmappeeKit never stores username or password - and neither should the code that uses it. Instead it optionally stores the access token and the refresh token received when authenticating the user. You may also opt out of having SmappeeKit store the tokens, and provide these yourself instead.

The architecture in the code has been inspired by the article [Error handling in Swift](http://nomothetis.svbtle.com/error-handling-in-swift), and I am using [LlamaKit](https://github.com/LlamaKit/LlamaKit) for the 'Result' abstraction.

Furthermore I have implemented a block-based extension of the 'map' concept in LlamaKit. This makes it really easy to tunnel a series of API calls and have error handling only happen in one place.

### Note ###
The current version of the source code is made for the Xcode 6.3 beta version of Swift.
I look very much forward to the release of Xcode 6.3 - and the following release of the xcode6.3 branch of SwiftyJSON. At that point I will add a podspec to SmappeKit so that you can use CocoaPods to install it.

### Also note ###
In accordance with [The CocoaPods documentation](http://guides.cocoapods.org/using/using-cocoapods.html#should-i-ignore-the-pods-directory-in-source-control), the Pods directory has been committed along with the project.

### Usage ###
Using SmappeeKit is really easy. You instantiate a SmappeeController object with the client id and client secret you receive from Smappee (You can write to info@smappee.com and ask for these credentials. Note that the API is for non-commercial use).

Initialisation:

```swift
let smappeeController = SmappeeController(clientId: "MY_CLIENT_ID", 
                                          clientSecret: "MY_CLIENT_SECRET")
```

Logging in:
```swift
if !smappeeController.isLoggedIn() {
    // Present login UI
    // and at some point call:
    smappeeController.login(username, password: password) { r in
        // r is a Result enum containing either a SmappeLoginStatus or an NSError
    }
}
```

Using the API:
The API is highly functional and inspired by the Error Handling article by Alexandros Salazar mentioned above.
In the following closure, r is a Result object which either represents an Failure (if something went wrong in the process of sending the request or authenticating the user) - or a Success which holds the actual response. 
```swift
  smappeeController.sendServiceLocationRequest { r in
    if let value = r.value {
       // r is now an array of ServiceLocation structs
    }
  }
```
All the other API calls are similar in structure.

You may use 'map' and 'flatMap' on the Result value to chain together serveral API methods. Besides the 'map' and 'flatMap' described by Alexandros, I have made corresponding versions that work asynchronously using closures.

This means that you may chain methods together as follows:
```swift
  smappeeController.sendServiceLocationRequest { locations in
    let firstLocation = locations.flatMap({ valueOrError($0.first, "No service locations found")})
    firstLocation.flatMap(self.smappeeController.sendServiceLocationInfoRequest) { locationInfo in
      let firstActuator = locationInfo.flatMap({ valueOrError($0.actuators.first, "No actuators found")})
      firstActuator.flatMap(self.smappeeController.sendTurnOnRequest) { r in
        // r is now a Success or a Failure propagated along from where it first went wrong
      }
    }
  }
```
This short snippet of code both handles any refreshing of access token depending on whether that is necessary, then gets a list of locations - gets the first of these (emitting an error if it went wrong), sends a location info request, which contains a list of actuators. If no actuators are found it emits an error - otherwise it turns on the actuator. Beautiful, right! ;-)

### TODO ###
* ~~Finish this README text~~
* ~~Add Swift structs to represent the data types returned by the Smappee API~~
* ~~Add a test suite~~
* ~~Use LlamaKit Result type~~
* Add a PodSpec so SmappeeKit can be used with CocoaPods
