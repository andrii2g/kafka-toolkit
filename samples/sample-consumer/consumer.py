import json
import os
import time

from confluent_kafka import Consumer


bootstrap = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
group = os.getenv("CONSUMER_GROUP", "sample-worker")
topic = os.getenv("CONSUMER_TOPIC", "orders")
sleep_ms = int(os.getenv("CONSUMER_SLEEP_MS", "100"))
auto_offset_reset = os.getenv("CONSUMER_AUTO_OFFSET_RESET", "earliest")

consumer = Consumer(
    {
        "bootstrap.servers": bootstrap,
        "group.id": group,
        "auto.offset.reset": auto_offset_reset,
        "enable.auto.commit": True,
    }
)
consumer.subscribe([topic])

try:
    while True:
        message = consumer.poll(1.0)
        if message is None:
            continue
        if message.error():
            print(f"consumer error: {message.error()}", flush=True)
            continue
        value = message.value().decode("utf-8", errors="replace")
        try:
            decoded = json.loads(value)
            summary = decoded.get("type", value[:80])
        except json.JSONDecodeError:
            summary = value[:80]
        key = message.key().decode("utf-8", errors="replace") if message.key() else ""
        print(
            f"{message.topic()}[{message.partition()}]@{message.offset()} key={key} {summary}",
            flush=True,
        )
        time.sleep(sleep_ms / 1000)
finally:
    consumer.close()
