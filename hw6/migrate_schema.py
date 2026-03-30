#!/usr/bin/env python3
"""
migrate_schema.py
HW6: Convert HW5 schema to 3rd Normal Form.

3NF Violation in HW5:
  requests table has: client_ip -> country (transitive dependency)
  A non-key attribute (country) is determined by another non-key attribute (client_ip).
  Fix: extract ip_country(client_ip PK, country) table.
  requests.client_ip becomes a FK referencing ip_country.

NOTE: In our actual data, one IP maps to many countries because the client
simulates requests from different countries through the same IP. We still
normalize the schema as required, using the first country seen per IP (MIN).
"""

import mysql.connector
import os

DB_HOST = os.environ.get("DB_HOST", "34.57.20.253")
DB_USER = os.environ.get("DB_USER", "root")
DB_PASS = os.environ.get("DB_PASS", "hw5password123")
DB_NAME = os.environ.get("DB_NAME", "hw5")

def get_conn():
    return mysql.connector.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME
    )

def migrate():
    conn = get_conn()
    cursor = conn.cursor()

    print("=== HW6: 3NF Schema Migration ===\n")

    # Step 1: Create ip_country table
    print("Step 1: Creating ip_country table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS ip_country (
            client_ip VARCHAR(45) NOT NULL,
            country   VARCHAR(100) NOT NULL,
            PRIMARY KEY (client_ip)
        ) ENGINE=InnoDB;
    """)
    conn.commit()
    print("  Done.\n")

    # Step 2: Populate ip_country (one country per IP using MIN to satisfy GROUP BY)
    print("Step 2: Populating ip_country from requests...")
    cursor.execute("""
        INSERT IGNORE INTO ip_country (client_ip, country)
        SELECT client_ip, MIN(country)
        FROM requests
        WHERE client_ip IS NOT NULL
          AND country IS NOT NULL
          AND country != ''
        GROUP BY client_ip;
    """)
    conn.commit()
    cursor.execute("SELECT * FROM ip_country;")
    rows = cursor.fetchall()
    print(f"  Inserted {len(rows)} rows:")
    for row in rows:
        print(f"    {row[0]:20s} -> {row[1]}")
    print()

    # Step 3: Verify schema looks correct
    print("Step 3: Final schema verification:")
    for table in ["ip_country", "requests", "errors"]:
        cursor.execute(f"DESCRIBE {table};")
        cols = cursor.fetchall()
        print(f"\n  Table: {table}")
        for col in cols:
            print(f"    {col[0]:20s} {col[1]}")

    cursor.close()
    conn.close()
    print("\n=== Migration complete ===")

if __name__ == "__main__":
    migrate()
