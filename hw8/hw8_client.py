#!/usr/bin/env python3
"""
HW8 Client — sends one request per second to the load balancer,
prints the X-Zone header so you can watch failover in real time.

Usage:
    python3 hw8_client.py --server <LB_IP> --port 8080
"""

import argparse
import time
import urllib.request
import urllib.error
import random
from datetime import datetime

COUNTRIES = [
    "united states", "canada", "united kingdom", "germany", "france",
    "australia", "japan", "brazil", "india", "mexico",
    "north korea", "iran", "cuba", "myanmar", "iraq",
    "libya", "sudan", "zimbabwe", "syria"
]
GENDERS = ["male", "female"]

def make_headers():
    return {
        "X-country": random.choice(COUNTRIES),
        "X-gender":  random.choice(GENDERS),
        "X-age":     str(random.randint(18, 80)),
        "X-income":  str(random.randint(20000, 200000)),
        "X-ip":      f"{random.randint(1,254)}.{random.randint(0,254)}.{random.randint(0,254)}.{random.randint(1,254)}",
    }

def run(server_ip, port, filename, interval, seed):
    if seed is not None:
        random.seed(seed)

    base_url = f"http://{server_ip}:{port}/{filename}"
    zone_counts = {}

    print(f"Sending requests to {base_url} every {interval}s — Ctrl-C to stop")
    print(f"{'Time':<12} {'Status':<8} {'Zone':<20} {'Country':<20}")
    print("-" * 62)

    while True:
        headers = make_headers()
        ts = datetime.now().strftime("%H:%M:%S")
        try:
            req = urllib.request.Request(base_url, headers=headers)
            with urllib.request.urlopen(req, timeout=5) as resp:
                status = resp.status
                zone   = resp.headers.get("X-Zone", "N/A")
        except urllib.error.HTTPError as e:
            status = e.code
            zone   = e.headers.get("X-Zone", "N/A") if e.headers else "N/A"
        except urllib.error.URLError as e:
            status = "ERR"
            zone   = "UNREACHABLE"

        zone_counts[zone] = zone_counts.get(zone, 0) + 1
        print(f"{ts:<12} {str(status):<8} {zone:<20} {headers['X-country']:<20}")

        time.sleep(interval)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server",   required=True)
    parser.add_argument("--port",     default=8080, type=int)
    parser.add_argument("--file",     default="0.html")
    parser.add_argument("--interval", default=1.0,  type=float)
    parser.add_argument("--seed",     default=None, type=int)
    args = parser.parse_args()

    try:
        run(args.server, args.port, args.file, args.interval, args.seed)
    except KeyboardInterrupt:
        print("\nStopped.")

if __name__ == "__main__":
    main()
