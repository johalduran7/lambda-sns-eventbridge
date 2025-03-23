

# Create event bridge to trigger Lambda
module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws" #Module in public registry https://registry.terraform.io/modules/terraform-aws-modules/eventbridge/aws/latest
  role_name = "eventbridge_role_${var.region}"
  create_bus = false

  rules = {
    crons = {
      description         = "Trigger for a Lambda"
      schedule_expression = "cron(0 15-23/3,0 * * ? *)" # from 10 AM ET to 7 PM. This is in GMT-0
    }
  }

  targets = {
    crons = [
      {
        name  = "lambda-loves-cron"
        arn   = "${aws_lambda_alias.prod_lambda_alias.arn}"
        input = jsonencode({ "job" : "cron-by-rate" })
      }
    ]
  }
  tags = {
    Name      = "lambda_rule"
    Terraform = "yes"
  }
}