# Get Help verification report

Date: 2026-11-01

## Verified in source and automated tests

- Accident/medical, breakdown, separated and general assistance categories.
- Category survives initial send and host group broadcast.
- Legacy generic SOS records map to general assistance.
- Active Ride and notification details use Get Help terminology.
- Notification details consume the actual alert payload or latest authorised
  ride alert, show the category/timestamp/location, and report loading failures.
- Cancellation uses the shared realtime `safe` event and leaves the alert live
  when cancellation fails.
- 112 opens the external dialler and is described as opening a dialler, not
  confirming a completed call or emergency dispatch.
- No automatic crash detection or dispatch claim remains on the landing page.

Actual dial placement, push delivery, multiple-device acknowledgement and
offline retry are **NOT VERIFIED** without devices and staging accounts.
