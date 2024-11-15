## Getting Started with PostgREST using Docker

#### Required tools

Everything here assumes Linux based environment. You will need to translate some of this for Windows environments.

What you need to have installed locally:

- `bash` (or something close)
- `tr`
- `head`
- `docker`
- `curl`
- `jq`

### Initial Setup

Create 3 strong passwords and store them in the following environment variables:

```shell
make_secret() {
  echo "$(LC_CTYPE=C LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c32)"
}

export POSTGRESQL_PASSWORD=$(make_secret)
export PGRST_AUTHENTICATOR_PASSWORD=$(make_secret)
export PGRST_JWT_SECRET=$(make_secret)
```

Create a docker network (simpler and more flexible than managing port bindings to host).

```shell
docker network create -d bridge postgrest-demo
```

### Setup PostgreSQL

Get [a Postgresql that has PGMQ extension](https://quay.io/repository/tembo/pg17-pgmq?tab=tags) running using docker:

_(**Note:** remember to set a strong password for the DB. This assumes it's stored in environment variable called `POSTGRESQL_PASSWORD`)_

```shell
docker pull quay.io/tembo/pg17-pgmq

docker run -d --name postgres --network postgrest-demo \
	-e "POSTGRES_PASSWORD=${POSTGRESQL_PASSWORD}" \
	-d quay.io/tembo/pg17-pgmq
```

Execute the following command to get minimal DB objects required to run PostgREST:

```shell
SQL=$(eval "echo \"$(<schema-0.sql)\"" 2> /dev/null)
docker exec -it postgres psql -U postgres -c "$SQL"
```

You can also connect to the `psql` console using the following docker command:

```shell
docker exec -it postgres psql -U postgres
```

You should see the psql prompt.

Look at at the objects in the schema (`pgmq` in this case):

```shell
# (tables)
\dt pgmq.*
# (functions)
\df pgmq.*
```

### Setup PostgREST

Get a PostgREST instance running using docker:

_(**Note:** remember to set a strong password for the authenticator role and the jwt-secret. This assumes these are stored in environment variables called `PGRST_AUTHENTICATOR_PASSWORD` and `PGRST_JWT_SECRET` respectively.)_

```shell
docker pull postgrest/postgrest

docker run -d --name pg-rest --network postgrest-demo \
	-e "PGRST_DB_URI=postgres://authenticator:${PGRST_AUTHENTICATOR_PASSWORD}@postgres:5432/postgres" \
	-e "PGRST_DB_ANON_ROLE=webanon" \
	-e "PGRST_DB_SCHEMAS=pgmq" \
	-e "PGRST_JWT_SECRET=${PGRST_JWT_SECRET}" \
	-e "PGRST_LOG_LEVEL=debug" \
	-d postgrest/postgrest
```

Test your installation by checking the container logs:

```shell
docker logs pg-rest
```

If everything went well this should show that PostgREST connected to the database, like so:

```shell
18/Jan/2024:16:00:17 +0000: Starting PostgREST 12.0.2...
18/Jan/2024:16:00:17 +0000: Attempting to connect to the database...
18/Jan/2024:16:00:17 +0000: Connection successful
18/Jan/2024:16:00:17 +0000: Listening on port 3000
18/Jan/2024:16:00:17 +0000: Config reloaded
18/Jan/2024:16:00:17 +0000: Listening for notifications on the pgrst channel
18/Jan/2024:16:00:17 +0000: Schema cache loaded
```

At this stage you have a schema to look at. You can visit it at the following address:

```shell
PGRST_ADDRESS="http://$(docker container inspect pg-rest | jq -r '.[] | .NetworkSettings.Networks["postgrest-demo"].IPAddress'):3000"

curl ${PGRST_ADDRESS} | jq
```

You should see the Open API schema.

### Adding a Queue (WITH JWT authentication)

Ok, let's take the level up and generate a JWT we can use to leverage bulk update through the REST API. (We could do bulk insert via psql but what's the fun in that.)

Create a JWT token and hold it. We're using Bitnami's containerized version of [jwt-cli](https://github.com/mike-engel/jwt-cli) to simplify our lives. It helps us create HS256 JWT tokens from the command line:

```shell
JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=webuser)"
```

### Create a Queue

```shell
curl -s "${PGRST_ADDRESS}/rpc/create" \
	-H "Authorization: Bearer $JWT_TOKEN" \
	--json '{"queue_name": "bar"}'
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
