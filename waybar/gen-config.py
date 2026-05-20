#!/usr/bin/env python3
"""Generate a combined waybar config array from two JSONC templates.

Usage: gen-config.py <wide.jsonc> <narrow.jsonc> <narrow-output-name> <dst.json>

Produces a JSON array [wide_bar, narrow_bar] where:
  wide_bar  targets all outputs EXCEPT narrow-output-name
  narrow_bar targets narrow-output-name only
"""
import json
import re
import sys


def load_jsonc(path):
    with open(path) as f:
        content = f.read()
    content = re.sub(r"//[^\n]*", "", content)
    content = re.sub(r",(\s*[}\]])", r"\1", content)
    return json.loads(content)


_, wide_path, narrow_path, narrow_out, dst = sys.argv
wide = load_jsonc(wide_path)
narrow = load_jsonc(narrow_path)
wide["output"] = [f"!{narrow_out}"]
narrow["output"] = narrow_out
with open(dst, "w") as f:
    json.dump([wide, narrow], f)
