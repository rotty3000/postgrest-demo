-- STEP 3
-- create our item table
create table api.item (
	id serial primary key,
	code text not null,
	description text not null,
	type text not null,
	unique(code,description,type)
);
-- populate the item table
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
-- then pull in the item ids
update api.sales as S
	set item_id = (
		select id from api.item as I where I.code = S.item_code and I.description = S.item_description and I.type = S.item_type
	);
-- do some table maintenance
alter table api.sales alter item_id set not null;
alter table api.sales drop column item_code, drop item_description, drop item_type;
-- grant permissions
grant select on api.item to webanon;
grant all on api.item to webuser;
grant usage, select on sequence api.item_id_seq to webuser;
-- tell PostgREST to update it's schema
NOTIFY pgrst, 'reload schema';