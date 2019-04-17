import EventKit
import NotificationCenter

let eventStore = EKEventStore()


public struct Config: Codable {
    var privateCalendar: String
    var officeCalendar: String
    var daysToSync: Int?
}

class Synchronizer {
    var privateCalendar: EKCalendar
    var officeCalendar: EKCalendar

    var daysToSynchronize = 10

    @objc func storeChanged() {
        print("Changed!")
    }

    init() {
        guard #available(macOS 10.12, *) else {
            fatalError("Macos Sierra is required!")
        }

        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".calendarsync.json")
        guard let data = try? Data(contentsOf: path) else {
            print("Cannot read ~/.calendarsync.json. Choose privateCalendar and officeCalendar from list: ")
            eventStore.calendars(for: .event).forEach({ calendar in
                print(calendar.title, calendar.calendarIdentifier)
            })
            exit(3)
        }

        let coder = JSONDecoder()

        let entry = try! coder.decode(Config.self, from: data)
        if let days = entry.daysToSync {
            self.daysToSynchronize = days
        }

        guard let privateCalendar = eventStore.calendar(withIdentifier: entry.privateCalendar) else {
            print("Unknown calendar: \(entry.privateCalendar)")
            exit(3)
        }
        self.privateCalendar = privateCalendar
        guard let officeCalendar = eventStore.calendar(withIdentifier: entry.officeCalendar) else {
            print("Unknown calendar: \(entry.officeCalendar)")
            exit(3)
        }
        self.officeCalendar = officeCalendar
    }

    func register() {
        NotificationCenter.default.addObserver(self, selector: #selector(Synchronizer.storeChanged), name: NSNotification.Name.EKEventStoreChanged, object: nil)
    }

    func getLastEvents(calendar: EKCalendar) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: Date(),
            end: Date().addingTimeInterval(TimeInterval(daysToSynchronize * 60 * 60 * 24)), calendars: [calendar]
        )
        return eventStore.events(matching: predicate)
    }

    func printCalendars() {
        eventStore.calendars(for: .event).forEach({ calendar in
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
        if privateCalendar.source.title != "iCloud" {
            print("Private calendar should be iCloud!")
            exit(7)
        }
        print(Date().addingTimeInterval(TimeInterval(-60 * 60 * 24 * 30)))
        copyOfficeEvents()
        removePrivateEventsWithoutOfficeEvents()
    }

    func copyOfficeEvents() {
        let officeEvents = getLastEvents(calendar: officeCalendar)
        for event in officeEvents {
            print(event.title ?? "no title")
            let alreadySyncedEvent = eventStore.events(matching: eventStore.predicateForEvents(withStart: event.startDate, end: event.endDate, calendars: [privateCalendar]))

            guard (alreadySyncedEvent.filter {
                $0.title == event.title
            }.count == 0) else {
                print("Already synchronized: \(event.title ?? "no title"). Skipping.")
                continue
            }

            let newevent = EKEvent(eventStore: eventStore)
            newevent.startDate = event.startDate
            newevent.endDate = event.endDate
            newevent.title = event.title
            newevent.location = event.location
            newevent.isAllDay = event.isAllDay
            newevent.calendar = privateCalendar

            let x = "\(String(describing: newevent.attendees))"
            newevent.notes = "\(event.notes ?? "") Attendees: " + x
            print("Add: \(String(describing: newevent.title))")
            try? eventStore.save(newevent, span: .thisEvent, commit: true)
        }
    }

    func removePrivateEventsWithoutOfficeEvents() {
        let privateEvents = getLastEvents(calendar: privateCalendar)
        for event in privateEvents {
            print(event.title ?? "no title")
            let officeExisting = eventStore.events(matching: eventStore.predicateForEvents(withStart: event.startDate, end: event.endDate, calendars: [officeCalendar]))

            let existing = officeExisting.filter {
                $0.title == event.title
            }

            if existing.count == 0 {
                print("Removing \(String(describing: event.title))!")
                try? eventStore.remove(event, span: .thisEvent, commit: true)
            }
        }
    }
}

func checkCalendarAuthorizationStatus() {
    let status = EKEventStore.authorizationStatus(for: EKEntityType.event)

    switch status {
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
        (accessGranted: Bool, _: Error?) in

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
