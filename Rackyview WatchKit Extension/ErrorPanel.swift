import Foundation
import WatchKit

class ErrorPanelInterfaceController:WKInterfaceController {
    
    @IBAction func retry() {
        self.dismissController()
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
}