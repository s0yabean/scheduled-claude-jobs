# weekly-dependency-digest

- **Cadence:** weekly (Monday 08:00 local)
- **Runner:** Claude Code cloud routine (runs with the laptop closed)
- **Skill:** `dependency-digest` (checked out fresh from the skills repo by `scripts/bootstrap.sh`)
- **Spend cap:** set one per job, in the skill and in any paid API it calls. Example: $0.50 per run.
- **Needs:** this repo attached to the routine, network access to the package registries and
  release-note sites it reads, `SKILLS_REPO_URL` (and `SKILLS_REPO_TOKEN` if private) as routine secrets.

## Routine prompt

```
Run `SKILLS="dependency-digest" bash scripts/bootstrap.sh` first and stop if it fails.
Then run the dependency-digest skill exactly as its SKILL.md describes, for the manifests listed in
jobs/weekly-dependency-digest.watchlist.txt.
Memory between runs: read the newest ledgers/weekly-dependency-digest-ledger-*.md (none = first run),
skip any release already in it, and write the FULL updated ledger to a NEW file
ledgers/weekly-dependency-digest-ledger-<YYYY-MM-DD>.md. Never edit or delete an older ledger.
Write the digest to digests/weekly-dependency-digest/<YYYY-MM-DD>.md.
Read-only: never open issues, PRs or comments, never bump a dependency.
Finish with a short log at runs/weekly-dependency-digest/<YYYY-MM-DD>.md
(what ran, counts, spend, where results went), then commit digests/, ledgers/ and runs/ to a branch.
```

## Notes

- A cloud run starts on a fresh machine. Anything it learned last week is gone unless it is in a
  file the next run can read, which is what the dated ledger is for.
- Every output file name ends in `.md`, so notes apps that only index markdown can see it.
- Run it once by hand from the routine page and read the full log before turning the schedule on.
