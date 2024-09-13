Install AKS

```bash
export AZURE_RESOURCE_GROUP="suraj-caa0913-2"
./deploy-aks.sh
```

Install KBS

```bash
export KEY_FILE=artifacts/keyfile
echo "this is important security file $RANDOM-$RANDOM" > $KEY_FILE
cat $KEY_FILE
./deploy-kbs.sh
```

Install CAA

```bash
export KBS_URL=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$(kubectl get svc kbs -n coco-tenant -o jsonpath='{.spec.ports[0].nodePort}')
./deploy-caa.sh
```

Start a basic application

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
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
      runtimeClassName: kata-remote
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        imagePullPolicy: Always
EOF
```

Now compare the key file coming from KBS and the one available locally:

```bash
kubectl -n default exec -it $(kubectl -n default get pods -l app=nginx -o name) -- curl http://127.0.0.1:8006/cdh/resource/reponame/workload_key/key.bin
cat $KEY_FILE
```
