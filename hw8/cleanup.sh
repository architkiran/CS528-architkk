#!/bin/bash
PROJECT_ID="utopian-planet-485618-b3"
ZONE_A="us-south1-b"
ZONE_B="us-south1-c"
FORBIDDEN_ZONE="us-south1-a"

echo "========================================"
echo "HW8 Cleanup — Project: $PROJECT_ID"
echo "========================================"

echo "Removing forwarding rule..."
gcloud compute forwarding-rules delete hw8-forwarding-rule \
    --global --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Removing TCP proxy..."
gcloud compute target-tcp-proxies delete hw8-tcp-proxy \
    --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Removing backend service..."
gcloud compute backend-services delete hw8-backend-service \
    --global --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Removing health check..."
gcloud compute health-checks delete hw8-health-check \
    --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Removing instance groups..."
gcloud compute instance-groups unmanaged delete hw8-ig-zone-b \
    --zone=$ZONE_A --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute instance-groups unmanaged delete hw8-ig-zone-c \
    --zone=$ZONE_B --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Deleting VMs..."
gcloud compute instances delete hw8-webserver-vm1 \
    --zone=$ZONE_A --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute instances delete hw8-webserver-vm2 \
    --zone=$ZONE_B --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute instances delete hw8-forbidden-vm \
    --zone=$FORBIDDEN_ZONE --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Releasing static IP..."
gcloud compute addresses delete hw8-lb-ip \
    --global --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Deleting Cloud NAT and router..."
gcloud compute routers nats delete hw8-nat --router=hw8-router --region=us-south1 --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute routers delete hw8-router --region=us-south1 --quiet --project=$PROJECT_ID 2>/dev/null || true

echo "Deleting firewall rules..."
gcloud compute firewall-rules delete hw8-allow-http \
    --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute firewall-rules delete hw8-allow-forbidden \
    --quiet --project=$PROJECT_ID 2>/dev/null || true
gcloud compute firewall-rules delete hw8-allow-health-checks \
    --quiet --project=$PROJECT_ID 2>/dev/null || true

echo ""
echo "========================================"
echo "HW8 Cleanup complete!"
echo "========================================"
