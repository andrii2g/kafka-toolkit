# kafka-toolkit

Small Bash/Python tools for day-to-day Kafka diagnostics, plus a Docker Compose
demo with Kafka, Kafka UI, sample producer, and sample consumers.


## Quick Start With Docker Compose

```bash
docker compose up -d --build
```

Kafka is available at `localhost:9092`. Kafka UI is available at
`http://localhost:8080`. The demo disables auto topic creation and uses
`topic-init` to create topics before the producer and consumers start.

Demo topics:

| Topic | Partitions | Replication Factor |
|---|---:|---:|
| `orders` | 6 | 1 |
| `payments` | 3 | 1 |
| `notifications` | 4 | 1 |
| `healthcheck.kafka` | 1 | 1 |

## Common Commands

```bash
make up
make topics
make lag
make lag-report
make snapshot
make smoke
make test
make shellcheck
make down
```

## Scripts Included

Lag and group tools:

```bash
./scripts/kafka-lag.sh --bootstrap localhost:9092 --group orders-worker --topic orders
./scripts/kafka-lag-report.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-report.local.md
./scripts/kafka-lag-check.sh --bootstrap localhost:9092 --group orders-worker --topic orders --max-lag 1000
./scripts/kafka-lag-watch.sh --bootstrap localhost:9092 --group orders-worker --topic orders --interval 5
./scripts/kafka-group-matrix.sh --bootstrap localhost:9092 --group orders-worker
./scripts/kafka-topic-consumers.sh --bootstrap localhost:9092 --topic orders
./scripts/kafka-lag-snapshot.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/lag-snapshot.local.csv
python3 ./scripts/kafka-lag-trend.py samples/reports/lag-snapshot.local.csv --group orders-worker --topic orders --out samples/reports/lag-trend.local.md
./scripts/kafka-group-state.sh --bootstrap localhost:9092 --group orders-worker
./scripts/kafka-rebalance-watch.sh --bootstrap localhost:9092 --group orders-worker
```

Topic and message tools:

```bash
./scripts/kafka-topic-watermark.sh --bootstrap localhost:9092 --topic orders
./scripts/kafka-topic-size.sh --bootstrap localhost:9092 --topic orders
./scripts/kafka-dead-consumers.sh --bootstrap localhost:9092
./scripts/kafka-smoke-test.sh --bootstrap localhost:9092 --topic healthcheck.kafka
./scripts/kafka-sample-json.sh --bootstrap localhost:9092 --topic orders --count 5 --from-beginning
./scripts/kafka-sample-keys.sh --bootstrap localhost:9092 --topic orders --count 100 --from-beginning
./scripts/kafka-partition-distribution.sh --bootstrap localhost:9092 --topic orders --count 1000 --from-beginning
```

Config and backup tools:

```bash
./scripts/kafka-topic-config-report.sh --bootstrap localhost:9092 --topic orders --out samples/reports/topic-config.local.md
./scripts/kafka-topic-config-diff.sh --source-bootstrap localhost:9092 --target-bootstrap localhost:9092 --topic orders
./scripts/kafka-offset-backup.sh --bootstrap localhost:9092 --group orders-worker --topic orders --out samples/reports/offsets-backup.local.json
```

Most reporting scripts support `--format table`, `--format csv`, or
`--format markdown`; JSON is available on selected scripts where it is useful.

## Using `--command-config`

For SASL/TLS clusters, pass a Kafka client properties file through to Kafka CLI
commands:

```bash
./scripts/kafka-lag.sh \
  --bootstrap broker.example.com:9093 \
  --command-config ./client.properties \
  --group orders-worker
```

`KAFKA_COMMAND_CONFIG` provides the same default for all scripts.

## Safety Notes

The toolkit is read-only by default. Allowed write actions are limited to:

- `samples/topics.sh` and `topic-init`, which create demo topics with
  `--if-not-exists`
- `kafka-smoke-test.sh`, which creates a healthcheck topic and produces one
  explicit test message
- sample producer containers that write demo messages
- report scripts that write local files

The v1 scripts do not delete topics, reset offsets, change ACLs, change topic
configs, or perform production remediation.

## Testing

```bash
make test
```

`make test` requires `bats` and fails when tests fail. `make test-optional`
prints a skip message if `bats` is not installed.

## Limitations

- Topic size is an approximate retained message count based on offsets, not
  disk byte size.
- `kafka-dead-consumers.sh` can be slow on large clusters because it describes
  all consumer groups.
- Output parsing targets the standard Kafka CLI text formats and may need small
  adjustments for heavily customized distributions.
