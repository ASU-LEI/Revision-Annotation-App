# Terraform remote state for the lean environment.
# Locking uses S3 native lockfiles (Terraform >= 1.10); no DynamoDB table.
bucket       = "lei-tf-state"
key          = "revision-annotation-app/terraform.tfstate"
region       = "us-west-2"
use_lockfile = true
encrypt      = true
