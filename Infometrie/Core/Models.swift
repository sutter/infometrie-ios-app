import Foundation

struct FeedItem: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var seq: Int64 = 0
    var at: String
    var kind: String
    var media: String
    var channel: String
    var show: String = ""
    var person: String
    var role: String = ""
    var party: String
    var title: String
    var citedBy: String = ""
    var durationSec: Int = 0
    var hasMedia: Bool = false
    var video: Bool = false
    var channelKey: String = ""
    var url: String = ""

    var isCitation: Bool { kind == "citation" }
    var isTweet: Bool { kind == "tweet" }
    var canPlay: Bool { hasMedia && !isTweet }
    /// The title without the "(Person)" prefix the API sometimes adds: the speaker is already shown above it.
    var displayTitle: String {
        let prefix = "(\(person))"
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil else { return title }
        return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var kindLabel: String {
        switch kind {
        case "intervention": "Intervention"
        case "citation": "Citation"
        case "tweet": "Publication X"
        default: "Publication"
        }
    }
    /// An external post is opened by the system, never by the authenticated API client.
    var publicationURL: URL? {
        guard isTweet, let value = URL(string: url), value.scheme?.lowercased() == "https",
              let host = value.host?.lowercased(),
              ["x.com", "www.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com"].contains(host),
              value.user == nil, value.password == nil, value.port == nil || value.port == 443 else { return nil }
        return value
    }
    private static let channelLogoAliases = [
        "lcp-public-senat": "lcp-senat",
        "backup-cnews": "cnews",
        "bfm_business": "bfm-business",
        "france_culture": "france-culture",
        "radio_j": "radio-j",
        "rmc_decouverte": "rmc-decouverte",
    ]
    var channelLogoAsset: String? {
        let key = channelKey.lowercased()
        guard !key.isEmpty, key.count <= 80,
              key.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else { return nil }
        return "channel-\(Self.channelLogoAliases[key] ?? key)"
    }
    var date: Date? { APIDate.parse(at) }
    var durationLabel: String { String(format: "%d:%02d", max(0, durationSec) / 60, max(0, durationSec) % 60) }

    enum CodingKeys: String, CodingKey {
        case id, seq, at, kind, media, channel, show, person, role, party, title, video
        case citedBy = "cited_by", durationSec = "duration_sec", hasMedia = "has_media"
        case channelKey = "channel_key", url
    }

    init(id: Int64, seq: Int64 = 0, at: String, kind: String, media: String, channel: String,
         show: String = "", person: String, role: String = "", party: String, title: String,
         citedBy: String = "", durationSec: Int = 0, hasMedia: Bool = false, video: Bool = false,
         channelKey: String = "", url: String = "") {
        self.id = id; self.seq = seq; self.at = at; self.kind = kind; self.media = media
        self.channel = channel; self.show = show; self.person = person; self.role = role
        self.party = party; self.title = title; self.citedBy = citedBy
        self.durationSec = durationSec; self.hasMedia = hasMedia; self.video = video
        self.channelKey = channelKey; self.url = url
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        seq = try c.decodeIfPresent(Int64.self, forKey: .seq) ?? 0
        at = try c.decode(String.self, forKey: .at)
        kind = try c.decode(String.self, forKey: .kind)
        media = try c.decode(String.self, forKey: .media)
        channel = try c.decode(String.self, forKey: .channel)
        person = try c.decode(String.self, forKey: .person)
        party = try c.decode(String.self, forKey: .party)
        title = try c.decode(String.self, forKey: .title)
        show = try c.decodeIfPresent(String.self, forKey: .show) ?? ""
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        citedBy = try c.decodeIfPresent(String.self, forKey: .citedBy) ?? ""
        durationSec = try c.decodeIfPresent(Int.self, forKey: .durationSec) ?? 0
        hasMedia = try c.decodeIfPresent(Bool.self, forKey: .hasMedia) ?? false
        video = try c.decodeIfPresent(Bool.self, forKey: .video) ?? false
        channelKey = try c.decodeIfPresent(String.self, forKey: .channelKey) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

struct FeedResponse: Decodable, Sendable {
    let items: [FeedItem]
    let lastSeq: Int64
    enum CodingKeys: String, CodingKey { case items; case lastSeq = "last_seq" }
}

/// A page of `/rest/v1/history`. Its items keep their feed id, but their `seq` is 0: never a live cursor.
struct HistoryResponse: Decodable, Sendable {
    var items: [FeedItem] = []
    var hasMore = false
    enum CodingKeys: String, CodingKey { case items; case hasMore = "has_more" }
    init(items: [FeedItem] = [], hasMore: Bool = false) { self.items = items; self.hasMore = hasMore }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([FeedItem].self, forKey: .items) ?? []
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

/// One complete Paris day of `/rest/v1/days`: every kind is counted, the app adds up the ones it shows.
struct DayCount: Codable, Identifiable, Hashable, Sendable {
    var id: String { day }
    let day: String
    var interventions = 0
    var citations = 0
    var tweets = 0
    var interventionSec = 0
    enum CodingKeys: String, CodingKey {
        case day, interventions, citations, tweets
        case interventionSec = "intervention_sec"
    }
    init(day: String, interventions: Int = 0, citations: Int = 0, tweets: Int = 0, interventionSec: Int = 0) {
        self.day = day; self.interventions = interventions; self.citations = citations
        self.tweets = tweets; self.interventionSec = interventionSec
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        interventions = try c.decodeIfPresent(Int.self, forKey: .interventions) ?? 0
        citations = try c.decodeIfPresent(Int.self, forKey: .citations) ?? 0
        tweets = try c.decodeIfPresent(Int.self, forKey: .tweets) ?? 0
        interventionSec = try c.decodeIfPresent(Int.self, forKey: .interventionSec) ?? 0
    }
    func count(ofKind kind: String) -> Int {
        switch kind {
        case "intervention": interventions
        case "citation": citations
        case "tweet": tweets
        default: 0
        }
    }
    func total(for filters: SearchFilters) -> Int { filters.selectedKinds.reduce(0) { $0 + count(ofKind: $1) } }
}

struct DaysResponse: Decodable, Sendable {
    var days: [DayCount] = []
    enum CodingKeys: String, CodingKey { case days }
    init(days: [DayCount] = []) { self.days = days }
    init(from decoder: Decoder) throws {
        days = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent([DayCount].self, forKey: .days) ?? []
    }
}

struct SequenceDetail: Decodable, Identifiable, Sendable {
    var id: Int64 { item.id }
    let item: FeedItem
    let resume: String
    let verbatim: String
    let playlist: String
    let playFrom: String
    let speechStart: String
    let speechDurationSec: Int

    enum CodingKeys: String, CodingKey {
        case resume, verbatim, playlist
        case playFrom = "play_from", speechStart = "speech_start", speechDurationSec = "speech_duration_sec"
    }
    init(from decoder: Decoder) throws {
        item = try FeedItem(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resume = try c.decodeIfPresent(String.self, forKey: .resume) ?? ""
        verbatim = try c.decodeIfPresent(String.self, forKey: .verbatim) ?? ""
        playlist = try c.decodeIfPresent(String.self, forKey: .playlist) ?? ""
        playFrom = try c.decodeIfPresent(String.self, forKey: .playFrom) ?? ""
        speechStart = try c.decodeIfPresent(String.self, forKey: .speechStart) ?? ""
        speechDurationSec = try c.decodeIfPresent(Int.self, forKey: .speechDurationSec) ?? 0
    }
    /// The summary worth showing: nil when empty or when the server only repeats the transcript,
    /// in full or cut short, which it does for some passages.
    var summary: String? {
        func words(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let summary = words(resume)
        guard !summary.isEmpty, !words(verbatim).hasPrefix(summary) else { return nil }
        return resume
    }
    init(item: FeedItem, resume: String, verbatim: String, playlist: String = "", playFrom: String = "", speechStart: String = "", speechDurationSec: Int = 0) {
        self.item = item; self.resume = resume; self.verbatim = verbatim; self.playlist = playlist
        self.playFrom = playFrom; self.speechStart = speechStart; self.speechDurationSec = speechDurationSec
    }
}

struct Person: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    var party: String = ""
    var role: String = ""
    enum CodingKeys: String, CodingKey { case name, party, role }
    init(name: String, party: String = "", role: String = "") { self.name = name; self.party = party; self.role = role }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        party = try c.decodeIfPresent(String.self, forKey: .party) ?? ""
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
    }
}
struct Party: Codable, Identifiable, Hashable, Sendable {
    var id: String { code }
    let code: String
    let name: String
}
struct DeviceInfo: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String?
    let model: String?
    let registeredAt: String?
    let lastSeen: String?
    enum CodingKeys: String, CodingKey {
        case id, name, model
        case registeredAt = "registered_at", lastSeen = "last_seen"
    }
}
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
    let deviceUid: String
    let deviceName: String
    let deviceModel: String
    var replaceDeviceId: Int64?
    enum CodingKeys: String, CodingKey {
        case email, password
        case deviceUid = "device_uid", deviceName = "device_name", deviceModel = "device_model", replaceDeviceId = "replace_device_id"
    }
}
struct Session: Codable, Sendable {
    let token: String
    let email: String
    let fullname: String?
    let organisation: String?
    let expires: Int64
    let deviceId: Int64?
    enum CodingKeys: String, CodingKey {
        case token, email, fullname, organisation, expires
        case deviceId = "device_id"
    }
}
struct DeviceQuotaResponse: Decodable, Sendable {
    // Only decode fields needed by the transfer UI. `error` is a boolean on HLS Test.
    let maxDevices: Int
    let devices: [DeviceInfo]
    enum CodingKeys: String, CodingKey { case devices; case maxDevices = "max_devices" }
}

enum APIDate {
    static func parse(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
    static func string(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
}
