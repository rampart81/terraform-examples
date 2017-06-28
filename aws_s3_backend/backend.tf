## AWS의 S3에서 "remote-state-file-example" bucket에 
## "example/terraform.state" 키로 테러폼 스테이트 파일을 저장한다.
terraform {
  backend "s3" {
    bucket = "remote-state-file-example"
    key    = "example/terraform.state"
    region = "ap-northeast-2"
  }
}
