

import UIKit
import Foundation


class TicketsSummaryViewController: UIViewController {
    @IBOutlet var OpenTicketsLabel:UILabel!
    @IBOutlet var ClosedTicketsLabel:UILabel!
    
    func dismiss() {
        (self.parent as! TicketsTabBarController).dismiss(animated: true)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.parent?.title = "Racky Tickets"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.OpenTicketsLabel.text = "Open Tickets: ..."
        self.ClosedTicketsLabel.text = "Closed Tickets: ..."
        self.refresh()
    }
    
    @IBAction func newTicket() {
        self.navigationController?.pushViewController(UIStoryboard(name:"Main",bundle:nil)
            .instantiateViewController(withIdentifier: "CreateTicketViewController") as!
        CreateTicketViewController, animated: true)
    }
    
   @IBAction func refresh() {
    raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
        OperationQueue().addOperation {
            let nsdata:NSData! = raxAPI.get_tickets_summary()
            if(nsdata == nil) {
                raxutils.alert(title: "Login Error", message: "sessionid has apparently expired", vc: self, onDismiss: { (action:UIAlertAction!) -> Void in
                    self.dismiss()
                })
                return
            }
            
            let ticketSummary:NSDictionary! = (try! JSONSerialization.jsonObject(with: nsdata as Data, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary)
            let stats:NSArray = (ticketSummary["summaryOfTickets"] as AnyObject).object(forKey: "statistic") as! NSArray
            raxutils.setUIBusy(v: nil, isBusy: false)
            OperationQueue.main.addOperation {
                self.OpenTicketsLabel.text = "Open Tickets: 0"
                self.ClosedTicketsLabel.text = "Closed Tickets: 0"
                var NotClosedTicketCount:Int = 0
                for case let stat as NSDictionary in stats {
                    if((stat["status"] as! String) == "CLOSED") {
                        self.ClosedTicketsLabel.text = "Closed Tickets: "
                        self.ClosedTicketsLabel.text?.append((stat["number-of-tickets"] as! NSNumber).stringValue)
                    } else {
                       NotClosedTicketCount += (stat["number-of-tickets"] as! NSNumber).intValue
                    }
                }
                self.OpenTicketsLabel.text = "Open Tickets: "
                self.OpenTicketsLabel.text?.append(String(NotClosedTicketCount))
            }
        }
    }
}
