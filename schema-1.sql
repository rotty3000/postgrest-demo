-- STEP 1
-- create our main table
create table if not exists api.sales (
  id serial primary key not null,
  year text not null,
  month integer not null,
  supplier text not null,
  item_code text not null,
  item_description text not null,
  item_type text not null,
  retail_sales decimal,
  retail_transfers decimal,
  warehouse_sales decimal
);
-- grant permissions
grant select on api.sales to webanon;
grant all on api.sales to webuser;
grant usage, select on sequence api.sales_id_seq to webuser;
-- tell PostgREST to update it's schema
NOTIFY pgrst, 'reload schema';