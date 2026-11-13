import Foundation

/// Masks secrets before anything is logged (spec S9): query/fragment values of auth-like keys,
/// and bearer tokens. Typed input values are never sent by `page-events.js` in the first place.
enum LogRedaction {
    private static let keys =
        "code|code_challenge|code_verifier|state|nonce|token|access_token|id_token|refresh_token|auth|authorization|password|passwd|pw|secret|session|sessionid|jwt|ticket|otp"

    private static let keyValue = try! NSRegularExpression(
        pattern: "(?i)(?<=^|[?&#;/\\s\"'{(,]|%3F|%26|%23|%2F)(\(keys))(=|%3D)(?:(?!%26|%23)[^&#\\s\"'<>])+")
    private static let bearer = try! NSRegularExpression(pattern: "(?i)\\bbearer\\s+[A-Za-z0-9._~+/=-]+")

    static func text(_ input: String) -> String {
        var output = input
        output = keyValue.stringByReplacingMatches(
            in: output, range: NSRange(output.startIndex..., in: output), withTemplate: "$1$2***")
        output = bearer.stringByReplacingMatches(
            in: output, range: NSRange(output.startIndex..., in: output), withTemplate: "Bearer ***")
        return output
    }
}
