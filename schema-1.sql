create table api.sales (
	id serial primary key not null,
	year text not null,
	month integer not null,
	supplier text not null,
	item_code text not null,
	item_description text not null,
	item_type text not null,
	retail_sales decimal not null,
	retail_transfers decimal not null,
	warehouse_sales decimal not null
);