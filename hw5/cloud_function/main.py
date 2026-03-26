import functions_framework
from googleapiclient import discovery

PROJECT_ID = "utopian-planet-485618-b3"
INSTANCE_NAME = "hw5-db"

@functions_framework.http
def stop_sql_if_running(request):
    service = discovery.build('sqladmin', 'v1beta4')
    
    # Check current state
    instance = service.instances().get(
        project=PROJECT_ID,
        instance=INSTANCE_NAME
    ).execute()
    
    state = instance.get('state', '')
    print(f"Cloud SQL instance '{INSTANCE_NAME}' state: {state}")
    
    if state == 'RUNNABLE':
        # Stop it
        body = {"settings": {"activationPolicy": "NEVER"}}
        service.instances().patch(
            project=PROJECT_ID,
            instance=INSTANCE_NAME,
            body=body
        ).execute()
        return f"Stopped Cloud SQL instance '{INSTANCE_NAME}'", 200
    else:
        return f"Cloud SQL instance '{INSTANCE_NAME}' is already stopped (state={state})", 200
