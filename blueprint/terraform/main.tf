
/*
Responsible for deploying the lambda, creating its IAM Role and IAM Policy. This module also creates the trusted role and policy that
is used by Genesys Cloud to invoke the lambda in
*/
module "lambda_order_status" {
  source                  = "./modules/lambda_order_status"
  environment             = var.environment
  prefix                  = var.prefix
  organizationId          = var.organizationId
  aws_region              = var.awsRegion
  lambda_zip_file         = data.archive_file.lambda_zip.output_path
  lambda_source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

/*
   This module creates a data integration for the lambda.  The module will create the credentials and in the integration.
*/
module "lambda_data_integration" {
  source                            = "git::https://github.com/GenesysCloudDevOps/integration-lambda-module.git?ref=main"
  environment                       = var.environment
  prefix                            = var.prefix
  data_integration_trusted_role_arn = module.lambda_order_status.data_integration_trusted_role_arn
}

/*
   Setups a data action that will invoke a lambda
*/
module "lambda_data_action" {
  source                 = "git::https://github.com/GenesysCloudDevOps/data-action-lambda-module.git?ref=main"
  environment            = var.environment
  prefix                 = var.prefix
  secure_data_action     = false
  genesys_integration_id = module.lambda_data_integration.genesys_integration_id
  lambda_arn             = module.lambda_order_status.lambda_arn
  data_action_input      = file("${path.module}/contracts/data-action-input.json")
  data_action_output     = file("${path.module}/contracts/data-action-output.json")
}

/*
   Creates the queues used within the flow
*/
module "dude_queues" {
  source                   = "git::https://github.com/GenesysCloudDevOps/genesys-cloud-queues-demo.git?ref=main"
  classifier_queue_names   = ["dude-cancellations", "dude-general-support"]
  classifier_queue_members = []
}

/*
   Looks up the id of the flow so we can associate it with a widget
*/
data "genesyscloud_flow" "my_chat_flow" {
  depends_on = [
    null_resource.deploy_archy_flow_chat
  ]
  name = "DudeWheresMyStuffChat"
}

/*   
   Configures the widget deployment
*/
module "widget_deploy" {
  source      = "./modules/widget_deployment"
  environment = var.environment
  prefix      = var.prefix
  flowId      = data.genesyscloud_flow.my_chat_flow.id
}



