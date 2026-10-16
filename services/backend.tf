terraform {
  backend "s3" {
    bucket       = "abhishek-tfstate-7391"
    key          = "services/terraform.tfstate" # sab services ek state mein (lab); bade setup mein har service ki alag
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
