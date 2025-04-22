azoo-key-skkserv
===

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を変換に利用したskkservです。

## azoo-key-skkservについて

受け取った読みをAzooKeyKanaKanjiConverterで漢字変換し、候補を返します。  
これにより例えば:

- `配達業者` などそれぞれの熟語は辞書に入っているけれど、繋がったものは登録されていないケースでも候補を表示できます。
- 送り仮名が不明瞭であったりする際、送り仮名ごと入力しても候補が表示されます。
- SKKの流儀とは反しそうですが、形態素解析の力を借りて、文をそのまま変換するような使い方も可能です。
    - SKKの仕様上ユーザー辞書にそのまま登録されてしまうので、その点はご注意ください。

## インストール

ソースコードからビルドする必要があります。

```sh
# リポジトリをクローンしてビルド
git clone git@github.com:gitusp/azoo-key-skkserv.git
cd azoo-key-skkserv
swift build -c release

# お好きなところに配置してください
cp -r .build/arm64-apple-macosx/release ~/opt/azoo-key-skkserve
ln -s ~/opt/azoo-key-skkserve/azoo-key-skkserv ~/bin/azoo-key-skkserv
```

## 使い方

```sh
azoo-key-skkserv [port]
```

`port` を指定しない場合、デフォルトの `1178` が使用されます。

### バックグラウンド実行

```sh
nohup azoo-key-skkserv [port] >&/dev/null &
```

など

## 仕様

### 文字コード

入力・出力どちらもEUC-JP

### プロトコル

基本的にはskkservの標準に準拠しているつもりです。  
入力の1文字目を `opcode` とし、それ以降を `operand` とした場合:

| opcode | operand  | 説明             | 出力                                              |
|--------|----------|------------------|---------------------------------------------------|
| 0      | なし     | コネクション破棄 | なし                                              |
| 1      | 見出し語 | 辞書要求         | 候補がある時は `1/{候補1}/{候補2}/.../{候補n}/\n` |
| 2      | なし     | サーバー情報要求 | `azoo-key-skkserve/{バージョン} `                 |
| 3      | なし     | ホスト情報要求   | `{ホスト名}/127.0.0.1:{ポート}/ `                 |
| 4      | 見出し語 | 補完要求         | `4\n` (未実装)                                    |

## 開発

```sh
swift run azoo-key-skkserve
```

## 動作検証環境

[macSKK](https://github.com/mtgto/macSKK)

## TODO

- [x] PoC
- [ ] バイナリ配布
- [ ] ネットワークサンドボックス
- [ ] Zenzaiの試験導入
