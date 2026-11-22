import logging
import math
import os
import time

from flask import Flask, jsonify, request

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# /health
# Used by the ALB target group health check.
# Returns 200 as long as the process is alive.
# ---------------------------------------------------------------------------

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


# ---------------------------------------------------------------------------
# /load
# Generates synthetic CPU load to trigger the ECS autoscaling policy.
#
# Query params:
#   duration  (int, seconds) — how long to burn CPU, default 30
#   intensity (int, 1-100)   — rough % of one core to saturate, default 100
#
# Example:
#   curl "http://<alb-dns>/load?duration=60&intensity=100"
# ---------------------------------------------------------------------------

@app.route("/load")
def load():
    values = {}
    for name, default in (("duration", "30"), ("intensity", "100")):
        raw_value = request.args.get(name, os.environ.get(f"LOAD_{name.upper()}_DEFAULT", default))
        try:
            values[name] = int(raw_value)
        except ValueError:
            if name in request.args:
                return jsonify({"error": f"{name} must be an integer"}), 400
            logger.error("Invalid LOAD_%s_DEFAULT configuration", name.upper())
            return jsonify({"error": "Invalid load default configuration"}), 500

    duration = values["duration"]
    intensity = values["intensity"]
    duration  = max(1, min(duration, 90))   # stay below the worker timeout
    intensity = max(1, min(intensity, 100))

    logger.info("Starting CPU load: duration=%ds intensity=%d%%", duration, intensity)

    start     = time.monotonic()
    deadline  = start + duration
    # How many seconds in each on/off cycle (granularity of intensity control)
    cycle     = 0.1
    on_time   = cycle * (intensity / 100.0)
    off_time  = cycle - on_time
    iterations = 0

    while time.monotonic() < deadline:
        cycle_start = time.monotonic()
        # Burn CPU: tight math loop for `on_time` seconds
        while time.monotonic() - cycle_start < on_time:
            _ = math.sqrt(sum(i * i for i in range(1000)))
            iterations += 1
        # Rest for `off_time` seconds
        if off_time > 0:
            time.sleep(off_time)

    elapsed = round(time.monotonic() - start, 2)
    logger.info("CPU load complete: elapsed=%ss iterations=%d", elapsed, iterations)

    return jsonify({
        "status":     "done",
        "duration_s": elapsed,
        "intensity":  intensity,
        "iterations": iterations,
    }), 200


# ---------------------------------------------------------------------------
# Entrypoint (local dev only — production uses gunicorn via CMD in Dockerfile)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 9999))
    app.run(host="0.0.0.0", port=port)
