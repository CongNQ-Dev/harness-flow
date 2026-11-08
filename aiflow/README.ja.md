# Basic AI Flow — ガイド

[English](README.en.md) · 日本語 · ビジュアル版: [guide.ja.html](guide.ja.html)

**backend**（Go）、**admin**（Next.js）、**mobile-app**（Flutter）
を横断する AI 駆動の開発フローです。各リポジトリの中ではなく、ワークスペース
直下（`ai-flow-demo`）で Claude Code を起動してください。1 回に 1 ステージだけ
実行し、必ず人の確認で止まります。

## コマンドは 1 つだけ

| 入力 | 動作 |
|---|---|
| `/aiflow PROJ-XXXX` | チケットの**次のステージ**を実行して停止。新規チケットはステージ 1 から。 |
| `/aiflow` | 全チケットの一覧（ステージ・ルート・対象リポジトリ・次の手順） |
| `/aiflow PROJ-XXXX status` | 進捗と、ステージごとの時間・トークン・概算コスト |
| `/aiflow PROJ-XXXX feature` | バグ修正ではなく新規開発（`feature/…` ブランチ）として開始 |
| `/aiflow PROJ-XXXX redo <stage>` | ステージのやり直し（`ticket` `spec` `plan` `impl` `review` `deliver`） |
| `/aiflow analyze` | リポジトリ横断ナレッジグラフの更新（無料） |
| `/aiflow wiki` | プロジェクト Wiki の作成・更新（LLM 使用、トークン消費あり） |
| `/aiflow <PR/MR の URL>` | 既存の PR/MR をレビュー |

## ステージ

| # | ステージ | 人の作業 | 成果物 `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | チケット整理：Notion 取得、bug/feature 判定、影響リポジトリ、難易度判断、ブランチ作成 | 承認 | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | 仕様：原因分析または設計 | 承認 | `spec.md` | ✅ | ✅ |
| 3 | 計画：TDD タスク（1 タスク = 1 リポジトリ） | 承認 | `plan.md` | — | ✅ |
| 4 | 実装：タスクごとに実装・仕様レビュー・品質レビュー | — | コード, `reviews/` | ✅ | ✅ |
| 5 | リポジトリ横断の最終レビュー＋手動テストケース | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | デリバリー：テスト、手動 QA、git ルートごとに Draft の PR/MR、CI 指摘の修正、その後 Ready | QA・承認 | PR/MR のリンク | ✅ | ✅ |

**light**（1→2→4→6）は次をすべて満たすときだけ：1 リポジトリ、3 ファイル以内、
API/スキーマ/DB 変更なし、原因特定済み、バグである、センシティブ領域（課金・
認証・マイグレーション）ではない。このときステージ 1 と 2 は 1 ターンで進み、
承認も 1 回です。それ以外は **full**。ルートは引き上げのみで、黙って下げることは
ありません。`status.md` は進捗（再開ポイント）、`log.json` は使用量（時間・
トークン・コスト）で、ルーティングには使われません。

## 必須ルール

1. **`main` へ直接 push しない。** ベースブランチへの反映は PR/MR のみ。
   `develop`/`main` へのコミットも force-push も禁止。機密情報（キー、トークン、`.env*`）も commit しない。
2. **GitHub/GitLab への書き込みは毎回確認。** `git push`、PR/MR の作成・編集、
   コメント投稿の前に、操作内容・対象・投稿する本文を提示し、明確な承諾があった
   ときだけ実行します。以前の承認、QA の回答、設定フラグでは代替できません。
   PR/MR の merge・approve・close は自動では行わず、チャットで依頼したときのみ。
3. **レビュアー名を必ず記録。** すべてのレビューと承認に `human:<名前>` または
   `ai:<役割> (<モデル>)` を、`reviews/*.md`、`status.md` の承認欄、PR/MR コメント
   に残します。
4. **全リポジトリで同じチケットブランチ。** チケットが開いている間、ラッパーと
   影響を受ける全リポジトリが同じ `bug/PROJ-XXXX/…` または `feature/PROJ-XXXX/…`
   ブランチにいます。

## PR/MR テンプレート

タイトルに Notion のタスク ID（例：`[PROJ-123] …`）を含め、タスクと連携します。
本文はチームの見出しをそのまま使います。

| 見出し | 内容 |
|---|---|
| 概要 | この PR で何をなぜ変えたか。関連 PR と spec/plan/レビューへのリンク |
| スクリーンショット（UIの変更があれば） | UI 変更の前後画像。変更がなければその旨を記載 |
| 相談項目（あれば） | レビュアーに聞きたい点（Minor の指摘を含む）。なければ「なし」 |
| 動作確認手順 | レビュアーが再現できるように：端末、手順、結果。未確認の範囲も正直に記載 |

## デリバリーの順序（ステージ 6）

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

ラッパーを含む各リポジトリは、`/aiflow setup` で選んだホストに応じて `gh`（GitHub）
または `glab`（GitLab）を使います（`aiflow/workflow.yaml` の `pr.tool` / `pr_tool`）。
base は backend/admin が `develop`、モバイルとラッパーが `main`。

## フローの更新

スキルとルールは汎用の
`harness-ai-flow`
バンドルから提供されます。変更はそちら（README も同時に）で行い、このリポジトリ
では `install.sh --force` で再インストールしてください。`.claude/skills/` の直接
編集は上書きされます。プロジェクト固有の設定は `aiflow/workflow.yaml` のみに置きます。

任意: `aiflow-visual` はブラウザ補助（モックアップや図を表示するローカルページ）です。
各ステージは視覚的な質問のときだけ、同意を得てから提案します。テレメトリは無効で、
`.superpowers/` は git に含めません。
