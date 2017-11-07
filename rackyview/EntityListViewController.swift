
import UIKit
import Foundation

class EntityListViewController: UITableViewController {
    var viewingstate:String!
    var keyForArrayInResultDictionary:String!
    var entities:NSArray!
    var previouslySelectedIndexPath:IndexPath!
    var isStreaming:Bool = false
    var displayingFavorites:Bool = false
    var highestSeverityFoundColor:UIColor = UIColor.black
    var timer:Timer!
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isStreaming = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.navigationController!.navigationBar.layer.removeAllAnimations()
        if timer != nil {
            timer.invalidate()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.gray
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.plain, target: self, action: #selector(EntityListViewController.dismiss))
        self.navigationController?.navigationBar.barTintColor = raxutils.getColorForState(state: viewingstate)
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.isTranslucent = false
        self.title = self.viewingstate + " Entities"
        self.tableView.dataSource = self
        self.tableView.reloadData()
        self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.black
        self.refreshControl?.tintColor = UIColor.white
        self.refreshControl?.addTarget(self, action: #selector(EntityListViewController.refresh), for: UIControlEvents.valueChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if previouslySelectedIndexPath != nil {
            let previouslySelectedCell = tableView.cellForRow(at: previouslySelectedIndexPath as IndexPath)
            raxutils.flashView(v: previouslySelectedCell!.contentView)
            previouslySelectedCell?.reloadInputViews()
            previouslySelectedIndexPath = nil
        }
        if displayingFavorites {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "stream", style: UIBarButtonItemStyle.plain, target: self, action: #selector(EntityListViewController.confirmStartStream))
            self.title = "Favorite Entities"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if entities != nil {
            return entities.count
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "EntityListTableCell")!
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        let entityState:String = entity["state"] as! NSString as String
        let alarmstatelist:NSArray = entity["latest_alarm_states"] as! NSArray
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
        (cell.viewWithTag(1) as! UILabel).text = String((entity[alarmstate+"Alarms"] as! NSArray).count)+" "+entityState+" Alarms"
        (cell.viewWithTag(2) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(epochTime: (alarmstatelist[0] as AnyObject).object(forKey: "timestamp") as! Double)
        (cell.viewWithTag(3) as! UILabel).text = entity["entity_label"] as? String
        (cell.viewWithTag(4) as! UILabel).text = (alarmstatelist[0] as AnyObject).object(forKey: "status") as? String
        (cell.viewWithTag(5) as! UIImageView).image = raxutils.createColoredImageFromUIImage(myImage: UIImage(named: "bellicon.png")!, myColor: raxutils.getColorForState(state: entityState))
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        if(raxutils.entityHasBeenMarkedAsFavorite(entity: entity)) {
            let uiimageview:UIImageView = UIImageView()
            uiimageview.image = UIImage(named: "smallhearticon.png")
            uiimageview.tag = 99
            uiimageview.frame = CGRect(x:cell.frame.width-12,y:12,width:12,height:12)
            raxutils.fadeInAndOut(uiview: uiimageview)
            cell.addSubview(uiimageview)
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        var myTitle = ""
        var favAction = ""
        var bgColor:UIColor
        if(raxutils.entityHasBeenMarkedAsFavorite(entity: entity)) {
            myTitle = "Remove\nfrom\nFavorites"
            favAction = "remove"
            bgColor = UIColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1)
        } else {
            myTitle = "Add\nto\nFavorites"
            favAction = "add"
            bgColor = UIColor.blue
        }
        let toggleFavorite = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: myTitle, handler:{(action,indexrow) in
            raxutils.updateEntityFavorites(entity: entity, action: favAction)
            self.tableView.setEditing(false, animated: true)
            self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
        })
        let showAgentInfo = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Agent\nInfo", handler:{(action,indexrow) in
            self.tableView.setEditing(false, animated: true)
            let agentinfoview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AgentInfoViewController") as! AgentInfoViewController
            agentinfoview.entityid = entity["entity_id"] as! String!
            agentinfoview.title = entity["entity_label"] as! String!
            self.present(UINavigationController(rootViewController: agentinfoview), animated: true, completion: nil)
        })
        showAgentInfo.backgroundColor = UIColor.purple
        toggleFavorite.backgroundColor = bgColor
        return [toggleFavorite, showAgentInfo]
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let uiimageview:UIImageView! = cell.viewWithTag(99) as! UIImageView!
        if uiimageview != nil {
            uiimageview.removeFromSuperview()
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        return//Apparently this empty function is required for cell buttons to show up.
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        previouslySelectedIndexPath = indexPath
        let alarmlistview = UIStoryboard(name:"Main",bundle:nil).instantiateViewController(withIdentifier: "AlarmListView") as! AlarmListViewController
        let entity:NSDictionary = entities[indexPath.row] as! NSDictionary
        alarmlistview.title = (entity["entity_label"] as! String) + " Alarms"
        alarmlistview.alarms = entity["allAlarms"] as! NSArray
        alarmlistview.entityId = entity["entity_id"] as! String
        alarmlistview.viewingstate = self.viewingstate
        self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
        if entity["wasntFound"] != nil {
            raxutils.alert(title: "Can't view alarms on this entity",message:"Either it was deleted or there are no valid alarms attached to it. Check the rackspace website.",
                vc:self, onDismiss: nil)
            tableView.cellForRow(at: indexPath)?.isSelected = false
        } else {
            self.present(UINavigationController(rootViewController: alarmlistview), animated: true, completion: {
                (self.presentedViewController as! UINavigationController).interactivePopGestureRecognizer!.isEnabled = false })
        }
    }
    
    @objc func refreshFavorites() {
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
            let entityFavorites = customSettings["entityFavorites"] as! NSMutableDictionary
            if entityFavorites.count == 0 {
                raxutils.alert(title: "No entity favorites",message:"To add/remove entity from favorites list, swipe an entity's row in the list to reveal more actions.",vc:self,
                    onDismiss: { action in
                        self.dismiss(animated: true)
                })
                return
            }
            let entitiesToSearchThrough = NSMutableArray()
            let entitiesToBeShown = NSMutableArray()
            entitiesToSearchThrough.addObjects(from: results["criticalEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjects(from: results["warningEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjects(from: results["okEntities"] as! NSMutableArray as [AnyObject])
            entitiesToSearchThrough.addObjects(from: results["unknownEntities"] as! NSMutableArray as [AnyObject])
            if(entitiesToSearchThrough.count == 0) {
                raxutils.alert(title: "Whoa, where'd the entities go?",message:"No entities found on this account!",vc:self,
                    onDismiss: { action in
                        self.dismiss(animated: false)
                    })
                return
            }
            var entityfav:NSMutableDictionary
            var wasFound:Bool
            for case let key as String in entityFavorites.keyEnumerator() {
                wasFound = false
                entityfav = entityFavorites[key] as! NSMutableDictionary
                for case let entity as NSDictionary in entitiesToSearchThrough {
                    if entity["entity_id"] as! String == entityfav["entity_id"] as! String {
                        entitiesToBeShown.add(entity)
                        wasFound = true
                        break
                    }
                }
                if !wasFound {
                    entityfav.setValue(true, forKey: "wasntFound")
                    entityfav.setValue("GONE", forKey: "state")
                    entityfav.setValue(UIColor.blue, forKey:"UIColor")
                    entitiesToBeShown.add(entityfav)
                }
            }
            self.entities = raxutils.sortEntitiesBySeverityThenTime(in_entities: entitiesToBeShown.copy() as! NSArray)
            self.highestSeverityFoundColor = raxutils.getColorForState(state: (self.entities[0] as! NSDictionary)["state"] as! NSString as String)
            OperationQueue.main.addOperation {
                self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                self.tableView.reloadData()
                self.view.setNeedsLayout()
                if self.isStreaming {
                    raxutils.navbarGlow(navbar: self.navigationController!.navigationBar, myColor: self.highestSeverityFoundColor)
                    self.timer = Timer.scheduledTimer(timeInterval: 45, target: self, selector: #selector(EntityListViewController.refreshFavorites), userInfo: nil, repeats: false)
                    if raxAPI.extend_session(reason: "favEntities") != "OK" {
                        NSLog("extend_session error, this might a sign of trouble in the futre... who knows.")
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
            uiview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(EntityListViewController.confirmCancelStream)))
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
            self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(EntityListViewController.refreshFavorites), userInfo: nil, repeats: false)
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
    
    @objc func confirmStartStream() {
        raxutils.confirmDialog(title: "About to activate streaming.", message: "This will auto-refresh every 45 seconds while constantly animating the color that matches the most severe entity status detected since the last refresh. \n\nYou *CANNOT* use the app during streaming. \n\nTo stop streaming, tap screen twice. \n\n And iOS autolock/sleep will be disabled so it is recommended this device is plugged in for charging.\n\nReady?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                raxutils.setUIBusy(v: self.view, isBusy: true)
                let retval:String! = raxAPI.extend_session(reason: "favEntities")
                raxutils.setUIBusy(v: nil, isBusy:false)
                if  retval == "OK" {
                    self.toggleStream()
                } else {
                    raxutils.askToRestartApp(vc: self)
                }
            })
    }
    
    @objc func confirmCancelStream() {
        self.navigationController?.view.viewWithTag(99)!.isUserInteractionEnabled = false
        raxutils.confirmDialog(title: "Streaming is active", message: "Turing it off will STOP auto-refresh. Is this what you want?", vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                self.navigationController?.view.viewWithTag(99)!.isUserInteractionEnabled = true
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                self.toggleStream()
        })
    }
    
    @objc func refresh() {
        self.refreshControl?.endRefreshing()
        if displayingFavorites {
            refreshFavorites()
        } else {
            raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true)
            OperationQueue().addOperation {
                let results:NSMutableDictionary! = raxAPI.latestAlarmStates(isStreaming: false)
                self.entities = nil
                raxutils.setUIBusy(v: nil, isBusy: false)
                if results == nil {
                    raxutils.reportGenericError(vc: self)
                    return
                }
                self.entities = (results[self.keyForArrayInResultDictionary] as! NSMutableArray).copy() as! NSArray
                OperationQueue.main.addOperation{
                    if self.entities == nil || self.entities.count == 0 {
                        raxutils.alert(title: "Poof! All gone!",message:"Whoa, all the entities are gone or something? Probably bad network. Try again.",vc:self,
                            onDismiss: { action in
                                self.dismiss(animated: true)
                        })
                        return
                    }
                    self.highestSeverityFoundColor = raxutils.getColorForState(state: (self.entities[0] as! NSDictionary)["state"] as! NSString as String)
                    self.navigationController?.navigationBar.barTintColor = self.highestSeverityFoundColor
                    self.tableView.reloadData()
                }
            }
        }
    }

}
