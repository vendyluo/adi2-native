import Foundation

enum Localization {
    static var language=UserDefaults.standard.string(forKey:"interfaceLanguage") ?? "zh-Hant"
    private static var pairs:[String:(String,String)]=[:]
    static func text(_ zh:String,_ en:String)->String {
        pairs[zh]=(zh,en);pairs[en]=(zh,en)
        return language == "en" ? en : zh
    }
    static func translated(_ value:String)->String {
        guard let pair=pairs[value] else { return value }
        return language == "en" ? pair.1 : pair.0
    }
}
func L(_ zh:String,_ en:String)->String { Localization.text(zh,en) }
