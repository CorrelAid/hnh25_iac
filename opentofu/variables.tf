variable "infisical_client_secret" {
  type = string
}

variable "infisical_client_id" {
  type = string
}


variable "infisical_workspace_id" {
  type    = string
  default = "c6b11c29-4e36-472e-93be-54130b65a987"
}


variable "netbird_vps_group" {
  type    = string
  default = "csa40a3l0ubs738srrgg"
}

variable "do_region" {
  type = string
  default = "fra1"

}
variable "project_settings" {
  type = map(any)
  default = {
    name             = "hnh25"
    user             = "correlaid"
  }
}

variable "vps" {
  type = map(any)
  default = {
    size              = "cpx31"
    image             = "ubuntu-24.04"
    user              = "correlaid"
    region         = "nbg1"
    distro_code = "jammy"
  }

}

variable "dns" {
  type = map(any)
  default = {
    zone                = "correlaid.org"
    subdomain   = "hack"
    subdomain_static   = "static.hack"
  }
}

variable "public_ssh_key" {
  type = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOLFcYL/WfQ225n2JubmmGDqLATlx2Cig++UDx3/k0o correlaid"
}