import JavaScriptCore

final actor HLJS {
    private var hljs: JSValue?
    
    private func load() throws -> JSValue {
        if let hljs {
            return hljs
        }
        guard let context = JSContext() else {
            throw HLJSError.contextIsNil
        }
        let highlightPath = Bundle.module.path(forResource: "highlight.min", ofType: "js")
        guard let highlightPath else {
            throw HLJSError.fileNotFound
        }
        let highlightScript = try String(contentsOfFile: highlightPath)
        context.evaluateScript(highlightScript)
        guard let hljs = context.objectForKeyedSubscript("hljs") else {
            throw HLJSError.hljsNotFound
        }
        self.hljs = hljs
        return hljs
    }
    
    func highlight(_ text: String, mode: HighlightMode) -> HLJSResult {
        let segments = text.components(separatedBy: "\n")  // Simple segmentation by sentence
        var finalText = ""
        var totalRelevance = 0
        var isIllegal = false
        
        for segment in segments {
            do {
                let result = try highlightSegment(segment, mode: mode)
                finalText += result.value + "\n "
                totalRelevance += Int(result.relevance)
                isIllegal = isIllegal || result.illegal
            } catch {
                // Append unmodified segment if error occurs
                finalText += segment + "\n"
            }
        }
        
        return HLJSResult(value: finalText, illegal: isIllegal, language: "mixed", relevance: Int32(totalRelevance))
    }
    
    private func highlightSegment(_ text: String, mode: HighlightMode) throws -> HLJSResult {
        switch mode {
            case .automatic:
                return try highlightAuto(text)
            case .languageAlias(let alias):
                return try highlight(text, language: alias, ignoreIllegals: false)
            case .languageAliasIgnoreIllegal(let alias):
                return try highlight(text, language: alias, ignoreIllegals: true)
            case .language(let language):
                return try highlight(text, language: language.alias, ignoreIllegals: false)
            case .languageIgnoreIllegal(let language):
                return try highlight(text, language: language.alias, ignoreIllegals: true)
        }
    }
    
    private func highlightAuto(_ text: String) throws -> HLJSResult {
        let hljs = try load()
        let jsResult = hljs.invokeMethod(
            "highlightAuto",
            withArguments: [text]
        )
        return try highlightResult(jsResult)
    }
    
    private func highlight(_ text: String, language: String, ignoreIllegals: Bool) throws -> HLJSResult {
        var languageOptions: [String: Any] = ["language": language]
        if ignoreIllegals {
            languageOptions["ignoreIllegals"] = ignoreIllegals
        }
        let hljs = try load()
        let jsResult = hljs.invokeMethod(
            "highlight",
            withArguments: [text, languageOptions]
        )
        return try highlightResult(jsResult)
    }
    
    private func highlightResult(_ result: JSValue?) throws -> HLJSResult {
        guard let result else {
            throw HLJSError.valueNotFound
        }
        let illegal = result.objectForKeyedSubscript("illegal").toBool()
        let relevance = result.objectForKeyedSubscript("relevance").toInt32()
        guard
            let value = result.objectForKeyedSubscript("value").toString(),
            let language = result.objectForKeyedSubscript("language").toString()
        else {
            throw HLJSError.valueNotFound
        }
        return HLJSResult(value: value, illegal: illegal, language: language, relevance: relevance)
    }
}
