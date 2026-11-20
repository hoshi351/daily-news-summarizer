terraform {                                    # Terraform 全体の設定ブロックを開始
  required_version = ">= 1.0.0"                # Terraform のバージョンが 1.0.0 以上であることを要求

  required_providers {                         # 利用する外部プロバイダー（プラグイン）を指定するブロック
    aws = {                                    # AWS プロバイダーの定義
      source  = "hashicorp/aws"                # 公式の AWS プロバイダーを取得元に指定
      version = "~> 5.0"                       # AWS プロバイダーのバージョン 5.x 系を使用
    }                                          # aws の設定終わり
    archive = {                                # ファイル圧縮（ZIP化）を行うプロバイダーの定義
      source  = "hashicorp/archive"            # 公式の archive プロバイダーを取得元に指定
      version = "~> 2.0"                       # archive プロバイダーのバージョン 2.x 系を使用
    }                                          # archive の設定終わり
  }                                            # required_providers の設定終わり
}                                              # terraform ブロックの終わり

provider "aws" {                               # AWS プロバイダーの具体的な動作設定
  region = "ap-northeast-1"                    # AWS リソースをデプロイするリージョンを「東京（ap-northeast-1）」に指定
}                                              # provider の設定終わり