from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Simple metric: total requests by endpoint
REQUEST_COUNT = Counter("app_requests_total", "Total app requests", ["endpoint"])


@app.get("/health")
def health():
    REQUEST_COUNT.labels("/health").inc()
    return jsonify(status="ok"), 200


@app.get("/api/greeting")
def greeting():
    REQUEST_COUNT.labels("/api/greeting").inc()
    return jsonify(message="hello from homelab api"), 200


@app.get("/metrics")
def metrics():
    REQUEST_COUNT.labels("/metrics").inc()
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
