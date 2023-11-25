#!/bin/bash

# Function to perform cleanup actions
cleanup() {
    echo "Cleaning up resources..."
    limactl stop falco-k8s
    limactl delete falco-k8s
    echo "Cleanup completed.Revert to your original kubeconfig by closing the current shell session or by running 'unset KUBECONFIG'."
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

# Check if the first argument is 'cleanup'
if [ "$1" == "cleanup" ]; then
    cleanup
    exit 0
fi

# Stop script on any error
set -e

# Prompt for GitHub repository details
read -p "Enter your GitHub repository URL: " git_repo_url
read -p "Enter your GitHub username: " git_username
read -sp "Enter your GitHub password: " git_password
echo

# Install necessary tools
echo "Installing lima, helm, and argocd..."
brew install lima helm argocd

# Deploy Kubernetes cluster using lima
echo "Deploying Kubernetes cluster with Lima..."
limactl start --name=falco-k8s template://k8s --tty=false
setup_kubeconfig


# Install ArgoCD using Helm
echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argo --create-namespace

# Install Argo Workflows using Helm
echo "Installing Argo Workflows..."
helm install argo-workflows argo/argo-workflows -n argo

# Start the ArgoCD API server
echo "Starting ArgoCD API server..."
kubectl port-forward svc/argocd-server -n argo 8080:443 &

# Change ArgoCD admin password
echo "Changing ArgoCD admin password..."
initial_password=$(kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Initial password: $initial_password"
argocd login localhost:8080 --username admin --password "$initial_password" --insecure
read -sp "Enter new password for ArgoCD 'admin' account: " new_password
echo
argocd account update-password --current-password "$initial_password" --new-password "$new_password"

# Create a sample ArgoCD app
echo "Creating a sample ArgoCD app..."
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

# Download the Falco chart
echo "Downloading Falco Helm chart..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm pull falcosecurity/falco --untar

# Modify Falco values.yaml for eBPF and enable Falco Sidekick
echo "Modifying Falco values.yaml..."
sed -i '' 's/driver:\n  kind: module/driver:\n  kind: ebpf/' falco/values.yaml
sed -i '' 's/falcosidekick:\n  enabled: false/falcosidekick:\n  enabled: true/' falco/values.yaml

# Commit changes to GitHub
echo "Committing changes to GitHub..."
git add falco/values.yaml
git commit -m "Update Falco configuration"
git push

# Add the repo to ArgoCD
echo "Adding repo to ArgoCD..."
argocd repo add "$git_repo_url" --username "$git_username" --password "$git_password"

# Deploy Falco as an ArgoCD app
echo "Deploying Falco as an ArgoCD app..."
argocd app create falco \
  --repo "$git_repo_url" \
  --path falco \
  --dest-namespace falco \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated

echo "Deployment completed successfully."