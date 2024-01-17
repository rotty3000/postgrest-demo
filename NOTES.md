## Notes

The ip of the tutorial (postgrest) container:

```shell
docker container inspect tutorial | jq -r '.[] | .NetworkSettings.Networks["my-app"].IPAddress'

172.20.0.3
```

The ip address of the keycloak container:

```shell
docker container inspect keycloak | jq -r '.[] | .NetworkSettings.Networks["my-app"].IPAddress'

172.20.0.2
```

http://localhost:3000/sales?retail_sales=gt.2000

http://localhost:3000/sales?and=(retail_sales.gte.490,retail_sales.lte.500)

http://localhost:3000/sales?and=(retail_sales.gte.490,retail_sales.lte.500)&select=id,name:supplier

http://localhost:3000/sales?and=(retail_sales.gte.490,retail_sales.lte.500)&select=id,name:supplier,sales:retail_sales&order=retail_sales.desc

http://localhost:3000/sales?select=product:item_description&limit=20
