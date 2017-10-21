
import UIKit
import Foundation


class AgentInfoViewController: UIViewController {
    var agentid:String!
    var entityid:String!
    var alreadyAutoRefreshed:Bool = false
    
    @IBOutlet var textview:UITextView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AgentInfoViewController.dismiss))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "↻Refresh", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AgentInfoViewController.refresh))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1.0)
        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !alreadyAutoRefreshed {
            refresh()
            alreadyAutoRefreshed = true
        }
    }
    
    @objc func refresh() {
        raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
        if agentid == nil {
            let entityDetails:NSDictionary! = raxAPI.getEntity(entityID: entityid)
            if entityDetails == nil {
                raxutils.reportGenericError(vc: self)
                return
            }
            agentid = entityDetails["agent_id"] as? String
            raxutils.setUIBusy(v: nil, isBusy: false)
        }
        if agentid == nil {
            raxutils.setUIBusy(v: nil, isBusy: false)
            textview.text = "No agent id. Please install agent on this entity. See Rackspace website for instructions."
            return
        }
        let agentInfoBasic:NSDictionary! = raxAPI.getAgentInfoBasic(agentID: agentid)
        raxutils.setUIBusy(v: nil, isBusy: false)
        if agentInfoBasic == nil {
            raxutils.confirmDialog(title: "Ureachable Agent", message: "I see the agentID/serverID but the agent seems to be unreachable. Please check Rackspace website to verify that the agent is actually installed, running & sending data correctly.\n\nIf you're sure the agent is running, there's also a chance that the websession has expired. \n\nWant to refresh your login from the login screen?", vc: self,
                cancelAction:{ (action:UIAlertAction!) -> Void in
                    return
                },
                okAction:{ (action:UIAlertAction!) -> Void in
                    raxutils.restartApp()
                })
            textview.text = "Agent unreachable"
            return
        }
        if(agentInfoBasic["values"] == nil ||
            ((agentInfoBasic["values"] as! NSArray)[0] as AnyObject).object(forKey: "host_info") == nil) {
            raxutils.reportGenericError(vc: self, message:"Missing or malformed data.")
            textview.text = "Missing or malformed data."
            return
        }
        var RAMUsage:String = "RAM: "
        var DiskUsage:String = "Disk: "
        var CPUsUsage:String = "CPUs: "
        let hostInfo:NSDictionary = ((agentInfoBasic["values"] as! NSArray)[0] as AnyObject).object(forKey: "host_info") as! NSDictionary
        
        if (hostInfo["memory"] as! NSDictionary!) != nil  {
            if ((hostInfo["memory"] as! NSDictionary!)["error"] as? String) != nil {
                RAMUsage += ((hostInfo["memory"] as! NSDictionary!)["error"] as! String )
            } else {
                let meminfo:NSDictionary = (hostInfo["memory"] as! NSDictionary!)["info"] as! NSDictionary
                RAMUsage += String(stringInterpolationSegment: (meminfo["used_percent"] as! NSNumber).intValue)
                RAMUsage += "% ("
                RAMUsage += String(stringInterpolationSegment: (meminfo["actual_used"] as! NSNumber).doubleValue / 1000000)
                RAMUsage += " MB of "
                RAMUsage += String(stringInterpolationSegment: ((meminfo["actual_used"] as! NSNumber).doubleValue + (meminfo["actual_free"] as! NSNumber).doubleValue)/1000000)
                RAMUsage += " MB)"
            }
        } else {
            RAMUsage += "N/A"
        }
        
        if (hostInfo["filesystems"] as! NSDictionary!) != nil  {
            if ((hostInfo["filesystems"] as! NSDictionary!)["error"] as? String) != nil {
                DiskUsage += ((hostInfo["filesystems"] as! NSDictionary!)["error"] as! String )
            } else if ((hostInfo["filesystems"] as! NSDictionary!)["info"] as! NSArray).count == 0 {
                DiskUsage = "N/A"
            } else {
                let filesys:NSDictionary = ((hostInfo["filesystems"] as! NSDictionary!)["info"] as! NSArray)[0] as! NSDictionary
                DiskUsage += "MountPoint: "+(filesys["dir_name"] as! String)
                DiskUsage += "\n"+String(stringInterpolationSegment: Float((filesys["used"] as! NSNumber).intValue) / Float((filesys["total"] as! NSNumber).intValue) * 100)
                DiskUsage += "% ("
                DiskUsage += String( stringInterpolationSegment: (filesys["used"] as! NSNumber).doubleValue/1000)
                DiskUsage += " MB of "
                DiskUsage += String( stringInterpolationSegment: (filesys["total"] as! NSNumber).doubleValue/1000)
                DiskUsage += " MB)"
            }
        } else {
            DiskUsage += "N/A"
        }
        
        if (hostInfo["cpus"] as! NSDictionary!) != nil  {
            if ((hostInfo["cpus"] as! NSDictionary!)["error"] as? String) != nil {
                CPUsUsage += ((hostInfo["cpus"] as! NSDictionary!)["error"] as! String )
            } else if ((hostInfo["cpus"] as! NSDictionary!)["info"] as! NSArray).count == 0 {
                CPUsUsage = "N/A"
            } else {
                for case let cpu as NSDictionary in (hostInfo["cpus"] as! NSDictionary!)["info"] as! NSArray {
                    let idle = (cpu["idle"] as! NSNumber).doubleValue
                    let total = (cpu["total"] as! NSNumber).doubleValue
                    CPUsUsage += "\n"
                    CPUsUsage += cpu["name"] as! String
                    CPUsUsage += " at " + String(stringInterpolationSegment: NSNumber(value: idle / total).intValue ) + "%"
                }
            }
        } else {
            CPUsUsage += "N/A"
        }
        textview.text = RAMUsage+"\n\n"+DiskUsage+"\n\n"+CPUsUsage
    }
    
    @IBAction func viewProcesses() {
        
        if agentid == nil {
            raxutils.alert(title: "No agent ID", message: "Cannot fetch this data without a reachable monitoring agent", vc: self, onDismiss: nil)
            return
        }
        let processlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "ProcessListView") as! ProcessListViewController
        processlistview.agentid = agentid
        processlistview.title = self.title
        self.present(UINavigationController(rootViewController: processlistview), animated: true, completion: nil)
    }
    
    @IBAction func viewRawData() {
        if agentid == nil {
            raxutils.alert(title: "No agent ID", message: "Cannot fetch this data without a reachable monitoring agent", vc: self, onDismiss: nil)
            return
        }
        let showAgentMetric:(String)->() = { atype in
            raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
            let ametric:NSDictionary! = raxAPI.getAgentInfoByType(agentID: self.agentid, type: atype)
            raxutils.setUIBusy(v: nil, isBusy: false)
            if ametric == nil {
                raxutils.reportGenericError(vc: self, message: "Couldn't get metric data. Sorry.")
            } else {
                raxutils.confirmDialog(title: atype+" data\n\nCopy this info to clipboard?", message: String(stringInterpolationSegment: ametric), vc: self,
                    cancelAction:{ (action:UIAlertAction!) -> Void in
                        return
                    },
                    okAction:{ (action:UIAlertAction!) -> Void in
                        UIPasteboard.general.string = String(stringInterpolationSegment: ametric)
                    })
            }
        }
        raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
        let agentInfoTypes:NSDictionary! = raxAPI.getSupportedAgentInfoTypes(agentID: agentid)
        if agentInfoTypes == nil {
            raxutils.reportGenericError(vc: self)
            return
        }
        if agentInfoTypes["types"] as? NSArray == nil {
            raxutils.reportGenericError(vc: self, message:"agent could not respond to request of available metrics")
            return
        }
        let atypes:NSArray = agentInfoTypes["types"] as! NSArray
        if atypes.count == 0 {
            raxutils.reportGenericError(vc: self, message:"Agent said it doesn't support any metrics at all!")
            return
        }
        let alert = UIAlertController(title: "Available Agent Metrics", message: "Choose one", preferredStyle: UIAlertControllerStyle.actionSheet)
        for atype in atypes {
            alert.addAction(UIAlertAction(title: atype as? String, style: UIAlertActionStyle.default, handler: {
                (action:UIAlertAction) -> Void in
                OperationQueue.main.addOperation{
                    showAgentMetric(atype as! String)
                }
            }))
        }
        alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.destructive, handler: {
            (action:UIAlertAction) -> Void in
            return
        }))
        raxutils.setUIBusy(v: nil, isBusy: false)
        OperationQueue.main.addOperation {
            self.present(alert, animated: true, completion: nil)
        }
    }

}
