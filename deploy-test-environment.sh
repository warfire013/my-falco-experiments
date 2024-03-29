#!/bin/bash

# Function to perform cleanup actions
cleanup() {
    echo "Cleaning up resources..."
    colima stop
    colima delete
    colima prune 
    echo "Cleanup completed. Revert to your original kubeconfig by closing the current shell session or by running 'unset KUBECONFIG'."
}

# Function to install kernel headers in Colima VM
install_kernel_headers() {
    echo "Installing Linux kernel headers in Colima VM..."
    colima ssh << EOF
    sudo apt-get update
    sudo apt-get install -y linux-headers-\$(uname -r)
EOF
    echo "Kernel headers installed."
}


# Check if the first argument is 'cleanup' and execute cleanup if true
if [ "$1" == "cleanup" ]; then
    cleanup
    exit 0
fi

# Function to check if ArgoCD is ready
wait_for_argocd() {
    echo "Waiting for ArgoCD to be ready..."
    end=$((SECONDS+120))
    while [ $SECONDS -lt $end ]; do
        if kubectl get pods -n argo -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].status.phase}" | grep -q Running; then
            echo "ArgoCD is ready."
            return 0
        fi
        echo "Waiting for ArgoCD server to start..."
        sleep 10
    done
    echo "ArgoCD did not become ready in time. Triggering cleanup."
    cleanup
    exit 1
}

# Error handling: Exit immediately if a command exits with a non-zero status.
set -e
trap cleanup ERR

# Install necessary tools
echo "Installing colima, helm, argocd and argo workflow cli..."
brew install colima helm argo argocd

# Deploy Kubernetes cluster using Colima
echo "Deploying Kubernetes cluster with CoLima..."
colima start --runtime containerd --cpu 4 --memory 8 --disk 40 --kubernetes --dns "8.8.8.8"

# Install kernel headers in Colima VM
install_kernel_headers

# Install ArgoCD using Helm
echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argo --create-namespace
kubectl create ns falco
# Wait for ArgoCD to be ready
wait_for_argocd

# Start the ArgoCD API server
echo "Starting ArgoCD API server..."
kubectl port-forward svc/argocd-server -n argo 8080:443 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Change ArgoCD admin password
echo "Changing ArgoCD admin password..."
initial_password=$(kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Initial password: $initial_password"
argocd login localhost:8080 --username admin --password "$initial_password" --insecure
read -sp "Enter new password for ArgoCD 'admin' account: " new_password
echo
argocd account update-password --current-password "$initial_password" --new-password "$new_password"
argocd login localhost:8080 --password "$new_password" --username admin

# Add the repo to ArgoCD
echo "Adding repo to ArgoCD..."
argocd repo add "https://github.com/warfire013/my-falco-experiments.git"

# Deploying Argo workflows
echo "Deploying Argo Workflows..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argo-workflows argo/argo-workflows --namespace argo
echo "Argo Workflows deployment initiated."

# Create a sample ArgoCD app
echo "Creating a sample ArgoCD app..."
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

# Deploy Falco as an ArgoCD app
echo "Deploying Falco as an ArgoCD app..."
argocd app create falco \
  --repo "https://github.com/warfire013/my-falco-experiments.git" \
  --path falco \
  --dest-namespace falco \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated


argocd app sync guestbook
sleep 30
argocd app sync falco
echo "Falco app deployed"

echo "Deploying Falco Event Generator"
kubectl run falco-event-generator --namespace=falco --image=falcosecurity/event-generator --restart=Never --command -- sleep 100000

echo "Deploying custom webhook"
kubectl create configmap webhook-script --from-file=template-webhook.py --from-file=requirements.txt
kubectl apply -f webhook-deployment.yaml


# echo "Deploying Custom ArgoCD Workflow"
# kubectl create -f custom-rbac.yaml --namespace argo
# kubectl create -f custom-workflow-template.yaml 
# echo "Deployment completed successfully."
# echo "Argo Server External IP"
# kubectl --namespace argo get services -o wide | grep argo-workflows-server

# Add Grafana Helm repository
kubectl create ns monitoring
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "Grafana repository added."

# Deploy Loki
echo "Deploying Loki..."
helm install loki grafana/loki --namespace monitoring --values loki-config/values.yaml

# Deploy Promtail
echo "Deploying Promtail..."
helm install promtail grafana/promtail --namespace monitoring --set "loki.serviceName=loki"

# Deploy Grafana
echo "Deploying Grafana..."
helm install grafana grafana/grafana --namespace monitoring

# Retrieve Grafana admin password
echo "Retrieving Grafana admin password..."
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port-forward Grafana for immediate access
kubectl port-forward service/grafana 3000:80 -n monitoring > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
echo "Access Grafana at http://localhost:3000"
echo "Use the above password to log in to Grafana."

echo "Deployment complete. Check the services for readiness and visit Grafana for log visualization."
echo "If any of the web-ui does not work, refer the port-forward commands in README.md or commands above in the script."