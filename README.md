## Introduction
SkarbSDK is a framework that makes you happier.
It automatically reports: 
1. install event - during SDK initialization phase. 
2. subscription event - this event could be reported manually as well by `sendPurchase()`, though it's not recommended way. 

In addition, you could enrich these events with features obtained from the traffic source by explicit call of `sendSource()` method. And if you're interesting in split testing inside an app take a look on `sendTest()` method.

## Installation
SkarbSDK can be installed with CocoaPods. Simply add pod 'SkarbSDK' to your Podfile.

## Usage
### Initialization 

```swift
import SkarbSDK

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
      SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: true, isDebug: isDebug)
    }
}
```
#### Params:
```clientId``` You could get it in your account dashboard.

```isObservable``` Automatically sends all events about purchases that are in your app. If you want to send a purchase event manually you should set this param to ```false``` and see ```Send purchase event``` section.

```isDebug``` Use this flag for testing events, etc. (not supported yet)

### Send features 

Using for loging the attribution.

```swift
import SkarbSDK

SkarbSDK.sendSource(source: SKSource,
                    features: [String: Any],
                    completion: @escaping (SKResponseError?)
```
#### Params:
```source``` indicates what service you use for attribution. There are three predefined sources: ```facebook```, ```searchads```, ```appsflyer```. Also might be used any value - ```SKSource.custom(String)```.

```features```. See features paragraphe, supported features has a string type, not supported are ignored silently. 


### Send purchase event 

You have to use this call if ```isObservable``` during initialization is ```false```

```swift
import SkarbSDK

SkarbSDK.sendPurchase(productId: String,
                      price: Float? = nil,
                      currency: String? = nil,
                      completion: ((SKResponseError?) -> Void)? = nil)													 
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
    SkarbSDK.sendSource(source: .appsflyer, features: conversionInfo, completion: { _ in })
}
```


### A/B testing

```swift
import SkarbSDK

SkarbSDK.sendTest(name: String,
                  group: String,
                  completion: @escaping (SKResponseError?) -> Void)
```
#### Params:
```name``` Name of A/B test

```group``` Group name of A/B test. For example: control group, B, etc.


## License
[MIT](https://choosealicense.com/licenses/mit/)
