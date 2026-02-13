# redmine_auto_close

> [!Tip]
> [redmine_studio_plugin](https://github.com/RedminePower/redmine_studio_plugin) をご利用いただければ、この機能を含む複数の便利な機能をまとめて管理できます。
>
> また、[Redmine Studio](https://www.redmine-power.com/) アプリと組み合わせることで、より快適に Redmine をお使いいただけます。

## 概要

条件に基づいてチケットを自動的にクローズ（ステータス変更・担当者変更・コメント追加）するプラグインです。
全子チケット終了時の親チケット自動クローズや、期限切れチケットの定期クローズなどが可能です。

詳細は [こちら](https://github.com/RedminePower/redmine_studio_plugin/blob/master/docs/auto_close.md) をご覧ください。

## 対応バージョン

- Redmine 5.x（5.1.11 にて動作確認済み）
- Redmine 6.x（6.1.1 にて動作確認済み）

## インストール

Redmine のインストール先はお使いの環境によって異なります。
以下の説明では `/var/lib/redmine` を使用しています。
お使いの環境に合わせて変更してください。

| 環境 | Redmine パス |
|------|-------------|
| apt (Debian/Ubuntu) | `/var/lib/redmine` |
| Docker (公式イメージ) | `/usr/src/redmine` |
| Bitnami | `/opt/bitnami/redmine` |

以下を実行し、Redmine を再起動してください。

```bash
cd /var/lib/redmine/plugins
git clone https://github.com/RedminePower/redmine_auto_close.git
cd /var/lib/redmine
bundle exec rake redmine_auto_close:install RAILS_ENV=production
```

`install` タスクは以下を実行します:
1. データベースマイグレーション
2. cron ジョブの登録（毎日 3:00 に期限切れチェックを実行）

## アンインストール

以下を実行し、Redmine を再起動してください。

```bash
cd /var/lib/redmine
bundle exec rake redmine_auto_close:uninstall RAILS_ENV=production
rm -rf plugins/redmine_auto_close
```

`uninstall` タスクは以下を実行します:
1. cron ジョブの解除
2. データベースのロールバック
