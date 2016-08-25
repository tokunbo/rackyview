

import UIKit
import Foundation

class ServerListViewController: UITableViewController {
    var servers:NSArray!

    func dismiss () {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.view.backgroundColor = UIColor.blackColor()
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "↓ Hide", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(ServerListViewController.dismiss))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "↻ Refresh", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(ServerListViewController.refresh))
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1)
        self.navigationController?.navigationBar.translucent = false
        self.title = "Servers (?)"
        if(self.servers == nil) {
           self.refresh()
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        raxutils.setUIBusy(nil, isBusy: false)
    }
    
    func refresh() {
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.tableView.scrollEnabled = false //Scrolling while loading causes a crash apparently
        raxutils.setUIBusy(self.view, isBusy: true,  expectingSignificantLoadTime: true)
        self.servers = nil
        GlobalState.addBackgroundTask("listServerDetails") {
            raxAPI.listServerDetails(self.callback)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if(self.servers != nil) {
            self.callback(self.servers, errors: nil)
        }
    }
    
    func callback(servers: NSArray, errors: NSArray!) {
        self.servers = servers
        if errors != nil && errors.count > 0 {
            var msg:String = String(errors.count)+" errors were encountered while fetching server list: "
            for e in errors {
                msg += "\n--------------------\n"
                msg += String(stringInterpolationSegment: e)
            }
            raxutils.alert("Warning", message: msg, vc: self, onDismiss: nil)
        }
        self.navigationItem.rightBarButtonItem?.enabled = true
        if (self.isViewLoaded() && self.view.window != nil) {//Because this callback() can be called when the view isn't currently displayed.
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.title = "Servers ("+String(self.servers.count)+")"
                self.tableView.reloadData()
                raxutils.setUIBusy(nil, isBusy: false)
                self.navigationController?.view.setNeedsLayout()
                self.tableView.scrollEnabled = true
            }
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(servers == nil) {
            return 0
        }
        return servers.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCellWithIdentifier("ServerListTableCell") as UITableViewCell!
        let server:NSDictionary = servers[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = (server.objectForKey("server") as! NSDictionary).objectForKey("name") as? String
        (cell.viewWithTag(2) as! UILabel).text = "status:" + ((server.objectForKey("server") as! NSDictionary).objectForKey("status") as? String)!
        (cell.viewWithTag(3) as! UILabel).text = "region:" + (server.objectForKey("region") as? String)!
        return cell
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let server:NSDictionary = servers[indexPath.row] as! NSDictionary
        let status = ((server.objectForKey("server") as! NSDictionary).objectForKey("status") as? String)!
        let attentionLabel = (cell.viewWithTag(4) as! UILabel)
        if(status != "ACTIVE") {
            attentionLabel.highlighted = true
            attentionLabel.text = "!"
            if( status == "ERROR") {
                attentionLabel.highlightedTextColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
            } else {
                attentionLabel.highlightedTextColor = UIColor(red: 1, green: 1, blue: 0, alpha: 1)
            }
        }
        //http://stackoverflow.com/questions/10482887/change-each-uitableviewcell-background-color-in-iphone-app
        //The below if-statement is redundant, but it's a workaround for an iOS bug in redrawing
        //tablecells. Removing it will cause cells to be marked for attention incorrectly.
        if(status == "ACTIVE") {
            attentionLabel.text = ""
        }
    }
    

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let serverdetailview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("ServerDetailViewController") as! ServerDetailViewController
        serverdetailview.server = servers[indexPath.row] as! NSMutableDictionary
        self.navigationController!.pushViewController(serverdetailview, animated: true)
    }
}
    