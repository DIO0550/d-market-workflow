#!/usr/bin/env python3
"""Block programming-language edits until code-intent-layering has been read."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

SKILL_RELATIVE_PATH = "skills/code-intent-layering/SKILL.md"

PROGRAMMING_EXTENSIONS = {
    ".c", ".cc", ".clj", ".cljs", ".cpp", ".cs", ".dart", ".ex", ".exs",
    ".fs", ".fsx", ".go", ".groovy", ".h", ".hpp", ".java", ".js",
    ".jsx", ".kt", ".kts", ".lua", ".m", ".mm", ".php", ".pl", ".pm",
    ".py", ".pyw", ".r", ".rb", ".rs", ".scala", ".sh", ".swift",
    ".ts", ".tsx", ".vue", ".zig",
}

PROGRAMMING_FILENAMES = {
    "Dockerfile", "Makefile", "Rakefile", "Gemfile", "CMakeLists.txt",
}


def load_event() -> dict[str, Any]:
    try:
        return json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        allow(f"hook input is not JSON: {exc}")


def allow(reason: str | None = None) -> None:
    if reason and os.environ.get("CODE_INTENT_GUARD_DEBUG"):
        print(reason, file=sys.stderr)
    raise SystemExit(0)


def block(reason: str) -> None:
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
    print(reason, file=sys.stderr)
    raise SystemExit(2)


def candidate_paths(tool_input: dict[str, Any]) -> set[str]:
    paths: set[str] = set()
    for key in ("file_path", "path"):
        value = tool_input.get(key)
        if isinstance(value, str):
            paths.add(value)

    edits = tool_input.get("edits")
    if isinstance(edits, list):
        for edit in edits:
            if isinstance(edit, dict):
                value = edit.get("file_path") or edit.get("path")
                if isinstance(value, str):
                    paths.add(value)

    return paths


def is_programming_file(path_text: str) -> bool:
    path = Path(path_text)
    if path.name in PROGRAMMING_FILENAMES:
        return True
    return path.suffix.lower() in PROGRAMMING_EXTENSIONS


def transcript_path(event: dict[str, Any]) -> Path | None:
    value = event.get("transcript_path")
    if not isinstance(value, str) or not value:
        return None
    path = Path(value)
    return path if path.is_file() else None


def skill_loaded(path: Path) -> bool:
    pattern = re.compile(r"skills[/\\]code-intent-layering[/\\]SKILL\.md")
    try:
        with path.open("r", encoding="utf-8", errors="replace") as transcript:
            for line in transcript:
                if pattern.search(line):
                    return True
    except OSError:
        return False
    return False


def main() -> None:
    event = load_event()
    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        allow("tool_input is missing")

    targets = candidate_paths(tool_input)
    programming_targets = sorted(path for path in targets if is_programming_file(path))
    if not programming_targets:
        allow("no programming-language target")

    path = transcript_path(event)
    if path and skill_loaded(path):
        allow("code-intent-layering skill was already loaded")

    targets_text = "\n".join(f"- {target}" for target in programming_targets)
    block(
        "プログラミング言語ファイルを変更する前に "
        f"`{SKILL_RELATIVE_PATH}` を Read してください。\n"
        "この Skill は、コード=How、テスト=What、コミット=Why、"
        "コメント=Why-not/局所的なWhy のレイヤリングを確認するために必要です。\n"
        f"対象:\n{targets_text}"
    )


if __name__ == "__main__":
    main()
