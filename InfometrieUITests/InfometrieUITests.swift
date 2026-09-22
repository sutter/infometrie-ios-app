import XCTest

final class InfometrieUITests: XCTestCase {
    @MainActor
    func testLoginCallsAPIStoresSessionAndRestoresAfterRelaunch() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "valide")
        XCTAssertTrue(app.buttons["feed-item-901"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts["demo-banner"].exists)
        app.tabBars.buttons["Compte"].tap()
        XCTAssertTrue(app.staticTexts["Compte de test API"].exists)
        XCTAssertTrue(app.staticTexts["connexion@example.invalid"].exists)
        capture("12-compte-connecte-api", app: app)

        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["feed-item-901"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["login-email"].exists)
        app.tabBars.buttons["Compte"].tap()
        reveal(app.buttons["logout"], in: app, down: false)
        app.buttons["logout"].tap()
        app.sheets["Se déconnecter ?"].buttons["Se déconnecter"].tap()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Le fil"].exists)
    }

    @MainActor
    func testLoginDisplaysAPIErrorsAndAllowsRetry() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "invalide")
        XCTAssertTrue(app.staticTexts["Email ou mot de passe invalide."].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["login-submit"].isEnabled)
        XCTAssertFalse(app.tabBars.buttons["Le fil"].exists)

        submitLogin(in: app, password: "inactif", replacing: "invalide")
        XCTAssertTrue(app.staticTexts["Votre abonnement n’est pas actif. Gérez votre compte sur le portail web InfoMétrie."].waitForExistence(timeout: 5))
        submitLogin(in: app, password: "hors-ligne", replacing: "inactif")
        XCTAssertTrue(app.staticTexts["Serveur injoignable. Vérifiez votre connexion puis réessayez."].waitForExistence(timeout: 5))
        submitLogin(in: app, password: "valide", replacing: "hors-ligne")
        XCTAssertTrue(app.buttons["feed-item-901"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLoginDeviceQuotaRequiresConfirmationThenAuthenticates() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "quota")
        XCTAssertTrue(app.navigationBars["Limite d’appareils"].waitForExistence(timeout: 5), app.debugDescription)
        capture("13-limite-appareils-api", app: app)
        XCTAssertFalse(app.tabBars.buttons["Le fil"].exists)
        app.buttons.containing(.staticText, identifier: "Ancien iPhone").firstMatch.tap()
        XCTAssertTrue(app.buttons["Remplacer cet appareil"].waitForExistence(timeout: 5))
        app.buttons["Remplacer cet appareil"].tap()
        XCTAssertTrue(app.buttons["feed-item-901"].waitForExistence(timeout: 10))
    }

    @MainActor private func loginTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-appearance", "light"]
        // The actual Keychain is exercised under a unique service, never the user's session.
        app.launchEnvironment["INFOMETRIE_LOGIN_TEST_ID"] = UUID().uuidString
        return app
    }

    @MainActor private func submitLogin(in app: XCUIApplication, password: String, replacing oldPassword: String? = nil) {
        let email = app.textFields["login-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        if oldPassword == nil {
            reveal(email, in: app, down: false)
            email.tap(); email.typeText("  Connexion@Example.Invalid  \n")
        } else {
            app.secureTextFields["login-password"].tap()
        }
        let field = app.secureTextFields["login-password"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if let oldPassword { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldPassword.count)) }
        field.typeText(password)
        // Test the visible button, not just the keyboard's submit action.
        app.swipeUp()
        let submit = app.buttons["login-submit"]
        reveal(submit, in: app, down: false)
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
    }

    @MainActor
    func testDemoSearchPersistenceSequenceAndPodcast() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-demo", "-appearance", "light"]
        app.launch()
        let demo = app.buttons["enter-demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 10))
        if !demo.isHittable { app.swipeUp() }
        demo.tap()
        XCTAssertTrue(app.staticTexts["demo-banner"].waitForExistence(timeout: 8))
        capture("01-fil", app: app)

        app.buttons["edit-filters"].tap()
        app.buttons["pick-persons"].tap()
        app.buttons["choice-Camille Martin"].tap()
        app.buttons["confirm-choices"].tap()
        capture("02-filtres", app: app)
        let save = app.buttons["save-search"]
        if !save.isHittable { app.swipeUp() }
        save.tap()
        let field = app.textFields["search-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let name = "Veille test " + UUID().uuidString.prefix(6)
        field.tap(); field.typeText(String(name))
        app.buttons["confirm-save-search"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 4))
        capture("02-recherches", app: app)
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Ajuster les filtres"].tap()
        reveal(app.buttons["save-search"], in: app, down: false)
        app.buttons["save-search"].tap()
        app.navigationBars["Enregistrer un suivi"].buttons["Annuler"].tap()
        XCTAssertTrue(app.navigationBars["Filtrer le fil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["apply-search"].isHittable)
        app.navigationBars["Filtrer le fil"].buttons["Annuler"].tap()

        app.terminate(); app.launchArguments = ["--uitesting", "--demo", "-appearance", "light"]; app.launch()
        app.tabBars.buttons["Mes suivis"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 5))
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Archiver"].tap()
        app.buttons["saved-archived"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].exists)
        app.buttons["restore-search-\(name)"].tap()
        app.buttons["saved-active"].tap()
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Supprimer"].tap()
        app.alerts.buttons["Supprimer"].tap()
        XCTAssertFalse(app.staticTexts[String(name)].exists)

        app.tabBars.buttons["Le fil"].tap()
        let first = app.buttons["feed-item-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        first.tap()
        XCTAssertTrue(app.buttons["play-sequence"].waitForExistence(timeout: 5))
        capture("03-sequence-avant-lecture", app: app)
        let summary = app.buttons["sequence-summary"]
        reveal(summary, in: app, down: false)
        summary.tap()
        XCTAssertTrue(app.buttons["play-sequence"].exists, "Déplier le résumé ne doit pas démarrer l’écoute")
        XCTAssertTrue(app.staticTexts["Exemple fictif pour découvrir la consultation d’une séquence. Aucun propos réel ni passage à l’antenne n’est représenté ici."].waitForExistence(timeout: 3))
        capture("03-sequence-resume", app: app)
        reveal(summary, in: app, down: false)
        summary.tap()
        let context = app.buttons["sequence-context"]
        reveal(context, in: app, down: false)
        context.tap()
        XCTAssertTrue(app.buttons["play-sequence"].exists, "Le contexte s’ouvre indépendamment du lecteur")
        XCTAssertTrue(app.staticTexts["Personnalité fictive"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.45)))
        capture("03-sequence-contexte", app: app)
        reveal(context, in: app, down: false)
        context.tap()
        reveal(app.staticTexts["sequence-title"], in: app, down: true)
        app.buttons["play-sequence"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        capture("03-sequence", app: app)
        reveal(app.buttons["player-toggle"], in: app, down: true)
        app.buttons["player-toggle"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Écouter")
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Le fil"].waitForExistence(timeout: 5))
        reveal(app.buttons["start-podcast"], in: app, down: true)
        app.buttons["start-podcast"].tap()
        XCTAssertTrue(app.buttons["close-podcast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-next"].tap()
        capture("04-podcast", app: app)
        app.buttons["close-podcast"].tap()

        app.tabBars.buttons["Compte"].tap()
        for _ in 0..<3 {
            if app.buttons["logout"].exists && app.buttons["logout"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["logout"].tap()
        XCTAssertTrue(app.buttons["enter-demo"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDarkAppearanceAndLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo", "-appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.staticTexts["demo-banner"].waitForExistence(timeout: 10))
        capture("05-fil-sombre", app: app)
        app.buttons["feed-item-1"].tap()
        XCTAssertTrue(app.buttons["play-sequence"].waitForExistence(timeout: 5))
        capture("05-sequence-sombre", app: app)
        app.buttons["play-sequence"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Pause")
        app.buttons["player-toggle"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Écouter")
        capture("05-sequence-ecoute-sombre", app: app)
        app.terminate()
        app.launchArguments = ["--uitesting", "--demo", "-appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["start-podcast"].waitForExistence(timeout: 10))
        capture("06-texte-accessible", app: app)
        let first = app.buttons["feed-item-1"]
        reveal(first, in: app, down: false)
        // Inspect the card itself, including its action, beyond the large-text header.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.82))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.30)))
        capture("06-carte-texte-accessible", app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.48)))
        capture("06-carte-action-accessible", app: app)
        XCTAssertTrue(first.isHittable)
        first.tap()
        let play = app.buttons["play-sequence"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(play.isHittable)
        XCTAssertGreaterThanOrEqual(play.frame.height, 52)
        play.tap()
        let toggle = app.buttons["player-toggle"]
        wait(toggle, key: "label", equals: "Pause")
        toggle.tap()
        let word = app.links["Cette"]
        reveal(word, in: app, down: false)
        XCTAssertTrue(word.isHittable)
        word.tap()
        wait(app.staticTexts["player-elapsed"], key: "label", equals: "0:00")
        XCTAssertTrue(toggle.isHittable, "La commande reste accessible pendant la lecture du texte")
        XCTAssertTrue(app.buttons["Reculer de 10 secondes"].isHittable)
        XCTAssertTrue(app.buttons["Avancer de 10 secondes"].isHittable)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 52)
        XCTAssertLessThanOrEqual(toggle.frame.maxX, app.frame.maxX)
        capture("06-lecture-texte-accessible", app: app)

    }

    @MainActor
    func testLoginFormAndEmptyFilters() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "-appearance", "light"]; app.launch()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login-submit"].isEnabled)
        capture("00-connexion", app: app)
        if !app.buttons["enter-demo"].isHittable { app.swipeUp() }
        app.buttons["enter-demo"].tap()
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertTrue(app.buttons["feed-item-1"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["edit-filters"].frame.height, 52)
        app.buttons["edit-filters"].tap()
        app.buttons["filter-kind-2"].tap()
        app.buttons["apply-search"].tap()
        XCTAssertTrue(app.staticTexts["Citations uniquement"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-1"].exists)
        app.buttons["clear-filters"].tap()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 5))
        // Cancelling the sheet must leave the applied criteria unchanged.
        app.buttons["edit-filters"].tap()
        app.buttons["filter-kind-1"].tap()
        app.buttons["Annuler"].tap()
        XCTAssertFalse(app.buttons["clear-filters"].exists)
        try auditVisibleFeed(app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.70))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.40)))
        try auditVisibleFeed(app)
        capture("14-fil-contraste", app: app)

    }

    @MainActor
    func testTranscriptSeeksPlayerAndFollowsScrubbingWhilePaused() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo", "--reset-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        reveal(app.links["passage"], in: app, down: false)
        XCTAssertTrue(app.links["passage"].isHittable, app.debugDescription)
        // Starting from the text must preserve the requested word through HLS loading.
        app.links["passage"].tap()
        let toggle = app.buttons["player-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        wait(toggle, key: "label", equals: "Pause")
        toggle.tap()
        wait(toggle, key: "label", equals: "Écouter")
        app.links["retrouverez"].tap()
        let status = app.staticTexts["transcript-position"]
        wait(status, key: "value", equals: "Mot 19 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:07")
        XCTAssertEqual(toggle.label, "Écouter")
        capture("07-verbatim-clic-en-pause", app: app)

        // Reverse direction: AVPlayer's slider drives the highlighted word while paused.
        let slider = app.sliders["player-position"]
        reveal(slider, in: app, down: true)
        slider.adjust(toNormalizedSliderPosition: 0.25)
        capture("07-curseur-apres-deplacement", app: app)
        XCTAssertEqual(app.buttons["player-toggle"].label, "Écouter")
        let elapsed = app.staticTexts["player-elapsed"].label
        let seconds = Int(elapsed.split(separator: ":").last ?? "") ?? -1
        // XCTest's normalized slider adjustment is approximate (thumb/track geometry).
        // Check the actual displayed media position against the highlighted word.
        XCTAssertTrue((2...6).contains(seconds), "Position après glissement : \(elapsed), curseur : \(slider.value ?? "nil")")
        reveal(toggle, in: app, down: false)
        let word = Int((status.value as? String ?? "").split(separator: " ").dropFirst().first ?? "") ?? -1
        let firstPossibleWord = Int(Double(seconds) / 18 * 41) + 1
        let lastPossibleWord = Int(Double(seconds + 1) / 18 * 41) + 1
        XCTAssertTrue((firstPossibleWord...lastPossibleWord).contains(word), "Mot après glissement : \(status.value ?? ""), position : \(elapsed)")

        let before = status.value as? String ?? ""
        toggle.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
        toggle.tap()
        let follow = app.buttons["transcript-follow"]
        reveal(follow, in: app, down: false)
        follow.tap()
        XCTAssertEqual(follow.value as? String, "Désactivé")
        follow.tap()
        XCTAssertEqual(follow.value as? String, "Activé")
        capture("08-verbatim-suivi-lecteur", app: app)
    }

    @MainActor
    func testPodcastTranscriptUsesCurrentSequenceAndResetsOnNext() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo", "--reset-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["start-podcast"].waitForExistence(timeout: 10))
        app.buttons["start-podcast"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-toggle"].tap()
        reveal(app.links["passage"], in: app, down: false)
        app.links["passage"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 9 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:03")
        reveal(app.buttons["player-next"], in: app, down: true)
        app.buttons["player-next"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-toggle"].tap()
        reveal(app.links["passage"], in: app, down: false)
        app.links["passage"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 9 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:03")
        capture("09-podcast-verbatim", app: app)
    }

    @MainActor private func wait(_ element: XCUIElement, key: String, equals value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", key, value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    @MainActor
    func testPreciseAPITimingsSeekToTwelveSecondsAndLeaveSilencesUnhighlighted() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo", "--precise-word-timings", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        app.buttons["play-sequence"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-toggle"].tap()
        reveal(app.links["retrouverez"], in: app, down: false)
        app.links["retrouverez"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 19 sur 41")
        // The fixture puts this word at 12s; uniform estimation would yield 7.9s.
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:12")
        XCTAssertTrue(app.staticTexts["transcript-precise"].exists)
        XCTAssertFalse(app.staticTexts["transcript-estimated"].exists)
        capture("10-verbatim-horodatages-api", app: app)
        reveal(app.buttons["Reculer de 10 secondes"], in: app, down: true)
        app.buttons["Reculer de 10 secondes"].tap()
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:02")
        XCTAssertEqual(app.buttons["player-toggle"].label, "Écouter")
        reveal(app.buttons["player-toggle"], in: app, down: false)
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Aucun mot actif")
        reveal(app.buttons["Avancer de 10 secondes"], in: app, down: true)
        app.buttons["Avancer de 10 secondes"].tap()
        reveal(app.buttons["player-toggle"], in: app, down: false)
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 19 sur 41")
    }

    @MainActor
    func testPodcastUsesPreciseAPITimingsAfterChangingSequence() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo", "--precise-word-timings", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["start-podcast"].waitForExistence(timeout: 10))
        app.buttons["start-podcast"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-next"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-toggle"].tap()
        reveal(app.links["retrouverez"], in: app, down: false)
        app.links["retrouverez"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 19 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:12")
        XCTAssertTrue(app.staticTexts["transcript-precise"].exists)
        capture("11-podcast-horodatages-api", app: app)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, down: Bool) {
        for _ in 0..<8 {
            // Keep gestures inside the content above the persistent playback dock,
            // including at the largest accessibility size, where it is taller.
            let bounds = app.frame
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY + 12 : bounds.minY + 100
            let slider = app.sliders["player-position"]
            let bottom = slider.exists ? slider.frame.minY - 12 : bounds.maxY - 150
            if element.exists && element.isHittable {
                let contentControl = ["sequence-summary", "sequence-context", "transcript-follow"].contains(element.identifier)
                if element.elementType != .link && !contentControl { return }
                // XCTest may report content controls as hittable underneath the
                // dock. Expose the complete word or disclosure/follow control.
                if element.frame.minY >= top && element.frame.maxY <= bottom { return }
            }
            let upper = top + (bottom - top) * 0.15
            let lower = top + (bottom - top) * 0.85
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: bounds.width - 8, dy: down ? upper : lower))
            let end = origin.withOffset(CGVector(dx: bounds.width - 8, dy: down ? lower : upper))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

    }

    @MainActor private func auditVisibleFeed(_ app: XCUIApplication) throws {
        var covered: [String] = []
        let tabBar = app.tabBars.firstMatch.frame
        let navigationBar = app.navigationBars.firstMatch.frame
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed-item-")).allElementsBoundByIndex.map(\.frame)
        let readingArea = CGRect(x: app.frame.minX, y: navigationBar.maxY, width: app.frame.width, height: tabBar.minY - navigationBar.maxY)
        XCTAssertTrue(cards.contains { readingArea.contains($0) }, "Au moins une carte complète doit être contrôlée")
        let coveredCards = cards.filter { !readingArea.contains($0) }
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion]) { issue in
            // XCTest also inspects content physically covered by native navigation.
            // Only fully exposed cards are in scope. A partially covered card can
            // trigger contrast findings near Liquid Glass; the next audit checks
            // that card after scrolling it fully into the reading area.
            guard issue.auditType == .contrast, let element = issue.element, element.exists else { return false }
            let frame = element.frame
            let isCovered = !readingArea.contains(frame)
                || coveredCards.contains { $0.contains(frame) }
            if isCovered { covered.append("\(element.label) — \(frame)") }
            return isCovered
        }
        if !covered.isEmpty {
            let attachment = XCTAttachment(string: "Contraste hors zone de lecture (barres natives / hors écran) :\n" + covered.joined(separator: "\n"))
            attachment.name = "Portée du contrôle de contraste"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
