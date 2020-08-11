//
//  BrowserDelegate.swift
//  CombineExternalAccessory
//
//  Created by Luis Reisewitz on 06.08.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import ExternalAccessory

class BrowserDelegate: NSObject, EAWiFiUnconfiguredAccessoryBrowserDelegate {
    var didUpdateState: ((EAWiFiUnconfiguredAccessoryBrowser, EAWiFiUnconfiguredAccessoryBrowserState) -> Void)?
    var didFindUnconfiguredAccessories: ((EAWiFiUnconfiguredAccessoryBrowser, Set<EAWiFiUnconfiguredAccessory>) -> Void)?
    var didRemoveUnconfiguredAccessories: ((EAWiFiUnconfiguredAccessoryBrowser, Set<EAWiFiUnconfiguredAccessory>) -> Void)?
    var didFinishConfiguringAccessory: ((EAWiFiUnconfiguredAccessoryBrowser, EAWiFiUnconfiguredAccessory, EAWiFiUnconfiguredAccessoryConfigurationStatus) -> Void)?

    // MARK: EAWiFiUnconfiguredAccessoryBrowserDelegate
    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didUpdate state: EAWiFiUnconfiguredAccessoryBrowserState) {
        didUpdateState?(browser, state)
    }

    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didFindUnconfiguredAccessories accessories: Set<EAWiFiUnconfiguredAccessory>) {
        didFindUnconfiguredAccessories?(browser, accessories)
    }

    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didRemoveUnconfiguredAccessories accessories: Set<EAWiFiUnconfiguredAccessory>) {
        didRemoveUnconfiguredAccessories?(browser, accessories)
    }

    func accessoryBrowser(_ browser: EAWiFiUnconfiguredAccessoryBrowser, didFinishConfiguringAccessory accessory: EAWiFiUnconfiguredAccessory, with status: EAWiFiUnconfiguredAccessoryConfigurationStatus) {
        didFinishConfiguringAccessory?(browser, accessory, status)
    }
}
