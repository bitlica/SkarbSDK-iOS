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
pod 'SkarbSDK'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding SkarbSDK as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/bitlica/SkarbSDK.git", .upToNextMajor(from: "0.4.16"))
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

### Send features 

Using for loging the attribution.

```swift
import SkarbSDK

SkarbSDK.sendSource(broker: SKBroker,
                    features: [String: Any])
```
#### Params:
```broker``` indicates what service you use for attribution. There are three predefined brokers: ```facebook```, ```searchads```, ```appsflyer```. Also might be used any value - ```SKBroker.custom(String)```.

```features```. See features paragraphe, supported features has a string type, not supported are ignored silently. 


### Send purchase event 

You have to use this call if ```isObservable``` during initialization is ```false```.

```swift
import SkarbSDK

SkarbSDK.sendPurchase(productId: String,
                      price: Float,
                      currency: String)													 
```
#### Params:
```productId``` It’s a SKProduct.productIdentifier of purchased product

```price``` It’s a SKProduct.price

```currency``` It’s SKProduct.priceLocale.currencyCode

#### Example for Appsflyer:
In delegate mothod:

```swift
import SkarbSDK

func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
    SkarbSDK.sendSource(broker: .appsflyer, features: conversionInfo)
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


## License
[MIT](https://choosealicense.com/licenses/mit/)

