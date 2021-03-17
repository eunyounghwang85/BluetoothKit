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

/**
    Class that represents a configuration used when starting a BKCentral object.
*/
public class BKConfiguration {

    // MARK: Properties

    /// The UUID for the service used to send data. This should be unique to your applications.
    public let dataServiceUUID: CBUUID

    /// The UUID for the characteristic used to send data. This should be unique to your application.
    public var dataServiceCharacteristicUUID: CBUUID
    
    /// The UUID for the characteristic used to read data. This should be unique to your application.
    public var dataServiceReadCharacteristicUUID: CBUUID
    
    public var advertisementNAMES: [String]
    

    /// Data used to indicate that no more data is coming when communicating.
    public var endOfDataMark: Data

    /// Data used to indicate that a transfer was cancellen when communicating.
    public var dataCancelledMark: Data

    internal var serviceUUIDs: [CBUUID] {
        let serviceUUIDs = [ dataServiceUUID ]
        return serviceUUIDs
    }

    // MARK: Initialization

    
    public init(dataServiceUUID: UUID, dataServiceCharacteristicUUID: UUID, _ readID: UUID? = nil, _ localnames: [String]? = nil) {
        // 해당 uuid를 블루투스 기계를 찾아준다
        self.dataServiceUUID = CBUUID(nsuuid: dataServiceUUID)
        //  문열기 요청시 필요하다
        self.dataServiceCharacteristicUUID = CBUUID(nsuuid: dataServiceCharacteristicUUID)

        endOfDataMark = "EOD".data(using: String.Encoding.utf8)!
        dataCancelledMark = "COD".data(using: String.Encoding.utf8)!
        
        // serviceuuid 와 readid가 다른이유 ? 아직도 모르겠다.
        // discover add 에서 readid로 넣지 않으면 진행이 안된다.
        // 서비스 아이디로넣어봤는데 계속안됌.
        
        let read = readID ?? dataServiceUUID
        self.dataServiceReadCharacteristicUUID  = CBUUID(nsuuid: read)
        
        // 출입가능한 공동현관 키를 받을것이므로 array 형태로 관리하며, namecontain 유무 체크를 진행한다.
        self.advertisementNAMES = localnames ?? [String]()
        
    }

    // MARK: Functions

    internal func characteristicUUIDsForServiceUUID(_ serviceUUID: CBUUID) -> [CBUUID] {
        if serviceUUID == dataServiceUUID {
            return [ dataServiceCharacteristicUUID ]
        }else if serviceUUID == dataServiceCharacteristicUUID {
            return [ dataServiceCharacteristicUUID ]
            
        }else if serviceUUID ==  dataServiceReadCharacteristicUUID {
            return [ dataServiceCharacteristicUUID ]
        }
        
        //    ED2B4E3C-2820-492F-9507-DF165285E831
        return []
    }

}
