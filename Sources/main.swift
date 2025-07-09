import Foundation
import ArgumentParser
import NIOCore
import NIOPosix
import KanaKanjiConverterModuleWithDefaultDictionary
import Logging

LoggingSystem.bootstrap(StreamLogHandler.standardError)
let logger = Logger(label: "io.github.gitusp.azoo-key-skkserv")

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
            do {
                try await runServer(context: self)
            } catch let error {
                logger.error("An error occurred: \(error)")
                abort()
            }
        }

        dispatchMain()
    }
}

AzooKeySkkserv.main()

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

/**
 * SKKServを起動する。
 *
 * Taskの中でrunServerを実行しTask.cancel()を呼び出すことでサーバーを停止できる。
 *
 * ```swift
 * // SKKServを起動
 * let task = Task {
 *     do {
 *         try await runServer(context: context)
 *     } catch is CancellationError {
 *         // タスクがキャンセルされたとき
 *     } catch {
 *         // その他のエラーが発生したとき
 *     }
 * }
 * // SKKServを停止
 * task.cancel()
 * ```
 */
func runServer(context: AzooKeySkkserv) async throws {
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
            port: context.port
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
    logger.notice("Server started on port \(context.port) with incoming charset \(context.incomingCharset.rawValue).")

    try await withThrowingDiscardingTaskGroup { group in
        try await withTaskCancellationHandler {
            try await server.executeThenClose { clients in
                for try await client in clients {
                    group.addTask {
                        await handleClient(context: context, converter: converter, client: client)
                    }
                }
            }
        } onCancel: {
            logger.notice("Server is shutting down.")
            server.channel.close(mode: .input, promise: nil)
        }
    }
}

func handleClient(context: AzooKeySkkserv, converter: KanaKanjiConverter, client: NIOAsyncChannel<ByteBuffer, ByteBuffer>) async {
    // クライアントが先にソケットを閉じている状態でソケットへの書き込みを行ったりすると例外が発生し、
    // そのあとの接続でinboundMessagesからメッセージが取得できなくなってしまう。
    // それを防ぐため例外をキャッチする必要がある。
    do {
        try await client.executeThenClose { inboundMessages, outbound in
            for try await inboundMessage in inboundMessages {
                if let bytes = inboundMessage.getBytes(at: 0, length: inboundMessage.readableBytes),
                    let message = String(bytes: bytes, encoding: context.incomingCharset.stringEncoding) {
                    let opcode = message.prefix(1)

                    switch (opcode) {
                    case "0":
                        return
                    case "1":
                        let yomi = String(message.suffix(message.count - 1))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacing(/([ぁ-ん])[a-z]$/) { matches in matches.1 }
                        var composingText = ComposingText()
                        composingText.insertAtCursorPosition(yomi, inputStyle: .direct)
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
                    case "2":
                        try await outbound.write(allocator.buffer(string: "azoo-key-skkserve/" + version + " "))
                    case "3":
                        let host = Host.current().localizedName ?? ""
                        try await outbound.write(allocator.buffer(string: host + "/127.0.0.1:" + String(context.port) + "/ "))
                    case "4":
                        try await outbound.write(allocator.buffer(string: "4\n" ))
                    default:
                        break
                    }
                }
            }
        }
    } catch {
        logger.warning("Hit error: \(error)")
    }
}
