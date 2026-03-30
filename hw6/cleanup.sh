#!/bin/bash
set -e

PROJECT_ID="utopian-planet-485618-b3"
ZONE="us-central1-c"
DB_INSTANCE="hw5-db"
VM_NAME="hw6-ml-vm"
BUCKET="bu-cs528-architkk"

gcloud config set project $PROJECT_ID

echo "========================================"
echo "HW6 Cleanup — Project: $PROJECT_ID"
echo "========================================"

# ---- Print final outputs ----
echo "[0/3] Printing final GCS outputs..."
echo ""
echo "--- summary.txt ---"
gsutil cat gs://$BUCKET/hw6/summary.txt 2>/dev/null || echo "(not found)"
echo ""
echo "--- model1_country_predictions.txt ---"
gsutil cat gs://$BUCKET/hw6/model1_country_predictions.txt 2>/dev/null || echo "(not found)"
echo ""
echo "--- model2_income_predictions.txt ---"
gsutil cat gs://$BUCKET/hw6/model2_income_predictions.txt 2>/dev/null || echo "(not found)"

# ---- Delete VM ----
echo ""
echo "[1/3] Deleting VM: $VM_NAME..."
VM_EXISTS=$(gcloud compute instances list \
    --filter="name=$VM_NAME" \
    --format="value(name)" 2>/dev/null)
if [ -n "$VM_EXISTS" ]; then
    gcloud compute instances delete $VM_NAME --zone=$ZONE --quiet
    echo "  Deleted."
else
    echo "  Not found, skipping."
fi

# ---- Stop Cloud SQL (DO NOT DELETE) ----
echo "[2/3] Stopping Cloud SQL: $DB_INSTANCE..."
STATE=$(gcloud sql instances describe $DB_INSTANCE \
    --format="value(state)" 2>/dev/null || echo "NOTFOUND")
if [ "$STATE" = "RUNNABLE" ]; then
    gcloud sql instances patch $DB_INSTANCE --activation-policy=NEVER --quiet
    echo "  Stopped."
else
    echo "  Already stopped (state=$STATE)."
fi

echo "[3/3] Done!"
echo "========================================"
echo "HW6 Cleanup Complete!"
echo "========================================"
