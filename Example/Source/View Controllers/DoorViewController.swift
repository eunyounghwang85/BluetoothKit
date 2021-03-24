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

internal class DoorViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AvailabilityViewController {

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
    }

    internal override func viewDidAppear(_ animated: Bool) {
        
    }

    internal override func viewWillDisappear(_ animated: Bool) {
       
    }

    deinit {
      
    }

    // MARK: Functions

    private func applyConstraints() {
        discoveriesTableView.snp.makeConstraints { make in
            make.top.equalTo(topLayoutGuide.snp.bottom)
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(availabilityView.snp.top)
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
        
        let discovery = discoveries[indexPath.row]
        Singleton.sharedInstance.connetdevice(discovery, indexPath, tableView)
    }

    // MARK: BKAvailabilityObserver

    internal func availabilityObserver(_ availabilityObservable: BKAvailabilityObservable, availabilityDidChange availability: BKAvailability) {
        
        availabilityView.availabilityObserver(availabilityObservable, availabilityDidChange: availability)
      
    }
    
    // MARK: ContinuousScanChangeHandlerWithVC
    func ContinuousScanChangeHandlerWithVC(_ changes: [BKDiscoveriesChange], _ discoveries: [BKDiscovery]){
        
        self.discoveries = discoveries
        self.discoveriesTableView.reloadData()
        /*
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
        */
    }
    
    // MARK: ContinuousScanStateHandlerWithVC
    func ContinuousScanStateHandlerWithVC(_ newState: BKCentral.ContinuousScanState){
        
        if newState == .scanning {
            self.activityIndicator?.startAnimating()
            return
            
        } else if newState == .stopped {
            self.discoveries.removeAll()
            self.discoveriesTableView.reloadData()
            
        }
        self.activityIndicator?.stopAnimating()
        
    }
    
    // MARK: ContinuousScanErrorHandlerWithVC
    func ContinuousScanErrorHandlerWithVC(_ error: BKError){
        Logger.heylog("Error from scanning: \(error)")
    }

}
