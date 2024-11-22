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

# To redeploy cleanly do:
helm uninstall postgrest-over-pgmq .
k delete pvc data-postgrest-over-pgmq-postgresql-0
helm upgrade -i postgrest-over-pgmq .
```

### List the paths from the OpenAPI schema

```shell
KEYCLOAK_ADDRESS="http://keycloak.docker.localhost"

PGRST_ADDRESS="http://postgrest.docker.localhost"

curl -s ${PGRST_ADDRESS} | jq '.paths | keys'
```

### Leftovers

```shell
PGRST_JWT_SECRET=$(k get secrets playground-secret -o jsonpath="{.data['jwt-secret']}" | base64 -d)

JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=loggedin)"

KC_PASSWORD=$(k get secrets playground-secret -o jsonpath="{.data['keycloak-admin-password']}" | base64 -d)
```
