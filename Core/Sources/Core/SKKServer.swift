// SPDX-License-Identifier: MIT

import Foundation
import NIOCore
import NIOPosix
import KanaKanjiConverterModuleWithDefaultDictionary
import Logging

@MainActor public struct SKKServer {
    let allocator = ByteBufferAllocator()
    let convertOption: ConvertRequestOptions
    let converter: KanaKanjiConverter
    let version: String
    let logger: Logger

    public init(version: String, logger: Logger) {
        self.version = version
        self.logger = logger
        convertOption = ConvertRequestOptions.withDefaultDictionary(
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
        // コンバータ初期化
        converter = KanaKanjiConverter(dicdataStore: DicdataStore(convertRequestOptions: convertOption))
    }

    public func prepare() {
        // HACK: ダミーリクエストを送信してモデルを先読みしておく
        var dummyComposingText = ComposingText()
        dummyComposingText.insertAtCursorPosition("もでるさきよみ", inputStyle: .direct)
        _ = converter.requestCandidates(dummyComposingText, options: convertOption)
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
      *         try await run()
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
    public func run(host: String = "127.0.0.1", port: Int = 1178, incomingCharset: String.Encoding = .utf8) async throws {
        // こちらのガイドを参考に実装した。
        // https://swiftonserver.com/using-swiftnio-channels/
        let server = try await ServerBootstrap(group: NIOSingletons.posixEventLoopGroup)
            .bind(
                host: host,
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
        logger.notice("Server started on port \(port) with incoming charset \(incomingCharset.rawValue).")

        try await withThrowingDiscardingTaskGroup { group in
            try await withTaskCancellationHandler {
                try await server.executeThenClose { clients in
                    for try await client in clients {
                        group.addTask {
                            await handleClient(client: client, host: host, port: port, incomingCharset: incomingCharset)
                        }
                    }
                }
            } onCancel: {
                logger.notice("Server is shutting down.")
                server.channel.close(mode: .input, promise: nil)
            }
        }
    }

    func handleClient(client: NIOAsyncChannel<ByteBuffer, ByteBuffer>, host: String, port: Int, incomingCharset: String.Encoding) async {
        // クライアントが先にソケットを閉じている状態でソケットへの書き込みを行ったりすると例外が発生し、
        // そのあとの接続でinboundMessagesからメッセージが取得できなくなってしまう。
        // それを防ぐため例外をキャッチする必要がある。
        do {
            try await client.executeThenClose { inboundMessages, outbound in
                for try await inboundMessage in inboundMessages {
                    if let bytes = inboundMessage.getBytes(at: 0, length: inboundMessage.readableBytes),
                       let message = String(bytes: bytes, encoding: incomingCharset) {
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
                            let results = converter.requestCandidates(composingText, options: convertOption)
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
                            try await outbound.write(allocator.buffer(string: "azoo-key-skkserv/" + version + " "))
                        case "3":
                            let hostname = Host.current().localizedName ?? ""
                            try await outbound.write(allocator.buffer(string: "\(hostname)/\(host):\(port) "))
                        case "4":
                            try await outbound.write(allocator.buffer(string: "4\n" ))
                        default:
                            logger.warning("Unsupported opcode: \(opcode)")
                            break
                        }
                    }
                }
            }
            logger.notice("Connection is closed")
        } catch {
            logger.warning("Hit error: \(error)")
        }
    }
}
