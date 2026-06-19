import json
import os
import random
import time
import uuid
from datetime import datetime, timezone

from confluent_kafka import Producer


bootstrap = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
topics = [t.strip() for t in os.getenv("PRODUCER_TOPICS", "orders").split(",") if t.strip()]
interval_ms = int(os.getenv("PRODUCER_INTERVAL_MS", "250"))
batch_size = int(os.getenv("PRODUCER_BATCH_SIZE", "5"))
keys = ["user:1", "user:2", "user:3", "account:1", "account:2"]

producer = Producer({"bootstrap.servers": bootstrap})


def event_type(topic: str) -> str:
    singular = topic[:-1] if topic.endswith("s") else topic
    return f"sample.{singular}.created"


while True:
    for _ in range(batch_size):
        topic = random.choice(topics)
        payload = {
            "id": str(uuid.uuid4()),
            "topic": topic,
            "type": event_type(topic),
            "createdUtc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "number": random.randint(1, 1_000_000),
            "payload": {
                "userId": random.randint(1, 25),
                "amount": round(random.uniform(5, 250), 2),
                "currency": "USD",
            },
        }
        producer.produce(topic, key=random.choice(keys), value=json.dumps(payload))
    producer.poll(0)
    producer.flush(5)
    time.sleep(interval_ms / 1000)
