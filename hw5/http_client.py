#!/usr/bin/env python3
import urllib.request
import sys
import random

if len(sys.argv) < 2:
    print("Usage: python3 http_client.py <server_ip> [num_requests] [seed]")
    sys.exit(1)

SERVER_IP = sys.argv[1]
NUM_REQUESTS = int(sys.argv[2]) if len(sys.argv) > 2 else 100
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 42

random.seed(SEED)

BASE_URL = f"http://{SERVER_IP}:8080"

COUNTRIES = [
    "usa", "canada", "uk", "germany", "france", "australia",
    "iran", "cuba", "syria", "north korea", "myanmar",
    "japan", "brazil", "india", "mexico", "italy"
]
GENDERS = ["Male", "Female"]
INCOME_GROUPS = ["10000", "30000", "50000", "75000", "100000", "150000"]
BANNED_COUNTRIES = {"iran", "cuba", "syria", "north korea", "myanmar", "iraq", "libya", "sudan", "zimbabwe"}

success = 0
errors = 0

for i in range(NUM_REQUESTS):
    file_index = random.randint(0, 19999)
    filename = f"{file_index}.html"
    url = f"{BASE_URL}/{filename}"

    country = random.choice(COUNTRIES)
    gender = random.choice(GENDERS)
    age = random.randint(18, 80)
    income = random.choice(INCOME_GROUPS)
    is_banned = str(country in BANNED_COUNTRIES).lower()

    try:
        req = urllib.request.Request(url)
        req.add_header("X-country", country)
        req.add_header("X-gender", gender)
        req.add_header("X-age", str(age))
        req.add_header("X-income", income)
        req.add_header("X-is-banned", is_banned)

        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
            resp.read()
            if status == 200:
                success += 1
            else:
                errors += 1
    except urllib.error.HTTPError as e:
        errors += 1
    except Exception as e:
        errors += 1

    if i % 1000 == 0:
        print(f"Progress: {i}/{NUM_REQUESTS} — success={success} errors={errors}", flush=True)

print(f"\nDone: {success} success, {errors} errors out of {NUM_REQUESTS} requests")
