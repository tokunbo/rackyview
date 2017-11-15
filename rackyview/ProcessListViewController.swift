
import UIKit
import Foundation

class ProcessListViewController: UITableViewController {
    var processes:NSArray!
    var agentid:String!
    var sortKey:String = "state_name"
    var sortAscend:Bool = true
    var sortSelector:String = "localizedCaseInsensitiveCompare:"
    
    @IBAction func actionDismiss() {
        super.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.gray
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ProcessListViewController.actionDismiss))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.white
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "sort", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ProcessListViewController.sortProcesses))
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        self.navigationController?.navigationBar.isTranslucent = false
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.black
        self.refreshControl?.tintColor = UIColor.white
        self.refreshControl?.addTarget(self, action: #selector(ProcessListViewController.refresh), for: UIControlEvents.valueChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    @IBAction func refresh() {
        raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
        let pidsData:NSDictionary! = raxAPI.getAgentInfoByType(agentID: agentid, type: "processes")
        self.refreshControl?.endRefreshing()
        raxutils.setUIBusy(v: nil, isBusy: false)
        if pidsData == nil {
            raxutils.reportGenericError(vc: self, message: "Agent did not respond. Is it installed & running? Verify on Rackspace's website")
            return
        }
        if pidsData["info"] as? NSArray == nil {
            raxutils.reportGenericError(vc: self, message: "Agent could not handle the request")
        }
        let tempArray = NSMutableArray()
        for p in (pidsData["info"] as! NSArray) {
            tempArray.add(p as! NSDictionary)
        }
        processes = tempArray.sortedArray(using: [NSSortDescriptor(key: sortKey, ascending: sortAscend, selector:Selector(sortSelector))]) as NSArray
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if processes != nil {
            return processes.count
        } else {
            return 0
        }
    }
    
    @IBAction func sortProcesses() {
        if processes == nil || processes.count == 0 {
            return
        }
        let doSort:()->() = {
            self.processes = self.processes.sortedArray(using: [NSSortDescriptor(key: self.sortKey, ascending: self.sortAscend, selector:Selector(self.sortSelector))]) as NSArray
            self.tableView.reloadData()
        }
        let alert = UIAlertController(title: "Sort "+String(processes.count)+" processes by...", message: "", preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.addAction(UIAlertAction(title: "Name", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            self.sortKey = "state_name"
            self.sortAscend = true
            self.sortSelector = "localizedCaseInsensitiveCompare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title: "RAM", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            self.sortKey = "memory_resident"
            self.sortAscend = false
            self.sortSelector = "compare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title: "PID", style: UIAlertActionStyle.default, handler: { (action:UIAlertAction) -> Void in
            self.sortKey = "pid"
            self.sortAscend = true
            self.sortSelector = "compare:"
            doSort()
        }))
        alert.addAction(UIAlertAction(title:"CANCEL", style: UIAlertActionStyle.destructive, handler: {
            (action:UIAlertAction) -> Void in
            return
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "ProcessListTableCell")!
        let process:NSDictionary = processes[indexPath.row] as! NSDictionary
        (cell.viewWithTag(1) as! UILabel).text = process["state_name"] as! String!
        (cell.viewWithTag(2) as! UILabel).text = "PID "+(process["pid"] as! NSNumber).stringValue
        (cell.viewWithTag(3) as! UILabel).text = "RAM "
        if process["memory_resident"] == nil {
            (cell.viewWithTag(3) as! UILabel).text?.append("N/A")
        } else {
            let memusage = (process["memory_resident"] as! NSNumber).intValue
            if memusage / 1000 > 999 {
                (cell.viewWithTag(3) as! UILabel).text?.append(String(stringInterpolationSegment: Float(memusage)/Float(1000000))+" MB")
            } else {
                (cell.viewWithTag(3) as! UILabel).text?.append(String(stringInterpolationSegment: Float(memusage)/Float(1000))+" KB")
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let process:NSDictionary = processes[indexPath.row] as! NSDictionary
        tableView.cellForRow(at: indexPath)?.isSelected = false
        tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
        raxutils.confirmDialog(title: (process["state_name"] as! String!)+"\n\nCopy this info to clipboard?",
            message: String(stringInterpolationSegment: process), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.general.string = String(stringInterpolationSegment: process)
            })
    }

}
