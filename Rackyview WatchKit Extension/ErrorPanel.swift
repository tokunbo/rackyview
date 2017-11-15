import Foundation
import WatchKit

class ErrorPanelInterfaceController:WKInterfaceController {
    
    @IBAction func retry() {
        self.dismiss()
    }
    
     override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
}
