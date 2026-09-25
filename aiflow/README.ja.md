# AI Flow — ワークスペースガイド（バックエンド・管理画面・モバイル）

bump-backend / bump-admin / bump-mobile-app の3プロジェクトを横断して動く AI ハーネスワークフローです。
無償トライアルの6ステップの流れはそのまま維持し、ご提案内容（横断ナレッジグラフ、難易度判断による省略版/完全版、処理ログ、リポジトリ横断チケットへの対応）を追加しました。

## 覚えるコマンドは1つだけ

```text
/aiflow PDT-2350          PDT-2350 の次のステップを実行（新規チケットもこれで開始）
/aiflow                   全チケットの進捗一覧
```

必要に応じて: `/aiflow PDT-2350 status`（進捗と処理ログ） · `/aiflow PDT-2350 redo spec`（やり直し） ·
`/aiflow PDT-2350 feature`（新規・保守開発として開始） · `/aiflow analyze`（ナレッジグラフ更新） · `/aiflow <PRのURL>`（既存PRのレビュー）

各ステップは完了すると必ず停止します。成果物を確認し、もう一度 `/aiflow PDT-2350` を実行すると次へ進みます。

## ステップ

| # | ステップ | 実行スキル | 成果物（`docs/aiflow/<ID>/`） | 人の作業 | 省略版 | 完全版 |
|---|---|---|---|---|---|---|
| 1 | チケット正規化（影響リポジトリ判定・難易度判断・ブランチ作成） | `/aiflow-spec`（§ステージ1） | `ticket.md`, `status.md` | 承認 | ✅ | ✅ |
| 2 | 仕様作成（根本原因 / 設計） | `/aiflow-spec`（省略版: §1.4 / 完全版: §ステージ2） | `spec.md` | 承認 | ✅ | ✅ |
| 3 | 修正プラン（タスクはリポジトリ単位） | `/aiflow-plan` | `plan.md` | 承認 | — | ✅ |
| 4 | 修正実装（TDD＋タスク毎に2段階レビュー） | `/aiflow-impl` | コード, `reviews/task*.md` | — | ✅ | ✅ |
| 5 | レビュー・テストケース作成（リポジトリ横断の最終レビュー） | `/aiflow-review`（ステージ5部分） | `reviews/final-review.md`, `test-cases.md` | — | — | ✅ |
| 6 | 納品（テスト実行・手動確認・リポジトリ毎にPR作成） | `/aiflow-review`（ステージ6部分） | `status.md` にPRのURL | 動作確認・承認 | ✅ | ✅ |

※ **省略版ではステージ1と2は1回の実行でまとめて完了します。** 小さな不具合の
場合、`/aiflow-spec` がトリアージ直後にその場で調査し `spec.md` まで書いて、
1回の承認で両方のステージを閉じます — 別途の対話ステップは挟みません。これは
「トリアージと修正案の作成を1ステップで行う」ファストトラックであり、完全版
（およびすべての新規開発チケット）が受ける、質問しながら2〜3案を比較する本来
の対話プロセスとは別物です。調査の途中で省略版の条件を満たさないと分かった
場合は、その場で完全版に切り替わり、通常どおりステージ2の対話を後で実行します。

※ ステージ5と6は同じ `aiflow-review` スキルファイルの中の別々の手順です。省略版ではステージ5の手順だけをスキップし、ステージ6は常に実行します（自分でどちらを実行するか選ぶ必要はありません — `/aiflow` が `status.md` を見て自動で判断します）。

処理ログ `log.json`（ステップ毎の所要時間・トークン・概算料金）は自動で記録されます。

**難易度判断（トリアージ）:** ステップ1の最後に `aiflow/workflow.yaml` の `triage.light_requires_all` で判定します。
条件は「1リポジトリのみ・変更ファイル3以下・API/スキーマ/DB/契約の変更なし・原因箇所特定済み・不具合対応・センシティブ領域外」です。
すべて満たせば **省略版**（1→2→4→6、軽量モデル）、それ以外は **完全版** になります。ルートは作業者が確定します。
ステップ2で複雑さが判明した場合は自動で完全版に切り替わります（完全版から省略版へは確認なしには戻しません）。

**不具合対応と新規開発:** 違うのは入口だけです。新規・保守開発では `feature/<ID>/<slug>` ブランチを作成し、仕様は「背景と目的」から書きます。ステップ2〜6は共通です。

## リポジトリ横断チケット

- ステップ1で、ナレッジグラフと `workflow.yaml` の契約（backend swagger → admin、backend GraphQL → アプリ）を根拠に影響リポジトリを判定します。PDT-1107（admin＋backend）や PDT-1136（backend＋アプリ側ヘッダー）のように、片側だけでは解決しないケースを想定しています。
- 対象の全リポジトリに同じ名前のブランチを作成します。
- `plan.md` のタスクは1タスク＝1リポジトリです。契約の提供側（backend）を先に実装し、クライアントの再生成もタスクとして明記します。
- ステップ5では変更全体をリポジトリ横断でレビューします（契約の整合性・後方互換性・呼び出し元への影響）。
- ステップ6ではリポジトリ毎に、それぞれのベースブランチ（backend/admin は `develop`、mobile は `main`）へPRを作成し、PR同士を相互リンクします。チケットの md ファイルも各PRに含めるため、受け入れ確認は引き続き「mdファイル確認方式」で行えます。

## ナレッジグラフ

`/aiflow analyze` で `aiflow/scripts/kg_build.py` が次を行います。

1. 各リポジトリの graphify グラフを更新（AST解析のみ、LLM費用なし）
2. `graphify-out/graph.json` に統合（各ノードにリポジトリ名を付与）
3. 複数リポジトリに存在する型名をリポジトリ間で接続

`/aiflow analyze docs` を実行すると設計書も取り込みます（トークンを消費するため、実行前に確認します）。どのステップもソースを読む前にグラフを検索します。

## セットアップ（端末ごとに1回）

```bash
git clone <このワークスペースのリポジトリ> ai-flow-demo && cd ai-flow-demo
git clone https://github.com/emole-inc/bump-backend.git
git clone https://github.com/emole-inc/bump-admin.git
git clone https://github.com/emole-inc/bump-mobile-app.git
gh auth login            # PR作成に使用
claude                   # 起動後: /aiflow analyze
```

必要なもの: `python3`、`graphify`、`gh`、各リポジトリの開発環境（Go / Node・yarn / FVM・Flutter）。
Notion チケットは Notion MCP、ブラウザ、貼り付けのいずれかで読み込みます。

## ファイル構成

| パス | 内容 |
|---|---|
| `aiflow/workflow.yaml` | リポジトリ・ベースブランチ・テストコマンド・契約・難易度判断ルール・モデル。変更はここで行う |
| `aiflow/pricing.json` | `log.json` の概算料金に使う単価 |
| `aiflow/scripts/` | `aiflow_status.py`（進捗・次ステップ判定） · `aiflow_log.py`（処理ログ） · `kg_build.py`（ナレッジグラフ） |
| `.claude/skills/aiflow*/` | 各ステップのスキルとテンプレート |
| `.claude/skills/aiflow/conventions.md` | 全ステップ共通のルール（ステップ毎の停止・承認・git・言語） |
| `.claude/skills/`（`aiflow-` が付かないもの） | 各ステージが内部的に読み込む汎用スキル（下記） |
| `docs/aiflow/<ID>/` | チケット毎のフォルダ。再開時は `status.md` から読む |
| `aiflow/selected-bugs/` | Notion のチケット一覧（チケットID → Notion URL） |

**`aiflow-` が付いていないスキルについて。** `.claude/skills/` には
`test-driven-development` `systematic-debugging` `verification-before-completion`
`receiving-code-review` `requesting-code-review` `dispatching-parallel-agents`
`graphify` の7つもあります。`aiflow-` プレフィックスが**あえて**付いていません
— これらは AI Flow 専用ではなく、各ステージが状況に応じて内部的に読み込む汎用の
開発規律スキルだからです。`/` メニューには出ません
（`user-invocable: false`）。理由は2つ:

1. `/aiflow-*` と名前が衝突しないようにするため。
2. 各スキルの `description` が `Use when...` で始まる標準的なトリガー形式に
   なっており、コマンドとして呼ぶのではなく、状況に合わせてAIが自動的に
   読み込む仕組みだからです（例: バグに直面したら `systematic-debugging`、
   実装前に `test-driven-development`）。

自分で直接使うことはありません — `docs/aiflow/aiflow*/` の各ステージが
必要なときに呼び出します。

## 他の人の作業を引き継ぐとき

`/aiflow PDT-XXXX` を実行するだけで、`status.md` を読んで続きから再開します。チャット履歴は不要です。
自分で確認する場合は `status.md` → `ticket.md` → `spec.md` → `plan.md` → `reviews/` → 各リポジトリのブランチの順に読んでください。

## トライアル版からの変更点

| トライアル版（リポジトリ毎） | 現行版（ワークスペース） |
|---|---|
| リポジトリ毎にフロー・グラフが別々 | 3リポジトリ共通のフロー＋リポジトリ間を接続した統合グラフ |
| `/` メニューに約17スキル、ステップ毎にコマンドを覚える必要あり | `/aiflow` の1つだけ（ステップ用コマンドは内部で呼び出すため覚える必要なし） |
| 常に全6ステップ | 難易度判断で省略版 / 完全版を選択し、モデルもルート毎に切り替え |
| PRのベースが `main` 固定（admin/backend では誤り） | `workflow.yaml` でリポジトリ毎に設定 |
| 利用量の記録なし | チケット毎の `log.json`（時間・トークン・概算料金） |
| 不具合対応のみ | 不具合対応と新規開発の両方に対応（ステップ2〜6は共通） |

**フローはワークスペースに1つだけです。** リポジトリ側にはコピーを置きません。

- トライアル版のリポジトリ毎のフローは3リポジトリすべてから削除しました。
- 各リポジトリはベースブランチ（`develop` / `main`）に戻してあり、bump-mobile-app にトライアルで入れた graphify の git フックもアンインストールしました。
- トライアル期間のチケット（PDT-1107・PDT-1136・PDT-1419）は `docs/aiflow/` に移し、`legacy: true` を付けています。進捗一覧と重複チェックの対象にもなります。
- Notion のチケット一覧は `aiflow/selected-bugs/` に移しました。

リポジトリに残っているのは各チームの資産です（例: bump-mobile-app の `CLAUDE.md`、`docs/ai/`、`.claude/skills/bump-*`）。フローはこれらを読み込み（`workflow.yaml` の `guides:` / `repo_skills:`）、コードやテストを書くときにそのルールに従います。
