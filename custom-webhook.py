from flask import Flask, request, jsonify
import requests
import os
import json

app = Flask(__name__)

# Environment variables or default values
WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "your-secret-token")
print(os.environ.get("WEBHOOK_SECRET", "your-secret-token"))
ARGO_WORKFLOW_API = os.environ.get("ARGO_WORKFLOW_API", "http://argo-workflows-server.argo.svc.cluster.local:2746/api/v1/workflows/argo")

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    # Verify secret token for security
    if request.headers.get('Authorization') != WEBHOOK_SECRET:
        return jsonify({"error": "Unauthorized"}), 403

    data = request.json
    print("Received alert:", json.dumps(data, indent=4))

    # Check for critical severity and extract pod_name
    if 'CRITICAL' in data.get('output', '') and 'pod_name' in data:
        pod_name = data['pod_name']
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

    return jsonify({"status": "Alert received, but not critical or missing data"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
