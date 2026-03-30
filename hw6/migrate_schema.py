#!/usr/bin/env python3
"""
migrate_schema.py
HW6: Convert schema to 3rd Normal Form.

3NF Violation:
  request_logs table has: client_ip -> country (transitive dependency)
  A non-key attribute (country) is determined by another non-key
  attribute (client_ip), violating 3NF.

Fix:
  Extract ip_country(client_ip PK, country) lookup table.
  request_logs.client_ip becomes a FK referencing ip_country.

In the TA dataset: each IP maps to exactly 1 country (43,542 unique IPs).
In our HW5 data: one IP mapped to many countries (data collection issue).
"""

import mysql.connector
import os

DB_HOST = os.environ.get("DB_HOST", "34.57.20.253")
DB_USER = os.environ.get("DB_USER", "root")
DB_PASS = os.environ.get("DB_PASS", "hw5password123")
DB_NAME = os.environ.get("DB_NAME", "hw6data")

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
            client_ip VARCHAR(64) NOT NULL,
            country   VARCHAR(128) NOT NULL,
            PRIMARY KEY (client_ip)
        ) ENGINE=InnoDB;
    """)
    conn.commit()
    print("  Done.\n")

    # Step 2: Populate ip_country from request_logs
    print("Step 2: Populating ip_country from request_logs...")
    cursor.execute("""
        INSERT IGNORE INTO ip_country (client_ip, country)
        SELECT client_ip, MIN(country)
        FROM request_logs
        WHERE client_ip IS NOT NULL
          AND country IS NOT NULL
          AND country != ''
        GROUP BY client_ip;
    """)
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM ip_country;")
    count = cursor.fetchone()[0]
    print(f"  Inserted {count} unique IP -> country mappings.\n")

    # Show sample
    cursor.execute("SELECT * FROM ip_country LIMIT 5;")
    rows = cursor.fetchall()
    print("  Sample rows:")
    for row in rows:
        print(f"    {row[0]:20s} -> {row[1]}")
    print()

    # Step 3: Verify schema
    print("Step 3: Final schema verification:")
    for table in ["ip_country", "request_logs", "failed_request_logs"]:
        try:
            cursor.execute(f"DESCRIBE {table};")
            cols = cursor.fetchall()
            print(f"\n  Table: {table}")
            for col in cols:
                print(f"    {col[0]:20s} {col[1]}")
        except Exception as e:
            print(f"\n  Table {table}: {e}")

    cursor.close()
    conn.close()
    print("\n=== Migration complete ===")

if __name__ == "__main__":
    migrate()
