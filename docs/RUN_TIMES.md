# Run times

How long the release gates take, so future work can be planned and judged (owner request,
2026-09-28). Every run gets its own timestamped log that is never reused. Times are wall clock
in the cloud work container (4 CPU cores, software rendering; runs in parallel where marked).
CI times come from GitHub Actions.

| Date (UTC) | Release | Gate | Start | End | Took | Result | Notes |
|---|---|---|---|---|---|---|---|
| 2026-09-28 | dev-000025 | Full unit suite | 20:56:16 | 21:02:02 | 5 min 46 s | 389/390 (naming rule; fixed in `8c07efb`) | in parallel with both playthroughs |
| 2026-09-28 | dev-000025 | Playthrough seed 7, to 100% | 20:56:16 | 21:01:59 | 5 min 43 s | 23/23 | in parallel; bot game time about 2,500 s |
| 2026-09-28 | dev-000025 | Playthrough seed 4242, to 100% | 20:56:16 | 21:01:17 | 5 min 01 s | 23/23 | in parallel |
| 2026-09-28 | dev-000025 | Full unit suite (final code) | 21:02:44 | 21:08:31 | 5 min 47 s | 390/390 | |
| 2026-09-28 | dev-000025 | Version drift | 21:07:37 | 21:07:56 | 19 s | pass | |
| 2026-09-28 | dev-000025 | OTA end-to-end (local) | 21:07:56 | 21:17:28 | 9 min 32 s | 42/42 | includes an offline playthrough |
| 2026-09-28 | dev-000025 | Performance views (15) | 21:17:50 | 21:22:11 | 4 min 21 s | within noise of dev-000024 | nothing else running |
| 2026-09-28 | expansion prep | Read-only world architecture audit | — | — | 5 min 17 s | brief | background agent |
| 2026-09-28 | dev-000025 | CI Build & Verify #33 (PR) | 21:22:53 | about 21:32 | about 10 min | green; APK job skipped | GitHub Actions |
| 2026-09-28 | dev-000025 | OTA publish #25 (push) | 21:33:27 | 21:42:05 | 8 min 38 s | success | GitHub Actions: tests, export, sign, publish, re-verify, pointer |
| 2026-09-28 | dev-000025 | b22 client staging check | 21:42:47 | 21:42:50 | 3 s | staged, hash matches | |
| 2026-09-28 | dev-000025 | Tests run from the published pack | 21:42:58 | 21:43:15 | 17 s | 50/50 | |

**Planning figures (dev-000025):**
- Local gates in parallel, about 6 min: unit suite plus both playthroughs.
- OTA end-to-end: about 10 min.
- Performance: about 4–5 min per sample.
- CI: about 10 min.
- Publish: about 9 min.
- From a validated commit to a verified, published OTA: about 20–25 min.
