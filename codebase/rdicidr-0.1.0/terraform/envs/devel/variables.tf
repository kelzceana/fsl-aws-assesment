variable "region" {
    type = string
    description = "aws region"
}
variable "bucket_name" {
    type = string
    description = "s3 bucket"
}
variable "env" {
    type = string
    description = "environment (devel, stage, prod)"
}
