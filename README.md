azoo-key-skkserve
===

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を変換に利用したskkservです。  
受け取った読みをAzooKeyKanaKanjiConverterで漢字変換し、候補を返します。

## ビルド

### 開発

```sh
swift run azoo-key-skkserve
```

### リリース

```sh
swift build -c release
```

## 使い方

```sh
nohup azoo-key-skkserv [port] >&/dev/null &
```

`port` を指定しない場合、デフォルトの `1178` が使用されます。

## 動作検証環境

[macSKK](https://github.com/mtgto/macSKK)

## ロードマップ

- [x] PoC
- [ ] Zenzaiの導入
- [ ] Makefile
- [ ] 使い方もう少し使いやすく
- [ ] バイナリ配布
- [ ] SKKのユーザー辞書が無制限に増えていく問題の対応
