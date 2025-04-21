import KanaKanjiConverterModuleWithDefaultDictionary
import Hummingbird

let converter = KanaKanjiConverter()
let router = Router()

// TODO: skkservの仕様に合わせる
router.get("hello") { request, _ -> String in
    var c = ComposingText()
    c.insertAtCursorPosition("あずーきーはしんじだいのきーぼーどあぷりです", inputStyle: .direct)
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
    return results.mainResults.first!.text
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
// run hummingbird application
try await app.runService()
