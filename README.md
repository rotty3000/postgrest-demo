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

### Install the chart

```shell
cd ./chart
helm upgrade -i postgrest-over-pgmq .
```

### Visit Keycloak

```shell
KEYCLOAK_ADDRESS="http://keycloak.docker.localhost"

KEYCLOAK_ADMIN_PASSWORD=$(k get secrets playground-secret -o jsonpath="{.data['keycloak-admin-password']}" | base64 -d)
KEYCLOAK_ADMIN_USERNAME=kadmin

open http://keycloak.docker.localhost
```

### Make a call to PostgREST

```shell
PGRST_ADDRESS="http://postgrest.docker.localhost"

# Look at the openapi schema
curl -s ${PGRST_ADDRESS} | jq

# Look at the available routes
curl -s ${PGRST_ADDRESS} | jq '.paths | keys'

PGRST_JWT_SECRET=$(k get secrets playground-secret -o jsonpath="{.data['jwt-secret']}" | base64 -d)

JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=loggedin)"

# Pick a route (if there are any objects defined in the schema...)
ROUTE="/"

curl -s ${PGRST_ADDRESS}${ROUTE} \
  -H "Authorization: bearer ${JWT_TOKEN}" \
   | jq
```

### To redeploy the chart cleanly, do

```shell
helm uninstall postgrest-over-pgmq .
k delete pvc data-postgrest-over-pgmq-postgresql-0
helm upgrade -i postgrest-over-pgmq .
```
