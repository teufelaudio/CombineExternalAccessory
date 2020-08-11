//
//  UnconfiguredExternalAccessoryBrowser.swift
//  CombineExternalAccessory
//
//  Created by Luis Reisewitz on 05.08.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import ExternalAccessory
import Foundation

public struct UnconfiguredExternalAccessoryBrowserType: Publisher {
    public typealias Output = UnconfiguredExternalAccessoryBrowser.Event
    public typealias Failure = UnconfiguredExternalAccessoryBrowser.Error

    private let onReceive: (AnySubscriber<Output, Failure>) -> Void

    public init<P: Publisher>(publisher: P) where P.Output == Output, P.Failure == Failure {
        onReceive = publisher.receive(subscriber:)
    }

    public init(browser: UnconfiguredExternalAccessoryBrowser) {
        self.init(publisher: browser)
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        onReceive(AnySubscriber(subscriber))
    }
}

public class UnconfiguredExternalAccessoryBrowser {
    private let predicate: NSPredicate?

    public init(
        predicate: NSPredicate? = nil
    ) {
        self.predicate = predicate
    }
}

extension UnconfiguredExternalAccessoryBrowser: Publisher {
    public typealias Output = Event
    public typealias Failure = Error

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = Subscription(subscriber: subscriber, predicate: predicate)
        subscriber.receive(subscription: subscription)
    }
}

extension UnconfiguredExternalAccessoryBrowser {
    private class Subscription<SubscriberType: Subscriber>: SimpleSubscription<SubscriberType>
    where SubscriberType.Input == Output, SubscriberType.Failure == Failure {
        /// Which browser to use for discovering WAC devices.
        private let browser: EAWiFiUnconfiguredAccessoryBrowser
        /// Which predicate to use for filtering events.
        private let predicate: NSPredicate?
        /// Delegate that is used for the browser to notify us about changes.
        private let browserDelegate = BrowserDelegate()

        init(subscriber: SubscriberType, predicate: NSPredicate?) {
            self.browser = EAWiFiUnconfiguredAccessoryBrowser()
            self.predicate = predicate

            super.init(subscriber: subscriber)
            browserDelegate.didUpdateState = { [weak self] _, state in
                guard let `self` = self else { return }
                switch state {
                case .wiFiUnavailable:
                    self.complete(completion: .failure(.wifiUnavailable))
                case .stopped, .configuring:
                    self.complete(completion: .finished)
                case .searching:
                    break
                @unknown default:
                    break
                }
            }

            browserDelegate.didFindUnconfiguredAccessories = { [weak self] _, accessories in
                guard let `self` = self else { return }
                let accessories = accessories.map { UnconfiguredExternalAccessory(accessory: $0) }
                _ = self.buffer?.buffer(value: .didFindUnconfiguredAccessories(accessories: accessories))
            }
            browserDelegate.didRemoveUnconfiguredAccessories = { [weak self] _, accessories in
                guard let `self` = self else { return }
                let accessories = accessories.map { UnconfiguredExternalAccessory(accessory: $0) }
                _ = self.buffer?.buffer(value: .didRemoveUnconfiguredAccessories(accessories: accessories))
            }

            // We don't need didFinishConfiguring here.
        }

        override func start() {
            browser.delegate = browserDelegate
            browser.startSearchingForUnconfiguredAccessories(matching: predicate)
        }

        override func stop() {
            browser.stopSearchingForUnconfiguredAccessories()
        }

        private func complete(completion: Subscribers.Completion<Failure>) {
            buffer?.complete(completion: completion)
            buffer = nil
        }
    }
}

// MARK: - Model
extension UnconfiguredExternalAccessoryBrowser {
    public enum Event {
        case didFindUnconfiguredAccessories(accessories: [UnconfiguredExternalAccessory])
        case didRemoveUnconfiguredAccessories(accessories: [UnconfiguredExternalAccessory])
    }

    public enum Error: Swift.Error {
        /// Sent to the NSNetServiceBrowser instance's delegate when an error in searching for domains or services has occurred.
        /// The error dictionary will contain two key/value pairs representing the error domain and code
        /// (see the NSNetServicesError enumeration above for error code constants).
        /// It is possible for an error to occur after a search has been started successfully.
        case wifiUnavailable
    }
}
