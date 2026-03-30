#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

PROJECT_ID="utopian-planet-485618-b3"
ZONE="us-central1-c"
BUCKET="bu-cs528-architkk"
DB_INSTANCE="hw5-db"
DB_NAME="hw6data"
DB_USER="root"
DB_PASS="hw5password123"
VM_NAME="hw6-ml-vm"
MACHINE_TYPE="e2-medium"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

gcloud config set project $PROJECT_ID

echo "========================================"
echo "HW6 Setup — Project: $PROJECT_ID"
echo "========================================"

# ---- Step 1: Start Cloud SQL ----
echo "[1/6] Starting Cloud SQL instance..."
STATE=$(gcloud sql instances describe $DB_INSTANCE --format="value(state)" 2>/dev/null || echo "NOTFOUND")

if [ "$STATE" = "NOTFOUND" ]; then
    echo "ERROR: $DB_INSTANCE not found. Run HW5 setup first."
    exit 1
fi

if [ "$STATE" != "RUNNABLE" ]; then
    gcloud sql instances patch $DB_INSTANCE --activation-policy=ALWAYS --quiet
    echo "  Waiting for Cloud SQL..."
    for i in $(seq 1 24); do
        sleep 10
        STATE=$(gcloud sql instances describe $DB_INSTANCE --format="value(state)")
        echo "  ... state=$STATE ($((i*10))s)"
        [ "$STATE" = "RUNNABLE" ] && break
    done
fi

DB_IP=$(gcloud sql instances describe $DB_INSTANCE \
    --format="value(ipAddresses[0].ipAddress)")
echo "  Cloud SQL RUNNABLE at $DB_IP"

# ---- Step 2: Authorize all IPs for VM access ----
echo "[2/6] Updating Cloud SQL authorized networks..."
gcloud sql instances patch $DB_INSTANCE \
    --authorized-networks=0.0.0.0/0 \
    --quiet
echo "  Done."

# ---- Step 3: Import TA dataset if needed ----
echo "[3/6] Checking hw6data database..."
gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE \
    --project=$PROJECT_ID 2>/dev/null || echo "  Database already exists."

ROW_COUNT=$(mysql -h $DB_IP -u $DB_USER -p$DB_PASS $DB_NAME \
    -e "SELECT COUNT(*) FROM request_logs;" 2>/dev/null | tail -1 || echo "0")

if [ "$ROW_COUNT" -lt "1000" ] 2>/dev/null; then
    echo "  Importing TA dataset from gs://cs528-hw6-data/data.gz ..."
    gcloud sql import sql $DB_INSTANCE gs://cs528-hw6-data/data.gz \
        --database=$DB_NAME \
        --project=$PROJECT_ID
    echo "  Import complete."
else
    echo "  hw6data already has $ROW_COUNT rows, skipping import."
fi

# ---- Step 4: Upload scripts to GCS ----
echo "[4/6] Uploading scripts to GCS..."
gsutil cp $SCRIPT_DIR/migrate_schema.py gs://$BUCKET/hw6/migrate_schema.py
gsutil cp $SCRIPT_DIR/train_models.py   gs://$BUCKET/hw6/train_models.py
echo "  Done."

# ---- Step 5: Create ML VM ----
echo "[5/6] Creating ML VM: $VM_NAME..."
VM_EXISTS=$(gcloud compute instances list \
    --filter="name=$VM_NAME" \
    --format="value(name)" 2>/dev/null)

if [ -n "$VM_EXISTS" ]; then
    echo "  VM already exists, deleting..."
    gcloud compute instances delete $VM_NAME --zone=$ZONE --quiet
fi

cat > /tmp/hw6_startup.sh << STARTUP
#!/bin/bash
if [ -f /var/log/hw6_done ]; then
    echo "Already ran. Skipping."
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing packages..."
apt-get update -qq
apt-get install -y -qq python3-pip default-mysql-client
pip3 install --quiet mysql-connector-python pandas scikit-learn google-cloud-storage

echo "==> Downloading scripts from GCS..."
mkdir -p /opt/hw6
gsutil cp gs://${BUCKET}/hw6/migrate_schema.py /opt/hw6/
gsutil cp gs://${BUCKET}/hw6/train_models.py   /opt/hw6/

echo "==> Running 3NF migration..."
DB_HOST=${DB_IP} DB_USER=${DB_USER} DB_PASS=${DB_PASS} DB_NAME=${DB_NAME} \
    python3 /opt/hw6/migrate_schema.py 2>&1 | tee /var/log/hw6_migrate.log

echo "==> Training ML models..."
DB_HOST=${DB_IP} DB_USER=${DB_USER} DB_PASS=${DB_PASS} DB_NAME=${DB_NAME} \
    BUCKET=${BUCKET} \
    python3 /opt/hw6/train_models.py 2>&1 | tee /var/log/hw6_models.log

echo "==> Complete!"
touch /var/log/hw6_done
STARTUP

gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --scopes=cloud-platform \
    --service-account=hw5-webserver-sa@utopian-planet-485618-b3.iam.gserviceaccount.com \
    --metadata-from-file startup-script=/tmp/hw6_startup.sh

echo "  VM created. Waiting for models to finish..."

# ---- Step 6: Wait then print results ----
echo "[6/6] Waiting for completion (checking every 30s, max 20min)..."
for i in $(seq 1 40); do
    sleep 30
    echo "  ... ($((i*30))s elapsed)"
    DONE=$(gcloud compute ssh $VM_NAME --zone=$ZONE \
        --command="[ -f /var/log/hw6_done ] && echo yes || echo no" \
        --ssh-flag="-o StrictHostKeyChecking=no" \
        --quiet 2>/dev/null || echo "no")
    [ "$DONE" = "yes" ] && echo "  Models complete!" && break
done

echo ""
echo "======== GCS Output Files ========"
echo ""
echo "--- summary.txt ---"
gsutil cat gs://$BUCKET/hw6/summary.txt 2>/dev/null || echo "(not found)"
echo ""
echo "--- model1_country_predictions.txt (first 20 lines) ---"
gsutil cat gs://$BUCKET/hw6/model1_country_predictions.txt 2>/dev/null | head -20
echo ""
echo "--- model2_income_predictions.txt (first 20 lines) ---"
gsutil cat gs://$BUCKET/hw6/model2_income_predictions.txt 2>/dev/null | head -20

echo ""
echo "========================================"
echo "HW6 Setup Complete!"
echo "========================================"
