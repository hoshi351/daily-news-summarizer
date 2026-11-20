# EventBridge スケジュールルールの作成           # コメント
resource "aws_cloudwatch_event_rule" "daily_trigger" { # タイマー（スケジュールルール）を定義
  name                = "daily_news_trigger"   # ルールの名前を "daily_news_trigger" に設定
  description         = "Triggers Lambda function daily for news summary" # ルールの説明文
  schedule_expression = "cron(0 22 * * ? *)"   # 実行スケジュール（UTC 21:00 ＝ 日本時間 朝6:00 に毎日実行）
}                                              # aws_cloudwatch_event_rule 終わり

# イベントのターゲット（呼び出し先）に Lambda を指定 # コメント
resource "aws_cloudwatch_event_target" "lambda_target" { # スケジュールが発動した際の呼び出し先を指定
  rule      = aws_cloudwatch_event_rule.daily_trigger.name # 紐付ける EventBridge ルール名
  target_id = "SendToLambda"                   # ターゲットの識別名
  arn       = aws_lambda_function.news_summarizer.arn # 呼び出す Lambda 関数の ARN（識別子）
}                                              # aws_cloudwatch_event_target 終わり

# EventBridge から Lambda を呼び出す権限を付与   # コメント
resource "aws_lambda_permission" "allow_eventbridge" { # EventBridge が Lambda を起動することを許可する設定
  statement_id  = "AllowExecutionFromEventBridge" # ステートメントの識別名
  action        = "lambda:InvokeFunction"      # 許可する操作（Lambda 関数の実行）
  function_name = aws_lambda_function.news_summarizer.function_name # 実行を許可する Lambda 関数の名前
  principal     = "events.amazonaws.com"       # 呼び出し元サービス（EventBridge）
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn # 呼び出し元となる EventBridge ルールの ARN
}                                              # aws_lambda_permission 終わり