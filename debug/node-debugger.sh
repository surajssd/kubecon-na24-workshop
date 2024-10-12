#!/usr/bin/env bash

set -euo pipefail
source utility.sh

# Check if the DEBUG env var is set to true
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

POD_NAME="debugger"
kubectl -n default delete pod ${POD_NAME} --ignore-not-found

NODE_NAME=$(kubectl get nodes -o name)
NODE_NAME=${NODE_NAME#node/}

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: default
spec:
  containers:
  - command:
    - sleep
    - infinity
    image: ubuntu
    imagePullPolicy: Always
    name: debugger
    volumeMounts:
    - mountPath: /host
      name: host-root
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  hostIPC: true
  hostNetwork: true
  hostPID: true
  nodeName: ${NODE_NAME}
  preemptionPolicy: PreemptLowerPriority
  priority: 0
  restartPolicy: Never
  schedulerName: default-scheduler
  tolerations:
  - operator: Exists
  volumes:
  - hostPath:
      path: /
      type: ""
    name: host-root
EOF

# Wait for the pod to be ready
kubectl -n default wait --for=condition=Ready pod/debugger --timeout=300s

SSH_PRIVATE_KEY="${SSH_KEY%.pub}"
kubectl -n default -c debugger cp $SSH_PRIVATE_KEY debugger:/host/root/.ssh/id_rsa
kubectl -n default -c debugger exec debugger -- chmod 400 /host/root/.ssh/id_rsa
kubectl -n default -c debugger exec -it debugger -- chroot /host /bin/bash
