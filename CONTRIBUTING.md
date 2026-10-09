# Contributing

1. Open an issue describing the change before large work.
2. Fork, branch from `main` (`feat/…`, `fix/…`), keep diffs small and scoped.
3. Scripts must stay idempotent, `set -euo pipefail`, and pass `bash -n`.
   Never require more privilege than the step needs (apt only).
4. Test on Ubuntu 24.04 + macOS and note results in the PR.
5. One concern per PR.
