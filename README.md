# SmappeeKit
SmappeeKit is an implementation of the [Smappee API](https://smappee.atlassian.net/wiki/display/DEVAPI/SmappeeDevAPI+Home) in Swift.
This project is dependent on the [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) library and on my own development fork of [LlamaKit](https://github.com/mortenbekditlevsen/LlamaKit) (until the LlamaKit developers hopefully accept my pull requests! :-)

The implementation focuses on ease of use of the API. This means that you can call any API method - and in case the user is not logged in, or the access token has expired, then SmappeeKit will do what is needed, and perform the requested method once login or token refresh has happened.

SmappeeKit never stores username or password - and neither should the code that uses it. Instead it optionally stores the access token and the refresh token received when authenticating the user. You may also opt out of having SmappeeKit store the tokens, and provide these yourself instead.

The architecture in the code has been inspired by the article [Error handling in Swift](http://nomothetis.svbtle.com/error-handling-in-swift), and eventually I will probably change it to use [LlamaKit](https://github.com/LlamaKit/LlamaKit) for the 'Result' abstraction.

Furthermore I am working on a block-based extension of the 'map' concept in LlamaKit. This should make it easy to tunnel a series of API calls and have error handling only happen in one place.

### Note ###
The current version of the source code is made for the Xcode 6.3 beta version of Swift.

### Also note ###
In accordance with [The CocoaPods documentation](http://guides.cocoapods.org/using/using-cocoapods.html#should-i-ignore-the-pods-directory-in-source-control), the Pods directory has been committed along with the project.

### TODO ###
* Finish this README text
* ~~Add Swift structs to represent the data types returned by the Smappee API~~
* ~~Add a test suite~~
* ~~Use LlamaKit Result type~~
* Add a PodSpec so SmappeeKit can be used with CocoaPods
