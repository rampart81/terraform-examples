resource "aws_vpc" "application" {
	cidr_block           = "10.2.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags { Name = "Application" }
}

resource "aws_subnet" "application_public_1a" {
	vpc_id            = "${aws_vpc.application.id}"
	cidr_block        = "10.2.1.0/24"
	availability_zone = "ap-northeast-1a"

	tags { Name = "Arontend Public Subnet 1A" }
}

resource "aws_subnet" "application_public_1c" {
	vpc_id            = "${aws_vpc.application.id}"
	cidr_block        = "10.2.2.0/24"
	availability_zone = "ap-northeast-1c"

	tags { Name = "Application Public Subnet 1C" }
}

resource "aws_subnet" "application_private_1a" {
	vpc_id            = "${aws_vpc.application.id}"
	cidr_block        = "10.2.3.0/24"
	availability_zone = "ap-northeast-1a"

	tags { Name = "Arontend Private Subnet 1A" }
}

resource "aws_subnet" "application_private_1c" {
	vpc_id            = "${aws_vpc.application.id}"
	cidr_block        = "10.2.4.0/24"
	availability_zone = "ap-northeast-1c"

	tags { Name = "Application Private Subnet 1C" }
}

resource "aws_default_route_table" "application_main" {
	default_route_table_id = "${aws_vpc.application.default_route_table_id}"

	tags { Name = "Application Public Route Table" }
}

resource "aws_route_table" "application_private" {
	vpc_id = "${aws_vpc.application.id}"

	tags { Name = "Application Route Private Table" }
}

resource "aws_route_table_association" "application_public_1a" {
	subnet_id      = "${aws_subnet.application_public_1a.id}"
	route_table_id = "${aws_vpc.application.default_route_table_id}"
}

resource "aws_route_table_association" "application_public_1c" {
	subnet_id      = "${aws_subnet.application_public_1c.id}"
	route_table_id = "${aws_vpc.application.default_route_table_id}"
}

resource "aws_route_table_association" "application_private_1a" {
	subnet_id      = "${aws_subnet.application_private_1a.id}"
	route_table_id = "${aws_route_table.application_private.id}"
}

resource "aws_route_table_association" "application_private_1c" {
	subnet_id      = "${aws_subnet.application_private_1c.id}"
	route_table_id = "${aws_route_table.application_private.id}"
}

resource "aws_internet_gateway" "application" {
	vpc_id = "${aws_vpc.application.id}"

	tags { Name = "Application Internet Gateway" }
}

resource "aws_route" "applicaton_public" {
	route_table_id         = "${aws_vpc.applicaton.default_route_table_id}"
	destination_cidr_block = "0.0.0.0/0"
	gateway_id             = "${aws_internet_gateway.applicaton.id}"
}

resource "aws_eip" "application_nat" {
	vpc = true
}

resource "aws_nat_gateway" "application" {
	allocation_id = "${aws_eip.application_nat.id}"
	subnet_id     = "${aws_subnet.application_public_1a.id}"
}

resource "aws_route" "application_private" {
	route_table_id         = "${aws_route_table.application_private.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id         = "${aws_nat_gateway.application.id}"
}

data "aws_caller_identity" "current" { }

resource "aws_vpc_peering_connection" "dmz_to_application" {
	# Main VPC ID.
	vpc_id = "${aws_vpc.application.id}"

	# AWS Account ID. This can be dynamically queried using the
	# aws_caller_identity data resource.
	# https://www.terraform.io/docs/providers/aws/d/caller_identity.html
	peer_owner_id = "${data.aws_caller_identity.current.account_id}"

	# Secondary VPC ID.
	peer_vpc_id = "${aws_vpc.dmz.id}"

	# Flags that the peering connection should be automatically confirmed. This
	# only works if both VPCs are owned by the same account.
	auto_accept = true
}

resource "aws_route" "peering_from_dmz" {
	# ID of VPC 1 main route table.
	route_table_id = "${aws_route_table.application_private.id}"

	# CIDR block / IP range for VPC 2.
	destination_cidr_block = "${aws_vpc.dmz.cidr_block}"

	# ID of VPC peering connection.
	vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz_to_application.id}"
}
