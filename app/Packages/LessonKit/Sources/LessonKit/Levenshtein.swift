import Foundation

/// Returns the Levenshtein distance between `a` and `b`, but short-circuits to
/// `Int.max` as soon as it can prove the distance exceeds `k`.
public enum Levenshtein {
    public static func atMost(_ a: String, _ b: String, k: Int) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if abs(m - n) > k { return Int.max }
        if m == 0 { return n <= k ? n : Int.max }
        if n == 0 { return m <= k ? m : Int.max }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
                if curr[j] < rowMin { rowMin = curr[j] }
            }
            if rowMin > k { return Int.max }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    /// Case-insensitive, whitespace-trimmed check for "is within k edits".
    public static func isWithin(_ a: String, _ b: String, k: Int) -> Bool {
        let normA = a.trimmingCharacters(in: .whitespaces).lowercased()
        let normB = b.trimmingCharacters(in: .whitespaces).lowercased()
        return atMost(normA, normB, k: k) <= k
    }
}
