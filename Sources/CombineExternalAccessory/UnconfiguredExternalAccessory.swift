//
//  UnconfiguredExternalAccessory.swift
//  CombineExternalAccessory
//
//  Created by Luis Reisewitz on 06.08.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import ExternalAccessory
import Foundation
import UIKit

public struct UnconfiguredExternalAccessory {
    /// Browser to use for configuring. We create a new one here, as we need to set the delegate.
    /// Switching the delegate of the existing Browser used for discovering devices would hang the discovery
    /// Publisher.
    let browser = EAWiFiUnconfiguredAccessoryBrowser()
    public let accessory: EAWiFiUnconfiguredAccessory

    /// - Warning: This completes the browser's search process and terminates the `Publisher`.
    public func configure(on viewController: UIViewController) -> UnconfiguredExternalAccessoryPublisher {
        return UnconfiguredExternalAccessoryPublisher(
            browser: browser,
            accessory: accessory,
            viewController: viewController
        )
    }

    /// The reason why a configuration for a device can be unsuccessful.
    public enum ConfigurationError: Error {
        /// User cancelled the process.
        case cancelled
        /// The process failed in any way.
        case failed
    }
}

// MARK: - Equatable
extension UnconfiguredExternalAccessory: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.accessory == rhs.accessory
    }
}

// MARK: - Hashable
extension UnconfiguredExternalAccessory: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(accessory)
    }
}

public struct UnconfiguredExternalAccessoryPublisher: Publisher {
    public typealias Output = Never
    public typealias Failure = UnconfiguredExternalAccessory.ConfigurationError

    private let browser: EAWiFiUnconfiguredAccessoryBrowser
    private let accessory: EAWiFiUnconfiguredAccessory
    private let viewController: UIViewController

    init(browser: EAWiFiUnconfiguredAccessoryBrowser, accessory: EAWiFiUnconfiguredAccessory, viewController: UIViewController) {
        self.browser = browser
        self.accessory = accessory
        self.viewController = viewController
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let subscription = UnconfiguredExternalAccessory.Subscription(
            subscriber: subscriber,
            browser: browser,
            accessory: accessory,
            viewController: viewController)
        subscriber.receive(subscription: subscription)
    }
}

extension UnconfiguredExternalAccessory {
    fileprivate class Subscription<SubscriberType: Subscriber>: SimpleSubscription<SubscriberType>
        where SubscriberType.Input == UnconfiguredExternalAccessoryPublisher.Output,
    SubscriberType.Failure == UnconfiguredExternalAccessoryPublisher.Failure {
        // MARK: Configuration Properties
        private let browser: EAWiFiUnconfiguredAccessoryBrowser
        private let accessory: EAWiFiUnconfiguredAccessory
        private let viewController: UIViewController

        /// Delegate that is used for the browser to notify us about changes.
        private let browserDelegate = BrowserDelegate()

        init(
            subscriber: SubscriberType,
            browser: EAWiFiUnconfiguredAccessoryBrowser,
            accessory: EAWiFiUnconfiguredAccessory,
            viewController: UIViewController
        ) {
            self.browser = browser
            self.accessory = accessory
            self.viewController = viewController

            super.init(subscriber: subscriber)

            browserDelegate.didFinishConfiguringAccessory = { [weak self] _, accessory, status in
                // `EAWiFiUnconfiguredAccessoryBrowser` is basically a singleton.
                // We will receive events here for all actions that are done on any
                // browser we use in our app. To make sure that this event is actually
                // for us (this accessory), we compare the accessories.
                guard let `self` = self, self.accessory == accessory else { return }

                switch status {
                case .failed:
                    self.buffer?.complete(completion: .failure(.failed))
                case .userCancelledConfiguration:
                    self.buffer?.complete(completion: .failure(.cancelled))
                case .success:
                    self.buffer?.complete(completion: .finished)
                @unknown default:
                    break
                }
            }
        }

        override func start() {
            browser.delegate = browserDelegate
            browser.configureAccessory(accessory, withConfigurationUIOn: viewController)
        }

        override func stop() {
            // NOOP, just so that we are not crashing.
        }
    }
}
