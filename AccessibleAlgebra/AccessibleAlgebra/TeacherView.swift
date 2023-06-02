//
//  TeacherView.swift
//  HelloTest
//
//  Created by Loaner on 5/31/23.
//

import UIKit
import CoreBluetooth

class TeacherView: UIViewController, CBPeripheralManagerDelegate {

    @IBOutlet weak var eqField: UITextField!
    @IBOutlet weak var toStudent: UIButton!
    @IBOutlet weak var ConnectionState: UILabel!
    
    var peripheralManager: CBPeripheralManager!
    var centralCharacteristic: CBMutableCharacteristic!
    var isConnected: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        let characteristicUUID = CBUUID(string: "9dcb19b7-bcfd-492a-9128-9b25b4293c97") //characteristic uuid
        centralCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: .notify, value: nil, permissions: [.readable, .writeable])
    }
    
    @IBAction func toStudentPressed(_ sender: Any) {
        guard let message = eqField.text?.data(using: .utf8) else {
            return
        }
        print("Attempting to Send: \(message)")
        if isConnected {
            peripheralManager.updateValue(message, for: centralCharacteristic, onSubscribedCentrals: nil)
            print("Sent")
        } else {
            print("Central device not connected")
            alertWhenInvalid()
        }
        eqField.resignFirstResponder()
        
    }
    
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let serviceUUID = CBUUID(string: "03f528d0-c011-432d-8bd0-45347e3ef095") // Service UUID
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [centralCharacteristic]
            peripheralManager.add(service)
            
            let advertisementData: [String: Any] = [
                CBAdvertisementDataLocalNameKey: "Teacher", // Peripheral name
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID] // Service UUIDs
            ]
            peripheralManager.startAdvertising(advertisementData)
            
            print("Started Advertising")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        isConnected = true
        print("Central subscribed to characteristic")
        DispatchQueue.main.async { [weak self] in
            self?.ConnectionState!.text = "Connected"
            self?.ConnectionState.textColor = UIColor.systemGreen
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        isConnected = false
        print("Central unsubscribed from characteristic")
        DispatchQueue.main.async { [weak self] in
            self?.ConnectionState!.text = "Disconnected"
            self?.ConnectionState.textColor = UIColor.systemRed
        }
    }
    /*func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to update characteristic value: \(error.localizedDescription)")
            return
        }
            
        guard let value = characteristic.value,
                let receivedMessage = String(data: value, encoding: .utf8)
        else {
            print("Invalid characteristic value")
            return
        }
        print("Received message from central: \(receivedMessage)")
    }*/
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to update characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let value = characteristic.value,
            let receivedMessage = String(data: value, encoding: .utf8) else {
                print("Invalid characteristic value")
                return
        }
        
        print("Received message from central: \(receivedMessage)")
        // Process the received message as needed
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("Ready to update subscribers")
    }
    
    func alertWhenInvalid(){
        let alertController = UIAlertController(title: "No Device Found", message: "Connect Student Phone", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
