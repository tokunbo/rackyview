
import UIKit
import Foundation

class AlarmListViewController: UITableViewController {
    var alarms:NSArray!
    var viewingstate:String!
    var keyForArrayInResultDictionary:String!
    var entityId:String!
    var displayingFavorites:Bool = false
    var previouslySelectedIndexPath:IndexPath!
    var isStreaming:Bool = false
    var highestSeverityFoundColor:UIColor = UIColor.black
    var timer:Timer!

    @IBAction func actionDismiss() {
        super.dismiss(animated: true, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isStreaming = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.navigationController!.navigationBar.layer.removeAllAnimations()
        self.navigationController!.navigationBar.barTintColor = UIColor.black
        if timer != nil {
            timer.invalidate()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.gray
        self.navigationController!.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16), NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController!.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AlarmListViewController.actionDismiss))
        self.navigationController!.navigationBar.tintColor = UIColor.white
        self.navigationController!.navigationBar.barTintColor = UIColor.gray
        self.navigationController!.navigationBar.isTranslucent = false
        self.tableView.reloadData()//---Because I want the heart icon to update in real time.
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.black
        self.refreshControl?.tintColor = UIColor.white
        self.refreshControl?.addTarget(self, action: #selector(AlarmListViewController.refresh), for: UIControlEvents.valueChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if previouslySelectedIndexPath != nil {
            let previouslySelectedCell = tableView.cellForRow(at: previouslySelectedIndexPath)
            raxutils.flashView(v: previouslySelectedCell!.contentView)
            previouslySelectedCell?.reloadInputViews()
            previouslySelectedIndexPath = nil
        }
        if displayingFavorites {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "stream", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AlarmListViewController.confirmStartStream))
            self.title = "Favorite Alarms"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(alarms != nil) {
            self.highestSeverityFoundColor = raxutils.getColorForState(state: (alarms[0] as! NSDictionary)["state"] as! NSString as String)
            self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
            return alarms.count
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCell(withIdentifier: "AlarmListTableCell")!
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        let alarmstate:String = (alarm["state"] as! String).lowercased()
        let alarmmessage:String! = alarm["status"] as! String!
        var shortcodestate:String = "GONE"
        (cell.viewWithTag(1) as! UIImageView).image = raxutils.createImageFromColor(myColor: UIColor.blue)
        
        if(alarmstate.range(of: "critical") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "reddot.png")
            shortcodestate = "CRIT"
        }
        if(alarmstate.range(of: "warning") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "yellowdot.png")
            shortcodestate = "WARN"
        }
        if(alarmstate.range(of: "ok") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "greendot.png")
            shortcodestate = "OK"
        }
        (cell.viewWithTag(2) as! UILabel).text = shortcodestate
        (cell.viewWithTag(3) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(epochTime: alarm["timestamp"] as! Double)
        if (alarm["alarm_label"] != nil) {
            (cell.viewWithTag(4) as! UILabel).text = alarm["alarm_label"] as? String
        } else {
            (cell.viewWithTag(4) as! UILabel).text = alarm["alarm_id"] as? String
        }
        (cell.viewWithTag(5) as! UILabel).text = alarmmessage
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        if(raxutils.alarmHasBeenMarkedAsFavorite(alarm: alarm)) {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "smallhearticon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-12,y:12,width:12,height:12)
            raxutils.fadeInAndOut(uiview: uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        var myTitle = ""
        var favAction = ""
        var bgColor:UIColor
        if(raxutils.alarmHasBeenMarkedAsFavorite(alarm: alarm)) {
            myTitle = "Favs\nDrop"
            favAction = "remove"
            bgColor = UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1)
        } else {
            myTitle = "Favs\nAdd"
            favAction = "add"
            bgColor = UIColor.blue
        }
        let toggleFavorite = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: myTitle, handler:{(action,indexrow) in
            raxutils.updateAlarmFavorites(alarm: alarm, action: favAction)
            self.tableView.setEditing(false, animated: true)
            self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
        })
        let showAlarmHistory = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Change\nLogs", handler:{(action,indexrow) in
            self.tableView.setEditing(false, animated: true)
            if (alarm["state"] as! String) == "GONE" {
                return
            }
            self.previouslySelectedIndexPath = indexPath
            let alarmchangeloglist = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AlarmChangelogListView") as! AlarmChangelogListViewController
            alarmchangeloglist.entityID = alarm["entity_id"] as? String
            alarmchangeloglist.alarmID = alarm["alarm_id"] as? String
            alarmchangeloglist.title = alarm["alarm_label"] as? String
            self.navigationController?.pushViewController(alarmchangeloglist, animated: true)
        })
        toggleFavorite.backgroundColor = bgColor
        showAlarmHistory.backgroundColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1)
        return [toggleFavorite, showAlarmHistory]
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        return//Apparently this empty function is required for cell buttons to show up.
    }
    
   override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
     override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        previouslySelectedIndexPath = indexPath
        let alarm = alarms[indexPath.row] as! NSMutableDictionary
        let alarmdetailview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AlarmDetailViewController") as! AlarmDetailViewController
        alarmdetailview.alarm = alarm
        if alarm["wasntFound"] != nil {
            raxutils.alert(title: "Missing",message:"This alarm wasnt found on your account. Maybe it was deleted?",
            vc:self, onDismiss: nil)
            tableView.cellForRow(at: indexPath)?.isSelected = false
        } else {
            self.navigationController!.pushViewController(alarmdetailview, animated: true)
        }
    }
    
    @IBAction func refreshFavorites() {
        self.navigationController!.navigationBar.layer.removeAllAnimations()
        raxutils.setUIBusy(v: self.navigationController!.view, isBusy: true)
        OperationQueue().addOperation {
            let results:NSMutableDictionary! = raxAPI.latestAlarmStates(isStreaming: self.isStreaming)
            raxutils.setUIBusy(v: nil, isBusy: false)
            if results == nil {
                raxutils.alert(title: "Session Error",message:"Either the network was down or the websessionID has expired. Gotta go...",vc:self,
                    onDismiss: { action in
                        self.dismiss(animated: true)
                })
                self.highestSeverityFoundColor = UIColor.white
                raxutils.navbarGlow(navbar: self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                return
            }
            let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
            let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
            if(results == nil) {
                raxutils.alert(title: "Network error or session timeout",message:"Let's try restarting the app.",vc:self,
                onDismiss: { action in
                    raxutils.restartApp()
                })
                return
            }
            if alarmFavorites.count == 0 {
                raxutils.alert(title: "No alarm favorites",message:"To add/remove alarms from favorites list, swipe an alarm to reveal more actions.",vc:self,
                onDismiss: { action in
                    self.dismiss(animated: true)
                })
                return
            }
            let alarmsToSearchThrough = NSMutableArray()
            let alarmsToBeShown = NSMutableArray()
            alarmsToSearchThrough.addObjects(from: results["allCriticalAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjects(from: results["allWarningAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjects(from: results["allOkAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjects(from: results["allUnknownAlarms"] as! NSMutableArray as [AnyObject])
            if(alarmsToSearchThrough.count == 0) {
                raxutils.alert(title: "No alarms found",message:"No alarms found on this account!",vc:self,
                               onDismiss: { action in
                                    self.dismiss(animated: true)
                               }
                )
            }
            var alarmfav:NSMutableDictionary
            var wasFound:Bool
            for key in alarmFavorites.keyEnumerator() {
                wasFound = false
                alarmfav = alarmFavorites.value(forKey: key as! String) as! NSMutableDictionary
                for case let alarm as NSDictionary in alarmsToSearchThrough {
                    if alarm["alarm_id"] as! String == alarmfav["alarm_id"] as! String {
                        alarmsToBeShown.add(alarm)
                        wasFound = true
                        break
                    }
                }
                if !wasFound {
                    alarmfav.setValue(true, forKey: "wasntFound")
                    alarmfav.setValue("GONE", forKey: "state")
                    alarmfav.setValue(UIColor.blue, forKey:"UIColor")
                    alarmsToBeShown.add(alarmfav)
                }
            }
            self.alarms = raxutils.sortAlarmsBySeverityThenTime(in_alarms: alarmsToBeShown.copy() as! NSArray)
            self.highestSeverityFoundColor = (self.alarms[0] as! NSDictionary)["UIColor"] as! UIColor
            OperationQueue.main.addOperation {
                self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                self.tableView.reloadData()
                self.view.setNeedsLayout()
                if self.isStreaming {
                    raxutils.navbarGlow(navbar: self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                    self.timer = Timer.scheduledTimer(timeInterval: 45, target: self, selector: #selector(AlarmListViewController.refreshFavorites), userInfo: nil, repeats: false)
                    if raxAPI.extend_session(reason: "favAlarms") != "OK" {
                        NSLog("extend_session returned something other than 'OK'. This might be a problem.")
                    }
                }
            }
        }
    }
    
    func toggleStream() {
        let navbar:UINavigationBar = self.navigationController!.navigationBar
        let navctrl:UINavigationController =  self.navigationController!
        if( !isStreaming ) {
            isStreaming = true
            UIApplication.shared.isIdleTimerDisabled = true
            let uiview = UIView()
            uiview.frame = navctrl.view.frame
            uiview.backgroundColor = UIColor.clear
            uiview.tag = 99
            uiview.alpha = 1
            uiview.center = CGPoint(x: navctrl.view.bounds.size.width / 2,  y: navctrl.view.bounds.size.height / 2)
            uiview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(AlarmListViewController.confirmCancelStream)))
            OperationQueue.main.addOperation {
                navbar.isTranslucent = true
                navctrl.view.addSubview(uiview)
                navctrl.view.bringSubview(toFront: uiview)
            }
            self.view.isUserInteractionEnabled = false
            raxutils.navbarGlow(navbar: navbar, myColor: UIColor.white)
            raxutils.tableLightwave(tableview: self.tableView, myColor:UIColor.white)
            OperationQueue().addOperation {
                while self.isStreaming {
                    sleep(2)
                    raxutils.tableLightwave(tableview: self.tableView, myColor:self.highestSeverityFoundColor)
                }
            }
            self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(AlarmListViewController.refreshFavorites), userInfo: nil, repeats: false)
            OperationQueue.main.addOperation {
                sleep(3)
                self.tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
            }
            
        } else {
            isStreaming = false
            UIApplication.shared.isIdleTimerDisabled = false
            self.timer.invalidate()
            OperationQueue.main.addOperation {
                while navctrl.view.viewWithTag(99) != nil {//Worst iOS dev hack in the history of iOS dev hacks.
                    navctrl.view.viewWithTag(99)?.removeFromSuperview()
                }
                navbar.barTintColor = self.highestSeverityFoundColor
                navbar.layer.removeAllAnimations()
                navbar.isTranslucent = false
                self.refresh()
                self.view.isUserInteractionEnabled = true
            }
        }
    }
    
    @IBAction func confirmStartStream() {
        raxutils.confirmDialog(title: "About to activate streaming.", message: "This will auto-refresh every 45 seconds while constantly animating the color that matches the most severe alarm status detected since the last refresh. \n\nYou *CANNOT* use the app during streaming. \n\nTo stop streaming, tap screen twice. \n\n And iOS autolock/sleep will be disabled so it is recommended this device is plugged in for charging.\n\nReady?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                raxutils.setUIBusy(v: self.view, isBusy: true)
                let retval:String! = raxAPI.extend_session(reason: "favAlarms")
                raxutils.setUIBusy(v: nil, isBusy:false)
                if  retval == "OK" {
                    self.toggleStream()
                } else {
                    raxutils.askToRestartApp(vc: self)
                }
            })
    }
    
    @IBAction func confirmCancelStream() {
        self.navigationController?.view.viewWithTag(99)!.isUserInteractionEnabled = false
        raxutils.confirmDialog(title: "Streaming is active", message: "Turing it off will STOP auto-refresh anymore. Is this what you want?", vc: self,
        cancelAction:{ (action:UIAlertAction!) -> Void in
            self.navigationController?.view.viewWithTag(99)!.isUserInteractionEnabled = true
            return
        },
        okAction:{ (action:UIAlertAction!) -> Void in
            self.toggleStream()
        })
    }
    
    @IBAction func refresh() {
        self.refreshControl?.endRefreshing()
        if displayingFavorites {
            refreshFavorites()
        } else {
            raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
            OperationQueue().addOperation {
                let results:NSMutableDictionary! = raxAPI.latestAlarmStates(isStreaming: false)
                self.alarms = nil
                raxutils.setUIBusy(v: nil, isBusy: false)
                if results == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                if self.keyForArrayInResultDictionary != nil {
                    self.alarms = (results[self.keyForArrayInResultDictionary] as! NSMutableArray).copy() as! NSArray
                } else {
                    for case let entity as NSDictionary in (results["allEntities"] as! NSArray) {
                        if self.entityId == entity["entity_id"] as! String {
                            self.alarms = entity["allAlarms"] as! NSArray
                            break
                        }
                    }
                }
                OperationQueue.main.addOperation {
                    if self.alarms == nil || self.alarms.count == 0 {
                        raxutils.alert(title: "Poof! All gone!",message:"This entity seems to have disappeared or lost all its alarms or something.",vc:self,
                            onDismiss: { action in
                                self.dismiss(animated: true)
                            })
                        return
                    }
                    self.tableView.reloadData()
                }
            }
        }
    }
}
