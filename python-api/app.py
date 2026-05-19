import random
import os
import time
from flask import Flask, Response, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

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
    }


@app.route('/health', methods=['GET'])
def health():
    return {"status": "ok"}


@app.route('/ready', methods=['GET'])
def ready():
    return {"status": "ready"}


@app.route('/metrics', methods=['GET'])
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
