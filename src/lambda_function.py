import json                                    # JSON データの相互変換を行う標準ライブラリ
import urllib.request                          # HTTP リクエスト（Webアクセス）を行うための標準ライブラリ
import xml.etree.ElementTree as ET             # XML データ（RSS フィード）をパース（解析）するためのライブラリ
import boto3                                   # AWS サービス（Bedrock や SSM）を操作するための AWS SDK ライブラリ

# クライアントの初期化                            # コメント
bedrock = boto3.client(service_name="bedrock-runtime", region_name="ap-northeast-1") # Bedrock 呼び出し用クライアントを東京リージョンで初期化
ssm = boto3.client(service_name="ssm", region_name="ap-northeast-1")                # SSM Parameter Store 操作用クライアントを初期化

def get_line_token():                          # SSM から LINE アクセストークンを取得する関数を定義
    response = ssm.get_parameter(Name="/daily_news/line_access_token", WithDecryption=True) # SSM から暗号化されたパラメータを取得
    return response["Parameter"]["Value"]     # パラメータの文字列（トークン本体）だけを返す

def fetch_google_news():                       # Google News RSS からニュースを取得する関数
    url = "https://news.google.com/rss?hl=ja&gl=JP&ceid=JP:ja" # 日本の Google News トップの RSS フィード URL
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}) # アクセス拒否を防ぐためブラウザの User-Agent を模倣
    xml_data = urllib.request.urlopen(req).read() # URL にアクセスして XML データをバイト列として読み込む
    root = ET.fromstring(xml_data)             # XML バイト列を解析して ElementTree オブジェクトに変換
    
    news_items = []                            # 取得したニュース項目を格納する空リストを作成
    for item in root.findall(".//item")[:5]:   # XML 内の <item> タグ（ニュース1件）を検索し、上から5件だけループ処理
        title = item.find("title").text        # ニュースのタイトルテキストを取得
        link = item.find("link").text          # ニュースの URL リンクを取得
        news_items.append(f"・{title}\n  {link}") # タイトルと URL を整形してリストに追加
    
    return "\n\n".join(news_items)            # リスト内のニュースを改行2つ挟んで1つのテキストに結合して返す

def summarize_with_bedrock(news_text):         # Bedrock (Claude) を使ってニュースを要約する関数
    prompt = f"以下のニュース一覧から重要な記事を3つ選び、分かりやすく日本語で要約してください。\n\nニュース:\n{news_text}" # AI に与える指示文（プロンプト）を作成
    
    body = json.dumps({                        # Bedrock の API リクエスト用パラメータを JSON 文字列に変換
        "anthropic_version": "bedrock-2023-05-31", # Anthropic API のメッセージフォーマット規格を指定
        "max_tokens": 1000,                   # AI が生成する最大トークン数（文字数の目安）
        "messages": [                          # 対話形式のメッセージリスト
            {"role": "user", "content": prompt} # ユーザーからの入力として指示文を渡す
        ]
    })
    
    # 推論プロファイル ID を使用して Bedrock を呼び出す # コメント
    response = bedrock.invoke_model(           # Bedrock のモデル呼び出しを実行
        modelId="jp.anthropic.claude-haiku-4-5-20251001-v1:0", # 日本リージョン用の Claude Haiku 4.5 推論プロファイル ID
        contentType="application/json",        # 送信するデータの形式（JSON）
        accept="application/json",             # 受け取るデータの形式（JSON）
        body=body                              # 送信するパラメータ本体
    )
    
    response_body = json.loads(response.get("body").read()) # レスポンスのバイナリデータを読み込んで JSON オブジェクトに変換
    return response_body["content"][0]["text"] # Claude が生成した要約テキスト部分を抽出して返す

def send_line_message(token, message_text):    # LINE Messaging API 経由でメッセージを送信する関数
    url = "https://api.line.me/v2/bot/message/broadcast" # 全登録ユーザーにプッシュ送信する LINE API エンドポイント
    headers = {                                # リクエストヘッダーの設定
        "Content-Type": "application/json",    # 送信形式を JSON に指定
        "Authorization": f"Bearer {token}"     # 認証情報として取得した LINE アクセストークンをセット
    }
    data = {                                   # LINE に送るメッセージデータ
        "messages": [                          # メッセージオブジェクトのリスト
            {"type": "text", "text": message_text} # テキスト形式のメッセージとして要約文を指定
        ]
    }
    
    req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers=headers, method="POST") # HTTP POST リクエストを作成
    with urllib.request.urlopen(req) as res:   # リクエストを送信
        pass                                   # エラーが出なければ処理成功としてスキップ

def lambda_handler(event, context):            # AWS Lambda 実行時に自動的に呼ばれるエントリーポイント関数
    try:                                       # エラーハンドリングのための try ブロックを開始
        line_token = get_line_token()          # ① LINE アクセストークンを SSM から取得
        news = fetch_google_news()             # ② Google News からニュース5件を取得
        summary = summarize_with_bedrock(news) # ③ ニュースを Claude で要約
        
        full_message = f"📰 本日の主要ニュースTOP3\n\n{summary}" # LINE 送信用にタイトルを冠したメッセージを作成
        send_line_message(line_token, full_message) # ④ LINE に要約メッセージを送信
        
        return {                               # Lambda の正常終了レスポンスを返す
            "statusCode": 200,                # ステータスコード 200（成功）
            "body": json.dumps("News summary sent successfully!") # 成功メッセージ
        }
    except Exception as e:                     # 処理中にエラーが発生した場合の捕獲
        print(f"Error: {str(e)}")              # CloudWatch Logs にエラー内容を出力
        raise e                                # エラーを再度投げ直して Lambda を失敗状態として記録