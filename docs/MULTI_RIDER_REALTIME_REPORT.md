# Multi-rider realtime report

Date: 2026-11-01

Reviewed ride creation/join/start/end services, membership approval, active
session recovery, location upserts, realtime reconnect, leader identity,
leave/cleanup paths, bounded queueing and group-health transitions.

Automated coverage verifies active-ride selection, stale/offline status logic,
accuracy-aware separation, category persistence and legacy alert compatibility.
Database migrations use unique membership/location constraints, JWT-bound
identity and transactional join functions to reduce duplicate/concurrent state.

Normal group ride, network loss, force-close, late join, leader unavailable,
leave/revocation and concurrent operations were not executed with multiple real
accounts because staging credentials/devices are unavailable. These scenarios
remain **NOT VERIFIED**, not passed.
