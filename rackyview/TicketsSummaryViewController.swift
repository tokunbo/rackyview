

import UIKit
import Foundation


class TicketsSummaryViewController: UIViewController {
    @IBOutlet var OpenTicketsLabel:UILabel!
    @IBOutlet var ClosedTicketsLabel:UILabel!
    
    func dismiss() {
        (self.parentViewController as! TicketsTabBarController).dismiss()
    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.parentViewController?.title = "Racky Tickets"
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.OpenTicketsLabel.text = "Open Tickets: ..."
        self.ClosedTicketsLabel.text = "Closed Tickets: ..."
        self.refresh()
    }
    
    @IBAction func newTicket() {
        self.navigationController?.pushViewController(UIStoryboard(name:"Main",bundle:nil)
        .instantiateViewControllerWithIdentifier("CreateTicketViewController") as!
        CreateTicketViewController, animated: true)
    }
    
   @IBAction func refresh() {
        raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
        NSOperationQueue().addOperationWithBlock {
            let nsdata:NSData! = raxAPI.get_tickets_summary()
            if(nsdata == nil) {
                raxutils.alert("Login Error", message: "sessionid has apparently expired", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                    self.dismiss()
                })
                return
            }
            
            let ticketSummary:NSDictionary! = (try! NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
            let stats:NSArray = ticketSummary.valueForKey("summaryOfTickets")?.valueForKey("statistic") as! NSArray
            raxutils.setUIBusy(nil, isBusy: false)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.OpenTicketsLabel.text = "Open Tickets: 0"
                self.ClosedTicketsLabel.text = "Closed Tickets: 0"
                var NotClosedTicketCount:Int = 0
                for stat in stats {
                    if((stat.valueForKey("status") as! String) == "CLOSED") {
                        self.ClosedTicketsLabel.text = "Closed Tickets: "
                        self.ClosedTicketsLabel.text?.appendContentsOf((stat.valueForKey("number-of-tickets") as! NSNumber).stringValue)
                    } else {
                       NotClosedTicketCount += (stat.valueForKey("number-of-tickets") as! NSNumber).integerValue
                    }
                }
                self.OpenTicketsLabel.text = "Open Tickets: "
                self.OpenTicketsLabel.text?.appendContentsOf(String(NotClosedTicketCount))
            }
        }
    }
}