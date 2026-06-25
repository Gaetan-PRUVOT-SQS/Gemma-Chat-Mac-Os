import Foundation

/// Harnais de tests fonctionnels headless (sans modèle). Lancé avec `--qa`.
/// Valide persistance + tombstone + rendu markdown (régression des correctifs QA).
@MainActor
enum QAHarness {
    nonisolated(unsafe) private static var passed = 0
    nonisolated(unsafe) private static var failed = 0

    static func run() {
        Task { @MainActor in
            await runAll()
            FileHandle.standardError.write("\n== QA: \(passed) PASS / \(failed) FAIL ==\n".data(using: .utf8)!)
            exit(failed == 0 ? 0 : 1)
        }
        RunLoop.main.run()
    }

    private static func check(_ name: String, _ cond: Bool) {
        if cond { passed += 1; log("✅ \(name)") }
        else { failed += 1; log("❌ \(name)") }
    }

    private static func eq(_ name: String, _ a: String, _ b: String) {
        if a == b { passed += 1; log("✅ \(name)") }
        else { failed += 1; log("❌ \(name)  got=[\(a)] expected=[\(b)]") }
    }

    private static func log(_ s: String) {
        FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
    }

    private static func runAll() async {
        await testPersistenceAndTombstone()
        testMessageMapping()
        testMarkdownBlocks()
        testInlineMarkdown()
    }

    // MARK: - Persistance + tombstone (course save/delete)

    private static func testPersistenceAndTombstone() async {
        let store = ConversationStore.shared
        let idA = "qa-A-\(nowMillis())"
        let idB = "qa-B-\(nowMillis())"
        let convA = StoredConversation(id: idA, title: "A", createdAt: 1, updatedAt: 100,
                                       messages: [StoredMessage(role: "user", text: "salut", createdAt: 1)])
        let convB = StoredConversation(id: idB, title: "B", createdAt: 2, updatedAt: 200)

        await store.save(convA)
        await store.save(convB)

        let summaries = await store.listSummaries()
        check("listSummaries contient A et B", summaries.contains { $0.id == idA } && summaries.contains { $0.id == idB })
        // Tri décroissant par updatedAt : B (200) avant A (100)
        let idxA = summaries.firstIndex { $0.id == idA }
        let idxB = summaries.firstIndex { $0.id == idB }
        check("tri updatedAt desc (B avant A)", (idxB ?? 99) < (idxA ?? 99))

        let loadedA = await store.load(idA)
        eq("load round-trip (titre)", loadedA?.title ?? "nil", "A")
        eq("load round-trip (message)", loadedA?.messages.first?.text ?? "nil", "salut")

        await store.delete(idA)
        let afterDelete = await store.load(idA)
        check("delete supprime A", afterDelete == nil)

        // Tombstone : une sauvegarde en vol pour A ne doit PAS recréer le fichier.
        await store.save(convA)
        let resurrected = await store.load(idA)
        check("tombstone empêche la résurrection après delete", resurrected == nil)

        await store.delete(idB)
    }

    // MARK: - Mapping ChatMessage <-> StoredMessage

    private static func testMessageMapping() {
        eq("rôle user → \"user\"", ChatMessage(role: .user, text: "x").stored.role, "user")
        eq("rôle assistant → \"model\"", ChatMessage(role: .assistant, text: "x").stored.role, "model")
        let stored = StoredMessage(role: "model", text: "y", createdAt: 7)
        let back = ChatMessage(stored: stored)
        check("\"model\" → .assistant", back.role == .assistant)
        eq("texte préservé", back.text, "y")
    }

    // MARK: - Découpage en blocs markdown (streaming-safe)

    private static func testMarkdownBlocks() {
        let closed = MarkdownParser.parse("avant\n```swift\nlet x = 1\n```\naprès")
        let hasCode = closed.contains { if case .code = $0 { return true } else { return false } }
        check("fence fermée → bloc .code", hasCode)

        let unclosed = MarkdownParser.parse("texte\n```\nlet x = 1")
        let onlyText = unclosed.allSatisfy { if case .text = $0 { return true } else { return false } }
        check("fence NON fermée (streaming) → uniquement du texte", onlyText)
    }

    // MARK: - Inline markdown (contenu rendu = ce qui s'affiche)

    private static func testInlineMarkdown() {
        func rendered(_ s: String) -> String { String(InlineMarkdown.attributed(s).characters) }
        eq("code inline strip", rendered("`code`"), "code")
        eq("gras strip", rendered("**gras**"), "gras")
        eq("italique strip", rendered("*ital*"), "ital")
        // Régression : marqueur ** non fermé laissé littéral
        eq("** non fermé → littéral", rendered("**gras"), "**gras")
        // Régression : astérisques espacés non transformés en italique
        eq("a * b * c littéral", rendered("a * b * c"), "a * b * c")
        // Robustesse (pas de crash, contenu conservé)
        eq("backtick non fermé", rendered("`x"), "`x")
        eq("étoile seule", rendered("*"), "*")
        eq("chaîne vide", rendered(""), "")
    }
}
