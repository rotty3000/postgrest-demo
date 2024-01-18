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
export PGRST_AUTENTICATOR_PASSWORD=$(make_secret)
export PGRST_JWT_SECRET=$(make_secret)
```

Create a docker network (simpler and more flexible than managing port bindings to host).

```shell
docker network create -d bridge postgrest-demo
```

### Setup PostgreSQL

Get a Postgresql instance running using docker:

_(__Note:__ remember to set a strong password for the DB. This assumes it's stored in environment variable called `POSTGRESQL_PASSWORD`)_

```shell
docker pull postgres

docker run -d --name pg-sql --network postgrest-demo \
	-e "POSTGRES_PASSWORD=${POSTGRESQL_PASSWORD}" \
	-d postgres
```

Execute the following command to get minimal DB objects required to run PostgREST. (This executes the SQL in `schema-0.sql`, go check it out):

```shell
SQL=$(eval "echo \"$(<schema-0.sql)\"" 2> /dev/null)
docker exec -it pg-sql psql -U postgres -c "$SQL"
```

You can also connect to the `psql` console using the following docker command:

```shell
docker exec -it pg-sql psql -U postgres"
```

You should see a command prompt.

### Setup PostgREST

Get a PostgREST instance running using docker:

_(__Note:__ remember to set a strong password for the authenticator role and the jwt-secret. This assumes these are stored in environment variables called `PGRST_AUTENTICATOR_PASSWORD` and `PGRST_JWT_SECRET` respectively.)_

```shell
docker pull postgrest/postgrest

docker run -d --name pg-rest --network postgrest-demo \
	-e "PGRST_DB_URI=postgres://authenticator:${PGRST_AUTENTICATOR_PASSWORD}@pg-sql:5432/postgres" \
	-e "PGRST_DB_ANON_ROLE=webanon" \
	-e "PGRST_DB_SCHEMAS=api" \
	-e "PGRST_JWT_SECRET=${PGRST_JWT_SECRET}" \
	-e "PGRST_LOG_LEVEL=info" \
	-d postgrest/postgrest:v12.0.1
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

There isn't much there but you can see that PostgREST provides a Open API schema already with the only path being the self describing OpenAPI at the root `/`.

### Adding Schema by Creating Tables

Let's make things more interesting by adding a table and grant access.

Execute the following. (This executes the SQL in `schema-1.sql`, go check it out):

```shell
SQL=$(eval "echo \"$(<schema-1.sql)\"" 2> /dev/null)
docker exec -it pg-sql psql -U postgres -c "$SQL"
```

Now you should see new paths you can observe by checking the update Open API:

```shell
curl ${PGRST_ADDRESS} | jq '.paths'
```

### Bulk Insert Data using REST (WITH JWT authentication)

Ok, let's take the level up and generate a JWT we can use to leverage bulk update through the REST API. (We could do bulk insert via psql but what's the fun in that.)

Create a JWT token and hold it. We're using Bitnami's containerized version of [jwt-cli](https://github.com/mike-engel/jwt-cli) to simplify our lives. It helps us create HS256 JWT tokens from the command line:

```shell
JWT_TOKEN="$(docker run --rm bitnami/jwt-cli encode -S ${PGRST_JWT_SECRET} -P role=webuser)"
```

We can now use the token to make authenticated requests via curl. This one will POST our json data file to populate our table:

```shell
curl ${PGRST_ADDRESS}/sales -X POST \
	-H "Authorization: Bearer $JWT_TOKEN" \
	-H "Content-Type: application/json" \
	-d @Warehouse_and_Retail_Sales.json
```

This great, but it's pretty boring database so let's normalize the data a bit so we can do things like joins.

Execute the following. (This executes the SQL in `schema-2.sql`, go check it out):

```shell
SQL=$(eval "echo \"$(<schema-2.sql)\"" 2> /dev/null)
docker exec -it pg-sql psql -U postgres -c "$SQL"
```

Finally, execute the following. (This executes the SQL in `schema-3.sql`, go check it out):

```shell
SQL=$(eval "echo \"$(<schema-3.sql)\"" 2> /dev/null)
docker exec -it pg-sql psql -U postgres -c "$SQL"
```

Now we have a prettier schema and we can try some interesting requests to explore the power of PostgREST:

```shell
# join
curl ${PGRST_ADDRESS}/sales?select=*,supplier(*),item(*)&limit=10

# reverse join
curl ${PGRST_ADDRESS}/supplier?select=*,sales(*,item(*))&limit=10
```

Enjoy!