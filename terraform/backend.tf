terraform {
    backend "s3" {
        bucket = "terraform-state-024596526245"
        key    = "terraform-cicd-pipeline/terraform.tfstate"
        region = "eu-west-1"

        encrypt = true
    }
}
