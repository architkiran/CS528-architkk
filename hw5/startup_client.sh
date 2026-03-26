#!/bin/bash

if [ -f /var/log/startup_already_done ]; then
    echo "Startup already ran. Skipping."
    exit 0
fi

echo "Starting HW5 client VM startup script..."

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip

touch /var/log/startup_already_done
echo "HW5 client VM startup complete."
