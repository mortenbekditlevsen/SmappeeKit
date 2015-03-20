# SmappeeKit
SmappeeKit is an implementation of the [Smappee API](https://smappee.atlassian.net/wiki/display/DEVAPI/SmappeeDevAPI+Home) in Swift.
This project is dependent on the [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) library and on my own development fork of [LlamaKit](https://github.com/mortenbekditlevsen/LlamaKit) (until the LlamaKit developers hopefully accept my pull requests! :-)

The implementation focuses on ease of use of the API. This means that you can call any API method - and in case the user is not logged in, or the access token has expired, then SmappeeKit will do what is needed, and perform the requested method once login or token refresh has happened.

SmappeeKit never stores username or password - and neither should the code that uses it. Instead it optionally stores the access token and the refresh token received when authenticating the user. You may also opt out of having SmappeeKit store the tokens, and provide these yourself instead.

The architecture in the code has been inspired by the article [Error handling in Swift](http://nomothetis.svbtle.com/error-handling-in-swift), and I am using [LlamaKit](https://github.com/LlamaKit/LlamaKit) for the 'Result' abstraction.

Furthermore I have implemented a block-based extension of the 'map' concept in LlamaKit. This makes it really easy to tunnel a series of API calls and have error handling only happen in one place.

### Note ###
The current version of the source code is made for the Xcode 6.3 beta version of Swift.

### Usage ###
Using SmappeeKit is really easy. You instantiate a SmappeeController object with the client id and client secret you receive from Smappee (You can write to info@smappee.com and ask for these credentials. Note that the API is for non-commercial use).
You need to implement a delegate protocol which includes a single method.
This method is used when the user of your app is asked to log in.  Note that your app should never ever store the user's username or password. Instead you should just pass these along to SmappeeKit, and they will be exchanged for an access token which is ok to store in your app. All this is handled by SmappeeKit.

Initialisation:

```swift
let smappeeController = SmappeeController(clientId: "MY_CLIENT_ID", 
                                          clientSecret: "MY_CLIENT_SECRET")
smappeeController.delegate = self
```

Example delegate method:
```swift
    func loginWithCompletion(completion: (SmappeeCredentialsResult) -> Void) {
        loginCompletion = completion
        
        let loginViewController = self.storyboard?.instantiateViewControllerWithIdentifier("loginViewController") as? LoginViewController
        
        if let loginViewController = loginViewController {
            loginViewController.delegate = self
            self.presentViewController(loginViewController, animated: true, completion: nil)
        }
        else {
            loginCompletion?(smappeeLoginFailure("Could not present login UI"))
            loginCompletion = nil
        }
    }
```

When the delegate method is called, your code must call the supplied completion handler exactly once. For instance you could do this after presenting a login UI. In the following example we imagine that the login UI calls the following delegate method once the user has entered username and password
```swift
    func loginViewController(loginViewController: LoginViewController, didReturnUsername username: String, password: String) {

        self.dismissViewControllerAnimated(true, completion: nil)

        loginCompletion?(smappeeLoginSuccess(username, password))
        loginCompletion = nil
    }
```

Now the API knows how to authenticate the user. This will automatically happen the first time you use any of the API methods on the SmappeeController instance. If the user has already logged in, a valid access token and refresh token will already be registered, and it will not be necessary to log in again.

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
This short snippet of code both handles any login, refreshing of access token depending on whether that is necessary, then gets a list of locations - gets the first of these (emitting an error if it went wrong), sends a location info request, which contains a list of actuators. If no actuators are found it emits an error - otherwise it turns on the actuator. Beautiful, right! ;-)


### Also note ###
In accordance with [The CocoaPods documentation](http://guides.cocoapods.org/using/using-cocoapods.html#should-i-ignore-the-pods-directory-in-source-control), the Pods directory has been committed along with the project.

### TODO ###
* Finish this README text
* ~~Add Swift structs to represent the data types returned by the Smappee API~~
* ~~Add a test suite~~
* ~~Use LlamaKit Result type~~
* Add a PodSpec so SmappeeKit can be used with CocoaPods
