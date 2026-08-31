# openxchg Test Suite

BATS test suite for openxchg 2.x. Fully offline: a mock `wget`
(`tests/mocks/wget`) serves generated JSON fixtures, and each test runs
against a scratch database via the `DB_PATH` environment override — no
network access, no writes outside the per-test temp directory.

## Run

```bash
./scripts/run_tests.sh          # whole suite
bats tests/openxchg.bats        # direct
```

Requires [bats-core](https://github.com/bats-core/bats-core) with
bats-support and bats-assert (install via `scripts/install_bats.sh`).

## Layout

| Path | Purpose |
|------|---------|
| `tests/openxchg.bats` | All tests: CLI, update, query, latest, error paths |
| `tests/test_helper.bash` | Per-test env setup, fixture generation |
| `tests/mocks/wget` | Intercepts API calls when `MOCK_API_ENABLED=true` |

Set `MOCK_API_ERROR=1` to make the mock return the API-error fixture.
