provider oci {
	region = "eu-frankfurt-1"
}

resource oci_core_instance generated_oci_core_instance {
	agent_config {
		is_management_disabled = "false"
		is_monitoring_disabled = "false"
	}
	availability_config {
		recovery_action = "RESTORE_INSTANCE"
	}
	availability_domain = var.availability_domain
	compartment_id = var.compartment_id
	create_vnic_details {
		assign_public_ip = "true"
		subnet_id = oci_core_subnet.generated_oci_core_subnet.id
		nsg_ids = [
			oci_core_network_security_group.nsg-gigispoll.id,
		]
	}
	display_name = "gigispoll"
	instance_options {
		are_legacy_imds_endpoints_disabled = "false"
	}
	metadata = {
		"ssh_authorized_keys" = var.ssh_authorized_keys
	}
	shape = var.shape
	source_details {
		source_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaf6gm7xvn7rhll36kwlotl4chm25ykgsje7zt2b4w6gae4yqfdfwa"
		source_type = "image"
	}
}

resource oci_core_vcn generated_oci_core_vcn {
	cidr_block = "10.0.0.0/16"
	compartment_id = var.compartment_id
	display_name = "vcn-gigispoll"
	dns_label = "vcn1gigispoll"
}

resource oci_core_subnet generated_oci_core_subnet {
	cidr_block = "10.0.0.0/24"
	compartment_id = var.compartment_id
	display_name = "public-subnet"
	dns_label = "publicsubnet"
	route_table_id = oci_core_vcn.generated_oci_core_vcn.default_route_table_id
	vcn_id = oci_core_vcn.generated_oci_core_vcn.id
}

resource oci_core_internet_gateway generated_oci_core_internet_gateway {
	compartment_id = var.compartment_id
	display_name = "Internet Gateway vcn-gigispoll"
	enabled = "true"
	vcn_id = oci_core_vcn.generated_oci_core_vcn.id
}

resource oci_core_network_security_group nsg-gigispoll {
  compartment_id = var.compartment_id
  display_name = "nsg-gigispoll"
  vcn_id = oci_core_vcn.generated_oci_core_vcn.id
}

resource oci_core_network_security_group_security_rule nsg-gigispoll_network_security_group_security_rule_1 {
  destination_type          = ""
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.nsg-gigispoll.id
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      max = "80"
      min = "80"
    }
  }
}

resource oci_core_default_route_table generated_oci_core_default_route_table {
	route_rules {
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = oci_core_internet_gateway.generated_oci_core_internet_gateway.id
	}
	manage_default_resource_id = oci_core_vcn.generated_oci_core_vcn.default_route_table_id
}

variable compartment_id {}
variable availability_domain {}
variable shape {
  default = "VM.Standard.E2.1.Micro"
}
variable ssh_authorized_keys {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSOFfGW2I4W3uyLcNr8YSCD/J/F7DPIvDoT8DIyWX2lbPf17PPGmJsQLbehx0mS8RBT4s20PIFB90svSyI60yqjs2aes3kBVS7XpqmNSbfOUdalJSPHnRXSY/z0k390SVsx7j4aXJN3otV8SUVj3LBYofV5J0WMwja/rk87o2hfzzO8YYZ01s3wXMtPDjj7TUt0lykMdgFb7QW5a7Y66V4+lBe0o08AZxixUVSd0H/DQ8R8HmxQLG0i9Nl7TfhFVeeUvE0fSyQaLgmjLGbRKg0QmGW2hKK9BOehing8G5n0dd1hJ6/pXLY9dQn4jI7NqCxVpMYKj9WOq9tE8nhZt9t ssh-key-2020-11-18"
}

output "Public_IP" {
  value = oci_core_instance.generated_oci_core_instance.public_ip
}
