import Network
import KanaKanjiConverterModuleWithDefaultDictionary

let converter = KanaKanjiConverter()

// TODO: skkservの仕様に合わせる
let port = NWEndpoint.Port(8080)

// Receive data on the connection, echo back, and continue receiving
func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, context, isComplete, error in
        if let data = data, !data.isEmpty {
            let message = String(decoding: data, as: UTF8.self)
            print("Received: \(message)")

            var c = ComposingText()
            c.insertAtCursorPosition(message, inputStyle: .direct)
            Task {
                let results = await converter.requestCandidates(c, options: .withDefaultDictionary(
                    // 日本語予測変換
                    requireJapanesePrediction: false,
                    // 英語予測変換 
                    requireEnglishPrediction: false,
                    // 入力言語 
                    keyboardLanguage: .ja_JP,
                    // 学習タイプ 
                    learningType: .nothing, 
                    // TODO: 設定できるように
                    // 学習データを保存するディレクトリのURL（書類フォルダを指定）
                    memoryDirectoryURL: .documentsDirectory, 
                    // ユーザ辞書データのあるディレクトリのURL（書類フォルダを指定）
                    sharedContainerURL: .documentsDirectory, 
                    // メタデータ
                    metadata: .init(appVersionString: "0.0.1")
                ))

                connection.send(content: results.mainResults.first!.text.data(using: .utf8), completion: .contentProcessed { sendError in
                    if let error = sendError {
                        print("Send error:", error)
                    }
                })
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

// Handle a new incoming connection
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
    // Create a TCP listener on the specified port
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
