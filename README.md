## Prerequisites

Make a copy of the sample env file and modify it as needed:

```bash
cp .env-sample .env
```

Source the env var file:

```bash
source .env
```

## Infrastructure Deployment

Deploy Kubernetes using Azure Kubernetes Service:

```bash
./infra-setup/deploy-aks.sh
```

Install Key Broker Service (KBS):

```bash
./infra-setup/deploy-kbs.sh
```

Install Cloud API Adaptor (CAA) a.k.a. peer pods:

```bash
./infra-setup/deploy-caa.sh
```

## Demo 1: Secure Key Release

### Step 1.1: Key Management

Generate a key:

```bash
export KEY_FILE="$(pwd)/artifacts/keyfile"
echo "this is important security file $RANDOM-$RANDOM" > $KEY_FILE
cat $KEY_FILE
```

Upload the key to KBS:

```bash
export KEY_ID="/reponame/workload_key/key.bin"
./demos/upload-key-to-kbs.sh $KEY_FILE $KEY_ID
```

### Step 1.2: Application Deployment

Look at the application deployment configuration:

```bash
cat demos/demo1/skr.yaml
```

Start a basic application:

```yaml
kubectl apply -f demos/demo1/skr.yaml
```

Wait for the pod to come up:

```bash
kubectl -n default wait --for=condition=Ready pod -l app=ubuntu --timeout=300s
kubectl -n default get pods -l app=ubuntu
```

### Step 1.3: Perform Secure Key Release

Perform a secure key release:

```bash
kubectl -n default exec -it $(kubectl -n default get pods -l app=ubuntu -o name) -- curl http://127.0.0.1:8006/cdh/resource/reponame/workload_key/key.bin
```

Compare the key released from KBS with the key file we have locally:

```bash
cat $KEY_FILE
```

### Step 1.4: Verify from KBS

```bash
./debug/kbs-logs.sh
```

### Step 1.5: Clean Up

Delete the deployment:

```bash
kubectl -n default delete deployment ubuntu
```

## Demo 2: Encrypted Container Image

### Step 2.1: Encrypt Container Image

Encrypt the container image $SOURCE_IMAGE and upload it to the container registry:

```bash
./demos/demo2/encrypt-container-image.sh
```

Verify the container image is encrypted, by pulling it in a pristine environment:

```bash
docker run --privileged --rm --name dind -d docker:stable-dind
docker exec -it dind /bin/ash -c "docker pull $DESTINATION_IMAGE"
```

Use skopeo to inspect the image:

```bash
skopeo inspect --raw "docker://${DESTINATION_IMAGE}" | jq -r '.layers[0].annotations."org.opencontainers.image.enc.keys.provider.attestation-agent"' | base64 -d | jq
```

### Step 2.2: Upload the key to KBS

```bash
./demos/upload-key-to-kbs.sh $ENCRYPTION_KEY_FILE $ENCRYPTION_KEY_ID
```

### Step 2.3: Deploy Encrypted Container Image

Look at the encrypted application configuration:

```bash
cat demos/demo2/encrypted-app.yaml
```

Deploy the encrypted application:

```bash
envsubst < demos/demo2/encrypted-app.yaml | kubectl apply -f -
```

Wait for the pod to come up:

```bash
kubectl -n default wait --for=condition=Ready pod -l app=nginx-encrypted --timeout=300s
kubectl -n default get pods -l app=nginx-encrypted
```

### Step 2.4: Verify Nginx in Encrypted Container Image is running

```bash
kubectl -n default exec -it $(kubectl -n default get pods -l app=nginx-encrypted -o name) -- curl localhost
```

### Step 2.5: Verify from KBS

```bash
./debug/kbs-logs.sh
```

### Step 2.6: Clean Up

Delete the deployment:

```bash
kubectl -n default delete deployment nginx-encrypted
```


## Troubleshooting

### Cloud API Adaptor (CAA) Logs

```bash
./debug/caa-logs.sh
```

### Key Broker Service (KBS) Logs

```bash
./debug/kbs-logs.sh
```

### Find region with Confidential VM capacity

```bash
./debug/find-region-machine-map.sh
```

### Get access to the Worker Node

```bash
./debug/node-debugger.sh
```

### Get access to the Confidential VM

Get into the debugger pod:

```bash
./debug/node-debugger.sh
```

Once inside run:

```bash
# TODO: Figure out an easier way to get the peer-pod VM IP
ssh peerpod@<VM IP>
```
