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
        app.launchArguments = ["--uitesting", "--reset-demo"]
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
        app.navigationBars.buttons.element(boundBy: 0).tap()
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

        app.terminate(); app.launchArguments = ["--uitesting", "--demo"]; app.launch()
        app.tabBars.buttons["Recherches"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 5))
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Archiver"].tap()
        app.segmentedControls.buttons["Archivées"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].exists)
        app.buttons["restore-search-\(name)"].tap()
        app.segmentedControls.buttons["Actives"].tap()
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Supprimer"].tap()
        app.alerts.buttons["Supprimer"].tap()
        XCTAssertFalse(app.staticTexts[String(name)].exists)

        app.tabBars.buttons["Le fil"].tap()
        let first = app.buttons["feed-item-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        first.tap()
        capture("03-sequence-avant-lecture", app: app)
        XCTAssertTrue(app.buttons["play-sequence"].waitForExistence(timeout: 5))
        app.buttons["play-sequence"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        capture("03-sequence", app: app)
        reveal(app.buttons["player-toggle"], in: app, down: true)
        app.buttons["player-toggle"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Lecture")
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
        app.terminate()
        app.launchArguments = ["--uitesting", "--demo", "-appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["start-podcast"].waitForExistence(timeout: 10))
        capture("06-texte-accessible", app: app)
    }

    @MainActor
    func testLoginFormAndEmptyFilters() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login-submit"].isEnabled)
        capture("00-connexion", app: app)
        if !app.buttons["enter-demo"].isHittable { app.swipeUp() }
        app.buttons["enter-demo"].tap()
        app.buttons["Interventions"].tap()
        app.buttons["Citations"].tap()
        XCTAssertTrue(app.staticTexts["Aucun type sélectionné"].waitForExistence(timeout: 3))
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
        let toggle = app.buttons["transcript-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        wait(toggle, key: "label", equals: "Mettre le verbatim en pause")
        toggle.tap()
        wait(toggle, key: "label", equals: "Reprendre la lecture du verbatim")
        app.links["retrouverez"].tap()
        let status = app.staticTexts["transcript-position"]
        wait(status, key: "label", equals: "Mot 19 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:07")
        XCTAssertEqual(toggle.label, "Reprendre la lecture du verbatim")
        capture("07-verbatim-clic-en-pause", app: app)

        // Reverse direction: AVPlayer's slider drives the highlighted word while paused.
        let slider = app.sliders["player-position"]
        reveal(slider, in: app, down: true)
        slider.adjust(toNormalizedSliderPosition: 0.25)
        capture("07-curseur-apres-deplacement", app: app)
        XCTAssertEqual(app.buttons["player-toggle"].label, "Lecture")
        let elapsed = app.staticTexts["player-elapsed"].label
        let seconds = Int(elapsed.split(separator: ":").last ?? "") ?? -1
        // XCTest's normalized slider adjustment is approximate (thumb/track geometry).
        // Check the actual displayed media position against the highlighted word.
        XCTAssertTrue((2...6).contains(seconds), "Position après glissement : \(elapsed), curseur : \(slider.value ?? "nil")")
        reveal(toggle, in: app, down: false)
        let word = Int(status.label.split(separator: " ").dropFirst().first ?? "") ?? -1
        let firstPossibleWord = Int(Double(seconds) / 18 * 41) + 1
        let lastPossibleWord = Int(Double(seconds + 1) / 18 * 41) + 1
        XCTAssertTrue((firstPossibleWord...lastPossibleWord).contains(word), "Mot après glissement : \(status.label), position : \(elapsed)")

        let before = status.label
        toggle.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
        toggle.tap()
        let follow = app.buttons["transcript-follow"]
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
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Mot 9 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:03")
        reveal(app.buttons["player-next"], in: app, down: true)
        app.buttons["player-next"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-toggle"].tap()
        reveal(app.links["passage"], in: app, down: false)
        app.links["passage"].tap()
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Mot 9 sur 41")
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
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Mot 19 sur 41")
        // The fixture puts this word at 12s; uniform estimation would yield 7.9s.
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:12")
        XCTAssertTrue(app.staticTexts["transcript-precise"].exists)
        XCTAssertFalse(app.staticTexts["transcript-estimated"].exists)
        capture("10-verbatim-horodatages-api", app: app)
        reveal(app.buttons["Reculer de 10 secondes"], in: app, down: true)
        app.buttons["Reculer de 10 secondes"].tap()
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:02")
        XCTAssertEqual(app.buttons["player-toggle"].label, "Lecture")
        reveal(app.buttons["transcript-toggle"], in: app, down: false)
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Aucun mot actif")
        reveal(app.buttons["Avancer de 10 secondes"], in: app, down: true)
        app.buttons["Avancer de 10 secondes"].tap()
        reveal(app.buttons["transcript-toggle"], in: app, down: false)
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Mot 19 sur 41")
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
        wait(app.staticTexts["transcript-position"], key: "label", equals: "Mot 19 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:12")
        XCTAssertTrue(app.staticTexts["transcript-precise"].exists)
        capture("11-podcast-horodatages-api", app: app)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, down: Bool) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            // Drag the outer page margin, away from the transcript's own scroll view.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.25 : 0.75))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: down ? 0.8 : 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
