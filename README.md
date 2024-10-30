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
echo "KubeconNA-2024-@SLC-$RANDOM-$(date '+%Y%m%b%d%H%M%S')" > $KEY_FILE
cat $KEY_FILE
```

Upload the key to KBS:

```bash
export KEY_ID="kubecon_na24/coco_demo/key.bin"
./demos/upload-key-to-kbs.sh $KEY_FILE $KEY_ID
```

### Step 1.2: Application Deployment

Look at the application deployment configuration:

```bash
cat demos/demo1/skr.yaml
```

Start a basic application:

```bash
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
kubectl -n default exec -it \
    $(kubectl -n default get pods -l app=ubuntu -o name) -- \
    curl http://127.0.0.1:8006/cdh/resource/$KEY_ID
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

Encrypt the container image `$SOURCE_IMAGE` and upload it to the container registry:

```bash
echo $SOURCE_IMAGE
```

```bash
./demos/demo2/encrypt-container-image.sh
```

Verify the container image is encrypted, by pulling it in a pristine environment:

```bash
docker run --privileged --rm --name dind -d docker:dind && sleep 5
docker exec -it dind /bin/sh -c "docker pull $DESTINATION_IMAGE"
```

Use skopeo to inspect the image:

```bash
skopeo inspect --raw "docker://${DESTINATION_IMAGE}" | \
    jq -r '.layers[0].annotations."org.opencontainers.image.enc.keys.provider.attestation-agent"' \
    | base64 -d | jq
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

```bash
echo $DESTINATION_IMAGE
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
PUBLIC_IP=$(kubectl -n default get svc nginx-encrypted \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "http://${PUBLIC_IP}:80"
```

### Step 2.5: Verify from KBS

```bash
./debug/kbs-logs.sh
```

### Step 2.6: Clean Up

Delete the deployment:

```bash
kubectl -n default delete deployment nginx-encrypted
kubectl -n default delete svc nginx-encrypted
```

## Demo 3: Confidential Containers Policy

### Scenario 3.1: Debug Policy

This policy has everything allowed:

```bash
cat demos/demo3/allow-all.rego
```

Sample application:

```bash
cat demos/demo3/policy-app.yaml
```

Generate policy for the deployment:

```bash
genpolicy --raw-out \
    --json-settings-path demos/demo3/genpolicy-settings.json \
    --yaml-file demos/demo3/policy-app.yaml \
    --rego-rules-path demos/demo3/allow-all.rego
```

Look at the updated application configuration:

```bash
cat demos/demo3/policy-app.yaml
```

Start the application:

```bash
kubectl apply -f demos/demo3/policy-app.yaml
```

Wait for the pod to come up:

```bash
kubectl -n default wait --for=condition=Ready pod -l app=nginx --timeout=300s
kubectl -n default get pods -l app=nginx
```

Verify that you can `exec` into the pod:

```bash
kubectl exec -it $(kubectl -n default get pods -l app=nginx -o name) -- curl localhost
```

Delete the deployment:

```bash
kubectl -n default delete deployment nginx
```

### Scenario 3.2: Disallow `exec` Policy

Let's look at the policy that disallows `exec`:

```bash
cat demos/demo3/disallow-exec.rego
```

You can look at the difference between the allow-all and disallow-exec policies:

```bash
diff demos/demo3/allow-all.rego demos/demo3/disallow-exec.rego
```

Regenerate policy with new rules:

```bash
genpolicy --raw-out \
    --json-settings-path demos/demo3/genpolicy-settings.json \
    --yaml-file demos/demo3/policy-app.yaml \
    --rego-rules-path demos/demo3/disallow-exec.rego
```

Look at the updated application configuration:

```bash
cat demos/demo3/policy-app.yaml
```

Apply the new deployment:

```bash
kubectl apply -f demos/demo3/policy-app.yaml
```

Wait for the pod to come up:

```bash
kubectl -n default wait --for=condition=Ready pod -l app=nginx --timeout=300s
kubectl -n default get pods -l app=nginx
```

Verify if you can `exec` into the pod:

```bash
kubectl exec -it $(kubectl -n default get pods -l app=nginx -o name) -- curl localhost
```

Delete the deployment:

```bash
kubectl -n default delete deployment nginx
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
