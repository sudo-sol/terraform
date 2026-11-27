import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from flask import Flask, Response, request

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 4096


@app.get("/")
def home():
    return """<!doctype html><title>Demo orders</title><h1>Create an order</h1>
    <form method="post" action="/orders"><label>Item
    <input name="item" maxlength="120" required></label><button>Create order</button></form>"""


@app.get("/health")
def health():
    return {"ready": True}


def api_request(path, body=None):
    req = Request(os.environ["API_URL"] + path, data=body, headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=8) as result:
            return Response(result.read(), status=result.status, content_type="application/json")
    except HTTPError as exc:
        with exc:
            return Response(exc.read(), status=exc.code, content_type=exc.headers.get_content_type())
    except (URLError, TimeoutError):
        return {"error": "Orders API unavailable"}, 503


@app.post("/orders")
def create_order():
    if request.is_json:
        body = request.get_data()
    else:
        body = json.dumps({"item": request.form.get("item")}).encode()
    return api_request("/orders", body)


@app.get("/orders/<uuid:order_id>")
def get_order(order_id):
    return api_request(f"/orders/{order_id}")
