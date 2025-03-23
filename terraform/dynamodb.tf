
# DynamoDB Table to store the price of dollar


resource "aws_dynamodb_table" "price_dollar" {
  name         = "price_dollar"
  billing_mode = "PAY_PER_REQUEST" # On-demand billing mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # S = String; change to "N" for Number if required
  }



  tags = {
    Environment = "Production"
    Project     = "dollar_sns"
    Terraform   = "yes"
  }
}

# Adding the first row. I don't Need to add the first row anymore, I'm handling this in the lambda function directly
# resource "aws_dynamodb_table_item" "price_dollar_first_row" {
#   table_name = aws_dynamodb_table.price_dollar.name
#   hash_key   = aws_dynamodb_table.price_dollar.hash_key

#   item = <<ITEM
# {
#   "id": {"S": "1"},
#   "price": {"S": "4140"}
# }
# ITEM
# }
