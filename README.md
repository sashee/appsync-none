# Sample code for some uses of the AppSync NONE data source

## Deploy

* ```terraform init```
* ```terraform apply```

## Usage

Send queries to the AppSync API:

```graphql
query MyQuery {
  user(id: "user1") {
    last_login(format: "MM/dd/YYYY HH:mm")
    last_modified
    name
  }
}
```

Response:

```json
{
  "data": {
    "user": {
      "last_login": "08/24/2022 08:23",
      "last_modified": "2022-08-24T08:22:43.932Z",
      "name": "John Adams"
    }
  }
}
````

## Cleanup

* ```terraform destroy```
