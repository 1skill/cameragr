import Foundation
import Security

/// The community over the network: the Cloudflare Worker at
/// `CommunityConfig.apiBase` (project/community-api.md). The session token
/// lives in the Keychain, this device only.
actor RemoteCommunityClient: CommunityClient {
    let base: URL
    private let session: URLSession
    private var token: String? = SessionToken.read()

    init(base: URL, session: URLSession = .shared) {
        self.base = base
        self.session = session
    }

    var isSignedIn: Bool { token != nil }

    // MARK: Account

    func signIn(_ apple: Community.AppleCredential) async throws -> Community.Me {
        struct Body: Encodable { let identityToken, authorizationCode, nonce: String; let name: String? }
        struct Reply: Decodable { let token: String; let user: Community.Me }
        let reply: Reply = try await send("POST", "v1/auth/apple",
            body: Body(identityToken: apple.identityToken, authorizationCode: apple.authorizationCode,
                       nonce: apple.nonce, name: apple.name), signed: false)
        token = reply.token
        SessionToken.write(reply.token)
        return reply.user
    }

    func me() async throws -> Community.Me { try await send("GET", "v1/me") }

    func signOut() async {
        _ = try? await sendEmpty("POST", "v1/auth/signout")
        forget()
    }

    func deleteAccount() async throws {
        try await sendEmpty("DELETE", "v1/me")
        forget()
    }

    private func forget() {
        token = nil
        SessionToken.write(nil)
    }

    // MARK: Reading

    func themes(at date: Date) async throws -> [Community.Theme] {
        try await send("GET", "v1/themes", query: ["at": Self.iso.string(from: date)], signed: false)
    }

    func posts(theme: String, cursor: String?) async throws -> (posts: [Community.Post], next: String?) {
        struct Page: Decodable { let posts: [Community.Post]; let next: String? }
        var query = ["limit": "30"]
        if let cursor { query["cursor"] = cursor }
        let page: Page = try await send("GET", "v1/themes/\(Self.segment(theme))/posts", query: query)
        return (page.posts, page.next)
    }

    // MARK: Writing

    /// Upload first (both pictures into private storage), then the post. The
    /// `clientID` stays the same across retries, so a retry never posts twice.
    func post(theme: String, photo: Data, thumb: Data, film: String, caption: String?, takenAt: Date?, clientID: String) async throws -> Community.Post {
        struct Upload: Decodable { let uploadId: String }
        let up: Upload = try await send("POST", "v1/uploads", body: [String: String]())
        try await sendEmpty("PUT", "v1/uploads/\(up.uploadId)/photo", raw: photo)
        try await sendEmpty("PUT", "v1/uploads/\(up.uploadId)/thumb", raw: thumb)
        struct Body: Encodable { let themeId, uploadId, filmId, clientId: String; let caption, takenAt: String? }
        return try await send("POST", "v1/posts", body: Body(
            themeId: theme, uploadId: up.uploadId, filmId: film, clientId: clientID,
            caption: caption, takenAt: takenAt.map { Self.iso.string(from: $0) }))
    }

    func delete(post: String) async throws { try await sendEmpty("DELETE", "v1/posts/\(Self.segment(post))") }

    func setLike(_ liked: Bool, post: String) async throws -> (likeCount: Int, liked: Bool) {
        struct Reply: Decodable { let likeCount: Int; let liked: Bool }
        let r: Reply = try await send(liked ? "PUT" : "DELETE", "v1/posts/\(Self.segment(post))/like")
        return (r.likeCount, r.liked)
    }

    func report(post: String, reason: Community.ReportReason, note: String?) async throws {
        struct Body: Encodable { let reason: String; let note: String? }
        try await sendEmpty("POST", "v1/posts/\(Self.segment(post))/report", body: Body(reason: reason.rawValue, note: note))
    }

    func setBlocked(_ blocked: Bool, user: String) async throws {
        try await sendEmpty(blocked ? "PUT" : "DELETE", "v1/blocks/\(Self.segment(user))")
    }

    func claimReward(milestone: Int) async throws -> String {
        struct Reply: Decodable { let filmId: String }
        let r: Reply = try await send("POST", "v1/rewards/\(milestone)/claim", body: [String: String]())
        return r.filmId
    }

    // MARK: Moderation

    func adminQueue() async throws -> [Community.Post] { try await send("GET", "v1/admin/queue") }
    func adminReports() async throws -> [Community.ReportedPost] { try await send("GET", "v1/admin/reports") }
    func adminHidden() async throws -> [Community.Post] { try await send("GET", "v1/admin/hidden") }
    func adminAlerts() async throws -> [Community.Alert] {
        struct Row: Decodable { let kind, text: String; let created_at: Date }
        let rows: [Row] = try await send("GET", "v1/admin/alerts")
        return rows.map { .init(kind: $0.kind, text: $0.text, createdAt: $0.created_at) }
    }
    func moderate(post: String, _ action: Community.ModAction, reason: String?) async throws {
        try await sendEmpty("POST", "v1/admin/posts/\(Self.segment(post))/\(action.rawValue)", body: ["reason": reason])
    }
    func setBanned(_ banned: Bool, user: String, reason: String?) async throws {
        try await sendEmpty("POST", "v1/admin/users/\(Self.segment(user))/\(banned ? "ban" : "unban")", body: ["reason": reason])
    }
    func markHandled(report: Int) async throws {
        try await sendEmpty("POST", "v1/admin/reports/\(report)/handled", body: [String: String]())
    }

    // MARK: Plumbing

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func segment(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? s
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            if let date = iso.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "date \(text)"))
        }
        return d
    }()

    private func request(_ method: String, _ path: String, query: [String: String], signed: Bool) throws -> URLRequest {
        var parts = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: parts.url!)
        r.httpMethod = method
        r.timeoutInterval = 30
        r.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Koco-TZ")
        if signed {
            guard let token else { throw Community.Failure.signedOut }
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return r
    }

    private func perform(_ r: URLRequest) async throws -> Data {
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: r) } catch { throw Community.Failure.network }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status) { return data }
        let code = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
        Diag.note("community \(r.httpMethod ?? "") \(r.url?.path ?? "") → \(status) \(code ?? "")")
        switch (status, code) {
        case (401, _), (403, "banned"):
            if status == 401 { forget() }
            throw Community.Failure.signedOut
        case (409, "theme-closed"): throw Community.Failure.themeClosed
        case (422, _): throw Community.Failure.words
        case (409, "not-yet"): throw Community.Failure.notYet
        default: throw Community.Failure.server(status)
        }
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], signed: Bool = true) async throws -> T {
        let data = try await perform(try request(method, path, query: query, signed: signed))
        do { return try Self.decoder.decode(T.self, from: data) } catch {
            Diag.note("community decode \(path): \(error)")
            throw Community.Failure.server(0)
        }
    }

    private func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B, signed: Bool = true) async throws -> T {
        var r = try request(method, path, query: [:], signed: signed)
        r.httpBody = try JSONEncoder().encode(body)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try await perform(r)
        do { return try Self.decoder.decode(T.self, from: data) } catch {
            Diag.note("community decode \(path): \(error)")
            throw Community.Failure.server(0)
        }
    }

    private func sendEmpty(_ method: String, _ path: String) async throws {
        _ = try await perform(try request(method, path, query: [:], signed: true))
    }

    private func sendEmpty<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        var r = try request(method, path, query: [:], signed: true)
        r.httpBody = try JSONEncoder().encode(body)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await perform(r)
    }

    private func sendEmpty(_ method: String, _ path: String, raw: Data) async throws {
        var r = try request(method, path, query: [:], signed: true)
        r.httpBody = raw
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = 90
        _ = try await perform(r)
    }
}

/// The community session token, in the Keychain (this device only, after
/// first unlock).
enum SessionToken {
    private static let account = "community-session"
    private static let service = "com.oneskill.cameragr.community"

    static func read() -> String? {
        var out: CFTypeRef?
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ token: String?) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard let token else { return }
        var add = q
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
