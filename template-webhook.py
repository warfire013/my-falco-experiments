from flask import Flask, request, jsonify
import requests
import os
import json

app = Flask(__name__)

# Argo Workflow API Endpoint
ARGO_WORKFLOW_API = os.environ.get("ARGO_WORKFLOW_API", "http://argo-workflows-server.argo.svc.cluster.local:2746/api/v1/workflows/argo")

def get_service_account_token():
    """Retrieve the service account token from the Kubernetes environment."""
    try:
        with open('/var/run/secrets/kubernetes.io/serviceaccount/token', 'r') as token_file:
            return token_file.read().strip()
    except IOError as e:
        print(f"Error reading service account token: {e}")
        return None

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle incoming webhook requests."""
    # Retrieve the token for authorization
    token = get_service_account_token()
    if not token:
        return jsonify({"error": "Service account token not found"}), 500

    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

    data = request.json
    print("Received alert:", json.dumps(data, indent=4))

    # Check if the alert is of 'Warning' priority and has a pod name
    if data.get('priority') == 'Warning':
        pod_name = data.get('output_fields', {}).get('k8s.pod.name')
        if pod_name:
            print(f"Triggering workflow for pod: {pod_name}")

            # Construct the request to trigger the workflow template
            workflow_request = {
                "apiVersion": "argoproj.io/v1alpha1",
                "kind": "Workflow",
                "metadata": {
                    "generateName": "falco-alert-response-"
                },
                "spec": {
                    "workflowTemplateRef": {
                        "name": "falco-alert-response-template"
                    },
                    "arguments": {
                        "parameters": [
                            {"name": "pod-name", "value": pod_name}
                        ]
                    }
                }
            }

            # Send the request to Argo Workflow API
            response = requests.post(ARGO_WORKFLOW_API, json=workflow_request, headers=headers)
            if response.status_code != 200:
                print(f"Error triggering workflow: {response.text}")
                return jsonify({"error": "Failed to trigger workflow", "argo_response": response.text}), response.status_code

            return jsonify({"status": "Workflow triggered", "argo_response": response.json()}), response.status_code
    else:
        return jsonify({"status": "Alert received, but not critical"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
