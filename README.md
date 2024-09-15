Make a copy of the sample env file and modify it as needed:

```bash
cp .env-sample .env
```

Source the env var file:

```bash
source .env
```

Install AKS

```bash
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
kubectl -n default get pods
kubectl -n default exec -it $(kubectl -n default get pods -l app=nginx -o name) -- curl http://127.0.0.1:8006/cdh/resource/reponame/workload_key/key.bin
cat $KEY_FILE
```
