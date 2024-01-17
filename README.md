## Get Started

Get a Postgresql instance running (using docker here):

```shell
docker run --name tutorial -p 5433:5432 \
	-e POSTGRES_PASSWORD=postgresqladmin \
	-d postgres
```

Get `postgrest` (see [documentation](https://postgrest.org/en/stable/tutorials/tut0.html) for details)

Test your installation by running the installed binary.

e.g.

```shell
./postgrest -h
```

If everything went well this should print available options.

Now connect to the SQL console (psql). Since we're using docker the following command is what we'll use:

```shell
docker exec -it tutorial psql -U postgres
```

We should see a command prompt.

Now we'll create a names schema for all the database objects we want to expose in our API.

```sql
create schema api;
```

Our API will have endpoints, one of which will be `/todos`, which will come from tables.

```sql
create table api.todos (
  id serial primary key,
  done boolean not null default false,
  task text not null,
  due timestamptz
);

-- here we insert some test data
insert into api.todos (task) values
  ('finish tutorial 0'),
  ('pat self on back');
```

Now we need to make a role for anonymous web requests. PostgREST will use this role to run queries when unauthenticated requests are made.

```sql
create role web_anon nologin;

-- note the limited permissions we've granted the role
grant usage on schema api to web_anon;
grant select on api.todos to web_anon;
```

PostgREST itself needs a role to connect to the database and it's a good practice for this role to have a few permissions as possible. So we'll create a role `authenticator` with the ability to switch to the `web_anon` role:

```sql
create role authenticator noinherit login password 'mysecretpassword';
grant web_anon to authenticator;

-- we did everything we needed in psql, quit
\q
```

`postgrest` can use a configuration file to tell it how to connect to the database, create `tutorial.conf`:

```properties
db-uri = "postgres://authenticator:mysecretpassword@localhost:5433/postgres"
db-schemas = "api"
db-anon-role = "web_anon"
```

There are a slew of [other options](https://postgrest.org/en/stable/references/configuration.html#configuration) but this is all we need to start.

Run it:

```shell
./postgrest tutorial.conf
```

You should see a success message and then you can perform a test request:

```shell
curl http://localhost:3000/todos
```
Response should look like:
```json
[
  {
    "id": 1,
    "done": false,
    "task": "finish tutorial 0",
    "due": null
  },
  {
    "id": 2,
    "done": false,
    "task": "pat self on back",
    "due": null
  }
]
```

If you try to make a post it will fail:

```shell
]$ curl http://localhost:3000/todos -X POST \
  -H "Content-Type: application/json" \
  -d '{"task": "do bad thing"}'
...
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "permission denied for table todos"
}
```

Now we want to add users and let them manage their todos. Since permissions are granted to roles in postgresql we need to create a role with the correct permissions and then assign this role users.

```sql
-- remember how we connected to the psql console earlier?

create role todo_user nologin;
grant todo_user to authenticator;

grant usage on schema api to todo_user;

-- note that we grant a little more permission to this role

grant all on api.todos to todo_user;
grant usage, select on sequence api.todos_id_seq to todo_user;
```

We don't have an authorization server setup yet so we need some way to create an sign JWT tokens. We'll use a shortcut provided by `postgrest` which is to store a signing secret in the configuration which will be used to verify tokens. We'll use some Linux-foo to generate the secret:

```shell
# Allow "tr" to process non-utf8 byte sequences
export LC_CTYPE=C

# read random bytes and keep only alphanumerics
echo "jwt-secret = \"$(LC_ALL=C tr -dc 'A-Za-z0-9' \
  </dev/urandom | head -c32)\"" >> tutorial.conf
```
Check `tutorial.conf` (e.g. `cat tutorial.conf`) to see the result.

Next, create and sign a token using the online tool [jwt.io](jwt.io).

The contents should be:

```javascript
// header
{
  "alg": "HS256",
  "typ": "JWT"
}

// payload
{
  "role": "todo_user"
}

// verify
HMACSHA256(
  base64UrlEncode(header) + "." +
  base64UrlEncode(payload),
  <secret> // <-- this was the value of 'jwt-secret' appended to the tutorial.conf earlier
)
```

Copy the token and store it in a shell variable:

```shell
export TOKEN="<paste token here>"

curl http://localhost:3000/todos -X POST \
  -H "Authorization: Bearer $TOKEN"   \
  -H "Content-Type: application/json" \
  -d '{"task": "learn how to auth"}'
```

Ok, we've completed all 3 items of the todo list, let's mark them as `done` using a `PATCH` request:

```shell
curl http://localhost:3000/todos -X PATCH \
  -H "Authorization: Bearer $TOKEN"    \
  -H "Content-Type: application/json"  \
  -d '{"done": true}'
```
## Storing Users and Passwords

```sql
-- We put things inside the basic_auth schema to hide
-- them from public view. Certain public procs/views will
-- refer to helpers and tables inside.
create schema if not exists basic_auth;

create table if not exists
users (
  email    text primary key check ( email ~* '^.+@.+\..+$' ),
  pass     text not null check (length(pass) < 512),
  role     name not null check (length(role) < 512)
);

create or replace function
check_role_exists() returns trigger as $$
begin
  if not exists (select 1 from pg_roles as r where r.rolname = new.role) then
    raise foreign_key_violation using message =
      'unknown database role: ' || new.role;
    return null;
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists ensure_user_role_exists on users;

create constraint trigger ensure_user_role_exists
  after insert or update on users
  for each row
  execute procedure check_role_exists();

create extension if not exists pgcrypto;

create or replace function
encrypt_pass() returns trigger as $$
begin
  if tg_op = 'INSERT' or new.pass <> old.pass then
    new.pass = crypt(new.pass, gen_salt('bf'));
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists encrypt_pass on users;

create trigger encrypt_pass
  before insert or update on users
  for each row
  execute procedure encrypt_pass();

create or replace function
user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
  select role from basic_auth.users
   where basic_auth.users.email = user_role.email
     and basic_auth.users.pass = crypt(user_role.pass, basic_auth.users.pass)
  );
end;
$$;

-----------------------------------------------------------------------
-- BEGIN (original https://github.com/michelp/pgjwt/blob/master/pgjwt--0.2.0.sql)
-----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION url_encode(data bytea) RETURNS text LANGUAGE sql AS $$
    SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$ IMMUTABLE;


CREATE OR REPLACE FUNCTION url_decode(data text) RETURNS bytea LANGUAGE sql AS $$
WITH t AS (SELECT translate(data, '-_', '+/') AS trans),
     rem AS (SELECT length(t.trans) % 4 AS remainder FROM t) -- compute padding size
    SELECT decode(
        t.trans ||
        CASE WHEN rem.remainder > 0
           THEN repeat('=', (4 - rem.remainder))
           ELSE '' END,
    'base64') FROM t, rem;
$$ IMMUTABLE;


CREATE OR REPLACE FUNCTION algorithm_sign(signables text, secret text, algorithm text)
RETURNS text LANGUAGE sql AS $$
WITH
  alg AS (
    SELECT CASE
      WHEN algorithm = 'HS256' THEN 'sha256'
      WHEN algorithm = 'HS384' THEN 'sha384'
      WHEN algorithm = 'HS512' THEN 'sha512'
      ELSE '' END AS id)  -- hmac throws error
SELECT url_encode(hmac(signables, secret, alg.id)) FROM alg;
$$ IMMUTABLE;


CREATE OR REPLACE FUNCTION sign(payload json, secret text, algorithm text DEFAULT 'HS256')
RETURNS text LANGUAGE sql AS $$
WITH
  header AS (
    SELECT url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) AS data
    ),
  payload AS (
    SELECT url_encode(convert_to(payload::text, 'utf8')) AS data
    ),
  signables AS (
    SELECT header.data || '.' || payload.data AS data FROM header, payload
    )
SELECT
    signables.data || '.' ||
    algorithm_sign(signables.data, secret, algorithm) FROM signables;
$$ IMMUTABLE;


CREATE OR REPLACE FUNCTION try_cast_double(inp text)
RETURNS double precision AS $$
  BEGIN
    BEGIN
      RETURN inp::double precision;
    EXCEPTION
      WHEN OTHERS THEN RETURN NULL;
    END;
  END;
$$ language plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION verify(token text, secret text, algorithm text DEFAULT 'HS256')
RETURNS table(header json, payload json, valid boolean) LANGUAGE sql AS $$
  SELECT
    jwt.header AS header,
    jwt.payload AS payload,
    jwt.signature_ok AND tstzrange(
      to_timestamp(try_cast_double(jwt.payload->>'nbf')),
      to_timestamp(try_cast_double(jwt.payload->>'exp'))
    ) @> CURRENT_TIMESTAMP AS valid
  FROM (
    SELECT
      convert_from(url_decode(r[1]), 'utf8')::json AS header,
      convert_from(url_decode(r[2]), 'utf8')::json AS payload,
      r[3] = algorithm_sign(r[1] || '.' || r[2], secret, algorithm) AS signature_ok
    FROM regexp_split_to_array(token, '\.') r
  ) jwt
$$ IMMUTABLE;
-----------------------------------------------------------------------
--END
-----------------------------------------------------------------------

-- add type
CREATE TYPE jwt_token AS (
  token text
);

-- login should be on your exposed schema
create or replace function
api.login(email text, pass text) returns jwt_token as $$
declare
  _role name;
  result jwt_token;
begin
  -- check email and password
  select user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;

  select sign(
      row_to_json(r), current_setting('api.jwt_secret')
    ) as token
    from (
      select _role as role, login.email as email,
         extract(epoch from now())::integer + 60*60 as exp
    ) r
    into result;
  return result;
end;
$$ language plpgsql security definer;

grant execute on function login(text,text) to web_anon;
```

Ok, add a user:

```sql
insert into basic_auth.users (email, pass, role) values
  ('rotty3000@gmail.com', 'test1', 'todo_user');
```

Don't forget to set the jwt secret:

___Note:__ When using `ALTER DATABASE` you need to restart the session for the settings to take effect._

```sql
-- use the value from the tutorial.conf from earlier
ALTER DATABASE postgres SET "api.jwt_secret" TO '<secret>';
```

Now try:

```shell
curl "http://localhost:3000/rpc/login" \
  -X POST -H "Content-Type: application/json" \
  -d '{ "email": "rotty3000@gmail.com", "pass": "test1" }'
```

Or store the token immediately in a shell variable:
```shell
export TOKEN=$(curl "http://localhost:3000/rpc/login" -s -X POST -H "Content-Type: application/json"   -d '{ "email": "rotty3000@gmail.com", "pass": "test1" }' | jq -r '.token')
```

## Auth with Keycloak

...

Get token from keycloak

```shell
TOKEN=$(curl -s http://172.20.0.2:8080/realms/my-app/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=myappclient' --data-urlencode 'username=rotty3000' --data-urlencode 'password=test1' | jq -r '.access_token')
```

Post the CSV file to fill the table

```shell
curl http://localhost:3000/sales \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/csv" \
  -d @Warehouse_and_Retail_Sales.csv | jq
```

## References
- https://www.mathieupassenaud.fr/codeless_backend/