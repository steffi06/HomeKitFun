import UIKit
import HomeKit

class ViewController: UITableViewController, HMHomeManagerDelegate, HMAccessoryDelegate {

    var manager: HMHomeManager
    var lights: [HMService]?

    required convenience init?(coder aDecoder: NSCoder) {
        self.init(aDecoder)
    }

    init?(_ coder: NSCoder? = nil) {
        self.manager = HMHomeManager.init()

        if let coder = coder {
            super.init(coder: coder)
        } else {
            super.init(nibName: nil, bundle:nil)
        }

        self.manager.delegate = self
    }

    override func prefersStatusBarHidden() -> Bool {
        return false
    }

    override func tableView(tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int {
            return self.lights?.count ?? 0
    }

    override func tableView(tableView: UITableView,
        heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
            let minHeight = 44.0
            var height = minHeight

            if self.lights?.count > 0 {
                let numLights = self.lights?.count
                let screenHeight = UIScreen.mainScreen().bounds.height
                let navBarHeight = self.navigationController?.navigationBar.frame.size.height
                let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.size.height
                height = Double(screenHeight - navBarHeight! - statusBarHeight) / Double(numLights!)
            }

            return CGFloat(height < minHeight ? minHeight : height)
    }

    override func tableView(tableView: UITableView,
        cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCellWithIdentifier("lightBulbCell")

            if (self.lights != nil) {
                let light = self.lights![indexPath.row]

                // Set the light label
                let lightLabel = cell!.contentView.viewWithTag(1) as! UILabel
                lightLabel.text = "\(light.name)"

                // Set the light status (On/Off Switch)
                let lightSwitch = cell!.contentView.viewWithTag(2) as! UISwitch

                lightSwitch.enabled = light.accessory!.reachable

                // Get the brightness slider (0-100%)
                let brightnessSlider = cell!.contentView.viewWithTag(3) as! UISlider

                for characteristic: HMCharacteristic in light.characteristics {
                    switch characteristic.characteristicType {

                    case HMCharacteristicTypePowerState:
                        characteristic.readValueWithCompletionHandler(){
                            (error: NSError?) -> Void in
                            if (error != nil) {
                                print(error?.localizedDescription)
                                if error!.code == HMErrorCode.CommunicationFailure.rawValue {
                                    lightSwitch.enabled = false
                                }
                            }

                            lightSwitch.setOn(characteristic.value as! Bool, animated: true)
                        }

                    case HMCharacteristicTypeHue:
                        characteristic.readValueWithCompletionHandler(){
                            (error: NSError?) -> Void in
                            if (error != nil) {
                                print(error?.localizedDescription)
                            }

                            cell?.changeBackgroundColorByValue(
                                .ColorValueHue,
                                value: CGFloat(characteristic.value as! Float)/360.0)
                        }

                    case HMCharacteristicTypeSaturation:
                        characteristic.readValueWithCompletionHandler(){
                            (error: NSError?) -> Void in
                            if (error != nil) {
                                print(error?.localizedDescription)
                            }

                            cell?.changeBackgroundColorByValue(
                                .ColorValueSaturation,
                                value: CGFloat(characteristic.value as! Float)/100.0)
                        }

                    case HMCharacteristicTypeBrightness:
                        characteristic.readValueWithCompletionHandler(){
                            (error: NSError?) -> Void in
                            if (error != nil) {
                                print(error?.localizedDescription)
                            }

                            brightnessSlider.value = (characteristic.value as! Float)/100.0
                        }

                    default: break
                    }
                }
            }

            return cell!
    }

    @IBAction func brightnessChanged(sender: UISlider) {
        let containingView = sender.superview!
        let containingCell = containingView.superview! as! UITableViewCell
        let indexPath = self.tableView.indexPathForCell(containingCell)
        let light = self.lights?[indexPath!.row]
        for characteristic: HMCharacteristic in light!.characteristics {
            if characteristic.characteristicType == HMCharacteristicTypeBrightness {
                characteristic.writeValue(Int(sender.value * 100), completionHandler: {
                    (error: NSError?) -> Void in

                    if error != nil {
                        print(error?.localizedDescription)
                    }
                })
            }
        }
    }

    @IBAction func switchToggled(sender: UISwitch, forEvent event: UIEvent) {
        let containingView = sender.superview!
        let containingCell = containingView.superview! as! UITableViewCell
        let indexPath = self.tableView.indexPathForCell(containingCell)
        let light = self.lights?[indexPath!.row]
        for characteristic: HMCharacteristic in light!.characteristics {
            if characteristic.characteristicType == HMCharacteristicTypePowerState {

                characteristic.writeValue(sender.on, completionHandler: {
                    (error: NSError?) -> Void in

                    if error != nil {
                        print(error?.localizedDescription)
                        if error!.code == HMErrorCode.CommunicationFailure.rawValue {
                            // Disable On/Off Switch since this indicates we cannot connect to the light
                            sender.enabled = false
                        }
                    }
                    sender.setOn(characteristic.value as! Bool, animated: true)
                })
            }
        }
    }

    func homeManagerDidUpdateHomes(manager: HMHomeManager) {
        // Get Primary Home
        let primaryHome = manager.primaryHome

        if primaryHome == nil {
            return
        }

        // Get Services with type light bulb
        self.lights = primaryHome?.servicesWithTypes([HMServiceTypeLightbulb])

        // Load tableView to show latest data
        self.tableView.reloadData()

        let characteristicTypesOfInterest = Set(arrayLiteral:
            HMCharacteristicTypePowerState,
            HMCharacteristicTypeBrightness,
            HMCharacteristicTypeHue,
            HMCharacteristicTypeSaturation)

        for light: HMService in self.lights! {
            light.accessory?.delegate = self

            for characteristic: HMCharacteristic in light.characteristics {
                if characteristicTypesOfInterest.contains(characteristic.characteristicType) {

                    // Subscribe for notifications when these characteristic types change
                    if characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                        characteristic.enableNotification(true, completionHandler: {
                            (error: NSError?) -> Void in
                            if (error != nil) {
                                print(error?.localizedDescription)
                            }
                        })
                    }
                }
            }
        }
    }

    func accessory(accessory: HMAccessory,
        service: HMService,
        didUpdateValueForCharacteristic characteristic: HMCharacteristic) {
            let row = self.lights?.indexOf(service)
            let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row!, inSection: 0))

            switch characteristic.characteristicType {
                
            case HMCharacteristicTypePowerState:
                let lightSwitch = cell!.contentView.viewWithTag(2) as! UISwitch
                lightSwitch.enabled = accessory.reachable
                lightSwitch.setOn(characteristic.value as! Bool, animated: true)

            case HMCharacteristicTypeHue:
                cell?.changeBackgroundColorByValue(
                    .ColorValueHue,
                    value: CGFloat(characteristic.value as! Float)/360.0)

            case HMCharacteristicTypeSaturation:
                cell?.changeBackgroundColorByValue(
                    .ColorValueSaturation,
                    value: CGFloat(characteristic.value as! Float)/100.0)

            case HMCharacteristicTypeBrightness:
                let brightnessSlider = cell!.contentView.viewWithTag(3) as! UISlider
                brightnessSlider.value = (characteristic.value as! Float)/100.0

            default: break
            }
    }

    func accessoryDidUpdateReachability(accessory: HMAccessory) {
        for service: HMService in accessory.services {
            if (service.serviceType == HMServiceTypeLightbulb) {
                let row = self.lights?.indexOf(service)
                let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row!, inSection: 0))
                let lightSwitch = cell!.contentView.viewWithTag(2) as! UISwitch
                lightSwitch.enabled = accessory.reachable
            }
        }
    }
}

