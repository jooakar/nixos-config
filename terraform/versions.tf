terraform {
  required_version = ">= 1.10"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "vps/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://d247563982d77af7026e8d7168647e81.eu.r2.cloudflarestorage.com"
    }

    use_lockfile                = true
    use_path_style              = true
    skip_s3_checksum            = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}

provider "upcloud" {
  # UPCLOUD_TOKEN from secrets/upcloud-api.age
}
