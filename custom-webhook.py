"""from flask import Flask, request, jsonify
import requests
import os
import json

app = Flask(__name__)

# Environment variables or default values
ARGO_WORKFLOW_API = os.environ.get("ARGO_WORKFLOW_API", "http://argo-workflows-server.argo.svc.cluster.local:2746/api/v1/workflows/argo")

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    data = request.json
    print("Received alert:", json.dumps(data, indent=4))

    # Check for critical severity
    if data.get('priority') == 'Critical':
        pod_name = data.get('output_fields', {}).get('k8s.pod.name')
        if pod_name:
            print(f"Triggering workflow for pod: {pod_name}")
            # Trigger Argo Workflow
            response = requests.post(
                ARGO_WORKFLOW_API,
                json={
                    "parameters": {
                        "pod-name": pod_name
                    }
                }
            )
            return jsonify({"status": "Workflow triggered", "argo_response": response.json()}), response.status_code
    else:
        return jsonify({"status": "Alert received, but not critical"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)"""
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
            
            # Define the workflow with the pod name
            workflow = {
                "apiVersion": "argoproj.io/v1alpha1",
                "kind": "Workflow",
                "metadata": {
                    "generateName": "falco-alert-response-"
                },
                "spec": {
                    "serviceAccountName": "pod-deleter",
                    "entrypoint": "respond-to-alert",
                    "arguments": {
                        "parameters": [
                            {"name": "pod-name", "value": pod_name}
                        ]
                    },
                    "templates": [
                        {
                            "name": "respond-to-alert",
                            "inputs": {
                                "parameters": [
                                    {"name": "pod-name"}
                                ]
                            },
                            "steps": [
                                [
                                    {
                                        "name": "delete-pod",
                                        "template": "delete-pod",
                                        "arguments": {
                                            "parameters": [
                                                {"name": "pod-name", "value": "{{inputs.parameters.pod-name}}"}
                                            ]
                                        }
                                    }
                                ]
                            ]
                        },
                        {
                            "name": "delete-pod",
                            "inputs": {
                                "parameters": [
                                    {"name": "pod-name"}
                                ]
                            },
                            "container": {
                                "image": "bitnami/kubectl:latest",
                                "command": ["sh", "-c"],
                                "args": ["kubectl delete pod {{inputs.parameters.pod-name}}"]
                            }
                        }
                    ]
                }
            }

            # Trigger Argo Workflow
            workflow_json = json.dumps(workflow)
            print(f"Sending workflow to Argo: {workflow_json}")
            #print(f"Workflow request to {ARGO_WORKFLOW_API} with headers: {headers} and body: {workflow_json}")
            #response = requests.post(ARGO_WORKFLOW_API, json=workflow, headers=headers)
            response = requests.post(ARGO_WORKFLOW_API, data=workflow_json, headers=headers)
            
            if response.status_code != 200:
                print(f"Error triggering workflow: {response}")
                return jsonify({"error": "Failed to trigger workflow", "argo_response": response.text}), response.status_code
                
            return jsonify({"status": "Workflow triggered", "argo_response": response.json()}), response.status_code
    else:
        return jsonify({"status": "Alert received, but not critical"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)