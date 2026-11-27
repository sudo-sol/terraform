import os
from uuid import uuid4

import boto3
import psycopg
from flask import Flask, request

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 4096


def connect():
    options = {"connect_timeout": 5}
    if os.environ.get("DB_IAM") == "true":
        options["password"] = boto3.client("rds").generate_db_auth_token(
            DBHostname=os.environ["PGHOST"], Port=5432, DBUsername=os.environ["PGUSER"]
        )
    return psycopg.connect(**options)


@app.get("/health")
def health():
    with connect() as conn:
        conn.execute("SELECT id FROM orders.items LIMIT 0")
    return {"ready": True}


@app.errorhandler(psycopg.OperationalError)
def unavailable(_error):
    return {"error": "Database unavailable"}, 503


@app.post("/orders")
def create_order():
    payload = request.get_json(silent=True)
    item = payload.get("item") if isinstance(payload, dict) else None
    if not isinstance(item, str) or not 1 <= len(item.strip()) <= 120 or "\x00" in item:
        return {"error": "Supply an item of 1 to 120 characters"}, 400
    order_id = uuid4()
    with connect() as conn:
        conn.execute("INSERT INTO orders.items (id, item) VALUES (%s, %s)", (order_id, item.strip()))
    return {"id": str(order_id), "item": item.strip()}, 201


@app.get("/orders/<uuid:order_id>")
def get_order(order_id):
    with connect() as conn:
        row = conn.execute("SELECT item FROM orders.items WHERE id = %s", (order_id,)).fetchone()
    if row is None:
        return {"error": "Order not found"}, 404
    return {"id": str(order_id), "item": row[0]}
