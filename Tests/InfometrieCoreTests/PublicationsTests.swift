import Foundation
import Testing
@testable import InfometrieCore

struct PublicationsTests {
    private let tweet = #"{"id":81,"seq":900,"at":"2026-09-23T14:00:00Z","kind":"tweet","media":"x","channel":"X","channel_key":"x","person":"Camille Martin","party":"TEST","title":"Une publication","url":"https://x.com/i/status/123456789","verbatim":"Texte complet"}"#

    @Test func publicationDecodesAndCannotEnterAudioEvenWithAnInconsistentMediaFlag() throws {
        let detail = try JSONDecoder().decode(SequenceDetail.self, from: Data(tweet.utf8))
        #expect(detail.item.isTweet)
        #expect(detail.item.kindLabel == "Publication X")
        #expect(detail.item.channelKey == "x")
        #expect(detail.item.channelLogoAsset == "channel-x")
        #expect(detail.item.publicationURL?.host == "x.com")
        #expect(detail.playlist.isEmpty)
        #expect(!detail.item.canPlay)
        var inconsistent = detail.item
        inconsistent.hasMedia = true; inconsistent.video = true
        #expect(!inconsistent.canPlay)
        let copy = try JSONDecoder().decode(FeedItem.self, from: JSONEncoder().encode(detail.item))
        #expect(copy == detail.item)
    }

    @Test func oldSavedFiltersKeepTheirScopeAndNewFiltersIncludeX() throws {
        let legacy = #"{"persons":["Camille Martin"],"parties":[],"interventions":true,"citations":true}"#
        let old = try JSONDecoder().decode(SearchFilters.self, from: Data(legacy.utf8))
        let post = try JSONDecoder().decode(FeedItem.self, from: Data(tweet.utf8))
        #expect(old.selectedKinds == ["intervention", "citation"])
        #expect(old.kindSelection == nil)
        #expect(!old.accepts(post))
        #expect(SearchFilters().accepts(post))
        var onlyX = SearchFilters(persons: ["Camille Martin"], parties: ["TEST"])
        onlyX.selectKind(3)
        #expect(onlyX.selectedKinds == ["tweet"])
        #expect(onlyX.accepts(post))
        let saved = SavedSearch(name: "Sur X", filters: onlyX)
        #expect(try JSONDecoder().decode(SavedSearch.self, from: JSONEncoder().encode(saved)) == saved)
        onlyX.parties = ["OTHER"]
        #expect(!onlyX.accepts(post))
    }

    @Test func kindsAreSentForEverySelectionWithoutChangingAudienceOrCursor() throws {
        let api = APIClient()
        for (index, expected) in [(0, "intervention,citation,tweet"), (1, "intervention"), (2, "citation"), (3, "tweet")] {
            var filters = SearchFilters(persons: ["Camille & Sam"], parties: ["TEST"])
            filters.selectKind(index)
            let request = api.feedRequest(token: "fixture", filters: filters, since: 91)
            let url = try #require(request.url)
            let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(query.contains(.init(name: "kinds", value: expected)))
            #expect(query.contains(.init(name: "since_seq", value: "91")))
            #expect(query.contains(.init(name: "persons", value: "Camille & Sam")))
            #expect(query.contains(.init(name: "parties", value: "TEST")))
        }
    }

    @Test func unknownKindsDoNotBecomeInterventions() throws {
        var item = try JSONDecoder().decode(FeedItem.self, from: Data(tweet.utf8))
        var filter = SearchFilters(); filter.selectKind(1)
        #expect(!filter.accepts(item))
        item.kind = "future-kind"
        #expect(item.kindLabel == "Publication")
        #expect(!filter.accepts(item))
        #expect(!SearchFilters().accepts(item))
    }

    @Test func externalPublicationLinksAndAssetKeysAreBounded() throws {
        var item = try JSONDecoder().decode(FeedItem.self, from: Data(tweet.utf8))
        for invalid in ["", "javascript:alert(1)", "http://x.com/i/status/1", "https://x.com.evil.invalid/i/status/1", "https://x.com@evil.invalid/1", "https://token@x.com/1", "https://x.com:8443/1", "/rest/v1/feed"] {
            item.url = invalid
            #expect(item.publicationURL == nil)
        }
        item.url = "https://twitter.com/i/status/1"
        #expect(item.publicationURL != nil)
        for invalid in ["", "../secret", "https://example.invalid/logo", "channel/a", String(repeating: "a", count: 81)] {
            item.channelKey = invalid
            #expect(item.channelLogoAsset == nil)
        }
        item.channelKey = "France_Info"
        #expect(item.channelLogoAsset == "channel-france_info")
        for (key, expectedAsset) in [
            ("lcp-public-senat", "channel-lcp-senat"),
            ("backup-cnews", "channel-cnews"),
            ("bfm_business", "channel-bfm-business"),
            ("france_culture", "channel-france-culture"),
            ("radio_j", "channel-radio-j"),
            ("rmc_decouverte", "channel-rmc-decouverte"),
        ] {
            item.channelKey = key
            #expect(item.channelLogoAsset == expectedAsset)
        }
    }
}
