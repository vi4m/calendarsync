# calendarsync

This is a quick & dirty calendar synchronization script. 

It simply copies all events from one iCal calendar to another, for given time period. 
Why? 
I created this script to help me transfer business calendars events to my shiny Apple Watch Series 2. 

## Installation

	brew install vi4m/repo/calendarsync
	
## Setup 


1. Create new iCloud calendar using iCal app. Name it somehow. 
2. Run app. When run the first time, it will dump all calendars ID's. Your newly created iCloud cal will hold all copied business events. 
3. Create ~/.calendarsync.json similar to: 

```
	{
		"privateCalendar": "1BA1FFED-17F7-48D1-BA07-3D207D8C5C16",
		"officeCalendar": "64362FAC-8DFF-485A-991B-B23B84D14D69"
	}
``` where officeCalendar is the ID of the calendar with all source business meetings. 
4. Launch program from console. It will show logs, and will copy all business meetings from next 2 days to your iCloud calendar.
