#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

PROJECT_ID="utopian-planet-485618-b3"
REGION="us-south1"
ZONE_A="us-south1-b"
ZONE_B="us-south1-c"
FORBIDDEN_ZONE="us-south1-a"
BUCKET_NAME="bu-cs528-architkk"
SA_EMAIL="hw4-webserver-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "========================================"
echo "HW8 Setup — Project: $PROJECT_ID"
echo "========================================"

echo "[1/10] Enabling APIs..."
gcloud services enable compute.googleapis.com \
    storage.googleapis.com \
    logging.googleapis.com \
    --project=$PROJECT_ID

echo "[2/10] Ensuring service account exists..."
gcloud iam service-accounts create hw4-webserver-sa \
    --display-name="HW4/HW8 Web Server SA" \
    --project=$PROJECT_ID 2>/dev/null || echo "  SA already exists, continuing..."

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectViewer" --quiet 2>/dev/null || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/logging.logWriter" --quiet 2>/dev/null || true

echo "[3/10] Creating forbidden service VM..."
gcloud compute instances create hw8-forbidden-vm \
    --zone=$FORBIDDEN_ZONE \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata-from-file startup-script=startup_forbidden.sh \
    --tags=forbidden-service \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "  Waiting 30s for forbidden VM IP..."
sleep 30

FORBIDDEN_IP=$(gcloud compute instances describe hw8-forbidden-vm \
    --zone=$FORBIDDEN_ZONE \
    --project=$PROJECT_ID \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
echo "  Forbidden service IP: $FORBIDDEN_IP"

echo "[4/10] Creating web server VM1 in $ZONE_A..."
gcloud compute instances create hw8-webserver-vm1 \
    --zone=$ZONE_A \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --metadata=bucket-name=${BUCKET_NAME},forbidden-service-url=http://${FORBIDDEN_IP}:8081/forbidden \
    --metadata-from-file startup-script=startup.sh \
    --tags=http-server \
    --no-address \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[5/10] Creating web server VM2 in $ZONE_B..."
gcloud compute instances create hw8-webserver-vm2 \
    --zone=$ZONE_B \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --metadata=bucket-name=${BUCKET_NAME},forbidden-service-url=http://${FORBIDDEN_IP}:8081/forbidden \
    --metadata-from-file startup-script=startup.sh \
    --tags=http-server \
    --no-address \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[6/10] Creating firewall rules..."
gcloud compute firewall-rules create hw8-allow-http \
    --allow=tcp:8080 \
    --target-tags=http-server \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute firewall-rules create hw8-allow-forbidden \
    --allow=tcp:8081 \
    --target-tags=forbidden-service \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute firewall-rules create hw8-allow-health-checks \
    --allow=tcp:8080 \
    --source-ranges=35.191.0.0/16,130.211.0.0/22 \
    --target-tags=http-server \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[7/10] Creating instance groups..."
gcloud compute instance-groups unmanaged create hw8-ig-zone-b \
    --zone=$ZONE_A --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute instance-groups unmanaged add-instances hw8-ig-zone-b \
    --instances=hw8-webserver-vm1 \
    --zone=$ZONE_A --project=$PROJECT_ID 2>/dev/null || echo "  Already added, continuing..."

gcloud compute instance-groups unmanaged create hw8-ig-zone-c \
    --zone=$ZONE_B --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute instance-groups unmanaged add-instances hw8-ig-zone-c \
    --instances=hw8-webserver-vm2 \
    --zone=$ZONE_B --project=$PROJECT_ID 2>/dev/null || echo "  Already added, continuing..."

gcloud compute instance-groups unmanaged set-named-ports hw8-ig-zone-b \
    --named-ports=http:8080 --zone=$ZONE_A --project=$PROJECT_ID

gcloud compute instance-groups unmanaged set-named-ports hw8-ig-zone-c \
    --named-ports=http:8080 --zone=$ZONE_B --project=$PROJECT_ID

echo "[8/10] Creating health check..."
gcloud compute health-checks create tcp hw8-health-check \
    --port=8080 \
    --check-interval=10s \
    --timeout=5s \
    --healthy-threshold=2 \
    --unhealthy-threshold=2 \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[9/10] Creating backend service and load balancer..."
gcloud compute backend-services create hw8-backend-service \
    --protocol=TCP \
    --health-checks=hw8-health-check \
    --global \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute backend-services add-backend hw8-backend-service \
    --instance-group=hw8-ig-zone-b \
    --instance-group-zone=$ZONE_A \
    --global --project=$PROJECT_ID 2>/dev/null || echo "  Already added, continuing..."

gcloud compute backend-services add-backend hw8-backend-service \
    --instance-group=hw8-ig-zone-c \
    --instance-group-zone=$ZONE_B \
    --global --project=$PROJECT_ID 2>/dev/null || echo "  Already added, continuing..."

gcloud compute target-tcp-proxies create hw8-tcp-proxy \
    --backend-service=hw8-backend-service \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

gcloud compute addresses create hw8-lb-ip \
    --ip-version=IPV4 \
    --global --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

LB_IP=$(gcloud compute addresses describe hw8-lb-ip \
    --global --project=$PROJECT_ID \
    --format="value(address)")
echo "  Load balancer IP: $LB_IP"

gcloud compute forwarding-rules create hw8-forwarding-rule \
    --global \
    --target-tcp-proxy=hw8-tcp-proxy \
    --address=$LB_IP \
    --ports=8080 \
    --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[9b/10] Creating Cloud NAT for outbound internet access..."
gcloud compute routers create hw8-router --region=us-south1 --network=default --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."
gcloud compute routers nats create hw8-nat --router=hw8-router --region=us-south1 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --project=$PROJECT_ID 2>/dev/null || echo "  Already exists, continuing..."

echo "[10/10] Waiting 90s for VMs and health checks to stabilise..."
sleep 90

echo ""
echo "========================================"
echo "HW8 Setup complete!"
echo "  Load Balancer IP : $LB_IP"
echo "  Forbidden svc IP : $FORBIDDEN_IP"
echo ""
echo "Test with: curl -v http://${LB_IP}:8080/0.html"
echo "========================================"
