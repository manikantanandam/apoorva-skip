# CI: selective module testing

- **Decision:** PRs run tests only for changed `libraries/*` modules plus their transitive dependents; pushes to `main` run all modules.
- **Why:** running every module on every PR wastes time. Path filters alone are unsafe because modules depend on each other (e.g. a `ApoorvaModels` change affects Services, OfflineStorage, Repository, Modules, AppCore).
- **How:** `scripts/changed-modules.sh <base> <head>` diffs files, maps to modules, expands reverse dependents via `.package(path: "../X")` (same grep as `deps_of` in `scripts/build.sh`). Used by `detect-modules` in `.github/workflows/ci.yml`.
- **Run ALL when:** `.github/`, `scripts/`, or `sonar-project.properties` change, or no usable base SHA (push to main).
- **Sonar:** scan job runs only if the test matrix succeeded; on PRs it sees coverage only for affected modules. Main push keeps the full baseline.
- **AppCore CI crash (PR 79):** `OfflineStorageContainer` hit `fatalError` (SQLite code 14, CANTOPEN) because the Documents dir didn't exist on the CI runner; fixed by creating the DB's parent directory before opening.
- **Caveat:** if `build-and-test` is a required status check, an empty/skipped matrix may block merges; add an always-run gate job if so.
