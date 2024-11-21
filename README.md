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
   --from-literal=keycloak-postgres-user=keycloak \
   --from-literal=keycloak-postgres-database=keycloak \
   --from-literal=keycloak-postgres-password="$(make_secret)"
```

> **TODO**: [Auto Generate Secret](https://itnext.io/manage-auto-generated-secrets-in-your-helm-charts-5aee48ba6918)

### Install the chart

```shell
cd ./chart
helm upgrade -i postgrest-over-pgmq .

# To redeploy clean do:
helm uninstall postgrest-over-pgmq .
k delete pvc data-postgrest-over-pgmq-postgresql-0
helm upgrade -i postgrest-over-pgmq .
```

Connect to the `psql` console using the following docker command:

```shell
k exec -it postgrest-over-pgmq-postgresql-0 -- bash
export PGPASSWORD=${POSTGRES_PASSWORD}
psql -U postgres
```

Look at at the objects in the schema:

```shell
# (tables)
\dt <schema>.*
# (functions)
\df <schema>.*
```

You can visit it at the following address:

```shell
PGRST_ADDRESS="http://postgrest.docker.localhost"

curl ${PGRST_ADDRESS} | jq
```

You should see the Open API schema.

### List the paths from the OpenAPI schema

```shell
curl -s ${PGRST_ADDRESS} | jq '.paths | keys'
```

### Adding a Queue (WITH JWT authentication)

Ok, let's take the level up and generate a JWT we can use to leverage bulk update through the REST API. (We could do bulk insert via psql but what's the fun in that.)

Create a JWT token and hold it. We're using Bitnami's containerized version of [jwt-cli](https://github.com/mike-engel/jwt-cli) to simplify our lives. It helps us create HS256 JWT tokens from the command line:

```shell
PGRST_JWT_SECRET=$(k get secrets playground-secret -o jsonpath="{.data['jwt-secret']}" | base64 -d)
JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=loggedin)"


```

