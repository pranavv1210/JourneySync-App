# Real-device tracking report

Date: 2026-11-01

## Implementation evidence

- Foreground service and Android location service types are declared.
- Tracking has adaptive moving/stationary/emergency intervals, bounded persisted
  offline queuing, upsert identity, reconnect, cleanup and session restoration.
- v1.11.0 now uploads and parses horizontal GPS accuracy.
- Poor fixes over 100 m are marked weak and cannot independently trigger a
  rider-separation alert.

## Automated evidence

Group-intelligence tests confirm that a fresh 180 m accuracy fix does not raise
separation and a fresh accurate fix beyond 1.8 km does. Flutter analysis and the
complete unit/widget suite are release gates.

## Physical devices

No physical Android device is attached. Foreground, screen-lock, background,
force-close, reboot, GPS/network loss and recovery, battery saver, permission
revocation, low-battery and prolonged-session scenarios are **NOT VERIFIED**.
No manufacturer names or device results are claimed.
