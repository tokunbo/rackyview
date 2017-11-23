
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
        let myUserInfo:[String:Any] = ["action":"latestAlarmStates"]
        self.critlabel.setText("Waiting for iOS login...")
        self.warnlabel.setText("Waiting for iOS login...")
        self.oklabel.setText("Waiting for iOS login...")
        self.critlabel.setText("loading...")
        self.warnlabel.setText("loading...")
        self.oklabel.setText("loading...")
        print("watch sending request for data...")
        WCSession.default.sendMessage(myUserInfo,
            replyHandler: {(response:[String:Any]) -> Void in
                print("iOS replied the watch with: \(response)")
                DispatchQueue.main.sync {
                    if response.index(forKey: "error") != nil {
                        self.presentController(withName: "ErrorPanel", context: response)
                    } else {
                        self.critlabel.setText(String(stringInterpolationSegment: response["critCount"] as! NSNumber)+" CRIT")
                        self.warnlabel.setText(String(stringInterpolationSegment: response["warnCount"] as! NSNumber)+" WARN")
                        self.oklabel.setText(String(stringInterpolationSegment: response["okCount"] as! NSNumber)+" OKAY")
                    }
                }
            },
            errorHandler: {(error:Error) -> Void in
                DispatchQueue.main.sync {
                    self.presentController(withName: "ErrorPanel", context: ["error": error])
                }
            }
        );
    }

    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        critbell.setBackgroundImage(createColoredImageFromUIImage(myImage: UIImage(named: "bellicon.png")!, myColor: getColorForState(state: "crit")))
        warnbell.setBackgroundImage(createColoredImageFromUIImage(myImage: UIImage(named: "bellicon.png")!, myColor: getColorForState(state: "warn")))
        okbell.setBackgroundImage(createColoredImageFromUIImage(myImage: UIImage(named: "bellicon.png")!, myColor: getColorForState(state: "ok")))
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        print("watch:willActivate")
        if WCSession.isSupported() {
            print("watch:wcsession.supported")
            let wcSession = WCSession.default
            wcSession.delegate = self
            wcSession.activate()
        }
        refresh()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func getColorForState(state:String) -> UIColor {
        var stateColor:UIColor
        if state.lowercased() == "ok" {
            stateColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        } else if state.lowercased() == "warn" || state.lowercased() == "warning" {
            stateColor = UIColor.orange
        } else if state.lowercased() == "crit" || state.lowercased() == "critical" {
            stateColor = UIColor.red
        } else {
            stateColor = UIColor.blue
        }
        return stateColor
    }
    
    func createColoredImageFromUIImage(myImage:UIImage,myColor:UIColor) -> UIImage {
        var coloredImage:UIImage = myImage.copy() as! UIImage
        var context:CGContext
        let rect:CGRect = CGRect(x: 0, y: 0, width: myImage.size.width, height: myImage.size.height)
        UIGraphicsBeginImageContextWithOptions(myImage.size, false, myImage.scale)
        coloredImage.draw(in: rect)
        context = UIGraphicsGetCurrentContext()!
        context.setBlendMode(CGBlendMode.sourceIn)
        context.setFillColor(myColor.cgColor)
        context.fill(rect)
        coloredImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return coloredImage
    }
    
    func sessionWatchStateDidChange(session: WCSession) {
        //Nothing
    }
}
