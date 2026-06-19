# Tests

Parser-level tests use Bats.

```bash
make test
```

`make test` fails when `bats` is missing. Use `make test-optional` for local
environments where Bats is not installed.
