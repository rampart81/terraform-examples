아래 글의 원본 내용은 [이곳](https://rampart81.github.io/post/vpc_confing_terraform/) 에서 볼수 있습니다.

VPC(Virtual Private Cloud) 는 논리적으로 독립된 가상의 네트워크 이다. 즉 클라우드 상에서 논리적으로 분리된 네트워크 이다. 데이터센터 에서 직접 서버를 운영하면 네크워크 분리를  하기위해 네트워크 장비를 사용하여 실제 물리적으로 네트워크들을 용도에 맞게 구분하고 분리하게 되는데, 이를 클라우드 상에서 가상으로 구현 가능하게 한게 VPC이다. VPC를 이용하여 네트워크 아키텍쳐를 구현하기 위해선 아래의 개념들을 이해해야 한다.

* **서브넷(subnet)**: 기본 서브넷 마스크를 사용하여 클래스로 묶여진 네트워크를 그보다 작은 네트워크로 나눈것. 즉 VPC의 경우 VPC를 더 상세하게 나눈 것. 오늘 포스트에서는 퍼블릭과 프라이빗 서브넷으로 나눌것이다. 퍼블릭 서브넷은 인터넷에 노출되어 있는 서브넷이고 프라이빗 서브넷은 외부접속이 기본적으로 차단되어 있는 서브넷이다.
* **NAT (Network Address Translator)**: 프라이빗 서브넷의 인스탄스들이 팩케지 업데이트 등등을 위한 인터넷 접속이 필요할때가 있는데 퍼블릭 서브넷을 통해 우회해서 인터넷 접속을 가능하게 해주는 기능을 제공한다.
* **Internet Gateway**: VPC를 인터넷에 접속시켜주는 게이트웨이. 퍼블릭 서브넷이 필요로 한다.
* **Route Table**: 서브넷을 위한 라우팅 테이블이다. 서브넷의 네트워크 트래픽을 설정하는데 쓰인다. 라우팅 테이블을 통해 서브넷을 internet gateway와 연결시킬수도 있고 nat과 연결시킬수도 있다. 모든 route table은 기본적으로 local 네트워크 설정이 되어있다 (만일 안되어 있으면 같은 서브넷 상의 인스탄스 끼리도 연결이 되지 않을테니).
* **VPC Peering Connection**: 다른 두 VPC끼리 연결시켜주는 기능이다. 같은 AWS 계졍내의 VPC끼리를 연결할수도 있고 다른 계졍들의 VPC를 연결시킬수도 있다. 하지만 서로 다른 리젼에 있는 VPC들은 연결 시킬수 없다. 

더 자세한 내용은 AWS 사이트에서 볼 수 있다. VPC와 위의 기본적인 네트워크 기능들을 사용하여 아래와 같은 네트워크를 terraform을 사용하여 구현해보자.

## Network Architecture

![arch](https://rampart81.github.io/img/vpc_peering.png)

아주 기본적인 two-tier 네트워크 이다. DMZ와 Application 전용 네트워크로 나누었다. DMZ 구간은 외부 인터넷으로부터 접속이 가능한 네트워크 구간으로 외부에서 접속이 필요한 서버들이 위치해 있다. 주로 load balancer나 웹페이지를 전송하는 프론트앤드 서버 (예를들어, ractjs 기반의 nodejs 서버) 들이 주로 위치하게 된다. Application 네트워크 구간은 외부 인터넷 접속이 차단되어 있으며 오직 내부 네트워크 그리고 DMZ 구간의 지정된 서버들만이 접속이 허용된다. 주로 백앤드 application 서버들이 위치하게 되며 database 서버도 위치할수 있다. 

이렇게 DMZ와 Application 구간을 나누는 이유는 보안 때문이다. 외부에서 접속할수 있는 서버들을 따로 네트워크 구간을 분리 함으로서 혹시나 해킹 공격을 당하더라도 그 피해를 최소화 하도록 하는 것이다. 그리고 VPC peering을 통하여서 분리된 VPC간의 데이터 전송을 허용하게 된다. 

## 필요한 terraform resource들

위의 네트워크 아키텍쳐를 terraform을 사용해서 구현하기 위해서는 아래의 terraform resource들이 필요하다. 

* [aws_vpc](https://www.terraform.io/docs/providers/aws/r/vpc.html)
* [aws_subnet](https://www.terraform.io/docs/providers/aws/r/subnet.html)
* [aws_eip](https://www.terraform.io/docs/providers/aws/r/eip.html)
* [aws_internet_gateway](https://www.terraform.io/docs/providers/aws/r/internet_gateway.html)
* [aws_default_route_table](https://www.terraform.io/docs/providers/aws/r/default_route_table.html)
* [aws_route](https://www.terraform.io/docs/providers/aws/r/route.html)
* [aws_route_table_association](https://www.terraform.io/docs/providers/aws/r/route_table_association.html)
* [aws_nat_gateway](https://www.terraform.io/docs/providers/aws/r/nat_gateway.html)
* [aws_vpc_peering_connection](https://www.terraform.io/docs/providers/aws/r/vpc_peering.html)

## Steps

1 - 먼저 VPC를 생성한다. 

```terraform
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
```

* cidr_block을 선택할때는 구현할 네트워크 아키텍쳐에 맞추어서 범위를 미리 계산해서 설정해야 한다. 기본적으로 VPC의 cidr block은 private이기 때문에 서로 다른 vpc가 동일한 cidr block을 가질수 있지만 그렇게 되면 vpc peering connection을 설정할수 없게 된다. 그러므로 서로 연걸될 vpc 끼리는 다른 cidr block 범위를 설정해줘야 한다.

2 - 그 후 각 VPC에 subnet들을 생성한다. DMZ VPC에는 public 서브넷만 구현하고 Application  VPC에는 public 서브넷과 private 서브넷을 구현한다.

   ```terraform
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
   ```

* 서브넷들은 각 availaility zone마다 생성한다. 서울 리젼의 경우 availability zone이 2개 이므로 각 서브넷이 2개를 생성하게 된다.

3 - 각 VPC마다 Router table들을 생성한다. public 서브넷을 위한 router table 과 private 서브넷을 위한 router table을 따로 생성한다.

   ```terraform
   resource "aws_default_route_table" "dmz_main" {
     default_route_table_id = "${aws_vpc.dmz.default_route_table_id}"

     tags { Name = "DMZ Public Route Table" }
   }

   resource "aws_default_route_table" "application_main" {
     default_route_table_id = "${aws_vpc.application.default_route_table_id}"

     tags { Name = "Application Public Route Table" }
   }
   
   resource "aws_route_table" "application_private" {
     vpc_id = "${aws_vpc.application.id}"

     tags { Name = "Application Route Private Table" }
   }
   ```

* 각 VPC에는 자동으로 생성된 default main route table이 있다. Public 서브넷은 default table을 사용하여 관리하고 private 서브넷용 route table을 새로 생성해준다.

4 - 서브넷들을 router table에 지정해준다

   ```terraform
   # DMZ route table association
   resource "aws_route_table_association" "dmz_public_1a" {
   	subnet_id      = "${aws_subnet.dmz_public_1a.id}"
   	route_table_id = "${aws_vpc.dmz.default_route_table_id}"
   }

   resource "aws_route_table_association" "dmz_public_1c" {
   	subnet_id      = "${aws_subnet.dmz_public_1c.id}"
   	route_table_id = "${aws_vpc.application.default_route_table_id}"
   }

   # Application route table association
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
   ```

5 - Internet Gateway를 생성한다.

   ```terraform
   resource "aws_internet_gateway" "dmz" {
     vpc_id = "${aws_vpc.dmz.id}"

     tags { Name = "DMZ Internet Gateway" }
   }

   resource "aws_internet_gateway" "application" {
     vpc_id = "${aws_vpc.application.id}"

     tags { Name = "Application Internet Gateway" }
   }
   ```

6 - Public 서브넷을 위한 router table에 internet gateway를 지정해준다

   ```terraform
   resource "aws_route" "dmz_public" {
   	route_table_id         = "${aws_vpc.dmz.default_route_table_id}"
   	destination_cidr_block = "0.0.0.0/0"
   	gateway_id             = "${aws_internet_gateway.dmz.id}"
   }

   resource "aws_route" "applicaton_public" {
   	route_table_id         = "${aws_vpc.applicaton.default_route_table_id}"
   	destination_cidr_block = "0.0.0.0/0"
   	gateway_id             = "${aws_internet_gateway.applicaton.id}"
   }
   ```

* Internet Gateway는 퍼플릭 서브넷이 지정된 route table에 지정되어야 한다.
* `destination_cidr_block = "0.0.0.0/0` 은 모든 ip 주소를 뜻한다. 즉 pubic internet 전체에 오픈이 된다.

7 - Public 서브넷에 NAT를 생성한다.

   ```terraform
   resource "aws_eip" "application_nat" {
     vpc = true
   }

   resource "aws_nat_gateway" "application" {
     allocation_id = "${aws_eip.application_nat.id}"
     subnet_id     = "${aws_subnet.application_public_1a.id}"
   }
   ```
* NAT를 생성하기 위해선 EIP(Elastic IP Address)가 필요하다.
* NAT는 private 서브넷을 위한것이므로 private 서브넷이 없는 DMZ는 설정해주지 않는다.
* NAT는 private 서브넷을 위한것이지만 NAT 자체는 public 서브넷에 설정해주어야 한다.

8 - Private 서브넷이 지정된 router table에 NAT를 지정해준다.

   ```terraform
   resource "aws_route" "application_private" {
   	route_table_id         = "${aws_route_table.application_private.id}"
   	destination_cidr_block = "0.0.0.0/0"
   	nat_gateway_id         = "${aws_nat_gateway.application.id}"
   }
   ```
* NAT를 private 서브넷이 지정되어 있는 route table에 지정해줌으로서 private 서브넷이 NAT을 통해 우회적으로 인터넷 접속이 가능하다 (외부 에서 접속은 막아준다).

9 - DMZ와 Application 사이에 VPC Peering Connection을 생성한다.

   ```terraform
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
   ```
* `peer_owner_id`는 vpc peering connection의 주체가 되는 vpc의 계정 아이디 인데, `aws_caller_identity` data 를 지정해줌으로 자동으로 AWS에서 받아올수 있다.
   * `auto_accept`는 true로 설정해서 vpc peering connection을 자동으로 accept하도록 한다 (vpc들이 같은 AWS 계정에 속해있을때만 가능).

10 - VPC Peering Connection을 각 VPC의 route table들에 지정해준다.

   ```terraform
   resource "aws_route" "peering_to_application" {
     # ID of VPC 2 main route table.
     route_table_id = "${aws_vpc.dmz.default_route_table_id}"

     # CIDR block / IP range for VPC 2.
     destination_cidr_block = "${aws_vpc.application.cidr_block}"

     # ID of VPC peering connection.
     vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz_to_application.id}"
   }

   resource "aws_route" "peering_from_dmz" {
     # ID of VPC 1 main route table.
     route_table_id = "${aws_route_table.application_private.id}"

     # CIDR block / IP range for VPC 2.
     destination_cidr_block = "${aws_vpc.dmz.cidr_block}"

     # ID of VPC peering connection.
     vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz_to_application.id}"
   }
   ```
* VPC Peering Connection을 설정해준후 연결된 각 VPC들의 route table에서 route까지 추가해주어야 한다.

전체 코드는 [이곳](https://github.com/rampart81/terraform-examples/tree/master/aws_vpc) 에서 볼수 있다. VPC를 사용하여 네트워크 아키텍쳐를 구현하는건 길고 manual적인 프로세스 이며 그래서 실수 하기도 쉬운 작업이다. 그렇게 terraform이 더욱 유용한 분야 이기도 하다. Terraform을 사용하면 테스트 해보기도 쉽고 업데이트 및 관리 하기도 훨씬 용이하다.

