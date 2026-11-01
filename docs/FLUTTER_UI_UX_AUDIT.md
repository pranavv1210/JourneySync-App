# Flutter UI/UX audit

Date: 2026-11-01

Reviewed splash/authentication, profile, home, discovery, creation, planning,
lobby, Ride Mode, Get Help, notifications, history, settings, shared buttons,
dialogs, sheets, cards and navigation source.

v1.11.0 aligns visible safety terminology around Get Help, removes the legacy
“Rider Down” presentation, uses the existing JourneySync tokens/components, and
keeps failures actionable. Static analysis and rendering/widget tests pass.

No emulator or physical device was available for a complete screen/font-scale
screenshot matrix. Keyboard, TalkBack, large font, smallest-screen overflow and
all interactive states are therefore **NOT VERIFIED** visually.
