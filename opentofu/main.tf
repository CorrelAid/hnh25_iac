data "infisical_secrets" "main" {
  env_slug     = "prod"
  folder_path  = "/"
  workspace_id = var.infisical_workspace_id
}

provider "hcloud" {
  token = data.infisical_secrets.main.secrets["PARROTPARK_HCLOUD_TOKEN"].value
}


provider "digitalocean" {
  token             = data.infisical_secrets.main.secrets["DO_TOKEN"].value
  spaces_access_id  = data.infisical_secrets.main.secrets["DO_SPACES_ACCESS_ID"].value
  spaces_secret_key = data.infisical_secrets.main.secrets["DO_SPACES_SECRET_KEY"].value
}

provider "hetznerdns" {
  api_token = data.infisical_secrets.main.secrets["HETZNER_DNS"].value

}

provider "restapi" {
  uri                  = "https://api.netbird.io"
  write_returns_object = true
  debug                = true

  headers = {
    "Authorization" = "Token ${data.infisical_secrets.main.secrets["NETBIRD_TOKEN"].value}",
    "Content-Type"  = "application/json",
    "Accept"        = "application/json"
  }

  create_method  = "POST"
  read_method    = "GET"
  update_method  = "PUT"
  destroy_method = "DELETE"
}

###################

resource "restapi_object" "group" {
  provider                  = restapi
  path                      = "/api/groups"
  ignore_all_server_changes = true
  data = jsonencode({
    name = var.project_settings.name
  })
}

resource "restapi_object" "policy" {
  provider                  = restapi
  path                      = "/api/policies"
  ignore_all_server_changes = true
  data = jsonencode({
    name        = var.project_settings.name,
    description = "This is a policy that allows connections between all the resources in the ${var.project_settings.name} group",
    enabled     = true,
    rules = [
      {
        name          = "Default",
        description   = "This is a default rule that allows connections between all the resources",
        enabled       = true,
        action        = "accept",
        bidirectional = true,
        protocol      = "all",
        sources       = [restapi_object.group.api_data.id],
        destinations  = [restapi_object.group.api_data.id],
      }
    ]
  })
}

resource "restapi_object" "setup_token" {
  provider                  = restapi
  path                      = "/api/setup-keys"
  ignore_all_server_changes = true
  data = jsonencode({
    name                   = var.project_settings.name
    type                   = "reusable"
    expires_in             = null
    auto_groups            = [restapi_object.group.api_data.id, var.netbird_vps_group]
    usage_limit            = 0
    ephemeral              = false
    allow_extra_dns_labels = false
  })
}

#################

resource "hcloud_server" "main" {
  name        = var.project_settings.name
  image       = var.vps.image
  server_type = var.vps.size
  location    = var.vps.region
  backups = true
  public_net {
    ipv6_enabled = false
    ipv4_enabled = true
  }
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
  user_data = templatefile("templates/user_data.tftpl", {
    public_ssh_key = var.public_ssh_key,
    user           = var.vps.user,
    hostname       = var.project_settings.name,

    netbird_setup_key = restapi_object.setup_token.api_data.key,

    distro_code = var.vps.distro_code
    }
  )
}

resource "hcloud_firewall" "main" {
  name = var.project_settings.name

  # Allow HTTP inbound
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow HTTPS inbound
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }


  # Allow all TCP outbound
  rule {
    direction = "out"
    protocol  = "tcp"
    port      = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Allow all UDP outbound
  rule {
    direction = "out"
    protocol  = "udp"
    port      = "any"
    destination_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_firewall_attachment" "main" {
  firewall_id = hcloud_firewall.main.id
  server_ids  = [hcloud_server.main.id]
}

#############
resource "digitalocean_spaces_bucket" "main" {
  name   = var.project_settings.name
  region = var.do_region
  acl = "public-read"
}

resource "digitalocean_cdn" "mycdn" {
  origin = digitalocean_spaces_bucket.main.bucket_domain_name
}

#############

resource "digitalocean_spaces_bucket" "backup" {
  name   = "${var.project_settings.name}backup"
  region = var.do_region
}


#############

resource "digitalocean_project" "main" {
  name = var.project_settings.name
}

resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.main.id
  resources = [
    digitalocean_spaces_bucket.main.urn,digitalocean_spaces_bucket.backup.urn
  ]
}

######

resource "null_resource" "proxy_cleanup" {
  triggers = {
    server_name   = hcloud_server.main.name
    netbird_token = data.infisical_secrets.main.secrets["NETBIRD_TOKEN"].value
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "Starting NetBird peer cleanup for ${self.triggers.server_name}"
      http_code=$(curl -s -o response.json -w "%%{http_code}" -X GET https://api.netbird.io/api/peers \
        -H 'Accept: application/json' \
        -H 'Authorization: Token ${self.triggers.netbird_token}' \
        -H 'Content-Type: application/json')

      if [ "$http_code" != "200" ]; then
        echo "Failed to get peers list. Status code: $http_code"
        exit 1
      fi

      peer_id=$(cat response.json | jq -r '.[] | select(.dns_label == "${self.triggers.server_name}.netbird.cloud") | .id')

      if [ -z "$peer_id" ]; then
        echo "No peer found with DNS label ${self.triggers.server_name}.netbird.cloud"
        exit 0
      fi

      echo "Found peer ID: $peer_id, attempting to delete"
      delete_status=$(curl -s -o /dev/null -w "%%{http_code}" -X DELETE https://api.netbird.io/api/peers/$peer_id \
        -H 'Authorization: Token ${self.triggers.netbird_token}')

      if [ "$delete_status" != "200" ] && [ "$delete_status" != "204" ]; then
        echo "Failed to delete peer. Status code: $delete_status"
        exit 1
      fi
      rm -f response.json
    EOT
  }
}


###################

data "hetznerdns_zone" "dns_zone" {
  name = var.dns.zone
}

resource "hetznerdns_record" "main" {
  zone_id = data.hetznerdns_zone.dns_zone.id
  name    = var.dns.subdomain
  value   = hcloud_server.main.ipv4_address
  type    = "A"
}

resource "hetznerdns_record" "static" {
  zone_id = data.hetznerdns_zone.dns_zone.id
  name    = var.dns.subdomain_static
  value   = hcloud_server.main.ipv4_address
  type    = "A"
}

resource "hetznerdns_record" "forward" {
  zone_id = data.hetznerdns_zone.dns_zone.id
  name    = var.dns.subdomain_forward
  value   = hcloud_server.main.ipv4_address
  type    = "A"
}

#################

# writing data to files for ansible

resource "local_file" "hosts" {
  filename = "../ansible/hosts"
  content = templatefile("templates/inventory.tftpl", {
    user         = var.project_settings.user
    server_name  = var.project_settings.name
    netbird_fqdn = "${var.project_settings.name}.netbird.cloud"
  })
}

resource "local_file" "group_vars" {
  filename = "../ansible/group_vars/group_vars.yml"
  content = templatefile("templates/group_vars.tftpl",
    {
      subdomain        = var.dns.subdomain
      subdomain_static = var.dns.subdomain_static
      subdomain_forward = var.dns.subdomain_forward
      domain           = var.dns.zone
      netbird_group_id = restapi_object.group.api_data.id
      s3_bucket_name   = digitalocean_spaces_bucket.main.name
      s3_backupbucket_name   = digitalocean_spaces_bucket.backup.name
      s3_endpoint      = digitalocean_spaces_bucket.main.endpoint
      s3_region        = digitalocean_spaces_bucket.main.region
      s3_cdn_endpoint = digitalocean_cdn.mycdn.endpoint
    }
  )
}
