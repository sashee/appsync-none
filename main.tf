provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_dynamodb_table" "user" {
  name         = "user-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# sample data

resource "aws_dynamodb_table_item" "user1" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key

  item = <<ITEM
{
  "id": {"S": "user1"},
	"name": {"S": "User 1"},
	"first_name": {"S": "John"},
	"last_name": {"S": "Adams"},
	"last_modified": {"N": "1661329363932"},
	"last_login": {"N": "1661329383064"}
}
ITEM
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "dynamodb:GetItem",
    ]
    resources = [
      aws_dynamodb_table.user.arn,
    ]
  }
}

resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "AWS_IAM"
}

resource "aws_appsync_datasource" "ddb_users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.user.name
  }
}

resource "aws_appsync_datasource" "none" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "none"
  type             = "NONE"
}

# resolvers
resource "aws_appsync_resolver" "Query_user" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "Query"
  field             = "user"
  data_source       = aws_appsync_datasource.ddb_users.name
  request_template  = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "GetItem",
	"key" : {
		"id" : {"S": $util.toJson($ctx.args.id)}
	},
	"consistentRead" : true
}
EOF
  response_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "User_name" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "User"
  field             = "name"
  data_source       = aws_appsync_datasource.none.name
  request_template  = <<EOF
{
	"version": "2018-05-29",
	"payload": "$util.toJson($ctx.source.first_name) $util.toJson($ctx.source.last_name)"
}
EOF
  response_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "User_last_modified" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "User"
  field             = "last_modified"
  data_source       = aws_appsync_datasource.none.name
  request_template  = <<EOF
{
	"version": "2018-05-29",
	"payload": $util.time.epochMilliSecondsToISO8601($ctx.source.last_modified)
}
EOF
  response_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "User_last_login" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "User"
  field             = "last_login"
  data_source       = aws_appsync_datasource.none.name
  request_template  = <<EOF
{
	"version": "2018-05-29",
	"payload": $util.time.epochMilliSecondsToFormatted($ctx.source.last_modified, $ctx.args.format)
}
EOF
  response_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
$util.toJson($ctx.result)
EOF
}
