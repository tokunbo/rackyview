

import UIKit
import Foundation

class ServerListViewController: UITableViewController {
    var servers:NSArray!

    @IBAction func actionDismiss() {
        super.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.view.backgroundColor = UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "↓ Hide", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ServerListViewController.actionDismiss))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "↻ Refresh", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ServerListViewController.refresh))
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1)
        self.navigationController?.navigationBar.isTranslucent = false
        self.title = "Servers (?)"
        if(self.servers == nil) {
           self.refresh()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        raxutils.setUIBusy(v: nil, isBusy: false)
    }
    
    @IBAction func refresh() {
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.tableView.isScrollEnabled = false //Scrolling while loading causes a crash apparently
        raxutils.setUIBusy(v: self.view, isBusy: true,  expectingSignificantLoadTime: true)
        self.servers = nil
        GlobalState.addBackgroundTask(name: "listServerDetails") {
            raxAPI.listServerDetails(funcptr: self.callback)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if(self.servers != nil) {
            self.callback(servers: self.servers, errors: nil)
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
            raxutils.alert(title: "Warning", message: msg, vc: self, onDismiss: nil)
        }
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        if (self.isViewLoaded && self.view.window != nil) {//Because this callback() can be called when the view isn't currently displayed.
            OperationQueue.main.addOperation {
                self.title = "Servers ("+String(self.servers.count)+")"
                self.tableView.reloadData()
                raxutils.setUIBusy(v: nil, isBusy: false)
                self.navigationController?.view.setNeedsLayout()
                self.tableView.isScrollEnabled = true
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(servers == nil) {
            return 0
        }
        return servers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCell(withIdentifier: "ServerListTableCell")!
        let server:NSDictionary = servers[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = (server["server"]as! NSDictionary)["name"] as? String
        (cell.viewWithTag(2) as! UILabel).text = "status:" + ((server["server"] as! NSDictionary)["status"] as? String)!
        (cell.viewWithTag(3) as! UILabel).text = "region:" + (server["region"] as? String)!
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let server:NSDictionary = servers[indexPath.row] as! NSDictionary
        let status = ((server["server"] as! NSDictionary)["status"] as? String)!
        let attentionLabel = (cell.viewWithTag(4) as! UILabel)
        if(status != "ACTIVE") {
            attentionLabel.isHighlighted = true
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
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let serverdetailview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "ServerDetailViewController") as! ServerDetailViewController
        serverdetailview.server = servers[indexPath.row] as! NSMutableDictionary
        self.navigationController!.pushViewController(serverdetailview, animated: true)
    }
}
    
