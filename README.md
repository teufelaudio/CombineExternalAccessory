# CombineExternalAccessory
Combine Wrapper for ExternalAccessory.framework.

Currently implements browsing for unconfigured WAC (Wireless Accessory Configuration) devices
and allows to start the configuration process for these in your app.

This is implemented in Apple's ExternalAccessory framework. That framework (and this wrapper)
is basically just an interface to Apple's MFi process.

## Installation

Installation via SPM.

## Usage

To get an array of the currently unconfigured devices, use and subscribe to `UnconfiguredExternalAccessoryBrowser`.
Subscribing to this publisher will start searching for unconfigured devices and deliver these as events. 

These are the possible events:
```
public enum Event {
    case didFindUnconfiguredAccessories(accessories: [UnconfiguredExternalAccessory])
    case didRemoveUnconfiguredAccessories(accessories: [UnconfiguredExternalAccessory])
}
```

```
UnconfiguredExternalAccessoryBrowser()
.sink { event in
    switch event {
    case let .didFindUnconfiguredAccessories(accessories):
        // Add to your list
    case let .didRemoveUnconfiguredAccessories(accessories):
        // Remove from your list
    }
}
```

Typically, you want to update your View or Store with the complete list, you could achieve this
with e.g. `scan`. Scan is like reduce but for Combine Publishers.

Example:
```
UnconfiguredExternalAccessoryBrowser()
    .scan(Set<UnconfiguredExternalAccessory>(), { (aggr, event) in
        var copy = aggr
        switch event {
        case let .didFindUnconfiguredAccessories(accessories):
            copy = copy.union(accessories)
        case let .didRemoveUnconfiguredAccessories(accessories):
            copy.subtract(accessories)
        }
        return copy
    })
    .sink { allAvailableAccessories in 
        // Do something with this full list 
    }
}
```

After you have retrieved a list unconfigured accessories, you can configure them. You do this
by calling and subscribing to `UnconfiguredExternalAccessory.configure(on:)`.

This will then open a Modal on the supplied `UIViewController`. From here, the flow is controlled
by the user and the system, you have no input. After the flow has finished, failed or been cancelled
by the user, the subscription will complete.

Example:
```
// device is an UnconfiguredExternalAccessory gotten from Discovery
device
    .configure(on: viewController)
    .sink(receiveCompletion: { completion
        // Configuration has finished, either successfully or with an error
        switch completion {
        case .finished:
            // All good, user finished setting up this device
        case .failure(let error):
            switch error {
            case .cancelled:
                // User cancelled the flow
            case .failed:
                // Something failed during the process
            }
        }
    }, ...)
```

## Limitations

As this is a global external process, this is basically like a super Singleton. Starting to configure 
a device will stop searching for new devices and terminate all discovery publisher, no matter 
how many instances you create. 

This is a limitation by Apple.

Limitation: delegate dilemma

## Important
According to Apple, searching for these devices is an expensive process, so you should only 
do this if the user is actively searching (e.g. the searching view is actively visible).
**Don't run this continously.**

When using this package, you need to add the `com.apple.external-accessory.wireless-configuration` entitlement to your app.

This is how a minimal MyApp.entitlements file should look like:

    <dict>
        <key>com.apple.external-accessory.wireless-configuration</key>
        <true/>
    </dict>

