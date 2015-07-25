
import UIKit
import Foundation

class ProcessListViewController: UITableViewController,UITableViewDataSource {
    var processes:NSArray!
    var agentid:String!
    var sortKey:String = "state_name"
    var sortAscend:Bool = true
    var sortSelector:String = "localizedCaseInsensitiveCompare:"
    
    func dismiss () {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.grayColor()
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Back", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "sort", style: UIBarButtonItemStyle.Plain, target: self, action: "sortProcesses")
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        self.navigationController?.navigationBar.translucent = false
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.blackColor()
        self.refreshControl?.tintColor = UIColor.whiteColor()
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: UIControlEvents.ValueChanged)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    func refresh() {
        raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
        var pidsData:NSDictionary! = raxAPI.getAgentInfoByType(agentid, type: "processes")
        self.refreshControl?.endRefreshing()
        raxutils.setUIBusy(nil, isBusy: false)
        if pidsData == nil {
            raxutils.reportGenericError(self, message: "Agent did not respond. Is it installed & running? Verify on Rackspace's website")
            return
        }
        if pidsData.objectForKey("info") as? NSArray == nil {
            raxutils.reportGenericError(self, message: "Agent could not handle the request")
        }
        var tempArray = NSMutableArray()
        for p in (pidsData.objectForKey("info") as! NSArray) {
            tempArray.addObject(p as! NSDictionary)
        }
        processes = tempArray.sortedArrayUsingDescriptors([NSSortDescriptor(key: sortKey, ascending: sortAscend, selector:Selector(sortSelector))])
        self.tableView.reloadData()
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if processes != nil {
            return processes.count
        } else {
            return 0
        }
    }
    
    func sortProcesses() {
        if processes == nil || processes.count == 0 {
            return
        }
        var doSort:()->() = {
            self.processes = self.processes.sortedArrayUsingDescriptors([NSSortDescriptor(key: self.sortKey, ascending: self.sortAscend, selector:Selector(self.sortSelector))])
            self.tableView.reloadData()
        }
        var alert = UIAlertController(title: "Sort "+String(processes.count)+" processes by...", message: "", preferredStyle: UIAlertControllerStyle.ActionSheet)
        alert.addAction(UIAlertAction(title: "Name", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction!) -> Void in
            self.sortKey = "state_name"
            self.sortAscend = true
            self.sortSelector = "localizedCaseInsensitiveCompare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title: "RAM", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction!) -> Void in
            self.sortKey = "memory_resident"
            self.sortAscend = false
            self.sortSelector = "compare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title: "PID", style: UIAlertActionStyle.Default, handler: { (action:UIAlertAction!) -> Void in
            self.sortKey = "pid"
            self.sortAscend = true
            self.sortSelector = "compare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.Destructive, handler: {
            (action:UIAlertAction!) -> Void in
            return
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = self.tableView.dequeueReusableCellWithIdentifier("ProcessListTableCell") as! UITableViewCell
        var process:NSDictionary = processes[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = process["state_name"] as! String!
        (cell.viewWithTag(2) as! UILabel).text = "PID "+(process["pid"] as! NSNumber).stringValue
        (cell.viewWithTag(3) as! UILabel).text = "RAM "
        if process["memory_resident"] == nil {
            (cell.viewWithTag(3) as! UILabel).text?.extend("N/A")
        } else {
            var memusage = (process["memory_resident"] as! NSNumber).integerValue
            if memusage / 1000 > 999 {
                (cell.viewWithTag(3) as! UILabel).text?.extend(String(stringInterpolationSegment: Float(memusage)/Float(1000000))+" MB")
            } else {
                (cell.viewWithTag(3) as! UILabel).text?.extend(String(stringInterpolationSegment: Float(memusage)/Float(1000))+" KB")
            }
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var process:NSDictionary = processes[indexPath.row] as! NSDictionary
        tableView.cellForRowAtIndexPath(indexPath)?.selected = false
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        raxutils.confirmDialog((process["state_name"] as! String!)+"\n\nCopy this info to clipboard?",
            message: String(stringInterpolationSegment: process), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.generalPasteboard().string = String(stringInterpolationSegment: process)
            })
    }

}