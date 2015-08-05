import Foundation
import WatchKit

class ErrorPanelInterfaceController:WKInterfaceController {
    
    @IBOutlet var errorlabel:WKInterfaceLabel!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        println(context)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
}