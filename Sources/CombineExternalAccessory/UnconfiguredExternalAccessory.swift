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
    public init(
        name: String,
        manufacturer: String,
        model: String,
        ssid: String,
        macAddress: String,
        properties: EAWiFiUnconfiguredAccessoryProperties
    ) {
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.ssid = ssid
        self.macAddress = macAddress
        self.properties = properties
        self.accessory = nil
    }

    public let name: String
    public let manufacturer: String
    public let model: String
    public let ssid: String
    public let macAddress: String
    public let properties: EAWiFiUnconfiguredAccessoryProperties
    let accessory: EAWiFiUnconfiguredAccessory?

    public init(accessory: EAWiFiUnconfiguredAccessory) {
        self.name = accessory.name
        self.manufacturer = accessory.manufacturer
        self.model = accessory.model
        self.ssid = accessory.ssid
        self.macAddress = accessory.macAddress
        self.properties = accessory.properties
        self.accessory = accessory
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
    public static func ==(lhs: UnconfiguredExternalAccessory, rhs: UnconfiguredExternalAccessory) -> Bool {
        lhs.name == lhs.name &&
        lhs.manufacturer == lhs.manufacturer &&
        lhs.model == lhs.model &&
        lhs.ssid == lhs.ssid &&
        lhs.macAddress == lhs.macAddress &&
        lhs.properties == lhs.properties
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
    private let unconfiguredExternalAccessory: UnconfiguredExternalAccessory
    private let viewController: UIViewController

    public init(browser: EAWiFiUnconfiguredAccessoryBrowser, unconfiguredExternalAccessory: UnconfiguredExternalAccessory, viewController: UIViewController) {
        self.browser = browser
        self.unconfiguredExternalAccessory = unconfiguredExternalAccessory
        self.viewController = viewController
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let subscription = UnconfiguredExternalAccessory.Subscription(
            subscriber: subscriber,
            browser: browser,
            unconfiguredExternalAccessory: unconfiguredExternalAccessory,
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
        private let unconfiguredExternalAccessory: UnconfiguredExternalAccessory
        private let viewController: UIViewController

        /// Delegate that is used for the browser to notify us about changes.
        private let browserDelegate = BrowserDelegate()

        init(
            subscriber: SubscriberType,
            browser: EAWiFiUnconfiguredAccessoryBrowser,
            unconfiguredExternalAccessory: UnconfiguredExternalAccessory,
            viewController: UIViewController
        ) {
            self.browser = browser
            self.unconfiguredExternalAccessory = unconfiguredExternalAccessory
            self.viewController = viewController

            super.init(subscriber: subscriber)

            browserDelegate.didFinishConfiguringAccessory = { [weak self] _, accessory, status in
                // `EAWiFiUnconfiguredAccessoryBrowser` is basically a singleton.
                // We will receive events here for all actions that are done on any
                // browser we use in our app. To make sure that this event is actually
                // for us (this accessory), we compare the accessories.
                guard let `self` = self,
                      self.unconfiguredExternalAccessory.accessory?.macAddress == accessory.macAddress
                else { return }

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
            guard let accessory = unconfiguredExternalAccessory.accessory
                    ?? browser.unconfiguredAccessories.first(
                        where: {
                            $0.macAddress == unconfiguredExternalAccessory.macAddress
                        })
            else { return }
            browser.configureAccessory(accessory, withConfigurationUIOn: viewController)
        }

        override func stop() {
            // NOOP, just so that we are not crashing.
        }
    }
}
