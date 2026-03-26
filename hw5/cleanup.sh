#!/bin/bash
set -e

PROJECT_ID="utopian-planet-485618-b3"
REGION="us-central1"
ZONE="us-central1-a"

echo "========================================"
echo "HW5 Cleanup — Project: $PROJECT_ID"
echo "========================================"

# Stop Cloud SQL (do NOT delete)
echo "Stopping Cloud SQL instance..."
gcloud sql instances patch hw5-db \
    --activation-policy=NEVER \
    --project=$PROJECT_ID 2>/dev/null || echo "Cloud SQL already stopped or not found."

# Delete VMs
echo "Deleting VMs..."
gcloud compute instances delete hw5-webserver-vm --zone=$ZONE --project=$PROJECT_ID --quiet 2>/dev/null || echo "Web server VM not found."
gcloud compute instances delete hw5-forbidden-vm --zone=$ZONE --project=$PROJECT_ID --quiet 2>/dev/null || echo "Forbidden VM not found."
gcloud compute instances delete hw5-client-vm    --zone=$ZONE --project=$PROJECT_ID --quiet 2>/dev/null || echo "Client VM not found."

# Release static IP
echo "Releasing static IP..."
gcloud compute addresses delete hw5-webserver-ip --region=$REGION --project=$PROJECT_ID --quiet 2>/dev/null || echo "Static IP not found."

# Delete firewall rules
echo "Deleting firewall rules..."
gcloud compute firewall-rules delete hw5-allow-http      --project=$PROJECT_ID --quiet 2>/dev/null || echo "Not found."
gcloud compute firewall-rules delete hw5-allow-forbidden --project=$PROJECT_ID --quiet 2>/dev/null || echo "Not found."

echo ""
echo "========================================"
echo "Cleanup complete! Cloud SQL stopped (not deleted)."
echo "========================================"
