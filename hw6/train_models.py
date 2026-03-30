#!/usr/bin/env python3
"""
train_models.py
HW6: Train 2 ML models on Cloud SQL data and write results to GCS.

Model 1: Predict country using all available fields (age, gender, income,
         hour, is_banned, requested_file_num).
         NOTE: IP alone cannot predict country in this dataset because only
         4 IPs exist and one IP (34.10.30.250) generated requests from all
         11 countries. We use all features instead and explain this in report.

Model 2: Predict income using age, gender, country, hour, is_banned.
"""

import os
import mysql.connector
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
from sklearn.preprocessing import LabelEncoder
from google.cloud import storage

# ── Config ────────────────────────────────────────────────────────────────────
DB_HOST  = os.environ.get("DB_HOST",  "34.57.20.253")
DB_USER  = os.environ.get("DB_USER",  "root")
DB_PASS  = os.environ.get("DB_PASS",  "hw5password123")
DB_NAME  = os.environ.get("DB_NAME",  "hw5")
BUCKET   = os.environ.get("BUCKET",   "bu-cs528-architkk")
SEED     = 42

# ── Load data ─────────────────────────────────────────────────────────────────
def load_data():
    print("Loading data from Cloud SQL...")
    conn = mysql.connector.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME
    )
    query = """
        SELECT
            client_ip,
            country,
            gender,
            age,
            income,
            is_banned,
            time_of_day,
            requested_file
        FROM requests
        WHERE gender  != ''
          AND income  != ''
          AND country != ''
    """
    df = pd.read_sql(query, conn)
    conn.close()
    print(f"  Loaded {len(df)} rows.\n")
    return df

# ── Feature engineering ───────────────────────────────────────────────────────
def engineer_features(df):
    df = df.copy()

    # Hour of day from time_of_day
    df["hour"] = pd.to_datetime(df["time_of_day"]).dt.hour

    # Extract number from requested_file (e.g. "3648.html" -> 3648)
    df["file_num"] = df["requested_file"].str.extract(r"(\d+)").astype(float).fillna(0)

    # Encode categorical columns
    le_gender  = LabelEncoder()
    le_country = LabelEncoder()
    le_income  = LabelEncoder()

    df["gender_enc"]  = le_gender.fit_transform(df["gender"])
    df["country_enc"] = le_country.fit_transform(df["country"])
    df["income_enc"]  = le_income.fit_transform(df["income"])

    df["is_banned"] = df["is_banned"].astype(int)

    return df, le_gender, le_country, le_income

# ── Upload to GCS ─────────────────────────────────────────────────────────────
def upload_to_gcs(content, filename):
    client = storage.Client()
    bucket = client.bucket(BUCKET)
    blob   = bucket.blob(f"hw6/{filename}")
    blob.upload_from_string(content, content_type="text/plain")
    print(f"  Uploaded -> gs://{BUCKET}/hw6/{filename}")

# ── Model 1: predict country ──────────────────────────────────────────────────
def model1_country(df, le_country):
    print("=" * 55)
    print("MODEL 1: Predict country from all features")
    print("=" * 55)
    print("NOTE: IP alone cannot determine country in this dataset.")
    print("      34.10.30.250 generated requests from all 11 countries.")
    print("      Using all available features instead.\n")

    features = ["age", "gender_enc", "income_enc", "is_banned", "hour", "file_num"]
    X = df[features].values
    y = df["country_enc"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=SEED, stratify=y
    )
    print(f"  Train: {len(X_train)} rows | Test: {len(X_test)} rows")

    clf = RandomForestClassifier(n_estimators=100, random_state=SEED, n_jobs=-1)
    print("  Training RandomForest...")
    clf.fit(X_train, y_train)

    y_pred = clf.predict(X_test)
    acc    = accuracy_score(y_test, y_pred)
    report = classification_report(
        y_test, y_pred,
        target_names=le_country.classes_,
        zero_division=0
    )

    print(f"\n  Accuracy: {acc*100:.2f}%")
    print(f"  {'PASS' if acc >= 0.99 else 'NOTE: below 99% — explained in report'}")
    print("\n  Classification Report:")
    print(report)

    # Build output text
    lines = [
        "HW6 - Model 1: Predict Country",
        f"Features: {features}",
        f"Train size: {len(X_train)} | Test size: {len(X_test)}",
        f"Accuracy: {acc*100:.2f}%",
        "",
        "NOTE: Only 4 unique IPs exist in this dataset. IP 34.10.30.250",
        "generated requests from all 11 countries, so IP alone cannot",
        "predict country. All available features were used instead.",
        "",
        "Classification Report:",
        report
    ]
    upload_to_gcs("\n".join(lines), "model1_country_predictions.txt")
    return acc

# ── Model 2: predict income ───────────────────────────────────────────────────
def model2_income(df, le_income):
    print("=" * 55)
    print("MODEL 2: Predict income from available features")
    print("=" * 55)

    features = ["age", "gender_enc", "country_enc", "is_banned", "hour", "file_num"]
    X = df[features].values
    y = df["income_enc"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=SEED, stratify=y
    )
    print(f"  Train: {len(X_train)} rows | Test: {len(X_test)} rows")
    print(f"  Income classes: {list(le_income.classes_)}\n")

    clf = RandomForestClassifier(
        n_estimators=200, max_depth=10,
        random_state=SEED, n_jobs=-1, class_weight="balanced"
    )
    print("  Training RandomForest...")
    clf.fit(X_train, y_train)

    y_pred = clf.predict(X_test)
    acc    = accuracy_score(y_test, y_pred)
    report = classification_report(
        y_test, y_pred,
        target_names=le_income.classes_,
        zero_division=0
    )

    print(f"\n  Accuracy: {acc*100:.2f}%")
    print(f"  {'PASS' if acc >= 0.40 else 'NOTE: below 40% — explained in report'}")
    print("\n  Classification Report:")
    print(report)

    # Feature importances
    importances = sorted(
        zip(features, clf.feature_importances_), key=lambda x: -x[1]
    )
    print("  Feature importances:")
    imp_lines = []
    for feat, imp in importances:
        line = f"    {feat:15s}: {imp:.4f}"
        print(line)
        imp_lines.append(line)

    lines = [
        "HW6 - Model 2: Predict Income",
        f"Features: {features}",
        f"Income classes: {list(le_income.classes_)}",
        f"Train size: {len(X_train)} | Test size: {len(X_test)}",
        f"Accuracy: {acc*100:.2f}%",
        "",
        "Classification Report:",
        report,
        "",
        "Feature Importances:",
    ] + imp_lines
    upload_to_gcs("\n".join(lines), "model2_income_predictions.txt")
    return acc

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print("\n" + "=" * 55)
    print("HW6: Machine Learning on Cloud SQL Data")
    print("=" * 55 + "\n")

    df, le_gender, le_country, le_income = engineer_features(load_data())

    acc1 = model1_country(df, le_country)
    print()
    acc2 = model2_income(df, le_income)

    summary = "\n".join([
        "=" * 55,
        "SUMMARY",
        "=" * 55,
        f"Model 1 (-> country): {acc1*100:.2f}%  {'PASS' if acc1>=0.99 else 'see report'}",
        f"Model 2 (-> income):  {acc2*100:.2f}%  {'PASS' if acc2>=0.40 else 'see report'}",
        "",
        f"Output files:",
        f"  gs://{BUCKET}/hw6/model1_country_predictions.txt",
        f"  gs://{BUCKET}/hw6/model2_income_predictions.txt",
    ])
    print("\n" + summary)
    upload_to_gcs(summary, "summary.txt")
    print("\nAll done!")

if __name__ == "__main__":
    main()
