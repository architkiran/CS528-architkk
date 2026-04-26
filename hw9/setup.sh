#!/bin/bash
set -e

PROJECT_ID="utopian-planet-485618-b3"
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="hw9-cluster"
REPO_NAME="hw9-repo"
IMAGE_NAME="hw9-webserver"
FORBIDDEN_VM="hw9-forbidden-vm"
BUCKET_NAME="bu-cs528-architkk"

echo "========================================"
echo "HW9 Setup Starting..."
echo "========================================"

# ── APIs ──────────────────────────────────────────────────────────────────────
echo "Enabling APIs..."
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    artifactregistry.googleapis.com \
    storage.googleapis.com \
    logging.googleapis.com \
    cloudbuild.googleapis.com \
    --project=$PROJECT_ID

# ── Artifact Registry ─────────────────────────────────────────────────────────
echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT_ID 2>/dev/null || echo "Repo already exists, skipping."

IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:latest"

# ── Build & Push via Cloud Build (avoids local Docker network issues) ─────────
echo "Building and pushing Docker image via Cloud Build..."
gcloud builds submit . \
    --tag=$IMAGE_URI \
    --project=$PROJECT_ID

# ── GKE Cluster ───────────────────────────────────────────────────────────────
echo "Creating GKE cluster (this takes ~3-5 minutes)..."
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=1 \
    --machine-type=e2-small \
    --scopes=storage-ro,logging-write,cloud-platform \
    --project=$PROJECT_ID 2>/dev/null || echo "Cluster already exists, skipping."

# ── Get credentials ───────────────────────────────────────────────────────────
echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID

# ── Create forbidden VM ───────────────────────────────────────────────────────
echo "Creating forbidden VM..."
gcloud compute instances create $FORBIDDEN_VM \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --scopes=logging-write,cloud-platform \
    --metadata-from-file startup-script=startup.sh \
    --project=$PROJECT_ID 2>/dev/null || echo "Forbidden VM already exists, skipping."

echo "Waiting 30s for forbidden VM to get external IP..."
sleep 30

FORBIDDEN_IP=$(gcloud compute instances describe $FORBIDDEN_VM \
    --zone=$ZONE \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
    --project=$PROJECT_ID)

echo "Forbidden VM IP: $FORBIDDEN_IP"

# ── Deploy to GKE ─────────────────────────────────────────────────────────────
echo "Deploying to GKE..."
sed -e "s|PLACEHOLDER_IMAGE|$IMAGE_URI|g" \
    -e "s|PLACEHOLDER_FORBIDDEN_URL|http://$FORBIDDEN_IP:8081|g" \
    deployment.yaml | kubectl apply -f -

echo "Waiting for deployment to roll out..."
kubectl rollout status deployment/hw9-webserver

echo "Waiting for LoadBalancer external IP (up to 5 minutes)..."
for i in $(seq 1 20); do
    EXTERNAL_IP=$(kubectl get svc hw9-webserver-svc \
        --output jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo "Still waiting... ($i/20)"
    sleep 15
done

# ── Firewall rule for forbidden service ───────────────────────────────────────
echo "Creating firewall rules..."
gcloud compute firewall-rules create hw9-allow-forbidden \
    --allow=tcp:8081 \
    --target-tags=hw9-forbidden \
    --project=$PROJECT_ID 2>/dev/null || echo "Firewall rule already exists."

gcloud compute instances add-tags $FORBIDDEN_VM \
    --tags=hw9-forbidden \
    --zone=$ZONE \
    --project=$PROJECT_ID

echo ""
echo "========================================"
echo "HW9 Setup Complete!"
echo "Web server (GKE) external IP: $EXTERNAL_IP"
echo "Forbidden VM IP: $FORBIDDEN_IP"
echo "Test with: curl http://$EXTERNAL_IP:8080/file_0001.html"
echo "========================================"
