"""Integration checks against the disposable PostgreSQL cluster in test-local.sh."""
import json
import multiprocessing
import os
from contextlib import ExitStack, contextmanager
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest import TestCase, main
from uuid import uuid4

import psycopg
from werkzeug.serving import make_server

from migrate import migrate


def serve(component, port, api_url, ready):
    if component == "api":
        os.environ["PGUSER"] = "orders_api"
        from api import app
    else:
        os.environ["API_URL"] = api_url
        from web import app
    with make_server("127.0.0.1", port, app) as server:
        ready.send(server.server_port)
        ready.close()
        server.serve_forever()


@contextmanager
def service(component, port=0, api_url=None):
    ctx = multiprocessing.get_context("spawn")
    reader, writer = ctx.Pipe(duplex=False)
    process = ctx.Process(target=serve, args=(component, port, api_url, writer))
    process.start()
    writer.close()
    try:
        if not reader.poll(10):
            raise RuntimeError(f"{component} startup timed out")
        yield reader.recv()
    finally:
        reader.close()
        process.terminate()
        process.join(10)
        process.close()


def request_json(url, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = Request(url, data=body, headers={"Content-Type": "application/json"})
    try:
        response = urlopen(request, timeout=10)
    except HTTPError as exc:
        response = exc
    with response:
        return response.status, json.load(response)


class OrdersTests(TestCase):
    @classmethod
    def setUpClass(cls):
        # Emulate only the role name RDS provisions; local PostgreSQL uses socket auth.
        with psycopg.connect() as conn:
            conn.execute("CREATE ROLE rds_iam")
        migrate()
        migrate()

    def test_database_permissions(self):
        with psycopg.connect(user="orders_api") as conn:
            self.assertFalse(conn.execute(
                "SELECT has_table_privilege(current_user, 'orders.items', 'DELETE')"
            ).fetchone()[0])

    def test_order_survives_api_replacement(self):
        # Keep the same frontend process and database while replacing the API.
        with ExitStack() as web_process:
            with service("api") as api_port:
                api_url = f"http://127.0.0.1:{api_port}"
                port = web_process.enter_context(service("web", api_url=api_url))
                base = f"http://127.0.0.1:{port}"
                self.assertEqual(request_json(base + "/health")[0], 200)
                self.assertEqual(request_json(api_url + "/health")[0], 200)
                self.assertEqual(request_json(base + "/orders", {"item": " "})[0], 400)
                self.assertEqual(request_json(base + "/orders/" + str(uuid4()))[0], 404)
                status, order = request_json(base + "/orders", {"item": " sample pen "})
                self.assertEqual(status, 201)
            self.assertEqual(request_json(base + "/orders", {"item": "pen"})[0], 503)
            with service("api", port=api_port):
                self.assertEqual(request_json(base + "/orders/" + order["id"]),
                                 (200, {"id": order["id"], "item": "sample pen"}))


if __name__ == "__main__":
    main()
