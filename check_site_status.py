#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from urllib.parse import urljoin
from urllib.parse import urlparse
from urllib.request import urlopen


def main() -> int:
    if len(sys.argv) < 2:
        print("No website address was provided.")
        return 1

    site_url = sys.argv[1]
    parsed = urlparse(site_url)
    last_path = parsed.path.rsplit("/", 1)[-1]
    base_url = site_url if site_url.endswith("/") or "." in last_path else site_url + "/"
    status_url = urljoin(base_url, "status.json")

    try:
        with urlopen(status_url, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except Exception:
        print("Cannot verify this website status. Please check the website address or network connection.")
        return 1

    if not payload.get("enabled"):
        print(payload.get("message") or "This service is no longer available.")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
