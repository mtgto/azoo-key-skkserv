import Foundation
import ArgumentParser
import NIOCore
import NIOPosix
import KanaKanjiConverterModuleWithDefaultDictionary

// TODO: stderrに出力を分けたい

let version = "0.1.0"

let allocator = ByteBufferAllocator()

let convertOption = ConvertRequestOptions.withDefaultDictionary(
    // 日本語予測変換
    requireJapanesePrediction: false,
    // 英語予測変換 
    requireEnglishPrediction: false,
    // 入力言語 
    keyboardLanguage: .ja_JP,
    // 学習タイプ 
    learningType: .nothing, 
    // TODO: 扱いについて検討
    memoryDirectoryURL: URL(fileURLWithPath: ""),
    sharedContainerURL: URL(fileURLWithPath: ""),
    zenzaiMode: .on(
        weight: Bundle.module.url(forResource: "zenz-v1", withExtension: "gguf")!,
        inferenceLimit: 1,
        personalizationMode: nil,
        versionDependentMode: .v1
    ),
    metadata: .init(versionString: version)
)

// 文字コードオプション
enum IncomingCharset: String, ExpressibleByArgument, CaseIterable {
    case utf8 = "UTF-8"
    case eucjp = "EUC-JP"

    static var defaultCompletionKind: CompletionKind {
        .list(IncomingCharset.allCases.map { $0.rawValue })
    }

    var stringEncoding: String.Encoding {
        switch self {
            case .utf8: return .utf8
            case .eucjp: return .japaneseEUC
        }
    }
}

struct AzooKeySkkserv: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A SKK server powered by AzooKeyKanaKanjiConverter",
        version: version
    )

    @Option(help: "The network port number to use.")
    var port: Int = 1178

    @Option(help: "The expected incoming character set.")
    var incomingCharset: IncomingCharset = .utf8

    func run() throws {
        Task {
            // コンバータ初期化
            let converter = await KanaKanjiConverter()

            // HACK: ダミーリクエストを送信してモデルを先読みしておく
            var dummyComposingText = ComposingText()
            dummyComposingText.insertAtCursorPosition("もでるさきよみ", inputStyle: .direct)
            let _ = await converter.requestCandidates(dummyComposingText, options: convertOption)

            // こちらのガイドを参考に実装した。
            // https://swiftonserver.com/using-swiftnio-channels/
            let server = try await ServerBootstrap(group: NIOSingletons.posixEventLoopGroup)
                .bind(
                    host: "127.0.0.1",
                    port: port
                ) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        return try NIOAsyncChannel(
                            wrappingChannelSynchronously: channel,
                            configuration: NIOAsyncChannel.Configuration(
                                inboundType: ByteBuffer.self,
                                outboundType: ByteBuffer.self
                            )
                        )
                    }
                }

            try await withThrowingDiscardingTaskGroup { group in
                try await server.executeThenClose { clients in
                    for try await client in clients {
                        group.addTask {
                            try await handleClient(context: self, converter: converter, client: client)
                        }
                    }
                }
            }
        }

        RunLoop.current.run()
    }
}

AzooKeySkkserv.main()

func handleClient(context: AzooKeySkkserv, converter: KanaKanjiConverter, client: NIOAsyncChannel<ByteBuffer, ByteBuffer>) async throws {
    try await client.executeThenClose { inboundMessages, outbound in
        for try await inboundMessage in inboundMessages {
            if let bytes = inboundMessage.getBytes(at: 0, length: inboundMessage.readableBytes),
                let message = String(bytes: bytes, encoding: context.incomingCharset.stringEncoding) {
                let opcode = message.prefix(1)

                switch (opcode) {
                case "0":
                    return
                case "1":
                    var yomi = String(message.suffix(message.count - 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    yomi.replace(/[a-z]$/, with: "")
                    var composingText = ComposingText()
                    composingText.insertAtCursorPosition(yomi, inputStyle: .direct)
                    Task {
                        let results = await converter.requestCandidates(composingText, options: convertOption)

                        let content = results.mainResults.count == 0
                            ? "4\n"
                            : "1/"
                                + results.mainResults
                                    // 読み全文に対応するもの以外・読みと完全一致するものは除去
                                    .filter({ result in result.correspondingCount == yomi.count && result.text != yomi })
                                    .map({ result in result.text })
                                    .joined(by: "/")
                                + "/\n"

                        try await outbound.write(allocator.buffer(string: content))
                    }
                case "2":
                    try await outbound.write(allocator.buffer(string: "azoo-key-skkserve/" + version + " "))
                case "3":
                    let host = Host.current().localizedName ?? ""
                    try await outbound.write(allocator.buffer(string: host + "/127.0.0.1:" + String(context.port) + "/ "))
                case "4":
                    try await outbound.write(allocator.buffer(string: "4\n" ))
                default:
                    break;
                }
            }
        }
    }
}
