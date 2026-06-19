# kafka-toolkit

Small Kafka operations scripts and a local Docker Compose demo.

## Local plan file

The implementation plan is kept as a local-only file and must not be staged,
committed, or pushed. The repository `.gitignore` intentionally ignores
`*PLAN.md`.

## Requirements

- Docker Compose
- Bash
- Kafka CLI tools for running scripts outside the demo container
- Optional: `bats` for tests and `shellcheck` for Bash linting

## Quick Start

```bash
docker compose up -d --build
make lag
make test
```

The Compose demo starts a single Kafka broker, creates demo topics with fixed
partition counts, then starts a sample producer and two sample consumers.
Kafka is exposed on `localhost:9092`, which works from WSL with Docker Desktop
WSL integration.

## Demo Topics

`topic-init` and `samples/topics.sh` create these topics:

| Topic | Partitions | Replication Factor |
|---|---:|---:|
| `orders` | 6 | 1 |
| `payments` | 3 | 1 |
| `notifications` | 4 | 1 |
| `healthcheck.kafka` | 1 | 1 |

Kafka auto topic creation is disabled in the demo broker so sample services
cannot accidentally create topics with default partition counts.

## Commands

```bash
make up
make topics
make lag
make test
make shellcheck
make down
```
