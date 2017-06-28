**아래 원본 내용은 [이곳]()에서 볼수 있습니다.**

Terraform을 실행하여 인프라를 생성시킬때마다 terraform은 _Terraform state file_ 이라는 파일(`terraform.tfstate`)에 실행한 작업들에 관한 정보를 저장한다. 예를 들어, `terraform apply` 커맨드를 사용하여 새로운 서버를 생성했다면 그에 관한 정보가 `terraform.tfstate` 파일에 저장이 된다. 이 파일은 JSON 포멧으로 되어 있는데, 유저가 설정해논 테라폼 설정들과 실제 클라우드 상에서의 상태간의 mapping을 기록해놓은 파일이다. 테라폼을 실행시킬때 마다 테라폼은 AWS 에서 (혹은 연결되어 있는 다른 provider에서) 최신 상태를 조회하여 state file을 업데이트 한다. 그리하여 새로 변경된 점들이 있는지 확인하여 실행시키는 것이다. 어차피 AWS (혹은 다른 provider)에서 최신 상태를 매번 업데이트 받을거면 굳이 state 파일을 사용해야 하는지 의문이 들것이다. 테라폼도 이 점에 관해서 많은 질문을 받았는지, 왜 state 파일 없이는 여러 문제가 생기는지  [이곳](https://www.terraform.io/docs/state/purpose.html) 에서 설명하고 있다.

테라폼 state file은 특별한 설정이 없으면 로컬 파일시스템에 생성된다. 만일 한명이 모든 테라폼 설정들을 관리한다면 특별한 문제가 없을수도 있지만 팀 단위로 관리를 한다면 state 파일을 팀이 공유해야 하기 때문에 로컬 파일시스템에 state 파일을 생성하는것은 적합하지 않다. 다행히 테라폼은 backend 라는 설정을 통하여 state 파일을 remote location에 저장할수 있도록 해준다. 예를 들어, state 파일을 AWS S3에 저장하여 팀에서 공유 하는것이 가능하진다.

## Terraform state file을 S3에 저장하기

1. backend.tf 파일을 생성한후 아래 코드를 삽입한다.

  ```terraform
  terraform {
    backend "s3" {
      bucket = "remote-state-file-example"
      key    = "example/terraform.state"
      region = "ap-northeast-2"
    }
  }
  ```

  위에 코드는 테라폼에게 테라폼 state 파일을 서울 리전의 S3의 `remote-state-file-example` 버켓에 `example/terraform.state` 라는 키로 저장하라는 설정이다. 

2. terraform init 커맨드를 사용하여 위의 backend 설정을 실행시킨다. 

   ```bash
   terraform init -backend-config="access_key=XXXXXXXXXXXXXXXXXXXX" -backend-config="secret_key=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
   ```

   위의 커맨드를 테라폼 설정 파일이 있는 디렉토리에서 실행시키면 이제부터는 테라폼이 state 파일을 위에 지정된 S3에서 저장하고 또 읽어 들인다. 한가지 주의 할점은 `terraform init` 커맨드는 로컬 설정이기 때문에 팀원 모두가 실행시켜줘야 한다. 또한 테라폼 설정 코드가 여러 디렉토리에 나뉘어져 있다면 디렉토리 별로 실행 시켜줘야 한다. 또한, AWS access_key 와 secrete_key를 `~/.aws/credentials` 파일에 설정해놓았다면 단순히 `terraform init` 커맨드만 실행시키면 되는데 만일 default 가 아닌 프로파일을 사용한다면 아래와 같은 옵션과 같이 실행 시켜줘야 한다.

   ```bash
   terraform init -backend-config="profile=profile_name"
   ```


Terraform init 커맨드에 대한 더 자세한 정보는 [이곳](https://www.terraform.io/docs/commands/init.html) 에서 볼 수 있다.  
