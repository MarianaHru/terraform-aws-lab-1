terraform {
  backend "s3" {
    bucket         = "it-step-lab-terraform-state-grudzinska"
    key            = "dev/domain1/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
