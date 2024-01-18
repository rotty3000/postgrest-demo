-- STEP 0
-- create the roles and grants we need for the demo
create schema api;
create role authenticator noinherit login password '${PGRST_AUTENTICATOR_PASSWORD}';
create role webanon nologin;
create role webuser nologin;
grant usage on schema api to webanon;
grant usage on schema api to webuser;
grant webanon to authenticator;
grant webuser to authenticator;