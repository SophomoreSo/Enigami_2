# Continuous integration

One workflow, [`workflows/ci.yml`](workflows/ci.yml), in one file on purpose:
"don't ship a red build" is then an edge in the job graph rather than a habit
people have to keep.

```
rules ─────┬──▶ build — Linux, Windows, Android ───┬──▶ release   (tags only)
           │                                       │
graphics ──┴──▶ build — macOS, iOS ─ ─ ─ ─ ─ ─ ─ ─ ┘   (on tags: opt-in)

module-split      runs alongside; gates nothing
```

A branch being worked on is not run here: it is tested at the desk with
`tests/run.sh` (below), and the workflow runs for what ships — a version tag.
A push to `master` does not start a run for now: master is tested at the desk
as it is merged. The **Run workflow** button (`workflow_dispatch`) is there for
the odd time a run of master or a branch is wanted anyway, and what the table
says of master is what a job does when it is run there by hand. Give a run
started by hand a title, so it can be told apart in the list, or it is named
by the branch and commit it ran on:

```
gh workflow run CI --ref master -f title="What this run is checking"
```

| Job | Runs on | What it is |
|---|---|---|
| **Rules tests** | `v*` tags | `tests/circuit`, `tests/feature`, `tests/story`, `tests/shared` under `--headless` |
| **Module split holds** | `v*` tags | the four graphics autoloads deleted, the circuit and rules tests run again |
| **Graphics tests** | `v*` tags | `tests/graphics` and `tests/mobile` under Xvfb, plus screenshots of every screen |
| **Build — Linux, Windows, Android** | `v*` tags, and master by hand | artifacts, kept 30 days |
| **Build — macOS, iOS** | master by hand; tags only if opted in | artifacts, kept 30 days — see below |
| **Release** | `v*` tags | whatever was built, zipped per platform, attached to a GitHub Release |

### Why Apple is opt-in for releases

The macOS/iOS job runs for **master** — by hand, while a push to master starts
no run — which is what keeps the macOS export honest. It does not run for a
**tag** unless the repository
variable `RELEASE_APPLE` is set to `true`.

The reason is that what it can produce today is an unsigned `.app` that
Gatekeeper refuses on anyone else's Mac, and an iOS step that skips itself for
want of a team id — nothing worth attaching to a release, at ten times the
runner cost of a Linux job. Set `RELEASE_APPLE` once there is a signing
identity to build with, and Apple rejoins the release with no other change.

The `release` job is written to tolerate that: a skipped dependency normally
skips whatever depends on it, so it guards with `!cancelled()` and then asks
only that the desktop build succeeded and the Apple build did not *fail*.
Skipped is fine; broken still stops the release.

## Two things had to change before any of this meant anything

**Every test exited 0, including the ones that failed.** All 34 scenes ended
`get_tree().quit()` with no argument, so the failure count lived only in the
printed `---- N failures ----` line and nothing acted on it. A CI job checking
exit status would have been green forever. They now end
`get_tree().quit(1 if fails > 0 else 0)`. `tests/shared/smoke.gd` had no counter
at all — it pushed errors and printed `---- complete ----` — so it grew a
`fail()` beside its `say()`, and now prints a count like everything else.

**A hanging test is not a failing test.** The graphics tests wait for a window;
under `--headless` they do not fail, they wait forever, and a CI job would sit
there until the six-hour ceiling. [`tests/run.sh`](../tests/run.sh) gives every
scene a deadline and calls the overrun a failure. It is the same runner you run
at your desk, which is the point — there is no separate CI-only path to drift.

## Running it the way CI does

```bash
tests/run.sh tests/circuit tests/feature tests/story tests/shared   # the headless half
tests/run.sh --display --exclude '*shot*' tests/graphics tests/mobile # needs a window
tests/run.sh --help
```

It reports `PASS`, `FAIL`, `TIMEOUT` or `QUARANTINE` per scene, writes a log per
scene to `.test-logs/`, and exits nonzero only if something not quarantined
failed.

## Quarantine

[`tests/quarantine.txt`](../tests/quarantine.txt) lists tests whose failure is
known and understood. They still run and still report — they just do not fail
the build, so one long-standing red does not train everyone to ignore the light.

## Two tests that read their surroundings

`editor_input_test` and `save_slot_test` both passed and failed on the same Mac
during this setup, depending on nothing more than where the mouse was sitting
and which window had the keyboard. Both have since passed on CI every time: a
virtual display has one window, no cursor and nothing to steal focus, which
makes it a *steadier* home for them than a desk. If either does go red for a
reason nobody can fix that day, the quarantine file is a one-line answer.

## The graphics runner needs a Korean font

`Loc.LANGUAGES["kor"]["fonts"]` names system faces to borrow Hangul from, so
playing in Korean builds a `SystemFont` over them — and every string measured
afterwards walks that chain. A bare GitHub runner has no CJK face for it to
resolve to, and `settings_pixel_test` took **217 seconds and then segfaulted**
at the moment it switches language. With `fonts-noto-cjk` installed it takes
six seconds and passes.

So `fonts-noto-cjk` in that job is load-bearing, not tidiness. A machine with
no Korean font is not a machine anyone plays on, and the step prints what
`fc-match` resolves to so the next person can see it did.

It is deliberately **not** installed for the rules job. `loc_test` is there to
prove the *bundled* faces spell everything unaided, and a system face would
quietly stand in for one that could not — which is the exact failure that test
exists to catch.

## Secrets

Nothing here is required for the tests. Each one unlocks a better build.

| Secret | Without it | With it |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | a debug-signed APK — installs for testing, and nothing else | a release APK signed for distribution |
| `ANDROID_KEYSTORE_PASSWORD` | — | the keystore's password |
| `ANDROID_KEYSTORE_USER` | — | the key alias |
| `APPLE_TEAM_ID` | the iOS job is skipped with a notice | an Xcode project, built and uploaded |

```bash
base64 -i release.keystore | pbcopy   # then paste as ANDROID_KEYSTORE_BASE64
```

## What these builds are and are not

- **Linux, Windows** — complete and runnable.
- **Android** — a real APK. Debug-signed unless the keystore secrets are set.
- **macOS** — unsigned. Gatekeeper will refuse it on anyone else's Mac until it
  is signed and notarised, which needs a Developer ID that is not in here.
- **iOS** — an *Xcode project*, not an `.ipa`. The preset sets
  `export_project_only`, because turning it into something installable needs a
  signing identity and a provisioning profile, and the exporter will not even
  start without a team id.

There is also a thing worth saying out loud about the two mobile targets: the
game is built for a keyboard and a mouse — LMB attacks, RMB charges, TAB opens
assembly, 1–4 arm the slots. The Android and iOS builds compile and install;
until there are touch controls there is not much to do once they are open.

## Releasing

```bash
git tag v0.1.0
git push origin v0.1.0
```

Tests run, all five platforms build, and a GitHub Release appears with one zip
per platform and generated notes.

## Pinning

The engine version lives in exactly one place — `GODOT_VERSION` at the top of
`ci.yml`. [`actions/setup-godot`](actions/setup-godot/action.yml) downloads that
build straight from the engine's own releases and caches it, so nothing sits
between this repo and the binary it builds with except GitHub's own actions.

Raising it is one line here and `config/features` in `project.godot`.
