create table api.sales (
	id serial primary key not null,
	year text not null,
	month integer not null,
	supplier_id integer not null,
	item_id integer not null,
	retail_sales decimal not null,
	retail_transfers decimal not null,
	warehouse_sales decimal not null,
	foreign key (supplier_id) references api.supplier (id),
	foreign key (item_id) references api.item (id),
);

create table api.supplier (
	id serial primary key not null,
	name text not null,
	unique(name)
);

create table api.item (
	id serial primary key not null,
	code text not null,
	description text not null,
	type text not null,
	unique(code,description,type)
);