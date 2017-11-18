//
//  AlarmHistoryListViewController.swift
//  Rackyview
//
//  Created by RackerQA on 6/20/15.
//  Copyright (c) 2015 rackyperson. All rights reserved.
//

import UIKit
import Foundation

class AlarmChangelogListViewController: UITableViewController {
    var entityID:String!
    var alarmID:String!
    var changelogs:NSArray!
    
    @IBAction func actionDismiss() {
        super.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if changelogs == nil {
            return 0
        } else {
            return changelogs.count
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor.gray
        self.navigationController!.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16), NSAttributedStringKey.foregroundColor: UIColor.white]
        self.navigationController!.setNavigationBarHidden(false, animated: true)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "←Dismiss", style: UIBarButtonItemStyle.plain, target: self, action: #selector(AlarmChangelogListViewController.actionDismiss))
        self.navigationController!.navigationBar.tintColor = UIColor.white
        self.navigationController!.navigationBar.barTintColor = UIColor.gray
        self.navigationController!.navigationBar.isTranslucent = false
        self.tableView.reloadData()//---Because I want the heart icon to update in real time.
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.backgroundColor = UIColor.black
        self.refreshControl?.tintColor = UIColor.white
        self.refreshControl?.addTarget(self, action: #selector(AlarmChangelogListViewController.refresh), for: UIControlEvents.valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    @IBAction func refresh() {
        self.refreshControl?.endRefreshing()
        var got1000entries:Bool = false
        raxutils.setUIBusy(v: self.navigationController?.view, isBusy: true, expectingSignificantLoadTime: true)
        changelogs = raxAPI.getAlarmChangelogs(entityID: entityID)
        raxutils.setUIBusy(v: nil, isBusy: false)
        if changelogs == nil {
            raxutils.reportGenericError(vc: self)
        } else {
            let tmpArray = NSMutableArray()
            for case let cl as NSDictionary in changelogs {
                if cl["alarm_id"] as? String == alarmID {
                    tmpArray.add(cl)
                }
            }
            if changelogs.count == 1000 {
                got1000entries = true
            }
            changelogs = tmpArray.sortedArray(using: [NSSortDescriptor(key: "timestamp", ascending: false)]) as NSArray
            if changelogs.count == 0 {
                raxutils.alert(title: "No changelogs", message: "There doesn't seem to be any changelogs for this alarm." , vc: self, onDismiss: { action in
                    self.dismiss(animated: true)
                })
            } else {
                tableView.reloadData()
                if got1000entries {
                    raxutils.alert(title: "1,000 entries",
                        message: "Note that this app doesn't support pagination and the API returns the changelogs for *ALL* the alarms on the entity this particular alarm belongs to, then this app filters by alarmID. The app just filtered by alarmID for the first 1,000 changelogs. Anything beyond that is unfortunately unavailable.", vc: self, onDismiss: nil)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (self.view as! UITableView).dequeueReusableCell(withIdentifier: "AlarmHistoryListTableCell")!
        let changelog:NSDictionary = changelogs[indexPath.row] as! NSDictionary
        let changelogState = (changelog["state"]as! String).lowercased()
        let stateColor = raxutils.getColorForState(state: changelogState)
        var shortcodeState = "????"
        (cell.viewWithTag(1) as! UIImageView).image = raxutils.createColoredImageFromUIImage(myImage: UIImage(named: "bellicon.png")!, myColor: stateColor)
        if(changelogState.range(of: "critical") != nil) {
            shortcodeState = "CRIT"
        }
        if(changelogState.range(of: "warning") != nil) {
            shortcodeState = "WARN"
        }
        if(changelogState.range(of: "ok") != nil) {
            shortcodeState = "OK"
        }
        (cell.viewWithTag(2) as! UILabel).text = shortcodeState
        (cell.viewWithTag(3) as! UILabel).text = raxutils.epochToHumanReadableTimeAgo(epochTime: changelog["timestamp"] as! Double)
        (cell.viewWithTag(4) as! UILabel).text = changelog["status"] as? String
        return cell
    }
    
     override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changelog:NSDictionary = changelogs[indexPath.row] as! NSDictionary
        tableView.cellForRow(at: indexPath)?.isSelected = false
        tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.fade)
        raxutils.confirmDialog(title: "Changelog Details\n\nCopy this info to clipboard?",
            message: String(stringInterpolationSegment: changelog), vc: self,
            cancelAction:{ (action:UIAlertAction!) -> Void in
                return
            },
            okAction:{ (action:UIAlertAction!) -> Void in
                UIPasteboard.general.string = String(stringInterpolationSegment: changelog)
            })
    }
    
}
