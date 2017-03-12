import EventKit
import NotificationCenter

let eventStore = EKEventStore()

class Synchronizer {
    
    var privateCalendar: EKCalendar
    var officeCalendar: EKCalendar
    
    let daysToSynchronize = 2
    
    @objc func storeChanged() {
        print("Changed!")
        
    }
   
 
    init() {
	guard #available(macOS 10.12, *) else {
		fatalError("Macos sierra is supported!")
	}

        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".calendarsync.json")
        guard let data = try? Data(contentsOf: path) else {
            print("Cannot read ~/.calendarsync.json. Choose privateCalendar and officeCalendar from list: ")
            eventStore.calendars(for: .event).forEach({ (calendar) in
                print(calendar.title, calendar.calendarIdentifier)
            })
            exit(3)
            
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data)  else {
            print("Can't read ~/.calendarsync.json")
	    exit(4)
        }
        
        if  let json = json as? [String: Any]  {
            if let privateId = json["privateCalendar"] as? String,
                let officeId = json["officeCalendar"] as? String {
                self.privateCalendar =  eventStore.calendar(withIdentifier: privateId)!
                self.officeCalendar = eventStore.calendar(withIdentifier: officeId)!
                return
            }
        }
        
        print("privateCalendar and officeCalendar have to be set to calendar ID's. For example: 1BA1FFED-17F7-48D1-BA07-3D207D8C5C12")
	exit(5)
    }
    
    func register() {
        NotificationCenter.default.addObserver(self, selector: #selector(Synchronizer.storeChanged), name: NSNotification.Name.EKEventStoreChanged, object: nil)

    }
    
    func getLastEvents(calendar: EKCalendar) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: Date(),
            end: Date().addingTimeInterval(TimeInterval(daysToSynchronize*60*60*24)), calendars: [calendar])
        return eventStore.events(matching: predicate)
        
    }
    
    func printCalendars() {
        eventStore.calendars(for: .event).forEach({ (calendar) in
            print(calendar.title, calendar.calendarIdentifier)
        })
    }
    
    
    func deleteAllEvents() {
        let events = getLastEvents(calendar: privateCalendar)
        events.forEach {
            try? eventStore.remove($0, span: .thisEvent, commit: true)
        }
    }
    
    
    func start() {
        
        if(self.privateCalendar.source.title != "iCloud") {
            print("Private calendar should be iCloud!")
	    exit(7)
        }
        print(Date().addingTimeInterval(TimeInterval(-60*60*24*30)))
        copyOfficeEvents()
        removePrivateEventsWithoutOfficeEvents()
    }
    
    func copyOfficeEvents() {
        
        let officeEvents = getLastEvents(calendar: officeCalendar)
        for event in officeEvents {
            print(event.title)
            let alreadySyncedEvent =  eventStore.events(matching: eventStore.predicateForEvents(withStart: event.startDate, end: event.endDate, calendars: [privateCalendar]))
            
            guard  (alreadySyncedEvent.filter {
                $0.title == event.title
                }.count == 0 ) else {
                    print("Already synchronized: \(event.title). Skipping.")
                    continue
            }
            
            
            let newevent = EKEvent(eventStore: eventStore)
            newevent.startDate = event.startDate
            newevent.endDate = event.endDate
            newevent.title = event.title
            newevent.location = event.location
            newevent.isAllDay = event.isAllDay
            newevent.calendar = privateCalendar
            
            let x = "\(newevent.attendees)"
            newevent.notes = "\(event.notes ?? "") Attendees: " + x
            print("Add: \(newevent.title)")
            try? eventStore.save(newevent, span: .thisEvent, commit: true)
        }
    }
    
    
    func removePrivateEventsWithoutOfficeEvents() {
        let privateEvents = self.getLastEvents(calendar: privateCalendar)
        for event in privateEvents {
            print(event.title)
            let officeExisting =  eventStore.events(matching: eventStore.predicateForEvents(withStart: event.startDate, end: event.endDate, calendars: [officeCalendar]))
            
            
            let existing = officeExisting.filter {
                $0.title == event.title
            }
            
            if existing.count == 0 {
                print("Removing \(event.title)!")
                try? eventStore.remove(event, span: .thisEvent, commit: true)
            }
        }
    }
}

func checkCalendarAuthorizationStatus() {
    let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
    
    switch (status) {
    case EKAuthorizationStatus.notDetermined:
        
        requestAccessToCalendar()
        
    case EKAuthorizationStatus.authorized:
        
        let s = Synchronizer()
        s.register()
        
        s.start()
        print("Done.")
        
        
    case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
        // We need to help them give us permission
        print("Denied")
    }
}

func requestAccessToCalendar() {
    eventStore.requestAccess(to: EKEntityType.event, completion: {
        (accessGranted: Bool, error: Error?) in
        
        if accessGranted == true {
            print("Granted")
        } else {
            print("Need permissions")
        }
    })
}

print("Checking access")
checkCalendarAuthorizationStatus()
print("Done")

