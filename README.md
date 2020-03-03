## Introduction
SkarbSDK is a framework that makes you happier.

## Installation
SkarbSDK can be installed with CocoaPods. Simply add pod 'SkarbSDK' to your Podfile.

## Usage
### Initialization 

```swift
import SkarSDK

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
      SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: true, isDebug: isDebug)
    }
}
```
#### Notes:
```clientId``` You could get it in your account dashboard.

```isObservable``` Automatically sends all events about purchases that are in your app. If you want to send a purchase event manually you should set this param to false and call SkarbSDK.sendPurchase() method.

```isDebug``` Use this flag for testing events, etc. (not supported yet)

### Log features 

Using for loging the attribution.

```swift
import SkarSDK

SkarbSDK.sendSource(source: SKSource,
                    features: [String: Any],
                    completion: @escaping (SKResponseError?)
```
#### Notes:
```source``` indicates what service you use for attribution. There are three predefined sources: ```facebook```, ```searchads```, ```appsflyer```. Also might be used any value - ```SKSource.custom(String)```.

```features```. See features paragraphe, supported features has a string type, not supported are ignored silently. 


### Send purchase event 

You have to use this call if ```isObservable``` during initialization is ```false```

```swift
import SkarSDK

SkarbSDK.sendPurchase(productId: String,
                      price: Float? = nil,
                      currency: String? = nil,
                      completion: ((SKResponseError?) -> Void)? = nil)													 
```
#### Notes:
```productId``` It’s a SKProduct.productIdentifier of purchased product

```price``` It’s a SKProduct.price

```currency``` It’s SKProduct.priceLocale.currencyCode

### A/B testing

```swift
import SkarSDK

SkarbSDK.sendSource(source: SKSource,
                    features: [String: Any],
                    completion: @escaping (SKResponseError?) -> Void)													 
```
#### Notes:
```name``` Name of A/B test

```group``` Group name of A/B test. For example: control group, B, etc.


## License
[MIT](https://choosealicense.com/licenses/mit/)
