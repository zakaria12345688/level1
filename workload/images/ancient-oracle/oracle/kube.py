"""
A small Kubernetes API client for use inside the cluster.

It authenticates with the pod's service account token and trusts the
cluster CA, both mounted by Kubernetes. Only the standard library is used,
so the image stays small.
"""

import email.utils
import json
import os
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

from . import shaping


SA_DIR = "/var/run/secrets/kubernetes.io/serviceaccount"


class KubeError(Exception):
    """The API server refused or failed a request."""

    def __init__(self, status, message):
        super().__init__(f"{status}: {message}")
        self.status = status


class Kube:

    def __init__(self):
        host = os.environ.get(
            "KUBERNETES_SERVICE_HOST", "kubernetes.default.svc"
        )
        port = os.environ.get("KUBERNETES_SERVICE_PORT", "443")

        if ":" in host:  # IPv6
            host = f"[{host}]"

        self.base = f"https://{host}:{port}"

        ca = os.path.join(SA_DIR, "ca.crt")
        self.ctx = ssl.create_default_context(
            cafile=ca if os.path.exists(ca) else None
        )

        # Pods drift; the API server's clock is the one the realm agrees on.
        # Every response carries it in its Date header.
        self.skew = 0.0

    def _token(self):
        # Re-read on every call: projected tokens are rotated by the kubelet.
        try:
            with open(os.path.join(SA_DIR, "token")) as f:
                return f.read().strip()
        except OSError as e:
            raise KubeError(
                401, f"no service account token: {e}"
            ) from None

    def _observe_clock(self, headers):
        date = headers.get("Date")
        if not date:
            return

        try:
            server = email.utils.parsedate_to_datetime(date).timestamp()
        except (TypeError, ValueError):
            return

        self.skew = server - time.time()

    def now(self):
        """Seconds since the epoch, by the API server's clock."""
        return time.time() + self.skew

    def realm_hour(self):
        """The hour of day in the realm's time zone (TZ), as a float."""
        t = time.localtime(self.now())
        return t.tm_hour + t.tm_min / 60

    def request(self, path, params=None, raw=False):
        url = self.base + path
        if params:
            url += "?" + urllib.parse.urlencode({
                k: v
                for k, v in params.items()
                if v not in (None, "")
            })

        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {self._token()}",
                "Accept": "text/plain" if raw else "application/json",
            },
        )

        try:
            with urllib.request.urlopen(
                req, context=self.ctx, timeout=15
            ) as r:
                self._observe_clock(r.headers)
                body = r.read()

        except urllib.error.HTTPError as e:
            self._observe_clock(e.headers)
            detail = e.read().decode(errors="replace")
            try:
                detail = json.loads(detail).get("message", detail)
            except ValueError:
                pass
            raise KubeError(e.code, detail) from None

        except urllib.error.URLError as e:
            raise KubeError(
                503, f"API server unreachable: {e.reason}"
            ) from None

        text = body.decode(errors="replace")
        return text if raw else json.loads(text)

    def items(self, path, params=None):
        """The items of a list call, ordered by relevance for the model."""
        data = self.request(path, params)
        return shaping.settle(
            data.get("items") or [],
            shaping.pressure(self.realm_hour()),
        )
