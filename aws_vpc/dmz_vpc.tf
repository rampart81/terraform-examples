resource "aws_vpc" "dmz" {
	cidr_block           = "10.1.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags { Name = "DMZ" }
}

resource "aws_subnet" "dmz_public_1a" {
	vpc_id            = "${aws_vpc.dmz.id}"
	cidr_block        = "10.1.1.0/24"
	availability_zone = "ap-northeast-1a"

	tags { Name = "Frontend Public Subnet 1A" }
}

resource "aws_subnet" "dmz_public_1c" {
	vpc_id            = "${aws_vpc.dmz.id}"
	cidr_block        = "10.1.2.0/24"
	availability_zone = "ap-northeast-1c"

	tags { Name = "Frontend Public Subnet 1C" }
}

resource "aws_default_route_table" "dmz_main" {
	default_route_table_id = "${aws_vpc.dmz.default_route_table_id}"

	tags { Name = "DMZ Public Route Table" }
}

resource "aws_default_route_table" "application_main" {
	default_route_table_id = "${aws_vpc.application.default_route_table_id}"

	tags { Name = "Application Public Route Table" }
}

resource "aws_route_table_association" "dmz_public_1a" {
	subnet_id      = "${aws_subnet.dmz_public_1a.id}"
	route_table_id = "${aws_vpc.dmz.default_route_table_id}"
}

resource "aws_route_table_association" "dmz_public_1c" {
	subnet_id      = "${aws_subnet.dmz_public_1c.id}"
	route_table_id = "${aws_vpc.application.default_route_table_id}"
}

resource "aws_internet_gateway" "dmz" {
	vpc_id = "${aws_vpc.dmz.id}"

	tags { Name = "DMZ Internet Gateway" }
}

resource "aws_route" "dmz_public" {
	route_table_id         = "${aws_vpc.dmz.default_route_table_id}"
	destination_cidr_block = "0.0.0.0/0"
	gateway_id             = "${aws_internet_gateway.dmz.id}"
}

resource "aws_route" "peering_to_application" {
	# ID of VPC 2 main route table.
	route_table_id = "${aws_vpc.dmz.default_route_table_id}"

	# CIDR block / IP range for VPC 2.
	destination_cidr_block = "${aws_vpc.application.cidr_block}"

	# ID of VPC peering connection.
	vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz_to_application.id}"
}
