#!/usr/bin/env python3
import mysql.connector
import os
import sys

DB_HOST = os.environ.get("DB_HOST", "")
DB_USER = os.environ.get("DB_USER", "root")
DB_PASS = os.environ.get("DB_PASS", "hw5password123")
DB_NAME = os.environ.get("DB_NAME", "hw5")

conn = mysql.connector.connect(host=DB_HOST, user=DB_USER, password=DB_PASS)
cursor = conn.cursor()

cursor.execute(f"CREATE DATABASE IF NOT EXISTS {DB_NAME}")
cursor.execute(f"USE {DB_NAME}")

cursor.execute("""
CREATE TABLE IF NOT EXISTS requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country VARCHAR(100),
    client_ip VARCHAR(45),
    gender VARCHAR(10),
    age INT,
    income VARCHAR(50),
    is_banned BOOLEAN,
    time_of_day DATETIME,
    requested_file VARCHAR(255)
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS errors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    time_of_day DATETIME,
    requested_file VARCHAR(255),
    error_code INT
)
""")

conn.commit()
cursor.close()
conn.close()
print("Schema created successfully!")
