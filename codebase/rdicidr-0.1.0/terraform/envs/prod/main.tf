# Configure the AWS Provider
provider "aws" {
  region = var.region
}

module "app" {
    source = "../../module/app"
    bucket_name = var.bucket_name
    env         = var.env
}