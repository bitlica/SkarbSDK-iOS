## Introduction
SkarbSDK is a framework that makes you happier.
It automatically reports: 
1. install event - during SDK initialization phase. 
2. purchase events - observed automatically, no call needed. The SDK watches StoreKit and reports every purchase itself.

In addition, you could enrich these events with features obtained from the traffic source by explicit call of `sendSource()` method. And if you're interesting in split testing inside an app take a look on `sendTest()` method.

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate SkarbSDK into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'SkarbSDK', '~> 0.7'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding SkarbSDK as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/bitlica/SkarbSDK.git", .upToNextMajor(from: "1.0.0"))
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

```isObservable``` Who finishes StoreKit transactions. Purchase reporting does not depend on it - the SDK reports every observed purchase either way.

- ```false``` - the SDK finishes transactions itself. This is what you want unless your app already runs its own StoreKit transaction handling.
- ```true``` - your app owns finishing. Adopt ```SKStoreKitObserver``` and finish each transaction from ```skarbTransactionNeedsFinish(_:)```. An unfinished transaction is redelivered by StoreKit on every launch, so if you pass ```true``` and never finish anything, transactions pile up forever.

Required parameter, there is no default.

```deviceId``` If you want to can use your own generated deviceId. Default value is ```nil``` - the
SDK generates a UUID itself.

### Purchase state callbacks

Adopt `SKStoreKitObserver` to be told about purchase state changes. It works on both StoreKit
versions and never exposes a StoreKit type, so nothing in your conformance needs an
availability annotation.

```swift
import SkarbSDK

SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: false)
SkarbSDK.setStoreKitObserver(self)
```

```swift
extension MyPurchaseService: SKStoreKitObserver {
  func skarbPurchaseStateDidChange(_ state: SKPurchaseState, productId: String) {
    switch state {
    case .purchasing: // the purchase was started
      break
    case .deferred:   // Ask-to-Buy / SCA, waiting for approval
      break
    case .purchased, .failed:
      break
    }
  }
}
```

Every callback is delivered on the **main thread**, and one purchase produces exactly one
`.purchased`, on both StoreKit versions.

`skarbShouldAddStorePayment(productId:)` and `skarbTransactionNeedsFinish(_:)` have default
implementations - implement them only if you handle App Store promoted purchases, or if you
initialized with `isObservable: true`.

### StoreKit 2 (opt-in)

StoreKit 1 remains the default. To run the SDK on StoreKit 2:

```swift
import SkarbSDK

// Must be called BEFORE initialize()
SkarbSDK.useStoreKitVersion(.v2)
SkarbSDK.initialize(clientId: "YOUR_CLIENT_ID", isObservable: false)

// Which one actually got used
print(SkarbSDK.effectiveStoreKitVersion)
```

Requires **iOS 15**. On earlier versions the SDK silently keeps running on StoreKit 1, and
`effectiveStoreKitVersion` reports `.v1`. Calling `useStoreKitVersion` after `initialize()` is
ignored with an error in the log - the version is not switched on a live service.

#### What does NOT change

The whole purchase API is identical on both versions - same methods, same signatures, same
models, same backend payload:

`validateReceipt`, `getOfferings`, `isOfferingsAvailable`, `getCachedUserPurchaseInfoIfAvailable`,
`purchasePackage`, `restorePurchases`, `canMakePayments`, every `SKOfferPackage` property except
`storeProduct` (`isTrial`, `period`, `numberOfUnits`, `localizedPriceString`,
`monthlyLocalizedPriceString`, ...), `SKUserPurchaseInfo`, `SKOfferings`, `SKRefreshPolicy`.

#### What you have to do

1. **Adopt `SKStoreKitObserver`** if you use `SKStoreKitDelegate` for purchase state.
   `storeKitUpdatedTransaction` is **never called** on StoreKit 2 - `SKPaymentTransaction` does
   not exist there - so anything built on it (typically a purchase funnel in analytics) goes
   silent with no other symptom. See the migration table below.
2. **Stop using `SKOfferPackage.storeProduct`.** It is `nil` on StoreKit 2 and deprecated. Use
   `priceLocale`, `period`, `numberOfUnits`, `discountPeriod`, `discountPeriodDuration`,
   `introductoryOffer` instead - all available on both versions.
3. **Add `SKIncludeConsumableInAppPurchaseHistory` to your Info.plist**, set to `true`:

   ```xml
   <key>SKIncludeConsumableInAppPurchaseHistory</key>
   <true/>
   ```

   Without it `Transaction.all` omits finished consumables, so the SDK cannot prove a consumable
   purchase to the backend and crediting falls back to the backend's own pipeline. Measured on a
   sandbox build: with the key a consumable was credited in **4 seconds**; without it, **10
   minutes 38 seconds**. The key changes nothing on StoreKit 1.

4. **Call `validateReceipt` once per launch, not twice.** The SDK does not coalesce concurrent
   calls yet, so two callers firing at the same moment produce two `VerifyReceipt` requests, each
   carrying the app receipt and the signed transactions. Route your launch-time refresh through a
   single owner.

5. **Test on a real sandbox account, not an Xcode `.storekit` configuration.** A build with a
   local StoreKit configuration has no app receipt file at all, so receipt-based reporting cannot
   work there. That is a property of the test setup, not of the SDK.

#### Migration table

| StoreKit 1 delegate | Replacement | Fires on v1 | Fires on v2 |
|---|---|---|---|
| `storeKitUpdatedTransaction`, `.purchasing` | `skarbPurchaseStateDidChange(.purchasing, productId:)` | yes | yes |
| `storeKitUpdatedTransaction`, `.deferred` | `skarbPurchaseStateDidChange(.deferred, productId:)` | yes | yes |
| `storeKitUpdatedTransaction`, `.purchased` | `skarbPurchaseStateDidChange(.purchased, productId:)` | yes | yes |
| `storeKitUpdatedTransaction`, `.failed` | `skarbPurchaseStateDidChange(.failed(error), productId:)` | yes | yes |
| `storeKitUpdatedTransaction`, `.restored` | `restorePurchases(completion:)` | - | - |
| `storeKit(shouldAddStorePayment:for:)` | `skarbShouldAddStorePayment(productId:)` | yes | yes |

Both subscriptions can be active at once - `setStoreKitDelegate` and `setStoreKitObserver` are
independent. Note that on StoreKit 1 the delegate and the observer both fire, so move your
handling to one of them rather than leaving it in both, or you will count every event twice.

Keep `setStoreKitDelegate` if you need `SKPayment` / `SKProduct` for promoted purchases: the
observer's version of that callback only carries `productId`, because a StoreKit 1 type cannot
appear in a version-neutral signature.

#### Behaviour differences to be aware of

- **Entitlements come from the server and from nowhere else**, on both StoreKit versions.
  `SKUserPurchaseInfo` is built from the `verifyReceipt` answer; the SDK never adds, removes or
  overrides anything on-device, and keeps no local copy of a purchase. What follows from that on
  StoreKit 2: a purchase becomes visible only once the backend has seen it, so a `validateReceipt`
  fired in the same moment as the purchase can legitimately answer without it, and a failed
  `validateReceipt` is a failure rather than a locally-resolved answer. Credit per `transactionID`
  idempotently - the same purchase can be reported more than once.
- **Signed transactions travel alongside the receipt.** On StoreKit 2 the SDK adds Apple-signed
  transactions (`VerificationResult.jwsRepresentation`) to two requests: the purchase's own
  transaction in `SetReceipt`, and, in `VerifyReceipt`, every consumable plus every live
  entitlement from `Transaction.all` - newest first, revoked ones excluded, capped at 200. This
  is additive: the legacy receipt still travels in the same requests, and nothing extra is sent
  on StoreKit 1.
- **`purchasePackage` answers exactly once, on the main thread, always.** StoreKit 2's own
  `purchase()` is not reliable enough to drive a paywall spinner: measured on a sandbox build it
  both hung forever and answered `.userCancelled` eleven seconds after the sheet had closed with
  the user having tapped nothing - while the purchase itself went through. The SDK therefore
  answers from whichever path sees the transaction first, `purchase()` or `Transaction.updates`.
  A cancellation is reported immediately, with no grace period.
- **What the failure carries.** A cancellation is an `NSError` in `SKErrorDomain` with
  `SKError.Code.paymentCancelled`, so `error as? SKError` keeps working. Ask-to-Buy / SCA is
  `SKResponseError(errorCode: 35)` - treat it as *pending*, not as a failure: the purchase can
  still be approved later, and it then arrives through `Transaction.updates`, reaches the backend,
  and fires `skarbPurchaseStateDidChange(.purchased,...)`. A transaction whose signature does not
  verify is never reported and comes back as a failure.
- **A purchase is reported whether or not your callback runs.** Reporting is driven by
  `Transaction.updates`, not by the `purchasePackage` completion, so killing the app mid-purchase
  or ignoring the result does not lose the purchase.
- **A backlog is finished silently at launch.** Transactions the SDK already reported in an
  earlier session are finished without a second `.purchased` callback - relevant on the first
  launch after switching to `.v2` on a device with purchase history. Credit per `transactionID`
  idempotently either way.
- **`restorePurchases` calls `AppStore.sync()`**, which asks the user for their App Store
  credentials. Call it from an explicit user action only, never automatically at launch.
- **`isObservable: true` is stricter.** StoreKit 2 redelivers an unfinished transaction on every
  launch. If you pass `true` and do not implement `skarbTransactionNeedsFinish(_:)`, nothing is
  ever finished.

#### Known limitations of `.v2` today

- Concurrent `validateReceipt` calls are not coalesced - see point 4 above.
- `signed_transactions` is capped at 200 per request, newest first. A larger history is
  truncated from the oldest end, and the drop is written to the log.
- Payload size: one signed transaction is ~5.4 KB. A typical account sends ~8 of them (~45 KB)
  per `VerifyReceipt` on top of the app receipt.
- `SKStoreKitDelegate` never fires on StoreKit 2. Use `SKStoreKitObserver`.
- App Store promoted purchases are still answered through the StoreKit 1 payment queue, which
  the SDK keeps subscribed for `shouldAddStorePayment` alone. No transaction handling goes
  through it. `PurchaseIntent` (iOS 16.4+) is a follow-up.

#### Suggested rollout

1. Turn `.v2` on in an internal build. Compare the `priceV4` / `purchaseV4` / `setReceipt` /
   `transactionV4` payloads in the log against a `.v1` run of the same product - everything
   except the transaction id must match.
2. Watch your own purchase funnel events for parity. This is where a missed observer migration
   shows up.
3. Buy a subscription with an introductory offer and, if you have them, a consumable on a real
   sandbox account. Check that the entitlement appears without an app restart.
4. Only then enable it in production.

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

### Logging
If you want to see errors and warning from SkarbSDK , please use set ```true``` before  ```SkarbSDK.initialize()``` method.  The default value is ```false```
```swift
import SkarbSDK

SkarbSDK.isLoggingEnabled = true
```
Lines go to both `print` and the unified log, prefixed with the SDK version -
`[SkarbSDK-0.7.0] [info] ...`. In Console.app, filtering on the plain text `SkarbSDK` finds them
without having to know the subsystem.

## License
[MIT](https://choosealicense.com/licenses/mit/)

