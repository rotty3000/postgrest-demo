create role webanon nologin;
create role webuser nologin;

grant usage on schema api to webanon;
grant usage on schema api to webuser;

grant webanon to authenticator;
grant webuser to authenticator;

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

-- ** load the data
-- curl http://localhost:3000/sales -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @Warehouse_and_Retail_Sales.json

-- ** how many records are there?
-- curl http://localhost:3000/sales?select=id.count()

-- ** I noticed there are records with no supplier
-- curl http://localhost:3000/sales?supplier=eq.

-- ** how many?
-- curl http://localhost:3000/sales?supplier=eq.&select=id.count()

-- ** What do those look like?
-- curl http://localhost:3000/sales?supplier=eq.&select=item_description,item_type&order=item_description

-- ** let's patch them using a "NO SUPPLIER"
-- curl 'http://localhost:3000/sales?supplier=eq.' -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"supplier": "NO SUPPLIER"}'

-- create our supplier table
create table if not exists api.supplier (
	id serial primary key not null,
	name text not null,
	unique(name)
);
-- populate the supplier table
insert into api.supplier (name) select distinct supplier from api.sales;
-- alter the api.sales table to add foreign key on supplier
alter table api.sales
	add column supplier_id integer
		constraint sales_supplier_fk_id
		references api.supplier (id)
		on update cascade
		on delete cascade;
-- then pull in the ids
update api.sales as sa
	set supplier_id = (
		select id from api.supplier as su where su.name = sa.supplier
	);
-- set supplier_id column to not null
alter table api.sales alter supplier_id set not null;
-- drop supplier
alter table api.sales drop column supplier;
-- grant
grant select on api.supplier to webanon;
grant all on api.supplier to webuser;
grant usage, select on sequence api.supplier_id_seq to webuser;
NOTIFY pgrst, 'reload schema';

-- curl http://localhost:3000/sales?select=item_description,supplier(id,name)&limit=10

-- curl http://localhost:3000/sales?limit=10

create table api.item (
	id serial primary key,
	code text not null,
	description text not null,
	type text not null,
	unique(code,description,type)
);
-- grant
grant select on api.item to webanon;
grant all on api.item to webuser;
grant usage, select on sequence api.item_id_seq to webuser;

NOTIFY pgrst, 'reload schema';

-- check the schema

insert into api.item (
	code, description, type
) select distinct item_code, item_description, item_type from api.sales;

-- alter the api.sales table to add foreign key on item
alter table api.sales
	add column item_id integer
		constraint sales_item_fk_id
		references api.item (id)
		on update cascade
		on delete cascade;

-- then pull in the ids
update api.sales as S
	set item_id = (
		select id from api.item as I where I.code = S.item_code and I.description = S.item_description and I.type = S.item_type
	);

alter table api.sales alter item_id set not null;

create index sales_idx on api.item (description) with (deduplicate_items = off);

NOTIFY pgrst, 'reload schema';

alter table api.sales drop column item_code, drop item_description, drop item_type;

NOTIFY pgrst, 'reload schema';

-- join
-- http://localhost:3000/sales?limit=10&select=*,supplier(*),item(*)

-- reverse join
-- http://localhost:3000/item?limit=10&select=*,sales(*,supplier(*))&order=description.asc

-- another reverse join
-- http://localhost:3000/supplier?limit=10&select=*,sales(*,item(*))

-- aggregate functions
-- http://localhost:3000/supplier?limit=10&select=*,retail_sales:sales(retail_sales.sum()),warehouse_sales:sales(warehouse_sales.sum())

-- create a relation table that connects items to suppliers called deliverable
create table api.deliverable (
	id serial primary key,
	supplier_id integer references api.supplier (id)
		on update cascade
		on delete cascade,
	item_id integer references api.item (id)
		on update cascade
		on delete cascade,
	unique(supplier_id, item_id)
);
-- grant
grant select on api.deliverable to webanon;
grant all on api.deliverable to webuser;
grant usage, select on sequence api.deliverable_id_seq to webuser;

NOTIFY pgrst, 'reload schema';

insert into api.deliverable (
	supplier_id, item_id
) select distinct supplier_id, item_id from api.sales;

-- alter the api.sales table to add foreign key on deliverable
alter table api.sales
	add column deliverable_id integer
		constraint sales_deliverable_fk_id
		references api.deliverable (id)
		on update cascade
		on delete cascade;

-- then pull in the ids
update api.sales as S
	set deliverable_id = (
		select id from api.deliverable as D where D.supplier_id = S.supplier_id and D.item_id = S.item_id
	);

alter table api.sales drop column supplier_id, drop item_id;

-- http://localhost:3000/sales?limit=10

-- sales --> item, supplier
-- http://localhost:3000/sales?limit=10&select=year,month,retail_sales,retail_transfers,warehouse_sales,deliverable(item(*),supplier(*))&order=year.asc,month.asc

-- supplier --> item, sales

-- http://localhost:3000/supplier?select=name,deliverable(item(description,type))
-- http://localhost:3000/supplier?name=eq.LYON%20DISTILLING%20COMPANY%20LLC&select=name,deliverable(item(description,type),sales(year,retail_sales:retail_sales.sum(),warehouse_sales:warehouse_sales.sum(),retail_transfers:retail_transfers.sum()))

-- item --> supplier, sales
-- http://localhost:3000/item?limit=20&select=description,type,deliverable(supplier(name))
-- http://localhost:3000/item?limit=20&select=description,type,deliverable(supplier(name),sales(retail_sales:retail_sales.sum()))