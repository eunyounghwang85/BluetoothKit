//
//  BluetoothKit
//
//  Copyright (c) 2015 Rasmus Taulborg Hummelmose - https://github.com/rasmusth
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import CoreBluetooth

internal class BKScanner: BKCBCentralManagerDiscoveryDelegate {

    // MARK: Type Aliases

    internal typealias ScanCompletionHandler = ((_ result: [BKDiscovery]?, _ error: BKError?) -> Void)

    // MARK: Enums

    internal enum BKError: Error {
        case noCentralManagerSet
        case busy
        case interrupted
    }

    // MARK: Properties

    internal var configuration: BKConfiguration!
    internal var centralManager: CBCentralManager!
    private var busy = false
    private var scanHandlers: (progressHandler: BKCentral.ScanProgressHandler?, completionHandler: ScanCompletionHandler )?
    private var discoveries = [BKDiscovery]()
    private var durationTimer: Timer?

    // MARK: Internal Functions

    internal func scanWithDuration(_ duration: TimeInterval, updateDuplicates: Bool, progressHandler: BKCentral.ScanProgressHandler? = nil, completionHandler: @escaping ScanCompletionHandler) throws {
        do {
            try validateForActivity()
            busy = true
            scanHandlers = ( progressHandler: progressHandler, completionHandler: completionHandler)
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: updateDuplicates]
            centralManager.scanForPeripherals(withServices: configuration.serviceUUIDs, options: options)
            if duration > 0 {
                durationTimer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(BKScanner.durationTimerElapsed), userInfo: nil, repeats: false)
            }
        } catch let error {
            throw error
        }
    }

    internal func interruptScan() {
        guard busy else {
            return
        }
        endScan(.interrupted)
    }

    // MARK: Private Functions

    private func validateForActivity() throws {
        guard !busy else {
            throw BKError.busy
        }
        guard centralManager != nil else {
            throw BKError.noCentralManagerSet
        }
    }

    @objc private func durationTimerElapsed() {
        endScan(nil)
    }

    private func endScan(_ error: BKError?) {
        invalidateTimer()
        centralManager.stopScan()
        let completionHandler = scanHandlers?.completionHandler
        let discoveries = self.discoveries
        scanHandlers = nil
        self.discoveries.removeAll()
        busy = false
        completionHandler?(discoveries, error)
    }

    private func invalidateTimer() {
        if let durationTimer = self.durationTimer {
            durationTimer.invalidate()
            self.durationTimer = nil
        }
    }

    // MARK: BKCBCentralManagerDiscoveryDelegate

    internal func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard busy else {
            return
        }
        
        /*
        var name = peripheral.name
        if name == nil {
            name = peripheral.identifier.uuidString
        }
        
        print("-- Peripheral discovered")
        print("-- Peripheral name - status : " + (name ?? "x") + " - " + getState(peripheral.state))
        print("-- Peripheral uuid: " + peripheral.identifier.uuidString)
        print("-- Peripheral adv : " + String(describing: advertisementData))*/
        
        let acceptNames = configuration.advertisementNAMES
        //getname(advertisementData).contains("B0001")
        let peripheralname = getname(advertisementData)
        
        guard acceptNames.count  < 1 ||  (acceptNames.contains(where: {peripheralname.contains($0)})) else {
            return
        }
        
        let RSSI = Int(truncating: RSSI)
        let remotePeripheral = BKRemotePeripheral(identifier: peripheral.identifier, peripheral: peripheral)
        remotePeripheral.configuration = configuration
        let discovery = BKDiscovery(advertisementData: advertisementData, remotePeripheral: remotePeripheral, RSSI: RSSI)
        
        if let index = discoveries.firstIndex(of: discovery) {
            discoveries[index] = discovery
        } else {
            discoveries.append(discovery)
        }
        scanHandlers?.progressHandler?([ discovery ])
    }
    
    func getState(_ state: CBPeripheralState) -> String {
        if state == .connected {
            return "connected"
        }
        if state == .connecting {
            return "connecting"
        }
        if state == .disconnected {
            return "disconnected"
        }
        if state == .disconnecting {
            return "disconnecting"
        }
        return ""
    }
    
    func getname(_ advertisementData: [String: Any]) -> String {
        
        guard  let name =  advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return ""
        }
      
        return name
    }
    

    

}
