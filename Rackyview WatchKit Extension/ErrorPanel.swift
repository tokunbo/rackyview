import Foundation
import WatchKit

class ErrorPanelInterfaceController:WKInterfaceController {
    
    @IBOutlet var errText:WKInterfaceLabel!
    
    @IBAction func retry() {
        self.dismiss()
    }
    
     override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        var err_msg = "You must start & login to the iOS main app first.\n --ErrorDetailsBelow--\n"
        err_msg += String(describing:(context as! NSDictionary)["error"])
        errText!.setText(err_msg)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
}
