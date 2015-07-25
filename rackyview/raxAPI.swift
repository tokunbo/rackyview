
import UIKit
import Foundation

class raxAPI {
    class func _createRequest(method: String, url: String, data: String!, qparams: String!, content_type:String!) -> NSMutableURLRequest! {
        var req:NSMutableURLRequest = NSMutableURLRequest()
        var cookieString:String = ""
        req.HTTPMethod = method
        if (content_type == nil) {
            req.setValue("application/json", forHTTPHeaderField:"content-type")
        } else {
            req.setValue(content_type, forHTTPHeaderField:"content-type")
        }
        req.setValue("Rackyview (iOS app "+raxutils.getVersion()+")", forHTTPHeaderField:"User-Agent")
        if(GlobalState.instance.authtoken != nil && url.rangeOfString("//mycloud") == nil) {
            req.setValue(GlobalState.instance.authtoken, forHTTPHeaderField:"X-Auth-Token")
        }
        if(url.rangeOfString("//mycloud") != nil && url.rangeOfString("com/") != nil) {//Don't set cookies when trying to login.
            if(GlobalState.instance.sessionid != nil) {
                cookieString.extend("sessionid="+GlobalState.instance.sessionid+";")
            }
            if(GlobalState.instance.csrftoken != nil) {
                cookieString.extend("csrftoken="+GlobalState.instance.csrftoken+";")
            }
            if(cookieString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0) {//setting an empty string breaks the whole req object, i think.
                req.setValue(cookieString,forHTTPHeaderField:"Cookie")
            }
        }
        if(qparams != nil){
            req.URL = NSURL(string: url+"/"+qparams!)
        } else {
            req.URL = NSURL(string: url)
        }
        if(data != nil) {
            req.HTTPBody = (data as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        }
        if(method == "HEAD") {
            req.setValue("close", forHTTPHeaderField: "Connection")
        }
        return req
    }
    
    class func login(u:String, p:String) -> String {
        var url:String = "https://mycloud.rackspace.com"
        var setcookie:String!
        var postdata:String = "username="+u
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        postdata += "&password="+p.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        postdata += "&type=password"
        NSURLConnection.sendSynchronousRequest(
            self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded")!,
            returningResponse:&resp, error:&err)
        if (resp == nil || err != nil) {
            if (err == nil) {
                return String(stringInterpolationSegment: resp)
            } else {
                return String(stringInterpolationSegment: err)
            }
        }
        setcookie = (resp as? NSHTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String!
        if setcookie == nil {
            return "Not Set-Cookie in responseHeaders"
        }
        var respURL = String(stringInterpolationSegment: resp?.URL)
        if respURL.rangeOfString("/cloud/") != nil {
            GlobalState.instance.sessionid = raxutils.substringUsingRegex("sessionid=(\\S+);", sourceString: setcookie)
            return "OK"
        } else if respURL.rangeOfString("/accounts/verify") != nil {
            return "twofactorauth"
        } else if respURL.rangeOfString("/home") != nil {
            return "Routed to deadend: "+respURL
        }
        return String(stringInterpolationSegment: resp)
    }
    
    class func _getSessionidWith2FAcode(code:String,myDelegate:NSURLSessionDelegate) {
        var url:String = "https://mycloud.rackspace.com/accounts/verify"
        var sessionid:String!
        var setcookie:String!
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var postdata:String = "verification_code="+code+"&mfa_type=multifactor_auth"
        var request = self._createRequest("POST", url: url, data: postdata, qparams: nil,
            content_type: "application/x-www-form-urlencoded")!
        NSURLSession(configuration: nil, delegate: myDelegate, delegateQueue: NSOperationQueue()).dataTaskWithRequest(request).resume()
    }
    
    class func get_csrftoken() -> String! {
        var csrftoken:String! = nil
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        url.extend(GlobalState.instance.userdata.objectForKey("access")!
            .objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String)
        url.extend("/servers")
        NSURLConnection.sendSynchronousRequest(
            self._createRequest("HEAD", url: url, data: nil, qparams: nil, content_type: "text/html; charset=utf-8")!,
            returningResponse:&resp, error:&err)
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            var setcookie:String! = (resp as? NSHTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String
            csrftoken = raxutils.substringUsingRegex("csrftoken=(\\S+);", sourceString: setcookie)
        }
        return csrftoken
    }
    
    class func getUserIdForUsername(username:String) -> String! {
        var userid:String!
        var url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/?limit=1000"
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        var jsonData = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        if jsonData != nil {
            for user in (jsonData["users"] as! NSArray) {
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
        var url:String = "https://mycloud.rackspace.com/proxy/identity/v2.0/users/"+userid+"/OS-KSADM/credentials/RAX-KSKEY:apiKeyCredentials"
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        var jsonData = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        if jsonData != nil {
            apikey = (jsonData["RAX-KSKEY:apiKeyCredentials"] as! NSDictionary)["apiKey"] as! NSString! as String
        }
        return apikey
    }
    
    class func getServiceCatalogUsingUsernameAndAPIKey(username:String,apiKey:String,funcptr:(response: NSURLResponse!, data: NSData!, error: NSError!)->Void) {
        var url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        var postdata = raxutils.dictionaryToJSONstring(
            ["auth": [
                "RAX-KSKEY:apiKeyCredentials":[
                    "username": username,
                    "apiKey": apiKey
                ]
            ]])
        NSURLConnection.sendAsynchronousRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
            queue: NSOperationQueue(), completionHandler: funcptr)
    }
    
    class func latestAlarmStatesUsingSavedUsernameAndPassword()->NSMutableDictionary {
        var results = NSMutableDictionary()
        var userdata = raxutils.getUserdata()
        if userdata == nil {
            results["error"] = "Userdata hasn't been saved in host iOS app"
            return results
        }
        var username = (NSKeyedUnarchiver.unarchiveObjectWithData(userdata) as! NSMutableDictionary!).objectForKey("access")!.objectForKey("user")!.objectForKey("name")! as! String
        var password:String! = raxutils.getPasswordFromKeychain()
        if password == nil {
            results["error"] = "Password wasn't saved in host iOS app."
            return results
        }
        var url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        var postdata = raxutils.dictionaryToJSONstring(
            ["auth": [
                "passwordCredentials":[
                    "username": username,
                    "password": password
                ]
            ]])
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            results["error"] = "Couldn't get service catalog."
            results["response"] = resp
            return results
        }
        var serviceCatalog = (NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!)
        GlobalState.instance.authtoken = serviceCatalog.objectForKey("access")!.objectForKey("token")!.objectForKey("id")! as! String
        for obj in (serviceCatalog.objectForKey("access")!.objectForKey("serviceCatalog")! as! NSArray) {
            if(obj.objectForKey("name")!.isEqualToString("cloudMonitoring")) {
                GlobalState.instance.monitoringEndpoint = (obj.objectForKey("endpoints") as! NSArray)[0].objectForKey("publicURL") as! String
                break
            }
        }
        results["latestAlarmStates"] = latestAlarmStates()
        return results
    }
    
    
    //TODO: This function is not actually used in the App right now.
    //Maybe add some UI to display the data from this function later?
    class func getAlarmHistory(alarm:NSDictionary) -> NSArray! {
        var ahistoricAlerts:NSMutableArray = NSMutableArray()
        var entityID:String = alarm["entity_id"] as! String
        var checkID:String = alarm["check_id"] as! String
        var alarmID:String = alarm["alarm_id"] as! String
        var url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID+"/notification_history/"+checkID
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        var jsonData = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for alert in jsonData["values"] as! NSArray {
            ahistoricAlerts.addObject(alert as! NSDictionary)
        }
        return ahistoricAlerts.copy() as! NSArray
    }
    
    class func getAlarmChangelogs(entityID:String!=nil) -> NSArray! {
        var changeLogs:NSMutableArray = NSMutableArray()
        var url = GlobalState.instance.monitoringEndpoint+"/changelogs/alarms/?"
        if entityID != nil {
            url += "entityId="+entityID+"&limit=1000"
        } else {
            url += "limit=1000"
        }
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        var jsonData = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for changelog in jsonData["values"] as! NSArray {
            changeLogs.addObject(changelog as! NSDictionary)
        }
        return changeLogs.copy() as! NSArray
    }
    
    class func refreshUserData(funcptr:(response: NSURLResponse!, data: NSData!, error: NSError!) -> Void) {
        var url = "https://identity.api.rackspacecloud.com/v2.0/tokens"
        var tenantID = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String
        var authtoken = GlobalState.instance.userdata.objectForKey("access")!.objectForKey("token")!.objectForKey("id")! as! String
        var postdata = raxutils.dictionaryToJSONstring(
        ["auth": [
            "tenantId": tenantID,
            "token": [
                "id": authtoken
            ]
        ]])
        NSURLConnection.sendAsynchronousRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
            queue: NSOperationQueue(), completionHandler: funcptr)
    }
    
    class func latestAlarmStates(isStreaming:Bool=false, updateGlobal:Bool=true) -> NSMutableDictionary! {
        var results = NSMutableDictionary()
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
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var severity = ""
        var alarmstatelist:NSArray! = nil
        var alarmState:String = ""
        var allCriticalAlarms:NSMutableArray = NSMutableArray()
        var allWarningAlarms:NSMutableArray = NSMutableArray()
        var allOkAlarms:NSMutableArray = NSMutableArray()
        var allUnknownAlarms:NSMutableArray = NSMutableArray()
        var allAlarmsFoundOnEntity:NSMutableArray = NSMutableArray()
        
        var criticalAlarms:NSMutableArray = NSMutableArray()
        var warningAlarms:NSMutableArray = NSMutableArray()
        var okAlarms:NSMutableArray = NSMutableArray()
        var unknownAlarms:NSMutableArray = NSMutableArray()
        
        var allEntities = NSMutableArray()
        var okEntities = NSMutableArray()
        var warningEntities = NSMutableArray()
        var criticalEntities = NSMutableArray()
        var unknownEntities = NSMutableArray()
        
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)

        if(nsdata == nil || resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200  ) {
            return nil
        }
        var jsonData = NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        if jsonData == nil {
            return nil
        }
        for entity in (jsonData.objectForKey("values") as! NSArray) {
            criticalAlarms.removeAllObjects()
            warningAlarms.removeAllObjects()
            okAlarms.removeAllObjects()
            unknownAlarms.removeAllObjects()
            allAlarmsFoundOnEntity.removeAllObjects()
            severity = ""
            alarmstatelist = (entity as! NSDictionary).objectForKey("latest_alarm_states") as! NSArray
            if(alarmstatelist.count == 0) {
                continue
            }
            for event in alarmstatelist {
                severity += ":"
                alarmState = (event.objectForKey("state") as! String).lowercaseString
                severity += alarmState
                if(alarmState.rangeOfString("ok") != nil) {
                    event.setObject(UIColor(red: 0, green: 0.5, blue: 0, alpha: 1), forKey: "UIColor")
                    okAlarms.addObject(event)
                    allOkAlarms.addObject(event)
                } else if(alarmState.rangeOfString("warning") != nil) {
                    event.setObject(UIColor.orangeColor(), forKey: "UIColor")
                    warningAlarms.addObject(event)
                    allWarningAlarms.addObject(event)
                } else if(alarmState.rangeOfString("critical") != nil) {
                    event.setObject(UIColor.redColor(), forKey: "UIColor")
                    allCriticalAlarms.addObject(event)
                    criticalAlarms.addObject(event)
                } else {//This alarm is in a state that we don't know about.
                    event.setObject(UIColor.blueColor(), forKey: "UIColor")
                    unknownAlarms.addObject(event)
                    allUnknownAlarms.addObject(event)
                }
                allAlarmsFoundOnEntity.addObject(event)
            }
            entity.setObject(raxutils.sortAlarmsBySeverityThenTime(allAlarmsFoundOnEntity), forKey:"allAlarms")
            entity.setObject(criticalAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "criticalAlarms")
            entity.setObject(warningAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "warningAlarms")
            entity.setObject(okAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "okAlarms")
            entity.setObject(unknownAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents), forKey: "unknownAlarms")
            if(unknownAlarms.count > 0 ) {
                entity.setValue("????", forKey: "state")
                unknownEntities.addObject(entity)
            } else if(severity.rangeOfString(":critical") != nil) {
                entity.setValue("CRIT", forKey: "state")
                criticalEntities.addObject(entity)
            } else if(severity.rangeOfString(":warning") != nil) {
                warningEntities.addObject(entity)
                entity.setValue("WARN", forKey: "state")
            } else {
                entity.setValue("OK", forKey: "state")
                okEntities.addObject(entity)
            }
            allEntities.addObject(entity)
        }
        unknownEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(unknownEntities))
        criticalEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(criticalEntities))
        warningEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(warningEntities))
        okEntities = NSMutableArray(array: raxutils.sortEntitiesAndTheirEvents(okEntities))
        allCriticalAlarms = NSMutableArray(array: allCriticalAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allWarningAlarms = NSMutableArray(array: allWarningAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allOkAlarms = NSMutableArray(array: allOkAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        allUnknownAlarms = NSMutableArray(array: allUnknownAlarms.sortedArrayUsingComparator(raxutils.compareAlarmEvents))
        results["allEntities"] = raxutils.sortEntitiesBySeverityThenTime(allEntities)
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
        var url = "https://mycloud.rackspace.com/proxy/rax:monitor,cloudMonitoring/views/agent_host_info/?include=memory&include=system&include=cpus&include=filesystems&agentId="+agentID+"&sampleCpus=true"
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
    
    class func getSupportedAgentInfoTypes(agentID:String) -> NSDictionary! {
        var url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info_types"
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
    
    class func getAgentInfoByType(agentID:String, type:String) -> NSDictionary! {
        var url = GlobalState.instance.monitoringEndpoint+"/agents/"+agentID+"/host_info/"+type
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
    
    class func getEntity(entityID:String) -> NSDictionary! {
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
 
    class func getCheck(entityid:String, checkid:String) -> NSDictionary! {
        var nsdata:NSData!
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/checks/"+checkid
        nsdata = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
    
    class func getAlarm(entityID:String, alarmID:String) -> NSMutableDictionary! {
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityID+"/alarms/"+alarmID
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSMutableDictionary!
    }
    
    class func getNotificationPlan(np_id:String) -> NSDictionary! {
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url = GlobalState.instance.monitoringEndpoint+"/notification_plans/"+np_id
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(nsdata, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
    }
    
    class func test_check_or_alarm(entityid:String, postdata:String, targetType:String) -> NSData! {
        var nsdata:NSData!
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url = GlobalState.instance.monitoringEndpoint+"/entities/"+entityid+"/test-"+targetType
        nsdata = NSURLConnection.sendSynchronousRequest(self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            nsdata = nil
        }
        return nsdata
    }
    
    class func extend_session(reason:String="") -> String! {
        var responseBody:String! = nil
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var url:String = "https://mycloud.rackspace.com/cloud/"
        var data:NSData! = nil
        url.extend(GlobalState.instance.userdata.objectForKey("access")!
            .objectForKey("token")!.objectForKey("tenant")!.objectForKey("id")! as! String)
        url.extend("/extend_session?window_hash=rackyview_iOSapp&reason="+reason)
        data = NSURLConnection.sendSynchronousRequest(
            self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: "text/html; charset=utf-8")!,
            returningResponse:&resp, error:&err)
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            responseBody = NSString(data: data, encoding: NSUTF8StringEncoding) as String!
        }
        return responseBody
    }
    
    class func _doProxyRequest(url:String) -> NSData! {
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var data:NSData! = NSURLConnection.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
        returningResponse: &resp, error: &err)
        if(resp == nil || (resp as! NSHTTPURLResponse).statusCode != 200 ) {
            data = nil
        }
        return data
    }
    
    class func getServerFlavor(server:NSDictionary) -> NSDictionary! {
        var flavor:NSDictionary! = nil
        var url:String = server["APIendpoint"] as! NSString as String
        url.extend("/flavors/")
        url.extend(((server["server"] as! NSDictionary)["flavor"] as! NSDictionary)["id"] as! NSString as String)
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var data:NSData! = NSURLConnection.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            flavor = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        }
        return flavor
    }
    
    class func getServerImage(server:NSDictionary) -> NSDictionary! {
        var image:NSDictionary!
        var url:String = server["APIendpoint"] as! NSString as String
        url.extend("/images/")
        url.extend(((server["server"] as! NSDictionary)["image"] as! NSDictionary)["id"] as! NSString as String)
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var data:NSData! = NSURLConnection.sendSynchronousRequest(_createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
            returningResponse: &resp, error: &err)
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 200 ) {
            image = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
        }
        return image
    }
    
    class func serveraction(server:NSDictionary, postdata:String, funcptr:(response: NSURLResponse!, data: NSData!, error: NSError!) -> Void) {
        var url:String = server["APIendpoint"] as! NSString as String
        url.extend("/servers/")
        url.extend((server["server"] as! NSDictionary)["id"] as! NSString as String)
        url.extend("/action")
        NSURLConnection.sendAsynchronousRequest(_createRequest("POST", url: url, data: postdata, qparams: nil, content_type: nil)!,
            queue: NSOperationQueue(), completionHandler: funcptr)
    }
    
    
    class func get_tickets_summary () -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/summary")
    }
    
    class func get_tickets_by_status(t_status:String) -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets?status="+t_status)
    }
    
    class func get_ticket_details(t_id:String) -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id)
    }
    
    class func get_ticket_categories() -> NSData! {
        return _doProxyRequest("https://mycloud.rackspace.com/proxy/rax:tickets,tickets/ticket-categories")
    }
    
    
    class func createTicket(primaryCategoryName:String,primaryCategoryID:String,subCategoryName:String,subCategoryID:String,ticketSubject:String,ticketMessageBody:String) -> String! {
        var url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets"
        var newTicketID:String!
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring(
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
        ]]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var data:NSData! = NSURLConnection.sendSynchronousRequest(_createRequest("POST", url: url, data:postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!,returningResponse: &resp, error: &err)
        if(resp != nil && (resp as! NSHTTPURLResponse).statusCode == 201 ) {
            var locationHeader:String! = (resp as? NSHTTPURLResponse)?.allHeaderFields["Location"] as? String
            let range = NSRegularExpression(pattern:"/v1/tickets/(\\S+)", options:nil, error:nil)!.firstMatchInString(locationHeader, options: nil, range: NSMakeRange(0, locationHeader.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))?.rangeAtIndex(1)
            newTicketID = (locationHeader as NSString).substringWithRange(NSMakeRange((range?.location)!, (range?.length)!))
        }
        return newTicketID
    }
    
    class func submitTicketComment(t_id:String,commentText:String, funcptr:(response: NSURLResponse!, data: NSData!, error: NSError!) -> Void) {
        var url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/comments"
        var postdata = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken
        postdata += "&data="
        postdata += raxutils.dictionaryToJSONstring([
            "comment": [
                "type": "TextCommentForCreateType",
                "text": commentText
            ]
        ]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        NSURLConnection.sendAsynchronousRequest(
          self._createRequest("POST", url: url, data: postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=utf-8")!,queue: NSOperationQueue(), completionHandler: funcptr)
    }
    
    class func closeTicket(t_id:String, rating:Int, comment:String) -> Int {
        var url:String = "https://mycloud.rackspace.com/proxy/rax:tickets,tickets/tickets/"+t_id+"/close"
        var responseCode:Int = 0
        var postdata:String = "csrfmiddlewaretoken="
        postdata += GlobalState.instance.csrftoken+"&data="
        postdata += raxutils.dictionaryToJSONstring(
            ["ticket-rating": [
                "rating":String(rating),
                "comment": [
                    "text":comment
                ]
            ]
        ]).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
        var resp:NSURLResponse? = nil
        var err:NSError? = nil
        var nsdata:NSData! = NSURLConnection.sendSynchronousRequest(_createRequest("PUT", url: url, data:postdata, qparams: nil, content_type: "application/x-www-form-urlencoded;charset=UTF-8")!,returningResponse: &resp, error: &err)
        if(resp != nil) {
            responseCode = (resp as! NSHTTPURLResponse).statusCode
        }
        return responseCode
    }
    
    class func listServerDetails( funcptr:(servers:NSArray,errors:NSArray)->Void ){
        var serverlist:NSMutableArray = NSMutableArray()
        var errorlist:NSMutableArray = NSMutableArray()
        var q = NSOperationQueue()
        q.maxConcurrentOperationCount = 1
        q.suspended = true
        for ep in GlobalState.instance.serverEndpoints {
            q.addOperationWithBlock {
                var url = String(ep.objectForKey("publicURL") as! NSString)+"/servers/detail"
                var resp:NSURLResponse? = nil
                var err:NSError? = nil
                var data:NSData! = NSURLConnection.sendSynchronousRequest(self._createRequest("GET", url: url, data: nil, qparams: nil, content_type: nil)!,
                    returningResponse: &resp, error: &err)
                if err != nil {
                    errorlist.addObject(err!)
                }
                if(data == nil) {
                    return
                }
                var serverdata:NSDictionary! = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary!
                if(serverdata == nil) {
                    return
                }
                var dentry:NSMutableDictionary!
                for s in serverdata.objectForKey("servers") as! NSArray {
                    dentry = NSMutableDictionary()
                    dentry.setValue(ep.objectForKey("region") as! String, forKeyPath: "region")
                    dentry.setValue(s, forKeyPath: "server")
                    dentry.setValue(ep.objectForKey("publicURL") as! NSString, forKeyPath: "APIendpoint")
                    serverlist.addObject(dentry)
                }
            }
        }
        q.suspended = false
        q.waitUntilAllOperationsAreFinished()
        funcptr(servers:serverlist.copy() as! NSArray,errors:errorlist.copy() as! NSArray)
    }
}