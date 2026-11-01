# Performance audit

Date: 2026-11-01

Flutter tracking uses bounded queues, upserts, adaptive sync intervals, capped
position prediction, stream cancellation and channel teardown. v1.11.0 adds one
numeric accuracy field without increasing request count. Group health filters
poor fixes before expensive false-alert workflows.

Landing local images now use `next/image` for responsive sizing, lazy loading
and layout stability. The runtime QR remains an external generated image and is
explicitly exempted from optimisation. ESLint warnings fell from eight to zero.

No profiler, battery historian, Lighthouse lab run or long-duration memory
trace was available; those measurements remain NOT VERIFIED. The release APK
size and build output are recorded after the signed build.

Release automation also suppresses Gradle command echoing when a developer
machine has `DEBUG` set, preventing encoded configuration from entering logs.
