#!/bin/bash
set -e

PROJECT_ID="utopian-planet-485618-b3"
REGION="us-central1"
ZONE="us-central1-a"
BUCKET_NAME="bu-cs528-architkk"
DB_INSTANCE="hw5-db"
DB_NAME="hw5"

echo "========================================"
echo "HW5 Setup — Project: $PROJECT_ID"
echo "========================================"

# ---- Step 1: Enable APIs ----
echo "[1/9] Enabling required APIs..."
gcloud services enable compute.googleapis.com \
    storage.googleapis.com \
    logging.googleapis.com \
    sqladmin.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudscheduler.googleapis.com \
    --project=$PROJECT_ID

# ---- Step 2: Service account ----
echo "[2/9] Creating service account..."
gcloud iam service-accounts create hw5-webserver-sa \
    --display-name="HW5 Web Server SA" \
    --project=$PROJECT_ID 2>/dev/null || echo "SA already exists, continuing..."

SA_EMAIL="hw5-webserver-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectViewer" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/logging.logWriter" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/cloudsql.admin" --quiet

# ---- Step 3: Start or create Cloud SQL ----
echo "[3/9] Checking Cloud SQL instance..."
DB_STATUS=$(gcloud sql instances describe $DB_INSTANCE \
    --project=$PROJECT_ID \
    --format="value(state)" 2>/dev/null || echo "NOTFOUND")

if [ "$DB_STATUS" = "NOTFOUND" ]; then
    echo "Creating Cloud SQL instance..."
    gcloud sql instances create $DB_INSTANCE \
        --database-version=MYSQL_8_0 \
        --tier=db-f1-micro \
        --region=$REGION \
        --storage-type=SSD \
        --storage-size=10GB \
        --availability-type=ZONAL \
        --root-password=hw5password123 \
        --project=$PROJECT_ID
    DB_HOST=$(gcloud sql instances describe $DB_INSTANCE \
        --project=$PROJECT_ID \
        --format="value(ipAddresses[0].ipAddress)")
    echo "Setting up schema..."
    pip3 install mysql-connector-python --break-system-packages -q
    DB_HOST=$DB_HOST DB_USER=root DB_PASS=hw5password123 DB_NAME=$DB_NAME \
        python3 setup_schema.py
else
    echo "Starting existing Cloud SQL instance..."
    gcloud sql instances patch $DB_INSTANCE \
        --activation-policy=ALWAYS \
        --project=$PROJECT_ID --quiet
    sleep 30
    DB_HOST=$(gcloud sql instances describe $DB_INSTANCE \
        --project=$PROJECT_ID \
        --format="value(ipAddresses[0].ipAddress)")
    echo "Cloud SQL running. DB_HOST=$DB_HOST"
fi

# ---- Step 4: Reserve static IP ----
echo "[4/9] Reserving static IP for web server..."
gcloud compute addresses create hw5-webserver-ip \
    --region=$REGION \
    --project=$PROJECT_ID 2>/dev/null || echo "Static IP already exists, continuing..."

STATIC_IP=$(gcloud compute addresses describe hw5-webserver-ip \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(address)")
echo "Static IP: $STATIC_IP"

# ---- Step 5: Create forbidden VM ----
echo "[5/9] Creating forbidden service VM..."
gcloud compute instances create hw5-forbidden-vm \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata-from-file startup-script=startup_forbidden.sh \
    --tags=forbidden-service \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --project=$PROJECT_ID 2>/dev/null || echo "Forbidden VM already exists, continuing..."

echo "Waiting 30s for forbidden VM IP..."
sleep 30
FORBIDDEN_IP=$(gcloud compute instances describe hw5-forbidden-vm \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
echo "Forbidden VM IP: $FORBIDDEN_IP"

# ---- Step 6: Authorize IPs in Cloud SQL ----
echo "[6/9] Authorizing IPs in Cloud SQL..."
gcloud sql instances patch $DB_INSTANCE \
    --authorized-networks=$STATIC_IP \
    --project=$PROJECT_ID --quiet

# ---- Step 7: Create web server VM ----
echo "[7/9] Creating web server VM..."
gcloud compute instances create hw5-webserver-vm \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --address=$STATIC_IP \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --metadata=bucket-name=${BUCKET_NAME},forbidden-service-url=http://${FORBIDDEN_IP}:8081/forbidden,db-host=${DB_HOST} \
    --metadata-from-file startup-script=startup.sh \
    --tags=http-server \
    --project=$PROJECT_ID 2>/dev/null || echo "Web server VM already exists, continuing..."

# ---- Step 8: Firewall rules ----
echo "[8/9] Creating firewall rules..."
gcloud compute firewall-rules create hw5-allow-http \
    --allow=tcp:8080 \
    --target-tags=http-server \
    --project=$PROJECT_ID 2>/dev/null || echo "Firewall rule already exists."

gcloud compute firewall-rules create hw5-allow-forbidden \
    --allow=tcp:8081 \
    --target-tags=forbidden-service \
    --project=$PROJECT_ID 2>/dev/null || echo "Firewall rule already exists."

# ---- Step 9: Client VM ----
echo "[9/9] Creating client VM..."
gcloud compute instances create hw5-client-vm \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata-from-file startup-script=startup_client.sh \
    --service-account=$SA_EMAIL \
    --scopes=cloud-platform \
    --project=$PROJECT_ID 2>/dev/null || echo "Client VM already exists, continuing..."

echo ""
echo "========================================"
echo "Setup complete!"
echo "Web server IP: $STATIC_IP"
echo "DB Host:       $DB_HOST"
echo ""
echo "Wait ~3 minutes for VMs to finish, then test:"
echo "  curl http://${STATIC_IP}:8080/0.html"
echo "========================================"
