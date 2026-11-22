import os
import unittest
from unittest.mock import patch

import app as demo


class LoadEndpointTests(unittest.TestCase):
    def setUp(self):
        demo.app.config["TESTING"] = True
        self.client = demo.app.test_client()

    def load(self, query):
        clock = iter(i / 10 for i in range(10000))
        with patch.object(demo.time, "monotonic", side_effect=lambda: next(clock)), \
                patch.object(demo.time, "sleep"):
            return self.client.get("/load" + query)

    def test_health(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {"status": "healthy"})

    def test_invalid_parameters_are_client_errors(self):
        for name in ("duration", "intensity"):
            for value in ("abc", "", "1.5", "NaN", "1" * 5000):
                with self.subTest(name=name, value=value[:20]):
                    response = self.client.get(f"/load?{name}={value}")
                    self.assertEqual(response.status_code, 400)
                    self.assertEqual(response.json, {"error": f"{name} must be an integer"})

    def test_valid_request(self):
        response = self.load("?duration=1&intensity=25")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["intensity"], 25)
        self.assertGreaterEqual(response.json["duration_s"], 1)
        self.assertLess(response.json["duration_s"], 1.5)

    def test_numeric_limits_remain_bounded(self):
        for value, duration, intensity in ((-20, 1, 1), (100000, 90, 100)):
            with self.subTest(value=value):
                response = self.load(f"?duration={value}&intensity={value}")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json["intensity"], intensity)
                self.assertGreaterEqual(response.json["duration_s"], duration)
                self.assertLess(response.json["duration_s"], duration + 0.5)

    def test_environment_defaults(self):
        with patch.dict(os.environ, {"LOAD_DURATION_DEFAULT": "1", "LOAD_INTENSITY_DEFAULT": "30"}):
            response = self.load("")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["intensity"], 30)
        self.assertLess(response.json["duration_s"], 1.5)

    def test_explicit_parameters_override_invalid_defaults(self):
        with patch.dict(os.environ, {"LOAD_DURATION_DEFAULT": "bad", "LOAD_INTENSITY_DEFAULT": "bad"}):
            response = self.load("?duration=1&intensity=1")
        self.assertEqual(response.status_code, 200)

    def test_invalid_server_default_is_not_a_client_error(self):
        with patch.dict(os.environ, {"LOAD_DURATION_DEFAULT": "bad"}):
            response = self.client.get("/load")
        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json, {"error": "Invalid load default configuration"})


if __name__ == "__main__":
    unittest.main()
