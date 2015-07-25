
import Foundation
import WatchKit

class MainInterfaceController:WKInterfaceController {
    
    @IBOutlet var critbell:WKInterfaceButton!
    @IBOutlet var warnbell:WKInterfaceButton!
    @IBOutlet var okbell:WKInterfaceButton!
    @IBOutlet var critlabel:WKInterfaceLabel!
    @IBOutlet var warnlabel:WKInterfaceLabel!
    @IBOutlet var oklabel:WKInterfaceLabel!
    var replydata:[NSObject:AnyObject]!
    
    
    @IBAction func refresh() {
        var myUserInfo = ["action":"latestAlarmStates"]
        WKInterfaceController.openParentApplication(myUserInfo, reply: { response, error in
            self.replydata = response
            if self.replydata == nil || self.replydata.indexForKey("error") != nil || error != nil {
                self.critlabel.setText("error")
                self.warnlabel.setText("error")
                self.oklabel.setText("error")
            } else {
                self.critlabel.setText(String(stringInterpolationSegment: response["critCount"] as! NSNumber)+" CRIT")
                self.warnlabel.setText(String(stringInterpolationSegment: response["warnCount"] as! NSNumber)+" WARN")
                self.oklabel.setText(String(stringInterpolationSegment: response["okCount"] as! NSNumber)+" OKAY")
            }
        })
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
        var rect:CGRect = CGRectMake(0, 0, myImage.size.width, myImage.size.height)
        UIGraphicsBeginImageContextWithOptions(myImage.size, false, myImage.scale)
        coloredImage.drawInRect(rect)
        context = UIGraphicsGetCurrentContext()
        CGContextSetBlendMode(context, kCGBlendModeSourceIn)
        CGContextSetFillColorWithColor(context, myColor.CGColor)
        CGContextFillRect(context, rect)
        coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return coloredImage
    }
}