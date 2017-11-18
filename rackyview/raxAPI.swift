
import UIKit
import Foundation

class raxAPI {
    class func _createRequest(method: String, url: String, reqbody: String!, qparams: String!, content_type:String!) -> NSMutableURLRequest! {
        let req:NSMutableURLRequest = NSMutableURLRequest()
        var cookieString:String = ""
        req.httpMethod = method
        if (content_type == nil) {
            req.setValue("application/json", forHTTPHeaderField:"content-type")
        } else {
            req.setValue(content_type, forHTTPHeaderField:"content-type")
        }
        
        req.setValue("Rackyview (iOS app "+raxutils.getVersion()+")", forHTTPHeaderField:"User-Agent")
        if(GlobalState.instance.authtoken != nil && url.range(of: "//mycloud") == nil) {
            req.setValue(GlobalState.instance.authtoken, forHTTPHeaderField:"X-Auth-Token")
        }
        if(url.range(of: "//mycloud") != nil && url.range(of: "com/") != nil) {//Don't set cookies when trying to login.
            if(GlobalState.instance.sessionid != nil) {
                cookieString.append("sessionid="+GlobalState.instance.sessionid+";")
            }
            if(GlobalState.instance.csrftoken != nil) {
                cookieString.append("csrftoken="+GlobalState.instance.csrftoken+";")
            }
            if(cookieString.lengthOfBytes(using: String.Encoding.utf8) > 0) {//setting an empty string breaks the whole req object, i think.
                req.setValue(cookieString,forHTTPHeaderField:"Cookie")
            }
        }
        if(url.range(of: "com/") == nil) {
            req.setValue("https://mycloud.rackspace.com/?logout_success=true", forHTTPHeaderField:"Referer")//Apparently Rackspace needs this now during login.
        }

        if(qparams != nil){
            req.url = (NSURL(string: url+"/"+qparams!)! as URL)
        } else {
            req.url = (NSURL(string: url)! as URL)
        }
        if(reqbody != nil) {
            req.httpBody = reqbody.data(using: .utf8)
        }
        if(method == "HEAD") {
            req.setValue("close", forHTTPHeaderField: "Connection")
        }
        return req
    }
    
    //Because Apple deprecated NSURLConnection.sendSynchronousRequest, but I really like its blocking behavior
    //Idea comes from the Obj-C equiv someone else wrote: https://forums.developer.apple.com/thread/11519
    class func sendSynchronousRequest(request:NSURLRequest, returningResponse: inout URLResponse?) throws -> NSData! {
        var nsdata:NSData! = nil
        var nserror:NSError! = nil
        var response:URLResponse! = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession(configuration: URLSessionConfiguration.default)
        .dataTask(with: request as URLRequest, completionHandler: { (async_nsdata, async_response, async_error) -> Void in
            nsdata = async_nsdata as NSData!
            nserror = async_error as NSError!
            response = async_response
            semaphore.signal()
        }).resume()
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        returningResponse = response
        if nserror != nil {
            throw nserror
        }
        return nsdata
    }
    
    class func login(u:String, p:String) -> String {
        let url:String = "https://mycloud.rackspace.com"
        var setcookie:String!
        var postdata:String = "username="+u
        var resp:URLResponse? = nil
        var err:NSError? = nil
        postdata += "&password="+p.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        postdata += "&type=password"
        do {
            try _ = self.sendSynchronousRequest(request:
                self._createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded")!,
                returningResponse:&resp)
        } catch let error as NSError {
            err = error
        }
        if (resp == nil || err != nil) {
            if (err == nil) {
                return String(stringInterpolationSegment: resp)
            } else {
                return String(stringInterpolationSegment: err)
            }
        }
        setcookie = (resp as? HTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String!
        if setcookie == nil {
            return "Not Set-Cookie in responseHeaders"
        }
        let respURL = String(stringInterpolationSegment: resp?.url)
        if respURL.range(of: "/cloud/") != nil {
            GlobalState.instance.sessionid = raxutils.substringUsingRegex(regexPattern: "sessionid=(\\S+);", sourceString: setcookie)
            return "OK"
        } else if respURL.range(of: "/accounts/verify") != nil {
            return "twofactorauth"
        } else if respURL.range(of: "/home") != nil {
            return "Routed to deadend(Sometimes that happens, just try again): " + respURL
        }
        return String(stringInterpolationSegment: resp)
    }
    
    class func _getSessionidWith2FAcode(code:String, myDelegate:URLSessionDelegate) {
        let url:String = "https://mycloud.rackspace.com/accounts/verify"
        let postdata:String = "verification_code="+code+"&mfa_type=multifactor_auth"
        let request = self._createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil,
            content_type: "application/x-www-form-urlencoded")!
        URLSession(configuration:URLSessionConfiguration.default, delegate: myDelegate, delegateQueue: OperationQueue()).dataTask(with: request as URLRequest).resume()
    }
    
    class func get_csrftoken() -> String! {
        var csrftoken:String! = nil
        var resp:URLResponse? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        url.append(
            (((GlobalState.instance.userdata.object(forKey: "access")! as AnyObject).object(forKey: "token")! as AnyObject).object(forKey: "tenant")! as AnyObject).object(forKey: "id")! as! String)
        url.append("/servers")
        do {
            try _ = self.sendSynchronousRequest(
                request: self._createRequest(method: "HEAD", url: url, reqbody: nil, qparams: nil, content_type: "text/html; charset=utf-8")!,
                returningResponse:&resp)
        } catch _ as NSError {
            //
        }
        if(resp != nil && (resp as! HTTPURLResponse).statusCode == 200 ) {
            let setcookie:String! = (resp as? HTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String
            csrftoken = raxutils.substringUsingRegex(regexPattern: "csrftoken=(\\S+);", sourceString: setcookie)
        }
        return csrftoken
    }
    
    class func getUserIdForUsername(username:String) -> String! {
        var userid:String!
        let url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/?limit=1000"
        var resp:URLResponse? = nil
        var nsdata:NSData! = nil
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            print("Error in getUserIdForUsername")
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        if jsonData != nil {
            for user in (jsonData!["users"] as! NSArray) {
                if (user as! NSDictionary)["username"] as! NSString! as String == username {
                    userid = (user as! NSDictionary)["id"] as! NSString! as String
                    break
                }
            }
        }
        return userid
    }
    
    class func getAPIkeyForUserid(userid:String) -> String! {
        var apikey:String!
        let url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/"+userid+"/OS-KSADM/credentials/RAX-KSKEY:apiKeyCredentials"
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request:  self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        if jsonData != nil {
            apikey = (jsonData!["RAX-KSKEY:apiKeyCredentials"] as! NSDictionary)["apiKey"] as! NSString! as String
        }
        return apikey
    }
    
    class func getServiceCatalogUsingUsernameAndAPIKey(username:String, apiKey:String, funcptr:@escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?)->Void) {
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let postdata = raxutils.dictionaryToJSONstring(dictionary:
            ["auth": [
                "RAX-KSKEY:apiKeyCredentials":[
                    "username": username,
                    "apiKey": apiKey
                ]
            ]])
        URLSession(configuration:URLSessionConfiguration.default)
            .dataTask(with: _createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: nil)! as URLRequest, completionHandler: funcptr).resume()
    }
    
    class func latestAlarmStatesUsingSavedUsernameAndPassword()->NSMutableDictionary {//This is purely for the appleWatch.
        let results = NSMutableDictionary()
        let userdata = raxutils.getUserdata()
        if userdata == nil {
            results["error"] = "Userdata hasn't been saved in host iOS app"
            return results
        }
        let username = (((NSKeyedUnarchiver.unarchiveObject(with: userdata! as Data) as! NSMutableDictionary!).object(forKey: "access")! as AnyObject).object(forKey: "user")! as AnyObject).object(forKey: "name")! as! String
        let password:String! = raxutils.getPasswordFromKeychain()
        if password == nil {
            results["error"] = "Password wasn't saved in host iOS app."
            return results
        }
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let postdata = raxutils.dictionaryToJSONstring(dictionary:
            ["auth": [
                "passwordCredentials":[
                    "username": username,
                    "password": password
                ]
            ]])
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request:  self._createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            results["error"] = "Couldn't get service catalog."
            results["response"] = resp
            return results
        }
        let serviceCatalog = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        GlobalState.instance.authtoken = (((serviceCatalog as AnyObject).object(forKey: "access") as AnyObject).object(forKey: "token") as AnyObject).object(forKey: "id")! as! String
        for obj in ((serviceCatalog as AnyObject).object(forKey: "access") as AnyObject).object(forKey: "serviceCatalog")! as! NSArray {
            if ((obj as AnyObject).object(forKey: "name")! as AnyObject).isEqual(to: "cloudMonitoring") {
                GlobalState.instance.monitoringEndpoint = ((((obj as AnyObject).object(forKey: "endpoints") as! NSArray)[0] as AnyObject).object as AnyObject).object(forKey: "publicURL") as! String
                break
            }
        }
        results["latestAlarmStates"] = latestAlarmStates()
        return results
    }
    
    
    //TODO: This function is not actually used in the App right now.
    //Maybe add some UI to display the data from this function later?
    class func getAlarmHistory(alarm:NSDictionary) -> NSArray! {
        let ahistoricAlerts:NSMutableArray = NSMutableArray()
        let entityID:String = alarm["entity_id"] as! String
        let checkID:String = alarm["check_id"] as! String
        let alarmID:String = alarm["alarm_id"] as! String
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID+"/notification_history/"+checkID
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody:  nil, qparams: nil, content_type: nil)!,
                        returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        if jsonData == nil {
            return nil
        }
        for alert in jsonData!["values"] as! NSArray {
            ahistoricAlerts.add(alert as! NSDictionary)
        }
        return ahistoricAlerts.copy() as! NSArray
    }
    
    class func getAlarmChangelogs(entityID:String!=nil) -> NSArray! {
        let changeLogs:NSMutableArray = NSMutableArray()
        var url = GlobalState.instance.monitoringEndpoint+"/changelogs/alarms/?"
        if entityID != nil {
            url += "entityId="+entityID+"&limit=1000"
        } else {
            url += "limit=1000"
        }
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        if jsonData == nil {
            return nil
        }
        for changelog in jsonData!["values"] as! NSArray {
            changeLogs.add(changelog as! NSDictionary)
        }
        return changeLogs.copy() as! NSArray
    }
    
    class func refreshUserData(funcptr:@escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?)->Void) {
        let url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        let tenantID = (((GlobalState.instance.userdata.object(forKey: "access")! as AnyObject).object(forKey: "token")! as AnyObject).object(forKey: "tenant")! as AnyObject).object(forKey: "id")! as! String
        let authtoken = ((GlobalState.instance.userdata.object(forKey: "access")! as AnyObject).object(forKey: "token")! as AnyObject).object(forKey: "id")! as! String
        let postdata = raxutils.dictionaryToJSONstring(dictionary:
        ["auth": [
            "tenantId": tenantID,
            "token": [
                "id": authtoken
            ]
        ]])
        URLSession(configuration:URLSessionConfiguration.default)
            .dataTask(with: _createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: nil)! as URLRequest, completionHandler: funcptr).resume()
    }
    
    class func latestAlarmStates(isStreaming:Bool=false, updateGlobal:Bool=true) -> NSMutableDictionary! {
        let results = NSMutableDictionary()
        var url:String
        //Why do I use the website endpoint for streaming? Because an authtoken can expire at any random time after 24hrs.
        //But it appears that by calling extend_session can keep the websessionID alive for 12hrs from the point of time
        //I use the extend_session API. So, I rather do that instead of just using the authtoken that might fail soon afterwards.
        //A known 12hr limit versus a 24hrs limit that might be 20 minutes away from expiring.
        if isStreaming  {
            url = "https://mycloud.rackspace.com/proxy/rax:monitor,cloudMonitoring/views/latest_alarm_states?limit=1000"
        } else {
            url = GlobalState.instance.monitoringEndpoint+"/views/latest_alarm_states?limit=1000"
        }
        var resp:URLResponse? = nil

        var severity = ""
        var alarmstatelist:NSArray! = nil
        var alarmState:String = ""
        var allCriticalAlarms:NSMutableArray = NSMutableArray()
        var allWarningAlarms:NSMutableArray = NSMutableArray()
        var allOkAlarms:NSMutableArray = NSMutableArray()
        var allUnknownAlarms:NSMutableArray = NSMutableArray()
        let allAlarmsFoundOnEntity:NSMutableArray = NSMutableArray()
        
        let criticalAlarms:NSMutableArray = NSMutableArray()
        let warningAlarms:NSMutableArray = NSMutableArray()
        let okAlarms:NSMutableArray = NSMutableArray()
        let unknownAlarms:NSMutableArray = NSMutableArray()
        
        let allEntities = NSMutableArray()
        var okEntities = NSMutableArray()
        var warningEntities = NSMutableArray()
        var criticalEntities = NSMutableArray()
        var unknownEntities = NSMutableArray()
        
        var nsdata:NSData!
        
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        let jsonData = try? JSONSerialization.jsonObject(with: nsdata as Data) as! [String: AnyObject]
        if jsonData == nil {
            return nil
        }
        
        for case let immutable_entity as AnyObject in jsonData!["values"] as! NSArray {
            criticalAlarms.removeAllObjects()
            warningAlarms.removeAllObjects()
            okAlarms.removeAllObjects()
            unknownAlarms.removeAllObjects()
            allAlarmsFoundOnEntity.removeAllObjects()
            severity = ""
            alarmstatelist = (immutable_entity as! NSDictionary).object(forKey: "latest_alarm_states") as! NSArray
            if(alarmstatelist.count == 0) {
                continue
            }
            for immutable_event in alarmstatelist {
                let event = (immutable_event as! NSDictionary).mutableCopy() as! NSMutableDictionary
                severity += ":"
                alarmState = (event["state"] as! String).lowercased()
                severity += alarmState
                if(alarmState.range(of: "ok") != nil) {
                    event["UIColor"] = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
                    okAlarms.add(event)
                    allOkAlarms.add(event)
                } else if(alarmState.range(of: "warning") != nil) {
                    event["UIColor"] = UIColor.orange
                    warningAlarms.add(event)
                    allWarningAlarms.add(event)
                } else if(alarmState.range(of: "critical") != nil) {
                  event["UIColor"] = UIColor.red
                    allCriticalAlarms.add(event)
                    criticalAlarms.add(event)
                } else {//This alarm is in a state that we don't know about.
                    event["UIColor"] = UIColor.blue
                    unknownAlarms.add(event)
                    allUnknownAlarms.add(event)
                }
                allAlarmsFoundOnEntity.add(event)
            }
            let entity = (immutable_entity as! NSDictionary).mutableCopy() as! NSMutableDictionary
            entity["allAlarms"] = raxutils.sortAlarmsBySeverityThenTime(in_alarms: allAlarmsFoundOnEntity)
            entity["criticalAlarms"] = criticalAlarms.sortedArray(comparator: raxutils.compareAlarmEvents)
            entity["warningAlarms"] = warningAlarms.sortedArray(comparator: raxutils.compareAlarmEvents)
            entity["okAlarms"] = okAlarms.sortedArray(comparator: raxutils.compareAlarmEvents)
            entity["unknownAlarms"] = unknownAlarms.sortedArray(comparator: raxutils.compareAlarmEvents)
            if(unknownAlarms.count > 0 ) {
                entity["state"] = "????"
                unknownEntities.add(entity)
            } else if(severity.range(of: ":critical") != nil) {
                entity["state"] = "CRIT"
                criticalEntities.add(entity)
            } else if(severity.range(of: ":warning") != nil) {
                entity["state"] = "WARN"
                warningEntities.add(entity)
            } else {
                entity["state"] = "OK"
                okEntities.add(entity)
            }
            allEntities.add(entity)
        }
        unknownEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(entities: unknownEntities))
        criticalEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(entities: criticalEntities))
        warningEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(entities: warningEntities))
        okEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(entities: okEntities))
        allCriticalAlarms = NSMutableArray(array: allCriticalAlarms.sortedArray(comparator: raxutils.compareAlarmEvents))
        allWarningAlarms = NSMutableArray(array: allWarningAlarms.sortedArray(comparator: raxutils.compareAlarmEvents))
        allOkAlarms = NSMutableArray(array: allOkAlarms.sortedArray(comparator: raxutils.compareAlarmEvents))
        allUnknownAlarms = NSMutableArray(array: allUnknownAlarms.sortedArray(comparator: raxutils.compareAlarmEvents))
        results["allEntities"] = raxutils.sortEntitiesBySeverityThenTime(in_entities: allEntities)
        results["unknownEntities"] = unknownEntities
        results["criticalEntities"] = criticalEntities
        results["warningEntities"] = warningEntities
        results["okEntities"] = okEntities
        results["allCriticalAlarms"] = allCriticalAlarms
        results["allWarningAlarms"] = allWarningAlarms
        results["allOkAlarms"] = allOkAlarms
        results["allUnknownAlarms"] = allUnknownAlarms
        if updateGlobal {
            GlobalState.instance.latestAlarmStates = results
        }
        return results
    }
    
    class func getAgentInfoBasic(agentID:String) -> NSDictionary! {
        let url = "https://mycloud.rackspace.com/proxy/rax:monitor,cloudMonitoring/views/agent_host_info/?include=memory&include=system&include=cpus&include=filesystems&agentId="+agentID+"&sampleCpus=true"
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
    }
    
    class func getSupportedAgentInfoTypes(agentID:String) -> NSDictionary! {
        let url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info_types"
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
    }
    
    class func getAgentInfoByType(agentID:String, type:String) -> NSDictionary! {
        let url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info/"+type
        var resp:URLResponse? = nil
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
    }
    
    class func getEntity(entityID:String) -> NSDictionary! {
        var resp:URLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
    }
 
    class func getCheck(entityid:String, checkid:String) -> NSDictionary! {
        var nsdata:NSData!
        var resp:URLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/checks/"+checkid
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as!NSDictionary
    }
    
    class func getAlarm(entityID:String, alarmID:String) -> NSMutableDictionary! {
        var resp:URLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! (JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary).mutableCopy() as! NSMutableDictionary
    }
    
    class func getNotificationPlan(np_id:String) -> NSDictionary! {
        var resp:URLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/notification_plans/"+np_id
        var nsdata:NSData!
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            nsdata = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return try! JSONSerialization.jsonObject(with: nsdata as Data) as! NSDictionary
    }
    
    class func test_check_or_alarm(entityid:String, postdata:String, targetType:String) -> NSData! {
        var nsdata:NSData! = nil
        var resp:URLResponse? = nil
        let url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/test-"+targetType
        do {
            nsdata = try self.sendSynchronousRequest(request: self._createRequest(method: "POST", url: url, reqbody:  postdata, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
           
        }

        if resp != nil && (resp as! HTTPURLResponse).statusCode != 200 {
            var message = "ERROR: Something went wrong with this alarm(phase:\(targetType))"
            message += "\nHTTP code \((resp as! HTTPURLResponse).statusCode)"
            message += NSString(data: nsdata! as Data, encoding: String.Encoding.utf8.rawValue)! as String
            nsdata = message.data(using: .utf8)! as NSData
        }
        return nsdata
    }
    
    class func extend_session(reason:String="") -> String! {
        var responseBody:String! = nil
        var resp:URLResponse? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        var data:NSData! = nil
        url.append(((((GlobalState.instance.userdata as AnyObject).object(forKey: "access") as AnyObject).object(forKey: "token") as AnyObject).object(forKey: "tenant") as AnyObject).object(forKey: "id")! as! String)
        url.append("/extend_session?window_hash=rackyview_iOSapp&reason="+reason)
        do {
            data = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody:  nil, qparams: nil, content_type: "text/html; charset=utf-8")!, returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! HTTPURLResponse).statusCode == 200 ) {
            responseBody = NSString(data: data! as Data, encoding: String.Encoding.utf8.rawValue)! as String
        }
        return responseBody
    }
    
    class func _doProxyRequest(url:String) -> NSData! {
        var resp:URLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(request: _createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!,
                    returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp == nil || (resp as! HTTPURLResponse).statusCode != 200 ) {
            data = nil
        }
        return data
    }
    
    class func getServerFlavor(server:NSDictionary) -> NSDictionary! {
        var flavor:NSDictionary! = nil
        var url:String = server["APIendpoint"] as! NSString as String
        url.append("/flavors/")
        url.append(((server["server"] as! NSDictionary)["flavor"] as! NSDictionary)["id"] as! NSString as String)
        var resp:URLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(request: _createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! HTTPURLResponse).statusCode == 200 ) {
            flavor = try! JSONSerialization.jsonObject(with: data as Data) as! NSDictionary
        }
        return flavor
    }
    
    class func getServerImage(server:NSDictionary) -> NSDictionary! {
        var image:NSDictionary!
        var url:String = server["APIendpoint"] as! NSString as String
        url.append("/images/")
        url.append(((server["server"] as! NSDictionary)["image"] as! NSDictionary)["id"] as! NSString as String)
        var resp:URLResponse? = nil
        var data:NSData!
        do {
            data = try self.sendSynchronousRequest(request: _createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!, returningResponse: &resp)
        } catch _ as NSError {
            data = nil
        }
        if(resp != nil && (resp as! HTTPURLResponse).statusCode == 200 ) {
            image = try! JSONSerialization.jsonObject(with: data as Data) as! NSDictionary
        }
        return image
    }
    
    class func serveraction(server:NSDictionary, postdata:String, funcptr:@escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?)->Void) {
        var url:String = server["APIendpoint"] as! NSString as String
        url.append("/servers/")
        url.append((server["server"] as! NSDictionary)["id"] as! NSString as String)
        url.append("/action")
        URLSession(configuration:URLSessionConfiguration.default)
            .dataTask(with: _createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: nil)! as URLRequest, completionHandler: funcptr).resume()
    }
    
    
    class func get_tickets_summary () -> NSData! {
        return _doProxyRequest(url: "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/summary")
    }
    
    class func get_tickets_by_status(t_status:String) -> NSData! {
        return _doProxyRequest(url: "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets?status="+t_status)
    }
    
    class func get_ticket_details(t_id:String) -> NSData! {
        return _doProxyRequest(url: "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id)
    }
    
    class func get_ticket_categories() -> NSData! {
        return _doProxyRequest(url: "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/ticket-categories")
    }
    
    
    class func createTicket(primaryCategoryName:String,primaryCategoryID:String,subCategoryName:String,subCategoryID:String,ticketSubject:String,ticketMessageBody:String) -> String! {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets"
        var newTicketID:String!
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring(dictionary:
            ["ticket": [
                "category": [
                    "id": primaryCategoryID,
                    "name": primaryCategoryName,
                    "sub-category": [
                        "id": subCategoryID,
                        "name": subCategoryName
                    ]
            ],
            "subject": ticketSubject,
            "description": ticketMessageBody
        ]]).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        var resp:URLResponse? = nil
        do {
           _ = try self.sendSynchronousRequest(request: _createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!, returningResponse: &resp)
        } catch _ as NSError {
            //Nothing
        }
        if(resp != nil && (resp as! HTTPURLResponse).statusCode == 201 ) {
            let locationHeader:String! = (resp as? HTTPURLResponse)?.allHeaderFields["Location"] as? String
            let range = (try! NSRegularExpression(pattern:"/v1/tickets/(\\S+)", options:[])).firstMatch(in: locationHeader, options: [], range: NSMakeRange(0, locationHeader.lengthOfBytes(using: String.Encoding.utf8)))?.range(at: 1)
            newTicketID = (locationHeader as NSString).substring(with: NSMakeRange((range?.location)!, (range?.length)!))
        }
        return newTicketID
    }
    
    class func submitTicketComment(t_id:String,commentText:String, funcptr:@escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?)->Void) {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/comments"
        var postdata = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring(dictionary: [
            "comment": [
                "type": "TextCommentForCreateType",
                "text": commentText
            ]
        ]).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        URLSession(configuration:URLSessionConfiguration.default)
            .dataTask(with: _createRequest(method: "POST", url: url, reqbody: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=utf-8")! as URLRequest, completionHandler: funcptr).resume()
    }
    
    class func closeTicket(t_id:String, rating:Int, comment:String) -> Int {
        let url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/close"
        var responseCode:Int = 0
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken+"&data="
        postdata += raxutils.dictionaryToJSONstring(
            dictionary: ["ticket-rating": [
                "rating":String(rating),
                "comment": [
                    "text":comment
                ]
            ]
        ]).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        var resp:URLResponse? = nil
        do {
            _ = try self.sendSynchronousRequest(request: _createRequest(method: "PUT", url: url, reqbody: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!, returningResponse: &resp)
        } catch _ as NSError {
        //nothing
        }
        if(resp != nil) {
            responseCode = (resp as! HTTPURLResponse).statusCode
        }
        return responseCode
    }
    
    class func listServerDetails( funcptr:@escaping (_ servers:NSArray,_ errors:NSArray)->Void ){
        let serverlist:NSMutableArray = NSMutableArray()
        let errorlist:NSMutableArray = NSMutableArray()
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.isSuspended = true
        for ep in GlobalState.instance.serverEndpoints {
            q.addOperation {
                let url = String((ep as AnyObject).object(forKey: "publicURL") as! NSString)+"/servers/detail"
                var resp:URLResponse? = nil
                var err:NSError? = nil
                var data:NSData!
                do {
                    data = try self.sendSynchronousRequest(request: self._createRequest(method: "GET", url: url, reqbody: nil, qparams: nil, content_type: nil)!,
                                        returningResponse: &resp)
                } catch let error as NSError {
                    err = error
                    data = nil
                } catch {
                    fatalError()
                }
                if err != nil {
                    errorlist.add(err!)
                }
                if(data == nil) {
                    return
                }
                let serverdata:NSDictionary! = try! JSONSerialization.jsonObject(with: data as Data) as! NSDictionary
                if(serverdata == nil) {
                    return
                }
                var dentry:NSMutableDictionary!
                for s in (serverdata as AnyObject).object(forKey: "servers") as! NSArray {
                    dentry = NSMutableDictionary()
                    dentry.setValue((ep as AnyObject).object(forKey: "region") as! String, forKeyPath: "region")
                    dentry.setValue(s, forKeyPath: "server")
                    dentry.setValue((ep as AnyObject).object(forKey: "publicURL") as! NSString, forKeyPath: "APIendpoint")
                    serverlist.add(dentry)
                }
            }
        }
        q.isSuspended = false
        q.waitUntilAllOperationsAreFinished()
        funcptr(serverlist.copy() as! NSArray, errorlist.copy() as! NSArray)
    }
}
