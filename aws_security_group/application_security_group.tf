resource "aws_security_group" "application" {
  vpc_id      = "${aws_vpc.application.id}"
  name        = "Application Security Group"
  description = "Application Security Group"

  tags { Name = "Application Security Group" }
}

resource "aws_security_group_rule" "application_http_frontend_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.application.id}"
  source_security_group_id = "${aws_security_group.frontend.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "application_http_frontend_egress" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.application.id}"
  source_security_group_id = "${aws_security_group.frontend.id}"

  lifecycle { create_before_destroy = true }
}
