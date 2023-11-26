#!/bin/bash

# Function to perform cleanup actions
cleanup() {
    echo "Cleaning up resources..."
    limactl stop falco-k8s
    limactl delete falco-k8s
    echo "Cleanup completed. Revert to your original kubeconfig by closing the current shell session or by running 'unset KUBECONFIG'."
}

# Function to set up Lima kubeconfig
setup_kubeconfig() {
    echo "Setting up separate kubeconfig for Lima..."
    mkdir -p "${HOME}/.lima/falco-k8s/conf"
    export KUBECONFIG="${HOME}/.lima/falco-k8s/conf/kubeconfig.yaml"
    limactl shell falco-k8s sudo cat /etc/kubernetes/admin.conf > $KUBECONFIG
    chmod 0600 $KUBECONFIG
    echo "Kubeconfig for Lima is set up. Run 'export KUBECONFIG=\$KUBECONFIG' in your shell to use it."
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
echo "Installing lima, helm, argocd and argo workflow cli..."
brew install lima helm argo argocd

# Deploy Kubernetes cluster using lima
echo "Deploying Kubernetes cluster with Lima..."
limactl start --name=falco-k8s template://k8s --tty=false
setup_kubeconfig

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
argocd login localhost:8080 --password "$new_password"

# Deploying Argo workflows
echo "Deploying Argo Workflows..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argo-workflows argo/argo-workflows --namespace argo
echo "Argo Workflows deployment initiated."

# Create a sample ArgoCD app
echo "Creating a sample ArgoCD app..."
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

# Add the repo to ArgoCD
echo "Adding repo to ArgoCD..."
argocd repo add "https://github.com/warfire013/my-falco-experiments.git"

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

echo "Deploying Custom ArgoCD Workflow"
kubectl create -f custom-workflow.yaml
echo "Deployment completed successfully."