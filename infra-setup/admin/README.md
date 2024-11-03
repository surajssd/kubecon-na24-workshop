```
source .admin-env
./create-group.sh
```


## Create Role

```bash
az role definition create \
    --role-definition role.json

az role definition update \
    --role-definition role.json
```


## Create Policy

```bash
az policy definition create \
    --name "AssignOwnerToRGCreator" \
    --description "Assign Owner role to resource group creators" \
    --mode All \
    --metadata category="Access Control" \
    --rules policy2.json

az policy assignment create \
    --policy "AssignOwnerToRGCreator" \
    --name "AssignOwnerToRGCreatorAssignment" \
    --scope "/subscriptions/<subscriptionId>"
```
