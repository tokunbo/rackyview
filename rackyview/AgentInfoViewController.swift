
import UIKit
import Foundation


class AgentInfoViewController: UIViewController {
    var agentid:String!
    var entityid:String!
    var alreadyAutoRefreshed:Bool = false
    
    @IBOutlet var textview:UITextView!
    
    func dismiss() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Back", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "↻Refresh", style: UIBarButtonItemStyle.Plain, target: self, action: "refresh")
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1.0)
        self.navigationController?.navigationBar.translucent = false
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if !alreadyAutoRefreshed {
            refresh()
            alreadyAutoRefreshed = true
        }
    }
    
    func refresh() {
        raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
        if agentid == nil {
            var entityDetails:NSDictionary! = raxAPI.getEntity(entityid)
            if entityDetails == nil {
                raxutils.reportGenericError(self)
                return
            }
            agentid = entityDetails.objectForKey("agent_id") as? String
            raxutils.setUIBusy(nil, isBusy: false)
        }
        if agentid == nil {
            raxutils.setUIBusy(nil, isBusy: false)
            textview.text = "No agent id. Please install agent on this entity. See Rackspace website for instructions."
            return
        }
        var agentInfoBasic:NSDictionary! = raxAPI.getAgentInfoBasic(agentid)
        raxutils.setUIBusy(nil, isBusy: false)
        if agentInfoBasic == nil {
            raxutils.confirmDialog("Ureachable Agent", message: "I see the agentID/serverID but the agent seems to be unreachable. Please check Rackspace website to verify that the agent is actually installed, running & sending data correctly.\n\nIf you're sure the agent is running, there's also a chance that the websession has expired. \n\nWant to refresh your login from the login screen?", vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    raxutils.restartApp()
                })
            textview.text = "Agent unreachable"
            return
        }
        if(agentInfoBasic.objectForKey("values") == nil ||
          (agentInfoBasic.objectForKey("values") as! NSArray)[0].objectForKey("host_info") == nil) {
            raxutils.reportGenericError(self, message:"Missing or malformed data.")
            textview.text = "Missing or malformed data."
            return
        }
        var RAMUsage:String = "RAM: "
        var DiskUsage:String = "Disk: "
        var CPUsUsage:String = "CPUs: "
        var hostInfo:NSDictionary = (agentInfoBasic.objectForKey("values") as! NSArray)[0].objectForKey("host_info") as! NSDictionary
        
        if (hostInfo.objectForKey("memory") as! NSDictionary!) != nil  {
            if ((hostInfo.objectForKey("memory") as! NSDictionary!).objectForKey("error") as? String) != nil {
                RAMUsage += ((hostInfo.objectForKey("memory") as! NSDictionary!)["error"] as! String )
            } else {
                var meminfo:NSDictionary = (hostInfo.objectForKey("memory") as! NSDictionary!)["info"] as! NSDictionary
                RAMUsage += String(stringInterpolationSegment: (meminfo["used_percent"] as! NSNumber).integerValue)
                RAMUsage += "% ("
                RAMUsage += String(stringInterpolationSegment: (meminfo["actual_used"] as! NSNumber).doubleValue / 1000000)
                RAMUsage += " MB of "
                RAMUsage += String(stringInterpolationSegment: ((meminfo["actual_used"] as! NSNumber).doubleValue + (meminfo["actual_free"] as! NSNumber).doubleValue)/1000000)
                RAMUsage += " MB)"
            }
        } else {
            RAMUsage += "N/A"
        }
        
        if (hostInfo.objectForKey("filesystems") as! NSDictionary!) != nil  {
            if ((hostInfo.objectForKey("filesystems") as! NSDictionary!).objectForKey("error") as? String) != nil {
                DiskUsage += ((hostInfo.objectForKey("filesystems") as! NSDictionary!)["error"] as! String )
            } else if ((hostInfo.objectForKey("filesystems") as! NSDictionary!)["info"] as! NSArray).count == 0 {
                DiskUsage = "N/A"
            } else {
                var filesys:NSDictionary = ((hostInfo.objectForKey("filesystems") as! NSDictionary!)["info"] as! NSArray)[0] as! NSDictionary
                DiskUsage += "MountPoint: "+(filesys["dir_name"] as! String)
                DiskUsage += "\n"+String(stringInterpolationSegment: Float((filesys["used"] as! NSNumber).integerValue) / Float((filesys["total"] as! NSNumber).integerValue) * 100)
                DiskUsage += "% ("
                DiskUsage += String( stringInterpolationSegment: (filesys["used"] as! NSNumber).doubleValue/1000)
                DiskUsage += " MB of "
                DiskUsage += String( stringInterpolationSegment: (filesys["total"] as! NSNumber).doubleValue/1000)
                DiskUsage += " MB)"
            }
        } else {
            DiskUsage += "N/A"
        }
        
        if (hostInfo.objectForKey("cpus") as! NSDictionary!) != nil  {
            if ((hostInfo.objectForKey("cpus") as! NSDictionary!).objectForKey("error") as? String) != nil {
                CPUsUsage += ((hostInfo.objectForKey("cpus") as! NSDictionary!)["error"] as! String )
            } else if ((hostInfo.objectForKey("cpus") as! NSDictionary!)["info"] as! NSArray).count == 0 {
                CPUsUsage = "N/A"
            } else {
                for cpu in (hostInfo.objectForKey("cpus") as! NSDictionary!)["info"] as! NSArray {
                    var idle = (cpu.objectForKey("idle") as! NSNumber).doubleValue
                    var total = (cpu.objectForKey("total") as! NSNumber).doubleValue
                    CPUsUsage += "\n"
                    CPUsUsage += cpu.objectForKey("name") as! String
                    CPUsUsage += " at " + String(stringInterpolationSegment: NSNumber(double: idle / total).integerValue ) + "%"
                }
            }
        } else {
            CPUsUsage += "N/A"
        }
        textview.text = RAMUsage+"\n\n"+DiskUsage+"\n\n"+CPUsUsage
    }
    
    @IBAction func viewProcesses() {
        
        if agentid == nil {
            raxutils.alert("No agent ID", message: "Cannot fetch this data without a reachable monitoring agent", vc: self, onDismiss: nil)
            return
        }
        var processlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("ProcessListView") as! ProcessListViewController
        processlistview.agentid = agentid
        processlistview.title = self.title
        self.presentViewController(UINavigationController(rootViewController: processlistview), animated: true, completion: nil)
    }
    
    @IBAction func viewRawData() {
        if agentid == nil {
            raxutils.alert("No agent ID", message: "Cannot fetch this data without a reachable monitoring agent", vc: self, onDismiss: nil)
            return
        }
        var showAgentMetric:(String)->() = { atype in
            raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
            var ametric:NSDictionary! = raxAPI.getAgentInfoByType(self.agentid, type: atype)
            raxutils.setUIBusy(nil, isBusy: false)
            if ametric == nil {
                raxutils.reportGenericError(self, message: "Couldn't get metric data. Sorry.")
            } else {
                raxutils.confirmDialog(atype+" data\n\nCopy this info to clipboard?", message: String(stringInterpolationSegment: ametric), vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        UIPasteboard.generalPasteboard().string = String(stringInterpolationSegment: ametric)
                    })
            }
        }
        raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
        var agentInfoTypes:NSDictionary! = raxAPI.getSupportedAgentInfoTypes(agentid)
        if agentInfoTypes == nil {
            raxutils.reportGenericError(self)
            return
        }
        if agentInfoTypes.objectForKey("types") as? NSArray == nil {
            raxutils.reportGenericError(self, message:"agent could not respond to request of available metrics")
            return
        }
        var atypes:NSArray = agentInfoTypes.objectForKey("types") as! NSArray
        if atypes.count == 0 {
            raxutils.reportGenericError(self, message:"Agent said it doesn't support any metrics at all!")
            return
        }
        var alert = UIAlertController(title: "Available Agent Metrics", message: "Choose one", preferredStyle: UIAlertControllerStyle.ActionSheet)
        for atype in atypes {
            alert.addAction(UIAlertAction(title: atype as! String, style: UIAlertActionStyle.Default, handler: {
                (action:UIAlertAction!) -> Void in
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    showAgentMetric(atype as! String)
                }
            }))
        }
        alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.Destructive, handler: {
            (action:UIAlertAction!) -> Void in
            return
        }))
        raxutils.setUIBusy(nil, isBusy: false)
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }

}