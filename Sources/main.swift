import Foundation
import NIOCore
import NIOPosix
import KanaKanjiConverterModuleWithDefaultDictionary

// TODO: stderrに出力を分けたい
let allocator = ByteBufferAllocator()

let converter = KanaKanjiConverter()

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
    metadata: .init(versionString: "0.0.1")
)

let port = getPort()

// HACK: ダミーリクエストを送信してモデルを先読みしておく
var dummyComposingText = ComposingText()
dummyComposingText.insertAtCursorPosition("もでるさきよみ", inputStyle: .direct)
let _ = converter.requestCandidates(dummyComposingText, options: convertOption)

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
                try await handleClient(client)
            }
        }
    }
}

func handleClient(_ client: NIOAsyncChannel<ByteBuffer, ByteBuffer>) async throws {
    try await client.executeThenClose { inboundMessages, outbound in
        for try await inboundMessage in inboundMessages {
            if let bytes = inboundMessage.getBytes(at: 0, length: inboundMessage.readableBytes),
                let message = String(bytes: bytes, encoding: .japaneseEUC) {
                let opcode = message.prefix(1)

                switch (opcode) {
                case "0":
                    return
                case "1":
                    let yomi = String(message.suffix(message.count - 1)).trimmingCharacters(in: .whitespacesAndNewlines)
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
                    try await outbound.write(allocator.buffer(string: "azoo-key-skkserve/0.1.0 "))
                case "3":
                    let host = Host.current().localizedName ?? ""
                    try await outbound.write(allocator.buffer(string: host + "/127.0.0.1:" + String(port) + "/ "))
                case "4":
                    try await outbound.write(allocator.buffer(string: "4\n" ))
                default:
                    break;
                }
            }
        }
    }
}

func getPort() -> Int {
    if CommandLine.arguments.count == 2 {
        if let port = Int(CommandLine.arguments[1]) {
            return port
        }
        print("Port argument is invalid. Falling back to default port.")
    }

    return 1178
}
