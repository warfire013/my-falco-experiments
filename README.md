# Kubernetes Lab Environment Setup with ArgoCD, Argo Workflows, and Falco

## Overview

This project sets up a Kubernetes lab environment on a MacOS system using Lima, with ArgoCD and Argo Workflows for application deployment and workflow management, respectively. Additionally, it incorporates Falco for runtime security monitoring, along with Falco Sidekick for handling alerts.

### Goals

1. Deploy a local Kubernetes cluster using Lima.
2. Install and configure ArgoCD for continuous deployment.
3. Set up Argo Workflows for automated workflow management.
4. Integrate Falco for security monitoring, with Falco Sidekick for alert management.

## Prerequisites

1. MacOS system
2. Brew package manager installed [Brew Installation Guide](https://brew.sh/)
3. Access to a GitHub repository

## Tools Installed

1. Lima: Lightweight VMs for MacOS [Lima](https://lima-vm.io/)
2. Helm: Package manager for Kubernetes [Helm Documentation](https://helm.sh/docs/)
3. ArgoCD CLI: Command-line tool for ArgoCD [ArgoCD CLI Documentation](https://argo-cd.readthedocs.io/en/stable/getting_started/)
4. Kubectl: Command-line tool for Kubernetes [Kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)

## Deployment

A script (deploy-test-environment.sh) is provided to automate the deployment process. It performs the following actions:

1. Installs Lima, Helm, and ArgoCD CLI using Brew.
2. Deploys a Kubernetes cluster using Lima.
3. Installs ArgoCD and Argo Workflows using Helm.
4. Sets up a separate kubeconfig for the Lima environment.
5. Deploys a sample application using ArgoCD.
6. Configures and deploys Falco with Falco Sidekick for security monitoring.

**To run the deployment, execute:**
`bash

./deploy-test-environment.sh
`

**Cleanup**

To clean up and remove the deployed resources, use the cleanup argument with the script:

`
bash

./deploy-test-environment.sh cleanup
`

This will stop and delete the Lima VM and revert the Kubernetes context to the original configuration.

**Considerations**
- The script creates a separate kubeconfig to avoid interference with existing Kubernetes configurations.
- Ensure that the GitHub repository URL, username, and password are correctly provided when prompted.
- For accessing the ArgoCD UI, port-forwarding needs to be set up separately.

### Documentation Links

[Deploying Falco using Lima](https://falco.org/blog/falco-apple-silicon/#falco-on-m1-on-kubernetes)
[ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[Argo Workflows](https://github.com/argoproj/argo-workflows/blob/master/docs/quick-start.md)
[Falco Sidekick Response Engine](https://falco.org/blog/falcosidekick-response-engine-part-5-argo/)