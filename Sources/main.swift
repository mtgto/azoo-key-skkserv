import Foundation
import Network
import KanaKanjiConverterModuleWithDefaultDictionary

// TODO: stderrに出力を分けたい

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

// HACK: ダミーリクエストを送信してモデルを先読みしておく
var dummyComposingText = ComposingText()
dummyComposingText.insertAtCursorPosition("もでるさきよみ", inputStyle: .direct)
let _ = converter.requestCandidates(dummyComposingText, options: convertOption)

func getPort() -> NWEndpoint.Port {
    if CommandLine.arguments.count == 2 {
        if let port = NWEndpoint.Port(CommandLine.arguments[1]) {
            return port
        }
        print("Port argument is invalid. Falling back to default port.")
    }

    return NWEndpoint.Port(1178)
}

func send(on connection: NWConnection, message: String) {
    connection.send(content: message.data(using: .japaneseEUC), completion: .contentProcessed { sendError in
        if let error = sendError {
            print("Send error:", error)
        }
    })
}

func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, context, isComplete, error in
        if let data = data, !data.isEmpty, let message = String(data: data, encoding: .japaneseEUC) {
            print("Received: \(message)")

            let opcode = message.prefix(1)

            switch (opcode) {
            case "0":
                connection.cancel()
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

                    send(on: connection, message: content)
                }
            case "2":
                send(on: connection, message: "azoo-key-skkserve/0.0.1 ")
            case "3":
                let host = Host.current().localizedName ?? ""
                send(on: connection, message: host + "/127.0.0.1:1178/ " )
            case "4":
                send(on: connection, message: "4\n" )
            default:
                break;
            }
        }
        if let error = error {
            print("Receive error:", error)
            connection.cancel()
        } else if isComplete {
            print("Connection ended by remote")
            connection.cancel()
        } else {
            receive(on: connection)
        }
    }
}

func handleConnection(_ connection: NWConnection) {
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("Client connected: \(connection.endpoint)")
            receive(on: connection)
        case .failed(let error):
            print("Connection failed:", error)
            connection.cancel()
        case .cancelled:
            print("Connection cancelled")
        default:
            break
        }
    }
    connection.start(queue: .main)
}

do {
    let port = getPort()
    let listener = try NWListener(using: .tcp, on: port)

    listener.newConnectionHandler = { connection in
        print("Accepted new connection from \(connection.endpoint)")
        handleConnection(connection)
    }

    listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("Server listening on port \(port)")
        case .failed(let error):
            print("Listener failed:", error)
            exit(EXIT_FAILURE)
        default:
            break
        }
    }

    listener.start(queue: .main)
    dispatchMain()
} catch {
    print("Failed to start listener:", error)
    exit(EXIT_FAILURE)
}
