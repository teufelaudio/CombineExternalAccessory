//
//  SimpleSubscription.swift
//  CombineExternalAccessory
//
//  Created by Luis Reisewitz on 06.08.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import Foundation

class SimpleSubscription<SubscriberType: Subscriber>: Combine.Subscription {
    // MARK: Internal State Machine Properties
    var buffer: DemandBuffer<SubscriberType>?
    // We need a lock to update the state machine of this Subscription
    private let lock = NSRecursiveLock()
    // The state machine here is only a boolean checking if the subscription has started.
    // If should start when there's demand for the first time (not necessarily on subscription)
    // Only demand starts the side-effect, so we have to be very lazy and postpone the side-effects as much as possible
    private var started: Bool = false

    init(subscriber: SubscriberType) {
        self.buffer = DemandBuffer(subscriber: subscriber)
    }

    public func request(_ demand: Subscribers.Demand) {
        guard let buffer = self.buffer else { return }

        lock.lock()

        if !started && demand > .none {
            // There's demand, and it's the first demanded value, so we start browsing
            started = true
            lock.unlock()

            start()
        } else {
            lock.unlock()
        }

        // Flush buffer
        // If subscriber asked for 10 but we had only 3 in the buffer, it will return 7 representing the remaining demand
        // We actually don't care about that number, as once we buffer more items they will be flushed right away, so simply ignore it
        _ = buffer.demand(demand)
    }

    public func cancel() {
        buffer = nil
        started = false
        stop()
    }

    open func start() {
        fatalError("SimpleSubscription.start needs to be overridden")
    }

    open func stop() {
        fatalError("SimpleSubscription.stop needs to be overridden")
    }

    private func complete(completion: Subscribers.Completion<SubscriberType.Failure>) {
        buffer?.complete(completion: completion)
        buffer = nil
    }
}
