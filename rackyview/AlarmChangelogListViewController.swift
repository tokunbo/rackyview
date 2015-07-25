//
//  AlarmHistoryListViewController.swift
//  Rackyview
//
//  Created by RackerQA on 6/20/15.
//  Copyright (c) 2015 rackyperson. All rights reserved.
//

import UIKit
import Foundation

class AlarmChangelogListViewController: UITableViewController,UITableViewDataSource {
    var entityID:String!
    var alarmID:String!
    var changelogs:NSArray!
    
    func dismiss () {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if changelogs == nil {
            return 0
        } else {
            return changelogs.count
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.grayColor()
        self.navigationController!.navigationBar.titleTextAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(16), NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController!.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.Plain, target: self, action: "dismiss")
        self.navigationController!.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController!.navigationBar.barTintColor = UIColor.grayColor()
        self.navigationController!.navigationBar.translucent = false
        self.tableView.reloadData()//---Because I want the heart icon to update in real time.
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
        self.refreshControl?.endRefreshing()
        var got1000entries:Bool = false
        raxutils.setUIBusy(self.navigationController?.view, isBusy: true, expectingSignificantLoadTime: true)
        changelogs = raxAPI.getAlarmChangelogs(entityID: entityID)
        raxutils.setUIBusy(nil, isBusy: false)
        if changelogs == nil {
            raxutils.reportGenericError(self)
        } else {
            var tmpArray = NSMutableArray()
            for cl in changelogs {
                if cl["alarm_id"] as? String == alarmID {
                    tmpArray.addObject(cl)
                }
            }
            if changelogs.count == 1000 {
                got1000entries = true
            }
            changelogs = tmpArray.sortedArrayUsingDescriptors([NSSortDescriptor(key: "timestamp", ascending: false)])
            if changelogs.count == 0 {
                raxutils.alert("No changelogs", message: "There doesn't seem to be any changelogs for this alarm." , vc: self, onDismiss: { action in
                    self.dismiss()
                })
            } else {
                tableView.reloadData()
                if got1000entries {
                    raxutils.alert("1,000 entries",
                        message: "Note that this app doesn't support pagination and the API returns the changelogs for *ALL* the alarms on the entity this particular alarm belongs to, then this app filters by alarmID. The app just filtered by alarmID for the first 1,000 changelogs. Anything beyond that is unfortunately unavailable.", vc: self, onDismiss: nil)
                }
            }
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = (self.view as! UITableView).dequeueReusableCellWithIdentifier("AlarmHistoryListTableCell") as! UITableViewCell
        var changelog:NSDictionary = changelogs[indexPath.row] as! NSDictionary
        var changelogState = (changelog["state"]as! String).lowercaseString
        var stateColor = raxutils.getColorForState(changelogState)
        var shortcodeState = "????"
        (cell.viewWithTag(1) as! UIImageView).image = raxutils.createColoredImageFromUIImage(UIImage(named: "bellicon.png")!, myColor: stateColor)
        if(changelogState.rangeOfString("critical") != nil) {
            shortcodeState = "CRIT"
        }
        if(changelogState.rangeOfString("warning") != nil) {
            shortcodeState = "WARN"
        }
        if(changelogState.rangeOfString("ok") != nil) {
            shortcodeState = "OK"
        }
        (cell.viewWithTag(2) as! UILabel).text = shortcodeState
        (cell.viewWithTag(3) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(changelog.objectForKey("timestamp") as! Double)
        (cell.viewWithTag(4) as! UILabel).text = changelog["status"] as? String
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var changelog:NSDictionary = changelogs[indexPath.row] as! NSDictionary
        tableView.cellForRowAtIndexPath(indexPath)?.selected = false
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        raxutils.confirmDialog("Changelog Details\n\nCopy this info to clipboard?",
            message: String(stringInterpolationSegment: changelog), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.generalPasteboard().string = String(stringInterpolationSegment: changelog)
            })
    }
    
}
