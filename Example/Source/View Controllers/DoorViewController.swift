//
//  DoorViewController.swift
//  BKExample (iOS)
//
//  Created by eunyoung hwang on 2021/03/15.
//  Copyright © 2021 Rasmus Taulborg Hummelmose. All rights reserved.
//

import UIKit
import BluetoothKit
import CoreBluetooth
import CryptoSwift

class DoorViewController: UIViewController, AvailabilityViewController{

    
    internal var availabilityView = AvailabilityView()
    
    var activityIndicator : UIActivityIndicatorView? {
        guard let activityIndicator = activityIndicatorBarButtonItem.customView as? UIActivityIndicatorView else {
            return nil
        }
        return activityIndicator
    }
    private let activityIndicatorBarButtonItem = UIBarButtonItem(customView: UIActivityIndicatorView(style: UIActivityIndicatorView.Style.white))
    
    private let discoveriesTableView = UITableView()
    private var discoveries = [BKDiscovery]()
    private let discoveriesTableViewCellIdentifier = "Discoveries Table View Cell Identifier"
    private let central = BKCentral()
    let peripheral = BKPeripheral()
    
    
    lazy var _connectedDevice :  BKRemotePeripheral? = nil
    var deviceReady : Bool = false
    
    var connectedDevice: BKRemotePeripheral?{
        set{
   
            guard  let tremotePeripheral = _connectedDevice else {
               return _connectedDevice = newValue
            }
            
            do {
                try central.disconnectRemotePeripheral(tremotePeripheral)
            } catch let error {
                Logger.log("Error disconnecting remote peripheral: \(error)")
            }
            
            _connectedDevice = newValue
            
        }
        
        get{
           return _connectedDevice
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        activityIndicator?.color = UIColor.black
        navigationItem.title = "Central"
        navigationItem.rightBarButtonItem = activityIndicatorBarButtonItem
        applyAvailabilityView()
        discoveriesTableView.register(UITableViewCell.self, forCellReuseIdentifier: discoveriesTableViewCellIdentifier)
        discoveriesTableView.dataSource = self
        discoveriesTableView.delegate = self
        view.addSubview(discoveriesTableView)
        applyConstraints()
        startCentral()

        // Do any additional setup after loading the view.
    }
    
    internal override func viewDidAppear(_ animated: Bool) {
        scan()
    }

    internal override func viewWillDisappear(_ animated: Bool) {
        central.interruptScan()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    
    // MARK: Functions

    private func applyConstraints() {
        discoveriesTableView.snp.makeConstraints { make in
            make.top.equalTo(topLayoutGuide.snp.bottom)
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(availabilityView.snp.top)
        }
    }

    private func startCentral() {
        do {
            central.delegate = self
            central.addAvailabilityObserver(self)
            
            let dataServiceUUID = UUID(uuidString: "0000F1AB-0000-1000-8000-00805F9B34FB")!
            let dataServiceCharacteristicUUID = UUID(uuidString: "ED2B4E3B-2820-492F-9507-DF165285E831")!
            let configuration = BKConfiguration(dataServiceUUID: dataServiceUUID, dataServiceCharacteristicUUID: dataServiceCharacteristicUUID, UUID(uuidString: "ED2B4E3A-2820-492F-9507-DF165285E831")!)
            
            
            try central.startWithConfiguration(configuration)
        } catch let error {
            print("Error while starting: \(error)")
        }
    }
    
    private func scan() {
        central.scanContinuouslyWithChangeHandler({ changes, discoveries in
            var oldcoves =  self.discoveries
            let checkdisco : [BKDiscovery] = changes
                .filter({ $0 == .remove(discovery: nil) })
                .compactMap({ guard  oldcoves.contains($0.discovery) else { return nil}
                                return $0.discovery })
            let indexPathsToRemove : [IndexPath] = checkdisco.compactMap({ guard let _row = oldcoves.firstIndex(of: $0) else { return nil}
                                return IndexPath(row:_row, section: 0) })
                                                    
            oldcoves.removeAll(where: {checkdisco.contains($0)})
            self.discoveries = oldcoves
            // 다시입히고. 지우고 다시넣기
            if !indexPathsToRemove.isEmpty {
                self.discoveriesTableView.deleteRows(at: indexPathsToRemove, with: UITableView.RowAnimation.automatic)
            }
            
            oldcoves = discoveries
            let indexPathsToInsert : [IndexPath] = changes
                .filter({ $0 == .insert(discovery: nil) })
                .compactMap({ guard let _row = oldcoves.firstIndex(of: $0.discovery)
                            else { return nil}
                                return IndexPath(row:_row, section: 0) })
            // 순서 주의
            self.discoveries = oldcoves
            if !indexPathsToInsert.isEmpty {
                self.discoveriesTableView.insertRows(at: indexPathsToInsert, with: UITableView.RowAnimation.automatic)
            }
            for insertedDiscovery in changes.filter({ $0 == .insert(discovery: nil) }) {
                Logger.log("Discovery: \(insertedDiscovery)")
            }
        }, stateHandler: { newState in
            if newState == .scanning {
                self.activityIndicator?.startAnimating()
                return
            } else if newState == .stopped {
                self.discoveries.removeAll()
                self.discoveriesTableView.reloadData()
            }
            self.activityIndicator?.stopAnimating()
        }, errorHandler: { error in
            Logger.log("Error from scanning: \(error)")
        })
    }
    
    
    
    // MARK: BKAvailabilityObserver

    internal func availabilityObserver(_ availabilityObservable: BKAvailabilityObservable, availabilityDidChange availability: BKAvailability) {
        availabilityView.availabilityObserver(availabilityObservable, availabilityDidChange: availability)
        if availability == .available {
            scan()
        } else {
            central.interruptScan()
        }
    }
    

}

extension DoorViewController : UITableViewDataSource, UITableViewDelegate{
    internal  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveries.count
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: discoveriesTableViewCellIdentifier, for: indexPath)
        let discovery = discoveries[indexPath.row]
        cell.textLabel?.text = discovery.localName != nil ? discovery.localName : discovery.remotePeripheral.name
        return cell
    }
    
    
    // MARK: UITableViewDelegate

    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard !self.deviceReady else {
            return reloadtable(indexPath)
        }
        
        self.deviceReady = true
        central.connect(remotePeripheral: discoveries[indexPath.row].remotePeripheral) {
         [weak self] remotePeripheral, error in
            
            
            guard let self = self  else {
                print("Error  self :!!")
                
                return
            }
            
            guard error == nil else {
                print("Error connecting peripheral: \(String(describing: error))")
              
                return self.reloadtable(indexPath)
            }
            
            
            
            print("connect Peripheral ready")
            print(remotePeripheral.identifier)
            
            remotePeripheral.delegate = self
            remotePeripheral.peripheralDelegate = self
            
            if remotePeripheral.state == BKRemotePeripheral.State.connected {
                self.deviceReady = true
                self.connectedDevice = remotePeripheral
                self.sendData()
                return
            }
            print("Peripheral not ready: \(remotePeripheral.state)")
            
            
           /* if remotePeripheral.state == BKRemotePeripheral.State.connected {
                print("REMOTE connected")
                print(remotePeripheral.identifier)
                // once connected, set appropriate flags
                self.deviceReady = true
                self.connectedDevice = remotePeripheral
                self.sendData()
                return self.reloadtable(indexPath, true)
            }else if remotePeripheral.state != BKRemotePeripheral.State.connecting {
                
                print("REMOTE not connect")
                print(remotePeripheral.identifier)
                remotePeripheral.delegate = nil
                return self.reloadtable(indexPath)
            }
 */
            
          
            
            
        }

    }
    
    func reloadtable(_ indexPath: IndexPath, _ isReady:Bool = false) {
        
        // 메인 스레드 확인.
        guard  Thread.isMainThread else {
            DispatchQueue.main.async {
                self.reloadtable(indexPath)
            }
            return
        }
        self.deviceReady = isReady
        self.discoveriesTableView.deselectRow(at: indexPath, animated: true)
    }
    
    @objc private func sendData() {
        
        guard let remotePeripheral = self.connectedDevice else {
            return
        }
        // 여기서 문열기 시도
        let numberOfBytesToSend : [UInt8] = [0x02, 0x30, 0x31, 0x43, 0x0D]
        let data = Data(bytes: numberOfBytesToSend, count: numberOfBytesToSend.count)
        Logger.log("Prepared \(numberOfBytesToSend) bytes with MD5 hash: \(data.md5().toHexString())")
        Logger.log("Sending to \(remotePeripheral)")
        print("sendData")
        central.interruptScan()
        
        central.sendData(data, toRemotePeer: remotePeripheral) { data, remotePeripheral, error in
            guard error == nil else {
                
                print("error sendData")
                self.deviceReady = false
                Logger.log("Failed sending to \(remotePeripheral)")
                return
            }
            self.deviceReady = false
            print("Sent to \(remotePeripheral)")
            
            Logger.log("Sent to \(remotePeripheral)")
        }
     
        
    }
    
}

extension DoorViewController : BKCentralDelegate{
    internal func central(_ central: BKCentral, remotePeripheralDidDisconnect remotePeripheral: BKRemotePeripheral) {
        Logger.log("Remote peripheral did disconnect: \(remotePeripheral)")
        self.deviceReady  = false
        self.connectedDevice = nil
        self.scan()
    }
}


extension DoorViewController : BKRemotePeripheralDelegate, BKRemotePeerDelegate {
    
    internal func remotePeripheral(_ remotePeripheral: BKRemotePeripheral, didUpdateName name: String) {
        navigationItem.title = name
        Logger.log("Name change: \(name)")
    }

    internal func remotePeer(_ remotePeer: BKRemotePeer, didSendArbitraryData data: Data) {
        Logger.log("Received data of length: \(data.count) with hash: \(data.md5().toHexString())")
    }

    internal func remotePeripheralIsReady(_ remotePeripheral: BKRemotePeripheral) {
        Logger.log("Peripheral ready: \(remotePeripheral)")
        
        print("Peripheral ready")
        print(remotePeripheral.identifier)
        // once connected, set appropriate flags
        self.deviceReady = false
        self.connectedDevice = nil
      //  self.sendData()
        
    }
    
}
