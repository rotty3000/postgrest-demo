## Getting Started with PostgREST using Docker

#### Required tools

Everything here assumes Linux based environment. You will need to translate some of this for Windows environments.

What you need to have installed locally:

- `kubectl` (or something close)
- `helm`
- `jq`
- `k3d` (or any Kubernetes distribution)

#### Initial Setup

Create a secret to contain security values:

```shell
  make_secret() {
    echo "$(LC_CTYPE=C LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c32)"
  }

  kubectl create secret generic postgresql-secret \
   --from-literal=postgres-password="$(make_secret)" \
   --from-literal=password="$(make_secret)" \
   --from-literal=replication-password="$(make_secret)"
   --from-literal=jwt-secret="$(make_secret)"
```

#### Create a Kubernetes cluster

```shell
k3d cluster create postgrest-over-pgmq -p "8880:80@loadbalancer" --registry-create registry:0.0.0.0:5000
```

### Install the chart

```shell
cd ./chart
helm upgrade -i postgrest-over-pgmq .
```

Connect to the `psql` console using the following docker command:

```shell
k exec -it postgrest-over-pgmq-postgresql-0 -- bash
export PGPASSWORD=${POSTGRES_PASSWORD}
psql -U postgres
```

Look at at the objects in the schema (`pgmq` in this case):

```shell
# (tables)
\dt pgmq.*
# (functions)
\df pgmq.*
```

You can visit it at the following address:

```shell
PGRST_ADDRESS="http://postgrest.docker.localhost:8880"

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
PGRST_JWT_SECRET=$(k get secrets postgresql-secret -o jsonpath="{.data['jwt-secret']}" | base64 -d)
JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=loggedin)"
```

### Create a Queue

```shell
curl -s "${PGRST_ADDRESS}/rpc/create" \
	-H "Authorization: Bearer $JWT_TOKEN" \
	--json '{"queue_name": "bar"}' | jq
```

### List Queues

```shell
curl -s ${PGRST_ADDRESS}/rpc/list_queues \
	-H "Authorization: Bearer $JWT_TOKEN" \
	-H "Content-Type: application/json" | jq
[
  {
    "queue_name": "bar",
    "is_partitioned": false,
    "is_unlogged": false,
    "created_at": "2024-11-14T21:14:15.035969+00:00"
  }
]
```

### Send a message to the queue

```shell
curl -s ${PGRST_ADDRESS}/rpc/send \
	-H "Authorization: Bearer $JWT_TOKEN" \
	--json '{"queue_name":"bar","msg":{"the":"message"}}' | jq
[
  1
]
```

### Read a message from the queue

```shell
curl -s ${PGRST_ADDRESS}/rpc/read \
	-H "Authorization: Bearer $JWT_TOKEN" \
	--json '{"queue_name":"bar","qty": 10, "vt": 30}' | jq
[
  {
    "msg_id": 1,
    "read_ct": 1,
    "enqueued_at": "2024-11-14T21:28:18.063172+00:00",
    "vt": "2024-11-14T21:30:50.764849+00:00",
    "message": {
      "the": "message"
    }
  }
]
```

### Archive a message from the queue

```shell
curl -s ${PGRST_ADDRESS}/rpc/archive \
	-H "Authorization: Bearer $JWT_TOKEN" \
	--json '{"queue_name":"bar","msg_ids": [1]}' | jq
[
  1
]
```

## Using Helm
