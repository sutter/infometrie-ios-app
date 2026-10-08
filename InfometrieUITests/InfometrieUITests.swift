import XCTest

final class InfometrieUITests: XCTestCase {
    @MainActor
    func testReadingComfortUpdatesTextImmediatelyAndPersists() {
        let app = XCUIApplication()
        // A system already set to XL is common among the app's readers: S, M and L must still differ.
        app.launchArguments = ["--uitesting", "--signed-in", "-appearance", "light",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"]
        app.launch()
        XCTAssertTrue(navigationButton("Compte", in: app).waitForExistence(timeout: 10))
        navigationButton("Compte", in: app).tap()
        let original = ["S", "M", "L"].first { app.buttons["reading-size-\($0)"].isSelected } ?? "M"
        func setSize(_ value: String) {
            let button = app.buttons["reading-size-\(value)"]
            reveal(button, in: app, down: false)
            button.tap()
            wait(button, key: "selected", equals: true)
        }
        defer { setSize(original) }
        func passageTitleHeight() -> CGFloat {
            navigationButton("Le journal", in: app).tap()
            let first = app.buttons["feed-item-1"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            reveal(first, in: app, down: false)
            first.tap()
            let title = app.staticTexts["sequence-title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            let height = title.frame.height
            app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
            navigationButton("Compte", in: app).tap()
            return height
        }
        var headingHeights: [CGFloat] = []
        var passageHeights: [CGFloat] = []
        for size in ["S", "M", "L"] {
            setSize(size)
            headingHeights.append(app.staticTexts["Apparence"].frame.height)
            passageHeights.append(passageTitleHeight())
            for choice in ["S", "M", "L"] {
                let button = app.buttons["reading-size-\(choice)"]
                XCTAssertEqual(button.isSelected, choice == size)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            }
            capture("22-compte-taille-\(size)", app: app)
        }
        XCTAssertGreaterThan(headingHeights[1], headingHeights[0])
        XCTAssertGreaterThan(headingHeights[2], headingHeights[1])
        XCTAssertGreaterThan(passageHeights[1], passageHeights[0], "Le réglage doit aussi agrandir les fiches")
        XCTAssertGreaterThan(passageHeights[2], passageHeights[1])
        app.terminate(); app.launch()
        XCTAssertTrue(navigationButton("Compte", in: app).waitForExistence(timeout: 10))
        navigationButton("Compte", in: app).tap()
        XCTAssertTrue(app.buttons["reading-size-L"].isSelected, "Le choix doit être conservé après relance")
        XCTAssertEqual(app.staticTexts["Apparence"].frame.height, headingHeights[2], accuracy: 1)
        setSize("M")
        XCTAssertEqual(app.staticTexts["Apparence"].frame.height, headingHeights[1], accuracy: 1)
    }

    @MainActor
    func testReadingSizesRespectSystemAccessibilityAndDarkAppearance() {
        let app = XCUIApplication()
        for accessible in [false, true] {
            app.launchArguments = ["--uitesting", "--signed-in", "-appearance", accessible ? "light" : "dark",
                                   "-UIPreferredContentSizeCategoryName", accessible ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
            app.launch()
            XCTAssertTrue(navigationButton("Compte", in: app).waitForExistence(timeout: 10))
            navigationButton("Compte", in: app).tap()
            let original = ["S", "M", "L"].first { app.buttons["reading-size-\($0)"].isSelected } ?? "M"
            var heights: [CGFloat] = []
            for size in ["S", "M", "L"] {
                let button = app.buttons["reading-size-\(size)"]
                reveal(button, in: app, down: false)
                XCTAssertTrue(button.isHittable)
                button.tap()
                wait(button, key: "selected", equals: true)
                heights.append(app.staticTexts["Apparence"].frame.height)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
                if size == "M" { capture(accessible ? "23-compte-accessibilite" : "23-compte-sombre", app: app) }
            }
            if accessible {
                XCTAssertEqual(heights[0], heights[1], accuracy: 1)
                XCTAssertEqual(heights[1], heights[2], accuracy: 1,
                               "S et M ne doivent pas réduire la taille d’accessibilité système")
            } else {
                XCTAssertLessThan(heights[0], heights[1], "S est plus petit que M à la taille système par défaut")
                XCTAssertLessThan(heights[1], heights[2], "L est plus grand que M à la taille système par défaut")
            }
            let previous = app.buttons["reading-size-\(original)"]
            reveal(previous, in: app, down: false)
            previous.tap()
            app.terminate()
        }
    }

    @MainActor
    func testPublicationsUseServerKindsResetCursorAndHaveNoAudio() {
        let app = loginTestApp()
        app.launchArguments += ["--feed-kinds-fixture"]
        app.launch()
        submitLogin(in: app, password: "valide")
        XCTAssertTrue(results("3 résultats", in: app).waitForExistence(timeout: 10))
        showKinds([3], in: app)
        XCTAssertTrue(app.buttons["feed-item-903"].waitForExistence(timeout: 5))
        XCTAssertTrue(results("1 résultat", in: app).exists)
        XCTAssertFalse(app.buttons["start-podcast"].isEnabled)
        capture("21-fil-publications-x", app: app)
        app.buttons["feed-item-903"].tap()
        XCTAssertTrue(app.staticTexts["publication-text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["open-publication"].exists || app.links["open-publication"].exists)
        XCTAssertFalse(app.buttons["play-sequence"].exists)
        XCTAssertFalse(app.buttons["player-toggle"].exists)
        XCTAssertFalse(app.sliders["player-position"].exists)
        XCTAssertFalse(app.otherElements["transcript-scroll"].exists)
        capture("21-publication-x", app: app)
        app.navigationBars["Publication X"].buttons.element(boundBy: 0).tap()
        for (selection, id) in [(1, 901), (2, 902), (3, 903)] {
            showKinds([selection], in: app)
            XCTAssertTrue(app.buttons["feed-item-\(id)"].waitForExistence(timeout: 5))
            XCTAssertTrue(results("1 résultat", in: app).exists)
        }
        app.buttons["edit-filters"].tap()
        reveal(app.buttons["filter-kind-3"], in: app, down: false)
        XCTAssertTrue(app.buttons["filter-kind-3"].isSelected)
        reveal(app.buttons["save-search"], in: app, down: false)
        app.buttons["save-search"].tap()
        let name = "Publications X " + UUID().uuidString.prefix(6)
        app.textFields["search-name"].tap(); app.textFields["search-name"].typeText(String(name))
        app.buttons["confirm-save-search"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["feed-kind-1"].waitForExistence(timeout: 10))
        navigationButton("Mes suivis", in: app).tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 5))
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Modifier la recherche"].tap()
        reveal(app.buttons["filter-kind-3"], in: app, down: false)
        XCTAssertTrue(app.buttons["filter-kind-3"].isSelected)
        app.buttons["apply-search"].tap()
        XCTAssertTrue(app.buttons["feed-item-903"].waitForExistence(timeout: 5))
        assertKinds([3], in: app)
        showKinds([1, 2, 3], in: app)
        XCTAssertTrue(results("3 résultats", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testLoginCallsAPIStoresSessionAndRestoresAfterRelaunch() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "valide")
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10), app.debugDescription)
        navigationButton("Compte", in: app).tap()
        XCTAssertTrue(app.staticTexts["Compte de test API"].exists)
        XCTAssertTrue(app.staticTexts["connexion@example.invalid"].exists)
        capture("12-compte-connecte-api", app: app)

        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["login-email"].exists)
        navigationButton("Compte", in: app).tap()
        reveal(app.buttons["logout"], in: app, down: false)
        app.buttons["logout"].tap()
        app.sheets["Se déconnecter ?"].buttons["Se déconnecter"].tap()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 5))
        XCTAssertFalse(navigationButton("Le journal", in: app).exists)
    }

    @MainActor
    func testLoginDisplaysAPIErrorsAndAllowsRetry() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "invalide")
        XCTAssertTrue(app.staticTexts["Email ou mot de passe invalide."].waitForExistence(timeout: 5), app.debugDescription)
        capture("20-connexion-erreur", app: app)
        XCTAssertTrue(app.buttons["login-submit"].isEnabled)
        XCTAssertFalse(navigationButton("Le journal", in: app).exists)

        submitLogin(in: app, password: "inactif", replacing: "invalide")
        XCTAssertTrue(app.staticTexts["Votre abonnement n’est pas actif. Gérez votre compte sur le portail web InfoMétrie."].waitForExistence(timeout: 5))
        submitLogin(in: app, password: "hors-ligne", replacing: "inactif")
        XCTAssertTrue(app.staticTexts["Serveur injoignable. Vérifiez votre connexion puis réessayez."].waitForExistence(timeout: 5))
        submitLogin(in: app, password: "valide", replacing: "hors-ligne")
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLoginDeviceQuotaRequiresConfirmationThenAuthenticates() {
        let app = loginTestApp()
        app.launch()
        submitLogin(in: app, password: "quota")
        XCTAssertTrue(app.navigationBars["Limite d’appareils"].waitForExistence(timeout: 5), app.debugDescription)
        capture("13-limite-appareils-api", app: app)
        XCTAssertFalse(navigationButton("Le journal", in: app).exists)
        app.buttons.containing(.staticText, identifier: "Ancien iPhone").firstMatch.tap()
        XCTAssertTrue(app.buttons["Remplacer cet appareil"].waitForExistence(timeout: 5))
        app.buttons["Remplacer cet appareil"].tap()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
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
        reveal(field, in: app, down: false)
        field.tap()
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
    func testSearchPersistenceSequenceAndPodcast() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        capture("01-fil", app: app)

        app.buttons["edit-filters"].tap()
        app.buttons["pick-persons"].tap()
        app.buttons["choice-Camille Martin"].tap()
        wait(app.staticTexts["choice-count"], key: "label", equals: "1 sélection")
        capture("15-personnalites", app: app)
        app.buttons["confirm-choices"].tap()
        XCTAssertTrue(app.buttons["pick-persons"].waitForExistence(timeout: 3))
        capture("02-filtres", app: app)
        let save = app.buttons["save-search"]
        reveal(save, in: app, down: false)
        save.tap()
        let field = app.textFields["search-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        capture("15-enregistrer-suivi", app: app)
        let name = "Veille test " + UUID().uuidString.prefix(6)
        field.tap(); field.typeText(String(name))
        app.buttons["confirm-save-search"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 4))
        capture("02-recherches", app: app)
        app.buttons["saved-actions-\(name)"].tap()
        app.buttons["Modifier la recherche"].tap()
        reveal(app.buttons["save-search"], in: app, down: false)
        app.buttons["save-search"].tap()
        app.navigationBars["Enregistrer un suivi"].buttons["Annuler"].tap()
        XCTAssertTrue(app.navigationBars["Recherche"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["apply-search"].isHittable)
        app.navigationBars["Recherche"].buttons["Annuler"].tap()

        app.terminate(); app.launchArguments = ["--uitesting", "--signed-in", "-appearance", "light"]; app.launch()
        navigationButton("Mes suivis", in: app).tap()
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

        navigationButton("Le journal", in: app).tap()
        let first = app.buttons["feed-item-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        first.tap()
        let toggle = app.buttons["player-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        capture("03-sequence-avant-lecture", app: app)
        let summary = app.buttons["sequence-summary"]
        reveal(summary, in: app, down: false)
        summary.tap()
        XCTAssertEqual(toggle.label, "Écouter", "Déplier le résumé ne doit pas démarrer l’écoute")
        XCTAssertTrue(app.staticTexts["Exemple fictif pour découvrir la consultation d’une séquence. Aucun propos réel ni passage à l’antenne n’est représenté ici."].waitForExistence(timeout: 3))
        capture("03-sequence-resume", app: app)
        reveal(summary, in: app, down: false)
        summary.tap()
        let context = app.buttons["sequence-context"]
        reveal(context, in: app, down: false)
        context.tap()
        XCTAssertEqual(toggle.label, "Écouter", "Le contexte s’ouvre indépendamment du lecteur")
        XCTAssertTrue(app.staticTexts["Personnalité fictive"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.45)))
        capture("03-sequence-contexte", app: app)
        reveal(context, in: app, down: false)
        context.tap()
        reveal(app.staticTexts["sequence-title"], in: app, down: true)
        listen(toggle)
        capture("03-sequence", app: app)
        reveal(app.buttons["player-toggle"], in: app, down: true)
        app.buttons["player-toggle"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Écouter")
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["feed-kind-1"].waitForExistence(timeout: 5))
        reveal(app.buttons["start-podcast"], in: app, down: true)
        app.buttons["start-podcast"].tap()
        XCTAssertTrue(app.buttons["close-podcast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        app.buttons["player-next"].tap()
        capture("04-podcast", app: app)
        app.buttons["close-podcast"].tap()

        navigationButton("Compte", in: app).tap()
        reveal(app.buttons["logout"], in: app, down: false)
        app.buttons["logout"].tap()
        app.sheets["Se déconnecter ?"].buttons["Se déconnecter"].tap()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDarkAppearanceAndLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "-appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        capture("05-fil-sombre", app: app)
        reveal(app.buttons["feed-item-2"], in: app, down: false)
        app.buttons["feed-item-2"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        capture("17-citation-sombre", app: app)
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        app.buttons["feed-item-1"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        capture("05-sequence-sombre", app: app)
        listen(app.buttons["player-toggle"])
        app.buttons["player-toggle"].tap()
        wait(app.buttons["player-toggle"], key: "label", equals: "Écouter")
        capture("05-sequence-ecoute-sombre", app: app)
        app.terminate()
        app.launchArguments = ["--uitesting", "--signed-in", "-appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["start-podcast"].waitForExistence(timeout: 10))
        capture("06-texte-accessible", app: app)
        let first = app.buttons["feed-item-1"]
        reveal(first, in: app, down: false)
        // Inspect the card and its metadata beyond the large-text header.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.82))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.30)))
        capture("06-carte-texte-accessible", app: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.48)))
        capture("06-carte-metadonnees-accessibles", app: app)
        reveal(first, in: app, down: true)
        XCTAssertTrue(first.isHittable)
        first.tap()
        let toggle = app.buttons["player-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(toggle.isHittable)
        XCTAssertGreaterThanOrEqual(toggle.frame.height, 52)
        listen(toggle)
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
        let app = loginTestApp(); app.launch()
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login-submit"].isEnabled)
        capture("00-connexion", app: app)
        submitLogin(in: app, password: "valide")
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(["Le journal", "Mes suivis", "Compte"].allSatisfy { navigationButton($0, in: app).exists })
        XCTAssertTrue(app.buttons["feed-item-1"].isHittable)
        // UIKit may report 43.99999999999999 for a 44pt toolbar target.
        XCTAssertGreaterThanOrEqual(app.buttons["edit-filters"].frame.height + 0.01, 44)
        capture("16-fil-cartes", app: app)
        app.buttons["edit-filters"].tap()
        reveal(app.buttons["filter-kind-2"], in: app, down: false)
        app.buttons["filter-kind-2"].tap()
        capture("17-filtres-citations", app: app)
        app.buttons["apply-search"].tap()
        XCTAssertTrue(app.buttons["feed-kind-2"].waitForExistence(timeout: 5))
        assertKinds([2], in: app)
        XCTAssertFalse(app.buttons["feed-item-1"].exists)
        capture("18-fil-citations", app: app)
        app.buttons["feed-item-2"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        capture("17-citation-claire", app: app)
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        showKinds([1, 2, 3], in: app)
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 5))
        // Cancelling the sheet must leave the applied criteria unchanged.
        app.buttons["edit-filters"].tap()
        reveal(app.buttons["filter-kind-1"], in: app, down: false)
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
    func testFilterSearchMultipleSelectionIntersectionAndReset() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["edit-filters"].waitForExistence(timeout: 10))
        app.buttons["edit-filters"].tap()
        XCTAssertTrue(app.buttons["pick-persons"].waitForExistence(timeout: 5))
        capture("15-filtres-initial", app: app)
        app.buttons["pick-persons"].tap()
        app.buttons["choice-Alex Morgan"].tap()
        app.buttons["choice-Camille Martin"].tap()
        wait(app.staticTexts["choice-count"], key: "label", equals: "2 sélections")

        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Camille")
        XCTAssertTrue(app.buttons["choice-Camille Martin"].exists)
        XCTAssertFalse(app.buttons["choice-Alex Morgan"].exists)
        wait(app.staticTexts["choice-count"], key: "label", equals: "2 sélections")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "zzzz")
        XCTAssertFalse(app.buttons["choice-Camille Martin"].exists)
        XCTAssertTrue(app.buttons["confirm-choices"].isHittable)
        wait(app.staticTexts["choice-count"], key: "label", equals: "2 sélections")
        // Confirm while searching: hidden selections must remain selected.
        app.buttons["confirm-choices"].tap()
        XCTAssertTrue(app.buttons["pick-parties"].waitForExistence(timeout: 5))
        app.buttons["pick-parties"].tap()
        app.buttons["choice-TEST-A"].tap()
        app.buttons["confirm-choices"].tap()
        XCTAssertTrue(app.staticTexts["Seules les personnalités choisies appartenant aux partis sélectionnés seront affichées."].waitForExistence(timeout: 5))
        capture("15-filtres-combines", app: app)
        app.buttons["apply-search"].tap()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-2"].exists, "Alex est exclu par le parti choisi")
        XCTAssertFalse(app.buttons["feed-item-3"].exists, "Sam appartient au parti mais ne fait pas partie des personnalités choisies")
        capture("15-fil-filtre", app: app)

        // A type change preserves both personality and party restrictions.
        showKinds([2], in: app)
        XCTAssertTrue(app.staticTexts["Aucun passage pour le moment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-podcast"].isEnabled)
        XCTAssertTrue(app.buttons["clear-filters"].exists)
        capture("18-fil-citations-vide", app: app)
        showKinds([1, 2, 3], in: app)
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-2"].exists, "Recocher les types ne doit pas réinitialiser les partis")
        XCTAssertFalse(app.buttons["feed-item-3"].exists, "Recocher les types ne doit pas réinitialiser les personnalités")

        app.buttons["edit-filters"].tap()
        reveal(app.buttons["reset-search"], in: app, down: false)
        app.buttons["reset-search"].tap()
        app.navigationBars["Recherche"].buttons["Annuler"].tap()
        XCTAssertTrue(app.buttons["clear-filters"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-2"].exists, "Annuler une remise à zéro conserve les filtres appliqués")

        app.buttons["edit-filters"].tap()
        app.buttons["pick-persons"].tap()
        wait(app.staticTexts["choice-count"], key: "label", equals: "2 sélections")
        app.buttons["clear-choices"].tap()
        wait(app.staticTexts["choice-count"], key: "label", equals: "Toutes les personnalités")
        app.buttons["confirm-choices"].tap()
        reveal(app.buttons["reset-search"], in: app, down: false)
        app.buttons["reset-search"].tap()
        app.buttons["apply-search"].tap()
        XCTAssertTrue(app.buttons["feed-item-2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testFiltersDarkAppearanceAndMaximumText() {
        let app = XCUIApplication()
        for largeText in [false, true] {
            app.launchArguments = ["--uitesting", "--signed-in", "-appearance", largeText ? "light" : "dark"]
            if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            app.launch()
            XCTAssertTrue(app.buttons["edit-filters"].waitForExistence(timeout: 10))
            let suffix = largeText ? "grand-texte" : "sombre"
            capture("20-fil-\(suffix)", app: app)
            navigationButton("Mes suivis", in: app).tap()
            capture("20-suivis-\(suffix)", app: app)
            navigationButton("Compte", in: app).tap()
            if largeText, app.buttons["navigation-account"].exists {
                let accountTab = app.buttons["navigation-account"]
                XCTAssertGreaterThanOrEqual(accountTab.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(accountTab.frame.maxX, app.frame.maxX,
                                        "La rubrique active doit rester entièrement visible en grand texte")
            }
            capture("20-compte-\(suffix)", app: app)
            let appearance = app.buttons["appearance-picker"]
            reveal(appearance, in: app, down: false)
            XCTAssertTrue(appearance.isHittable)
            capture("20-reglages-\(suffix)", app: app)
            navigationButton("Le journal", in: app).tap()
            app.buttons["edit-filters"].tap()
            XCTAssertTrue(app.buttons["pick-persons"].waitForExistence(timeout: 5))
            capture("15-filtres-\(suffix)", app: app)
            reveal(app.buttons["pick-persons"], in: app, down: false)
            app.buttons["pick-persons"].tap()
            let person = app.buttons["choice-Camille Martin"]
            reveal(person, in: app, down: false)
            if largeText { capture("15-personnalites-grand-texte-liste", app: app) }
            person.tap()
            wait(app.staticTexts["choice-count"], key: "label", equals: "1 sélection")
            capture("15-personnalites-\(suffix)", app: app)
            let confirm = app.buttons["confirm-choices"]
            XCTAssertTrue(confirm.isHittable)
            XCTAssertGreaterThanOrEqual(confirm.frame.height, 52)
            XCTAssertLessThanOrEqual(confirm.frame.maxX, app.frame.maxX)
            confirm.tap()
            let interventions = app.buttons["filter-kind-1"]
            reveal(interventions, in: app, down: false)
            interventions.tap()
            capture("15-types-\(suffix)", app: app)
            let apply = app.buttons["apply-search"]
            XCTAssertTrue(apply.isHittable)
            XCTAssertGreaterThanOrEqual(apply.frame.height, 52)
            XCTAssertLessThanOrEqual(apply.frame.maxX, app.frame.maxX)
            apply.tap()
            XCTAssertTrue(app.buttons["feed-kind-1"].waitForExistence(timeout: 5))
            assertKinds([1], in: app)
            app.terminate()
        }
    }

    @MainActor
    func testMainNavigationPreservesFeedSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches", "-appearance", "light"]
        app.launch()
        let citations = app.buttons["feed-kind-2"]
        XCTAssertTrue(citations.waitForExistence(timeout: 10))
        capture("19-fil-initial", app: app)
        if app.buttons["navigation-feed"].exists {
            XCTAssertFalse(app.tabBars.firstMatch.exists, "L’iPad ne doit afficher qu’une navigation principale")
        }
        showKinds([2], in: app)
        XCTAssertTrue(results("2 résultats", in: app).waitForExistence(timeout: 5))

        let saved = navigationButton("Mes suivis", in: app)
        saved.tap()
        XCTAssertTrue(app.buttons["new-search"].waitForExistence(timeout: 5))
        capture("20-suivis-vides", app: app)
        let account = navigationButton("Compte", in: app)
        account.tap()
        XCTAssertTrue(app.buttons["reading-size-M"].waitForExistence(timeout: 5))
        capture("20-compte", app: app)
        let feed = navigationButton("Le journal", in: app)
        feed.tap()
        XCTAssertTrue(citations.waitForExistence(timeout: 5))
        assertKinds([2], in: app)
        XCTAssertTrue(results("2 résultats", in: app).exists)
        app.buttons["feed-item-2"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        assertKinds([2], in: app)
        capture("19-navigation-principale", app: app)
    }

    @MainActor
    func testFeedKindSelectionSyncNavigationAndPodcast() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches", "-appearance", "light"]
        app.launch()
        let interventions = app.buttons["feed-kind-1"]
        let citations = app.buttons["feed-kind-2"]
        XCTAssertTrue(interventions.waitForExistence(timeout: 10))
        assertKinds([1, 2, 3], in: app)
        XCTAssertTrue(results("7 résultats", in: app).exists)
        capture("18-fil-tous", app: app)

        showKinds([2], in: app)
        XCTAssertTrue(results("2 résultats", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-1"].exists)
        // On/off: the last checked type can be unchecked too, and the journal says why it is empty.
        citations.tap()
        assertKinds([], in: app, "Tous les types peuvent être décochés")
        XCTAssertTrue(app.staticTexts["Aucun type sélectionné"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-podcast"].isEnabled)
        citations.tap()
        assertKinds([2], in: app)
        XCTAssertFalse(app.buttons["clear-filters"].exists, "Le type seul ne doit pas ajouter un récapitulatif redondant")
        capture("18-fil-citations", app: app)
        app.buttons["feed-item-2"].tap()
        XCTAssertTrue(app.buttons["player-toggle"].waitForExistence(timeout: 10))
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(citations.waitForExistence(timeout: 5))
        assertKinds([2], in: app, "Le retour au fil conserve les types cochés")

        app.buttons["edit-filters"].tap()
        reveal(app.buttons["filter-kind-2"], in: app, down: false)
        XCTAssertTrue(app.buttons["filter-kind-2"].isSelected)
        app.buttons["filter-kind-1"].tap()
        app.buttons["apply-search"].tap()
        XCTAssertTrue(interventions.waitForExistence(timeout: 5))
        assertKinds([1], in: app, "Le panneau doit actualiser les cases du fil")
        XCTAssertTrue(results("3 résultats", in: app).exists)
        XCTAssertFalse(app.buttons["feed-item-2"].exists)
        capture("18-fil-interventions", app: app)

        // Checkboxes combine types, which the former tabs could not do.
        showKinds([1, 3], in: app)
        XCTAssertTrue(results("5 résultats", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-item-2"].exists)
        showKinds([1, 2, 3], in: app)
        XCTAssertTrue(results("7 résultats", in: app).waitForExistence(timeout: 5))
        showKinds([2], in: app)
        XCTAssertTrue(results("2 résultats", in: app).waitForExistence(timeout: 5))
        reveal(app.buttons["start-podcast"], in: app, down: true)
        app.buttons["start-podcast"].tap()
        XCTAssertTrue(app.staticTexts["Passage 1 sur 2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Les enjeux de la rentrée"].exists)
        wait(app.buttons["player-toggle"], key: "label", equals: "Pause")
        app.buttons["player-toggle"].tap()
        app.buttons["player-next"].tap()
        XCTAssertTrue(app.staticTexts["Passage 2 sur 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Un nouveau regard sur les territoires"].exists)
        XCTAssertFalse(app.buttons["player-next"].isEnabled)
        app.buttons["close-podcast"].tap()
        XCTAssertTrue(citations.waitForExistence(timeout: 5))
        assertKinds([2], in: app)
    }

    @MainActor
    func testFeedPeriodsChartSelectsDay() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(results("7 résultats", in: app).waitForExistence(timeout: 10))
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        func day(_ offset: Int) -> String {
            let date = paris.date(byAdding: .day, value: -offset, to: paris.startOfDay(for: Date()))!
            let parts = paris.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        }
        func bar(_ offset: Int) -> XCUIElement { app.descendants(matching: .any)["feed-day-\(day(offset))"] }

        // 7 j: the last 7 complete days, 8 fictional passages each, more than one 50-item page.
        app.buttons["feed-period-7"].tap()
        XCTAssertTrue(app.buttons["feed-period-7"].isSelected)
        XCTAssertTrue(results("56 résultats", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["feed-day-chart"].exists)
        XCTAssertTrue(bar(1).exists && bar(7).exists)
        XCTAssertFalse(bar(0).exists, "Aujourd’hui reste dans Live")
        XCTAssertFalse(bar(8).exists)
        XCTAssertFalse(app.buttons["feed-display-chart"].exists, "Le choix Liste / Graphique est retiré")
        capture("periode-7-jours", app: app)

        // Touching a bar shows that day only; previous and next move one day; the cross restores the period.
        bar(1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["feed-day-selection"].waitForExistence(timeout: 5))
        XCTAssertTrue(results("8 résultats", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-day-next"].isEnabled, "Hier est le dernier jour de la période")
        XCTAssertTrue(app.buttons["feed-item-1297"].waitForExistence(timeout: 5))
        capture("periode-jour-choisi", app: app)
        app.buttons["feed-day-previous"].tap()
        wait(bar(2), key: "value", equals: "Sélectionné")
        XCTAssertFalse(app.buttons["feed-item-1297"].exists)
        XCTAssertTrue(app.buttons["feed-day-next"].isEnabled)
        app.buttons["feed-day-clear"].tap()
        XCTAssertTrue(results("56 résultats", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["feed-day-selection"].exists)

        // The end of the first page loads the next one: the period's oldest passage appears.
        let oldest = app.buttons["feed-item-1230"]
        for _ in 0..<25 where !oldest.exists { app.swipeUp() }
        XCTAssertTrue(oldest.waitForExistence(timeout: 5), "La page suivante de l’historique doit se charger")
        // 1230 is a Publication X; 1231, an intervention of the same day, opens a sequence.
        let passage = app.buttons["feed-item-1231"]
        reveal(passage, in: app, down: true)
        passage.tap()
        XCTAssertTrue(app.navigationBars["Séquence"].waitForExistence(timeout: 10))
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()

        // The type checkboxes drive the bars and the list together.
        toggleKind(2, in: app)
        XCTAssertTrue(results("42 résultats", in: app).waitForExistence(timeout: 10))
        toggleKind(2, in: app)
        XCTAssertTrue(results("56 résultats", in: app).waitForExistence(timeout: 10))

        // 30 j: thirty bars; a day without passages says so and keeps the chart.
        reveal(app.buttons["feed-period-30"], in: app, down: false)
        app.buttons["feed-period-30"].tap()
        XCTAssertTrue(results("89 résultats", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(bar(30).exists && bar(1).exists)
        bar(30).tap()
        XCTAssertTrue(app.staticTexts["Aucun passage ce jour-là"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["feed-day-chart"].exists)
        XCTAssertFalse(app.buttons["feed-day-previous"].isEnabled)
        capture("periode-30-jours-jour-vide", app: app)

        // Live comes back with its own list.
        app.buttons["feed-period-live"].tap()
        XCTAssertTrue(results("7 résultats", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["feed-day-chart"].exists)
        XCTAssertTrue(app.buttons["feed-item-1"].exists)
    }

    @MainActor
    func testFeedKindsDarkAppearanceAndMaximumText() {
        let app = XCUIApplication()
        for largeText in [false, true] {
            app.launchArguments = ["--uitesting", "--signed-in", "-appearance", largeText ? "light" : "dark"]
            if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            app.launch()
            let suffix = largeText ? "grand-texte" : "sombre"
            XCTAssertTrue(app.buttons["feed-kind-2"].waitForExistence(timeout: 10))
            showKinds([2], in: app)
            assertKinds([2], in: app)
            capture("18-fil-citations-\(suffix)", app: app)
            for index in 1...3 {
                let choice = app.buttons["feed-kind-\(index)"]
                reveal(choice, in: app, down: false)
                XCTAssertGreaterThanOrEqual(choice.frame.height, 48)
                // The iPhone page margin (AppLayout.margin), 16 pt since 2026-10-07.
                XCTAssertGreaterThanOrEqual(choice.frame.minX, app.frame.minX + 16)
                XCTAssertLessThanOrEqual(choice.frame.maxX, app.frame.maxX - 16)
            }
            showKinds([1], in: app)
            assertKinds([1], in: app)
            capture("18-fil-interventions-\(suffix)", app: app)
            showKinds([1, 2, 3], in: app)
            assertKinds([1, 2, 3], in: app)
            capture("18-fil-tous-\(suffix)", app: app)
            app.terminate()
        }
    }

    @MainActor
    func testFullscreenTranscriptKeepsPreciseSeekingAndPlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--precise-word-timings", "-appearance", "dark",
                               "-readingSize", "M", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        let toggle = app.buttons["player-toggle"]
        listen(toggle)
        toggle.tap()
        reveal(app.links["retrouverez"], in: app, down: false)
        app.links["retrouverez"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 19 sur 41")
        let expand = app.buttons["expand-transcript"]
        reveal(expand, in: app, down: true)
        expand.tap()
        let fullscreen = app.descendants(matching: .any).matching(identifier: "fullscreen-transcript").firstMatch
        let close = fullscreen.buttons["collapse-transcript"]
        let fullToggle = fullscreen.buttons["player-toggle"]
        let fullElapsed = fullscreen.staticTexts["player-elapsed"]
        let fullStatus = fullscreen.staticTexts["transcript-position"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        wait(fullToggle, key: "label", equals: "Écouter")
        XCTAssertTrue(fullToggle.isHittable)
        XCTAssertEqual(fullElapsed.label, "0:12", "Agrandir ne doit pas recréer le lecteur")
        wait(fullStatus, key: "value", equals: "Mot 19 sur 41")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(app.buttons["navigation-feed"].isHittable, "Le plein écran doit aussi masquer la navigation iPad")
        let scroll = fullscreen.scrollViews["transcript-scroll"]
        XCTAssertGreaterThan(scroll.frame.height, 300, "Le texte utilise la hauteur disponible")
        fullscreen.buttons["Reculer de 10 secondes"].tap()
        wait(fullStatus, key: "value", equals: "Aucun mot actif")
        fullscreen.buttons["Avancer de 10 secondes"].tap()
        wait(fullStatus, key: "value", equals: "Mot 19 sur 41")
        fullscreen.links["retrouverez"].tap()
        XCTAssertEqual(fullElapsed.label, "0:12")
        capture("24-texte-plein-ecran-sombre", app: app)

        let slider = fullscreen.sliders["player-position"]
        slider.adjust(toNormalizedSliderPosition: 0.25)
        XCTAssertNotEqual(fullElapsed.label, "0:12")
        XCTAssertNotEqual(fullStatus.value as? String, "Mot 19 sur 41", "Le curseur met aussi à jour le texte")
        XCTAssertEqual(fullToggle.label, "Écouter", "Déplacer le curseur conserve la pause")
        let pausedPosition = fullElapsed.label
        scroll.swipeUp()
        let follow = fullscreen.buttons["transcript-follow"]
        wait(follow, key: "value", equals: "Désactivé")
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, pausedPosition)
        XCTAssertEqual(toggle.label, "Écouter")
        XCTAssertEqual(app.buttons["transcript-follow"].value as? String, "Désactivé", "Le choix de suivi est partagé entre les deux vues")
        expand.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertEqual(follow.value as? String, "Désactivé")
        follow.tap()
        XCTAssertTrue(follow.waitForNonExistence(timeout: 3), "Reprendre le suivi disparaît une fois le suivi repris")
        for _ in 0..<4 {
            if fullscreen.links["Cette"].isHittable { break }
            scroll.swipeDown()
        }
        fullscreen.links["Cette"].tap()
        wait(fullStatus, key: "value", equals: "Mot 1 sur 41")
        XCTAssertEqual(fullElapsed.label, "0:01")
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        toggle.tap()
        wait(toggle, key: "label", equals: "Pause")
        expand.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertEqual(fullToggle.label, "Pause", "L’écoute continue à l’ouverture")
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Pause", "L’écoute continue à la fermeture")
        toggle.tap()
        app.navigationBars["Séquence"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFullscreenTranscriptSeeksFromTextAtMaximumSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "-appearance", "light", "-readingSize", "M",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        let expand = app.buttons["expand-transcript"]
        reveal(expand, in: app, down: false)
        expand.tap()
        let fullscreen = app.descendants(matching: .any).matching(identifier: "fullscreen-transcript").firstMatch
        let close = fullscreen.buttons["collapse-transcript"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let toggle = fullscreen.buttons["player-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "Écouter", "Agrandir ne démarre pas l’écoute")
        XCTAssertTrue(fullscreen.links["Cette"].isHittable)
        fullscreen.links["Cette"].tap()
        wait(fullscreen.staticTexts["player-elapsed"], key: "label", equals: "0:00")
        listen(toggle)
        toggle.tap()
        XCTAssertEqual(toggle.label, "Écouter")
        let scroll = fullscreen.scrollViews["transcript-scroll"]
        XCTAssertGreaterThan(scroll.frame.height, 100)
        for control in [close, toggle, fullscreen.sliders["player-position"], fullscreen.buttons["Avancer de 10 secondes"], fullscreen.buttons["Reculer de 10 secondes"]] {
            XCTAssertTrue(control.isHittable)
            // Native sliders expose their track frame, independently of their extended hit area.
            if control.elementType != .slider { XCTAssertGreaterThanOrEqual(control.frame.height, 44) }
            XCTAssertLessThanOrEqual(control.frame.maxY, app.frame.maxY)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        scroll.swipeUp()
        let follow = fullscreen.buttons["transcript-follow"]
        wait(follow, key: "value", equals: "Désactivé")
        follow.tap()
        XCTAssertTrue(follow.waitForNonExistence(timeout: 3), "Reprendre le suivi disparaît une fois le suivi repris")
        capture("25-texte-plein-ecran-accessibilite", app: app)
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player-toggle"].exists)
        XCTAssertEqual(app.buttons["player-toggle"].label, "Écouter")
    }

    @MainActor
    func testTranscriptSeeksPlayerAndFollowsScrubbingWhilePaused() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        reveal(app.links["passage"], in: app, down: false)
        XCTAssertTrue(app.links["passage"].isHittable, app.debugDescription)
        // A word tapped while HLS loads is kept until the player is ready, without starting it.
        app.links["passage"].tap()
        let toggle = app.buttons["player-toggle"]
        let status = app.staticTexts["transcript-position"]
        wait(status, key: "value", equals: "Mot 9 sur 41")
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:03")
        XCTAssertEqual(toggle.label, "Écouter", "Toucher un mot place l’écoute sans la démarrer")
        app.links["retrouverez"].tap()
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
        // The fixture text fits its frame, so it cannot be scrolled to suspend following here;
        // the fullscreen journeys cover suspending and resuming.
        XCTAssertFalse(app.buttons["transcript-follow"].exists, "Le suivi actif n’affiche aucune commande")
        capture("08-verbatim-suivi-lecteur", app: app)
    }

    @MainActor
    func testPodcastTranscriptUsesCurrentSequenceAndResetsOnNext() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--reset-searches"]
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

    @MainActor private func navigationButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let identifiers = ["Le journal": "navigation-feed", "Mes suivis": "navigation-saved", "Compte": "navigation-account"]
        let editorial = app.buttons[identifiers[title] ?? ""]
        return editorial.exists ? editorial : app.tabBars.buttons[title]
    }

    /// The feed status line, which starts with the result count ("7 résultats · il y a …").
    @MainActor private func results(_ count: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND (label == %@ OR label BEGINSWITH %@)", "feed-status", count, count + " ")).firstMatch
    }

    /// Checks exactly the given feed types: 1 interventions, 2 citations, 3 Publications X.
    @MainActor private func showKinds(_ kinds: Set<Int>, in app: XCUIApplication) {
        // Check before unchecking, so the journal never goes empty between two steps.
        for index in kinds.sorted() where !isKindChecked(index, in: app) { toggleKind(index, in: app) }
        for index in [1, 2, 3] where !kinds.contains(index) && isKindChecked(index, in: app) { toggleKind(index, in: app) }
    }

    @MainActor private func isKindChecked(_ index: Int, in app: XCUIApplication) -> Bool {
        app.buttons["feed-kind-\(index)"].value as? String == "Coché"
    }

    @MainActor private func toggleKind(_ index: Int, in app: XCUIApplication) {
        let box = app.buttons["feed-kind-\(index)"]
        let expected = isKindChecked(index, in: app) ? "Non coché" : "Coché"
        reveal(box, in: app, down: false)
        box.tap()
        wait(box, key: "value", equals: expected)
    }

    @MainActor private func assertKinds(_ kinds: Set<Int>, in app: XCUIApplication, _ message: String = "") {
        for index in 1...3 {
            XCTAssertEqual(isKindChecked(index, in: app), kinds.contains(index), "feed-kind-\(index) \(message)")
        }
    }

    /// A sequence page prepares its player on opening: wait until it can play, then start listening.
    @MainActor private func listen(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        wait(toggle, key: "enabled", equals: true)
        toggle.tap()
        wait(toggle, key: "label", equals: "Pause")
    }

    @MainActor private func wait(_ element: XCUIElement, key: String, equals value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", key, value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    @MainActor private func wait(_ element: XCUIElement, key: String, equals value: Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "%K == %@", key, NSNumber(value: value)), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    @MainActor
    func testPreciseAPITimingsSeekToTwelveSecondsAndLeaveSilencesUnhighlighted() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--signed-in", "--precise-word-timings", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["feed-item-1"].waitForExistence(timeout: 10))
        app.buttons["feed-item-1"].tap()
        listen(app.buttons["player-toggle"])
        app.buttons["player-toggle"].tap()
        reveal(app.links["retrouverez"], in: app, down: false)
        app.links["retrouverez"].tap()
        wait(app.staticTexts["transcript-position"], key: "value", equals: "Mot 19 sur 41")
        // The fixture puts this word at 12s; uniform estimation would yield 7.9s.
        XCTAssertEqual(app.staticTexts["player-elapsed"].label, "0:12")
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
        app.launchArguments = ["--uitesting", "--signed-in", "--precise-word-timings", "-appearance", "light"]
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
        capture("11-podcast-horodatages-api", app: app)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication, down: Bool) {
        for _ in 0..<8 {
            // Keep gestures inside the content above the persistent playback dock,
            // including at the largest accessibility size, where it is taller.
            let bounds = app.frame
            let navigationBottom = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max()
            let mainNavigation = app.otherElements["primary-navigation"]
            let navigationTop = mainNavigation.exists
                ? (mainNavigation.frame.height > mainNavigation.frame.width ? mainNavigation.frame.minY : mainNavigation.frame.maxY)
                : bounds.minY + 88
            let top = navigationBottom.map { $0 + 12 } ?? (navigationTop + 12)
            // List creates offscreen rows lazily. Reading their identifier before
            // they exist causes XCTest to fail instead of scrolling to the row.
            let identifier = element.exists ? element.identifier : ""
            // The compact type row begins 8pt below the native navigation bar.
            // It is fully visible there; do not keep pulling to refresh in an
            // attempt to create the larger gap used by scrolling body controls.
            let picker = app.otherElements["feed-filter-bar"]
            let contentTop = identifier.hasPrefix("feed-item-") && picker.exists && picker.isHittable
                ? max(top, picker.frame.maxY + 8) : top
            let controlTop = identifier.hasPrefix("feed-kind-") ? top - 8 : contentTop
            let slider = app.sliders["player-position"]
            let filterFooter = ["confirm-save-search", "confirm-choices", "apply-search"].map { app.buttons[$0] }.first { $0.exists && $0.isHittable }
            let choiceCount = app.staticTexts["choice-count"]
            // The fixed selection summary can span several lines at maximum text size.
            // Its top, rather than the confirmation button, bounds the scrolling list.
            let filterBottom = choiceCount.exists && choiceCount.isHittable
                ? choiceCount.frame.minY - 28 : filterFooter.map { $0.frame.minY - 28 }
            // Before playback the dock holds only the listen button, which grows with the text size.
            let listen = app.buttons["play-sequence"]
            let dockBottom = listen.exists && listen.isHittable ? listen.frame.minY - 12 : nil
            let bottom = slider.exists ? slider.frame.minY - 12 : filterBottom ?? dockBottom ?? bounds.maxY - 150
            if element.exists && element.isHittable {
                let contentControl = ["sequence-summary", "sequence-context", "transcript-follow", "expand-transcript", "transcript-scroll"].contains(identifier)
                    || ["save-search", "reset-search", "clear-choices", "start-podcast", "logout"].contains(identifier)
                    || ["filter-kind-", "feed-kind-", "feed-item-", "choice-", "pick-"].contains { identifier.hasPrefix($0) }
                if element.elementType != .link && !contentControl { return }
                // A large-text choice can be taller than the viewport. Its center
                // remains a valid tap target when it lies above the fixed footer.
                if contentControl, element.frame.height > bottom - top,
                   element.frame.midY >= top, element.frame.midY <= bottom { return }
                // In a sheet the list can end before a row clears the footer margin. Another drag
                // there would not scroll and would tap the row instead; its centre in the band is enough.
                if contentControl, filterFooter != nil,
                   element.frame.midY >= controlTop, element.frame.midY <= bottom { return }
                // XCTest may report cards and controls as hittable underneath
                // navigation or the dock. Bring their tap target into the content.
                if element.frame.minY >= controlTop && element.frame.maxY <= bottom { return }
            }
            let upper = top + (bottom - top) * 0.15
            let lower = top + (bottom - top) * 0.85
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // iPad sheets are narrower than the app. Derive the gesture's x from
            // their footer so a scroll cannot dismiss the sheet by touching outside.
            let x = filterFooter.map { $0.frame.maxX - bounds.minX - 8 } ?? (bounds.width - 8)
            let frame = element.exists ? element.frame : .zero
            let towardTop = frame != .zero ? frame.minY < controlTop : down
            let distance = frame == .zero ? lower - upper : min(lower - upper, max(44, towardTop ? controlTop - frame.minY : frame.maxY - bottom))
            let startY = towardTop ? upper : lower
            let endY = towardTop ? startY + distance : startY - distance
            let start = origin.withOffset(CGVector(dx: x, dy: startY))
            let end = origin.withOffset(CGVector(dx: x, dy: endY))
            // A slow drag that holds at the end leaves no momentum: at the largest text sizes a
            // flick overshoots the target and the loop then oscillates around it.
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }

    }

    @MainActor private func auditVisibleFeed(_ app: XCUIApplication) throws {
        var covered: [String] = []
        let tabBar = app.otherElements["main-tab-bar"]
        let navigationBar = app.navigationBars.firstMatch
        let mainNavigation = app.otherElements["primary-navigation"]
        let sidebar = mainNavigation.exists && mainNavigation.frame.height > mainNavigation.frame.width
        let navigationTop = mainNavigation.exists && !sidebar ? mainNavigation.frame.maxY : (navigationBar.exists ? navigationBar.frame.maxY : app.frame.minY)
        let picker = app.otherElements["feed-filter-bar"]
        let top = picker.exists && picker.isHittable ? max(navigationTop, picker.frame.maxY) : navigationTop
        let bottom = tabBar.exists ? tabBar.frame.minY : app.frame.maxY
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed-item-")).allElementsBoundByIndex.map(\.frame)
        let leading = sidebar ? mainNavigation.frame.maxX : app.frame.minX
        let readingArea = CGRect(x: leading, y: top, width: app.frame.maxX - leading, height: bottom - top)
        XCTAssertTrue(cards.contains { readingArea.contains($0) }, "Au moins une carte complète doit être contrôlée")
        let coveredCards = cards.filter { !readingArea.contains($0) }
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion]) { issue in
            print("Accessibility audit \(issue.auditType): \(issue.element?.debugDescription ?? "No exposed element")")
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
