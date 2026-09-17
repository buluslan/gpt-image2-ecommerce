#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

scenario_files = sorted((ROOT / "references/scenarios").glob("*.json"))
assert len(scenario_files) == 39, len(scenario_files)
for path in scenario_files:
    json.loads(path.read_text(encoding="utf-8"))

evals = json.loads((ROOT / "evals/evals.json").read_text(encoding="utf-8"))
assert evals["evals"] and "不是可直接运行" in evals["notes"]

with tempfile.TemporaryDirectory() as temp:
    output = Path(temp) / "pack"
    result = subprocess.run([
        "bash", str(ROOT / "scripts/imagegen.sh"), "--mode", "manual",
        "--prompt", '{"subject":"blue insulated bottle","scene_type":"product photography"}',
        "--output", str(output),
    ], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    envelope = json.loads(result.stdout)
    assert envelope["ok"] is True
    assert (output / "prompt.txt").is_file()
    assert (output / "request.json").is_file()

print("offline checks: ok")
