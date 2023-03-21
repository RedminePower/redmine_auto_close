# redmine_auto_close

## 機能

- このプラグインインは、特定のトリガで、該当チケットのステータスを終了にしたり、担当者を変更したりすることができます。
  - 初版では、「全子チケット終了時」のトリガのみをサポートしています。
  - 今後は、「期限切れ時」のトリガもサポート予定です。
- 主に [Redmine Time Puncher](https://www.redmine-power.com/) のレビュー機能と、合わせて使うことで、効果を発揮することができます。
  - 「Redmine Time Puncher」のレビュー機能では、レビュー対象の配下に、レビュー依頼のチケットおよび、レビュー指摘のチケットが作成されます。
  - 全員がレビューを実施済みになり、すべてのレビュー指摘が終了になったら、レビュー開催のチケットを自動で終了にすることができます。 

## 対応Redmine
- V4.x (V4.2.3にて動作確認済み)

## インストール
- Redmineのプラグインのディレクトリにて、以下を実行してください。

```
$ cd /var/lib/redmine/plugins
$ git clone https://github.com/RedminePower/redmine_auto_close.git
$ bundle exec rake redmine:plugins:migrate NAME=redmine_auto_close RAILS_ENV=production
```

## 使用方法
プラグインをインストールすると、管理者メニューに「自動クローズ」が追加されます。

![image](https://user-images.githubusercontent.com/87136359/226633071-159626ee-aca0-4724-b651-187ca66de7b2.png)

「自動クローズ」を押下すると、一覧画面に遷移します。

![image](https://user-images.githubusercontent.com/87136359/226633407-4cac6c54-d2fe-4d13-95fb-3c60c7ad765a.png)

「新しい自動クローズ」を押下し、各種項目を入力し、「OK」ボタンを押下してください。

![image](https://user-images.githubusercontent.com/87136359/226633705-caf445eb-c687-478a-bd71-f126856582ae.png)

「トリガ」にて設定した条件を満たした場合に、「アクション」で指定した内容を実行します。

## アンインストール

- 以下のコマンドを実行して、追加したDBを削除後に、配置したプラグインフォルダを削除してください。

```
$ cd /var/lib/redmine/plugins
$ bundle exec rake redmine:plugins:migrate NAME=redmine_auto_close VERSION=0 RAILS_ENV=production
$ rm -rf redmine_auto_close
```


