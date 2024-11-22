## Getting Started with PostgREST using Docker

#### Required tools

Everything here assumes Linux based environment. You will need to translate some of this for Windows environments.

What you need to have installed locally:

- `kubectl` (or something close)
- `helm`
- `jq`
- `k3d` (or any Kubernetes distribution)

#### Create a Kubernetes cluster

This uses k3d to create a local Kubernetes cluster

```shell
k3d cluster create playground \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --registry-create registry:0.0.0.0:5000
```

#### Initial Setup

Create a secret to contain security values:

```shell
  make_secret() {
    echo "$(LC_CTYPE=C LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c32)"
  }

  kubectl create secret generic playground-secret \
   --from-literal=postgres-password="$(make_secret)" \
   --from-literal=password="$(make_secret)" \
   --from-literal=replication-password="$(make_secret)" \
   --from-literal=postgres-host=postgrest-over-pgmq-postgresql \
   --from-literal=postgres-port=5432 \
   --from-literal=postgrest-jwt-secret="$(make_secret)" \
   --from-literal=keycloak-admin-password="$(make_secret)" \
   --from-literal=keycloak-postgres-user=keycloak \
   --from-literal=keycloak-postgres-database=keycloak \
   --from-literal=keycloak-postgres-password="$(make_secret)"
```

> **TODO**: [Auto Generate Secret](https://itnext.io/manage-auto-generated-secrets-in-your-helm-charts-5aee48ba6918)

### Install the chart

```shell
cd ./chart
helm upgrade -i postgrest-over-pgmq .

# To redeploy cleanly do:
helm uninstall postgrest-over-pgmq .
k delete pvc data-postgrest-over-pgmq-postgresql-0
helm upgrade -i postgrest-over-pgmq .
```

### List the paths from the OpenAPI schema

```shell
PGRST_ADDRESS="http://postgrest.docker.localhost"

curl -s ${PGRST_ADDRESS} | jq '.paths | keys'
```

### Leftovers

```shell
PGRST_JWT_SECRET=$(k get secrets playground-secret -o jsonpath="{.data['jwt-secret']}" | base64 -d)

JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=loggedin)"

KC_PASSWORD=$(k get secrets playground-secret -o jsonpath="{.data['keycloak-admin-password']}" | base64 -d)
```
