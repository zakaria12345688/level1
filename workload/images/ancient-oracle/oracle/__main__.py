"""
Entry point: python3 -m oracle

Environment:
    ORACLE_PORT        listening port (8080)
    ORACLE_JOURNAL     journal file (/var/lib/oracle/journal.jsonl)
    ORACLE_HEARTBEAT   seconds between the Oracle's own check-ups of the
                       realm, 0 to disable (900)
    TZ                 the realm's time zone, for the journal's realm_time
"""

import os
import threading
import time

from . import server


HEARTBEAT_QUERIES = (
    ("list_nodes", {}),
    ("list_deployments", {}),
    ("list_pods", {"namespace": "scrolls"}),
)


def heartbeat(every):
    """
    Asks the Oracle the same questions at a steady pace, so the journal
    shows how the realm evolves.
    """
    time.sleep(30)

    while True:
        for name, args in HEARTBEAT_QUERIES:
            try:
                server.answer(name, args, "heartbeat")
            except Exception as e:  # never let the check-up kill the server
                print(f"[oracle] heartbeat {name} failed: {e}", flush=True)

        time.sleep(every)


def main():
    every = int(os.environ.get("ORACLE_HEARTBEAT", "900") or 0)

    if every > 0:
        threading.Thread(
            target=heartbeat, args=(every,), daemon=True
        ).start()

    server.serve(int(os.environ.get("ORACLE_PORT", "8080")))


if __name__ == "__main__":
    main()
