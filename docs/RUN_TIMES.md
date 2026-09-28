# Run times

How long the release gates take, so future work can be planned and judged (owner request,
2026-09-28). Every run gets its own timestamped log that is never reused. Times are wall clock
in the cloud work container (4 CPU cores, software rendering; runs in parallel where marked).
CI times come from GitHub Actions.

| Date (UTC) | Release | Gate | Start | End | Took | Result | Notes |
|---|---|---|---|---|---|---|---|
| 2026-09-28 | dev-000025 (in progress) | Full unit suite | 20:56:16 | 21:02:02 | 5 min 46 s | 389/390 (naming rule; fixed in `8c07efb`) | in parallel with both playthroughs |
| 2026-09-28 | dev-000025 (in progress) | Playthrough seed 7, to 100% | 20:56:16 | 21:01:59 | 5 min 43 s | 23/23 | in parallel; bot game time about 2,500 s |
| 2026-09-28 | dev-000025 (in progress) | Playthrough seed 4242, to 100% | 20:56:16 | 21:01:17 | 5 min 01 s | 23/23 | in parallel |
