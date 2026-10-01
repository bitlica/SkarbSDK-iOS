## Introduction
SkarbSDK is a framework that makes you happier.
It automatically reports: 
1. install event - during SDK initialization phase. 
2. subscription event - this event could be reported manually as well by `sendPurchase()`, though it's not recommended way. 

In addition, you could enrich these events with features obtained from the traffic source by explicit call of `sendSource()` method. And if you're interesting in split testing inside an app take a look on `sendTest()` method.

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate SkarbSDK into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'SkarbSDK', '~> 0.6'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding SkarbSDK as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/bitlica/SkarbSDK.git", .upToNextMajor(from: "0.6.34"))
]
```

## Usage
### Initialization 

```swift
import SkarbSDK

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
      SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: true, deviceId: "YOUR_DEVICE_ID")
    }
}
```
#### Params:
```clientId``` You could get it in your account dashboard.

```isObservable``` Automatically sends all events about purchases that are in your app. If you want to send a purchase event manually you should set this param to ```false``` and see ```Send purchase event``` section. Default value is ```true```.

```deviceId``` If you want to can use your own generated deviceId. Default value is ```nil```.

```isAnalyticsEnabled``` The user's analytics consent, see ```Analytics consent``` section. Default value is ```nil```: the last value set, on by default.

### Send features 

Using for loging the attribution.

```swift
import SkarbSDK

SkarbSDK.sendSource(broker: SKBroker,
                    features: [String: Any],
                    brokerUserID: String?)
```
#### Params:
```broker``` indicates what service you use for attribution. There are three predefined brokers: ```facebook```, ```searchads```, ```appsflyer```. Also might be used any value - ```SKBroker.custom(String)```.

```features```. See features paragraphe, supported features has a string type, not supported are ignored silently. 

```brokerUserID```. Use the unique userID for this SKBroker if you want to use postbacks. For example, for Appsflyer - AppsFlyerLib.shared().getAppsFlyerUID()

#### Example for Appsflyer:
In delegate mothod:

```swift
import SkarbSDK

func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
    SkarbSDK.sendSource(broker: .appsflyer,
                        features: conversionInfo,
                        brokerUserID: AppsFlyerLib.shared().getAppsFlyerUID())
}
```


### A/B testing

```swift
import SkarbSDK

SkarbSDK.sendTest(name: String,
                  group: String)
```
#### Params:
```name``` Name of A/B test

```group``` Group name of A/B test. For example: control group, B, etc.


### IDFA
SkarbSDK automaticaly collects IDFA. If you want to disable it, please set ```false``` before ```SkarbSDK.initialize()``` method. The default value is ```true```
```swift
import SkarbSDK

SkarbSDK.automaticCollectIDFA = false
```
Also you can sent idfa after getting ```status``` from ```ATTrackingManager.requestTrackingAuthorization()``` and if the the ```status``` is ```.authorized``` get idfa from ```ASIdentifierManager.shared().advertisingIdentifier.uuidString``` and use this method:
```swift
SkarbSDK.sendIDFA(idfa: String?)
```

### Reset device id
After the user's data has been erased on their request, switch the SDK to a new device id so
the device is reported as a fresh install from then on:

```swift
import SkarbSDK

let newDeviceId = SkarbSDK.resetDeviceId() // or SkarbSDK.resetDeviceId(newDeviceId: "YOUR_NEW_DEVICE_ID")
```

- A new install is sent for the new id, together with IDFA and Apple Search Ads attribution if
  they are enabled. Everything tied to the old install - install, `sendSource`, `sendTest` and
  `sendIDFA` data, pending logs - is dropped, sent or not. Call `sendSource` / `sendTest` /
  `sendIDFA` again if the new install needs them.
- Purchase data is kept: queued purchases are still delivered with the old device id, and the
  cached purchase info stays, so a subscriber keeps access. The next `validateReceipt` verifies
  it for the new id.
- If you pass your own `deviceId` to `initialize`, pass the new one on every launch from now on.
- Called before `initialize`, it only saves the new id; `initialize` sends the install for it.
- Nothing is erased on the server.

### Analytics consent
Apply the user's analytics consent (GDPR), e.g. when it is revoked from the app's settings.
The value is saved, so pass it to `initialize` too if consent can change while the app is not running:

```swift
import SkarbSDK

SkarbSDK.setAnalyticsEnabled(false)
```

- Off, purchases keep working (install, receipt and purchase validation), and the rest stops:
  `sendSource`, `sendTest` and `sendIDFA` are ignored, IDFA and Apple Search Ads attribution are
  not collected, the install and purchase requests go without IDFV and with a zeroed IDFA, and the
  SDK's error logs are not sent.
- Queued source, test, IDFA, Search Ads and log data is dropped, sent or not, so it is sent again
  once consent is given back. Call `sendSource` / `sendTest` / `sendIDFA` again then if they are
  needed.
- Can be called on any thread, before `initialize` too. Nothing is erased on the server.

### Logging
If you want to see errors and warning from SkarbSDK , please use set ```true``` before  ```SkarbSDK.initialize()``` method.  The default value is ```false```
```swift
import SkarbSDK

SkarbSDK.isLoggingEnabled = true
```

## License
[MIT](https://choosealicense.com/licenses/mit/)

