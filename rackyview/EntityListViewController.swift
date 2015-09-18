
import UIKit
import Foundation

class EntityListViewController: UITableViewController {
    var viewingstate:String!
    var keyForArrayInResultDictionary:String!
    var entities:NSArray!
    var previouslySelectedIndexPath:NSIndexPath!
    var isStreaming:Bool = false
    var displayingFavorites:Bool = false
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
        if timer != nil {
            timer.invalidate()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.grayColor()
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationController?.navigationBar.barTintColor = raxutils.getColorForState(viewingstate)
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.translucent = false
        self.title = self.viewingstate + " Entities"
        self.tableView.dataSource = self
        self.tableView.reloadData()
        self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.blackColor()
        self.refreshControl?.tintColor = UIColor.whiteColor()
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: UIControlEvents.ValueChanged)
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
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "stream", style: UIBarButtonItemStyle.Plain, target: self, action: "confirmStartStream")
            self.title = "Favorite Entities"
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if entities != nil {
            return entities.count
        } else {
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("EntityListTableCell") as UITableViewCell!
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        let entityState:String = entity.objectForKey("state") as! NSString as String
        let alarmstatelist = (entity as NSDictionary).objectForKey("latest_alarm_states") as! NSArray
        var _:UIColor
        var alarmstate:String = ""
        if entityState == "OK" {
            alarmstate = "ok"
        } else if entityState == "WARN" {
            alarmstate = "warning"
        } else if entityState == "CRIT" {
            alarmstate = "critical"
        } else {
            alarmstate = "unknown"
        }
        (cell.viewWithTag(1) as! UILabel).text = String((entity.objectForKey(alarmstate+"Alarms") as! NSArray).count)+" "+entityState+" Alarms"
        (cell.viewWithTag(2) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(alarmstatelist[0].objectForKey("timestamp") as! Double)
        (cell.viewWithTag(3) as! UILabel).text = entity.objectForKey("entity_label") as? String
        (cell.viewWithTag(4) as! UILabel).text = alarmstatelist[0].objectForKey("status") as? String
        (cell.viewWithTag(5) as! UIImageView).image = raxutils.createColoredImageFromUIImage(UIImage(named: "bellicon.png")!, myColor: raxutils.getColorForState(entityState))
        return cell
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        if(raxutils.entityHasBeenMarkedAsFavorite(entity)) {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "smallhearticon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-12,y:12,width:12,height:12)
            raxutils.fadeInAndOut(uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        var myTitle = ""
        var favAction = ""
        var bgColor:UIColor
        if(raxutils.entityHasBeenMarkedAsFavorite(entity)) {
            myTitle = "Remove\nfrom\nFavorites"
            favAction = "remove"
            bgColor = UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1)
        } else {
            myTitle = "Add\nto\nFavorites"
            favAction = "add"
            bgColor = UIColor.blueColor()
        }
        let toggleFavorite = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: myTitle, handler:{(action,indexrow) in
            raxutils.updateEntityFavorites(entity, action: favAction)
            self.tableView.setEditing(false, animated: true)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        })
        let showAgentInfo = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "Agent\nInfo", handler:{(action,indexrow) in
            self.tableView.setEditing(false, animated: true)
            let agentinfoview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AgentInfoViewController") as! AgentInfoViewController
            agentinfoview.entityid = entity["entity_id"] as! String!
            agentinfoview.title = entity["entity_label"] as! String!
            self.presentViewController(UINavigationController(rootViewController: agentinfoview), animated: true, completion: nil)
        })
        showAgentInfo.backgroundColor = UIColor.purpleColor()
        toggleFavorite.backgroundColor = bgColor
        return [toggleFavorite, showAgentInfo]
    }
    
    override func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        return//Apparently this empty function is required for cell buttons to show up.
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        previouslySelectedIndexPath = indexPath
        let alarmlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewControllerWithIdentifier("AlarmListView") as! AlarmListViewController
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        alarmlistview.title = (entity.objectForKey("entity_label") as! String) + " Alarms"
        alarmlistview.alarms = entity["allAlarms"] as! NSArray
        alarmlistview.entityId = entity["entity_id"] as! String
        alarmlistview.viewingstate = self.viewingstate
        self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
        if entity.valueForKey("wasntFound") != nil {
            raxutils.alert("Can't view alarms on this entity",message:"Either it was deleted or there are no valid alarms attached to it. Check the rackspace website.",
                vc:self, onDismiss: nil)
            tableView.cellForRowAtIndexPath(indexPath)?.selected = false
        } else {
            self.presentViewController(UINavigationController(rootViewController: alarmlistview), animated: true, completion: {
            (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.enabled = false })
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
            let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
            if entityFavorites.count == 0 {
                raxutils.alert("No entity favorites",message:"To add/remove entity from favorites list, swipe an entity's row in the list to reveal more actions.",vc:self,
                    onDismiss: { action in
                        self.dismiss()
                })
                return
            }
            let entitiesToSearchThrough = NSMutableArray()
            let entitiesToBeShown = NSMutableArray()
            entitiesToSearchThrough.addObjectsFromArray(results["criticalEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjectsFromArray(results["warningEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjectsFromArray(results["okEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjectsFromArray(results["unknownEntities"] as! NSMutableArray as [AnyObject])
            if(entitiesToSearchThrough.count == 0) {
                raxutils.alert("Whoa, where'd the entities go?",message:"No entities found on this account!",vc:self,
                    onDismiss: { action in
                        self.dismiss()
                    })
                return
            }
            var entityfav:NSMutableDictionary
            var wasFound:Bool
            for key in entityFavorites.keyEnumerator() {
                wasFound = false
                entityfav = entityFavorites.valueForKey(key as! String) as! NSMutableDictionary
                for entity in entitiesToSearchThrough {
                    if entity["entity_id"] as! String == entityfav["entity_id"] as! String {
                        entitiesToBeShown.addObject(entity)
                        wasFound = true
                        break
                    }
                }
                if !wasFound {
                    entityfav.setValue(true, forKey: "wasntFound")
                    entityfav.setValue("GONE", forKey: "state")
                    entityfav.setValue(UIColor.blueColor(), forKey:"UIColor")
                    entitiesToBeShown.addObject(entityfav)
                }
            }
            self.entities = raxutils.sortEntitiesBySeverityThenTime(entitiesToBeShown.copy() as! NSArray)
            self.highestSeverityFoundColor = raxutils.getColorForState((self.entities[0] as! NSDictionary)["state"] as! NSString as String)
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                self.tableView.reloadData()
                self.view.setNeedsLayout()
                if self.isStreaming {
                    raxutils.navbarGlow(self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                    self.timer = NSTimer.scheduledTimerWithTimeInterval(45, target: self, selector: Selector("refreshFavorites"), userInfo: nil, repeats: false)
                    if raxAPI.extend_session("favEntities") != "OK" {
                        NSLog("extend_session error, this might a sign of trouble.")
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
            uiview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: Selector("confirmCancelStream")))
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
            self.timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: Selector("refreshFavorites"), userInfo: nil, repeats: false)
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
        raxutils.confirmDialog("About to activate streaming.", message: "This will auto-refresh every 45 seconds while constantly animating the color that matches the most severe entity status detected since the last refresh. \n\nYou *CANNOT* use the app during streaming. \n\nTo stop streaming, tap screen twice. \n\n And iOS autolock/sleep will be disabled so it is recommended this device is plugged in for charging.\n\nReady?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                raxutils.setUIBusy(self.view, isBusy: true)
                let retval:String! = raxAPI.extend_session("favEntities")
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
        raxutils.confirmDialog("Streaming is active", message: "Turing it off will STOP auto-refresh. Is this what you want?", vc: self,
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
                self.entities = nil
                raxutils.setUIBusy(nil, isBusy: false)
                if results == nil {
                    raxutils.reportGenericError(self)
                    return
                }
                self.entities = (results[self.keyForArrayInResultDictionary] as! NSMutableArray).copy() as! NSArray
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    if self.entities == nil || self.entities.count == 0 {
                        raxutils.alert("Poof! All gone!",message:"Whoa, all the entities are gone or something? Probably bad network. Try again.",vc:self,
                            onDismiss: { action in
                                self.dismiss()
                        })
                        return
                    }
                    self.highestSeverityFoundColor = raxutils.getColorForState((self.entities[0] as! NSDictionary)["state"] as! NSString as String)
                    self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                    self.tableView.reloadData()
                }
            }
        }
    }

}
