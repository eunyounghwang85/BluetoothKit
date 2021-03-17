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

import UIKit
import BluetoothKit
import CoreBluetooth

internal class CentralViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, BKCentralDelegate, AvailabilityViewController, RemotePeripheralViewControllerDelegate {

    // MARK: Properties

    internal var availabilityView = AvailabilityView()

    private var activityIndicator: UIActivityIndicatorView? {
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
    var deviceReady : Bool = false

    // MARK: UIViewController Life Cycle

    internal override func viewDidLoad() {
        view.backgroundColor = UIColor.white
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
    }

    internal override func viewDidAppear(_ animated: Bool) {
        scan()
    }

    internal override func viewWillDisappear(_ animated: Bool) {
        central.interruptScan()
    }

    deinit {
        _ = try? central.stop()
    }

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
            let configuration = BKConfiguration(dataServiceUUID: dataServiceUUID, dataServiceCharacteristicUUID: dataServiceCharacteristicUUID, UUID(uuidString: "ED2B4E3A-2820-492F-9507-DF165285E831")!, ["B0001"])
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
            
            guard !self.deviceReady else {return}
            
            var Checkperipheral : [String : [String]] = [String : [String]]()
            let allcoveries = self.discoveries
            var connectDeviceIndex : Int? = nil
            
            for discovery  in allcoveries {
                var name =  discovery.localName ?? "-1"
                name = name.replacingOccurrences(of: "B0001_", with: "")
                
                // 현재 키 구분
                let tname =  name
                
                name = name.replacingOccurrences(of: "M", with: "")
                name = name.replacingOccurrences(of: "S", with: "")
                var distanceArray = Checkperipheral[name] ?? [String]()
                if !distanceArray.contains(tname){
                    distanceArray.append(tname)
                }
                Checkperipheral[name] = distanceArray
                if distanceArray.count > 1, let discover =  allcoveries.enumerated().filter({$0.element.localName == "B0001_" + name + "M" }).first {
                    connectDeviceIndex = discover.offset
                    break
                }
            }
            
            guard let index = connectDeviceIndex else {return}
            let path = IndexPath(row: index, section: 0)
            self.discoveriesTableView.selectRow(at:path, animated: true, scrollPosition: .none)
            self.gotoConnet(path)
         /*   for insertedDiscovery in changes.filter({ $0 == .insert(discovery: nil) }) {
                Logger.log("Discovery: \(insertedDiscovery)")
            }*/
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

    func  gotoConnet(_ indexPath:IndexPath){
        guard !self.deviceReady else {
            return  self.discoveriesTableView.deselectRow(at: indexPath, animated: true)
        }
        self.deviceReady = true
        self.discoveriesTableView.isUserInteractionEnabled = false
        central.connect(remotePeripheral: discoveries[indexPath.row].remotePeripheral) { remotePeripheral, error in
            self.discoveriesTableView.isUserInteractionEnabled = true
            guard error == nil else {
                self.deviceReady = false
                print("Error connecting peripheral: \(String(describing: error))")
                self.discoveriesTableView.deselectRow(at: indexPath, animated: true)
                return
            }
            
            let remotePeripheralViewController = RemotePeripheralViewController(central: self.central, remotePeripheral: remotePeripheral)
            remotePeripheralViewController.delegate = self
            self.central.interruptScan()
           
            self.navigationController?.pushViewController(remotePeripheralViewController, animated: true)
        }
        
    }
    // MARK: UITableViewDataSource

    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
        
        self.gotoConnet(indexPath)
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

    // MARK: BKCentralDelegate

    internal func central(_ central: BKCentral, remotePeripheralDidDisconnect remotePeripheral: BKRemotePeripheral) {
        
        self.deviceReady = false
        Logger.log("Remote peripheral did disconnect: \(remotePeripheral)")
        _ = self.navigationController?.popToViewController(self, animated: true)
    }

    // MARK: RemotePeripheralViewControllerDelegate

    internal func remotePeripheralViewControllerWillDismiss(_ remotePeripheralViewController: RemotePeripheralViewController) {
        do {
            try central.disconnectRemotePeripheral(remotePeripheralViewController.remotePeripheral)
        } catch let error {
            Logger.log("Error disconnecting remote peripheral: \(error)")
        }
    }

}
