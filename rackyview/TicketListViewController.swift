

import UIKit
import Foundation

class TicketListViewController: UITableViewController {
    var t_status:String = ""
    var tickets:NSMutableArray = NSMutableArray()
    var previouslySelectedIndexPath:NSIndexPath!
    
    func dismiss() {
        (self.parentViewController as! TicketsTabBarController).dismiss()
    }
    
    func refresh() {
        self.tableView.scrollEnabled = false //Scrolling while loading causes a crash apparently
        raxutils.setUIBusy(self.navigationController!.view, isBusy: true)
        NSOperationQueue().addOperationWithBlock {
            let nsdata:NSData! = raxAPI.get_tickets_by_status(self.t_status)
            if(nsdata == nil) {
                raxutils.alert("Auth Error", message: "sessionid has apparently expired", vc: self,onDismiss: { action in
                    self.dismiss()
                })
                return
            }
            let responsedata:NSDictionary! = (try? NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary!
            if(responsedata == nil || responsedata.valueForKey("tickets") == nil) {
                raxutils.alert("Some kind of error", message: "expired websessionid or unexpected data returned", vc: self,onDismiss: { action in
                    self.dismiss()
                })
                return
            }
            self.tickets.removeAllObjects()
            self.tickets.addObjectsFromArray(responsedata.valueForKey("tickets")?.valueForKey("ticket") as! NSArray as [AnyObject])
            if self.title! as NSString as String == "Open Tickets" {
                self.tickets = raxutils.syncTickets(self.tickets)
            }
            if(self.tickets.count == 0) {
                raxutils.alert("None!", message: "No "+((self.title! as NSString) as String)+" to show you", vc: self, onDismiss: nil)
            }
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.tableView.reloadData()
                raxutils.setUIBusy(nil, isBusy: false)
                self.tableView.scrollEnabled = true
                self.refreshControl?.endRefreshing()
                self.view.setNeedsLayout()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if self.title! as NSString as String == "Open Tickets" && self.tickets.count > 0 {
            self.tickets = raxutils.syncTickets(self.tickets)
        }
        self.tableView.reloadData()//---Needed to ensure animation in cells continue.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if previouslySelectedIndexPath != nil {
            let previouslySelectedCell = tableView.cellForRowAtIndexPath(previouslySelectedIndexPath)
            raxutils.flashView(previouslySelectedCell!.contentView)
            previouslySelectedCell?.reloadInputViews()
            previouslySelectedIndexPath = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.blackColor()
        self.refreshControl?.tintColor = UIColor.whiteColor()
        self.refreshControl?.addTarget(self, action: #selector(TicketListViewController.refresh), forControlEvents: UIControlEvents.ValueChanged)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tickets.count == 0) {
            let emptyMessage:UILabel = UILabel(frame: CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height))
            emptyMessage.backgroundColor = UIColor(red: 0, green: 0.1, blue: 0, alpha: 1)
            emptyMessage.textColor = UIColor.whiteColor()
            emptyMessage.text = "Pull all the way down to refresh"
            emptyMessage.textAlignment = NSTextAlignment.Center
            emptyMessage.font = UIFont(name: "Verdana", size: 20)
            emptyMessage.sizeToFit()
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.tableView.backgroundView = emptyMessage
            }
        } else {
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.tableView.backgroundView = nil
            }
        }
        return tickets.count
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if self.title! as NSString as String != "Open Tickets" {
            return
        }
        let ticket:NSMutableDictionary = tickets[indexPath.row] as! NSMutableDictionary
        if ticket["hasUnreadComments"] as! Bool {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "newmessageicon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-47,y:cell.frame.height-36,width:47,height:36)
            raxutils.fadeInAndOut(uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
    override func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCellWithIdentifier("TicketListTableCell") as UITableViewCell!
        let ticket:NSDictionary = tickets[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = (ticket.objectForKey("subject") as! NSString) as String
        (cell.viewWithTag(2) as! UILabel).text = "Updated: "
        (cell.viewWithTag(2) as! UILabel).text?.appendContentsOf((ticket.objectForKey("updated-at") as! NSString) as String)
        (cell.viewWithTag(3) as! UILabel).text = "Status: "
        (cell.viewWithTag(3) as! UILabel).text?.appendContentsOf((ticket.objectForKey("ticket-status") as! NSString) as String)
        (cell.viewWithTag(4) as! UILabel).text = "ID: "
        (cell.viewWithTag(4) as! UILabel).text?.appendContentsOf((ticket.objectForKey("ticket-id") as! NSString) as String)
        
        //TODO: The reason this view is hidden is because the API sometimes returns the wrong count and that hasn't been fixed AFAIK. I don't want to show data that's not reiable if I can help it.
        cell.viewWithTag(5)?.hidden = true
        
        (cell.viewWithTag(5) as! UILabel).text = "Comments: "
        (cell.viewWithTag(5) as! UILabel).text?.appendContentsOf((ticket.objectForKey("public-comment-count") as! NSNumber).stringValue)
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        previouslySelectedIndexPath = indexPath
        tableView.cellForRowAtIndexPath(indexPath)?.selected = false
        let ticket = tickets[indexPath.row] as! NSMutableDictionary
        let ticketdetailsview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("TicketDetailsViewController") as! TicketDetailsViewController
        ticketdetailsview.ticket = ticket
        self.navigationController!.pushViewController(ticketdetailsview, animated: true)
    }
}