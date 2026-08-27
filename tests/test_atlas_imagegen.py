#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "imagegen.sh"


class AtlasHandler(BaseHTTPRequestHandler):
    generation_posts = 0
    upload_posts = 0
    prediction_gets = 0
    payloads = []
    fail_generation = False

    def log_message(self, _format, *_args):
        pass

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path == "/model/uploadMedia":
            type(self).upload_posts += 1
            length = int(self.headers.get("content-length", "0"))
            self.rfile.read(length)
            self.send_json(
                200,
                {
                    "code": 200,
                    "data": {"download_url": f"{self.server.base_url}/reference.jpg"},
                },
            )
            return

        if self.path == "/model/generateImage":
            type(self).generation_posts += 1
            length = int(self.headers.get("content-length", "0"))
            payload = json.loads(self.rfile.read(length))
            type(self).payloads.append(payload)
            if type(self).fail_generation:
                self.send_json(500, {"code": 500, "message": "mock failure"})
            else:
                self.send_json(
                    200,
                    {"code": 200, "data": {"id": "prediction-test", "status": "starting"}},
                )
            return

        self.send_error(404)

    def do_GET(self):
        if self.path == "/model/prediction/prediction-test":
            type(self).prediction_gets += 1
            status = "processing" if type(self).prediction_gets == 1 else "completed"
            outputs = [] if status == "processing" else [f"{self.server.base_url}/output.jpg"]
            self.send_json(
                200,
                {
                    "code": 200,
                    "data": {"id": "prediction-test", "status": status, "outputs": outputs},
                },
            )
            return

        if self.path == "/output.jpg":
            body = b"mock-jpeg"
            self.send_response(200)
            self.send_header("content-type", "image/jpeg")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        self.send_error(404)


class AtlasImagegenTests(unittest.TestCase):
    def setUp(self):
        AtlasHandler.generation_posts = 0
        AtlasHandler.upload_posts = 0
        AtlasHandler.prediction_gets = 0
        AtlasHandler.payloads = []
        AtlasHandler.fail_generation = False
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), AtlasHandler)
        self.server.base_url = f"http://127.0.0.1:{self.server.server_port}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.tempdir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()
        self.tempdir.cleanup()

    def run_script(self, *args):
        env = os.environ.copy()
        env.update(
            {
                "ATLASCLOUD_API_KEY": "test-key",
                "ATLASCLOUD_API_BASE_URL": self.server.base_url,
            }
        )
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
        )

    def test_text_to_image_submits_once_and_downloads_output(self):
        output = Path(self.tempdir.name) / "result.jpg"
        result = self.run_script(
            "--mode", "atlas", "--prompt", "studio product photo", "--output", str(output)
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(AtlasHandler.generation_posts, 1)
        self.assertEqual(AtlasHandler.prediction_gets, 2)
        self.assertEqual(AtlasHandler.payloads[0]["model"], "openai/gpt-image-2/text-to-image")
        self.assertNotIn("images", AtlasHandler.payloads[0])
        self.assertEqual(output.read_bytes(), b"mock-jpeg")
        self.assertEqual(result.stdout.strip(), str(output))

    def test_reference_image_uses_upload_and_edit_model(self):
        reference = Path(self.tempdir.name) / "reference.jpg"
        reference.write_bytes(b"reference")
        output = Path(self.tempdir.name) / "edited.jpg"
        result = self.run_script(
            "--mode",
            "atlas",
            "--prompt",
            "place the product on marble",
            "--image",
            str(reference),
            "--output",
            str(output),
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(AtlasHandler.upload_posts, 1)
        self.assertEqual(AtlasHandler.generation_posts, 1)
        self.assertEqual(AtlasHandler.payloads[0]["model"], "openai/gpt-image-2/edit")
        self.assertEqual(AtlasHandler.payloads[0]["images"], [f"{self.server.base_url}/reference.jpg"])

    def test_generation_post_is_not_retried(self):
        AtlasHandler.fail_generation = True
        result = self.run_script("--mode", "atlas", "--prompt", "studio product photo")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(AtlasHandler.generation_posts, 1)
        self.assertEqual(AtlasHandler.prediction_gets, 0)


if __name__ == "__main__":
    unittest.main()
