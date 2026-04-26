#!/bin/bash

PROJECT_ID="utopian-planet-485618-b3"
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="hw9-cluster"
REPO_NAME="hw9-repo"
FORBIDDEN_VM="hw9-forbidden-vm"

echo "========================================"
echo "HW9 Cleanup Starting..."
echo "========================================"

# ── GKE resources ─────────────────────────────────────────────────────────────
echo "Deleting Kubernetes deployments..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE --project=$PROJECT_ID 2>/dev/null && \
kubectl delete -f deployment.yaml 2>/dev/null || true

# ── GKE Cluster ───────────────────────────────────────────────────────────────
echo "Deleting GKE cluster..."
gcloud container clusters delete $CLUSTER_NAME \
    --zone=$ZONE --quiet --project=$PROJECT_ID 2>/dev/null || true

# ── Forbidden VM ──────────────────────────────────────────────────────────────
echo "Deleting forbidden VM..."
gcloud compute instances delete $FORBIDDEN_VM \
    --zone=$ZONE --quiet --project=$PROJECT_ID 2>/dev/null || true

# ── Firewall rules ────────────────────────────────────────────────────────────
echo "Deleting firewall rules..."
gcloud compute firewall-rules delete hw9-allow-forbidden \
    --quiet --project=$PROJECT_ID 2>/dev/null || true

# ── Artifact Registry ─────────────────────────────────────────────────────────
echo "Deleting Artifact Registry repo..."
gcloud artifacts repositories delete $REPO_NAME \
    --location=$REGION --quiet --project=$PROJECT_ID 2>/dev/null || true

echo ""
echo "========================================"
echo "HW9 Cleanup Complete!"
echo "========================================"
