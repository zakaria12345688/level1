#!/usr/bin/env python3
"""Serves the bare repositories in /srv/git over Git's smart HTTP protocol."""

import gzip
import http.server
import os
import re
import socketserver
import subprocess
import sys
from datetime import datetime, timezone

ROOT = os.environ.get("GIT_ROOT", "/srv/git")
PORT = int(os.environ.get("PORT", "8080"))
SERVICES = ("git-upload-pack", "git-receive-pack")
REPO_PATH = re.compile(r"^/([A-Za-z0-9._-]+\.git)/(info/refs|git-upload-pack|git-receive-pack)$")


def pkt(line):
    data = line.encode()
    return f"{len(data) + 4:04x}".encode() + data


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "grimoire/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        when = datetime.now(timezone.utc).strftime("%H:%M:%S")
        print(f"[grimoire {when}] {self.client_address[0]} {fmt % args}", flush=True)

    def _repo(self):
        m = REPO_PATH.match(self.path.split("?")[0])
        if not m:
            return None, None
        repo = os.path.join(ROOT, m.group(1))
        return (repo if os.path.isfile(os.path.join(repo, "HEAD")) else None), m.group(2)

    def _reply(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def _env(self):
        env = dict(os.environ)
        proto = self.headers.get("Git-Protocol")
        if proto:
            env["GIT_PROTOCOL"] = proto
        env["REMOTE_ADDR"] = self.client_address[0]
        return env

    def do_GET(self):
        repo, action = self._repo()
        service = (re.search(r"service=([a-z-]+)", self.path) or [None, None])[1]
        if not repo or action != "info/refs" or service not in SERVICES:
            return self._reply(404, "text/plain", b"The grimoire has no such page.\n")
        out = subprocess.run(["git", service[4:], "--stateless-rpc", "--advertise-refs", repo],
                             capture_output=True, env=self._env()).stdout
        body = out if self.headers.get("Git-Protocol") else pkt(f"# service={service}\n") + b"0000" + out
        self._reply(200, f"application/x-{service}-advertisement", body)

    def _read_body(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks = []
            while True:
                size = int(self.rfile.readline().strip().split(b";")[0], 16)
                if size == 0:
                    self.rfile.readline()
                    break
                chunks.append(self.rfile.read(size))
                self.rfile.readline()
            data = b"".join(chunks)
        else:
            data = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if self.headers.get("Content-Encoding") == "gzip":
            data = gzip.decompress(data)
        return data

    def do_POST(self):
        repo, action = self._repo()
        if not repo or action not in SERVICES:
            return self._reply(404, "text/plain", b"The grimoire has no such page.\n")
        data = self._read_body()
        if action == "git-receive-pack":
            print(f"[grimoire] {self.client_address[0]} is writing in {os.path.basename(repo)}", flush=True)
        out = subprocess.run(["git", action[4:], "--stateless-rpc", repo], input=data, capture_output=True, env=self._env()).stdout
        self._reply(200, f"application/x-{action}-result", out)


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"[grimoire] open on :{PORT} for {ROOT}", flush=True)
    Server(("", PORT), Handler).serve_forever()
    sys.exit(0)
