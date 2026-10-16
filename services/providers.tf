provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project   = "aws-learning"
      ManagedBy = "terraform"
      Owner     = "abhishek"
    }
  }
}
