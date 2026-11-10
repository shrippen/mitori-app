import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import Mitori

// Style and language change while the app runs (Appearance): the window built anew, the texts
// retranslated, nothing lost. Run by tst_ui from Leinen (ctest look) and from Shinki (look_shinki),
// in a file of its own: tst_ui.qml holds page types of the start's style through its own uses.
TestCase {
    id: test

    name: "Look"
    when: windowShown

    property var window: null
    readonly property int startStyle: uiShinki ? Appearance.Style.Shinki : Appearance.Style.Leinen
    readonly property int otherStyle: uiShinki ? Appearance.Style.Kante : Appearance.Style.Shinki
    readonly property string startName: uiShinki ? "Shinki" : "Leinen"
    readonly property string otherName: uiShinki ? "Kante" : "Shinki"
    readonly property string pages: "qrc:/qt/qml/Mitori/qml/"
    // ms CPU, as in tst_perf.qml: 1.3 times the most measured with 40 busy processes, debug build
    // (Leinen to Shinki 557, Shinki to Kante 756; release 451 and 694).
    readonly property int switchBudget: uiShinki ? 1000 : 750
    readonly property int scrolled: 200
    readonly property int startScrolled: 50

    function initTestCase() {
        Appearance.setLanguage(Appearance.Language.English)
        const component = Qt.createComponent("Mitori", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null, { width: 420, height: 800 })
        window.show()
        tryVerify(() => window.pageStack.currentItem !== null)
        compare(Appearance.window, window)
    }

    function init() {
        failOnWarning(/Binding loop/)
        failOnWarning(/ReferenceError/)
        failOnWarning(/TypeError/)
        failOnWarning(/is not a type/)
    }

    // Kirigami 6.31 crashes on a pop in the last moments of a slide: ColumnView::setCurrentIndex
    // hands the focus to the page below, a Behavior on that makes Qt run the slide's end there and
    // then, which takes the current item away (SIGSEGV in QQuickItem::size). A tap does not get
    // here, a page does not take taps while it slides; a test does.
    function popPage() {
        tryVerify(() => !window.pageStack.columnView.moving, 5000, "the slide ends")
        // A page may have gone during the wait (TrainingEndPage): the start menu stays.
        if (window.pageStack.depth > 1) {
            window.pageStack.pop()
        }
    }

    function cleanup() {
        Appearance.setLanguage(Appearance.Language.English)
        toStyle(startStyle)
        window.width = 420
        window.height = 800
        while (window.pageStack.depth > 1)
            popPage()
    }

    function allChildren(item) {
        let all = []
        for (let i = 0; i < item.children.length; i++) {
            all.push(item.children[i])
            all = all.concat(allChildren(item.children[i]))
        }
        return all
    }

    function findChildren(item, name) {
        return allChildren(item).filter(c => c.objectName === name)
    }

    // Applies a style as a tap does; returns when the new window stands.
    function toStyle(style) {
        if (Appearance.style === style && Appearance.running === style) {
            return
        }
        const old = Appearance.window
        Appearance.setStyle(style)
        tryVerify(() => Appearance.window !== old && Appearance.window !== null)
        window = Appearance.window
        tryVerify(() => window.pageStack.currentItem !== null)
    }

    function shot(name) {
        wait(300)
        let done = false
        window.pageStack.grabToImage(result => {
            result.saveToFile(uiShotsDir + "/" + name + ".png")
            done = true
        })
        tryVerify(() => done)
    }

    function push(page, properties) {
        window.pageStack.push(Qt.resolvedUrl(pages + page + ".qml"), properties || {})
        tryVerify(() => window.pageStack.currentItem && window.pageStack.currentItem.title !== undefined)
        // A page that makes a part after it is drawn (TodayPage): with it.
        tryVerify(() => window.pageStack.currentItem.built !== false)
        return window.pageStack.currentItem
    }

    function openAppearance() {
        const settings = push("SettingsPage")
        findChild(settings, "appearanceButton").clicked()
        tryVerify(() => window.pageStack.depth === 3 && window.pageStack.currentItem.keptPage === "AppearancePage.qml")
        return window.pageStack.currentItem
    }

    function tile(page, name, text) {
        const found = findChildren(page, name).find(t => t.text === text)
        verify(found, name + " " + text)
        return found
    }

    function standingPreviews(page) {
        const all = findChildren(page, "lookPreview")
        verify(all.length > 0)
        tryVerify(() => all.every(p => p.ready), 20000, "every preview stands")
        return all
    }

    // The file selector reached the new window: Look, the head instead of Kirigami's bar, a
    // component's own file.
    function verifyStyle(shinki) {
        compare(Look.shinki, shinki)
        compare(window.pageStack.globalToolBar.style,
                shinki ? Kirigami.ApplicationHeaderStyle.None : Kirigami.ApplicationHeaderStyle.Auto)
        compare(findChild(window, "lookHead").implicitHeight > 0, shinki)
        compare(uiCatalog.drawnByShinki(findChild(window.pageStack.currentItem, "introButton")), shinki)
    }

    // Both ways: the same pages come back, the old window is gone, Back still works, the window
    // turns, the bars take the new ground.
    function test_style_both_ways() {
        const windows = uiCatalog.windowCount()
        const page = openAppearance()
        uiCatalog.watch(window)
        uiCatalog.watch(page)
        verifyStyle(uiShinki)
        const bar = String(Appearance.barColor)     // a copy: a colour read is a live reference
        verify(Qt.colorEqual(bar, Look.backgroundColor))
        standingPreviews(page)
        shot("look-" + startName)
        page.flickable.contentY = scrolled
        window.x = 321
        window.y = 123

        // CPU time: a busy machine took 13296 ms by the clock.
        const started = Date.now()
        const startedCpu = uiCatalog.cpuMs()
        toStyle(otherStyle)
        const took = uiCatalog.cpuMs() - startedCpu
        console.log("change of style:", Date.now() - started, "ms,", took, "ms CPU")
        verify(took <= switchBudget, took + " ms CPU")
        compare(uiCatalog.watchedAlive(), 0, "old window and page gone")
        compare(uiCatalog.windowCount(), windows)
        compare(Appearance.running, otherStyle)
        compare(window.pageStack.depth, 3)
        compare(window.pageStack.currentItem.keptPage, "AppearancePage.qml")
        compare(window.pageStack.get(1).keptPage, "SettingsPage.qml")
        compare(window.width, 420)
        compare(window.height, 800)
        compare(window.x, 321, "X11: the window stays where it was")
        compare(window.y, 123)
        verifyStyle(!uiShinki)
        tryVerify(() => window.pageStack.currentItem.flickable.contentY === scrolled, 5000, "the same place on the page")
        verify(Qt.colorEqual(Appearance.barColor, Look.backgroundColor))
        verify(!Qt.colorEqual(Appearance.barColor, bar), "the bars follow")
        standingPreviews(window.pageStack.currentItem)
        shot("look-" + otherName)

        // Sideways and back.
        window.width = 800
        window.height = 420
        wait(100)
        window.width = 420
        window.height = 800

        toStyle(startStyle)
        compare(window.pageStack.depth, 3)
        verifyStyle(uiShinki)
        verify(Qt.colorEqual(Appearance.barColor, bar))

        // Back through the kept pages, as the Back key.
        window.back()
        tryVerify(() => window.pageStack.currentItem.keptPage === "SettingsPage.qml")
        window.back()
        tryVerify(() => window.pageStack.currentIndex === 0)
    }

    // The start tiles are all as high, in every style, on a phone and a tablet: the exam tile's
    // short hint made it smaller than the others.
    function test_start_tiles_equal_height() {
        const names = ["todayTile", "examTile", "statsTile", "coursesTile", "mapTile", "glossaryTile"]
        const sizes = [{ w: 360, h: 640 }, { w: 420, h: 800 }, { w: 1000, h: 600 }]
        const styles = [Appearance.Style.Breeze, Appearance.Style.Material, Appearance.Style.Kante, Appearance.Style.Leinen, Appearance.Style.Shinki]
        for (const style of styles) {
            toStyle(style)
            for (const size of sizes) {
                window.width = size.w
                window.height = size.h
                const start = window.pageStack.get(0)
                const tiles = names.map(n => findChild(start, n))
                tryVerify(() => tiles.every(t => t.visible && t.height > 0))
                wait(100)
                const where = "style " + style + ", " + size.w + "x" + size.h + ": "
                for (const t of tiles) {
                    // A cell's fractional height rounds apart by a pixel.
                    fuzzyCompare(t.height, tiles[0].height, 1, where + t.objectName + " is as high as " + tiles[0].objectName)
                }
            }
        }
    }

    // The start page keeps its place too, below the kept pages.
    function test_start_page_place() {
        // Low enough for the tiles to scroll.
        window.height = 360
        const flick = window.pageStack.get(0).flickable
        tryVerify(() => flick.contentHeight - flick.height >= startScrolled)
        flick.contentY = startScrolled
        openAppearance()
        toStyle(otherStyle)
        tryVerify(() => window.pageStack.get(0).flickable.contentY === startScrolled, 5000, "the start page's place")
    }

    // A place beyond the page's end ends at its end; once settled the page does not jump back to
    // it when it grows later (the page is narrower, its text wraps).
    function test_scroll_to_clamps() {
        // Low enough for the page to scroll.
        window.height = 360
        const flick = push("BackupPage").flickable
        const far = flick.contentHeight + 5000
        window.scrollTo(flick, far)
        tryVerify(() => flick.contentY > 0 && flick.contentY === flick.contentHeight + flick.bottomMargin - flick.height,
                  5000, "the page's end")
        wait(window.scrollSettle + 200)
        flick.contentY = 0
        const height = flick.contentHeight
        window.width = 240
        tryVerify(() => flick.contentHeight !== height, 5000, "the page changed")
        wait(100)
        compare(flick.contentY, 0)
    }

    // A tap on the tile itself, there and back; a tile of the running style does nothing.
    function test_style_by_tap() {
        const page = openAppearance()
        const old = window
        tile(page, "styleTile", startName).clicked()
        wait(50)
        compare(Appearance.window, old, "the running style: no new window")
        for (const name of [otherName, startName]) {
            const before = window
            tile(window.pageStack.currentItem, "styleTile", name).clicked()
            tryVerify(() => Appearance.window !== before)
            window = Appearance.window
            tryVerify(() => window.pageStack.depth === 3)
            standingPreviews(window.pageStack.currentItem)
        }
        compare(Appearance.running, startStyle)
        compare(Appearance.style, startStyle)
    }

    // The wizard: a change of style comes back on the same step.
    function test_style_in_wizard() {
        const welcome = push("WelcomePage")
        findChild(welcome, "welcomeNext").clicked()
        toStyle(otherStyle)
        compare(window.pageStack.depth, 2)
        compare(window.pageStack.currentItem.step, 1)
        compare(findChild(window.pageStack.currentItem, "welcomeSteps").currentIndex, 1)
        verify(findChildren(window.pageStack.currentItem, "styleTile").length >= 3)
    }

    // A note being typed when the window goes is saved (NoteRow); the service is the same one.
    function test_draft_kept() {
        const id = "draft-entry"
        const count = Practice.notes(id).length
        const service = Practice
        const page = window.pageStack.push(Qt.resolvedUrl("DraftPage.qml"), { entryId: id })
        findChild(page, "noteField").text = "Entwurf beim Stilwechsel"

        toStyle(otherStyle)
        const notes = Practice.notes(id)
        compare(notes.length, count + 1)
        verify(notes.some(n => n.text === "Entwurf beim Stilwechsel"))
        verify(Practice === service, "the service stayed")
    }

    // A popped page goes when its slide ends, while the app runs: only then is a draft saved
    // (NoteRow), and the system may kill the app any time after. A new height stops Kirigami's
    // slide without ending it: Shinki's head on the start menu, the keyboard closing, a turn.
    function test_popped_page_goes_data() {
        return [{ tag: "as it is", height: 800 }, { tag: "new height during the slide", height: 700 }]
    }
    function test_popped_page_goes(data) {
        const slidIn = page => () => page.mapToItem(window.contentItem, 0, 0).x === 0
        const id = "popped-entry-" + data.height
        const count = Practice.notes(id).length
        const draft = window.pageStack.push(Qt.resolvedUrl("DraftPage.qml"), { entryId: id })
        tryVerify(slidIn(draft), 5000, "slid in")
        findChild(draft, "noteField").text = "Entwurf beim Zurück"

        popPage()
        window.height = data.height
        tryVerify(() => Practice.notes(id).length === count + 1, 5000, "the draft is saved")
        window.height = 800

        const grades = push("GradesPage")
        tryVerify(slidIn(grades), 5000, "slid in")
        let gone = false
        grades.Component.destruction.connect(() => { gone = true })

        popPage()
        window.height = data.height
        tryVerify(() => gone, 5000, "GradesPage destroyed")
    }

    // A text still in focus when the style changes is saved: the window takes the focus first.
    function test_settings_field_kept() {
        const videos = push("VideosPage")
        const field = findChild(videos, "videoFolder")
        const before = Videos.folder
        const folder = uiDataDir + "/some-folder"
        window.requestActivate()
        tryVerify(() => window.active)
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = folder

        toStyle(otherStyle)
        compare(Videos.folder, folder)
        Videos.folder = before
    }

    // The same beside the list.
    function test_field_kept_beside_list() {
        const host = listHost(1280, 800)
        tryVerify(() => paneOf(host).item && paneOf(host).item.title === "Videos", 5000)
        const field = findChild(paneOf(host).item, "videoFolder")
        const before = Videos.folder
        const folder = uiDataDir + "/some-folder-beside"
        window.requestActivate()
        tryVerify(() => window.active)
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = folder

        toStyle(otherStyle)
        compare(Videos.folder, folder)
        Videos.folder = before
    }

    function paneOf(host) {
        return findChild(host, "pagePane")
    }
    function listHost(width, height) {
        window.width = width
        window.height = height
        wait(100)
        const host = push("ListAndPage", { listSource: "SettingsPage.qml" })
        tryVerify(() => host.width === width)
        return host
    }

    // Settings on a tablet, Appearance chosen in it, upright and sideways: a change of style, both
    // ways, and of language bring back the same thing in the same place, and rows still work.
    function test_list_and_page_kept_data() {
        return [ { tag: "upright", width: 800, height: 1280, upright: true },
                 { tag: "sideways", width: 1280, height: 800, upright: false } ]
    }
    function test_list_and_page_kept(data) {
        let host = listHost(1280, 800)
        tryVerify(() => host.wide)
        const chooseAppearance = () => {
            findChild(host, "appearanceButton").clicked()
            tryVerify(() => paneOf(host).item && paneOf(host).item.keptPage === "AppearancePage.qml", 5000)
        }
        chooseAppearance()
        window.setGeometry(window.x, window.y, data.width, data.height)
        tryVerify(() => host.width === data.width && host.wide === !data.upright)

        const paneFlick = () => paneOf(host).item.flickable
        const listFlick = () => findChild(host, "listPane").item.flickable
        tryVerify(() => paneFlick().contentHeight - paneFlick().height >= scrolled, 20000, "the page scrolls")
        paneFlick().contentY = scrolled
        const depth = window.pageStack.depth

        for (const style of [otherStyle, startStyle]) {
            toStyle(style)
            host = window.pageStack.currentItem
            compare(window.pageStack.depth, depth)
            compare(host.keptPage, "ListAndPage.qml")
            compare(host.everWide, true, "still a tablet")
            tryVerify(() => paneOf(host).item && paneOf(host).item.keptPage === "AppearancePage.qml", 5000, "the page came back")
            verify(paneOf(host).item.visible, "and shows")
            compare(host.showsPage, data.upright)
            compare(findChild(host, "listPane").visible, !data.upright)
            compare(host.title, data.upright ? "Appearance" : "Settings")
            // The old place, or the page's end where it is shorter in this style.
            tryVerify(() => paneFlick().contentY === Math.min(scrolled, paneFlick().contentHeight + paneFlick().bottomMargin - paneFlick().height)
                      && paneFlick().contentY > 0, 5000, "the same place on the page")
        }

        // A language: the same page, in the new words.
        const page = paneOf(host).item
        tile(page, "languageTile", "Deutsch").clicked()
        compare(paneOf(host).item, page)
        compare(host.title, data.upright ? "Darstellung" : "Einstellungen")
        compare(host.showsPage, data.upright)
        verify(page.visible)
        Appearance.setLanguage(Appearance.Language.English)
        compare(host.title, data.upright ? "Appearance" : "Settings")

        if (!data.upright) {
            return
        }
        // Back to the list, a row opens in the page again: a tablet still.
        window.back()
        tryVerify(() => !host.showsPage)
        tryVerify(() => window.pageStack.currentItem === host)
        compare(window.pageStack.depth, depth)
        findChild(host, "backupButton").clicked()
        tryVerify(() => host.showsPage && paneOf(host).item && paneOf(host).item.title === "Backup and sync", 5000)
        compare(window.pageStack.depth, depth)
    }

    // What stood there by itself comes back too, also upright in front of the list.
    function test_list_and_page_first_kept() {
        const uid = Courses.create("Kurs", "2030-01-05", "2030-01-06", "", "")
        window.width = 1280
        window.height = 800
        wait(100)
        const backup = { source: "BackupPage.qml", props: {} }
        let host = push("ListAndPage", { listSource: "CoursesPage.qml", first: backup })
        tryVerify(() => host.wide)
        tryVerify(() => paneOf(host).item && paneOf(host).item.title === "Backup and sync")

        toStyle(otherStyle)
        host = window.pageStack.currentItem
        tryVerify(() => paneOf(host).item && paneOf(host).item.title === "Backup and sync", 5000, "the same page")
        verify(!host.chosen)

        host.chosen = host.first
        window.setGeometry(window.x, window.y, 800, 1280)
        tryVerify(() => host.showsPage)
        toStyle(startStyle)
        host = window.pageStack.currentItem
        tryVerify(() => host.showsPage && paneOf(host).item && paneOf(host).item.title === "Backup and sync", 5000)
        window.back()
        tryVerify(() => !host.showsPage)

        popPage()
        Courses.remove(uid)
    }

    // German and English both ways, with pages there before the change: their texts, models built
    // in C++ (Practice.levelNames, Appearance.styles, AllNotes), dates and numbers.
    function test_language_both_ways() {
        const page = openAppearance()
        const settings = window.pageStack.get(1)
        const start = window.pageStack.get(0)
        const first = window
        const todayEnglish = findChild(start, "todayTile").text

        // A note on a technique that left the programme: its row's title comes from the catalog.
        verify(Practice.addNote("gone-from-programme", "note"))
        const notes = allNotes.createObject(test)
        const goneTitle = () => notes.rows.find(r => r.entry === "gone-from-programme").title
        compare(goneTitle(), "Technique no longer in the programme")
        compare(page.title, "Appearance")
        compare(Practice.levelNames[4], "exam-ready")

        tile(page, "languageTile", "Deutsch").clicked()
        compare(Appearance.language, Appearance.Language.German)
        compare(Appearance.window, first, "the window stays")
        compare(page.title, "Darstellung")
        compare(settings.title, "Einstellungen")
        verify(findChild(settings, "appearanceButton").subtitle.indexOf("Stil") === 0)
        verify(findChild(start, "todayTile").text !== todayEnglish)
        compare(Practice.levelNames[4], "prüfungsreif")
        compare(goneTitle(), "Technik nicht mehr im Programm")
        tryVerify(() => findChildren(page, "styleTile").some(t => t.hint === "Kante in hellem Leinen"))
        compare(Qt.locale().name.substring(0, 2), "de")
        compare(Number(1.5).toLocaleString(Qt.locale(), "f", 1), "1,5")
        compare(new Date(2026, 0, 2).toLocaleDateString(Qt.locale(), "MMMM"), "Januar")
        // Qt's own words (a dialog's Cancel) follow, where Qt's catalog is installed.
        if (uiCatalog.qtCatalogThere()) {
            compare(qsTranslate("QPlatformTheme", "Cancel"), "Abbrechen")
        }
        standingPreviews(page)
        shot("look-de-" + startName)

        tile(page, "languageTile", "English").clicked()
        compare(page.title, "Appearance")
        compare(settings.title, "Settings")
        compare(findChild(start, "todayTile").text, todayEnglish)
        compare(Practice.levelNames[4], "exam-ready")
        compare(goneTitle(), "Technique no longer in the programme")
        compare(Qt.locale().name.substring(0, 2), "en")
        compare(Number(1.5).toLocaleString(Qt.locale(), "f", 1), "1.5")
        compare(new Date(2026, 0, 2).toLocaleDateString(Qt.locale(), "MMMM"), "January")
        compare(qsTranslate("QPlatformTheme", "Cancel"), "Cancel")
        notes.destroy()
    }

    // The programme data in the app's language (x_en of mitori-daten), with pages there before the
    // change: the start page's tiles, the programme dates, a note's technique (AllNotes), the
    // glossary and the search; ids stay.
    function test_programme_language() {
        Programme.discipline = "aikido"
        const page = openAppearance()
        const start = window.pageStack.get(0)
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "language"))
        const notes = allNotes.createObject(test)
        const noteTitle = () => notes.rows.find(r => r.entry === entry.id).title
        const hint = name => findChild(start, name).hint
        const dates = () => findChildren(page, "programmeDate").map(l => l.text).join("\n")
        const meaning = word => Glossary.words.find(w => w.word === word).meaning

        const english = () => {
            verify(/\d(st|nd|rd|th) Kyu/.test(hint("programmeTile")), hint("programmeTile"))
            verify(/\d(st|nd|rd|th) Kyu/.test(hint("examTile")), hint("examTile"))
            verify(dates().includes("As of"), dates())
            verify(noteTitle().includes("5th Kyu"), noteTitle())
            compare(meaning("Koshi-nage"), "hip throw")
            verify(Programme.search("2 variants").length > 0)
            compare(Programme.search("2 Arten").length, 0)
            compare(Programme.entries("aikido", "k5").find(r => r.kind === "entry").id, entry.id)
        }
        english()

        tile(page, "languageTile", "Deutsch").clicked()
        verify(/\d\. Kyu/.test(hint("programmeTile")), hint("programmeTile"))
        verify(/\d\. Kyu/.test(hint("examTile")), hint("examTile"))
        verify(dates().includes("Stand"), dates())
        verify(noteTitle().includes("5. Kyu"), noteTitle())
        compare(meaning("Koshi-nage"), "Hüftwurf")
        verify(Programme.search("2 Arten").length > 0)
        compare(Programme.search("2 variants").length, 0)

        tile(page, "languageTile", "English").clicked()
        english()
        Practice.deleteNote(Practice.notes(entry.id)[0].uid)
        notes.destroy()
    }

    // The language survives a change of style, and the new window's pages speak it.
    function test_language_then_style() {
        openAppearance()
        Appearance.setLanguage(Appearance.Language.German)
        toStyle(otherStyle)
        compare(window.pageStack.currentItem.title, "Darstellung")
        compare(window.pageStack.get(1).title, "Einstellungen")
        Appearance.setLanguage(Appearance.Language.English)
        compare(window.pageStack.currentItem.title, "Appearance")
    }

    // The previews: each style and language has one, drawn by the style's own components, its
    // texts in the language asked for; a tap on one applies it.
    function test_previews() {
        const page = openAppearance()
        const previews = standingPreviews(page)
        const styles = findChildren(page, "styleTile")
        const languages = findChildren(page, "languageTile")
        compare(languages.length, 3)
        compare(previews.length, styles.length + languages.length)

        const shinki = previews.find(p => p.look === Appearance.Style.Shinki)
        const leinen = previews.find(p => p.look === Appearance.Style.Leinen)
        verify(uiCatalog.drawnByShinki(findChild(shinki.sample, "sampleButton")), "Shinki's button")
        verify(!uiCatalog.drawnByShinki(findChild(leinen.sample, "sampleButton")), "Kante's button")

        // The language's tiles come after the styles': their words in the running style.
        const german = previews[styles.length + Appearance.Language.German]
        const english = previews[styles.length + Appearance.Language.English]
        compare(findChild(german.sample, "sampleChip").text, "prüfungsreif")
        compare(findChild(english.sample, "sampleChip").text, "exam-ready")
        compare(uiCatalog.drawnByShinki(findChild(german.sample, "sampleButton")), uiShinki)
        shot("look-previews-" + startName)

        // A tap on the sample chooses too.
        const flick = page.flickable
        flick.contentY = german.mapToItem(flick.contentItem, 0, 0).y - 20
        wait(50)
        const before = window
        mouseClick(german)
        compare(Appearance.language, Appearance.Language.German)
        compare(Appearance.window, before)
    }

    Component {
        id: allNotes

        AllNotes {
            practice: Practice
            courses: Courses
            programme: Programme
        }
    }
}
