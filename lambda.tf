# Lambda 実行ロール                            # コメント（Lambda用IAMロールの定義）
resource "aws_iam_role" "lambda_role" {        # Lambda が AWS リソースを操作するための IAM ロールを作成
  name = "daily_news_lambda_role"              # IAM ロールの名前を "daily_news_lambda_role" に設定

  assume_role_policy = jsonencode({            # Lambda サービスがこのロールを引き受けられるように信頼関係を JSON に変換して設定
    Version = "2012-10-17"                     # IAM ポリシーの構文バージョン指定
    Statement = [                              # 権限ステートメントのリストを開始
      {                                        # 1つ目のステートメント
        Action = "sts:AssumeRole"              # ロール引き受け（AssumeRole）のアクションを許可
        Effect = "Allow"                       # 許可（Allow）に設定
        Principal = {                          # 誰に許可を与えるかを指定
          Service = "lambda.amazonaws.com"     # AWS Lambda サービス自身に許可
        }                                      # Principal 終わり
      }                                        # ステートメント 終わり
    ]                                          # Statement 終わり
  })                                           # jsonencode 終わり
}                                              # aws_iam_role 終わり

# IAM ポリシー（SSM, Bedrock, Marketplace, CloudWatch Logs 権限）# コメント（具体的に許可する操作の定義）
resource "aws_iam_role_policy" "lambda_policy" { # IAM ロールにインラインポリシー（権限）をアタッチ
  name = "daily_news_lambda_policy"            # ポリシー名を "daily_news_lambda_policy" に設定
  role = aws_iam_role.lambda_role.id           # 上で定義した IAM ロール（lambda_role）にこのポリシーを紐付け

  policy = jsonencode({                        # 許可する具体的な権限リストを JSON に変換
    Version = "2012-10-17"                     # IAM ポリシーの構文バージョン
    Statement = [                              # 権限ルールのリストを開始
      {                                        # ① SSM パラメータ読み込み権限
        Effect = "Allow"                       # 許可
        Action = [                             # アクション指定
          "ssm:GetParameter"                   # SSM Parameter Store からパラメータを取得する操作を許可
        ]                                      # Action 終わり
        Resource = "arn:aws:ssm:ap-northeast-1:*:parameter/daily_news/line_access_token" # 対象の SSM パラメータのみ許可
      },                                       # ① 終わり
      {                                        # ② Bedrock モデル呼び出し権限
        Effect = "Allow"                       # 許可
        Action = [                             # アクション指定
          "bedrock:InvokeModel"                # Bedrock の AI モデルを呼び出す（実行する）操作を許可
        ]                                      # Action 終わり
        Resource = "*"                         # すべての Bedrock モデル／推論プロファイルを対象とする
      },                                       # ② 終わり
      {                                        # ③ AWS Marketplace 契約チェック権限
        Effect = "Allow"                       # 許可
        Action = [                             # アクション指定
          "aws-marketplace:ViewSubscriptions", # Marketplace のサブスクリプション状況を確認する操作を許可
          "aws-marketplace:Subscribe"          # 必要に応じて Marketplace でモデルを利用登録する操作を許可
        ]                                      # Action 終わり
        Resource = "*"                         # すべての Marketplace リソースを対象とする
      },                                       # ③ 終わり
      {                                        # ④ ログ出力権限
        Effect = "Allow"                       # 許可
        Action = [                             # アクション指定
          "logs:CreateLogGroup",               # CloudWatch Logs にロググループを作成する操作を許可
          "logs:CreateLogStream",              # ログストリームを作成する操作を許可
          "logs:PutLogEvents"                  # ログイベント（ログ本文）を書き込む操作を許可
        ]                                      # Action 終わり
        Resource = "*"                         # すべてのログリソースを対象とする
      }                                        # ④ 終わり
    ]                                          # Statement 終わり
  })                                           # jsonencode 終わり
}                                              # aws_iam_role_policy 終わり

# Python パッケージとソースコードの ZIP 化       # コメント
data "archive_file" "lambda_zip" {             # ソースコード群を ZIP ファイルにまとめるデータソース
  type        = "zip"                          # 圧縮形式を zip に指定
  source_dir  = "${path.module}/src"           # 圧縮対象のディレクトリ（Terraform ファイルと同じ階層にある src フォルダ）
  output_path = "${path.module}/lambda_function.zip" # 作成された ZIP ファイルの出力先パス
}                                              # archive_file 終わり

# Lambda 関数定義                               # コメント
resource "aws_lambda_function" "news_summarizer" { # AWS 上に Lambda 関数を作成
  filename         = data.archive_file.lambda_zip.output_path # アップロードする ZIP ファイルのパス
  function_name    = "DailyNewsSummarizer"     # AWS 上に作成される Lambda 関数の名前
  role             = aws_iam_role.lambda_role.arn # 関数に割り当てる IAM ロールの ARN（識別子）
  handler          = "lambda_function.lambda_handler" # 実行時に最初に呼び出される関数（lambda_function.py 内の lambda_handler 関数）
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # ZIP のハッシュ値（コードが更新された時に自動で再デプロイするため）
  runtime          = "python3.11"              # 実行環境として Python 3.11 を指定
  timeout          = 30                        # タイムアウト時間を 30 秒に設定（Bedrock の応答を待つため少し長めに設定）
}                                              # aws_lambda_function 終わり