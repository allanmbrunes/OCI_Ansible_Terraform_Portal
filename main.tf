// Copyright (c) 2017, 2021, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0


variable "compartment_ocid" {}
variable "region" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {}
variable "ssh_public_key" {}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid = var.user_ocid
  fingerprint = var.fingerprint
  private_key = var.private_key
  region = var.region
}

variable "ad_region_mapping" {
  type = map(string)

  default = {
    us-phoenix-1 = 2
    us-ashburn-1 = 2
    sa-saopaulo-1 = 1
  }
}

variable "images" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.9-2020.10.26-0"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaacirjuulpw2vbdiogz3jtcw3cdd3u5iuangemxq5f5ajfox3aplxa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaabbg2rypwy5pwnzinrutzjbrs3r35vqzwhfjui7yibmydzl7qgn6a"
    sa-saopaulo-1   = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaudio63gdicxwujhfok7jdyewf6iwl6sgcaqlyk4fvttg3bw6gbpq"
  }
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = var.ad_region_mapping[var.region]
}

resource "oci_core_virtual_network" "vcn-net-aut" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "vcnnetaut"
  dns_label      = "vcnnetAut"
}

resource "oci_core_subnet" "financial_subnet" {
  cidr_block        = "10.0.1.0/24"
  display_name      = "financialSubnet"
  dns_label         = "financialsubnet"
  security_list_ids = [oci_core_security_list.financial_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.vcn-net-aut.id
  route_table_id    = oci_core_route_table.net_aut_route_table.id
  dhcp_options_id   = oci_core_virtual_network.vcn-net-aut.default_dhcp_options_id
}

resource "oci_core_subnet" "commercial_subnet" {
  cidr_block        = "10.0.2.0/24"
  display_name      = "commercialSubnet"
  dns_label         = "commercialsubnet"
  security_list_ids = [oci_core_security_list.commercial_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.vcn-net-aut.id
  route_table_id    = oci_core_route_table.net_aut_route_table.id
  dhcp_options_id   = oci_core_virtual_network.vcn-net-aut.default_dhcp_options_id
}

resource "oci_core_route_table" "net_aut_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn-net-aut.id
  display_name   = "netautRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.net_aut_internet_gateway.id
  }
}

resource "oci_core_internet_gateway" "net_aut_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "netautIG"
  vcn_id         = oci_core_virtual_network.vcn-net-aut.id
}

resource "oci_core_security_list" "commercial_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn-net-aut.id
  display_name   = "commercialSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "172.103.149.203/32"

    tcp_options {
      max = "22"
      min = "22"
    }
  }  
}

resource "oci_core_security_list" "financial_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn-net-aut.id
  display_name   = "financialSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "172.103.149.203/32"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.2.0/24"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
}

resource "oci_core_instance" "webserver1" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserver1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.financial_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "webserver1"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

resource "oci_core_instance" "webserver2" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserver2"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.financial_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "webserver2"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}


resource "oci_load_balancer" "lb1" { 
  shape = "100Mbps" 
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.financial_subnet.id,
  ]
  is_private = false 
  display_name = "lb1" 
}

resource "oci_load_balancer_backend_set" "lb-bes1" { 
  name = "lb-bes1" 
  load_balancer_id = oci_load_balancer.lb1.id
  policy = "WEIGHTED_ROUND_ROBIN"
    health_checker { 
      port = "80" 
      protocol = "HTTP" 
      response_body_regex = ".*" 
      url_path = "/" 
    } 
}  

resource "oci_load_balancer_listener" "lb-listener1" { 
  load_balancer_id = oci_load_balancer.lb1.id
  name = "http" 
  default_backend_set_name = oci_load_balancer_backend_set.lb-bes1.name 
  #hostname_names = ["${oci_load_balancer_hostname.test_hostname1.name}", "${oci_load_balancer_hostname.test_hostname2.name}"] 
  port = 80 
  protocol = "HTTP" 
  #rule_set_names = ["${oci_load_balancer_rule_set.test_rule_set.name}"]
  
  connection_configuration { 
    idle_timeout_in_seconds = "10" 
  } 
}

resource "oci_load_balancer_backend" "lb-be1" {
  load_balancer_id = oci_load_balancer.lb1.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes1.name
  ip_address       = oci_core_instance.webserver1.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}


resource "oci_load_balancer_backend" "lb-be2" {
  load_balancer_id = oci_load_balancer.lb1.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes1.name
  ip_address       = oci_core_instance.webserver2.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}


/*teste*/