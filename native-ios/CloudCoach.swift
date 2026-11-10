import Foundation
import Security
import SwiftUI

enum CloudCoach {
    static let service = "com.steveypugs.brickbybrick.cloud-coach"
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "cloudCoachConsent") }
    static var endpoint: String { UserDefaults.standard.string(forKey: "cloudCoachEndpoint") ?? "" }
    static func token() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "trial",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func saveToken(_ token: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "trial"]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(token.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = Data(token.utf8)
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw Failure.message("Could not save the trial access token securely.") }
        } else if status != errSecSuccess { throw Failure.message("Could not update the trial access token.") }
    }
    static func validURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", let host = url.host,
              host.hasSuffix(".netlify.app"), url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil,
              url.path == "" || url.path == "/" else { return nil }
        return url.appendingPathComponent(".netlify/functions/coach")
    }
    enum Failure: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
    }
    struct Message: Encodable { let role: String; let content: String }
    struct RequestBody: Encodable { let mode: String; let goal: String; let context: String; let messages: [Message] }
    struct Reply: Decodable { let reply: String; let memory: String; let status: String; let outcome: String }
    struct Plan: Decodable { let bricks: [Brick] }
    struct Brick: Decodable { let title: String; let purpose: String; let finish: String }

    static func request<T: Decodable>(_ type: T.Type, goal: GuidedGoal, brick: GoalBrick?, mode: String) async throws -> T {
        guard enabled, let url = validURL(endpoint), let secret = token(), secret.count >= 32 else {
            throw Failure.message("Set up Cloud AI and consent to sending conversation context before continuing.")
        }
        var messages = (brick?.messages ?? goal.discovery).map { Message(role: $0.isUser ? "user" : "assistant", content: $0.text) }
        if messages.last?.role != "user" {
            messages.append(Message(role: "user", content: mode == "plan" ? "Draft my path using our decisions." : "Start this brick using my earlier decisions."))
        }
        var context = "Discovery notes: \(goal.memory)"
        if let brick = brick {
            context += "\nCurrent brick: \(brick.title)\nPurpose: \(brick.purpose)\nFinish: \(brick.finish)\nNotes: \(brick.memory)"
            for earlier in goal.bricks.prefix(while: { $0.id != brick.id }) where earlier.completed {
                context += "\nEarlier outcome — \(earlier.title): \(earlier.outcome)"
            }
        }
        let body = try JSONEncoder().encode(RequestBody(mode: mode, goal: goal.title, context: context, messages: messages))
        guard body.count <= 32000, messages.count <= 100, context.count <= 8000 else {
            throw Failure.message("This conversation is too long for the trial. Your messages are saved; nothing was silently removed or sent.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.httpBody = body; request.timeoutInterval = 55
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        // Ephemeral session and no redirects: never forward the trial credential to another host.
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.message("No server response. Your chat is saved.") }
        guard http.statusCode == 200 else {
            let text: String
            switch http.statusCode {
            case 401: text = "The trial access token was not accepted. Check Cloud AI settings."
            case 429: text = "The trial allowance is used up. Your chats are saved; no further AI requests will be charged through this service."
            case 400, 413: text = "The conversation could not be sent within the trial limits. Your chat is saved."
            default: text = "Cloud AI is unavailable or not enabled yet. Your chat is saved. Try again later."
            }
            throw Failure.message(text)
        }
        try Task.checkCancellation()
        return try JSONDecoder().decode(T.self, from: data)
    }
    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
}

struct CloudCoachSettings: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = CloudCoach.endpoint
    @State private var token = ""
    @State private var consent = CloudCoach.enabled
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Private trial") {
                    Text("Cloud AI sends the current conversation, goal, notes and earlier outcomes through your Netlify backend to OpenAI. Chats remain saved on this phone. Internet is required. Provider retention policies still apply.")
                    TextField("https://your-project.netlify.app", text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Trial access token — NOT your OpenAI key", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Use Cloud AI and send conversation context", isOn: $consent)
                    Text("The OpenAI API key belongs only in Netlify. This field is for a separate private trial token. Turning this off returns to on-device AI.").font(.caption)
                }
                if let error = error { Text(error).foregroundStyle(.red) }
                Button("Save") {
                    do {
                        if consent {
                            guard CloudCoach.validURL(endpoint) != nil else { throw CloudCoach.Failure.message("Enter the HTTPS Netlify project address, without a path.") }
                            if CloudCoach.validURL(endpoint) != CloudCoach.validURL(CloudCoach.endpoint), token.isEmpty {
                                throw CloudCoach.Failure.message("Enter the trial token for this backend address. An existing token won't be sent to a different backend.")
                            }
                            if !token.isEmpty { guard token.count >= 32 else { throw CloudCoach.Failure.message("Use the full trial access token.") }; try CloudCoach.saveToken(token) }
                            guard CloudCoach.token() != nil else { throw CloudCoach.Failure.message("Add your trial access token first.") }
                        }
                        UserDefaults.standard.set(endpoint, forKey: "cloudCoachEndpoint")
                        UserDefaults.standard.set(consent, forKey: "cloudCoachConsent")
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }.navigationTitle("Cloud AI").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
