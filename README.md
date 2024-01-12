# Kubernetes Lab Environment Setup with ArgoCD, Argo Workflows, Falco, Prometheus, and Grafana

## Overview

This project sets up a Kubernetes lab environment on a MacOS system using Colima, with ArgoCD and Argo Workflows for application deployment and workflow management. Additionally, it incorporates Falco for runtime security monitoring, along with Falco Sidekick for handling alerts, and integrates Prometheus and Grafana for monitoring and visualizing cluster metrics.

### Goals

1. Deploy a local Kubernetes cluster using Colima.
2. Install and configure ArgoCD for continuous deployment.
3. Set up Argo Workflows for automated workflow management.
4. Integrate Falco for security monitoring, with Falco Sidekick for alert management.
5. Deploy Prometheus and Grafana for cluster monitoring and data visualization.

## Prerequisites

1. MacOS system
2. Brew package manager installed [Brew Installation Guide](https://brew.sh/)
3. Access to a GitHub repository

## Tools Installed

1. Lima: Lightweight VMs for MacOS [Lima](https://lima-vm.io/)
2. Helm: Package manager for Kubernetes [Helm Documentation](https://helm.sh/docs/)
3. ArgoCD CLI: Command-line tool for ArgoCD [ArgoCD CLI Documentation](https://argo-cd.readthedocs.io/en/stable/getting_started/)
4. Kubectl: Command-line tool for Kubernetes [Kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
5. Prometheus: Monitoring system and time series database [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
6. Grafana: Open source platform for monitoring and observability [Grafana Documentation](https://grafana.com/docs/)

## Deployment
The script (deploy-test-environment.sh) deploys the Kubernetes Lab environment. It performs the following actions:

1. Installs Colima, Helm, ArgoCD CLI, Prometheus, and Grafana using Brew.
2. Deploys a Kubernetes cluster using Colima.
3. Installs ArgoCD and Argo Workflows using Helm.
4. Sets up a separate kubeconfig for the Colima environment.
5. Deploys a sample application using ArgoCD.
6. Configures and deploys Falco with Falco Sidekick for security monitoring.
7. Deploys Prometheus and Grafana for monitoring the cluster.

To run the deployment, execute:
`
sh deploy-test-environment.sh
`
## Accessing ArgoCD, Prometheus and Grafana UI
To access the ArgoCD, Prometheus and Grafana dashboards, port-forwarding commands are already executed in the script:
`
kubectl port-forward svc/argocd-server -n argo 8080:443
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring 
kubectl port-forward service/grafana 3000:80 -n monitoring
`
To access the UI, just go to the local browser and access the UI:
- ArgoCD: http://localhost:8080/
- Prometheus: http://localhost:9090/
- Grafana: http://localhost:3000/

### Configuring Prometheus as a Data Source in Grafana
Since Grafana and Prometheus do not have a CLI interface, Promethus needs to be configured as a data source in Grafana manually. 
1. Access Grafana UI: Navigate to http://localhost:3000 in your browser. The default login credentials are admin for username and password is can be accessed as output of the script.
2. Add Prometheus as Data Source:
   - In the Grafana dashboard, go to Configuration (gear icon) > Data Sources.
   - Click Add data source, and select Prometheus.
   - In the HTTP section, set the URL to http://prometheus-server.monitoring.svc.cluster.local.
   - Click Save & Test to ensure Grafana can connect to Prometheus.

## Sample Prometheus and Grafana queries
1. For CPU usage of the Falco pods, use the following query:
   `
   sum(rate(container_cpu_usage_seconds_total{namespace="falco"}[1m])) by (pod)
   `
   This query shows the rate of CPU usage by Falco pods in the namespace "falco" over the last minute.
2. For memory usage of the Falco pods, use this query:
   `
   sum(container_memory_usage_bytes{namespace="falco"}) by (pod)
   `
   This query shows the current memory usage of Falco pods.


**Cleanup**
To clean up and remove the deployed resources, use the cleanup argument with the script:
`
sh deploy-test-environment.sh cleanup
`
This will stop and delete the Colima VM, remove Prometheus and Grafana, and revert the Kubernetes context to the original configuration.

### Documentation Links

[Deploying Falco using Lima](https://falco.org/blog/falco-apple-silicon/#falco-on-m1-on-kubernetes)
[ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
[Argo Workflows](https://github.com/argoproj/argo-workflows/blob/master/docs/quick-start.md)
[Falco Sidekick Response Engine](https://falco.org/blog/falcosidekick-response-engine-part-5-argo/)