
import UIKit
import Foundation

class GlobalState {
    var authtoken:String! = nil
    var sessionid:String! = nil
    var csrftoken:String! = nil
    var userdata:NSMutableDictionary! = nil
    var username:String!
    var monitoringEndpoint:String! = nil
    var serverEndpoints:NSArray = NSArray()
    var aiview:UIActivityIndicatorView! = nil
    var opqueues:NSMutableDictionary = NSMutableDictionary()
    var serverlistview:ServerListViewController!
    var latestAlarmStates:NSMutableDictionary!
    
    static var instance:GlobalState = { return GlobalState() }()
    
    class func reset() {
        self.instance = GlobalState()
    }
    
    class func addBackgroundTask(name:String, block:@escaping ( () -> () )) {
        if self.instance.opqueues.value(forKey: name) != nil {
            return
        }
        let q = OperationQueue()
        self.instance.opqueues.setValue(q,forKey: name)
        q.isSuspended = true
        q.addOperation{
            block();
            self.instance.opqueues.removeObject(forKey: name)
        }
        q.isSuspended = false
    }
}
