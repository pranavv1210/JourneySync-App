# Landing page QA

Date: 2026-11-01

The production build was captured at 320, 360, 375, 390, 414, 430, 768, 1024
and 1440 CSS pixels using headless Chrome 156. The QA script asserts the exact
viewport width and fails when `documentElement.scrollWidth > innerWidth`.

All nine widths: **PASS**, no horizontal overflow. Mobile menu visibility was
confirmed at 320–1024 px, desktop navigation at 1440 px, and an opened 320 px
menu screenshot was captured. Visual inspection covered 320, 768 and 1440 hero
layouts plus the mobile menu. The 320 px clipping defect was corrected.

Evidence: `docs/qa/v1.11.0/landing-*.png`, `landing-320-menu.png`, and
`responsive-results.json`. The script is reproducible with
`npm run qa:responsive` against Chrome remote debugging port 9222.

Lint has zero warnings. Production build routes `/`, `/_not-found`, and
`/beta/download` compile successfully. Live deployed navigation and APK are
verified by the release workflow after push.
