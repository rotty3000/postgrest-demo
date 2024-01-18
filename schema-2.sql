-- STEP 2
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
-- then pull in the supplier ids
update api.sales as sa
	set supplier_id = (
		select id from api.supplier as su where su.name = sa.supplier
	);
-- set supplier_id column to not null
alter table api.sales alter supplier_id set not null;
-- drop supplier
alter table api.sales drop column supplier;
-- grant permissions
grant select on api.supplier to webanon;
grant all on api.supplier to webuser;
grant usage, select on sequence api.supplier_id_seq to webuser;
-- tell PostgREST to update it's schema
NOTIFY pgrst, 'reload schema';
