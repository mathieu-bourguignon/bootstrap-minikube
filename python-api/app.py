import random
import os
import time
import uuid
from flask import Flask, Response, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import psycopg
from psycopg.types.json import Jsonb
import redis

app = Flask(__name__)

POSTGRES_DSN = os.getenv("POSTGRES_DSN")
REDIS_URL = os.getenv("REDIS_URL")
SEED_ROWS = int(os.getenv("POSTGRES_SEED_ROWS", "50"))
SCHEMA_READY = False

SAMPLE_ADJECTIVES = [
    "calm",
    "fast",
    "curious",
    "steady",
    "bright",
    "warm",
    "sharp",
    "bold",
]
SAMPLE_TOPICS = [
    "deploy",
    "canary",
    "metric",
    "trace",
    "cache",
    "query",
    "pod",
    "route",
]

REQUEST_COUNT = Counter(
    "python_api_requests_total",
    "Total HTTP requests handled by the Python API.",
    ["method", "endpoint", "http_status", "app_version"],
)
REQUEST_LATENCY = Histogram(
    "python_api_request_duration_seconds",
    "HTTP request latency for the Python API.",
    ["endpoint", "app_version"],
)


def get_db_connection():
    if not POSTGRES_DSN:
        raise RuntimeError("POSTGRES_DSN is not configured")
    return psycopg.connect(POSTGRES_DSN)


def get_redis_client():
    if not REDIS_URL:
        raise RuntimeError("REDIS_URL is not configured")
    return redis.Redis.from_url(REDIS_URL, decode_responses=True)


def random_sample():
    return {
        "external_id": str(uuid.uuid4()),
        "label": f"{random.choice(SAMPLE_ADJECTIVES)}-{random.choice(SAMPLE_TOPICS)}",
        "score": round(random.uniform(1, 100), 2),
        "payload": {
            "region": random.choice(["local", "edge", "core"]),
            "priority": random.choice(["low", "medium", "high"]),
            "latency_ms": random.randint(15, 750),
        },
    }


def ensure_schema_and_seed():
    global SCHEMA_READY
    if SCHEMA_READY:
        return

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS api_samples (
                    id BIGSERIAL PRIMARY KEY,
                    external_id UUID NOT NULL,
                    label TEXT NOT NULL,
                    score NUMERIC(8, 2) NOT NULL,
                    payload JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
                """
            )
            cur.execute("SELECT count(*) FROM api_samples")
            current_rows = cur.fetchone()[0]
            rows_to_insert = max(SEED_ROWS - current_rows, 0)
            for _ in range(rows_to_insert):
                sample = random_sample()
                cur.execute(
                    """
                    INSERT INTO api_samples (external_id, label, score, payload)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (
                        sample["external_id"],
                        sample["label"],
                        sample["score"],
                        Jsonb(sample["payload"]),
                    ),
                )
        conn.commit()

    SCHEMA_READY = True


@app.before_request
def prepare_dependencies():
    if request_endpoint() != "/data":
        return
    ensure_schema_and_seed()


@app.after_request
def record_metrics(response):
    endpoint = request_endpoint()
    app_version = os.getenv("APP_VERSION", "local")
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        http_status=response.status_code,
        app_version=app_version,
    ).inc()
    return response


def request_endpoint():
    if request.url_rule is None:
        return "unknown"
    return request.url_rule.rule


@app.route('/', methods=['GET'])
def generate_load():
    app_version = os.getenv("APP_VERSION", "local")
    app_message = os.getenv("APP_MESSAGE", "dev")

    max_delay = float(os.getenv("MAX_DELAY_SECONDS", "0.2"))
    delay = random.uniform(0.02, max_delay)
    end_time = time.time() + delay

    # Générer un délai aléatoire entre 20ms et 2s
    delay = random.uniform(0.02, 2.0)  # En secondes
    end_time = time.time() + delay

    # Simuler un traitement CPU en utilisant un calcul lourd
    with REQUEST_LATENCY.labels(endpoint="/", app_version=app_version).time():
        while time.time() < end_time:
            _ = random.random() * random.random() * random.random() * random.random()

    return {
        "delay": round(delay, 2),
        "message": app_message,
        "version": app_version,
        "max_delay_configured": max_delay,
    }


@app.route('/health', methods=['GET'])
def health():
    return {"status": "ok"}


@app.route('/ready', methods=['GET'])
def ready():
    checks = {}
    status = 200

    try:
        ensure_schema_and_seed()
        checks["postgres"] = "ready"
    except Exception as exc:
        checks["postgres"] = f"not ready: {exc}"
        status = 503

    try:
        get_redis_client().ping()
        checks["redis"] = "ready"
    except Exception as exc:
        checks["redis"] = f"not ready: {exc}"
        status = 503

    return {"status": "ready" if status == 200 else "not ready", "checks": checks}, status


@app.route('/data', methods=['GET'])
def data():
    app_version = os.getenv("APP_VERSION", "local")

    with REQUEST_LATENCY.labels(endpoint="/data", app_version=app_version).time():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, external_id, label, score, payload, created_at
                    FROM api_samples
                    ORDER BY random()
                    LIMIT 1
                    """
                )
                row = cur.fetchone()

        cache_hits = get_redis_client().incr("python-api:data:hits")

    return {
        "cache": {
            "redis_key": "python-api:data:hits",
            "hits": cache_hits,
        },
        "sample": {
            "id": row[0],
            "external_id": str(row[1]),
            "label": row[2],
            "score": float(row[3]),
            "payload": row[4],
            "created_at": row[5].isoformat(),
        },
    }


@app.route('/metrics', methods=['GET'])
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
