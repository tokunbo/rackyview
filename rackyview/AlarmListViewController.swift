
import UIKit
import Foundation

class AlarmListViewController: UITableViewController {
    var alarms:NSArray!
    var viewingstate:String!
    var keyForArrayInResultDictionary:String!
    var entityId:String!
    var displayingFavorites:Bool = false
    var previouslySelectedIndexPath:NSIndexPath!
    var isStreaming:Bool = false
    var highestSeverityFoundColor:UIColor = UIColor.blackColor()
    var timer:NSTimer!

    func dismiss () {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        isStreaming = false
        UIApplication.sharedApplication().idleTimerDisabled = false
        self.navigationController!.navigationBar.layer.removeAllAnimations()
        self.navigationController!.navigationBar.barTintColor = UIColor.blackColor()
        if timer != nil {
            timer.invalidate()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.grayColor()
        self.navigationController!.navigationBar.titleTextAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(16), NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController!.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(AlarmListViewController.dismiss))
        self.navigationController!.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController!.navigationBar.barTintColor = UIColor.grayColor()
        self.navigationController!.navigationBar.translucent = false
        self.tableView.reloadData()//---Because I want the heart icon to update in real time.
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.blackColor()
        self.refreshControl?.tintColor = UIColor.whiteColor()
        self.refreshControl?.addTarget(self, action: #selector(AlarmListViewController.refresh), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if previouslySelectedIndexPath != nil {
            let previouslySelectedCell = tableView.cellForRowAtIndexPath(previouslySelectedIndexPath)
            raxutils.flashView(previouslySelectedCell!.contentView)
            previouslySelectedCell?.reloadInputViews()
            previouslySelectedIndexPath = nil
        }
        if displayingFavorites {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "stream", style: UIBarButtonItemStyle.Plain, target: self, action: #selector(AlarmListViewController.confirmStartStream))
            self.title = "Favorite Alarms"
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(alarms != nil) {
            self.highestSeverityFoundColor = raxutils.getColorForState((alarms[0] as! NSDictionary)["state"] as! NSString as String)
            self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
            return alarms.count
        } else {
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCellWithIdentifier("AlarmListTableCell") as UITableViewCell!
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        let alarmstate:String = (alarm.objectForKey("state") as! String).lowercaseString
        let alarmmessage:String! = alarm.objectForKey("status") as! String!
        var shortcodestate:String = "GONE"
        (cell.viewWithTag(1) as! UIImageView).image = raxutils.createImageFromColor(UIColor.blueColor())
        
        if(alarmstate.rangeOfString("critical") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "reddot.png")
            shortcodestate = "CRIT"
        }
        if(alarmstate.rangeOfString("warning") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "yellowdot.png")
            shortcodestate = "WARN"
        }
        if(alarmstate.rangeOfString("ok") != nil) {
            (cell.viewWithTag(1) as! UIImageView).image = UIImage(named: "greendot.png")
            shortcodestate = "OK"
        }
        (cell.viewWithTag(2) as! UILabel).text = shortcodestate
        (cell.viewWithTag(3) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(alarm.objectForKey("timestamp") as! Double)
        if (alarm.objectForKey("alarm_label") != nil) {
            (cell.viewWithTag(4) as! UILabel).text = alarm.objectForKey("alarm_label") as? String
        } else {
            (cell.viewWithTag(4) as! UILabel).text = alarm.objectForKey("alarm_id") as? String
        }
        (cell.viewWithTag(5) as! UILabel).text = alarmmessage
        
        return cell
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        if(raxutils.alarmHasBeenMarkedAsFavorite(alarm)) {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "smallhearticon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-12,y:12,width:12,height:12)
            raxutils.fadeInAndOut(uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let alarm:NSDictionary = alarms[indexPath.row] as! NSDictionary
        var myTitle = ""
        var favAction = ""
        var bgColor:UIColor
        if(raxutils.alarmHasBeenMarkedAsFavorite(alarm)) {
            myTitle = "Remove\nfrom\nFavorites"
            favAction = "remove"
            bgColor = UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1)
        } else {
            myTitle = "Add\nto\nFavorites"
            favAction = "add"
            bgColor = UIColor.blueColor()
        }
        let toggleFavorite = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: myTitle, handler:{(action,indexrow) in
            raxutils.updateAlarmFavorites(alarm, action: favAction)
            self.tableView.setEditing(false, animated: true)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        })
        let showAlarmHistory = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "Change\nLogs", handler:{(action,indexrow) in
            self.tableView.setEditing(false, animated: true)
            if (alarm["state"] as! String) == "GONE" {
                return
            }
            self.previouslySelectedIndexPath = indexPath
            let alarmchangeloglist = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AlarmChangelogListView") as! AlarmChangelogListViewController
            alarmchangeloglist.entityID = alarm["entity_id"] as? String
            alarmchangeloglist.alarmID = alarm["alarm_id"] as? String
            alarmchangeloglist.title = alarm["alarm_label"] as? String
            self.navigationController?.pushViewController(alarmchangeloglist, animated: true)
        })
        toggleFavorite.backgroundColor = bgColor
        showAlarmHistory.backgroundColor = UIColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1)
        return [toggleFavorite, showAlarmHistory]
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        return//Apparently this empty function is required for cell buttons to show up.
    }
    
    override func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        previouslySelectedIndexPath = indexPath
        let alarm = alarms[indexPath.row] as! NSMutableDictionary
        let alarmdetailview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AlarmDetailViewController") as! AlarmDetailViewController
        alarmdetailview.alarm = alarm
        if alarm.valueForKey("wasntFound") != nil {
            raxutils.alert("Missing",message:"This alarm wasnt found on your account. Maybe it was deleted?",
            vc:self, onDismiss: nil)
            tableView.cellForRowAtIndexPath(indexPath)?.selected = false 
        } else {
            self.navigationController!.pushViewController(alarmdetailview, animated: true)
        }
    }
    
    func refreshFavorites() {
        self.navigationController!.navigationBar.layer.removeAllAnimations()
        raxutils.setUIBusy(self.navigationController!.view, isBusy: true)
        NSOperationQueue().addOperationWithBlock {
            let results:NSMutableDictionary! = raxAPI.latestAlarmStates(self.isStreaming)
            raxutils.setUIBusy(nil, isBusy: false)
            if results == nil {
                raxutils.alert("Session Error",message:"Either the network was down or the websessionID has expired. Gotta go...",vc:self,
                    onDismiss: { action in
                        self.dismiss()
                })
                self.highestSeverityFoundColor = UIColor.whiteColor()
                raxutils.navbarGlow(self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                return
            }
            let customSettings = GlobalState.instance.userdata["customSettings"] as! NSMutableDictionary
            let alarmFavorites = customSettings["alarmFavorites"] as! NSMutableDictionary
            if(results == nil) {
                raxutils.alert("Network error or session timeout",message:"Let's try restarting the app.",vc:self,
                onDismiss: { action in
                    raxutils.restartApp()
                })
                return
            }
            if alarmFavorites.count == 0 {
                raxutils.alert("No alarm favorites",message:"To add/remove alarms from favorites list, swipe an alarm to reveal more actions.",vc:self,
                onDismiss: { action in
                    self.dismiss()
                })
                return
            }
            let alarmsToSearchThrough = NSMutableArray()
            let alarmsToBeShown = NSMutableArray()
            alarmsToSearchThrough.addObjectsFromArray(results["allCriticalAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjectsFromArray(results["allWarningAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjectsFromArray(results["allOkAlarms"] as! NSMutableArray as [AnyObject])
            alarmsToSearchThrough.addObjectsFromArray(results["allUnknownAlarms"] as! NSMutableArray as [AnyObject])
            if(alarmsToSearchThrough.count == 0) {
                raxutils.alert("No alarms found",message:"No alarms found on this account!",vc:self,
                onDismiss: { action in
                    self.dismiss()
                })            }
            var alarmfav:NSMutableDictionary
            var wasFound:Bool
            for key in alarmFavorites.keyEnumerator() {
                wasFound = false
                alarmfav = alarmFavorites.valueForKey(key as! String) as! NSMutableDictionary
                for alarm in alarmsToSearchThrough {
                    if alarm["alarm_id"] as! String == alarmfav["alarm_id"] as! String {
                        alarmsToBeShown.addObject(alarm)
                        wasFound = true
                        break
                    }
                }
                if !wasFound {
                    alarmfav.setValue(true, forKey: "wasntFound")
                    alarmfav.setValue("GONE", forKey: "state")
                    alarmfav.setValue(UIColor.blueColor(), forKey:"UIColor")
                    alarmsToBeShown.addObject(alarmfav)
                }
            }
            self.alarms = raxutils.sortAlarmsBySeverityThenTime(alarmsToBeShown.copy() as! NSArray)
            self.highestSeverityFoundColor = (self.alarms[0] as! NSDictionary)["UIColor"] as! UIColor
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                self.tableView.reloadData()
                self.view.setNeedsLayout()
                if self.isStreaming {
                    raxutils.navbarGlow(self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                    self.timer = NSTimer.scheduledTimerWithTimeInterval(45, target: self, selector: #selector(AlarmListViewController.refreshFavorites), userInfo: nil, repeats: false)
                    if raxAPI.extend_session("favAlarms") != "OK" {
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
            UIApplication.sharedApplication().idleTimerDisabled = true
            let uiview = UIView()
            uiview.frame = navctrl.view.frame
            uiview.backgroundColor = UIColor.clearColor()
            uiview.tag = 99
            uiview.alpha = 1
            uiview.center = CGPointMake(navctrl.view.bounds.size.width / 2,  navctrl.view.bounds.size.height / 2)
            uiview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(AlarmListViewController.confirmCancelStream)))
            NSOperationQueue.mainQueue().addOperationWithBlock {
                navbar.translucent = true
                navctrl.view.addSubview(uiview)
                navctrl.view.bringSubviewToFront(uiview)
            }
            self.view.userInteractionEnabled = false
            raxutils.navbarGlow(navbar, myColor: UIColor.whiteColor())
            raxutils.tableLightwave(self.tableView, myColor:UIColor.whiteColor())
            NSOperationQueue().addOperationWithBlock {
                while self.isStreaming {
                    sleep(2)
                    raxutils.tableLightwave(self.tableView, myColor:self.highestSeverityFoundColor)
                }
            }
            self.timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: #selector(AlarmListViewController.refreshFavorites), userInfo: nil, repeats: false)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                sleep(3)
                self.tableView.scrollRectToVisible(CGRectMake(0, 0, 1, 1), animated: true)
            }
            
        } else {
            isStreaming = false
            UIApplication.sharedApplication().idleTimerDisabled = false
            self.timer.invalidate()
            NSOperationQueue.mainQueue().addOperationWithBlock {
                while navctrl.view.viewWithTag(99) != nil {//Worst iOS dev hack in the history of iOS dev hacks.
                    navctrl.view.viewWithTag(99)?.removeFromSuperview()
                }
                navbar.barTintColor = self.highestSeverityFoundColor
                navbar.layer.removeAllAnimations()
                navbar.translucent = false
                self.refresh()
                self.view.userInteractionEnabled = true
            }
        }
    }
    
    func confirmStartStream() {
        raxutils.confirmDialog("About to activate streaming.", message: "This will auto-refresh every 45 seconds while constantly animating the color that matches the most severe alarm status detected since the last refresh. \n\nYou *CANNOT* use the app during streaming. \n\nTo stop streaming, tap screen twice. \n\n And iOS autolock/sleep will be disabled so it is recommended this device is plugged in for charging.\n\nReady?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                raxutils.setUIBusy(self.view, isBusy: true)
                let retval:String! = raxAPI.extend_session("favAlarms")
                raxutils.setUIBusy(nil, isBusy:false)
                if  retval == "OK" {
                    self.toggleStream()
                } else {
                    raxutils.askToRestartApp(self)
                }
            })
    }
    
    func confirmCancelStream() {
        self.navigationController?.view.viewWithTag(99)!.userInteractionEnabled = false
        raxutils.confirmDialog("Streaming is active", message: "Turing it off will STOP auto-refresh anymore. Is this what you want?", vc: self,
        cancelAction:{ (action:UIAlertAction!) -> Void in
            self.navigationController?.view.viewWithTag(99)!.userInteractionEnabled = true
            return
        },
        okAction:{ (action:UIAlertAction!) -> Void in
            self.toggleStream()
        })
    }
    
    func refresh() {
        self.refreshControl?.endRefreshing()
        if displayingFavorites {
            refreshFavorites()
        } else {
            raxutils.setUIBusy(self.navigationController?.view, isBusy: true)
            NSOperationQueue().addOperationWithBlock {
                let results:NSMutableDictionary! = raxAPI.latestAlarmStates(false)
                self.alarms = nil
                raxutils.setUIBusy(nil, isBusy: false)
                if results == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                if self.keyForArrayInResultDictionary != nil {
                    self.alarms = (results[self.keyForArrayInResultDictionary] as! NSMutableArray).copy() as! NSArray
                } else {
                    for entity in (results["allEntities"] as! NSArray) {
                        if self.entityId == (entity as! NSDictionary)["entity_id"] as! String {
                            self.alarms = (entity as! NSDictionary)["allAlarms"] as! NSArray
                            break
                        }
                    }
                }
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    if self.alarms == nil || self.alarms.count == 0 {
                        raxutils.alert("Poof! All gone!",message:"This entity seems to have disappeared or lost all its alarms or something.",vc:self,
                            onDismiss: { action in
                                self.dismiss()
                            })
                        return
                    }
                    self.tableView.reloadData()
                }
            }
        }
    }
}

    