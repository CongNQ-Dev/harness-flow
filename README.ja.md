# Basic AI Flow

[English](README.md) · 日本語 · [Tiếng Việt](README.vi.md)

**backend**、**admin**、**mobile-app** を横断する、AI 駆動の開発
フローです。このリポジトリが持つのはフローだけです。3 つのソースリポジトリは
この中にクローンして git の管理対象外にするため、このリポジトリから変更される
ことはありません。

```
harness-flow/                 ← このリポジトリ：AI Flow（ここで Claude Code を起動）
├── backend/             ← ソースリポジトリ（GitHub、ここでは追跡しない）
├── admin/               ← ソースリポジトリ（GitHub、ここでは追跡しない）
└── mobile-app/          ← ソースリポジトリ（GitHub、ここでは追跡しない）
```

このリポジトリは AI Flow の本体で、単独で完結しています。`install.sh` /
`install.ps1` で、Claude Code、Codex、GitHub Copilot、Cursor、OpenCode、Kilo Code、
OpenClaw のどれを使うプロジェクトにも導入できます。プロジェクト固有の設定はすべて
`aiflow/workflow.yaml` にあります。

## 自分のプロジェクトに導入する

```bash
git clone https://github.com/CongNQ-Dev/harness-flow.git
./harness-flow/install.sh --dir ~/code/my-app        # macOS / Linux
.\harness-flow\install.ps1 -Dir C:\code\my-app        # Windows
```

インストーラーはオンボーディング形式です。4 つの質問に答えると、選んだものだけを設定します。

1. **エージェント** — 1 つでも複数でも可（Codex と Copilot を使うチームなら両方）。
2. **Git ホスト** — GitHub（`gh`）、GitLab（`glab`、gitlab.com またはセルフマネージド）、
   またはリポジトリごとに選ぶ。CLI がインストール・ログイン済みかを確認し、未対応なら
   実行すべきコマンドを表示します。
3. **言語** — チケット文書と PR の言語。English、日本語、Tiếng Việt、または任意のコード。
4. **機能** — ナレッジグラフ（`graphify`）、ビジュアルコンパニオン、プロジェクト wiki。
   選ばなかった機能のスキルはインストールしません。

回答は `aiflow/install.yaml` に保存され、`/aiflow setup` はそれを読んで同じ質問を
繰り返しません。どの質問もフラグで指定でき、スクリプトや CI でも使えます。

```bash
./harness-flow/install.sh --dir ~/code/my-app --agent codex,copilot \
  --git-host gitlab --gitlab-host gitlab.acme.io --language vi --features graph,wiki --yes
```

| `--agent` | スキルの配置先 | `/aiflow` の提供元 | ルールファイル |
|---|---|---|---|
| `claude` | `.claude/skills/` | `aiflow` スキル | `CLAUDE.md` (+ hooks in `.claude/settings.json`) |
| `codex` | `.agents/skills/` | `$aiflow` | `AGENTS.md` |
| `copilot` | `.github/skills/` | `.github/prompts/aiflow.prompt.md` | `AGENTS.md` |
| `cursor` | `.cursor/skills/` | `.cursor/commands/aiflow.md` | `AGENTS.md` |
| `opencode` | `.opencode/skills/` | `.opencode/commands/aiflow.md` | `AGENTS.md` |
| `kilocode` | `.kilo/skills/` | `.kilo/commands/aiflow.md` | `AGENTS.md` |
| `openclaw` | `skills/` | `aiflow` スキル | `AGENTS.md` |

その後、エージェントでプロジェクトを開き `/aiflow setup`（Codex では `$aiflow setup`）を
実行すると、リポジトリを検出し、残りだけを質問して `aiflow/workflow.yaml` を作ります。
回答の変更や更新は、このリポジトリを pull してインストーラーを再実行します（`--force` で
導入済みスキルも更新）。`aiflow/workflow.yaml`、`CLAUDE.md` / `AGENTS.md` の独自の記述
（AI Flow のブロックは `<!-- aiflow:start/end -->` の間）、既存のフックは保持されます。
スキルは Claude Code のツール名で書かれており、他のエージェント向けの対応表は
`aiflow/AGENTS-TOOLS.md` にあります。使用量ログを記録するのは Claude Code だけです。

## クイックスタート（このリポジトリをワークスペースとして使う）

```bash
git clone https://github.com/CongNQ-Dev/harness-flow.git
cd harness-flow
git clone https://github.com/<your-org>/backend.git
git clone https://github.com/<your-org>/admin.git
git clone https://github.com/<your-org>/mobile-app.git
gh auth login      # GitHub 上のリポジトリがある場合  ─┐ /aiflow setup で選んだ
glab auth login    # GitLab 上のリポジトリがある場合  ─┘ ホストの CLI にログイン
claude
```

Claude Code の中で：

```text
/aiflow analyze        ナレッジグラフを一度作成（3 リポジトリ、最新なら数秒）
/aiflow PROJ-123       チケットを開始・再開
```

必要なもの：Claude Code、`python3`、`graphify`、`gh` または `glab`（`/aiflow setup`
で選んだホスト — GitHub か GitLab — 用）、および各リポジトリ
のツールチェーン（Go · Node/yarn · FVM/Flutter）。Notion のチケットは Notion MCP、
ブラウザ、またはチケット本文の貼り付けで読み込みます。

## コマンドは 1 つだけ

| 入力 | 動作 |
|---|---|
| `/aiflow PROJ-XXXX` | チケットの**次のステージ**を実行して停止。新規チケットはステージ 1 から。 |
| `/aiflow` | 全チケットの一覧（ステージ・ルート・リポジトリ・次の手順） |
| `/aiflow PROJ-XXXX status` | 進捗と、ステージごとの時間・トークン・概算コスト |
| `/aiflow PROJ-XXXX feature` | バグ修正ではなく新規開発（`feature/…` ブランチ）として開始 |
| `/aiflow PROJ-XXXX redo spec` | ステージのやり直し（`ticket` `spec` `plan` `impl` `review` `deliver`） |
| `/aiflow analyze` | リポジトリ横断ナレッジグラフの更新 |
| `/aiflow wiki` | プロジェクト Wiki の作成・更新（AI が執筆、トークン消費あり） |
| `/aiflow <PR URL>` | 既存の PR をレビュー |

各ステージの結果を確認したら、もう一度 `/aiflow PROJ-XXXX` を実行します。これが
フローのすべてです。

`feature` を付けない場合、bug か feature かは推測ではなく根拠で判定します。まず
Notion チケットの「種別」プロパティ、なければチケット本文です（根拠の順序は
`aiflow-spec` スキルの §1.2）。

## ステージ

| # | ステージ | 人の作業 | 成果物 `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | チケット整理：影響リポジトリ、難易度判断、リポジトリごとのブランチ | 承認 | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | 仕様：原因分析または設計 | 承認 | `spec.md` | ✅ | ✅ |
| 3 | 修正計画：TDD タスク（1 タスク = 1 リポジトリ） | 承認 | `plan.md` | — | ✅ |
| 4 | 実装：タスクごとに実装＋仕様レビュー＋品質レビュー | — | コード, `reviews/` | ✅ | ✅ |
| 5 | リポジトリ横断の最終レビュー＋手動テストケース | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | デリバリー：テスト、手動 QA ゲート、リポジトリごとに Draft の PR、CI 指摘の修正、その後 Ready | QA・承認 | PR のリンク | ✅ | ✅ |

light ルート（小さなバグ）では、ステージ 1 と 2 は 2 回ではなく **1 ターン**で
進みます。`/aiflow-spec` が難易度判断・調査を行い、直後に `spec.md` を書き、承認は
まとめて 1 回です。別途の対話停止はありません。これは（難易度判断＋修正の書き出し
を 1 ステップにした）ファストトラックであり、「ステージ 1 の承認を足しただけの
同じ対話」ではありません。full ルートと、バグ以外のチケットは、常にステージ 2 の
対話を別途行います。ステージ 5 と 6 は `aiflow-review` スキルの 2 つのセクション
で、light はステージ 5 のセクションだけを省略します。

**light**（1→2→4→6）は、チケットが 1 リポジトリ・3 ファイル以内・API/スキーマ/DB
変更なし・原因特定済み・バグであり、かつセンシティブ領域（課金・認証・マイグレー
ション）でない場合に限ります。それ以外は **full** です。ルートは人が確認します。
ルールは [`aiflow/workflow.yaml`](aiflow/workflow.yaml) にあります。

## このリポジトリの中身

| パス | 用途 |
|---|---|
| `CLAUDE.md` | Claude Code が起動時に読むワークスペースのルール |
| `.claude/skills/aiflow*/` | フロー本体：ルーター `aiflow`、各ステージのスキル、テンプレート、サブエージェント用プロンプト |
| `.claude/skills/*`（その他） | 内部で使うエンジニアリング規律（TDD、デバッグ、検証、コードレビュー）。`/` メニューには出ません |
| `.claude/settings.json` | フック：ナレッジグラフのリマインド、使用量ログ |
| `aiflow/workflow.yaml` | **設定**：リポジトリ、ベースブランチ、テストコマンド、リポジトリ間の契約、難易度ルール、モデル |
| `aiflow/scripts/` | `aiflow_status.py`（一覧と次のステージ）· `aiflow_log.py`（使用量ログ）· `kg_build.py`（ナレッジグラフ） |
| `aiflow/pricing.json` | コスト概算に使う単価 |
| `aiflow/selected-bugs/` | Notion チケットの一覧 |
| `wiki/` | `/aiflow-wiki` が生成する、整理済みのアーキテクチャ文書 |
| `docs/aiflow/<ID>/status.md` | チケットごとに 1 つ。再開ポイント。`/aiflow` が次の実行を決めるときに読む唯一のファイル |
| `docs/aiflow/<ID>/log.json` | チケットごとに 1 つ。ステージごとの使用量（時間・トークン・概算コスト） |

`aiflow-` で始まるスキルだけがステージです（`/aiflow` が呼び出します）。それ以外は
あえて接頭辞を付けない汎用のエンジニアリング規律スキルで、各ステージが状況に応じて
内部で読み込みます（`description` は「Use when…」で始まる標準の自動トリガー形式）。
`user-invocable: false` により `/` メニューにも `/aiflow-*` との衝突にも現れません。
直接呼び出すことはありません。

`aiflow-visual` は `aiflow-` で始まるがステージではない唯一のスキルで、任意のブラウザ補助
（モックアップ・図・クリック選択を表示するローカルページ）です。各ステージは視覚的な質問の
ときだけ、同意を得てから提案します。テレメトリは無効で、`.superpowers/` は git に含めません。

**`status.md` と `log.json` は重複ではなく、別の軸を記録します。** `status.md` は
*進捗*（どのステージが完了し、誰が承認したか）で、`/aiflow` がルーティングに使う
唯一のファイルです。`log.json` は*使用量*（ステージごとの時間・トークン・概算
コスト）で、ルーティングには使いません。「light は本当に full より安いのか」
「どのステージが最もコストがかかるか」は、進捗だけでは答えられません。

## フローが守るルール

**ステージ**
- すべてのステージは完了時に停止します。人の確認なしに先へ進みません。
- `docs/aiflow/` 配下の全成果物と PR の文面は、`workflow.yaml` の `language:`
  （現在は `en`）で書かれます。
- ソースを読む前に、まずナレッジグラフを照会します。
- コードについては各リポジトリチームのガイドが優先されます（例：mobile-app
  の `CLAUDE.md`、`docs/ai/`、project-specific スキル）。

**Git とブランチ**
- Git は常に `git -C <repo>` で実行します。`develop`/`main` へのコミット、`main`
  への直接 push（PR/MR のみ）、force-push は一切行いません。
- **機密情報は commit / push しません。** API キー、トークン、パスワード、秘密鍵、
  `.env*`、認証情報ファイルは stage しません。ファイルは明示的に指定して追加し、
  commit のたびに `git diff --cached` を確認し、怪しいものがあれば止めて警告します。
  チケットのドキュメントにはプレースホルダーを使います。
- チケットが開いている間は、**このラッパーリポジトリと影響を受ける全リポジトリが
  同じチケットブランチ**（`bug/PROJ-XXXX/…` / `feature/PROJ-XXXX/…`）にいます。
  チケット文書はラッパーのチケットブランチにコミットし、`main` には載せません。
  デリバリー時、ラッパーは各リポジトリの PR と並んで文書のみの MR を持ちます。
  `/aiflow PROJ-XXXX` はチケットのブランチへ自動で戻り、`/aiflow` の一覧は
  ラッパーの現在のブランチで見えるチケットを表示します。
- PR は各リポジトリ自身のベースブランチへ（backend/admin は `develop`、モバイルは
  `main`）。ラッパーの PR/MR はこのリポジトリの
  `main` へ。各リポジトリは `/aiflow setup` で選んだホストに応じて `gh`（GitHub）
  または `glab`（GitLab）を使います（`aiflow/workflow.yaml` の `pr.tool` / `pr_tool`）。

**デリバリー（ステージ 6）— 自動で行うことはありません**
- GitHub/GitLab への書き込み（`git push`、PR/MR の作成・編集、コメント投稿）は
  毎回、操作内容・対象・本文を示して確認します。以前の承認、QA の回答、設定
  フラグでは代替できません。PR/MR の merge・approve・close は自動では行わず、
  チャットで依頼したときだけ行います。
- **Draft → CI レビュー → Ready → 顧客。** PR/MR は **Draft** で作成し、CI レビューが
  実行され、CI の指摘をすべて修正または回答します（push のたびに確認）。その後、
  確認のうえ **Ready for review** にし、顧客がレビューします。CI レビューの完了後に
  もう一度 `/aiflow PROJ-XXXX` を実行します（`status.md` の `delivery:` は `draft` →
  `ready`）。CI の指摘が残っている間は Ready にしません。
- PR/MR のタイトルにはタスク ID（例：`[PROJ-123]`）を含めます。本文はチームの
  テンプレート見出しを日本語のまま使います：概要 / スクリーンショット / 相談項目 /
  動作確認手順。
- すべてのレビューと承認にレビュアー名を記録します。`reviews/*.md`、`status.md`
  の承認欄、PR コメントに `human:<名前>` または `ai:<役割> (<モデル>)` を残します。

### デリバリーの順序（ステージ 6）

**Draft の PR/MR → CI レビューが実行 → CI の指摘をすべて対応 → Ready for review →
顧客がレビュー。**

1. 各リポジトリのテストを実行。
2. QA ゲート：「確認済み、PR を作成」— これは push の承諾では**ありません**。
3. 確認 → `<repo>` の `<branch>` を `origin` へ push。
4. 確認 → PR/MR を **Draft で**作成（タイトル、base ← head、本文全文を提示）。
   ここで停止し、`status.md` は `delivery: draft` になります。
5. CI レビューが終わったら、もう一度 `/aiflow <ID>` を実行。CI のコメントとチェックを
   読み取り（読み取りのみ）、レビュアー名とともに `reviews/ci-review.md` に記録し、
   1 件ずつ修正または回答します。push・返信・resolve は毎回事前に確認します。CI の
   未対応コメントがなくなり、チェックが通るまで繰り返します。
6. 確認 → PR/MR を **Ready for review** に変更（CI の指摘が残っている間は不可）。
   `delivery: ready`。顧客がレビューし、そのコメントも次の `/aiflow <ID>` で同様に
   対応します。
7. merge はチャットで依頼したときのみ。

フロー自体のルールは `conventions.md`（`aiflow` スキル内）と `aiflow/AIFLOW.md` に
あります。AI Flow を導入したプロジェクトは、`--force` 付きでインストーラーを再実行すると
変更を取り込めます。ビジュアル版（英語・日本語・ベトナム語）：[aiflow/guide.en.html](aiflow/guide.en.html) ·
[aiflow/guide.ja.html](aiflow/guide.ja.html) · [aiflow/guide.vi.html](aiflow/guide.vi.html)。
