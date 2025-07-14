// SPDX-License-Identifier: MIT

import SwiftUI
import Core
import Logging

struct ContentView: View {
    @State var host: String = "127.0.0.1"
    @State var port: Int = 1178
    @State var incomingCharset: IncomingCharset = .utf8
    @State var running: Bool = false
    @State var serverTask: Task<Void, Error>? = nil
    @State var showingAlert: Bool = false
    @State var errorMessage: String = ""
    let logger = Logger(label: "io.github.gitusp.azoo-key-skkserv")
    let server: SKKServer
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 1
        formatter.maximum = 65535
        return formatter
    }()

    init() {
        server = SKKServer(version: "0.1.0", logger: logger)
    }

    var body: some View {
        VStack {
            Form {
                TextField("Host", text: $host, prompt: Text("127.0.0.1"))
                    .disabled(running)
                TextField("Port", value: $port, formatter: formatter, prompt: Text("1178"))
                    .disabled(running)
                Picker("Incoming Charset", selection: $incomingCharset) {
                    ForEach(IncomingCharset.allCases, id: \.self) { charset in
                        Text(charset.rawValue).tag(charset)
                    }
                }
                .disabled(running)
                Button("Start Server") {
                    running = true
                    serverTask = Task {
                        do {
                            try await server.run(host: host, port: port, incomingCharset: incomingCharset.stringEncoding)
                        } catch is CancellationError {
                            // キャンセルが正常に完了した
                            logger.notice("Server task was cancelled.")
                        } catch {
                            // キャンセル以外のエラーが発生した場合はアラートを表示する
                            logger.error("Server task error: \(error)")
                            errorMessage = error.localizedDescription
                            showingAlert = true
                        }
                        running = false
                        serverTask = nil
                    }
                }
                .disabled(running)
                Button("Stop Server") {
                    serverTask?.cancel()
                }
                .disabled(!running)
            }
        }
        .padding()
        .onAppear {
            server.prepare()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 320, height: 180)
}
