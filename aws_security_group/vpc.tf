resource "aws_vpc" "dmz" {
	cidr_block           = "10.1.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags { Name = "DMZ" }
}

resource "aws_vpc" "application" {
	cidr_block           = "10.2.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags { Name = "Application" }
}

# DMZ Public Subnets
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

# Application Public Subnets
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

# Application Private Subnets
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
