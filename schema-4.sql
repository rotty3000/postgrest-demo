create table api.sales (
	id serial primary key not null,
	year text not null,
	month integer not null,
	deliverable_id integer not null,
	retail_sales decimal not null,
	retail_transfers decimal not null,
	warehouse_sales decimal not null,
	foreign key (deliverable_id) references api.deliverable (id)
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

create table api.deliverable (
	id serial primary key not null,
	supplier_id integer not null,
	item_id integer not null,
	unique(supplier_id, item_id),
	foreign key (supplier_id) references api.supplier (id),
	foreign key (item_id) references api.item (id)
);