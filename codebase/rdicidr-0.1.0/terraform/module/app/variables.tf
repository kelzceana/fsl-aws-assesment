# In this file put the variables related to the deployment
variable "bucket_name" {
    type        = string
    description = "s3 bucket name"
}

variable "env" {
    type        = string
    description = "environment (devel, stage, prod)"
}

variable "domain_name" {
    type        = string
    description = "cloud front distribution"
    default     = ""
}
