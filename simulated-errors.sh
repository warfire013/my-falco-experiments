#!/bin/bash

# Scenario 1: Pod with incorrect image
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-wrong-image
spec:
  containers:
  - name: nginx
    image: nginx:wrongtag
EOF

# Scenario 2: Pod trying to mount a non-existent volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-wrong-mount
spec:
  containers:
  - name: alpine
    image: alpine
    volumeMounts:
    - name: non-existent-volume
      mountPath: /mnt
  volumes:
  - name: non-existent-volume
    emptyDir: {}
EOF

# Scenario 3: Pod with missing ServiceAccount
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-missing-sa
spec:
  containers:
  - name: alpine
    image: alpine
  serviceAccountName: non-existent-sa
EOF

# Scenario 4: Service with no matching selector
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-no-selector-match
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 9376
  selector:
    app: non-existent-app
EOF

# Scenario 5: Deploying a resource in a non-existent namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-wrong-namespace
  namespace: non-existent-ns
spec:
  containers:
  - name: alpine
    image: alpine
EOF

# Additional Scenario: Creating a deployment with insufficient resources
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-insufficient-resources
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        resources:
          requests:
            memory: "100Gi" # Adjust this value to be higher than the available resources
          limits:
            memory: "100Gi"
EOF

echo "Resources deployed. Waiting for 3 minutes before cleanup..."
sleep 180

# Cleanup
echo "Cleaning up resources..."
kubectl delete pod pod-wrong-image
kubectl delete pod pod-wrong-mount
kubectl delete pod pod-missing-sa
kubectl delete svc service-no-selector-match
kubectl delete pod pod-wrong-namespace --ignore-not-found
kubectl delete deployment deployment-insufficient-resources

echo "Cleanup completed."
