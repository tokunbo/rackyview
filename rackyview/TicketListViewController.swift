

import UIKit
import Foundation

class TicketListViewController: UITableViewController {
    var t_status:String = ""
    var tickets:NSMutableArray = NSMutableArray()
    var previouslySelectedIndexPath:IndexPath!
    
    func dismiss() {
        (self.parent as! TicketsTabBarController).dismiss(animated: true)
    }
    
    @IBAction func refresh() {
        self.tableView.isScrollEnabled = false //Scrolling while loading causes a crash apparently
        raxutils.setUIBusy(v: self.navigationController!.view, isBusy: true)
        OperationQueue().addOperation {
            let nsdata:NSData! = raxAPI.get_tickets_by_status(t_status: self.t_status)
            if(nsdata == nil) {
                raxutils.alert(title: "Auth Error", message: "sessionid has apparently expired", vc: self,onDismiss: { action in
                    self.dismiss()
                })
                return
            }
            //let responsedata:NSDictionary! = try? JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
            let responsedata:NSDictionary! = (try? JSONSerialization.jsonObject(with: nsdata as Data, options: JSONSerialization.ReadingOptions.mutableContainers)) as! NSDictionary!

            if(responsedata == nil || responsedata["tickets"] == nil) {
                raxutils.alert(title: "Some kind of error",
                               message: "expired websessionid or unexpected data returned",
                               vc: self,onDismiss: { action in
                                 self.dismiss()
                              })
                return
            }
            self.tickets = ((responsedata["tickets"] as! NSDictionary)["ticket"] as! NSArray).mutableCopy() as! NSMutableArray
            
            if self.title! as NSString as String == "Open Tickets" {
                self.tickets = raxutils.syncTickets(tickets: self.tickets)
            }
            if(self.tickets.count == 0) {
                raxutils.alert(title: "None!",
                               message: "No "+((self.title! as NSString) as String)+" to show you",
                               vc: self, onDismiss: nil)
            }
            OperationQueue.main.addOperation {
                self.tableView.reloadData()
                raxutils.setUIBusy(v: nil, isBusy: false)
                self.tableView.isScrollEnabled = true
                self.refreshControl?.endRefreshing()
                self.view.setNeedsLayout()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.title! as NSString as String == "Open Tickets" && self.tickets.count > 0 {
            self.tickets = raxutils.syncTickets(tickets: self.tickets)
        }
        self.tableView.reloadData()//---Needed to ensure animation in cells continue.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if previouslySelectedIndexPath != nil {
            let previouslySelectedCell = tableView.cellForRow(at: previouslySelectedIndexPath)
            raxutils.flashView(v: previouslySelectedCell!.contentView)
            previouslySelectedCell?.reloadInputViews()
            previouslySelectedIndexPath = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.black
        self.refreshControl?.tintColor = UIColor.white
        self.refreshControl?.addTarget(self, action: #selector(TicketListViewController.refresh), for: UIControlEvents.valueChanged)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tickets.count == 0) {
            let emptyMessage:UILabel = UILabel(frame: CGRect(x: 0, y: 0,
                                                             width: self.view.bounds.size.width,
                                                             height: self.view.bounds.size.height))
            emptyMessage.backgroundColor = UIColor(red: 0, green: 0.1, blue: 0, alpha: 1)
            emptyMessage.textColor = UIColor.white
            emptyMessage.text = "Pull all the way down to refresh"
            emptyMessage.textAlignment = NSTextAlignment.center
            emptyMessage.font = UIFont(name: "Verdana", size: 20)
            emptyMessage.sizeToFit()
            OperationQueue.main.addOperation {
                self.tableView.backgroundView = emptyMessage
            }
        } else {
            OperationQueue.main.addOperation {
                self.tableView.backgroundView = nil
            }
        }
        return tickets.count
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if self.title! as NSString as String != "Open Tickets" {
            return
        }
        let ticket:NSMutableDictionary = tickets[indexPath.row] as! NSMutableDictionary
        if ticket["hasUnreadComments"] as! Bool {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "newmessageicon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-47,y:cell.frame.height-36,width:47,height:36)
            raxutils.fadeInAndOut(uiview: uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
     override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "TicketListTableCell")!
        let ticket:NSDictionary = tickets[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = (ticket["subject"] as! NSString) as String
        (cell.viewWithTag(2) as! UILabel).text = "Updated: "
        (cell.viewWithTag(2) as! UILabel).text?.append((ticket["updated-at"] as! NSString) as String)
        (cell.viewWithTag(3) as! UILabel).text = "Status: "
        (cell.viewWithTag(3) as! UILabel).text?.append((ticket["ticket-status"] as! NSString) as String)
        (cell.viewWithTag(4) as! UILabel).text = "ID: "
        (cell.viewWithTag(4) as! UILabel).text?.append((ticket["ticket-id"] as! NSString) as String)
        
        //TODO: The reason this view is hidden is because the API sometimes returns the wrong count and that hasn't been fixed AFAIK. I don't want to show data that's not reiable if I can help it.
        cell.viewWithTag(5)?.isHidden = true
        
        (cell.viewWithTag(5) as! UILabel).text = "Comments: "
        (cell.viewWithTag(5) as! UILabel).text?.append((ticket["public-comment-count"] as! NSNumber).stringValue)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        previouslySelectedIndexPath = indexPath
        tableView.cellForRow(at: indexPath)?.isSelected = false
        let ticket = tickets[indexPath.row] as! NSMutableDictionary
        let ticketdetailsview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "TicketDetailsViewController") as! TicketDetailsViewController
        ticketdetailsview.ticket = ticket
        self.navigationController!.pushViewController(ticketdetailsview, animated: true)
    }
}
