-- STEP 0
-- create the roles and grants we need for the demo
create extension pgmq;
create role authenticator noinherit login password '${PGRST_AUTHENTICATOR_PASSWORD}';
create role webanon nologin;
create role webuser nologin;
grant usage on schema pgmq to webanon;
grant usage on schema pgmq to webuser;
grant webanon to authenticator;
grant webuser to authenticator;

-- grant permissions
alter default privileges in schema pgmq grant select on tables to webuser;
grant select on pgmq.meta to webuser;
grant all on schema pgmq to webuser;
grant postgres to webuser;