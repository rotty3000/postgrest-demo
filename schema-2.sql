create table api.sales (
	id serial primary key not null,
	year text not null,
	month integer not null,
	supplier_id integer not null,
	item_code text not null,
	item_description text not null,
	item_type text not null,
	retail_sales decimal not null,
	retail_transfers decimal not null,
	warehouse_sales decimal not null,
	foreign key (supplier_id) references api.supplier (id)
);

create table api.supplier (
	id serial primary key not null,
	name text not null,
	unique(name)
);
