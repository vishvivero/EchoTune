import Foundation
import Testing
@testable import EchoTune

struct DeepgramMessageTests {
    @Test func interimResultsMapToNonFinalPartial() {
        let data = Data(#"{"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hello wor"}]}}"#.utf8)
        let partial = DeepgramMessage.parse(data, receivedAt: Date(timeIntervalSince1970: 10))
        #expect(partial?.text == "hello wor")
        #expect(partial?.isFinal == false)
        #expect(partial?.receivedAt == Date(timeIntervalSince1970: 10))
    }

    @Test func finalResultsMapToFinalPartial() {
        let data = Data(#"{"type":"Results","is_final":true,"speech_final":true,"channel":{"alternatives":[{"transcript":"hello world"}]}}"#.utf8)
        #expect(DeepgramMessage.parse(data)?.isFinal == true)
        #expect(DeepgramMessage.parse(data)?.text == "hello world")
    }

    @Test func metadataAndUtteranceEndAreIgnored() {
        let metadata = Data(#"{"type":"Metadata","request_id":"private"}"#.utf8)
        let utteranceEnd = Data(#"{"type":"UtteranceEnd","last_word_end":1.2}"#.utf8)
        #expect(DeepgramMessage.parse(metadata) == nil)
        #expect(DeepgramMessage.parse(utteranceEnd) == nil)
    }

    @Test func malformedAndErrorMessagesAreIgnored() {
        #expect(DeepgramMessage.parse(Data("not-json".utf8)) == nil)
        #expect(DeepgramMessage.parse(Data(#"{"type":"Error","description":"bad request"}"#.utf8)) == nil)
    }

    @Test func emptyTranscriptIsIgnored() {
        let data = Data(#"{"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"  "}]}}"#.utf8)
        #expect(DeepgramMessage.parse(data) == nil)
    }
}
