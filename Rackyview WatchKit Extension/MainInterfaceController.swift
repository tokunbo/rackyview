
import Foundation
import WatchKit
import WatchConnectivity

class MainInterfaceController:WKInterfaceController, WCSessionDelegate {
    @available(watchOSApplicationExtension 2.2, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        //TODO... something I guess....
    }
    
    
    @IBOutlet var critbell:WKInterfaceButton!
    @IBOutlet var warnbell:WKInterfaceButton!
    @IBOutlet var okbell:WKInterfaceButton!
    @IBOutlet var critlabel:WKInterfaceLabel!
    @IBOutlet var warnlabel:WKInterfaceLabel!
    @IBOutlet var oklabel:WKInterfaceLabel!
    
    @IBAction func refresh() {
        let myUserInfo = ["action":"latestAlarmStates"]
        self.critlabel.setText("loading...")
        self.warnlabel.setText("loading...")
        self.oklabel.setText("loading...")
        WCSession.default.sendMessage(myUserInfo,
            replyHandler: {(response:[String:Any]) -> Void in
                DispatchQueue.sync(dispatch_get_main_queue(), {
                    if response.indexForKey("error") != nil {
                        self.presentControllerWithName("ErrorPanel", context: response)
                    } else {
                        self.critlabel.setText(String(stringInterpolationSegment: response["critCount"] as! NSNumber)+" CRIT")
                        self.warnlabel.setText(String(stringInterpolationSegment: response["warnCount"] as! NSNumber)+" WARN")
                        self.oklabel.setText(String(stringInterpolationSegment: response["okCount"] as! NSNumber)+" OKAY")
                    }
                })
            },
            errorHandler: {(error:Error) -> Void in
                dispatch_sync(dispatch_get_main_queue(), {
                    self.presentControllerWithName("ErrorPanel", context: ["error": error])
                })
            }
        );
    }

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        critbell.setBackgroundImage(createColoredImageFromUIImage(UIImage(named: "bellicon.png")!, myColor: getColorForState("crit")))
        warnbell.setBackgroundImage(createColoredImageFromUIImage(UIImage(named: "bellicon.png")!, myColor: getColorForState("warn")))
        okbell.setBackgroundImage(createColoredImageFromUIImage(UIImage(named: "bellicon.png")!, myColor: getColorForState("ok")))
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        if WCSession.isSupported() {
            let wcSession = WCSession.defaultSession()
            wcSession.delegate = self
            wcSession.activateSession()
        }
        refresh()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func getColorForState(state:String) -> UIColor {
        var stateColor:UIColor
        if state.lowercaseString == "ok" {
            stateColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        } else if state.lowercaseString == "warn" || state.lowercaseString == "warning" {
            stateColor = UIColor.orangeColor()
        } else if state.lowercaseString == "crit" || state.lowercaseString == "critical" {
            stateColor = UIColor.redColor()
        } else {
            stateColor = UIColor.blueColor()
        }
        return stateColor
    }
    
    func createColoredImageFromUIImage(myImage:UIImage,myColor:UIColor) -> UIImage {
        var coloredImage:UIImage = myImage.copy() as! UIImage
        var context:CGContextRef
        let rect:CGRect = CGRectMake(0, 0, myImage.size.width, myImage.size.height)
        UIGraphicsBeginImageContextWithOptions(myImage.size, false, myImage.scale)
        coloredImage.drawInRect(rect)
        context = UIGraphicsGetCurrentContext()!
        CGContextSetBlendMode(context, CGBlendMode.SourceIn)
        CGContextSetFillColorWithColor(context, myColor.CGColor)
        CGContextFillRect(context, rect)
        coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return coloredImage
    }
    
    func sessionWatchStateDidChange(session: WCSession) {
        //Nothing
    }
}
