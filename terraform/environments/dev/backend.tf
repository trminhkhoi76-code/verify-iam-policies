terraform {
  backend "s3" {
    bucket         = "verrify-terraform-state-develop"
    key            = "heatmap-japan/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "verify-terraform-lock"
  }
}