azoo-key-skkserve
===

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を変換に利用したskkservです。

## 概要

受け取った読みをAzooKeyKanaKanjiConverterで漢字変換し、候補を返します。  
これにより例えば:

- `配達業者` などそれぞれの熟語は辞書に入っているけれど、繋がったものは登録されていないケースでも候補を表示できます。
- 送り仮名が不明瞭であったりする際、送り仮名ごと入力しても候補が表示されます。
- SKKの流儀とは反しそうですが、形態素解析の力を借りて、文をそのまま変換するような使い方も可能です。
    - SKKの仕様上ユーザー辞書にそのまま登録されてしまうので、その点はご注意ください。

### 動作イメージ

TODO:

### 使い方

```sh
azoo-key-skkserv [port]
```

`port` を指定しない場合、デフォルトの `1178` が使用されます。

#### バックグラウンド実行

```sh
nohup azoo-key-skkserv [port] >&/dev/null &
```

など

## ビルド

### 開発

```sh
swift run azoo-key-skkserve
```

### リリース

```sh
swift build -c release
```

## 動作検証環境

[macSKK](https://github.com/mtgto/macSKK)

## TODO

- [x] PoC
- [ ] Zenzaiの導入
- [ ] ネットワークサンドボックス
- [ ] バイナリ配布
