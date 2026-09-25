# architecture/<repo>.md template

```markdown
---
type: Architecture Overview
title: <repo name> アーキテクチャ概要
repos: [<repo>]
sources: [<repo>/README.md, <repo>/go.mod|package.json|pubspec.yaml, graphify:<community ids>]
generated: {by: aiflow-wiki, at: YYYY-MM-DD}
status: draft
---

# <repo> — アーキテクチャ概要

## スタック
<言語・フレームワーク・DB・主要ライブラリ。workflow.yaml の stack: と一致させ、
実際の設定ファイルで確認したものだけ書く>

## レイヤー / モジュール構成
<グラフのコミュニティ構造から導いたレイヤー図。箇条書きまたは簡単な図>

## 主要モジュール（god nodes）
| モジュール | 役割 | 主な依存先 |
|---|---|---|
<graphify の中心性が高いノード3〜6個>

## 境界づけられたコンテキスト
<コードのディレクトリ構成から見える責務の境界。他リポジトリとの境界は
contracts.md 側で扱う>

## このリポジトリ固有の注意点
<workflow.yaml の repos.<repo>.notes と重複せず、アーキテクチャ理解に必要な補足のみ>
```

Every factual line needs a source: `repo/path:line` or a graphify node id in
`sources:`. No source → don't write the claim.
