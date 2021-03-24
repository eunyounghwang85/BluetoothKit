//
//  Singleton.swift
//  BKExample (iOS)
//
//  Created by Eunyoung Hwang on 2021/03/22.
//  Copyright © 2021 Rasmus Taulborg Hummelmose. All rights reserved.
//

import UIKit
import BluetoothKit
import CoreBluetooth

//Model singleton so that we can refer to this from throughout the app.
//let appControllerSingletonGlobal = Singleton()

public enum Appstate : Int {
    case appNone =  -1
    case appLaunch =  0
    case appBackground = 1
    //inactive
    case appWillResignActive = 2
    // active
    case appWillEnterForeground = 3
    case appBecomeActive = 4
    
}
class Singleton: NSObject {
    public struct appControllerSingletonGlobal {
        
        static var instance: Singleton?
        
        //static  instance = Singleton()
    }
    
    @objc class var sharedInstance: Singleton {
       /*struct appControllerSingletonGlobal {
           static  instance = Singleton()
       }*/
        guard let instance = appControllerSingletonGlobal.instance else {
            appControllerSingletonGlobal.instance = Singleton()
            return appControllerSingletonGlobal.instance!
        }
        return instance
      
   }
   /* class func sharedInstance() -> Singleton {
        return appControllerSingletonGlobal
    }*/

    // used by BLE stack
    let serialQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default) //DispatchQueue(label: "my serial queue")
    
    // Be careful. those class cannot use appController, because it would be a cyclic redundance
    let doorVcontroller = DoorViewController()
    
    // App restore after IOS killed it, and bluetooth status has changed : device switch on, or advertise something.
    var appRestored = false
    var centralManagerToRestore = ""
    var appstate : Appstate = .appNone
    var deviceReady : Bool = false
    
    public var discoveries = [BKDiscovery]()
    
    internal let central: BKCentral
    lazy var remotePeripheral: BKRemotePeripheral? = nil
    
    override init() {
        central =  BKCentral()
    }
    
    public func startCentral() {
        do {
            central.delegate = self
            central.addAvailabilityObserver(self)
               let dataServiceUUID = UUID(uuidString: "0000F1AB-0000-1000-8000-00805F9B34FB")!
               let dataServiceCharacteristicUUID = UUID(uuidString: "ED2B4E3B-2820-492F-9507-DF165285E831")!
               let configuration = BKConfiguration(dataServiceUUID: dataServiceUUID, dataServiceCharacteristicUUID: dataServiceCharacteristicUUID, UUID(uuidString: "ED2B4E3A-2820-492F-9507-DF165285E831")!, ["B0001"])
               try central.startWithConfiguration(configuration)
           } catch let error {
               print("Error while starting: \(error)")
           }
       }
    
    deinit {
        if let remoteh = remotePeripheral {
            try? central.disconnectRemotePeripheral(remoteh)
        }
        _ = try? central.stop()
       }
    
    internal func tbyteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
            withUnsafeBytes(of: value.bigEndian, Array.init)
        }
    
    

    // MARK: Target Actions

    public func sendData(_ remotePeripheral: BKRemotePeripheral? = nil) {
        guard let remotePeripheral = remotePeripheral else {
            return
        }
       // let numberOfBytesToSend: Int = Int(arc4random_uniform(950) + 50)
       // let data = Data.dataWithNumberOfBytes(numberOfBytesToSend)
        
        let numberOfBytesToSend : [UInt8] = [0x02, 0x30, 0x31, 0x43, 0x0D]
        let pos = numberOfBytesToSend.count
        let data =  Data(bytes: numberOfBytesToSend, count: pos)
        
    
        Logger.heylog("!!!hey : Prepared \(numberOfBytesToSend) bytes with MD5 hash: \(data.md5().toHexString())")
        Logger.heylog("Sending to \(remotePeripheral)")
    
        self.central.sendData(data, toRemotePeer: remotePeripheral) { data, remotePeripheral, error in
            guard error == nil else {
                Logger.heylog("Failed sending to \(remotePeripheral)")
                return
            }
            Logger.heylog("Sent to \(remotePeripheral)")
        }
    }

    
    
}

extension Singleton : BKCentralDelegate {
    
    // MARK: BKCentralDelegate
    internal func central(_ central: BKCentral, remotePeripheralDidDisconnect remotePeripheral: BKRemotePeripheral) {
      
        #if DEBUG
        self.deviceReady = false
        #else
        self.deviceReady = false
        #endif
        if let remoteh = self.remotePeripheral {
            
            do {
                try self.central.disconnectRemotePeripheral(remoteh)
                self.remotePeripheral  = nil
            } catch let error {
                self.remotePeripheral  = nil
                Logger.heylog("Error disconnecting remote peripheral: \(error)")
            }
            
            return self.scan()
        }
        
        guard let doornavc = self.doorVcontroller.navigationController,
              doornavc.viewControllers.count > 1 else {
            return self.scan()
        }
        _ = doornavc.popToViewController(self.doorVcontroller, animated: true)
        self.scan()
    }
    
    internal func scan() {
        central.scanContinuouslyWithChangeHandler({
            [weak self] changes, discoveries in
            
            guard let self  = self else {
                return
            }
            self.discoveries = discoveries
            self.doorVcontroller.ContinuousScanChangeHandlerWithVC(changes, self.discoveries)
            /*
            if self.appstate.rawValue  > Appstate.appWillResignActive.rawValue {
                self.doorVcontroller.Co ntinuousScanChangeHandlerWithVC(changes, self.discoveries)
            }
            */
            guard !self.deviceReady else {return}
            var Checkperipheral : [String : [String]] = [String : [String]]()
            let allcoveries = self.discoveries
     
            for discovery  in allcoveries {
                let name =  discovery.localName ?? "-1"
                
                // 현재 키 구분
                var tname = name.replacingOccurrences(of: "B0001_", with: "")
                tname = tname.replacingOccurrences(of: "M", with: "")
                tname = tname.replacingOccurrences(of: "S", with: "")
                var distanceArray = Checkperipheral[tname] ?? [String]()
                if !distanceArray.contains(name){
                    distanceArray.append(name)
                }
                Checkperipheral[tname] = distanceArray
                guard distanceArray.count  > 1,
                      let discover = allcoveries.filter({$0.localName == ("B0001_" + tname + "M")}).first else {
                    continue
                }
                self.connetdevice(discover)
                break
                /*if distanceArray.count > 1, let discover =  allcoveries.enumerated().filter({$0.element.localName == "B0001_" + name + "M" }).first {
                    connectDeviceIndex = discover.offset
                    break
                    
                }*/
                
            }
            
            
            
            
        }, stateHandler: { newState in
            guard self.appstate.rawValue > Appstate.appWillResignActive.rawValue else {
                return
            }
        
            self.doorVcontroller.ContinuousScanStateHandlerWithVC(newState)
            
        }, errorHandler: { error in
            Logger.heylog("Error from scanning: \(error)")
        })
    }
    
    func connetdevice(_ discover:BKDiscovery, _ indexPath:IndexPath? = nil, _ tableview:UITableView? = nil){
        guard !self.deviceReady else {
            if let table = tableview, let indexPath = indexPath {
                return  table.deselectRow(at: indexPath, animated: true)
            }
            return
        }
        self.deviceReady = true
        if let table = tableview{
            table.isUserInteractionEnabled = false
        }
        
        central.connect(remotePeripheral: discover.remotePeripheral){
            remotePeripheral, error in
            if let table = tableview{
                table.isUserInteractionEnabled = false
            }
            guard error == nil else {
                self.deviceReady = false
                print("Error connecting peripheral: \(String(describing: error))")
                if let table = tableview, let indexPath = indexPath {
                    return  table.deselectRow(at: indexPath, animated: true)
                }
                return
            }
            
            remotePeripheral.delegate = self
            remotePeripheral.peripheralDelegate  = self
            self.remotePeripheral = remotePeripheral
            
            guard self.appstate.rawValue > Appstate.appWillResignActive.rawValue else {
                return  self.central.interruptScan()
            }
            self.remotePeripheral = nil
            let remotePeripheralViewController = RemotePeripheralViewController(central: self.central, remotePeripheral: remotePeripheral)
            remotePeripheralViewController.delegate = self
            self.central.interruptScan()
            
            self.doorVcontroller.navigationController?.pushViewController(remotePeripheralViewController, animated: true)
            
            
        }
        
    }
}
extension Singleton : BKAvailabilityObserver {
    
    // MARK: BKAvailabilityObserver

    internal func availabilityObserver(_ availabilityObservable: BKAvailabilityObservable, availabilityDidChange availability: BKAvailability) {
        if self.appstate.rawValue  > Appstate.appWillResignActive.rawValue {
            self.doorVcontroller.availabilityObserver(availabilityObservable, availabilityDidChange: availability)
        }
        
        if availability == .available {
            scan()
            
        } else {
            central.interruptScan()
        }
        
    }

    internal func availabilityObserver(_ availabilityObservable: BKAvailabilityObservable, unavailabilityCauseDidChange unavailabilityCause: BKUnavailabilityCause) {
       
        
    }
 
}
extension Singleton : RemotePeripheralViewControllerDelegate {
    // MARK: RemotePeripheralViewControllerDelegate

    internal func remotePeripheralViewControllerWillDismiss(_ remotePeripheralViewController: RemotePeripheralViewController) {
        do {
            try self.central.disconnectRemotePeripheral(remotePeripheralViewController.remotePeripheral)
        } catch let error {
            Logger.heylog("Error disconnecting remote peripheral: \(error)")
        }
    }
}

extension Singleton : BKRemotePeripheralDelegate, BKRemotePeerDelegate {
    // MARK: BKRemotePeripheralDelegate
    internal func remotePeripheral(_ remotePeripheral: BKRemotePeripheral, didUpdateName name: String) {
      
        Logger.heylog("Name change: \(name)")
    }
    internal func remotePeer(_ remotePeer: BKRemotePeer, didSendArbitraryData data: Data) {
        Logger.heylog("Received data of length: \(data.count) with hash: \(data.md5().toHexString())")
        
    }
    internal func remotePeripheralIsReady(_ remotePeripheral: BKRemotePeripheral) {
        Logger.heylog("Peripheral ready: \(remotePeripheral)")
        self.sendData(self.remotePeripheral)
    }
}
