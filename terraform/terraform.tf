terraform {
  required_providers {
    google = {
      // https://github.com/hashicorp/terraform-provider-google/releases
      source  = "hashicorp/google"
      version = ">= 5.38.0"
    }
  }

  // https://github.com/hashicorp/terraform/releases
  required_version = ">= 1.9.2"
}
