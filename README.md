azoo-key-skkserv
===

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を変換に利用したskkservです。  
ニューラルかな漢字変換システム「Zenzai」で利用するモデルは[zenz-v1](https://huggingface.co/Miwa-Keita/zenz-v1)を利用させていただいています。

## azoo-key-skkservについて

macOSで動作する、受け取った読みをAzooKeyKanaKanjiConverterで漢字変換し、候補を辞書として返すskkservです。  
これにより例えば:

- `配達業者` などそれぞれの熟語は辞書に入っているけれど、繋がったものは登録されていないケースでも候補を表示できます。
- 送り仮名が不明瞭であったりする際、送り仮名ごと入力しても候補が表示されます。
- SKKの流儀とは反しそうですが、Zenzaiの強力な変換力により、長文をそのまま変換することも可能です。
    - SKKの仕様上ユーザー辞書にそのまま登録されてしまうと思うので、その点はご注意ください。

## インストール

[Releases](https://github.com/gitusp/azoo-key-skkserv/releases)よりご自身のarchに対応したパッケージをダウンロードしてください。  
その後、解凍されたパッケージをお好きなところに配置してください。

私は以下のような感じでホームディレクトリ配下に置いています。

```sh
mv ~/Downloads/azoo-key-skkserve-arm64-0.0.1 ~/opt
ln -s ~/opt/azoo-key-skkserve-arm64-0.0.1/azoo-key-skkserv ~/bin/azoo-key-skkserv
```

## 使い方

```sh
azoo-key-skkserv [port]
```

`port` を指定しない場合、デフォルトの `1178` が使用されます。

### バックグラウンド実行

私はmacOSのAutomatorで以下のshellを実行するアプリケーションを作成しています。

```sh
nohup ~/bin/azoo-key-skkserv >&/dev/null &
```

作成したアプリケーションはログイン項目に登録しておき、自動的にサーバーが立ち上がるようにしています。

## 仕様

### 文字コード

入力・出力どちらもEUC-JP

### プロトコル

skkservの標準に準拠しているつもりです。  
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

## やりたいこと等

- [x] PoC
- [x] Zenzaiの導入
- [ ] homebrewでバイナリ配布
- [ ] ネットワークサンドボックス
    - 見出し語の入力がどこにも送信されないことを保証したい
    - SKKにはTCPで通信できる必要がある。リモートへの通信のみ制限することができるのか？
    - 詳しい方いたら教えてください🙏
- [ ] 設定ファイルで挙動を変えられるように？
    - 設定したいことがあれば
    - 少しの項目であればコマンドライン引数でよさそう
    - luaを実行できるようにしておけば、プログラマブルな補完とかもできて夢広がる
