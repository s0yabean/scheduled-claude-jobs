---
name: dependency-digest
description: Weekly digest of new releases and notable news for a list of packages, written to a markdown file. Read-only.
---

# dependency-digest (example skill)

Input: a watchlist file, one `<ecosystem> <name>` per line (lines starting with `#` are comments).

For each package:

1. Look up the latest version on its registry (npm or PyPI) and the release notes since the version
   recorded in the newest ledger.
2. Skip any release already in the ledger.
3. Note breaking changes, security advisories and deprecations. Ignore routine patch releases.

Output `digests/weekly-dependency-digest/<YYYY-MM-DD>.md`:

- **Act on this week**: breaking changes or advisories, one line each with a link.
- **Worth knowing**: notable features or deprecations.
- **Nothing new**: packages with no release since the last run.

Write the updated ledger as described in the job file. Keep total paid API spend under the job's cap
and report what was spent. Never open issues or PRs.
