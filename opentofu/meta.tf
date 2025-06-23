terraform {
  required_version = "1.9.1"
  backend "s3" {
    endpoints = {
      s3 = "https://fra1.digitaloceanspaces.com"
    }

    bucket = "opentofustates"
    key    = "hnh25state.tfstate"

    # Deactivate a few AWS-specific checks
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    region                      = "us-east-1"
  }

  required_providers {
    infisical = {
      version = "0.11.6"
      source  = "infisical/infisical"
    }
    hetznerdns = {
      source  = "germanbrew/hetznerdns"
      version = "3.2.2"
    }
        hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 0.13"
    }

     digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    restapi = {
      source  = "mastercard/restapi"
      version = "2.0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"

    }
  }
}

provider "infisical" {
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}

