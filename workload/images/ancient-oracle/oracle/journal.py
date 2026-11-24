"""
The Oracle's journal: every answer it gave, one JSON object per line.

Kept on a volume so it survives restarts. Read it at /mcp/journal.
"""

import json
import os
import threading
import time


MAX_BYTES = 20 * 1024 * 1024
MAX_ANSWER = 8000


class Journal:

    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()

        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
        except OSError:
            pass

    def write(self, caller, tool, arguments, answer, is_error=False):
        now = time.time()

        entry = {
            "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
            "realm_time": time.strftime("%H:%M", time.localtime(now)),
            "caller": caller,
            "tool": tool,
            "arguments": arguments,
            "error": bool(is_error),
            "answer": answer[:MAX_ANSWER] + (
                "\n[...]" if len(answer) > MAX_ANSWER else ""
            ),
        }
        line = json.dumps(entry, ensure_ascii=False) + "\n"

        with self.lock:
            try:
                if (
                    os.path.exists(self.path)
                    and os.path.getsize(self.path) > MAX_BYTES
                ):
                    os.replace(self.path, self.path + ".1")

                with open(self.path, "a", encoding="utf-8") as f:
                    f.write(line)

            except OSError as e:
                print(f"[oracle] journal not written: {e}", flush=True)

    def read(self, limit=200, tool=None):
        with self.lock:
            lines = []
            for path in (self.path + ".1", self.path):
                try:
                    with open(path, encoding="utf-8") as f:
                        lines.extend(f.readlines())
                except OSError:
                    pass

        entries = []
        for line in lines:
            try:
                e = json.loads(line)
            except ValueError:
                continue

            if tool is None or e.get("tool") == tool:
                entries.append(e)

        return entries[-limit:]
