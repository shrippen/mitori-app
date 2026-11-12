import QtQuick
import QtMultimedia
import QtTest
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import Kante
import Mitori

// The pages as the user meets them: start menu, programme, technique sheet, comment, player.
// Screenshots go to uiShotsDir (for a look, not compared).
TestCase {
    id: test

    name: "Ui"
    when: windowShown

    property var window: null
    // The video folder before a case put stand-ins in its place; null: nothing to put back ("" is
    // one too: none, without MITORI_VIDEOS).
    property var realFolder: null

    // A run stays in one day: the course calendar is written at its start, ratings count per day.
    // In America/Los_Angeles, midnight during a run (08:00 UTC in winter): test_9m_courses 11 days
    // for 12, test_9o_grades, test_9z_stats 2 practice days for 1.
    function test_0_run_stays_in_its_day() {
        const kHoursLeft = 11
        for (let utc = 0; utc < 24; ++utc) {
            const west = uiCatalog.hoursWest(utc)
            verify(west > 0, "west of UTC at " + utc)
            const local = (utc - west + 24) % 24
            verify(23 - local >= kHoursLeft, "at " + utc + " UTC the run starts at " + local + " here")
        }
        verify(new Date().getTimezoneOffset() > 0, "this run is west of UTC")
    }

    function initTestCase() {
        const component = Qt.createComponent("Mitori", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null, { width: 420, height: 800 })
        window.show()
        tryVerify(() => window.pageStack.currentItem !== null)
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

    // The page on top stands: a page takes no click while it slides, however long that takes.
    function slidIn() {
        const page = window.pageStack.currentItem
        tryVerify(() => !window.pageStack.columnView.moving && page.enabled
                        && Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 15000, "the page has slid in")
    }

    // A failed or skipped case (no videos, as in the CI) leaves no tablet window and no pages
    // to the next ones: each starts on the start page.
    function cleanup() {
        window.width = 420
        window.height = 800
        while (window.pageStack.depth > 1)
            popPage()
        if (realFolder !== null) {
            Videos.folder = realFolder
            realFolder = null
        }
        // A case that failed with a Lernpaket on the shelf leaves none to the next ones.
        uiCatalog.removeLesson(lessonId)
        uiCatalog.removeLesson(unsupportedId)
        Videos.showSubtitles()
    }

    function cleanupTestCase() {
        window.destroy()
    }

    // The page stack, or with `whole` the window with its overlay (dialogs, sheets).
    function shot(name, whole) {
        wait(800)       // Kirigami slides pages in
        let done = false
        const item = whole ? window.overlay.parent : window.pageStack
        item.grabToImage(result => {
            result.saveToFile(uiShotsDir + "/" + name + ".png")
            done = true
        })
        tryVerify(() => done)
    }

    // A start tile into view (the column of tiles is taller than a phone), then a click on it.
    function clickTile(tile) {
        const f = window.pageStack.items[0].flickable
        const y = tile.mapToItem(f.contentItem, 0, 0).y
        f.contentY = Math.max(0, Math.min(y - 20, f.contentHeight - f.height))
        wait(50)
        mouseClick(tile)
    }

    // WCAG contrast of two colours (text over ground, alpha laid on the ground).
    function contrast(fore, back) {
        const lin = c => c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
        const lum = c => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
        const laid = Qt.rgba(fore.r * fore.a + back.r * (1 - fore.a), fore.g * fore.a + back.g * (1 - fore.a),
                             fore.b * fore.a + back.b * (1 - fore.a), 1)
        const a = lum(laid), b = lum(back)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }

    // Every item below `item`, for what no objectName marks.
    function allChildren(item) {
        let all = []
        for (let i = 0; i < item.children.length; i++) {
            all.push(item.children[i])
            all = all.concat(allChildren(item.children[i]))
        }
        return all
    }

    function push(page, properties) {
        window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/" + page + ".qml"), properties || {})
        tryVerify(() => window.pageStack.currentItem && window.pageStack.currentItem.title !== undefined)
        // A page that makes a part after it is drawn (TodayPage): with it.
        tryVerify(() => window.pageStack.currentItem.built !== false)
        return window.pageStack.currentItem
    }

    // The first-start wizard: welcome, style, tour; Start marks it done and goes back to the start menu.
    function test_0_welcome() {
        const page = push("WelcomePage")
        const steps = findChild(page, "welcomeSteps")
        const next = findChild(page, "welcomeNext")
        compare(steps.currentIndex, 0)
        // Screen readers hear the steps' states in the app's language, not Kante's German default.
        compare(findChild(page, "welcomeStepper").stateNames.current, "current")
        shot("0-welcome")
        next.clicked()
        compare(steps.currentIndex, 1)
        const tiles = findChildren(page, "styleTile")
        verify(tiles.length >= 2, "Kante, Leinen at least")
        // A real change of style has its own cases (tst_look.qml): here the running one.
        const running = tiles.find(t => t.checked)
        verify(running)
        running.clicked()
        compare(Appearance.window, window)
        shot("0-welcome-style")
        next.clicked()
        compare(steps.currentIndex, 2)
        compare(findChildren(page, "tourRow").length, 5)
        shot("0-welcome-tour")
        next.clicked()
        tryVerify(() => window.pageStack.depth === 1)
        verify(Appearance.welcomed)
    }

    // An older version's grade is the practice grade at the first start, chosen by hand.
    function test_0a_practice_migrated() {
        compare(PracticeGrade.grade("shinkitoho"), "chuden")
        verify(PracticeGrade.manual("shinkitoho"))
        compare(PracticeGrade.grade("aikido"), "k5", "nothing stored, nothing entered: the first grade")
        verify(!PracticeGrade.manual("aikido"))
        PracticeGrade.setGrade("shinkitoho", "shoden")
        verify(!PracticeGrade.manual("shinkitoho"))
    }

    // Settings → Appearance: the style and language tiles with their previews, about Mitori.
    function test_0b_appearance() {
        const settings = push("SettingsPage")
        findChild(settings, "appearanceButton").clicked()
        tryVerify(() => window.pageStack.currentItem.title === "Appearance")
        const page = window.pageStack.currentItem
        compare(findChildren(page, "languageTile").length, 3)
        compare(findChildren(page, "languageTile").find(t => t.checked).text, "System")
        verify(findChild(page, "aboutText").text.indexOf(Appearance.version) >= 0)
        verify(findChild(page, "licences").text.indexOf("Frank Osterfeld") >= 0)
        verify(Appearance.version !== "")
        verify(/^\D*\d{4}\.\d{1,2}\.\d+$/.test(findChild(page, "dataVersion").text))
        shot("0b-appearance")
    }

    function test_1_start() {
        compare(Programme.errorString, "")
        // The run's style reached Look (the file selector "shinki" in ui_shinki).
        compare(Look.shinki, uiShinki)
        compare(window.pageStack.currentItem.title, "Mitori 見取り")
        // The tiles in the decided order: Today, Exam, Statistics, Courses (clickdummy "Startmenü").
        const start = window.pageStack.currentItem
        const order = ["todayTile", "examTile", "statsTile", "coursesTile", "mapTile", "glossaryTile", "notesTile"]
        const items = order.map(n => findChild(start, n))
        const at = it => it.mapToItem(start, 0, 0)
        for (let i = 1; i < items.length; i++) {
            const a = at(items[i - 1]), b = at(items[i])
            verify(b.y > a.y || (b.y === a.y && b.x > a.x), order[i - 1] + " before " + order[i])
        }
        // The discipline by its short name (clickdummy: "Aikido · 5. Kyu · 7 of 20 exam-ready").
        const short = Programme.disciplines.find(d => d.id === Programme.discipline).kurzname
        verify(findChild(start, "programmeTile").hint.startsWith(short + " · "), findChild(start, "programmeTile").hint)
        // The tiles fill in after the page is drawn (StartBoard, off the GUI thread).
        tryVerify(() => order.concat("programmeTile").every(n => findChild(start, n).filled))
        verify(findChild(start, "todayTile").hint.endsWith(" · " + short), findChild(start, "todayTile").hint)
        shot("1-start")
    }

    // Under Shinki the symbols on red and on ink are white (bible section 5), on every platform:
    // the play button and a checked tool button (loop, sound).
    function test_1c_icons_on_red() {
        if (!uiShinki) {
            skip("Shinki only")
        }
        const play = createTemporaryQmlObject("import Mitori; LookPlayButton {}", window.contentItem)
        const loop = createTemporaryQmlObject(
            "import QtQuick.Controls; import Mitori; LookToolButton { x: 100; checkable: true; checked: true; "
            + "icon.name: 'media-playlist-repeat'; display: AbstractButton.IconOnly }", window.contentItem)
        for (const button of [play, loop]) {
            tryVerify(() => button.width > 0)
            wait(100)
            const image = grabImage(button)
            // The brightest pixel inside the round ground (the corners show the page): white.
            let lightest = 0
            const cx = image.width / 2, cy = image.height / 2, r = Math.min(cx, cy) - 3
            for (let x = 0; x < image.width; x++) {
                for (let y = 0; y < image.height; y++) {
                    const c = image.pixel(x, y)
                    if ((x - cx) * (x - cx) + (y - cy) * (y - cy) < r * r) {
                        lightest = Math.max(lightest, Math.min(c.r, c.g, c.b))
                    }
                }
            }
            verify(lightest > 0.9, button + ": the symbol is not white, lightest " + lightest)
        }
    }

    // A dialog of the content's size (Fit): its content measures the text.
    function test_1d_dialog_fit() {
        const dialog = createTemporaryQmlObject(
            "import QtQuick.Controls; import Mitori; LookDialog { Label { text: 'Hello' } }", window.contentItem)
        verify(dialog.contentWidth > 0, "content width " + dialog.contentWidth)
        tryVerify(() => dialog.contentHeight > 0, 1000, "content height " + dialog.contentHeight)  // Kante: once built
    }

    // A date field says when its text is no date (pages lock their button on it), and its month
    // opens inside the window, also at the window's bottom.
    function test_1e_date_field() {
        const field = createTemporaryQmlObject(
            "import Mitori; LookDateField { format: 'yyyy-MM-dd'; date: new Date(2026, 0, 5) }", window.contentItem)
        field.forceActiveFocus()
        keySequence("Ctrl+A")
        keyClick(Qt.Key_Delete)
        for (const c of "2026-02-31") {
            keyClick(c)
        }
        keyClick(Qt.Key_Return)
        compare(field.invalid, true, "31 February is no date")

        // Opened once at the top, then the page scrolls it to the bottom (as on a phone).
        const popup = findChild(field, "popup")
        field.open()
        tryVerify(() => popup.opened)
        field.close()
        tryVerify(() => !popup.visible)
        field.y = window.contentItem.height - field.height - 10     // below a head the content is shorter
        field.open()
        tryVerify(() => popup.opened)
        const top = popup.contentItem.mapToItem(null, 0, 0).y - popup.topPadding
        verify(top >= 0 && top + popup.height <= window.height, "month inside the window: " + top + " + " + popup.height)
        field.close()
        tryVerify(() => !popup.visible)

        // A month of six week rows after one of five (January, then March 2026), at the bottom:
        // still inside the window and off the field.
        field.date = new Date(2026, 0, 5)
        field.y = 0
        field.open()
        tryVerify(() => popup.opened)
        field.close()
        tryVerify(() => !popup.visible)
        field.date = new Date(2026, 2, 30)
        field.y = 392
        field.open()
        tryVerify(() => popup.opened)
        wait(50)
        const six = popup.contentItem.mapToItem(null, 0, 0).y - popup.topPadding
        const fieldTop = field.mapToItem(null, 0, 0).y
        verify(six >= 0 && six + popup.height <= window.height, "six rows inside the window: " + six + " + " + popup.height)
        verify(six + popup.height <= fieldTop || six >= fieldTop + field.height, "the month leaves the field free")
        field.close()
    }

    // Under Shinki the window carries Shinki's own head (bible section 5, Kopf), not Kirigami's
    // bar: back as a red column naming the page before, the title in PT Sans bold, the page's
    // actions.
    function test_1f_shinki_head() {
        if (!uiShinki) {
            skip("Shinki only")
        }
        compare(window.pageStack.globalToolBar.actualStyle, Kirigami.ApplicationHeaderStyle.None)
        const head = findChild(window, "lookHead")
        verify(head && head.visible, "Shinki's head")
        compare(head.title, "Mitori")
        compare(head.kanji, "見取り")
        verify(!findChild(head, "headBack").enabled, "no way back from the start menu")
        const height = head.height

        // Same height on every page: Kirigami keeps a page that leaves while the view's height
        // changes (test_4s_player_swipe).
        const page = push("CoursesPage")
        tryCompare(head, "title", page.title)
        const back = findChild(head, "headBack")
        verify(back.enabled)
        compare(head.height, height, "the head keeps its height")
        compare(back.text, "‹ MITORI", "the title before, without its Japanese")
        verify(findChildren(head, "headAction").length >= 1, "the page's actions")
        shot("1f-shinki-head", true)
        mouseClick(back)
        tryCompare(window.pageStack, "depth", 1)

        // Back by key (goBack) keeps the page ahead; the head names the page before the current.
        push("CoursesPage")
        window.pageStack.goBack()
        tryCompare(window.pageStack, "currentIndex", 0)
        compare(head.title, "Mitori")
        verify(!back.enabled, "no way back from the start menu")
    }

    function test_2_programme() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        compare(page.grade, "k5")
        verify(page.rows.filter(r => r.kind === "entry").length === 20)
        // The list scrolls under the grade chips, not over them.
        verify(findChild(page, "programmeScroll").clip, "the list is clipped")
        shot("2-programme-aikido")

        // A tap on the chosen grade keeps it chosen (the chip does not toggle off).
        const chips = findChild(page, "gradeChips")
        const k5 = chips.itemAt(page.grades.findIndex(g => g.id === "k5"))
        mouseClick(k5)
        compare(page.grade, "k5")
        verify(k5.checked, "the chosen grade stays checked")
        for (let i = 0; i < chips.count; i++) {
            compare(chips.itemAt(i).checked, chips.itemAt(i) === k5, chips.itemAt(i).text)
        }

        Programme.discipline = "shinkitoho"
        page.grade = PracticeGrade.grade("shinkitoho")
        compare(page.grade, "shoden")
        verify(page.rows.some(r => r.kind === "info"))
        shot("3-programme-shinkitoho")
        popPage()
    }

    function test_2b_sheet() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        const entry = page.rows.find(r => r.kind === "entry" && r.attack)
        page.open(entry)
        const sheet = findChild(page, "techniqueSheet")
        verify(sheet)
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, entry.id)
        // The head: attack, addition and grade above the name (clickdummy "Blatt").
        const eyebrow = findChild(sheet.contentItem, "sheetEyebrow")
        verify(eyebrow.text.indexOf(entry.attack) >= 0 && eyebrow.text.indexOf("5. Kyu") >= 0, eyebrow.text)
        // Without the video on the device: what to do (the grade has a video: enter the code).
        const hint = findChild(sheet.contentItem, "sheetNoVideo")
        compare(hint.visible, !sheet.hasVideo)
        if (!sheet.hasVideo) {
            verify(findChild(sheet.contentItem, "sheetCodeButton").visible)
        }
        // The notes button counts them, the last note has its date.
        Practice.addNote(entry.id, "Schritt kleiner")
        const notes = findChild(sheet.contentItem, "sheetNotesButton")
        verify(notes.text.indexOf("(1)") >= 0, notes.text)
        const lastNote = findChild(sheet.contentItem, "sheetLastNote")
        verify(lastNote.text.indexOf(new Date().toLocaleDateString(Qt.locale(), Locale.ShortFormat)) >= 0, lastNote.text)
        // The sheet grows with what it shows (a new last note): the buttons stay in it, unscrolled.
        wait(500)       // the layout takes the new row a frame later
        verify(sheet.flickable.contentHeight <= sheet.flickable.height + 0.5,
               "content " + sheet.flickable.contentHeight + " of " + sheet.flickable.height)
        verify(sheet.y + sheet.height <= sheet.parent.height + 0.5)
        shot("2b-sheet", true)
        for (const n of Practice.notes(entry.id)) {
            Practice.deleteNote(n.uid)
        }
        sheet.close()
        popPage()
    }

    // The sheet stays inside a narrow phone, and names the Japanese once.
    function test_2b_sheet_fits() {
        const width = window.width
        window.width = 360
        const page = push("ProgrammePage")
        page.open(page.rows.find(r => r.kind === "entry" && r.jp))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        verify(sheet.x >= 0 && sheet.x + sheet.width <= window.width + 0.5,
               "sheet " + sheet.x + " + " + sheet.width + " of " + window.width)
        if (Look.shinki) {
            const japanese = allChildren(sheet.contentItem).filter(c => c.visible && c.text === sheet.entry.jp)
            compare(japanese.length, 1, "the Japanese once")
        }
        sheet.close()
        popPage()
        window.width = width
    }

    // A technique without any video (Shinki Toho Jun-Menkyo, the last grade with forms): the
    // sheet says so, no code to enter.
    function test_2b_sheet_no_video() {
        Programme.discipline = "shinkitoho"
        const grades = Programme.grades("shinkitoho")
        const last = grades[grades.length - 1]
        const before = PracticeGrade.grade("shinkitoho")
        PracticeGrade.setGrade("shinkitoho", last.id)
        const page = push("ProgrammePage")
        const entry = page.rows.find(r => r.kind === "entry" && !r.video)
        verify(entry, "an entry without a video in " + last.name)
        page.open(entry)
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        verify(findChild(sheet.contentItem, "sheetNoVideo").visible)
        verify(!findChild(sheet.contentItem, "sheetCodeButton").visible)
        sheet.close()
        popPage()
        PracticeGrade.setGrade("shinkitoho", before)
        Programme.discipline = "aikido"
    }

    // Shinki Toho Shoden: the Kamae exercise is one row; its sheet lists the 26 positions.
    function test_2g_kamae_sheet() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        const page = push("ProgrammePage")
        const kamae = page.rows.filter(r => r.kind === "entry" && r.id.startsWith("shinkitoho/kamae"))
        compare(kamae.length, 1)
        compare(kamae[0].id, "shinkitoho/kamae")
        page.open(kamae[0])
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.steps.length, 26)
        const list = findChild(sheet.contentItem, "sheetSteps")
        tryCompare(list, "count", 26)
        const steps = findChildren(list, "step")
        compare(steps[2].modelData.title, "Seigan")
        compare(steps[11].modelData.title, "Seigan")
        shot("2g-sheet-kamae", true)
        sheet.close()
        tryVerify(() => !sheet.opened)
        // A technique without positions shows none.
        page.open(page.rows.find(r => r.kind === "entry" && r.id.startsWith("shinkitoho/odachi/")))
        tryVerify(() => sheet.opened)
        compare(sheet.steps.length, 0)
        verify(!findChild(sheet.contentItem, "sheetSteps").visible)
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()
    }

    // A small phone: the Kamae sheet is taller than the window; the keys scroll it.
    function test_2h_sheet_keys() {
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        window.width = 360
        window.height = 640
        const page = push("ProgrammePage")
        page.open(page.rows.find(r => r.id === "shinkitoho/kamae"))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        wait(500)
        const flick = sheet.flickable
        verify(flick && flick.contentHeight > flick.height, "taller than the window")
        compare(flick.contentY, 0)
        keyClick(Qt.Key_Down)
        tryVerify(() => flick.contentY > 0, 1000, "Down scrolls")
        const down = flick.contentY
        keyClick(Qt.Key_PageDown)
        tryVerify(() => flick.contentY > down, 1000, "Page Down scrolls")
        keyClick(Qt.Key_End)
        tryVerify(() => Math.abs(flick.contentY - (flick.contentHeight - flick.height)) < 2, 1000, "End to the last position")
        keyClick(Qt.Key_Home)
        tryCompare(flick, "contentY", 0)
        // With the focus on Close in the header (outside the content) too. Under Shinki the close
        // lives inside the sheet head (the content), not in sheet.header: search both.
        const close = findCloseButton(sheet.header) || findCloseButton(sheet.contentItem)
        verify(close, "the header's close button")
        close.forceActiveFocus()
        verify(close.activeFocus)
        keyClick(Qt.Key_PageDown)
        tryVerify(() => flick.contentY > 0, 1000, "Page Down scrolls from Close")
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()
    }

    function findCloseButton(item) {
        if (!item) {
            return null
        }
        if (item.icon !== undefined && item.icon.name.startsWith("window-close") && item.visible) {
            return item
        }
        for (let i = 0; i < item.children.length; i++) {
            const found = findCloseButton(item.children[i])
            if (found) {
                return found
            }
        }
        return null
    }

    // Rating in the sheet: the list row shows the level as dots, the sheet the last rating.
    function test_2d_rate_in_sheet() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        const entry = page.rows.find(r => r.kind === "entry")
        compare(Practice.level(entry.id), 0)
        page.open(entry)
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const picker = findPicker(window.overlay, entry.id)
        verify(picker, "the sheet has the level picker for its entry")
        // The sheet shows its content, not only its title: the picker lies inside it, visibly.
        wait(300)
        verify(picker.height > 0 && picker.width > 0, "picker has a size")
        const at = picker.mapToItem(null, 0, 0)
        const box = sheet.background.mapToItem(null, 0, 0)
        verify(at.y >= box.y && at.y + picker.height <= box.y + sheet.background.height,
               "picker within the sheet (" + at.y + " + " + picker.height + " outside " + box.y + " + " + sheet.background.height + ")")
        wait(500)       // the sheet slides in
        mouseClick(picker, picker.width * 5 / 8, picker.height / 2)     // the third of four buttons
        tryCompare(Practice, "revision", 1)
        compare(Practice.level(entry.id), 3)
        compare(picker.value, 3)
        shot("2d-sheet-rated", true)
        // The grade's bar counts the new rating.
        const stand = findChild(page, "gradeStand")
        verify(stand)
        compare(stand.counts[3], 1)
        compare(stand.counts[0], stand.ids.length - 1)
        sheet.close()
        tryVerify(() => !sheet.opened)
        shot("2e-programme-rated")
        popPage()
    }

    // A row near the bottom of the window opens its sheet too (Kirigami keeps its notification
    // area in the overlay there; it must not swallow the taps).
    function test_2f_tap_row_at_bottom() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        wait(500)
        const sheet = findChild(page, "techniqueSheet")
        const list = findChild(page, "programmeList")
        // An entry row brought to the bottom edge of the list.
        const last = page.rows.map(r => r.kind).lastIndexOf("entry")
        list.positionViewAtIndex(last - 1, ListView.End)
        wait(300)
        let lowest = null, lowestY = -1
        for (const row of list.contentItem.children) {
            if (!row.visible || !row.modelData || row.modelData.kind !== "entry") {
                continue
            }
            const y = row.mapToItem(null, 0, 0).y
            if (y + row.height <= window.height && y > lowestY) {
                lowest = row
                lowestY = y
            }
        }
        verify(lowest && lowestY + lowest.height > window.height - 60, "an entry row at the bottom edge (" + lowestY + ")")
        mouseClick(lowest, lowest.width / 3, lowest.height / 2)
        tryVerify(() => sheet.opened, 2000, "a tap near the bottom opens the sheet")
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()
    }

    // The visible level picker of an entry (in the overlay: sheets of earlier pages may linger).
    function findPicker(item, id) {
        if (!item) {
            return null
        }
        if (item.picked !== undefined && item.focusLevel !== undefined && item.parent.entry === id && item.visible) {
            return item
        }
        // The ratings of Kino (PlayerRatings): the player's row or column.
        if (item.picked !== undefined && item.vertical !== undefined && item.entry === id && item.visible) {
            return item
        }
        for (let i = 0; i < item.children.length; i++) {
            const found = findPicker(item.children[i], id)
            if (found) {
                return found
            }
        }
        return null
    }

    // Entering the video folder in the settings: the list behind them shows the videos at once.
    function test_2c_folder_change() {
        const real = Videos.folder
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        Videos.folder = uiShotsDir
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        verify(!page.hasVideo)
        Videos.folder = real
        verify(page.hasVideo, "the list follows the folder")
        popPage()
    }

    // Keys reach the page only in an active window with the focus on the page.
    function activate(page) {
        window.requestActivate()
        tryVerify(() => window.active)
        page.forceActiveFocus()
    }

    // Escape goes back one page, like the Back key, from any page above the start page.
    function test_2i_escape_back() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        compare(window.pageStack.depth, 2)
        slidIn()
        activate(page)
        keyClick(Qt.Key_Escape)
        tryCompare(window.pageStack, "depth", 1, 5000, "Escape leaves the programme")

        const entry = Programme.entry("shinkitoho/odachi/1")
        push("CommentPage", { entry: entry })
        compare(window.pageStack.depth, 2)
        slidIn()
        activate(window.pageStack.currentItem)
        keyClick(Qt.Key_Escape)
        tryCompare(window.pageStack, "depth", 1, 5000, "Escape leaves the comment")

        // On the start page there is nothing to leave.
        keyClick(Qt.Key_Escape)
        wait(200)
        compare(window.pageStack.depth, 1)
    }

    // Escape in a field with text leaves the field, not the page: the typed text stays.
    function test_2i_escape_field_first() {
        const page = push("SearchPage")
        slidIn()
        window.requestActivate()
        tryVerify(() => window.active)
        const field = findChild(page, "searchField")
        field.forceActiveFocus()
        keyClick(Qt.Key_I)
        compare(field.text, "i")
        keyClick(Qt.Key_Escape)
        wait(300)
        compare(window.pageStack.depth, 2, "Escape in the field keeps the page")
        compare(field.text, "i")
        verify(!field.activeFocus, "the field gave up the keys")
        keyClick(Qt.Key_Escape)
        tryCompare(window.pageStack, "depth", 1, 5000, "the next Escape leaves the page")
    }

    // An open sheet takes the Escape; the page stays until the next one.
    function test_2i_escape_sheet_first() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        slidIn()
        activate(page)
        page.open(page.rows.find(r => r.kind === "entry" && r.attack))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        keyClick(Qt.Key_Escape)
        tryVerify(() => !sheet.opened, 5000, "Escape closes the sheet")
        wait(300)
        compare(window.pageStack.depth, 2)
        activate(page)
        keyClick(Qt.Key_Escape)
        tryCompare(window.pageStack, "depth", 1, 5000, "the next Escape leaves the page")
    }

    function test_3_comment() {
        const entry = Programme.entry("shinkitoho/odachi/1")
        verify(entry.comment)
        const page = push("CommentPage", { entry: entry })
        compare(page.title, entry.comment.titel)
        shot("4-comment")
        popPage()
    }

    // A comment with headings ("## Rei-ho …" in the Kumidachi text): headings, not raw marks;
    // the full title in the column (the header elides it).
    function test_3_comment_headings() {
        const all = []
        for (const g of Programme.grades("shinkitoho")) {
            for (const r of Programme.entries("shinkitoho", g.id)) {
                if (r.comment && r.comment.text && r.comment.text.indexOf("\n## ") >= 0) {
                    all.push(r)
                }
            }
        }
        verify(all.length > 0, "a comment with a heading")
        const page = push("CommentPage", { entry: all[0] })
        const headings = findChildren(page, "commentHeading")
        verify(headings.length > 0)
        verify(headings.every(h => !h.text.startsWith("#")), headings.map(h => h.text).join(" | "))
        verify(findChildren(page, "commentParagraph").every(p => !p.text.startsWith("#")))
        compare(findChild(page, "commentTitle").text, all[0].comment.titel)
        // A long title wraps, also where Kante draws it (Kante 1.68), never ends in "…".
        const long = Programme.entries("shinkitoho", Programme.grades("shinkitoho").find(g => Programme.entries("shinkitoho", g.id)
                         .some(r => r.comment && r.comment.titel.length > 60)).id).find(r => r.comment && r.comment.titel.length > 60)
        const longPage = push("CommentPage", { entry: long })
        const title = findChild(longPage, "commentTitle")
        // The text Kante draws over the hidden original: the child label with the same text.
        const drawn = Array.from(title.children).find(c => c.text === title.text && c.lineCount !== undefined)
        tryVerify(() => title.width <= longPage.width, 2000, "the title stays in the page: " + title.width)
        verify(!drawn || !drawn.visible || (!drawn.truncated && drawn.lineCount > 1), long.comment.titel)
        verify(!title.truncated)
        popPage()
        shot("4-comment-headings")
        popPage()
    }

    function test_3b_settings() {
        failOnWarning(/Binding loop/)       // the merge dialog measured its text against itself
        const page = push("SettingsPage")
        compare(page.title, "Settings")
        // The style's ground, not the platform's (ScrollablePage does not inherit the theme).
        verify(Qt.colorEqual(page.background.color, Look.backgroundColor),
               page.background.color + " is not " + Look.backgroundColor)
        // and the scope reaches the page's controls: the style's text colour, not the platform's.
        verify(Qt.colorEqual(page.Kirigami.Theme.textColor, Look.textColor),
               page.Kirigami.Theme.textColor + " is not " + Look.textColor)
        // Each row leads with its kanji (clickdummy `EINST`); under Shinki drawn in Noto Serif JP,
        // whose subset carries them (not a system fallback).
        for (const [row, kanji] of [["videosButton", "映"], ["backupButton", "保"], ["appearanceButton", "色"]]) {
            const item = findChild(page, row)
            compare(item.glyph, kanji, row)
            if (Look.shinki) {
                compare(findChild(item, "rowGlyph").font.family, "Noto Serif JP", row)
            }
        }
        shot("4b-settings")
        // Each setting leads to its page.
        for (const [row, title] of [["videosButton", "Videos"], ["backupButton", "Backup and sync"], ["appearanceButton", "Appearance"]]) {
            findChild(page, row).clicked()
            tryVerify(() => window.pageStack.currentItem !== page && window.pageStack.currentItem.title === title)
            popPage()
            tryVerify(() => window.pageStack.currentItem === page)
        }
        popPage()
    }

    // Sync off: its rows go with their fields, no name stands over nothing.
    function test_3b_settings_sync_off() {
        Sync.enabled = false
        const page = push("BackupPage")
        const names = ["Folder on the server:", "User:", "App password:", "This device:"].map(t => qsTr(t))
        const shown = allChildren(page.contentItem).filter(c => names.indexOf(c.text) >= 0 && c.visible)
        compare(shown.length, 0, "rows without a field: " + shown.map(c => c.text))
        popPage()
    }

    // Sync: switched on it shows the account; without one "Sync now" says what is missing. The
    // conflicts page without conflicts says so.
    function test_3d_sync() {
        const page = push("BackupPage")
        verify(!findChild(page, "syncServer").visible)
        Sync.enabled = true
        tryVerify(() => findChild(page, "syncServer").visible)
        compare(findChild(page, "syncState").text, "Not synced yet.")
        verify(!Sync.syncNow())
        verify(findChild(page, "syncState").text.indexOf("server") >= 0, findChild(page, "syncState").text)
        shot("4d-sync")
        Sync.enabled = false
        popPage()

        const conflicts = push("ConflictsPage")
        compare(conflicts.title, "Conflicts")
        verify(findChild(conflicts, "noConflicts").visible)
        popPage()
    }

    // No key store answers (the test's environment): the password lands in the file, the note says
    // so and what to do. Runs after the case without an account.
    function test_3e_sync_password_in_file() {
        const page = push("BackupPage")
        Sync.enabled = true
        const hint = findChild(page, "syncPasswordNote")
        verify(!hint.visible)
        Sync.setAccount("https://cloud.example.org/dav/", "ich", "nur-ein-test", "")
        tryVerify(() => hint.visible, mediaLoads)
        verify(hint.text.indexOf("restart Mitori") >= 0, hint.text)
        verify(Sync.hasPassword)
        page.flickable.contentY = hint.mapToItem(page.flickable.contentItem, 0, 0).y - 20
        wait(50)
        shot("4e-sync-password-file")
        Sync.enabled = false
        verify(hint.visible, "it still lies there with sync off")
        verify(hint.text.indexOf("With sync on") >= 0, hint.text)

        // States only a failing disk reaches (tst_sync): each sentence is true of its state.
        hint.syncOn = true
        hint.note = Sync.NotRecorded
        hint.inFile = false
        verify(hint.text.indexOf("older one") < 0, "no older password on the first one: " + hint.text)
        verify(hint.text.indexOf("Sync now") >= 0, hint.text)
        hint.inFile = true
        verify(hint.text.indexOf("older one") >= 0, hint.text)
        hint.note = Sync.NotSaved
        verify(hint.text.indexOf("Sync now") >= 0, "memory holds it: " + hint.text)
        verify(hint.text.indexOf("enter it") < 0, "servers show an app password once: " + hint.text)
        hint.syncOn = false
        verify(hint.visible, "an older password lies in the file")
        verify(hint.text.indexOf("older app password") >= 0, hint.text)
        compare(hint.titleText, qsTr("App password lies in a file"))
        hint.inFile = false
        verify(!hint.visible)
        popPage()
    }

    // Backup: saved, read back on the same device it changes nothing; merging says so.
    function test_3c_backup() {
        const page = push("BackupPage")
        const url = "file://" + uiShotsDir + "/sicherung-test.zip"
        verify(Backup.save(url), Backup.errorString)

        // The built-in dialog's answer without a suffix: the backup gets it.
        const bare = "sicherung-bare-" + Date.now()
        findChild(page, "saveBackupDialog").take("file://" + uiShotsDir + "/" + bare)
        tryVerify(() => findChild(page, "backupDone").visible)
        verify(findChild(page, "backupDone").text.indexOf(bare + ".zip") > 0, findChild(page, "backupDone").text)

        page.inspect(url)
        const dialog = findChild(page, "mergeBackup")
        tryVerify(() => dialog.opened)
        const text = findChild(page, "mergeText")
        verify(text.text.indexOf("Nothing new") >= 0, text.text)
        tryVerify(() => dialog.contentHeight >= text.implicitHeight, 1000,
                  "the text fits: " + dialog.contentHeight + " for " + text.implicitHeight)
        shot("4c-backup", true)
        dialog.accept()
        tryVerify(() => findChild(page, "backupDone").visible)
        compare(findChild(page, "backupError").visible, false)
        popPage()
    }

    // Both ways of reading a backup: merging keeps what the backup lacks; replacing asks a second
    // time with what goes, cancelling leads back, numbers follow a sync that brought something, a
    // running sync refuses it plainly, and accepting takes it away, turns the sync off and reloads
    // Practice.
    function test_3d_backup_choices() {
        const page = push("BackupPage")
        const url = "file://" + uiShotsDir + "/sicherung-wahl.zip"
        verify(Backup.save(url), Backup.errorString)
        const entry = Programme.entries("aikido", "k4").filter(r => r.kind === "entry")[0].id
        const notes = Practice.notes(entry).length
        verify(Practice.addNote(entry, "nicht in der Sicherung"))
        const mergeDialog = findChild(page, "mergeBackup")
        const replaceDialog = findChild(page, "replaceBackup")

        // Merge, the dialog's main button: the note stays.
        page.inspect(url)
        tryVerify(() => mergeDialog.opened)
        const text = findChild(page, "mergeText")
        verify(text.text.indexOf("It holds") >= 0, text.text)
        verify(text.text.indexOf("newer deletion") >= 0, text.text)
        verify(text.text.indexOf("only added") >= 0, text.text)
        verify(text.text.indexOf("a notebook the backup deleted later") >= 0, text.text)
        verify(text.text.indexOf("two notebooks of one course become one") >= 0, text.text)
        verify(text.text.indexOf("one grade entered twice") >= 0, text.text)
        verify(text.text.indexOf("keeps everything") < 0, text.text)
        verify(text.text.indexOf("Nothing new") >= 0, text.text)
        verify(text.text.indexOf("On this device it changes") < 0, text.text)

        // What changed and stays, beside what goes (a mark in `changed`, a clean-up's row only in `removed`).
        const counted = page.changes({ "entries": { "added": 0, "changed": 2, "edited": 1, "removed": 2 } })
        verify(counted.indexOf("1 changed, 2 deleted") >= 0, counted)
        tryVerify(() => mergeDialog.contentHeight >= findChild(page, "replaceInstead").y + findChild(page, "replaceInstead").height, 1000,
                  "the column fits: " + mergeDialog.contentHeight)
        shot("4c-backup-choice", true)
        mergeDialog.accept()
        tryVerify(() => !mergeDialog.visible)
        compare(Practice.notes(entry).length, notes + 1)

        // Replace: the second step says what goes, Cancel leads back to the first.
        Sync.enabled = true
        page.inspect(url)
        tryVerify(() => mergeDialog.opened)
        findChild(page, "replaceInstead").clicked()
        tryVerify(() => replaceDialog.opened)
        verify(!mergeDialog.visible)
        const warning = findChild(page, "replaceText")
        verify(warning.text.indexOf("cannot be undone") >= 0, warning.text)
        verify(warning.text.indexOf("Notes: 1") >= 0, warning.text)
        verify(warning.text.indexOf("Sync is turned off") >= 0, warning.text)
        verify(warning.text.indexOf("changes and deletions") >= 0, warning.text)
        verify(warning.text.indexOf("what you restored from the backup can go again") >= 0, warning.text)

        // A sync brings something while the dialog is open: the numbers follow.
        verify(Practice.addNote(entry, "kam mit dem Abgleich"))
        Sync.merged()
        tryVerify(() => warning.text.indexOf("Notes: 2") >= 0, 2000, warning.text)
        tryVerify(() => replaceDialog.contentHeight >= warning.implicitHeight, 1000,
                  "the text fits: " + replaceDialog.contentHeight + " for " + warning.implicitHeight)
        shot("4c-backup-replace", true)

        // A phone held sideways: the dialog stays in the window, the text scrolls.
        window.width = 800
        window.height = 360
        const scroll = findChild(page, "replaceScroll")
        tryVerify(() => replaceDialog.height <= window.height, 1000, "dialog " + replaceDialog.height)
        tryVerify(() => scroll.contentItem.contentHeight > scroll.height, 1000, "the text scrolls")
        shot("4c-backup-replace-sideways", true)
        window.width = 420
        window.height = 800
        replaceDialog.reject()
        tryVerify(() => mergeDialog.opened)
        compare(Practice.notes(entry).length, notes + 2)

        // While a sync runs: not replaced, and it says so. (A real run needs a password, which would
        // go to this computer's key store; so the page is told. tst_sync runs real ones.)
        mergeDialog.close()
        tryVerify(() => !mergeDialog.visible)
        page.replaceData(true)
        const refused = findChild(page, "backupError")
        verify(refused.visible)
        verify(refused.text.indexOf("Not replaced") >= 0, refused.text)
        compare(findChild(page, "backupDone").visible, false)
        compare(Practice.notes(entry).length, notes + 2)

        // Saving says how that went, not the refusal before it.
        verify(page.saveBackup("file://" + uiShotsDir + "/sicherung-wahl-2.zip"))
        verify(!refused.visible, refused.text)

        // Read again and accepted: as in the backup, Practice read anew, the sync off, and it says so.
        page.inspect(url)
        verify(!refused.visible)
        tryVerify(() => mergeDialog.opened)
        findChild(page, "replaceInstead").clicked()
        tryVerify(() => replaceDialog.opened)
        replaceDialog.accept()
        const done = findChild(page, "backupDone")
        tryVerify(() => done.visible)
        verify(done.text.indexOf("Sync is off") >= 0, done.text)
        compare(refused.visible, false)
        compare(Practice.notes(entry).length, notes)
        verify(!Sync.enabled)
        tryVerify(() => !replaceDialog.visible)

        // Beside the switch until it is on again: what turning it on brings back.
        const note = findChild(page, "syncAfterReplace")
        verify(note.visible)
        verify(note.text.indexOf("changes and deletions") >= 0, note.text)
        Sync.enabled = true
        verify(!note.visible)
        Sync.enabled = false
        popPage()
    }

    // Mitori asks which: both choices in view without scrolling, on small phones and sideways, with
    // the longest preview; only the text scrolls.
    function test_3d_backup_choice_sizes() {
        const page = push("BackupPage")
        const url = "file://" + uiShotsDir + "/sicherung-groessen.zip"
        verify(Backup.save(url), Backup.errorString)
        page.inspect(url)
        const dialog = findChild(page, "mergeBackup")
        tryVerify(() => dialog.opened)
        const row = { "added": 3, "edited": 2, "removed": 1, "holds": 9 }
        page.summary = { "created": page.summary.created, "ratings": row, "notes": row, "rounds": row, "notebooks": row,
                         "entries": row, "grades": row, "starts": row, "media": 2, "mediaRemoved": 1, "mediaHolds": 4 }

        const merge = dialog.standardButton(QQC2.Dialog.Ok)
        const replace = findChild(page, "replaceInstead")
        const scroll = findChild(page, "mergeScroll")
        const inside = () => {
            const at = replace.mapToItem(dialog.contentItem, 0, 0)
            return replace.visible && at.x >= 0 && at.y >= 0 && at.x + replace.width <= dialog.contentItem.width
                   && at.y + replace.height <= dialog.contentItem.height
        }
        for (const [width, height] of [[360, 640], [640, 360], [320, 568]]) {
            window.width = width
            window.height = height
            tryVerify(() => dialog.width <= width && dialog.height <= height && inside(), 2000,
                      width + "x" + height + ": dialog " + dialog.height + ", button at "
                      + replace.mapToItem(dialog.contentItem, 0, 0).y + " in " + dialog.contentItem.height)
            verify(merge.visible && merge.width > 0)
            tryVerify(() => scroll.contentItem.contentHeight > scroll.height, 2000, "the text scrolls")
            shot("4c-backup-choice-" + width + "x" + height, true)
        }
        dialog.reject()
        tryVerify(() => !dialog.visible)
        popPage()
    }

    // The German words on the smallest phone: every footer button of both dialogs lies inside its
    // dialog. And what replacing does is the first thing to read.
    function test_3d_backup_german_footer() {
        window.width = 320
        window.height = 568
        const page = push("BackupPage")
        const url = "file://" + uiShotsDir + "/sicherung-deutsch.zip"
        verify(Backup.save(url), Backup.errorString)
        page.inspect(url)
        const first = findChild(page, "mergeBackup")
        tryVerify(() => first.opened)
        tryVerify(() => first.width <= 320)

        const hint = findChild(page, "replaceHint")
        verify(hint.y < findChild(page, "mergeText").y, "hint at " + hint.y)

        // The dialog's height follows the text, not its first lines.
        const firstArea = findChild(page, "mergeScroll")
        const wanted = hint.implicitHeight + findChild(page, "mergeText").implicitHeight
        tryVerify(() => firstArea.height >= Math.min(wanted, 200), 2000, "shows " + firstArea.height + " of " + wanted)

        const fits = (dialog, word) => {
            const accept = dialog.standardButton(QQC2.Dialog.Ok)
            const cancel = dialog.standardButton(QQC2.Dialog.Cancel)
            dialog.acceptText = word
            cancel.text = "Abbrechen"
            tryVerify(() => accept.text === word && cancel.text === "Abbrechen")
            wait(50)   // the button box lays the new widths out
            for (const button of [accept, cancel]) {
                const at = button.mapToItem(dialog.parent, 0, 0)
                verify(at.x >= dialog.x && at.x + button.width <= dialog.x + dialog.width,
                       button.text + " from " + at.x + " to " + (at.x + button.width)
                       + " in a dialog from " + dialog.x + " to " + (dialog.x + dialog.width))
            }
        }
        fits(first, uiCatalog.german("BackupPage", "Merge"))
        shot("4c-backup-choice-de-320", true)

        findChild(page, "replaceInstead").clicked()
        const second = findChild(page, "replaceBackup")
        tryVerify(() => second.opened)
        fits(second, uiCatalog.german("BackupPage", "Delete and replace"))

        // The warning shows, not one line of it (the dialog's height follows the text).
        const warning = findChild(page, "replaceText")
        const warningArea = findChild(page, "replaceScroll")
        tryVerify(() => warningArea.height >= warning.implicitHeight, 2000,
                  "shows " + warningArea.height + " of " + warning.implicitHeight)
        shot("4c-backup-replace-de-320", true)

        second.acceptText = "Delete and replace"
        first.acceptText = "Merge"
        second.standardButton(QQC2.Dialog.Cancel).text = "Cancel"
        first.standardButton(QQC2.Dialog.Cancel).text = "Cancel"
        second.reject()
        tryVerify(() => first.opened)
        first.reject()
        tryVerify(() => !first.visible)
        popPage()
    }

    // The player's switches: the screen stays on while a video plays (and the switch on);
    // sound off mutes also at full tempo; both switches stay for the next start. "Noted today" lists
    // the day's notes on the technique.
    function test_4t_player_switches() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        // The page has the bar's style (with Auto it had no head, and no way back, under Kante).
        const bar = window.pageStack.globalToolBar
        // With a picture (Kino) the dark page has no head of its own.
        compare(page.globalToolBarStyle, page.kino ? Kirigami.ApplicationHeaderStyle.None : bar.actualStyle)
        verify(!Levels.held, "no video plays: the screen may sleep")
        Levels.setPlayback(Levels.Playback.Playing)     // as the player does while it plays
        const awake = findChild(page, "awakeSwitch")
        const sound = findChild(page, "soundSwitch")
        verify(awake.checked && sound.checked)
        awake.clicked()
        verify(!Levels.held && !Levels.awake)
        awake.clicked()
        verify(Levels.held)
        sound.clicked()
        verify(!Levels.sound && !sound.checked)
        sound.clicked()
        verify(Levels.sound)
        findChild(page, "transportBar").speedChangeRequested(0.5)
        verify(!sound.checked, "slow motion is silent")
        verify(!sound.enabled, "no unseen change in slow motion")
        findChild(page, "transportBar").speedChangeRequested(1)
        verify(sound.checked)

        // With a picture (Kino) the middle lists the last notes, else the controls say "Noted today".
        const noted = findChild(page, "notedToday")
        verify(!noted.visible)
        Practice.addNote(page.current.id, "Schritt kleiner")
        Practice.addNote(page.current.id, "Blick")
        if (page.kino && findChild(page, "kinoMiddle").tight) {
            verify(findChild(page, "kinoNotesLine").text.indexOf("2") >= 0, findChild(page, "kinoNotesLine").text)
        } else if (page.kino) {
            const listed = allChildren(findChild(page, "kinoHistory")).filter(c => c.objectName === "lastNote" && c.visible)
            verify(listed.length === 2 && listed[0].text.indexOf("Blick") >= 0 && listed[1].text.indexOf("Schritt kleiner") >= 0)
        } else {
            verify(noted.visible)
            verify(noted.text.indexOf("Schritt kleiner") >= 0 && noted.text.indexOf("Blick") >= 0, noted.text)
        }
        for (const n of Practice.notes(page.current.id)) {
            Practice.deleteNote(n.uid)
        }
        popPage()
        // The page goes after its slide: on a busy machine (the CI, under Shinki) over two seconds.
        tryVerify(() => !Levels.held, mediaLoads, "the screen may sleep again")
    }

    // Swipe on the picture: up on the left half brightens the screen, down on the right half
    // turns the sound down; leaving the player gives the screen its brightness back. The levels
    // stay in memory (MITORI_DEVICE_LEVELS), no video needed.
    function test_4s_player_swipe() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        const stage = findChild(page, "stage")
        verify(stage)
        stage.visible = true    // without a video a card stands for the stage; the gesture needs it
        slidIn()
        tryVerify(() => stage.height > 100, 5000, "the stage has its place")
        const brightness = Levels.brightness
        const volume = Levels.volume
        mouseDrag(stage, stage.width / 4, stage.height * 0.8, 0, -stage.height / 2)
        tryVerify(() => Levels.brightness > brightness + 0.3, 2000, "brightness " + Levels.brightness)
        compare(Levels.volume, volume)
        mouseDrag(stage, stage.width * 3 / 4, stage.height * 0.2, 0, stage.height / 4)
        tryVerify(() => Levels.volume < volume - 0.1, 2000, "volume " + Levels.volume)
        verify(!findChild(page, "levelShown").visible, "shown only while swiping")
        window.back()      // as the head does (Kirigami's pop() may keep the page, PlayerPage.leave)
        tryCompare(Levels, "brightness", brightness)
    }

    // The double tap's hint stands on the side that was tapped.
    function test_4s_jump_hint() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        const stage = findChild(page, "stage")
        stage.visible = true
        wait(800)
        const area = findChild(page, "jumpHintArea")
        page.showJump(true)
        tryVerify(() => area.visible)
        verify(area.width > stage.width / 3, "width " + area.width)
        verify(area.mapToItem(stage, 0, 0).x >= stage.width / 2 - 1, "x " + area.mapToItem(stage, 0, 0).x)
        window.back()
        tryVerify(() => window.pageStack.depth === 1)
    }

    // The Back key (goBack) takes the player off the stack, so it cannot play on unseen (Review #64).
    function test_4s_player_back_key() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        push("PlayerPage", { playlist: rows, index: 0 })
        const depth = window.pageStack.depth
        slidIn()
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.depth === depth - 1, 2000, "depth " + window.pageStack.depth)
    }

    // Player layout screens (no video needed): the player renders a card for a missing video.
    function test_4p_player_layout() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        wait(500)
        shot("5-player")
        window.width = 800
        window.height = 360
        wait(500)
        shot("6-player-landscape")
        window.width = 420
        window.height = 800
        popPage()
    }

    function test_4_player() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const page = push("PlayerPage", { playlist: rows, index: 1 })
        tryVerify(() => page.playing, mediaLoads)
        tryVerify(() => page.position >= page.from && page.position < page.to, mediaLoads)
        wait(1500)
        verify(Qt.colorEqual(page.background.color, Look.backgroundColor), "the style's ground")
        shot("5-player")
        // Sideways the rail has what the player needs, all of it in view on a phone.
        window.width = 800
        window.height = 360
        wait(500)
        shot("6-player-landscape")
        verify(page.headless, "sideways")
        verify(findChild(page, "railBack").visible)
        const loop = findChild(page, "railLoop")
        const bottom = loop.mapToItem(page, 0, loop.height).y
        verify(bottom <= page.height, "the rail ends at " + bottom + " of " + page.height)
        // The rail's play button says what a tap does (under Shinki its own icon, the red circle).
        const play = findChild(page, "railPlay")
        verify(page.playing)
        compare(play.symbol, "media-playback-pause")
        if (uiShinki) {
            compare(play.contentItem.children[0].name, "media-playback-pause")
        }
        window.width = 420
        window.height = 800
        popPage()
    }

    // An item's edges in the page's coordinates.
    function edgesIn(page, item) {
        const at = item.mapToItem(page, 0, 0)
        return { left: at.x, top: at.y, right: at.x + item.width, bottom: at.y + item.height }
    }
    function overlap(a, b) {
        return a.left < b.right - 0.5 && b.left < a.right - 0.5 && a.top < b.bottom - 0.5 && b.top < a.bottom - 0.5
    }

    // The player's design "Kino" sideways (a tablet, a phone): the picture fills the page; over it
    // the back button and the name at the top left, the notes at the top right, the four ratings as
    // a column at the right edge, the plate with the timeline and the controls at the foot.
    function test_4t_player_kino_data() {
        return [{ tag: "tablet", width: 1280, height: 800 }, { tag: "phone", width: 860, height: 420 },
                { tag: "small phone", width: 800, height: 360 }]
    }
    function test_4t_player_kino(data) {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        useFolder(standInVideos)
        const rows = Programme.entries("aikido", "k2").filter(r => r.kind === "entry" && r.video)
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        window.width = data.width
        window.height = data.height
        const plate = findChild(page, "plate")
        tryVerify(() => plate.visible && plate.height > 0, 5000, "the plate")
        wait(500)
        shot("player-kino-" + data.width + "x" + data.height)

        verify(page.headless, "no head sideways")
        const stage = edgesIn(page, findChild(page, "stage"))
        verify(Math.abs(stage.top) < 1 && Math.abs(stage.bottom - page.height) < 1, "the picture fills the page")

        // The plate at the foot, the full width; the timeline above its row.
        const foot = edgesIn(page, plate)
        verify(Math.abs(foot.bottom - page.height) < 1 && Math.abs(foot.right - page.width) < 1 && foot.left < 1, "the plate at the foot")
        const timeline = edgesIn(page, findChild(page, "railTimeline"))
        const play = edgesIn(page, findChild(page, "railPlay"))
        verify(timeline.bottom <= play.top + 1 && timeline.top >= foot.top, "the timeline above the controls, on the plate")
        for (const part of ["plateTime", "plateTempo", "railFrameBack", "railFrameOn", "railLoop", "plateSound", "plateNext"]) {
            const e = edgesIn(page, findChild(page, part))
            verify(e.left >= 0 && e.right <= page.width && e.top >= foot.top && e.bottom <= page.height, part + " in view on the plate")
        }
        verify(!findChild(page, "fullButton").visible, "the stage's full-screen button is not there")
        verify(findChild(page, "plateFull").visible)

        // The back button and the name at the top left, the notes at the top right.
        const back = edgesIn(page, findChild(page, "railBack"))
        const name = edgesIn(page, findChild(page, "kinoName"))
        const notes = edgesIn(page, findChild(page, "kinoNotesButton"))
        verify(back.left < page.width / 4 && back.top < page.height / 4, "back at the top left")
        verify(name.left >= back.right && name.top < page.height / 4, "the name beside it")
        verify(findChild(page, "kinoName").text.indexOf(rows[0].title) >= 0)
        verify(notes.right <= page.width && notes.left > page.width / 2 && notes.top < page.height / 4, "notes at the top right")
        verify(findChild(page, "kinoNotesButton").text.indexOf("0") >= 0, "the count of notes")

        // The ratings: a column at the right edge, over the picture, clear of the notes and the plate.
        const column = findChild(page, "ratingColumn")
        verify(column.vertical && column.visible)
        const ratings = edgesIn(page, column)
        verify(ratings.right > page.width - Look.unit(24) && ratings.right <= page.width, "at the right edge: " + ratings.right)
        verify(ratings.top >= stage.top && ratings.bottom <= foot.top + 0.5, "over the picture, above the plate")
        verify(!overlap(ratings, notes) && !overlap(ratings, foot) && !overlap(notes, name), "nothing overlaps")
        const buttons = column.children.filter(c => c.level !== undefined)
        compare(buttons.length, 4)
        for (let i = 1; i < buttons.length; ++i) {
            verify(edgesIn(page, buttons[i]).top >= edgesIn(page, buttons[i - 1]).bottom - 0.5, "one below the other")
        }
        verify(!findChild(page, "kinoRating").visible, "the thumb zone's row is not there")

        // A tap rates; the one filled is the level.
        column.picked(3)
        compare(Practice.level(rows[0].id), 3)
        verify(buttons[2].chosen && !buttons[1].chosen)

        // The notes button asks for the notes.
        findChild(page, "kinoNotesButton").clicked()
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "the notes page opens")
        window.back()
        tryVerify(() => window.pageStack.currentItem === page, 3000)
    }

    // Kino upright (a phone): the name, the picture and its timeline, in the middle how the technique
    // was rated and its last notes with a field for a new one, below in the thumb zone the controls,
    // the ratings and the way on. The middle is never empty and nothing overlaps.
    function test_4u_player_kino_upright_data() {
        // `tight`: the middle is too short for the notes and the field (a small phone); left out,
        // the style's fonts decide (Shinki needs more room than Kante).
        return [{ tag: "tall phone", width: 420, height: 960, row: 0, tight: false },
                { tag: "phone", width: 420, height: 860, row: 2 },
                { tag: "small phone", width: 360, height: 640, row: 1, tight: true }]
    }
    function test_4u_player_kino_upright(data) {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        useFolder(standInVideos)
        const rows = Programme.entries("aikido", "k2").filter(r => r.kind === "entry" && r.video)
        window.width = data.width
        window.height = data.height
        const page = push("PlayerPage", { playlist: rows, index: data.row })
        const id = rows[data.row].id
        const middle = findChild(page, "kinoMiddle")
        tryVerify(() => middle.visible && middle.height > 0, 5000, "the middle")
        slidIn()
        verify(page.upright && !page.headless)

        // The dark title row carries the name whole and Back; no light head above it.
        const title = findChild(page, "kinoTitle")
        tryVerify(() => title.width > 0, 2000)
        tryVerify(() => !title.truncated, 2000, "the name is cut: " + title.text + " in " + title.width + " px")
        compare(page.globalToolBarStyle, Kirigami.ApplicationHeaderStyle.None, "no light head over the dark page")
        verify(findChild(page, "kinoBack").visible, "Back in the title row")

        // Not empty, whatever the technique has: the history stands there with its height.
        const history = findChild(page, "kinoHistory")
        verify(history.visible && history.height > 0)
        const before = history.ratings.length
        compare(Practice.notes(id).length, 0)
        const tight = middle.tight
        if (data.tight !== undefined) {
            verify(tight === data.tight, "tight " + tight + " at a height of " + middle.height + " (needs " + middle.needed + ")")
        }
        verify(middle.clip, "the middle is clipped")
        if (!tight) {
            verify(findChild(page, "noNotes").visible, "without notes it says so")
        }
        shot("player-kino-" + data.width + "x" + data.height + "-empty")

        // Ratings and notes show; the field adds today's.
        verify(Practice.rate(id, 1))
        verify(Practice.rate(id, 3))
        Practice.addNote(id, "Schritt kleiner")
        Practice.addNote(id, "Blick zum Partner")
        Practice.addNote(id, "Hüfte zuerst")
        compare(history.ratings.length, Math.min(8, before + 2))
        compare(history.ratings[history.ratings.length - 2].level, 1)
        compare(history.ratings[history.ratings.length - 1].level, 3)
        const lastNotes = () => allChildren(history).filter(c => c.objectName === "lastNote" && c.visible)
        if (tight) {
            // Too short: the bars, a "Notes · n" line and a button to the note input, no list, no field.
            compare(lastNotes().length, 0)
            verify(findChild(page, "kinoNotesLine").visible)
            verify(findChild(page, "kinoNotesLine").text.indexOf("3") >= 0, findChild(page, "kinoNotesLine").text)
            verify(!findChild(page, "kinoNote").active, "no inline field")
            const add = findChild(page, "kinoAddNote")
            verify(add.visible)
            add.clicked()
            tryVerify(() => window.pageStack.currentItem !== page, 3000, "the note input opens")
            window.back()
            tryVerify(() => window.pageStack.currentItem === page, 3000)
        } else {
            compare(lastNotes().length, 2, "the last two notes")
            verify(lastNotes()[0].text.indexOf("Hüfte zuerst") >= 0 && lastNotes()[1].text.indexOf("Blick zum Partner") >= 0,
                   lastNotes()[0].text + " / " + lastNotes()[1].text)
            verify(!findChild(page, "noNotes").visible)
            verify(!findChild(page, "kinoAddNote").visible)

            const note = findChild(page, "kinoNote")
            const field = findChild(note, "noteField")
            field.text = "Heute ruhiger"
            findChild(note, "addNote").clicked()
            compare(field.text, "")
            verify(lastNotes()[0].text.indexOf("Heute ruhiger") > 0, lastNotes()[0].text)
        }
        wait(300)
        shot("player-kino-" + data.width + "x" + data.height)

        // From top to bottom: the name, the picture, the timeline, the middle, the thumb zone; none
        // over another, all in the page.
        const order = ["kinoTitleRow", "stage", "kinoScrub", "kinoMiddle", "thumbZone"].map(n => ({ n: n, e: edgesIn(page, findChild(page, n)) }))
        for (let i = 1; i < order.length; ++i) {
            verify(order[i].e.top >= order[i - 1].e.bottom - 0.5, order[i].n + " below " + order[i - 1].n + ": " + JSON.stringify(order))
        }
        verify(order[4].e.bottom <= page.height + 0.5, "the thumb zone in view: " + order[4].e.bottom + " of " + page.height)
        verify(order[3].e.bottom - order[3].e.top > 0, "the middle has height")
        // Nothing of the middle reaches below its edge into the thumb zone.
        const stray = allChildren(middle).filter(c => c.visible && c.width > 0 && c.height > 0
                                                 && (c.text !== undefined || c.clicked !== undefined || c.picked !== undefined)
                                                 && edgesIn(page, c).bottom > order[3].e.bottom + 0.5)
                                         .map(c => (c.objectName || c.text) + " to " + edgesIn(page, c).bottom + " of " + order[3].e.bottom)
        compare(stray, [], "the middle spills into the thumb zone")
        for (const part of order) {
            verify(part.e.left >= 0 && part.e.right <= page.width + 0.5, part.n + " within the width")
        }
        const row = edgesIn(page, findChild(page, "kinoRating"))
        verify(row.top >= order[3].e.bottom - 0.5, "the ratings in the thumb zone")
        verify(!findChild(page, "ratingColumn").visible && !findChild(page, "plate").visible)
        verify(findChild(page, "fullButton").visible, "full screen on the picture")

        // The row rates, and the training would move on.
        findChild(page, "kinoRating").picked(4)
        compare(Practice.level(id), 4)
        compare(history.ratings.length, Math.min(8, before + 3))
        compare(history.ratings[history.ratings.length - 1].level, 4)

        for (const n of Practice.notes(id)) {
            Practice.deleteNote(n.uid)
        }
        window.back()
        tryCompare(window.pageStack, "depth", 1)
    }

    // Until a page's item stands still in the window. Clicking earlier hits what is under it: a tile
    // of the start menu, whose push then replaces the page the test is on (and destroys `item`).
    // A fixed wait is too short for the first page of a run, which still compiles, or under load.
    function standStill(item) {
        const kStillReads = 3
        let last = null, still = 0
        tryVerify(() => {
            wait(100)
            const at = item.mapToItem(window.contentItem, 0, 0)
            still = last && at.x === last.x && at.y === last.y && at.x >= 0 && at.x < window.width ? still + 1 : 0
            last = at
            return still >= kStillReads
        }, 15000, "the item stands still")
    }

    // A click lands only once the page has slid in: again until it did what it should.
    function clickUntil(item, done) {
        verify(item, "something to click")
        standStill(item)
        tryVerify(() => {
            if (!done()) {
                mouseClick(item)
            }
            return done()
        }, 5000)
    }

    function test_4v_full_screen() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const before = window.visibility
        failOnWarning(/Binding loop/)

        // Upright: ⤢ on the picture, full screen in place, ⤡ at the band brings it back.
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        const full = findChild(page, "fullButton")
        tryVerify(() => full.visible && full.width > 0)
        slidIn()
        clickUntil(full, () => page.big)
        compare(window.visibility, Window.FullScreen)
        wait(300)
        shot("6b-full-screen")
        verify(!full.visible, "⤢ is gone in full screen")
        const leave = findChild(page, "railBack")
        tryVerify(() => leave.visible && leave.width > 0)
        wait(300)
        compare(leave.symbol, "view-restore")
        clickUntil(leave, () => !page.big)
        compare(window.visibility, before)
        verify(full.visible, "⤢ again")

        // Space after ⤡ stops the video: the button does not keep the focus (and would mean Back).
        tryVerify(() => page.playing, 5000)
        keyClick(Qt.Key_Space)
        tryCompare(page, "playing", false)
        compare(window.pageStack.currentItem, page)
        page.togglePlay()

        // Esc leaves it as well, and the page stays.
        const depth = window.pageStack.depth
        wait(500)       // the window has its size back
        clickUntil(full, () => page.big)
        page.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        compare(page.big, false)
        compare(window.pageStack.depth, depth)
        popPage()

        // By keyboard the hidden button gives the focus back: Space pauses, it does not press it.
        const typed = push("PlayerPage", { playlist: rows, index: 0 })
        tryVerify(() => typed.playing, 5000)
        wait(500)
        findChild(typed, "fullButton").forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(typed.big, true)
        keyClick(Qt.Key_Space)
        compare(typed.big, true, "still full screen")
        tryCompare(typed, "playing", false)
        keyClick(Qt.Key_Escape)
        popPage()

        // A nearly square window: the head does not turn the page back and forth (Shinki).
        const squareWidth = window.width
        const square = push("PlayerPage", { playlist: rows, index: 0 })
        wait(500)
        window.width = window.height - Look.unit(20)
        wait(300)
        let turns = 0
        const count = () => turns++
        square.heightChanged.connect(count)
        wait(500)
        square.heightChanged.disconnect(count)
        compare(turns, 0, "page height stands still")
        window.width = squareWidth
        popPage()

        // Space still plays and stops: ⤢ does not keep the focus.
        const spaced = push("PlayerPage", { playlist: rows, index: 0 })
        const spacedFull = findChild(spaced, "fullButton")
        tryVerify(() => spaced.playing, 5000)
        wait(500)
        clickUntil(spacedFull, () => spaced.big)
        keyClick(Qt.Key_Space)
        compare(spaced.playing, false, "paused by Space")
        compare(spaced.big, true)

        // The Back key ends full screen too, and the video stops.
        // Seen as it happens: the page goes within the key press (pop in the same turn of the loop),
        // so a read afterwards finds it destroyed. Full screen must end and the video stop first.
        let bigEnded = false
        spaced.bigChanged.connect(() => { bigEnded = bigEnded || !spaced.big })
        keyClick(Qt.Key_Back)
        tryCompare(window.pageStack, "currentIndex", 0)
        tryCompare(window, "visibility", before)
        tryVerify(() => bigEnded, 5000, "full screen ended")
        window.pageStack.pop(window.pageStack.currentItem)
        const hidden = push("PlayerPage", { playlist: rows, index: 0 })
        tryVerify(() => hidden.playing, 5000)
        wait(500)
        let quiet = false
        hidden.playingChanged.connect(() => { quiet = quiet || !hidden.playing })
        keyClick(Qt.Key_Back)
        tryCompare(window.pageStack, "currentIndex", 0)
        tryVerify(() => quiet, 5000, "no sound from a page left")
        window.pageStack.pop(window.pageStack.currentItem)

        // Back from full screen leaves the keys with the page before: the search goes on.
        const search = push("SearchPage")
        const searchField = findChild(search, "searchField")
        tryVerify(() => searchField.activeFocus)
        searchField.text = ""
        const above = push("PlayerPage", { playlist: rows, index: 0 })
        wait(500)
        clickUntil(findChild(above, "fullButton"), () => above.big)
        keyClick(Qt.Key_Back)
        tryCompare(window.pageStack, "currentItem", search)
        tryVerify(() => !above.big)
        wait(200)
        keyClick(Qt.Key_A)
        compare(searchField.text, "a", "typed into the search")
        window.pageStack.pop(window.pageStack.currentItem)
        popPage()

        // A place outside the chapter (the small player was still loading): the chapter start.
        const chapter = rows.findIndex(r => r.video.von > 60)
        verify(chapter >= 0)
        const early = push("PlayerPage", { playlist: rows, index: chapter, startAt: 0 })
        tryVerify(() => early.duration > 0 && early.playing, 5000)
        wait(300)
        verify(early.position >= early.from - 500, "at " + early.position + ", chapter at " + early.from)
        popPage()

        // Beside the list: ⤢ opens the big player where the small one stands; ⤡ closes that page.
        const width = window.width
        const height = window.height
        window.width = 1280
        window.height = 800
        const programme = push("ProgrammePage")
        tryVerify(() => programme.split)
        programme.open(programme.rows.find(r => r.id === rows[0].id))
        const pane = findChild(programme, "playerPane")
        tryVerify(() => pane.item && pane.item.duration > 0, 5000)
        pane.item.pause()
        const place = pane.item.from + 1000
        pane.item.jump(1000)
        wait(500)
        const small = findChild(pane.item, "fullButton")
        verify(small.visible, "⤢ on the small player")
        const before2 = window.pageStack.depth
        clickUntil(small, () => window.pageStack.depth === before2 + 1)
        tryCompare(window.pageStack, "depth", before2 + 1)
        const bigPage = window.pageStack.currentItem
        compare(bigPage.big, true)
        wait(500)
        tryVerify(() => bigPage.duration > 0, 5000)
        tryVerify(() => Math.abs(bigPage.position - place) < 500, 3000, "at " + bigPage.position)
        compare(window.visibility, Window.FullScreen)
        const close = findChild(bigPage, "railBack")
        tryVerify(() => close.visible && close.width > 0)
        clickUntil(close, () => window.pageStack.depth === before2)
        tryCompare(window.pageStack, "depth", before2)
        tryCompare(window, "visibility", before)
        popPage()
        window.width = width
        window.height = height
    }

    // What the eye sees and no behaviour test would: symbols in the middle of their buttons, the
    // bars with their margins, no bar without anything to scroll, hints inside their fields.
    function test_4u_shapes() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        if (player.hasVideo) {
            // With a picture (Kino) the thumb zone holds the symbol buttons, else the style's bar.
            const bar = findChild(player, player.kino ? "thumbZone" : "transportBar")
            const buttons = allChildren(bar).filter(c => c.visible && c.width > 0 && c.checkable !== undefined
                                                    && c.display === 0)
            verify(buttons.length > 0 || !uiShinki, "the bar's symbol buttons")
            for (const button of buttons) {
                for (const icon of allChildren(button).filter(c => c.visible && c.width > 0 && /Icon/.test(c.toString()))) {
                    const centre = icon.mapToItem(button, icon.width / 2, icon.height / 2)
                    verify(Math.abs(centre.x - button.width / 2) < 1.5, button.text + " dx " + (centre.x - button.width / 2))
                    verify(Math.abs(centre.y - button.height / 2) < 1.5, button.text + " dy " + (centre.y - button.height / 2))
                }
            }
        }
        window.back()
        tryCompare(window.pageStack, "depth", 1)

        const notes = push("NotesPage", { entry: rows[0] })
        const compose = findChild(notes, "compose")
        tryVerify(() => compose.mapToItem(notes, 0, 0).x >= Look.unit(8) - 0.5, 2000, "the field's margin")
        const add = allChildren(compose.parent).filter(c => c.text === qsTr("Add"))[0]
        const right = notes.width - add.mapToItem(notes, add.width, 0).x
        verify(right >= Look.unit(8) - 0.5, "the button's margin: " + right)
        popPage()

        const all = push("AllNotesPage")
        const scroll = findChild(all, "lookScrollBar")
        if (scroll.size >= 1) {
            verify(!scroll.contentItem.visible, "nothing to scroll: no bar")
        }
        popPage()

        const search = push("SearchPage")
        const field = findChild(search, "searchField")
        tryVerify(() => field.activeFocus)
        const hint = findChild(field, uiShinki ? "fieldHint" : "kantePlaceholder")
        verify(hint.visible, "the hint in the empty field with the focus")
        verify(hint.y >= 0 && hint.y + hint.height <= field.height + 0.5, "inside the field")
        const hintText = field.placeholderText
        field.placeholderText = hintText + " " + hintText + " " + hintText + " " + hintText
        verify(hint.truncated, "a long hint is cut")
        verify(hint.x + hint.width <= field.width + 0.5, "and ends in the field: " + hint.width)
        field.placeholderText = hintText
        compare(field.placeholderTextColor.a, 0, "Material would float its own above the field")
        field.text = "x"
        verify(!hint.visible)
        popPage()

        const settings = push("BackupPage")
        const label = allChildren(settings).filter(c => c.text === qsTr("Folder on the server") && c.font !== undefined)[0]
        compare(label.font.capitalization, Font.AllUppercase)
        popPage()

        // Rows without a video keep the place of the button: the dots stay in line.
        const programme = push("ProgrammePage")
        Programme.discipline = "shinkitoho"
        wait(500)
        const dots = allChildren(programme).filter(c => c.visible && c.width > 0 && c.names !== undefined && c.value !== undefined)
        verify(dots.length > 3, "dots: " + dots.length)
        const edges = new Set(dots.map(d => Math.round(d.mapToItem(programme, d.width, 0).x)))
        compare(edges.size, 1, "the dots end in line: " + Array.from(edges))
        Programme.discipline = "aikido"
        popPage()
    }

    function playerAt(index) {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const page = push("PlayerPage", { playlist: rows, index: index < 0 ? rows.length + index : index })
        tryVerify(() => page.playing && page.position > page.from + 500, mediaLoads)
        return page
    }

    // Back from the player held sideways: the page goes (it does not keep playing), in every
    // style. Kirigami's pop() kept it once the window had turned.
    function test_5a_back_sideways() {
        let player = playerAt(0)
        window.width = 800
        window.height = 360
        tryVerify(() => player.headless, 2000, "sideways")
        const back = findChild(player, "railBack")
        tryVerify(() => back.visible, 2000, "Back beside the video")
        wait(800)
        mouseClick(back)
        tryCompare(window.pageStack, "depth", 1)
        tryVerify(() => !player || player.visible !== true, 2000, "the player is gone")     // deleted: undefined
    }

    // Steps and jumps stay where they land (the backend reports "loaded" after every seek).
    function test_5_step_and_jump_stay() {
        const page = playerAt(0)
        page.togglePlay()
        tryVerify(() => !page.playing)
        const before = page.position
        page.step(1)
        tryVerify(() => page.position >= before + page.frameMs - 5, 3000)
        wait(500)
        verify(!page.playing)
        verify(page.position > page.from + 400)
        page.jump(3000)
        tryVerify(() => page.position > before + 2500, 3000)
        wait(500)
        verify(page.position > before + 2500)
        popPage()
    }

    // Next technique in the same video: plays the new chapter, not the old one from its start.
    function test_5b_next_technique() {
        const page = playerAt(0)
        const firstTo = page.to
        page.go(1)
        tryVerify(() => page.from === firstTo, 2000)
        tryVerify(() => page.position >= page.from && page.position < page.to, 5000)
        wait(800)
        verify(page.position >= page.from, "still in the new chapter")
        popPage()
    }

    // ▶ in the list opens the player; the list marks the entry the player showed last.
    function test_5c_list_marks_last_shown() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const list = push("ProgrammePage")
        if (!list.hasVideo) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const playable = list.rows.filter(r => list.playable(r))
        list.play(playable[1])
        tryVerify(() => window.pageStack.currentItem !== list && window.pageStack.currentItem.playlist !== undefined)
        const player = window.pageStack.currentItem
        compare(list.lastId, playable[1].id)
        player.go(1)
        compare(list.lastId, playable[2].id)
        popPage()
        tryVerify(() => window.pageStack.currentItem === list)
        popPage()
    }

    // Next technique in another video (Shoden: the suburi, then the forms): its own chapter too.
    function test_5d_next_technique_other_file() {
        const rows = Programme.entries("shinkitoho", "shoden").filter(r => r.kind === "entry" && r.video)
        const at = rows.findIndex((r, i) => i > 0 && r.video.video !== rows[i - 1].video.video)
        verify(at > 0)
        if (!Videos.available(rows[at - 1].video.video) || !Videos.available(rows[at].video.video)) {
            skip("no video for Shinki Toho Shoden (set MITORI_VIDEOS)")
        }
        const page = push("PlayerPage", { playlist: rows, index: at - 1 })
        tryVerify(() => page.playing && page.position > page.from + 500, mediaLoads)
        page.go(1)
        compare(page.video, rows[at].video.video)
        tryVerify(() => page.playing && page.position >= page.from && page.position < page.to, mediaLoads)
        wait(800)
        verify(page.position >= page.from && page.position < page.to, "in the chapter of the new file")
        popPage()
    }

    // The transport bar's keys work right after opening; Space and the arrows stay single.
    function test_5e_keys_without_click() {
        const page = playerAt(0)
        page.forceActiveFocus()
        keyClick(Qt.Key_K)
        tryVerify(() => !page.playing)
        keyClick(Qt.Key_Minus)
        compare(page.rate, 0.75)
        keyClick(Qt.Key_Space)
        tryVerify(() => page.playing)
        wait(300)
        verify(page.playing, "Space toggles once")
        keyClick(Qt.Key_K)
        tryVerify(() => !page.playing)
        const before = page.position
        keyClick(Qt.Key_Right)
        tryVerify(() => page.position >= before + page.frameMs - 5, 3000)
        popPage()
    }

    // Today's practice: two new techniques of the current grade; rating one brings the next.
    function test_7_today() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("TodayPage")
        compare(page.discipline, "aikido")
        // Two new ones a day, less those of the grade already rated today (earlier cases).
        const newToday = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && Practice.ratedToday(r.id)).length
        verify(newToday < 2, "room for a new one today")
        compare(page.due.length, 2 - newToday)
        verify(page.due.every(r => r.level === 0 && r.current))
        const first = page.due[0].id
        verify(!Practice.ratedToday(first))
        Practice.rate(first, 2)
        // At most two new ones a day: the one practised counts, no other new one comes.
        compare(page.due.length, 1 - newToday)
        verify(page.due.every(r => r.id !== first), "practised today: not due")
        compare(findChild(page, "dueCount").value, String(1 - newToday))
        verify(Qt.colorEqual(page.background.color, Look.backgroundColor), "the style's ground")
        shot("7-today")
        if (page.due.length > 0) {
            Practice.rate(page.due[0].id, 1)
        }
        compare(page.due.length, 0, "everything practised for today")
        popPage()
    }

    // The discipline chosen for today is kept: the next time, and the start tiles, follow it.
    function test_7_today_keeps_discipline() {
        Programme.discipline = "aikido"
        const page = push("TodayPage")
        const choice = findChild(page, "todayDiscipline")
        const daitoryu = Programme.disciplines.findIndex(d => d.id === "daitoryu")
        choice.activated(daitoryu)
        compare(page.discipline, "daitoryu")
        compare(Programme.discipline, "daitoryu", "the choice is kept")
        popPage()
        const again = push("TodayPage")
        compare(again.discipline, "daitoryu")
        popPage()
        Programme.discipline = "aikido"
    }

    // The page is drawn before its due rows and interval fields: they come in the next frames
    // (half its time with five years of use, tst_perf). A row's tap still opens the sheet.
    function test_7_today_rows_later() {
        const grade = PracticeGrade.grade("daitoryu")
        Programme.discipline = "daitoryu"
        PracticeGrade.setGrade("daitoryu", "k1")
        window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/TodayPage.qml"))
        const page = window.pageStack.currentItem
        verify(!page.built)
        compare(findChild(page, "intervalDays"), null, "made with the page")
        tryVerify(() => page.built)
        verify(findChild(page, "intervalDays"))

        verify(page.due.length > 0, "techniques due")
        const row = findChild(page, "dueRow")
        compare(row.text, page.due[0].title)
        row.clicked()
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, page.due[0].id)
        sheet.close()
        tryVerify(() => !sheet.visible)
        popPage()
        PracticeGrade.setGrade("daitoryu", grade)
        Programme.discipline = "aikido"
    }

    // Training plays today's due techniques; a rating moves on to the next open one.
    function test_7b_training() {
        // Daitoryu: nothing practised there yet today, two new ones are due.
        Programme.discipline = "daitoryu"
        PracticeGrade.setGrade("daitoryu", "k5")
        const today = push("TodayPage")
        const playable = today.due.filter(r => !!r.video && Videos.available(r.video.video))
        if (playable.length < 2) {
            skip("no video for Daitoryu 5. Kyu (set MITORI_VIDEOS)")
        }
        today.startTraining()
        tryVerify(() => window.pageStack.currentItem.training === true)
        const player = window.pageStack.currentItem
        compare(player.index, 0)
        // Skip the first with "next", rate the second: the training goes back to the skipped one.
        player.go(1)
        compare(player.index, 1)
        findPicker(player, player.current.id).picked(3)
        compare(player.index, 0, "back to the open one that was skipped")
        findPicker(player, player.current.id).picked(2)
        if (player.playlist.length > 2) {
            compare(player.index, 2, "rating moves on")
        }
        // The last one rated: the player goes, its end stands above today's page.
        while (window.pageStack.currentItem === player) {
            findPicker(player, player.current.id).picked(2)
        }
        verify(window.pageStack.currentItem.count > 0)
        window.pageStack.currentItem.close()
        tryVerify(() => window.pageStack.currentItem === today)
        popPage()
    }

    // Training on a tablet sideways: "Comment" beside the list opens the technique's comment.
    function test_7a_training_comment() {
        const rows = Programme.entries("shinkitoho", "shoden").filter(r => r.kind === "entry" && r.comment).slice(0, 2)
        verify(rows.length > 0, "Shinki Toho has comments")
        window.width = 1280
        window.height = 800
        wait(200)
        const player = push("PlayerPage", { playlist: rows, index: 0, training: true })
        tryVerify(() => player.split)
        const button = findChild(player, "commentButton")
        tryVerify(() => button.visible)
        button.clicked()
        tryVerify(() => window.pageStack.currentItem !== player, 2000, "the comment page opens")
        compare(window.pageStack.currentItem.entry.id, rows[0].id)
        compare(player.autoPlay, false, "a file still loading stays quiet under the page")
        popPage()
        tryVerify(() => window.pageStack.currentItem === player)
        verify(player.autoPlay)
    }

    // The comment over the training: quiet, whether the file plays or is still loading.
    function test_7a_training_comment_quiet() {
        const rows = Programme.entries("shinkitoho", "shoden").filter(r => r.kind === "entry" && r.comment && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Shinki Toho Shoden (set MITORI_VIDEOS)")
        }
        window.width = 1280
        window.height = 800
        wait(200)

        // Still loading another file (the next technique of a training): the tap comes before its
        // LoadedMedia, in this very event.
        const other = rows.findIndex(r => r.video.video !== rows[0].video.video)
        if (other < 0 || !Videos.available(rows[other].video.video)) {
            skip("no second video for Shinki Toho Shoden (set MITORI_VIDEOS)")
        }
        const loading = push("PlayerPage", { playlist: rows, index: 0, training: true })
        tryVerify(() => loading.playing, mediaLoads)
        loading.index = other
        verify(loading.startPending)
        findChild(loading, "commentButton").clicked()
        verify(loading.startPending)
        tryVerify(() => !loading.startPending, mediaLoads)
        wait(500)
        verify(!loading.playing, "no sound under the comment")
        popPage()
        tryVerify(() => window.pageStack.currentItem === loading)
        popPage()
        wait(800)

        // Playing: it rests under the comment.
        const playing = push("PlayerPage", { playlist: rows, index: 0, training: true })
        tryVerify(() => playing.playing, mediaLoads)
        findChild(playing, "commentButton").clicked()
        tryVerify(() => window.pageStack.currentItem !== playing, 2000)
        tryVerify(() => !playing.playing, 2000, "it pauses under the comment")
        popPage()
        tryVerify(() => window.pageStack.currentItem === playing)
        verify(!playing.playing, "it waits for a tap")
        popPage()
        wait(800)
    }

    // Sideways the training keeps its ratings: the list beside the small player (clickdummy
    // "session"). It was a dead end on a tablet: the picture and no way to rate or go on.
    function test_7b_training_sideways() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry").slice(0, 3)
        const width = window.width, height = window.height
        window.width = 1280
        window.height = 800
        wait(200)
        const player = push("PlayerPage", { playlist: rows, index: 0, training: true })
        tryVerify(() => player.split)
        const list = findChild(player, "trainingSideList")
        verify(list.visible)
        compare(list.count, 3)
        verify(findChild(player, "ratingRow").visible)
        verify(!player.headless, "the head with its Back stays")
        // A row goes to its technique; the current one is marked.
        tryVerify(() => list.width > 100 && list.height > 100, 2000, list.width + " × " + list.height)
        tryVerify(() => list.itemAtIndex(2) !== null)
        verify(!list.itemAtIndex(2).focusOnClick, "Space stays with the player")
        list.itemAtIndex(2).clicked()
        compare(player.index, 2)
        verify(list.itemAtIndex(2).selected)
        // Full screen has no list; back it is there again.
        player.big = true
        verify(!player.split)
        player.big = false
        tryVerify(() => player.split)
        window.back()
        tryVerify(() => window.pageStack.currentItem !== player)
        window.width = width
        window.height = height
        wait(200)
    }

    // The title says which variant it is: as the list does.
    function test_7b_player_title_has_the_addition() {
        const rows = ["k5", "k4", "k3", "k2", "k1"].reduce((all, g) => all.concat(Programme.entries("aikido", g)), []).filter(r => r.kind === "entry" && r.extra && !r.nr)
        verify(rows.length > 0)
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        verify(player.title.indexOf(rows[0].extra) >= 0, player.title)
        window.back()
        tryVerify(() => window.pageStack.currentItem !== player)
    }

    // Esc leaves the player as Back does, upright too.
    function test_7b_escape_leaves() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        tryVerify(() => player.activeFocus || player.isCurrentPage)
        wait(300)
        keyClick(Qt.Key_Escape)
        tryVerify(() => window.pageStack.currentItem !== player, 2000)
    }

    // Training without videos (CI): every due technique comes in, shown as a card, with the
    // playlist (✓, tap jumps), the position and an end page with the count.
    function test_7c_training_list() {
        Programme.discipline = "daitoryu"
        PracticeGrade.setGrade("daitoryu", "k4")
        const today = push("TodayPage")
        verify(today.due.length >= 2, "Daitoryu 4. Kyu has due techniques")
        today.startTraining()
        tryVerify(() => window.pageStack.currentItem.training === true)
        const player = window.pageStack.currentItem
        compare(player.playlist.length, today.due.length, "every due technique, with or without a video")

        // Position and the card standing for a missing video.
        const place = findChild(player, "placeText")
        verify(place.text.endsWith("1 / " + player.playlist.length), place.text)
        verify(place.text.indexOf(player.current.gradeName) >= 0, place.text)
        if (!player.hasVideo) {
            verify(findChild(player, "noVideoCard").visible)
            verify(!findChild(player, "stage").visible)
        }

        // The playlist: one numbered row each, the current one selected, a tap jumps.
        const rows = findChildren(player, "trainingRow")
        compare(rows.length, player.playlist.length)
        verify(rows[0].selected)
        verify(rows[1].text.startsWith("2. "), rows[1].text)
        rows[1].clicked()
        compare(player.index, 1)
        verify(rows[1].selected && !rows[0].selected)
        verify(place.text.endsWith("2 / " + player.playlist.length), place.text)
        shot("7c-training-list")

        // Rating ticks the row; all rated: the end counts them.
        const before = player.practisedCount
        const practised = player.playlist.length
        findPicker(player, player.current.id).picked(3)
        verify(rows[1].done)
        compare(player.practisedCount, before + 1)
        while (window.pageStack.currentItem === player) {
            findPicker(player, player.current.id).picked(2)
        }
        const end = window.pageStack.currentItem
        compare(end.count, practised)
        compare(findChild(end, "practisedCount").value, String(practised))
        end.close()
        tryVerify(() => window.pageStack.currentItem === today)
        popPage()
    }

    // Up to `length` techniques not rated today, new for each case (the log stays for the run).
    function freshRows(length) {
        return Programme.entries("aikido", "k1").filter(r => r.kind === "entry" && !Practice.ratedToday(r.id)).slice(0, length)
    }

    // Today's page with a training above it, as startTraining leaves them.
    function trainingOver(rows) {
        const today = push("TodayPage")
        const player = push("PlayerPage", { playlist: rows, index: 0, training: true })
        tryVerify(() => window.pageStack.currentItem === player)
        return { today: today, player: player }
    }

    function hasPlayer() {
        return window.pageStack.items.some(p => p.playlist !== undefined)
    }

    // The last rating leaves the player for the end page, on a phone and a tablet (the list beside
    // the small player); each way back leads to today's page, no player left behind.
    function test_7d_training_end_data() {
        const button = () => findChild(window.pageStack.currentItem, "backToToday").clicked()
        return [
            { tag: "phone, button", width: 420, height: 800, back: button },
            { tag: "phone, Esc", width: 420, height: 800, back: () => keyClick(Qt.Key_Escape) },
            { tag: "phone, Back key", width: 420, height: 800, back: () => window.pageStack.goBack() },
            { tag: "phone, the head's Back", width: 420, height: 800, back: () => window.back() },
            { tag: "360 px, button", width: 360, height: 640, back: button },
            { tag: "tablet sideways, Esc", width: 1280, height: 800, videos: true, back: () => keyClick(Qt.Key_Escape) },
            { tag: "tablet sideways, Back key", width: 1280, height: 800, videos: true, back: () => window.pageStack.goBack() },
            { tag: "tablet upright, button", width: 800, height: 1280, videos: true, back: button }
        ]
    }
    function test_7d_training_end(data) {
        failOnWarning(/ReferenceError|TypeError/)
        if (data.videos) {
            realFolder = Videos.folder
            Videos.folder = standInVideos
        }
        window.width = data.width
        window.height = data.height
        wait(200)

        const rows = freshRows(2)
        const pages = trainingOver(rows)
        findPicker(pages.player, rows[0].id).picked(3)
        compare(window.pageStack.currentItem, pages.player, "one is open")
        compare(pages.player.index, 1)
        findPicker(pages.player, rows[1].id).picked(2)

        // Not the player any more, and nothing of it under the end.
        tryVerify(() => window.pageStack.currentItem.count === 2)
        const end = window.pageStack.currentItem
        compare(window.pageStack.depth, pages.today.Kirigami.ColumnView.index + 2)
        compare(end.Kirigami.ColumnView.index, pages.today.Kirigami.ColumnView.index + 1)
        verify(!hasPlayer(), "the player is gone")
        compare(findChild(end, "practisedCount").value, "2")
        tryVerify(() => Math.abs(end.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)
        compare(JSON.stringify(overflowing(end, data.width)), "[]")
        shot("7d-training-end-" + data.width)

        data.back()
        tryVerify(() => window.pageStack.currentItem === pages.today, 2000)
        tryVerify(() => window.pageStack.depth === pages.today.Kirigami.ColumnView.index + 1, 2000, "nothing above today")
        verify(!hasPlayer())
    }

    // The end page's head has the style's page ground (KanteWindowScope's bar role), as any page
    // that slid in (it stood in the platform's colours). Shinki's head is the window's.
    function test_7d_training_end_head_data() {
        return [{ tag: "upright", width: 420, height: 800 }, { tag: "sideways", width: 800, height: 420 }]
    }
    function test_7d_training_end_head(data) {
        if (uiShinki) {
            skip("Shinki's head is the window's")
        }
        window.width = data.width
        window.height = data.height
        wait(200)
        const rows = freshRows(1)
        const pages = trainingOver(rows)
        wait(1500)      // at rest, as after practising: no slide still running
        findPicker(pages.player, rows[0].id).picked(3)
        tryVerify(() => window.pageStack.currentItem.count === 1)
        const page = window.pageStack.currentItem
        const ground = () => page.Kirigami.ColumnView.globalHeader.item.background.color
        tryVerify(() => Qt.colorEqual(ground(), KanteStyle.backgroundColor), 2000,
                  "head " + ground() + ", expected " + KanteStyle.backgroundColor)
    }

    // Full screen has no rating; should one come, the window comes back as it was.
    function test_7d_training_end_big() {
        realFolder = Videos.folder
        Videos.folder = standInVideos
        const before = window.visibility
        const rows = freshRows(1)
        const pages = trainingOver(rows)
        pages.player.big = true
        compare(window.visibility, Window.FullScreen)
        verify(Practice.rate(rows[0].id, 2))
        findChild(pages.player, "ratingRow").rated(2)
        tryVerify(() => window.pageStack.currentItem.count === 1)
        compare(window.visibility, before)
        verify(!hasPlayer())
    }

    // A second tap on the last rating: one end page, not two.
    function test_7d_training_end_once() {
        const rows = freshRows(1)
        const pages = trainingOver(rows)
        const row = findChild(pages.player, "ratingRow")
        verify(Practice.rate(rows[0].id, 2))
        row.rated(2)
        row.rated(2)
        tryVerify(() => window.pageStack.currentItem.count === 1)
        compare(window.pageStack.depth, pages.today.Kirigami.ColumnView.index + 2)
        window.pageStack.currentItem.close()
        tryVerify(() => window.pageStack.currentItem === pages.today)
    }

    // Rating one already done again, others open: on to the open one, no end. With all done before
    // the player opened (a sync, midnight): it plays, and the next rating ends it, no loop.
    function test_7d_training_rated_again() {
        const rows = freshRows(2)
        const pages = trainingOver(rows)
        findPicker(pages.player, rows[0].id).picked(3)
        pages.player.index = 0
        findPicker(pages.player, rows[0].id).picked(4)
        compare(window.pageStack.currentItem, pages.player)
        compare(pages.player.index, 1)
        findPicker(pages.player, rows[1].id).picked(3)
        tryVerify(() => window.pageStack.currentItem.count === 2)
        window.pageStack.currentItem.close()
        tryVerify(() => window.pageStack.currentItem === pages.today)

        const again = push("PlayerPage", { playlist: rows, index: 1, training: true })
        tryVerify(() => window.pageStack.currentItem === again)
        compare(again.index, 1, "it stays where it was opened")
        findPicker(again, rows[1].id).picked(4)
        tryVerify(() => window.pageStack.currentItem.count === 2)
        window.pageStack.currentItem.close()
        tryVerify(() => window.pageStack.currentItem === pages.today)
    }

    // A training done today: not due any more, so today's page offers none and opens nothing.
    function test_7d_training_done_today() {
        const grade = PracticeGrade.grade("daitoryu")
        Programme.discipline = "daitoryu"
        PracticeGrade.setGrade("daitoryu", "k3")
        const today = push("TodayPage")
        verify(today.due.length > 0, "new techniques are due")
        const button = findChild(today, "startTraining")
        verify(button.visible)
        button.clicked()
        tryVerify(() => window.pageStack.currentItem.training === true)
        const player = window.pageStack.currentItem
        while (window.pageStack.currentItem === player) {
            findPicker(player, player.current.id).picked(3)
        }
        window.pageStack.currentItem.close()
        tryVerify(() => window.pageStack.currentItem === today)
        const depth = today.Kirigami.ColumnView.index + 1
        tryVerify(() => window.pageStack.depth === depth)

        compare(today.due.length, 0)
        verify(!button.visible)
        today.startTraining()
        wait(50)
        compare(window.pageStack.currentItem, today)
        compare(window.pageStack.depth, depth)
        PracticeGrade.setGrade("daitoryu", grade)
    }

    // A clip that plays: the last rating stops it, also after the window turned (Kirigami's pop()
    // then keeps a page, PlayerPage.leave). Needs MITORI_VIDEOS (none in the repository).
    function test_7d_training_end_stops_data() {
        return [{ tag: "upright", turned: false }, { tag: "turned sideways", turned: true }]
    }
    function test_7d_training_end_stops(data) {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video && Videos.available(r.video.video)
                                                                   && !Practice.ratedToday(r.id)).slice(0, 1)
        if (rows.length === 0) {
            skip("no video (set MITORI_VIDEOS)")
        }
        const pages = trainingOver(rows)
        tryVerify(() => pages.player.playing, mediaLoads)
        if (data.turned) {
            window.width = 800
            window.height = 420
            tryVerify(() => pages.player.split)
            wait(200)
        }

        // The player's last word: it goes at once, so ask it as it goes.
        let stopped = false
        pages.player.playingChanged.connect(() => stopped = true)
        findPicker(pages.player, rows[0].id).picked(3)
        tryVerify(() => window.pageStack.currentItem.count === 1)
        verify(stopped, "it stopped playing")
        verify(!hasPlayer())
    }

    // Notes: add one for today from the field, change it and delete it (press and hold).
    function test_8_notes() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        const page = push("NotesPage", { entry: entry })
        compare(page.notes.length, 0)
        const compose = findChild(page, "compose")
        compose.text = "Hüfte früher drehen"
        compose.accepted()                              // Enter in the field
        compare(page.notes.length, 1)
        compare(compose.text, "")
        compare(Practice.lastNote(entry.id).text, "Hüfte früher drehen")
        compare(page.days.length, 1)
        Practice.addNote(entry.id, "Blick beim Partner")
        compare(page.days[0].notes.length, 2)
        shot("8-notes")
        const note = findChild(page, "note")
        verify(note)
        // Tab to a note: the style's focus frame (Shinki: 2 px ink, not red, which means chosen).
        note.forceActiveFocus(Qt.TabFocusReason)
        if (uiShinki) {
            verify(Qt.colorEqual(note.background.border.color, Look.textColor), "focus in ink: " + note.background.border.color)
            verify(note.background.border.width >= 2, "focus 2 px: " + note.background.border.width)
        }
        mousePress(note, 20, note.height - 10)
        wait(1000)
        mouseRelease(note, 20, note.height - 10)
        const editor = findChild(page, "noteEditor")
        tryVerify(() => editor.opened, 2000, "press and hold opens the editor")
        compare(editor.note.uid, page.notes[0].uid)
        // Save from the editor.
        findChild(editor, "noteArea").text = "Hüfte viel früher drehen"
        editor.customFooterActions[1].trigger()
        tryVerify(() => !editor.opened)
        compare(page.notes[0].text, "Hüfte viel früher drehen")
        // Right-click the second note, delete it from the editor.
        wait(500)                                       // the editor's overlay fades out
        const second = findChildren(page, "note").find(n => n.modelData.uid === page.notes[1].uid)
        mouseClick(second, 20, second.height / 2, Qt.RightButton)
        tryVerify(() => editor.opened)
        compare(editor.note.uid, page.notes[1].uid)
        editor.customFooterActions[0].trigger()
        tryVerify(() => !editor.opened)
        compare(page.notes.length, 1)
        compare(findChild(page, "dayName").text, "Today")
        popPage()
    }

    // The sheet from the search: "Enter code" leads to the videos (as from the programme).
    function test_9_search_sheet_code() {
        const page = push("SearchPage")
        findChild(page, "searchField").text = "ikkyo shomen"
        tryVerify(() => page.techniques.length > 0, 2000)
        const result = page.techniques.find(r => !!r.video && !Videos.available(r.video.video))
        if (!result) {
            skip("every Ikkyo video is on this device")
        }
        const sheet = findChild(page, "techniqueSheet")
        sheet.entry = result
        sheet.playable = false
        sheet.open()
        tryVerify(() => sheet.opened)
        findChild(sheet.contentItem, "sheetCodeButton").clicked()
        tryVerify(() => window.pageStack.currentItem.title === "Videos", 2000, "the videos page opens")
        popPage()
        popPage()
    }

    // Glossary on a tablet sideways: a rail that stays, the list, the detail of the word tapped.
    function test_9_glossary_wide() {
        failOnWarning(/SearchPage.qml.*(TypeError|ReferenceError)|WordDetail.qml.*(TypeError|ReferenceError)/)
        window.width = 1280
        window.height = 800
        wait(100)       // the page opens with the keyboard focus on the field: it takes its columns from this size
        const page = push("SearchPage")
        tryVerify(() => page.wide)
        slidIn()
        const list = findChild(page, "glossaryList")
        const rail = findChild(page, "letterRail")
        const detail = findChild(page, "glossaryDetail")
        tryVerify(() => rail.visible && detail.visible)
        verify(!findChild(page, "letterRailPhone").visible)
        tryCompare(list, "count", Glossary.words.length)
        verify(page.usedLetters.length > 10)
        verify(page.usedLetters.every(l => page.alphabet.indexOf(l) >= 0), "every section is a letter of A–Z")

        // Before a tap the pane shows the first word.
        compare(findChild(detail, "detailWord").text, Glossary.words[0].word)
        compare(findChild(page, "detailKanji").visible, Glossary.words[0].jp !== "")

        // The rail stays in place, and follows the section in view.
        const before = rail.mapToItem(page, 0, 0)
        const far = page.usedLetters[Math.floor(page.usedLetters.length * 0.6)]     // the last sections are too short to reach the top
        list.contentY = list.originY + 3 * list.height
        waitForRendering(list)
        const after = rail.mapToItem(page, 0, 0)
        compare(after.x, before.x)
        compare(after.y, before.y)
        verify(rail.current !== "A" && rail.current !== "", "the rail follows the list: " + rail.current)
        verify(rail.mapToItem(page, 0, 0).x + rail.width <= list.mapToItem(page, 0, 0).x + 0.5, "the rail is left of the list")

        // The rail is for the keyboard and the screen reader too.
        const letterA = railLetter(rail, page.usedLetters[0])
        compare(letterA.Accessible.role, Accessible.Button)
        verify(letterA.Accessible.name.indexOf(page.usedLetters[0]) >= 0, letterA.Accessible.name)
        rail.forceActiveFocus()
        tryVerify(() => rail.activeFocus)
        const here = list.currentSection
        keyClick(Qt.Key_Down)
        tryVerify(() => list.currentSection !== here, 1000, "Down goes to the next letter")
        keyClick(Qt.Key_Up)
        tryCompare(list, "currentSection", here)
        list.positionViewAtBeginning()

        // A letter without words is grey and does not react.
        const none = page.alphabet.find(l => page.usedLetters.indexOf(l) < 0)
        if (none !== undefined) {
            verify(!railLetter(rail, none).has)
            const was = list.contentY
            mouseClick(railLetter(rail, none))
            wait(100)
            compare(list.contentY, was)
        }

        // A tap on a letter goes to its section; the letter lights up.
        mouseClick(railLetter(rail, far))
        tryCompare(list, "currentSection", far)
        tryCompare(rail, "current", far)
        verify(railLetter(rail, far).isCurrent)
        verify(list.contentY > list.height)
        const idx = page.glossary.findIndex(w => w.letter === far)
        tryVerify(() => Math.abs(list.itemAtIndex(idx).y - list.contentY) < list.height / 4, 1000, "the section is at the top")

        // A tap on a word shows it in the pane and does not say it.
        saySpy.clear()
        list.positionViewAtBeginning()
        const row = findChildren(list, "glossaryRow").find(r => r.found.word === "Ago")
        tryVerify(() => !!row)
        mouseClick(row, row.width / 3, row.height / 2)
        tryCompare(findChild(page, "detailWord"), "text", "Ago")
        compare(findChild(page, "detailMeaning").text, row.found.meaning)
        compare(saySpy.count, 0)
        // Ago is no whole word of any technique's name: no section.
        compare(findChildren(page, "detailHit").length, 0)
        verify(!findChild(page, "detailHitsHead").visible)
        // The kanji at the row's end are not smaller than the row's word.
        const kanji = findChild(row, "rowKanji")
        const name = allChildren(row).find(c => c.text === "Ago" && c.objectName !== "rowKanji")
        verify(kanji.visible && !!name, "kanji " + kanji.visible + " name " + name + " " + allChildren(row).filter(c => c.text !== undefined).map(c => c.text).join("|"))
        verify(kanji.font.pixelSize >= name.font.pixelSize && kanji.font.pointSize >= name.font.pointSize,
               "kanji " + kanji.font.pointSize + "/" + kanji.font.pixelSize + " word " + name.font.pointSize + "/" + name.font.pixelSize)
        shot("9-glossary-wide")
        const kiri = Glossary.words.find(w => w.word === "Kiri-otoshi")
        page.chosen = kiri
        tryCompare(findChild(page, "detailKanji"), "text", kiri.jp)
        compare(findChild(page, "detailWord").text, "Kiri-otoshi")
        tryVerify(() => findChildren(page, "detailHit").length > 0, 2000, "techniques of the word")
        // All of them, not the first five; none looks like another (the attack tells them apart).
        const hits = findChildren(page, "detailHit")
        verify(hits.length >= 10, "every technique named Kiri-otoshi: " + hits.length)
        // The addition stands once: in the title or, with a form number, in the subtitle.
        for (const h of hits) {
            const named = h.text.indexOf("(") >= 0 ? h.text.slice(h.text.indexOf("(") + 1, -1) : ""
            verify(named === "" || h.subtitle.indexOf(named) < 0, "twice: " + h.text + " / " + h.subtitle)
        }
        compare(new Set(hits.map(h => h.leadingText + h.subtitle)).size, hits.length, "subtitles: " + hits.map(h => h.leadingText + h.subtitle))
        shot("9-glossary-wide-hits")

        // A search keeps working, the rail goes.
        findChild(page, "searchField").text = "hüftwurf"
        tryCompare(page, "searching", true)
        tryVerify(() => !rail.visible)
        verify(page.glossary.some(w => w.word === "Koshi-nage"))
        tryCompare(findChild(page, "detailWord"), "text", page.glossary[0].word)
        popPage()
    }

    // Glossary on a phone: the rail at the right edge, a tap or a drag over it jumps.
    function test_9_glossary_phone() {
        failOnWarning(/SearchPage.qml.*(TypeError|ReferenceError)|LetterRail.qml.*(TypeError|ReferenceError)/)
        window.width = 360
        window.height = 800
        const page = push("SearchPage")
        slidIn()
        verify(!page.wide)
        const list = findChild(page, "glossaryList")
        const rail = findChild(page, "letterRailPhone")
        tryVerify(() => rail.visible)
        verify(!findChild(page, "glossaryDetail").visible)
        tryCompare(list, "count", Glossary.words.length)
        tryCompare(page, "width", 360)
        tryVerify(() => Math.abs(rail.mapToItem(page, rail.width, 0).x - page.width) < 1, 2000,
                  "the rail at the right edge: " + rail.mapToItem(page, rail.width, 0).x + " of " + page.width)
        verify(rail.mapToItem(page, 0, 0).x > list.mapToItem(page, 0, 0).x + list.width / 2, "right of the list")
        verify(findChildren(rail, "railLetter").length === page.alphabet.length, "all letters")
        verify(list.headerItem.height < list.height / 4, "the hints stay short: " + list.headerItem.height)

        // Pinned heading: the section's letter stays at the top while its rows scroll.
        const mid = page.usedLetters[Math.floor(page.usedLetters.length / 2)]
        mouseClick(railLetter(rail, mid))
        tryCompare(list, "currentSection", mid)
        list.contentY += list.height / 3
        waitForRendering(list)
        compare(list.currentSection, mid)
        const heads = findChildren(list, "letterHeading").filter(h => h.text === mid)
        verify(heads.some(h => h.mapToItem(list, 0, 0).y <= 1 && h.mapToItem(list, 0, 0).y >= -1), "the heading is pinned at the top")
        shot("9-glossary-phone")

        // A drag over the rail jumps, a bubble shows the letter beside the finger.
        const first = page.usedLetters[0]
        const last = page.usedLetters[Math.floor(page.usedLetters.length * 0.6)]
        const start = railLetter(rail, first)
        const stop = railLetter(rail, last)
        const bubble = findChild(rail, "railBubble")
        mousePress(start, start.width / 2, start.height / 2)
        tryCompare(list, "currentSection", first)
        verify(bubble.visible, "a bubble while dragging")
        const sy = start.mapToItem(rail, 0, 0).y
        const ey = stop.mapToItem(rail, 0, 0).y
        for (let i = 1; i <= 10; i++) {
            mouseMove(start, start.width / 2, start.height / 2 + (ey - sy) * i / 10)
        }
        tryCompare(list, "currentSection", last)
        verify(bubble.x + bubble.width <= 0, "the bubble beside the rail")
        shot("9-glossary-phone-drag")
        mouseRelease(start, start.width / 2, start.height / 2 + (ey - sy))
        verify(!bubble.visible)

        // A tap on a word says it, as before.
        saySpy.clear()
        list.positionViewAtBeginning()
        const inView = () => findChildren(list, "glossaryRow").find(r => r.mapToItem(list, 0, 0).y > list.headerItem.height
                                                                         && r.mapToItem(list, 0, r.height).y < list.height)
        tryVerify(() => !!inView())
        const row = inView()
        mouseClick(row, row.width / 3, row.height / 2)
        compare(saySpy.count, 1)
        popPage()
    }

    // Search: techniques across disciplines and own notes; a result opens the sheet.
    function test_9_search() {
        // A reused row between notes, words and techniques reads its kind and data together.
        failOnWarning(/SearchPage.qml.*TypeError/)
        Practice.addNote(Programme.entries("aikido", "k5").find(r => r.kind === "entry").id, "Kreis größer machen")
        const page = push("SearchPage")
        const field = findChild(page, "searchField")
        field.text = "ikkyo shomen"
        tryVerify(() => page.techniques.length > 0, 2000)
        verify(page.techniques.every(r => r.discipline !== undefined))
        compare(page.notes.length, 0)
        field.text = "kreis grosser"                    // größer without umlaut and ß
        tryVerify(() => page.query === "kreis grosser", 2000)
        compare(page.notes.length, 1)
        // More than the list shows: a hint to narrow the search.
        field.text = "nage"
        tryVerify(() => page.query === "nage", 2000)
        verify(page.more, "more than the list shows")
        compare(page.shown.length, page.limit)
        // The list is virtual: the hint below the rows is made when it comes into view.
        findChild(page, "glossaryList").positionViewAtEnd()
        tryVerify(() => findChild(page, "moreHint") !== null && findChild(page, "moreHint").visible)
        // The notes have the same limit and hint.
        for (let i = 0; i <= page.limit; i++)
            Practice.addNote("many-notes", "Wiederholung " + i)
        field.text = "wiederholung"
        tryVerify(() => page.query === "wiederholung", 2000)
        verify(page.notesMore)
        compare(page.notesShown.length, page.limit)
        findChild(page, "glossaryList").positionViewAtEnd()
        tryVerify(() => findChild(page, "notesMoreHint") !== null && findChild(page, "notesMoreHint").visible)
        // A note on a technique that is no longer in the programme still opens its notes.
        Practice.addNote("gone-technique", "Kreis kleiner")
        field.text = "kreis kleiner"
        tryVerify(() => page.query === "kreis kleiner", 2000)
        compare(page.notes.length, 1)
        const orphan = findChild(page, "noteResult")
        mouseClick(orphan, orphan.width / 3, orphan.height / 2)
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        compare(window.pageStack.currentItem.entry.id, "gone-technique")
        verify(window.pageStack.currentItem.notes.length === 1)
        popPage()
        field.text = "ikkyo"
        tryVerify(() => page.query === "ikkyo", 2000)
        verify(!page.more)
        shot("9-search")
        const result = findChild(page, "techniqueResult")
        mouseClick(result, result.width / 3, result.height / 2)
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened, 2000)
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()
    }

    // Search: a word of a Shinki Toho comment finds the technique and opens the comment; a word of a
    // course note finds the entry and opens its notebook.
    function test_9_search_comments_courses() {
        failOnWarning(/SearchPage.qml.*TypeError/)
        const course = Courses.create("Winterlehrgang", "2026-01-10", "2026-01-11", "", "")
        verify(Courses.addEntry(course, "Erste Zeile\nSchwebende Hüftdrehung geübt"))
        const page = push("SearchPage")
        const field = findChild(page, "searchField")

        field.text = "hochst angespannte"                // höchst without umlaut
        tryVerify(() => page.comments.length > 0, 2000)
        compare(page.courseEntries.length, 0)
        const hit = findChild(page, "commentResult")
        tryVerify(() => hit !== null && hit.visible)
        verify(hit.subtitle.indexOf("höchst") >= 0, hit.subtitle)
        shot("9-search-comments")
        mouseClick(hit, hit.width / 3, hit.height / 2)
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        verify(window.pageStack.currentItem.entry.comment.text.indexOf("höchst") >= 0)
        popPage()

        field.text = "schwebende hüftdrehung"
        tryVerify(() => page.courseEntries.length === 1, 2000)
        compare(page.comments.length, 0)
        const entry = findChild(page, "courseEntryResult")
        tryVerify(() => entry !== null && entry.visible)
        compare(entry.text, "Schwebende Hüftdrehung geübt")
        verify(entry.subtitle.indexOf("Winterlehrgang") === 0, entry.subtitle)
        shot("9-search-course-notes")
        mouseClick(entry, entry.width / 3, entry.height / 2)
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        compare(window.pageStack.currentItem.uid, course)
        popPage()
        verify(Courses.remove(course))
    }

    // Courses: the coming dates from the calendar (a local file in this test), a date's notebook
    // with an entry, a course of one's own, deleting a notebook.
    function test_9m_courses() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        tryCompare(window.pageStack, "depth", 1)
        wait(500)
        const tile = findChild(window.pageStack.items[0], "coursesTile")
        verify(tile && tile.visible)
        clickTile(tile)
        tryCompare(window.pageStack, "depth", 2)
        const page = window.pageStack.currentItem
        tryVerify(() => page.title === qsTr("Courses"))
        tryCompare(Courses, "calendarState", Courses.CalendarState.Ready, 5000)
        tryVerify(() => findChildren(page, "eventRow").length === 2)
        const rows = findChildren(page, "eventRow")
        compare(rows[0].course.title, "Daitoryu Aiki Jujutsu")
        compare(rows[0].course.teacher, "M. D. Nakajima Shihan")
        compare(rows[0].daysAway, 12)
        compare(rows[1].daysAway, 40)
        // The first day as a local day (no time zone moves it to the day before).
        compare(rows[0].firstDay.getDate(), new Date(Date.now() + 12 * 86400000).getDate())
        compare(findChildren(page, "notebookRow").length, 0, "the list lives on its own page")
        tryVerify(() => findChild(window.pageStack.items[0], "coursesTile").hint.indexOf("Siebeldingen") === 0)
        shot("14-courses")

        // "My notebooks" says how many, and opens the list: empty, it says how to make one.
        const notebooksTile = findChild(page, "myNotebooks")
        verify(notebooksTile.visible)
        verify(notebooksTile.hint.indexOf("0") === 0, notebooksTile.hint)
        verify(findChild(page, "myGrades").visible)
        mouseClick(notebooksTile)
        tryCompare(window.pageStack, "depth", 3)
        const emptyList = window.pageStack.currentItem
        tryVerify(() => emptyList.title === "My notebooks")
        verify(findChild(emptyList, "notebooksEmpty").visible)
        compare(findChildren(emptyList, "notebookRow").length, 0)
        shot("14a-notebooks-empty")
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        slidIn()

        // A date opens its notebook, made on first use; an entry is added from the field.
        mouseClick(rows[0])
        tryCompare(window.pageStack, "depth", 3)
        const book = window.pageStack.currentItem
        tryVerify(() => book.title === qsTr("Notebook"))
        compare(findChild(book, "courseTitle").text, "Daitoryu Aiki Jujutsu")
        verify(findChild(book, "announcement").visible, "the calendar names an announcement")
        verify(findChild(book, "toCalendar").visible)
        const compose = findChild(book, "courseCompose")
        compose.text = "Kote-gaeshi aus Tsuki"
        compose.accepted()                              // Enter in the field
        tryVerify(() => book.entries.length === 1)
        compare(compose.text, "")
        tryVerify(() => findChildren(book, "courseEntry").length === 1)
        shot("14b-course-notebook")
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        tryVerify(() => findChildren(page, "eventRow")[0].course.entries === 1)
        const dateBook = Courses.notebookFor("ui-daito")
        compare(dateBook, book.uid, "the same notebook again")

        // The date's notebook is counted and listed; a tap on its row opens it.
        verify(notebooksTile.hint.indexOf("1") === 0, notebooksTile.hint)
        slidIn()
        mouseClick(notebooksTile)
        tryCompare(window.pageStack, "depth", 3)
        const list = window.pageStack.currentItem
        tryVerify(() => findChildren(list, "notebookRow").length === 1)
        verify(!findChild(list, "notebooksEmpty").visible)
        const listed = findChildren(list, "notebookRow")[0]
        compare(listed.course.uid, dateBook)
        shot("14d-notebooks")
        mouseClick(listed)
        tryCompare(window.pageStack, "depth", 4)
        tryVerify(() => window.pageStack.currentItem.uid === dateBook)
        popPage()
        tryVerify(() => window.pageStack.currentItem === list)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)

        // A course of one's own: "New course" stays on this page.
        page.actions.find(a => a.objectName === "newCourse").trigger()
        tryVerify(() => findChild(window.pageStack.currentItem, "makeCourse") !== null)
        const made = window.pageStack.currentItem
        verify(!findChild(made, "makeCourse").enabled, "a title is needed")
        findChild(made, "courseTitleField").text = "Training mit Gastlehrer"
        findChild(made, "coursePlace").text = "Dojo Weimar"
        tryVerify(() => findChild(made, "makeCourse").enabled)
        mouseClick(findChild(made, "makeCourse"))
        tryVerify(() => window.pageStack.currentItem !== made && window.pageStack.currentItem.uid !== undefined)
        const own = window.pageStack.currentItem
        compare(own.course.title, "Training mit Gastlehrer")
        compare(own.course.place, "Dojo Weimar")
        verify(!findChild(own, "announcement").visible)
        // Deleting it asks first.
        const remove = findChild(own, "removeCourse")
        remove.open()
        tryVerify(() => remove.opened)
        shot("14c-course-delete", true)
        remove.accept()
        tryVerify(() => window.pageStack.currentItem === page, 3000)
        compare(Courses.notebooks.length, 1)
        popPage()
    }

    // A tile's title, the label that shows its text.
    function tileTitle(tile) {
        return allChildren(tile).find(c => c.text === tile.text && c.lineCount !== undefined)
    }

    // Lines break between words only: "Meine / Notizbüche / r" has more lines than words.
    function checkTitle(tile) {
        const title = tileTitle(tile)
        const words = tile.text.split(" ").length
        verify(title.lineCount <= words, tile.text + ": " + title.lineCount + " lines, broken inside a word")
        verify(title.contentWidth <= title.width + 1, tile.text + " runs past its tile")
    }

    // The start menu in German (the run stays English: the catalog, not installed), Shinki only
    // (its tile is ours). A single word too long for a line may end in an ellipsis.
    function checkStartTiles() {
        const tiles = findChild(window.pageStack.items[0], "tiles")
        wait(100)
        const shown = []
        for (let i = 0; i < tiles.children.length; i++) {
            if (tiles.children[i].visible && tiles.children[i].glyph !== undefined) {
                shown.push(tiles.children[i])
            }
        }
        verify(shown.length >= 6, "the start tiles: " + shown.length)
        for (const tile of shown) {
            const english = tile.text
            tile.text = uiCatalog.german("StartPage", english)
            verify(tile.text !== "", "no German for " + english)
            wait(20)
            checkTitle(tile)
            tile.text = english
        }
    }

    // At 360 and 320 px, in every look of the Kante side (Shinki: ctest ui_shinki): the two tiles
    // lie side by side, equally wide and high, with no text cut, however many grades there are.
    function test_9m_tiles_fit_data() {
        const looks = Look.shinki ? [{ tag: "shinki" }]
                                  : [{ tag: "system", kind: KanteStyle.Kind.System },
                                     { tag: "kante", kind: KanteStyle.Kind.Kante },
                                     { tag: "leinen", kind: KanteStyle.Kind.KanteLight }]
        const rows = []
        for (const width of [360, 320]) {
            for (const look of looks) {
                rows.push({ tag: look.tag + "-" + width, kind: look.kind, width: width })
            }
        }
        return rows
    }
    function test_9m_tiles_fit(data) {
        const kind = KanteStyle.kind
        if (!Look.shinki) {
            KanteStyle.kind = data.kind
        }
        window.width = data.width
        if (Look.shinki) {
            checkStartTiles()
        }
        for (const [discipline, grade] of [["aikido", "k5"], ["daitoryu", "k5"], ["shinkitoho", "shoden"]]) {
            verify(Courses.addGrade(discipline, grade, "2024-03-01", ""))
            const page = push("CoursesPage")
            wait(300)
            const grades = findChild(page, "myGrades")
            const notebooks = findChild(page, "myNotebooks")
            // The test runs in English; German is the longer (mitori_de.ts).
            grades.text = uiCatalog.german("CoursesPage", "My grades")
            notebooks.text = uiCatalog.german("CoursesPage", "My notebooks")
            notebooks.hint = "12 Notizbücher"
            wait(50)
            compare(grades.y, notebooks.y, "side by side")
            compare(grades.width, notebooks.width)
            compare(grades.height, notebooks.height)
            verify(notebooks.mapToItem(window.contentItem, notebooks.width, 0).x <= data.width)
            // "Notizbücher" fits no line of Shinki's tile at 320 px: only that title may end in an
            // ellipsis, and only there.
            const mayCut = Look.shinki && data.width < 360 ? tileTitle(notebooks) : null
            for (const item of allChildren(grades).concat(allChildren(notebooks))) {
                verify(!item.truncated || item === mayCut, grade + ": cut off: " + item.text)
            }
            checkTitle(grades)
            checkTitle(notebooks)
            // Shinki's text starts at the top of the tile: one title on two lines moves no other.
            if (Look.shinki) {
                compare(tileTitle(grades).mapToItem(window.contentItem, 0, 0).y,
                        tileTitle(notebooks).mapToItem(window.contentItem, 0, 0).y, "the titles' tops")
            }
            shot("14e-tiles-" + data.tag + "-" + discipline)
            popPage()
        }
        // The uids first: Courses.grades shrinks with each removal.
        for (const uid of Courses.grades.map(g => g.uid)) {
            verify(Courses.removeGrade(uid))
        }
        compare(Courses.grades.length, 0)
        KanteStyle.kind = kind
    }

    // Videos: a DVD's code unlocks its bundle (the test data's), which loads onto the device and
    // plays from there; a wrong code says why; removing keeps the code.
    function test_9n_videos() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const page = push("VideosPage")
        tryCompare(Bundles, "manifestState", Bundles.ManifestState.Ready, 5000)
        tryVerify(() => findChildren(page, "bundleRow").length === 1)
        const row = () => findChildren(page, "bundleRow")[0]
        compare(row().bundleState, Bundles.State.Locked)
        // A change of the list changes the row in place (a press on Cancel during a download
        // meets the same button when it is let go).
        const first = row()
        verify(!findChild(row(), "bundleAction").visible)
        const field = findChild(page, "codeField")
        const message = findChild(page, "codeMessage")
        field.text = "7KQ2M-X9HDV-3TAPR-WE6YA"          // check character wrong
        slidIn()
        mouseClick(findChild(page, "unlockButton"))
        tryVerify(() => message.visible)
        compare(message.text, qsTr("This code has a typing error; check it character by character."))
        shot("15-videos-code-wrong")
        field.text = "7kq2m x9hdv 3tapr we6yt"
        mouseClick(findChild(page, "unlockButton"))
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Installed, mediaLoads)
        verify(message.text.indexOf("Test") > 0, message.text)
        compare(field.text, "")
        verify(Videos.available("test/v"), "the bundle's video is on the device")
        compare(Videos.crop("test/v").h, undefined, "a bundle's file is cut already")
        verify(Bundles.size > 0)
        compare(findChildren(page, "bundleRow").length, 1)
        verify(row() === first, "the row stays through unlocking and loading")
        tryVerify(() => findChild(row(), "bundleAction").text === qsTr("Remove"))
        shot("15b-videos-loaded")
        mouseClick(findChild(row(), "bundleAction"))
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Unlocked)
        verify(!Videos.available("test/v"))
        compare(Bundles.bundles[0].code, "7KQ2M-X9HDV-3TAPR-WE6YT", "the code stays")
        popPage()
    }

    // A download shows its percentage as a counter and a bar under the row; waiting for Wi-Fi shows the
    // bar indeterminate; other states show neither. The rows are made up: a real download ends too fast.
    function test_9n_videos_download() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const page = push("VideosPage")
        tryCompare(Bundles, "manifestState", Bundles.ManifestState.Ready, 5000)
        tryVerify(() => findChildren(page, "bundleRow").length === 1)
        const model = findChild(page, "bundleModel")
        const real = Bundles.bundles[0]
        const fake = (st, pr) => { model.rows = [Object.assign({}, real, { state: st, progress: pr })] }
        const row = () => findChildren(page, "bundleRow")[0]
        const counter = () => findChild(row().parent, "bundleCounter")
        const bar = () => findChild(row().parent, "bundleBar")
        const odometer = () => findChild(row().parent, "bundleOdometer")

        slidIn()
        fake(Bundles.State.Unlocked, 0)
        tryVerify(() => row().bundleState === Bundles.State.Unlocked)
        verify(!counter().visible)
        verify(!bar().visible)
        verify(findChild(row(), "bundleState").visible)

        fake(Bundles.State.Downloading, 0.42)
        tryVerify(() => counter().visible)
        verify(bar().visible)
        verify(!bar().indeterminate)
        compare(bar().value, 0.42)
        compare(odometer().value, 42)
        // Kante's counter rolls Live (1): Show restarts its staggered roll on each new value, and a
        // download's 250 ms steps left the later reels behind (review of #137). Shinki rolls at once.
        if (!uiShinki) {
            compare(odometer().pace, 1, "KanteOdometer.Pace.Live")
        }
        compare(counter().Accessible.name, qsTr("loading %1 %").arg(42))
        verify(!findChild(row(), "bundleState").visible)
        shot("15c-videos-downloading")

        fake(Bundles.State.Waiting, 0)
        tryVerify(() => !counter().visible)
        verify(bar().visible)
        verify(bar().indeterminate)
        compare(findChild(row(), "bundleState").text, qsTr("waits for Wi-Fi"))
        shot("15d-videos-waiting")

        fake(Bundles.State.Installed, 1)
        tryVerify(() => !bar().visible)
        verify(!counter().visible)
        popPage()
    }

    // The Lernpakete in the list: none before its code (or on the device), then under their own head;
    // one in a format this version cannot read asks for an update, and can still be removed.
    readonly property string unsupportedId: "test-unsupported"
    function test_9n_videos_lessons() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        const page = push("VideosPage")
        tryCompare(Bundles, "manifestState", Bundles.ManifestState.Ready, 5000)
        tryVerify(() => findChildren(page, "bundleRow").length === 1)
        compare(findChildren(page, "bundleKind").filter(h => h.visible).map(h => h.text), ["Exam videos"])
        const rowOf = id => findChildren(page, "bundleRow").find(r => r.row.id === id)
        compare(rowOf(lessonId), undefined)
        compare(rowOf(unsupportedId), undefined)

        verify(uiCatalog.installLesson(unsupportedId, same))
        Bundles.reload()
        tryVerify(() => rowOf(unsupportedId) !== undefined)
        compare(findChildren(page, "bundleKind").filter(h => h.visible).map(h => h.text), ["Exam videos", "Learning videos"])
        compare(rowOf(unsupportedId).bundleState, Bundles.State.Unsupported)
        compare(findChild(rowOf(unsupportedId), "bundleState").text, qsTr("Needs a newer Mitori"))
        const action = findChild(rowOf(unsupportedId), "bundleAction")
        tryVerify(() => action.visible, 3000, "its videos can be removed")
        compare(action.text, qsTr("Remove"))
        // The list is taller than the window under Shinki: the row into view first.
        page.flickable.contentY = Math.max(0, action.mapToItem(page.flickable.contentItem, 0, 0).y - page.flickable.height / 2)
        wait(50)
        mouseClick(action)
        tryVerify(() => Bundles.bundles.every(b => b.id !== unsupportedId), 3000, "removed")
        // Removed and never unlocked (the test puts it on the shelf without a code): gone again.
        tryVerify(() => rowOf(unsupportedId) === undefined)
        popPage()
    }

    // The subtitles' size: only with learning videos (they bring the subtitles); a tap saves it.
    function test_9n_videos_subtitle_size() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        const page = push("VideosPage")
        const row = findChild(page, "subtitleSizeRow")
        verify(!row.visible, "no learning videos, no subtitles")

        verify(uiCatalog.installLesson(lessonId, same))
        Bundles.reload()
        tryVerify(() => row.visible)
        const choice = findChild(row, "subtitleSize")
        compare(choice.currentIndex, Videos.SubtitleSize.Normal)
        page.flickable.contentY = Math.max(0, row.mapToItem(page.flickable.contentItem, 0, 0).y - page.flickable.height / 2)
        wait(50)
        mouseClick(choice, choice.width * 5 / 8, choice.height / 2)       // the third of four: Large
        tryCompare(Videos, "subtitleSize", Videos.SubtitleSize.Large)
        compare(choice.currentIndex, Videos.SubtitleSize.Large)
        shot("15g-videos-subtitle-size")
        Videos.subtitleSize = Videos.SubtitleSize.Normal
        popPage()
    }

    // Where the videos lie: the app's own folder in use, a folder of one's own to pick (Linux); no
    // field for a folder of one's own videos any more.
    function test_9n_videos_storage() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const page = push("VideosPage")
        compare(findChild(page, "videoFolder"), null)
        const places = findChildren(page, "storagePlace")
        verify(places.length >= 1)
        compare(places[0].text, qsTr("On this device"))
        verify(places[0].selected)
        verify(findChild(page, "storageFolder").visible)
        verify(!findChild(page, "storageMissing").visible)
        verify(!findChild(page, "storageMoving").visible)
        verify(!findChild(page, "storageError").visible)
        // Another place with videos on the device: the page asks under the places, Cancel keeps all.
        const confirm = findChild(page, "storageConfirm")
        verify(!confirm.visible)
        page.pendingMove = { path: uiDataDir + "/card", name: "SD card" }
        tryVerify(() => confirm.visible)
        page.flickable.contentY = Math.max(0, page.flickable.contentHeight - page.flickable.height)
        wait(50)
        shot("15f-videos-storage-ask")
        page.pendingMove = null
        tryVerify(() => !confirm.visible)
        page.flickable.contentY = Math.max(0, page.flickable.contentHeight - page.flickable.height)
        wait(50)
        shot("15e-videos-storage")
        popPage()
    }

    // Learning videos (Lernpakete): without a package no tile (a code on the videos page brings one);
    // the page, still open when the last package goes, explains them and shows the way to the code.
    readonly property string lessonId: "test-lesson"
    function test_9p_lessons_empty() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const start = window.pageStack.items[0]
        tryCompare(Library.packages, "length", 0)
        verify(!findChild(start, "lessonsTile").visible)
        // 7 small tiles (today's practice spans both columns): the rest in pairs.
        const tiles = findChild(start, "tiles")
        compare(tiles.smallTiles, 7)
        verify(findChild(start, "glossaryTile").width < tiles.width)
        push("LessonsPage")
        tryVerify(() => window.pageStack.depth === 2)
        slidIn()
        const page = window.pageStack.currentItem
        verify(findChild(page, "lessonsEmpty").visible)
        verify(findChild(page, "lessonsEmpty").explanation !== "")
        compare(findChildren(page, "packageRow").length, 0)
        shot("16-lessons-empty")
        mouseClick(findChild(page, "lessonsCode"))
        tryVerify(() => window.pageStack.currentItem.title === "Videos")
        // Exam bundles under their own head.
        const videos = window.pageStack.currentItem
        tryVerify(() => findChildren(videos, "bundleKind").some(h => h.visible))
        compare(findChildren(videos, "bundleKind").filter(h => h.visible).map(h => h.text), ["Exam videos"])
        popPage()
    }

    // An installed package: its tile, its list, a technique's sheet with the description and the way
    // to the programme's entry, the player around it.
    function test_9p_lessons() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        const start = window.pageStack.items[0]
        const tile = findChild(start, "lessonsTile")
        tryVerify(() => tile.visible)
        // Last of 8 small tiles on the phone: after the notes, over both columns.
        const glossary = findChild(start, "notesTile")
        tryVerify(() => tile.mapToItem(start, 0, 0).y > glossary.mapToItem(start, 0, 0).y)
        tryCompare(tile, "width", findChild(start, "tiles").width)
        wait(200)       // the rows settle with the new tile
        compare(tile.hint, qsTr("%n package(s)", "", 1) + " · " + qsTr("%n technique(s)", "", 4))
        slidIn()
        clickTile(tile)
        tryVerify(() => window.pageStack.depth === 2)
        slidIn()
        const list = window.pageStack.currentItem
        const packageRow = () => findChildren(list, "packageRow")[0]
        tryVerify(() => packageRow() !== undefined)
        compare(packageRow().text, Library.packages[0].title)
        shot("16b-lessons-packages")
        mouseClick(packageRow())
        tryVerify(() => window.pageStack.depth === 3)
        slidIn()
        const page = window.pageStack.currentItem
        compare(page.title, Library.packages[0].title)
        tryVerify(() => findChildren(page, "lessonRow").length >= 4)
        verify(findChild(page, "packageText").visible)
        verify(findChild(page, "playAll").visible, "videos are on the device")
        shot("16c-lessons-package")

        // Its sheet: the description, and the same technique in the programme.
        const row = findChildren(page, "lessonRow").find(r => r.entry.id === "lern/" + lessonId + "/irimi")
        verify(row)
        mouseClick(row)
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, row.entry.id)
        compare(findChild(sheet, "sheetLessonText").text, row.entry.text)
        // The delegate of a Repeater is no QObject child of the sheet: by the items below it.
        const programmeLink = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetProgramme" && i.visible)
        tryVerify(() => !!programmeLink())
        const link = programmeLink()
        verify(link.visible)
        compare(link.text, "In the programme: " + Programme.techniqueLabel(same))
        shot("16d-lessons-sheet", true)
        mouseClick(link)
        tryVerify(() => sheet.entry.id === same)
        verify(!findChild(sheet, "sheetLessonText").visible, "an exam entry has no description")
        tryVerify(() => !programmeLink())

        // The way back: the exam entry names the lesson's technique, a tap shows it again.
        const lessonLink = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetLesson" && i.visible)
        tryVerify(() => !!lessonLink())
        compare(lessonLink().text, "In the learning videos: " + Library.packages[0].title + " · " + row.entry.title + " (" + row.entry.extra + ")")
        shot("16e-lessons-reverse", true)
        mouseClick(lessonLink())
        tryVerify(() => sheet.entry.id === row.entry.id)
        verify(sheet.playable, "its video is on the device")
        tryVerify(() => !lessonLink())
        sheet.close()
        tryVerify(() => !sheet.opened)

        // ▶ and "Play all": the package's list, previous and next work.
        const play = findChild(row, "rowPlay")
        verify(play.enabled)
        wait(400)       // the sheet fades out
        mouseClick(play)
        tryVerify(() => window.pageStack.depth === 4, 5000)
        const player = window.pageStack.currentItem
        compare(player.current.id, row.entry.id)
        compare(player.playlist.map(r => r.id), ["lern/" + lessonId + "/irimi", "lern/" + lessonId + "/tenkan"])
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        slidIn()
        // Entries without a video on the device have no play button.
        const without = findChildren(page, "lessonRow").find(r => r.entry.id === "lern/" + lessonId + "/ohne")
        verify(!findChild(without, "rowPlay").enabled)
        // The player from elsewhere (search, notes): the package's list for a lesson's id.
        const around = Library.around("lern/" + lessonId + "/tenkan")
        compare(around.index, 1)
        popPage()
        popPage()
    }

    // The lesson's player with its subtitles: on by default, the switch only for a video with tracks,
    // the text of the cue at the position (and none in a gap) on the picture, off hides it, and the
    // choice holds for the next video.
    function test_9p_lessons_subtitles() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        const lesson = "lern/" + lessonId + "/irimi"
        const visibleOf = (root, name) => findChildren(root, name).find(i => i.visible)
        const lessonPlayer = () => {
            const around = Library.around(lesson)
            return push("PlayerPage", { playlist: around.playlist, index: around.index })
        }

        // A video without tracks: no switch, no text.
        useFolder(standInVideos)
        const plain = push("PlayerPage", { playlist: Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video), index: 0 })
        tryVerify(() => plain.hasVideo)
        verify(!visibleOf(plain, "subtitleButton"), "no tracks, no switch")
        verify(!findChild(plain, "subtitleText").visible)
        popPage()

        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        verify(Videos.subtitlesOn, "on by default")
        const page = lessonPlayer()
        tryVerify(() => page.hasVideo)
        slidIn()
        const button = () => visibleOf(page, "subtitleButton")
        tryVerify(() => !!button())
        verify(button().checked, "on by default")
        compare(button().Accessible.name, qsTr("Subtitles"))
        compare(button().icon.name, "media-view-subtitles-symbolic")
        const track = findChild(page, "subtitleTrack")
        const text = findChild(page, "subtitleText")
        const stage = findChild(page, "stage")
        tryVerify(() => stage.width > 0 && stage.height > 0, 3000, "the picture has its size")

        // In a cue: its text on the picture, inside the stage, inside 90 % of the picture's width.
        track.position = 1500
        tryVerify(() => text.visible)
        compare(text.text, "Hello test")
        const at = text.mapToItem(stage, 0, 0)
        verify(at.x >= 0 && at.y >= 0 && at.x + text.width <= stage.width && at.y + text.height <= stage.height, "inside the stage: " + JSON.stringify([at.x, at.y, text.width, text.height, stage.width, stage.height]))
        verify(text.width <= stage.width * 0.9, "no wider than 90 %")
        verify(Math.abs(at.x + text.width / 2 - stage.width / 2) < 1, "in the middle")
        verify(at.y > stage.height / 2, "at the foot")
        verify(at.y + text.height <= stage.height - 2, "above the edge")
        shot("16h-subtitles-phone")
        // A gap, then a cue of two lines.
        track.position = 3700
        tryVerify(() => !text.visible)
        track.position = 4500
        tryVerify(() => text.visible)
        compare(text.text, "First line\nSecond line")
        shot("16h-subtitles-phone-two-lines")

        // Off: the text goes, the switch stays, the choice is the app's.
        mouseClick(button())
        tryVerify(() => !text.visible)
        verify(!button().checked)
        verify(!Videos.subtitlesOn)
        verify(button().visible, "still there to turn them on")
        shot("16h-subtitles-phone-off")
        mouseClick(button())
        tryVerify(() => text.visible)
        verify(button().checked)
        verify(Videos.subtitlesOn)

        // Sideways on a phone and on a tablet (the plate of Kino): the switch in view, the text above the timeline.
        window.width = 800
        window.height = 360
        tryVerify(() => page.headless && !!button())
        wait(300)
        verify(button().mapToItem(page, 0, button().height).y <= page.height, "the rail ends in view")
        verify(overflowing(page, 800).length === 0, "past the edge: " + overflowing(page, 800))
        const timeline = findChild(page, "railTimeline")
        verify(text.mapToItem(page, 0, text.height).y <= timeline.mapToItem(page, 0, 0).y, "above the timeline")
        shot("16h-subtitles-phone-landscape")
        const phoneSize = text.font.pixelSize
        window.width = 1280
        window.height = 1000     // room above and below the 16:9 picture
        tryVerify(() => findChild(page, "plate").visible && button().visible, 2000, "the plate")
        wait(300)
        verify(button().mapToItem(page, button().width, 0).x <= page.width, "the row ends in view")
        verify(overflowing(page, 1280).length === 0, "past the edge: " + overflowing(page, 1280))
        shot("16h-subtitles-tablet")

        // The text grows with the picture, and with the size chosen in the settings.
        const tabletSize = text.font.pixelSize
        verify(tabletSize > phoneSize * 1.5, "tablet " + tabletSize + " px, phone " + phoneSize + " px")
        Videos.subtitleSize = Videos.SubtitleSize.Large
        tryVerify(() => Math.abs(text.font.pixelSize - tabletSize * 1.25) <= 1, 2000,
                  "a quarter larger (whole pixels): " + text.font.pixelSize)
        shot("16h-subtitles-tablet-large")
        Videos.subtitleSize = Videos.SubtitleSize.Normal
        window.width = 420
        window.height = 800
        popPage()

        // The choice holds for the next video: off stays off.
        Videos.hideSubtitles()
        const again = lessonPlayer()
        tryVerify(() => again.hasVideo)
        slidIn()
        tryVerify(() => !!visibleOf(again, "subtitleButton"))
        verify(!visibleOf(again, "subtitleButton").checked, "off holds")
        findChild(again, "subtitleTrack").position = 1500
        wait(100)
        verify(!findChild(again, "subtitleText").visible, "off holds")
        popPage()

        // Several tracks: a menu, Off and each language by its own name; the app's language by default.
        Videos.showSubtitles()
        verify(uiCatalog.installLessonTracks(lessonId, same))
        const video = Library.around(lesson).playlist[0].video.video
        compare(Videos.subtitleLanguage(video), uiCatalog.appLanguage(), "the app's language")
        const several = lessonPlayer()
        tryVerify(() => !!visibleOf(several, "subtitleButton"))
        slidIn()
        const opener = visibleOf(several, "subtitleButton")
        const menu = findChild(opener, "subtitleMenu")
        wait(1000)      // the page's layout settles (the switch moves while the picture takes its height)
        mouseClick(opener)
        tryVerify(() => menu.opened)
        const names = findChildren(menu.contentItem, "subtitleLanguage").map(i => i.text)
        compare(names, ["Deutsch", "English"], "each language by its plain name (not \"American English\")")
        compare(findChild(menu.contentItem, "subtitleOff").text, qsTr("Off"))
        shot("16h-subtitles-menu", true)
        // The chosen entry tapped again keeps its tick (a checkable entry toggled itself off after
        // triggered and lost it): German chosen first, on any system's language.
        Videos.chooseSubtitles("de")
        const german = () => findChildren(menu.contentItem, "subtitleLanguage")[0]
        compare(german().tick, LookMenuItem.Tick.On)
        mouseClick(german())
        tryVerify(() => !menu.opened)
        compare(Videos.subtitleLanguage(video), "de")
        compare(german().tick, LookMenuItem.Tick.On, "Deutsch still ticked")
        compare(findChildren(menu.contentItem, "subtitleLanguage")[1].tick, LookMenuItem.Tick.Off)
        compare(findChild(menu.contentItem, "subtitleOff").tick, LookMenuItem.Tick.Off)
        const severalTrack = findChild(several, "subtitleTrack")
        severalTrack.position = 1500
        tryVerify(() => findChild(several, "subtitleText").visible)
        compare(findChild(several, "subtitleText").text, "Hallo test")
        popPage()

        // A chosen language the next video lacks: the default rule.
        verify(uiCatalog.installLesson(lessonId, same))
        compare(Videos.subtitleLanguage(video), "en")
        verify(Videos.subtitlesOn)
        verify(uiCatalog.removeLesson(lessonId))
    }

    // A lesson's sheet from the search: the chip to the programme works on any page that hosts the sheet.
    function test_9p_lessons_search() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        const page = push("SearchPage")
        findChild(page, "searchField").text = "irimi-nage variant"
        const lessonRow = () => findChildren(page, "techniqueResult").find(r => r.found.id === "lern/" + lessonId + "/irimi")
        tryVerify(() => !!lessonRow(), 2000)
        slidIn()
        mouseClick(lessonRow())
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, "lern/" + lessonId + "/irimi")
        const link = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetProgramme" && i.visible)
        tryVerify(() => !!link())
        mouseClick(link())
        tryVerify(() => sheet.entry.id === same)
        tryVerify(() => !link())
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()
    }

    // An exam entry's sheet shows the learning-video techniques that name it, only while the package is
    // installed; the chip follows install and remove.
    function test_9p_lessons_reverse() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        const page = push("SearchPage")
        findChild(page, "searchField").text = Programme.entry(same).title
        const result = () => findChildren(page, "techniqueResult").find(r => r.found.id === same)
        tryVerify(() => !!result(), 2000)
        slidIn()
        mouseClick(result())
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, same)
        const link = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetLesson" && i.visible)
        verify(!link(), "no package, no chip")

        verify(uiCatalog.installLesson(lessonId, same))
        tryVerify(() => !!link())
        // The sheet grew under the chip: the tap itself is the main case's; here the signal.
        link().clicked()
        tryVerify(() => sheet.entry.id === "lern/" + lessonId + "/irimi")
        verify(sheet.playable)
        sheet.close()
        tryVerify(() => !sheet.opened)

        sheet.entry = Programme.entry(same)
        sheet.open()
        tryVerify(() => sheet.opened)
        tryVerify(() => !!link())
        verify(uiCatalog.removeLesson(lessonId))
        tryVerify(() => !link())
        sheet.close()
        popPage()
    }

    // The Lernpaket's notes have their filter on "All notes".
    function test_9p_lessons_notes() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        const page = push("AllNotesPage")
        page.filter = ""
        wait(100)
        verify(!findChild(page, "filter_lern"), "no notes on a lesson, no filter")
        verify(Practice.addNote("lern/" + lessonId + "/irimi", "Eintritt"))
        tryVerify(() => findChild(page, "filter_lern") !== null)
        slidIn()
        wait(300)
        mouseClick(findChild(page, "filter_lern"))
        wait(300)
        tryVerify(() => page.filter === "lern")
        tryCompare(page.shown, "length", 1)
        compare(page.shown[0].discipline, "lern")
        shot("16e-lessons-notes")
        // The package goes, its note stays and so does its filter.
        verify(uiCatalog.removeLesson(lessonId))
        wait(100)
        verify(findChild(page, "filter_lern"))
        mouseClick(findChild(page, "filter_all"))
        tryVerify(() => page.filter === "")
        popPage()
    }

    // On a tablet sideways the packages and the open one stand side by side.
    function test_9p_lessons_tablet() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        window.width = 1280
        window.height = 800
        const start = window.pageStack.items[0]
        wait(200)
        slidIn()
        clickTile(findChild(start, "lessonsTile"))
        tryVerify(() => window.pageStack.depth === 2)
        slidIn()
        const host = window.pageStack.currentItem
        const pane = findChild(host, "pagePane")
        tryVerify(() => host.wide && pane.item && pane.item.uid === lessonId, 3000)
        verify(findChild(host, "packageRow").selected)
        tryVerify(() => findChildren(pane.item, "lessonRow").length >= 4)
        compare(overflowing(host, 1280), [])
        shot("16f-lessons-tablet")
        mouseClick(findChild(pane.item, "lessonRow"))
        const sheet = findChild(pane.item, "techniqueSheet")
        tryVerify(() => sheet.opened)
        shot("16g-lessons-tablet-sheet", true)
        sheet.close()
        tryVerify(() => !sheet.opened)
        // The tile, four to a row: after the notes, in a row of its own.
        popPage()
        const tiles = findChild(start, "tiles")
        compare(tiles.smallTiles, 8)
        compare(findChild(start, "lessonsTile").width, findChild(start, "glossaryTile").width)
    }

    // The chip in the dialog swaps it to the lesson technique; playing it plays that one, in a
    // player page of its own (the grade's list does not hold it).
    function test_9p_lessons_chip_play() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        useFolder(standInVideos)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        slidIn()
        page.open(Programme.entry(same))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const link = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetLesson" && i.visible)
        tryVerify(() => !!link())
        link().clicked()
        const lesson = "lern/" + lessonId + "/irimi"
        tryVerify(() => sheet.entry.id === lesson)
        sheet.playRequested(sheet.entry)
        tryVerify(() => window.pageStack.currentItem !== page)
        const player = window.pageStack.currentItem
        verify(player.playlist.length > 0)
        compare(player.playlist[player.index].id, lesson)
        popPage()
        popPage()
        verify(uiCatalog.removeLesson(lessonId))
    }

    // The dialog led on to a technique of another grade (lesson chip, then its programme chip): it
    // plays in its own list, not in this grade's (where it is not: index -1, an empty player).
    function test_9p_other_grade_play() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        useFolder(standInVideos)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        slidIn()
        page.open(Programme.entries("aikido", "k5").find(r => r.kind === "entry"))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const other = Programme.entries("aikido", "k4").find(r => r.kind === "entry" && r.video && Videos.available(r.video.video))
        verify(!!other)
        sheet.entry = other
        sheet.playRequested(other)
        tryVerify(() => window.pageStack.currentItem !== page)
        const player = window.pageStack.currentItem
        verify(player.index >= 0, "the technique is in the player's list")
        compare(player.playlist[player.index].id, other.id)
        popPage()
        popPage()
    }

    // Turned sideways with a lesson technique in the dialog: it stays there, the pane's state is not its.
    function test_9p_lessons_chip_turn() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        useFolder(standInVideos)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        window.width = 420
        window.height = 900
        const page = push("ProgrammePage")
        slidIn()
        const sheet = findChild(page, "techniqueSheet")
        page.showDialog(Programme.entry(same))
        tryVerify(() => sheet.opened)
        const link = () => allChildren(sheet.contentItem).find(i => i.objectName === "sheetLesson" && i.visible)
        tryVerify(() => !!link())
        link().clicked()
        const lesson = "lern/" + lessonId + "/irimi"
        tryVerify(() => sheet.entry.id === lesson)
        window.width = 1280
        window.height = 800
        tryVerify(() => page.wide)
        wait(300)
        verify(sheet.opened, "the dialog stays")
        compare(sheet.entry.id, lesson)
        compare(page.sheetId, "")
        verify(page.lastId !== lesson)
        sheet.close()
        popPage()
        verify(uiCatalog.removeLesson(lessonId))
    }

    // The chip in the right pane (tablet) opens the lesson technique in the dialog; the pane keeps its own.
    function test_9p_lessons_chip_pane() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        const page = tabletProgramme()
        page.sheetId = same
        const body = () => findChild(page, "paneSheet")
        tryVerify(() => !!body())
        const link = () => allChildren(body()).find(i => i.objectName === "sheetLesson" && i.visible)
        tryVerify(() => !!link())
        link().clicked()
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, "lern/" + lessonId + "/irimi")
        compare(page.sheetId, same)
        compare(body().entry.id, same)

        // Turned upright: the open dialog keeps the lesson, the pane's technique does not take its place.
        window.width = 420
        window.height = 800
        tryVerify(() => !page.wide)
        wait(100)
        verify(sheet.opened)
        compare(sheet.entry.id, "lern/" + lessonId + "/irimi", "the lesson stays in the dialog")
        sheet.close()
        popPage()
        verify(uiCatalog.removeLesson(lessonId))
    }

    // Scanning (fake frames, no camera): refused without a camera or permission, typing stays;
    // Cancel changes nothing; a QR code without a code gets a sentence and the page stays; a
    // code goes the way of a typed one: its errors, its unlocking.
    function test_9n_videos_scan() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const page = push("VideosPage")
        tryCompare(Bundles, "manifestState", Bundles.ManifestState.Ready, 5000)
        slidIn()
        const field = findChild(page, "codeField")
        const message = findChild(page, "codeMessage")
        const scan = findChild(page, "scanButton")
        const scanPage = () => window.pageStack.currentItem
        const onScanPage = () => scanPage().title === qsTr("Scan code")
        const openScan = () => {
            mouseClick(scan)
            tryVerify(onScanPage)
            wait(800)
            return scanPage()
        }
        // A camera at work: the same picture until something happens.
        const showUntil = (text, happened) => {
            const sink = findChild(scanPage(), "scanOutput").videoSink
            tryVerify(() => {
                if (happened()) {
                    return true
                }
                uiCatalog.showFrame(sink, text)
                return false
            }, 5000)
        }

        uiCatalog.setCamera("none")
        mouseClick(scan)
        compare(message.text, qsTr("This device has no camera. Type the code instead."))
        verify(window.pageStack.currentItem === page)
        uiCatalog.setCamera("denied")
        mouseClick(scan)
        compare(message.text, qsTr("Mitori may not use the camera. Type the code instead, or allow it in the system settings."))
        verify(window.pageStack.currentItem === page)
        verify(findChild(page, "codeField").enabled, "typing still works")
        uiCatalog.setCamera("frames")

        // Cancel means cancel: a code still in the picture while the page slides out redeems
        // nothing and takes no second page off the stack. The same for the way back.
        const depth = window.pageStack.depth
        const leaveThenShowCode = leave => {
            const leaving = openScan()
            const sink = findChild(leaving, "scanOutput").videoSink
            leave(leaving)
            for (let i = 0; i < 12 && leaving.title; ++i) {      // until the page is gone with its sink
                uiCatalog.showFrame(sink, "7KQ2M-X9HDV-3TAPR-WE6YT")
                wait(60)
            }
            tryVerify(() => window.pageStack.currentItem === page)
            wait(600)
            compare(field.text, "", "nothing redeemed")
            compare(message.text, "")
            verify(!Bundles.unlocking)
            compare(window.pageStack.currentItem, page, "the videos page stays")
            compare(window.pageStack.depth, depth)
        }
        leaveThenShowCode(leaving => mouseClick(findChild(leaving, "scanCancel")))
        leaveThenShowCode(() => popPage())
        leaveThenShowCode(leaving => {
            const cancel = findChild(leaving, "scanCancel")
            mouseClick(cancel)
            mouseClick(cancel)
        })

        // Two answers to one wish (a double tap, the permission dialog): one page.
        CodeScanner.open()
        CodeScanner.open()
        tryVerify(onScanPage)
        compare(window.pageStack.depth, depth + 1)
        wait(800)
        mouseClick(findChild(scanPage(), "scanCancel"))
        tryVerify(() => window.pageStack.currentItem === page)
        wait(800)

        let scanning

        // An empty picture says nothing; a foreign QR code a sentence, the camera reads on.
        scanning = openScan()
        const hint = findChild(scanning, "scanHint")
        const asked = hint.text
        uiCatalog.showFrame(findChild(scanning, "scanOutput").videoSink, "")
        wait(300)
        compare(hint.text, asked)
        showUntil("https://example.org/keine-dvd", () => hint.text !== asked)
        compare(hint.text, qsTr("This QR code holds no DVD code. Use the one on the insert of the DVD."))
        verify(onScanPage())
        shot("15c-videos-scan")

        // A camera that fails: a sentence of ours beside the foreign one, the way out stays.
        const failed = findChild(scanning, "scanError")
        verify(!failed.visible)
        scanning.cameraFailed = true
        tryVerify(() => failed.visible)
        compare(failed.text, qsTr("The camera does not work; another program may be using it. Cancel and type the code instead."))
        verify(hint.visible && hint.text === qsTr("This QR code holds no DVD code. Use the one on the insert of the DVD."))
        scanning.cameraFailed = false

        // Nothing foreign in the picture any more: the sentence goes.
        tryCompare(hint, "text", asked, mediaLoads)

        // A well-formed code nobody knows: back, the same answer as to a typed one, in the field.
        const prefix = "0000000000000000000"
        const unknown = Array.from("0123456789ABCDEFGHJKMNPQRSTVWXYZ").map(c => prefix + c).find(c => Bundles.codeValid(c))
        showUntil(unknown, () => !onScanPage())
        tryVerify(() => window.pageStack.currentItem === page)
        tryCompare(message, "text", qsTr("This code is not known (or no longer valid)."))
        compare(field.text, Bundles.grouped(unknown))
        verify(!page.codeOk)
        wait(800)

        // The code: unlocked and loaded as if typed.
        scanning = openScan()
        showUntil("7KQ2M-X9HDV-3TAPR-WE6YT", () => !onScanPage())
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Installed, mediaLoads)
        verify(message.text.indexOf("Test") > 0, message.text)
        compare(field.text, "")
        verify(Bundles.remove("test-bundle"))
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Unlocked)
        popPage()
    }

    // The scan with a turn while the camera stands above: the code is redeemed by the page beside
    // the list, the scan page goes.
    function test_9n_videos_scan_turned() {
        failOnWarning(/ReferenceError|TypeError/)
        uiCatalog.setCamera("frames")
        const host = listHost("SettingsPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.title === "Videos")
        const videos = pane.item
        const depth = window.pageStack.depth
        tryCompare(Bundles, "manifestState", Bundles.ManifestState.Ready, 5000)
        CodeScanner.open()
        tryCompare(window.pageStack, "depth", depth + 1)
        wait(800)
        const scanning = window.pageStack.currentItem

        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        const sink = findChild(scanning, "scanOutput").videoSink
        tryVerify(() => {
            if (window.pageStack.depth === depth) {
                return true
            }
            uiCatalog.showFrame(sink, "7KQ2M-X9HDV-3TAPR-WE6YT")
            return false
        }, 5000, "the scan page goes")
        compare(pane.item, videos, "the page that asked")
        tryVerify(() => window.pageStack.currentItem === host)
        verify(host.showsPage, "back on the page that asked, not the list")
        verify(videos.visible)
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Installed, mediaLoads, "redeemed")
        verify(Bundles.remove("test-bundle"))
        tryVerify(() => Bundles.bundles[0].state === Bundles.State.Unlocked)
        turn(1280, 800)
        tryVerify(() => host.wide)
        popPage()
    }

    // The licences of what ships with the app (Apache-2.0 and the BSD ones ask for it).
    function test_9n_videos_licences() {
        const page = push("AppearancePage")
        const text = findChild(page, "licences").text
        for (const needed of ["ZXing-C++", "Apache License", "Axel Waggershauser", "libzueci", "Copyright (C) 2022 gitlost",
                              "Redistribution and use in source and binary forms", "Bjoern Hoehrmann", "Monocypher", "Loup Vaillant", "Frank Osterfeld"]) {
            verify(text.indexOf(needed) >= 0, needed)
        }
        popPage()
    }

    // A bundle loaded while the player is open: file and cut points change together, never the
    // new times over the old file. (After test_9n_videos: unlocked, nothing loaded.)
    function test_9n_videos_player() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const entry = {id: "test/tech", title: "T", video: {video: "test/v", von: 10, bis: 20}}
        const player = push("PlayerPage", {playlist: [entry], index: 0})
        compare(player.from, 10000, "the app's own time")
        compare(player.source.toString(), "")
        verify(!player.hasVideo)
        Bundles.load("test-bundle", Bundles.Network.Any)
        tryCompare(player, "from", 1500, mediaLoads)
        compare(player.to, 2500)
        verify(player.source.toString().indexOf("test") > 0, player.source)
        verify(player.hasVideo, "no sound behind the card: the picture and its controls come too")
        verify(Bundles.remove("test-bundle"))
        tryCompare(player, "from", 10000)
        compare(player.source.toString(), "")
        verify(!player.hasVideo)
        popPage()
    }

    // Saving the shelf for another bundle leaves a playing video alone; a new file of this video
    // (an update, here another folder) loads at the chapter's start and waits, no sudden sound.
    function test_9n_videos_player_keeps_playing() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const before = Videos.folder
        const folder = name => uiDataDir + "/played-" + name
        Videos.folder = folder("a")
        const entry = {id: "x", title: "T", video: {video: "aikido/k5", von: 0.1, bis: 60}}
        const next = {id: "y", title: "U", video: {video: "aikido/k5", von: 0.2, bis: 60}}
        const player = push("PlayerPage", {playlist: [entry, next], index: 0})
        tryVerify(() => player.playing, mediaLoads)
        tryVerify(() => player.position > 300 && player.position < 700, mediaLoads)
        const at = player.position

        Videos.folderChanged()
        wait(150)
        verify(player.playing, "still playing")
        verify(player.position >= at, player.position + " after " + at)

        Videos.folder = folder("b")
        tryVerify(() => player.source.toString().indexOf("played-b") > 0)
        tryVerify(() => player.position === player.from && !player.playing, mediaLoads)
        wait(300)
        verify(!player.playing, "it waits for a tap")

        // The next technique plays as usual again.
        player.go(1)
        tryVerify(() => player.playing, 5000)
        popPage()
        Videos.folder = before
    }

    // My grades and a planned exam: a passed grade sets the next one and its waiting time; an
    // exam planned on a coming course shows in the start menu, today's practice and the exam mode.
    function test_9o_grades() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        // grades.js names the states by number.
        compare([Courses.Wait.First, Courses.Wait.FromStart, Courses.Wait.Unknown, Courses.Wait.Earliest,
                 Courses.Wait.Fits, Courses.Wait.TooEarly], [0, 1, 2, 3, 4, 5])
        const page = push("GradesPage")
        tryVerify(() => findChildren(page, "addGrade").length === 3)
        const aikido = findChild(page, "grades_aikido")
        verify(findChild(aikido, "nextGrade").text.indexOf(qsTr("Next: %1").arg("5. Kyu")) === 0)
        findChild(aikido, "gradeDay").date = new Date(Date.now() - 400 * 86400000)
        findChild(aikido, "gradePlace").text = "Mainz"
        const add = findChild(aikido, "addGrade")
        slidIn()
        // The page's columns settle a moment after the slide: a click before that misses the button.
        tryVerify(() => add.mapToItem(page, 0, 0).x + add.width <= page.width, 3000, "the button inside the page")
        const at = add.mapToItem(page, 0, 0)
        mouseClick(add)
        tryVerify(() => Courses.grades.length === 1, 3000,
                  "add at " + at.x + "," + at.y + " enabled " + add.enabled + " page " + page.width + "×" + page.height)
        tryVerify(() => findChildren(aikido, "passedRow").length === 1)
        compare(findChild(aikido, "gradePlace").text, "")
        const next = findChild(aikido, "nextGrade").text
        verify(next.indexOf(qsTr("Next: %1").arg("4. Kyu")) === 0, next)
        compare(findChild(aikido, "gradeBox").currentIndex, 1, "the next grade is offered")
        // Shinki Toho Shoden counts from the start of training: entered, its waiting time has a day.
        const toho = findChild(page, "grades_shinkitoho")
        verify(findChild(toho, "trainingStart").visible)
        verify(!findChild(aikido, "trainingStart").visible)
        verify(Courses.setTrainingStart("shinkitoho", "2024-09-01"))
        tryVerify(() => findChild(toho, "trainingStart").date !== null)
        const shoden = findChild(toho, "nextGrade").text
        verify(shoden.indexOf("enter it") < 0 && /26/.test(shoden), shoden)     // from 01.09.26 (C: 1 09 2026)
        // Picked by the user, the field still follows the saved day (a sync may bring another).
        const startField = findChild(toho, "trainingStart")
        startField.pick(new Date(2024, 9, 1, 12))
        compare(Courses.trainingStart("shinkitoho"), "2024-10-01")
        verify(Courses.setTrainingStart("shinkitoho", "2024-09-01"))
        tryVerify(() => startField.date && startField.date.getMonth() === 8, 2000, "the field follows the saved day")
        shot("16-grades")
        popPage()

        // An exam on the coming Daitoryu course (in 12 days): 4. Kyu fits (a year after 5. Kyu).
        const uid = Courses.notebookFor("ui-daito")
        const book = push("CoursePage", { uid: uid })
        verify(findChild(book, "planExam").visible)
        wait(800)
        mouseClick(findChild(book, "planExam"))
        book.examDiscipline = "aikido"
        book.examGrade = Courses.nextGrade("aikido")
        tryVerify(() => findChild(book, "examGrade_k4") && findChild(book, "examGrade_k4").checked)
        verify(findChild(book, "examGrade_k4").text.indexOf(qsTr("next")) > 0)
        verify(findChild(book, "examGrade_k5").text.indexOf(qsTr("passed")) > 0)
        verify(findChild(book, "choiceWait").text.indexOf(qsTr("fits (from %1)").split("%1")[0]) > 0, findChild(book, "choiceWait").text)
        shot("16b-course-exam-choose")
        mouseClick(findChild(book, "examPlan"))
        tryVerify(() => findChild(book, "examChip").visible)
        compare(findChild(book, "examChip").text, qsTr("Exam %1").arg("Aikido 4. Kyu"))
        shot("16c-course-exam")
        popPage()

        const start = window.pageStack.items[0]
        // CD-5 shot: the start menu with the planned exam's countdown on the exam tile.
        tryVerify(() => findChild(start, "examCountdown").visible)
        shot("1b-start-planned-exam")
        compare(findChild(start, "examDays").text, qsTr("in %n day(s)", "", 12))
        compare(findChild(start, "examTile").t.name, "Aikido 4. Kyu")
        verify(findChild(start, "examRing").visible)
        verify(!findChild(start, "plannedExam"), "the countdown is the exam tile's, no hint box above the tiles")
        Programme.discipline = "aikido"
        const today = push("TodayPage")
        verify(findChild(today, "plannedHint").visible)
        popPage()
        PracticeGrade.setGrade("aikido", "k5")
        const exam = push("ExamPage")
        verify(findChild(exam, "plannedHint").visible)
        verify(findChild(exam, "toExamGrade").visible)
        slidIn()
        clickUntil(findChild(exam, "toExamGrade"), () => exam.grade === "k4")
        verify(!findChild(exam, "toExamGrade").visible)
        popPage()

        // "Mock exam" on Today opens the exam at the planned grade and makes it the practice grade.
        PracticeGrade.setGrade("aikido", "k5")
        const today1 = push("TodayPage")
        clickUntil(findChild(today1, "toMockExam"), () => window.pageStack.currentItem !== today1)
        tryCompare(window.pageStack.currentItem, "title", qsTranslate("ExamPage", "Exam mode"))
        compare(window.pageStack.currentItem.grade, "k4")
        compare(PracticeGrade.grade("aikido"), "k4")
        popPage()
        popPage()

        // A planned grade without material in the exam mode (Shinki Toho Menkyo-Kaiden): no
        // button that would open another grade.
        verify(Courses.planExam(uid, "shinkitoho", "kaiden"))
        Programme.discipline = "shinkitoho"
        const today2 = push("TodayPage")
        verify(findChild(today2, "plannedHint").visible)
        verify(!findChild(today2, "toMockExam").visible, "Menkyo-Kaiden has no mock exam")
        popPage()
        const exam2 = push("ExamPage")
        verify(findChild(exam2, "plannedHint").visible)
        verify(!findChild(exam2, "toExamGrade").visible, "Menkyo-Kaiden has no mock exam")
        popPage()
        Programme.discipline = "aikido"

        // Back as before for the other cases.
        verify(Courses.planExam(uid, "", ""))
        verify(Courses.removeGrade(Courses.grades[0].uid))

        // Every grade passed: nothing is chosen, so "Add" cannot overwrite the first grade's day;
        // the heading names the highest grade, also when a lower one has the later day.
        const ladder = Courses.ladder("daitoryu")
        ladder.forEach((g, i) => verify(Courses.addGrade("daitoryu", g.id, (2010 + i) + "-01-01", "")))
        verify(Courses.addGrade("daitoryu", "k5", "2030-01-01", ""))
        const all = push("GradesPage")
        const daito = findChild(all, "grades_daitoryu")
        tryVerify(() => findChild(daito, "addGrade"))
        compare(findChild(daito, "gradeBox").currentIndex, -1)
        verify(!findChild(daito, "addGrade").enabled)
        verify(findChild(daito, "gradesHeading").text.indexOf(ladder[ladder.length - 1].name) > 0, findChild(daito, "gradesHeading").text)
        popPage()
        const uids = Courses.grades.filter(g => g.discipline === "daitoryu").map(g => g.uid)
        compare(uids.length, ladder.length)
        for (const u of uids) {
            verify(Courses.removeGrade(u), "remove " + u + ": " + Courses.errorString)
        }
    }

    // Technique map: from the start menu, a grid per group with empty places, a place coloured by
    // its level and opening its sheet, the keys moving on; Shinki Toho as numbered forms.
    function test_9k_map() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k4")
        tryCompare(window.pageStack, "depth", 1)
        slidIn()
        const tile = findChild(window.pageStack.items[0], "mapTile")
        verify(tile && tile.visible)
        clickTile(tile)
        tryCompare(window.pageStack, "depth", 2)
        const page = window.pageStack.currentItem
        tryVerify(() => page.title === qsTr("Technique map"))
        slidIn()
        compare(page.grade, "k4")
        verify(page.matrix)
        // The grade is one control: another grade changes the grids.
        const gradeBox = findChild(page, "gradeBox")
        compare(gradeBox.count, Programme.grades("aikido").length)
        const gridsBefore = page.grids
        gradeBox.activated(0)
        tryCompare(page, "grade", page.grades[0].id)
        verify(JSON.stringify(page.grids) !== JSON.stringify(gridsBefore), "another grade, other grids")
        page.grade = "k4"
        tryCompare(gradeBox, "currentIndex", page.grades.findIndex(g => g.id === "k4"))

        // Techniques × attacks (KanteHeatGrid); combinations not in the programme are gaps.
        const heat = findChild(page, "techniqueMatrix")
        compare(heat.rowCount, page.shown.rows.length)
        compare(heat.columnCount, page.shown.columns.length)
        // Technique names in the text font, not the small mono labels.
        compare(heat.rowLabelFont.family, Look.smallFont.family)
        compare(heat.rowLabelFont.pointSize, Look.smallFont.pointSize)
        let gap = null, target = null
        for (let r = 0; r < heat.rowCount; r++) {
            for (let c = 0; c < heat.columnCount; c++) {
                if (heat.isEmpty(r, c))
                    gap = gap || { r: r, c: c }
                else if (!target && heat.valueOf(r, c) === 0)
                    target = { r: r, c: c }
            }
        }
        verify(gap, "combinations not in the programme stay empty")
        verify(!heat.cellAt(gap.r, gap.c).shown)
        verify(target)

        // A rating colours the place; its tip names technique, attack, grade and level.
        const data = page.shown.rows[target.r].cells[target.c]
        verify(Practice.rate(data.ids[0], 4))
        const cell = heat.cellAt(target.r, target.c)
        tryCompare(cell, "level", 4)
        compare(heat.entryOf(target.r, target.c).label, "4")
        const tip = heat.tipOf(target.r, target.c)
        verify(tip.indexOf(data.gradeName) > 0, tip)
        verify(tip.indexOf(Practice.levelNames[4]) > 0, tip)
        shot("11-map-aikido")

        // A tap opens the technique sheet.
        const sheet = findChild(page, "techniqueSheet")
        mouseClick(cell)
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, data.entry.id)
        sheet.close()
        tryVerify(() => !sheet.visible)

        // The keys: Right moves to the next place of the row (over gaps), Enter opens it.
        cell.forceActiveFocus(Qt.TabFocusReason)
        let next = target.c + 1
        while (next < heat.columnCount && heat.isEmpty(target.r, next))
            next++
        keyClick(Qt.Key_Right)
        if (next < heat.columnCount)
            compare(heat.currentColumn, next)
        keyClick(Qt.Key_Return)
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, page.shown.rows[heat.currentRow].cells[heat.currentColumn].entry.id)
        sheet.close()
        tryVerify(() => !sheet.visible)       // a closing sheet still takes the taps

        // Groups apart: another chip, another grid.
        const chips = findChildren(page, "groupChip")
        verify(chips.length > 1)
        page.flickable.contentY = 0
        mouseClick(chips[1])
        compare(page.shown.title, chips[1].text)

        // Shinki Toho: the Ô-dachi forms up to Chûden, eight to a row on the phone.
        page.discipline = "shinkitoho"
        page.grade = "chuden"
        verify(!page.matrix)
        const forms = findChild(page, "formGrid")
        verify(forms.visible)
        compare(forms.perRow, 8)
        compare(forms.rowCount, 3)
        // The forms fill the width: the last of a row ends at the right edge.
        const fills = () => {
            const last = forms.cellAt(0, forms.perRow - 1)
            const right = last.mapToItem(forms, last.width, 0).x
            return right <= forms.width + 0.5 && right > forms.width - forms.cellSide / 2
        }
        tryVerify(fills, 2000, "the forms fill the width")
        compare(forms.entryOf(1, 3).label, "12")
        verify(forms.isEmpty(2, 7), "after the last form")
        verify(Practice.rate("shinkitoho/odachi/12", 2))
        const form = forms.cellAt(1, 3)
        tryCompare(form, "level", 2)
        // The level also as a number, not only as the colour.
        compare(forms.entryOf(1, 3).label, "12·2")
        waitForRendering(forms)       // the page lays out the forms in the next frame
        mouseClick(form)
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, "shinkitoho/odachi/12")
        sheet.close()
        tryVerify(() => !sheet.visible)
        shot("11-map-shinkitoho")

        // Tablet in landscape: bigger places, more forms per row.
        window.width = 1280
        window.height = 800
        tryCompare(forms, "perRow", 11)
        compare(forms.entryOf(1, 0).label, "12·2")
        tryVerify(fills, 2000, "the forms fill the tablet's width")
        page.discipline = "daitoryu"
        page.grade = Programme.grades("daitoryu").slice(-1)[0].id
        verify(page.matrix)
        compare(heat.cellSize, KanteStyle.unit(34))
        // A place with entries of several grades names them all.
        let multi = null
        for (let r = 0; !multi && r < heat.rowCount; r++) {
            for (let c = 0; !multi && c < heat.columnCount; c++) {
                const d = page.shown.rows[r].cells[c]
                if (d.gradeNames && d.gradeNames.length > 1)
                    multi = { r: r, c: c, names: d.gradeNames }
            }
        }
        verify(multi, "a place with entries of two grades in Daitoryu")
        for (const name of multi.names)
            verify(heat.tipOf(multi.r, multi.c).indexOf(name) > 0, heat.tipOf(multi.r, multi.c))
        shot("11-map-tablet")
        popPage()
    }

    // The map on a tablet sideways: the matrix centred in its area, a tap shows the technique in the
    // panel beside it (no sheet), a ring marks the place; Shinki Toho's forms the same.
    function test_9k_map_wide() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k4")
        window.width = 1280
        window.height = 800
        const page = push("TechniqueMapPage")
        slidIn()
        tryVerify(() => page.wide, 2000, "a wide window")
        const panel = findChild(page, "mapPanel")
        verify(panel.visible)
        verify(findChild(page, "mapPanelHint").visible, "a hint before the first tap")
        const heat = findChild(page, "techniqueMatrix")
        const area = heat.parent
        tryVerify(() => heat.width > 0 && area.width > heat.width, 2000, "narrower than its area")
        const left = heat.mapToItem(area, 0, 0).x
        const right = area.width - left - heat.width
        verify(Math.abs(left - right) <= 1, "centred: " + left + " / " + right)
        verify(panel.mapToItem(page, 0, 0).x > heat.mapToItem(page, heat.width, 0).x, "the panel stands right of the map")

        let target = null
        for (let r = 0; r < heat.rowCount && !target; r++) {
            for (let c = 0; c < heat.columnCount; c++) {
                if (!heat.isEmpty(r, c)) {
                    target = { r: r, c: c }
                    break
                }
            }
        }
        verify(target)
        const data = page.shown.rows[target.r].cells[target.c]
        const cell = heat.cellAt(target.r, target.c)
        const sheet = findChild(page, "techniqueSheet")
        mouseClick(cell)
        tryVerify(() => page.paneEntry !== null)
        compare(page.paneEntry.id, data.entry.id)
        verify(!findChild(page, "mapPanelHint").visible)
        compare(findChild(panel, "paneSheet").entry.id, data.entry.id)
        verify(!sheet.visible, "no sheet on a wide window")
        verify(findChild(page, "mapHint").text.indexOf("open") < 0, "the hint does not say open: " + findChild(page, "mapHint").text)
        // Another technique from the panel (same one in a video) opens the sheet; panel and ring stay.
        const paneBody = findChild(panel, "paneSheet")
        const shownId = page.paneEntry.id
        paneBody.lessonRequested({ id: "other/x", title: "Other", discipline: "aikido" })
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, "other/x")
        compare(page.paneEntry.id, shownId, "the panel keeps its technique")
        verify(findChild(cell, "placeRing") !== null, "the ring stays")
        sheet.close()
        tryVerify(() => !sheet.visible)
        tryVerify(() => findChild(cell, "placeRing") !== null, 2000, "the tapped place is marked")
        shot("11-map-wide")

        // Shinki Toho's forms: the same panel.
        page.discipline = "shinkitoho"
        page.grade = "chuden"
        const forms = findChild(page, "formGrid")
        tryVerify(() => forms.visible && forms.rowCount > 0)
        verify(page.paneEntry === null, "another grid, no mark")
        waitForRendering(forms)
        const form = forms.cellAt(0, 1)
        mouseClick(form)
        tryVerify(() => page.paneEntry !== null)
        compare(page.paneEntry.id, page.shown.cells[1].entry.id)
        verify(!sheet.visible)
        tryVerify(() => findChild(form, "placeRing") !== null)
        popPage()
    }

    // The same page on a phone: a tap opens the sheet, no panel.
    function test_9k_map_phone() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k4")
        window.width = 420
        window.height = 860
        const page = push("TechniqueMapPage")
        slidIn()
        tryVerify(() => !page.wide, 2000, "a phone")
        verify(!findChild(page, "mapPanel").visible)
        // The filters: at most three lines (discipline; grade and groups).
        const filters = findChild(page, "mapFilters")
        tryVerify(() => filters.height > 0 && filters.height <= 3 * findChild(page, "gradeBox").height + 4 * Kirigami.Units.smallSpacing, 2000, "filters " + filters.height)
        const heat = findChild(page, "techniqueMatrix")
        let target = null
        for (let r = 0; r < heat.rowCount && !target; r++) {
            for (let c = 0; c < heat.columnCount; c++) {
                if (!heat.isEmpty(r, c)) {
                    target = { r: r, c: c }
                    break
                }
            }
        }
        verify(target)
        shot("11-map-phone")
        const sheet = findChild(page, "techniqueSheet")
        mouseClick(heat.cellAt(target.r, target.c))
        tryVerify(() => sheet.opened)
        compare(sheet.entry.id, page.shown.rows[target.r].cells[target.c].entry.id)
        verify(page.paneEntry === null)
        sheet.close()
        tryVerify(() => !sheet.visible)
        popPage()
    }

    // Glossary: without a query A–Z with headings, the source below; a query finds words by
    // romaji, kanji and German next to techniques; without a Japanese voice no speaker buttons.
    SignalSpy {
        id: saySpy

        target: Glossary
        signalName: "sayRequested"
    }

    function test_9b_glossary() {
        failOnWarning(/ReferenceError|TypeError/)
        const start = window.pageStack.items[0]
        const tile = findChild(start, "glossaryTile")
        verify(tile.visible)
        // Cases that end with skip() (no videos) leave their pages on the stack.
        while (window.pageStack.depth > 1)
            popPage()
        tryVerify(() => window.pageStack.currentItem === start)
        slidIn()
        clickTile(tile)
        tryVerify(() => window.pageStack.currentItem !== start && window.pageStack.currentItem.glossary !== undefined, 2000)
        const page = window.pageStack.currentItem
        const list = findChild(page, "glossaryList")
        const field = findChild(page, "searchField")
        verify(Glossary.words.length > 219)
        tryCompare(list, "count", Glossary.words.length)
        verify(findChild(page, "glossaryIntro").visible)
        compare(page.rows[0].section, "A")
        tryVerify(() => findChild(list, "letterHeading") !== null)
        compare(findChild(list, "letterHeading").text, "A")
        compare(Glossary.words[0].word, "Ago")
        shot("9b-glossary")

        // No Japanese voice (mock engine): a hint, no buttons, saying does nothing.
        verify(Glossary.speech !== Glossary.Ready)
        verify(findChild(page, "speechHint").visible)
        const say = findChild(list, "sayButton")
        verify(say === null || !say.visible)
        Glossary.say(Glossary.words[0].speech)

        // Keyboard: Down from the field into the list, Return and Space say the current word,
        // Up back to the field.
        field.forceActiveFocus()
        keyClick(Qt.Key_Down)
        tryVerify(() => list.activeFocus)
        compare(list.currentIndex, 0)
        keyClick(Qt.Key_Down)
        compare(list.currentIndex, 1)
        saySpy.clear()
        keyClick(Qt.Key_Return)
        compare(saySpy.count, 1)
        compare(saySpy.signalArguments[0][0], page.glossary[1].speech)
        keyClick(Qt.Key_Space)
        compare(saySpy.count, 2)
        keyClick(Qt.Key_Up)
        keyClick(Qt.Key_Up)
        tryVerify(() => field.activeFocus)

        // The same word by romaji with or without hyphen and by kanji with other okurigana.
        for (const q of ["Kiriotoshi", "Kiri-otoshi", "切り落とし"]) {
            field.text = q
            tryVerify(() => page.query === q, 2000)
            verify(page.glossary.some(w => w.word === "Kiri-otoshi"), q)
            verify(page.techniques.length > 0, q)
        }
        compare(page.rows[0].section, qsTr("Glossary"))
        verify(!findChild(page, "glossaryIntro").visible)
        // German words find their Japanese term.
        field.text = "hüftwurf"
        tryVerify(() => page.query === "hüftwurf", 2000)
        verify(page.glossary.some(w => w.word === "Koshi-nage"))
        // One list: the words first, then the techniques and notes found.
        tryCompare(list, "count", page.rows.length)
        compare(page.rows[page.glossary.length - 1].kind, "word")
        compare(page.rows.length, page.glossary.length + page.shown.length + page.notesShown.length)
        tryVerify(() => findChild(page, "glossarySource") !== null && findChild(page, "glossarySource").visible)
        verify(findChild(page, "glossarySource").text.includes("shinkiryu.de"))
        shot("9b-glossary-search")
        popPage()
    }

    // All notes: every technique's notes by day, a filter per discipline; a tap opens the
    // technique's notes, press and hold the editor.
    function test_8d_all_notes() {
        failOnWarning(/ReferenceError|TypeError/)
        const daito = Programme.entries("daitoryu", Programme.grades("daitoryu")[0].id).find(r => r.kind === "entry")
        Practice.addNote(daito.id, "Daitoryu: Hüfte zuerst")
        Practice.addNote("not-in-the-programme", "verwaist")
        const page = push("AllNotesPage")
        page.filter = ""
        const total = page.shown.length
        verify(total >= 2)
        compare(page.shown[0].text, "verwaist", "newest first")
        verify(page.shown.filter(n => n.day === page.shown[0].day).length >= 2, "both today")
        tryVerify(() => page.enabled)   // Kirigami slides the page in (disabled while it loads) ...
        wait(500)                       // ... and moves it
        mouseClick(findChild(page, "filter_daitoryu"))
        tryVerify(() => page.filter === "daitoryu")
        verify(page.shown.length >= 1 && page.shown.every(n => n.discipline === "daitoryu"))
        verify(page.shown.length < total, "the orphan and other disciplines left out")
        shot("8d-all-notes")
        const note = findChild(page, "note")
        mouseClick(note, 20, note.height - 10)
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        compare(window.pageStack.currentItem.entry.id, daito.id)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        slidIn()
        mousePress(note, 20, note.height - 10)
        wait(1000)
        mouseRelease(note, 20, note.height - 10)
        const editor = findChild(page, "noteEditor")
        tryVerify(() => editor.opened, 2000, "press and hold opens the editor")
        editor.close()
        tryVerify(() => !editor.opened)
        // Many notes: a virtual list builds delegates for the visible ones only.
        page.filter = ""
        wait(50)        // another filter goes to the top a moment later
        const many = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        for (let i = 0; i < 60; i++)
            Practice.addNote(many[i % many.length].id, "Übung " + i)
        const list = findChild(page, "notesList")
        tryVerify(() => list.count >= 60)
        verify(findChildren(list.contentItem, "note").length < list.count / 2, "only the visible delegates")
        // A change further down keeps the place in the list.
        list.positionViewAtIndex(40, ListView.Beginning)
        wait(50)
        const top = page.shown[list.indexAt(10, list.contentY + 10)].uid
        Practice.changeNote(page.shown[42].uid, "geändert")
        tryVerify(() => page.shown[42].text === "geändert")
        wait(50)
        compare(page.shown[list.indexAt(10, list.contentY + 10)].uid, top, "same note at the top")
        // Also with the gap between two notes at the top, and when the top note is deleted.
        const y = list.contentY
        list.contentY = y - list.spacing / 2
        wait(50)
        verify(list.indexAt(10, list.contentY) < 0, "a gap at the very top")
        Practice.changeNote(page.shown[44].uid, "noch einmal")
        wait(50)
        compare(page.shown[list.indexAt(10, list.contentY + 10)].uid, top, "same note after a gap at the top")
        const next = page.shown[41].uid
        Practice.deleteNote(top)
        tryVerify(() => !page.shown.some(n => n.uid === top))
        wait(50)
        compare(page.shown[list.indexAt(10, list.contentY + list.spacing + 10)].uid, next, "the next note moves up")
        // Tab: through the filter to the list, on a note in view (not the first one far above).
        mouseClick(findChild(page, "filter_all"))
        const chips = Programme.disciplines.length + 2          // All, the disciplines, Courses
        for (let i = 0; i <= chips + 2 && !list.activeFocus; i++)       // Back first if the page has the focus
            keyClick(Qt.Key_Tab)
        verify(list.activeFocus, "Tab reaches the list after the filter")
        keyClick(Qt.Key_Backtab)
        compare(window.activeFocusItem, findChild(page, "filter_courses"), "Shift+Tab goes back to the filter")
        keyClick(Qt.Key_Tab)
        verify(list.activeFocus)
        // A whole round of Tab: the toolbar (Back), every chip and the list, each once.
        const round = []
        for (let i = 0; i < 30; i++) {
            keyClick(Qt.Key_Tab)
            if (list.activeFocus)
                break
            round.push(String(window.activeFocusItem))
        }
        verify(list.activeFocus, "back at the list: " + round.join(" > "))
        verify(round.some(t => t.indexOf("NavButton") >= 0 || t.indexOf("headBack") >= 0), "Tab reaches Back: " + round.join(" > "))
        compare(round.filter(t => t.indexOf("filter_") >= 0).length, chips, round.join(" > "))
        const cur = list.itemAtIndex(list.currentIndex)
        verify(cur && cur.y + cur.height > list.contentY && cur.y < list.contentY + list.height,
               "the current note is in view (" + list.currentIndex + ")")
        // Changed with the keyboard: the focus and the note stay.
        const at = list.currentIndex
        keyClick(Qt.Key_Menu)
        tryVerify(() => editor.opened, 2000)
        Practice.changeNote(page.shown[at].uid, "mit der Tastatur")
        editor.close()
        tryVerify(() => !editor.opened)
        tryVerify(() => list.activeFocus, 1000, "the list has the focus again")
        compare(list.currentIndex, at)
        // Page Down, End and Home move through the list.
        keyClick(Qt.Key_PageDown)
        verify(list.currentIndex > at + 1, "Page Down: " + list.currentIndex)
        keyClick(Qt.Key_End)
        compare(list.currentIndex, list.count - 1)
        keyClick(Qt.Key_Home)
        compare(list.currentIndex, 0)
        tryVerify(() => list.atYBeginning, 1000, "Home shows the count above the first note")
        // Page Up back to the first note shows the count too.
        for (let i = 0; i < 3; i++)
            keyClick(Qt.Key_PageDown)
        while (list.currentIndex > 0)
            keyClick(Qt.Key_PageUp)
        tryVerify(() => list.atYBeginning, 1000, "Page Up to the first note shows the count")
        // A new note while the current one is out of view: the view stays where it is.
        list.positionViewAtIndex(30, ListView.Beginning)
        wait(50)
        const shownTop = page.shown[list.indexAt(10, list.contentY + 10)].uid
        Practice.addNote(many[0].id, "ganz neu")
        tryVerify(() => page.shown[0].text === "ganz neu")
        wait(50)
        compare(page.shown[list.indexAt(10, list.contentY + 10)].uid, shownTop, "no jump to the current note")
        // Scrolled, the notes stay below the filter (the list is clipped).
        const chip = findChild(page, "filter_all")
        list.positionViewAtBeginning()
        wait(50)
        const area = chip.mapToItem(window.contentItem, 0, 0)
        const clean = grabImage(window.contentItem)
        list.contentY = list.originY + 150
        wait(50)
        const scrolled = grabImage(window.contentItem)
        let covered = 0
        for (let x = area.x + 1; x < area.x + chip.width - 1; x += 3)
            for (let y = area.y + 1; y < area.y + chip.height - 1; y += 3)
                if (String(clean.pixel(x, y)) !== String(scrolled.pixel(x, y)))
                    covered++
        compare(covered, 0, "the filter is not covered by the scrolled list")
        // The filter in line with the notes.
        compare(findChild(page, "filter").rightPadding, findChild(page, "notesView").rightPadding)
        // End again after scrolling away: the last note comes back into view.
        list.forceActiveFocus()
        keyClick(Qt.Key_End)
        tryVerify(() => list.atYEnd, 1000)
        list.positionViewAtBeginning()
        wait(50)
        keyClick(Qt.Key_End)
        tryVerify(() => list.atYEnd, 1000, "End shows the last note again")
        // The scroll bar at the window's edge, not over the notes. Shinki's bar (LookScrollView) is
        // 4 px wide; Kante's wider bar keeps the note content inside its left. Under both the
        // bar lives to the right of the notes: read it as the rightmost x of the bar.
        const bar = list.parent.QQC2.ScrollBar.vertical
        if (bar && bar.width > 0) {
            const note = findChild(list.contentItem, "note")
            const noteRight = note.mapToItem(page, note.width, 0).x
            const barRight = bar.mapToItem(page, bar.width, 0).x
            // The bar's right is at or past the page's right, the note's right is left of it.
            verify(barRight >= page.width - 1
                   && noteRight <= barRight + 1,
                   "bar right " + barRight + ", note right " + noteRight + ", page right " + page.width)
        }
        // The keyboard reaches every note: Down moves through the list, which follows; Enter opens.
        list.positionViewAtBeginning()
        list.forceActiveFocus()
        list.currentIndex = 0
        for (let i = 0; i < 30; i++)
            keyClick(Qt.Key_Down)
        compare(list.currentIndex, 30)
        verify(list.contentY > 200, "the list follows the keyboard (" + list.contentY + ")")
        const target = page.shown[30].entry
        keyClick(Qt.Key_Return)
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        compare(window.pageStack.currentItem.entry.id, target)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        slidIn()
        // Page Up up to the first note shows the count above it too.
        list.forceActiveFocus()
        keyClick(Qt.Key_End)
        tryVerify(() => list.atYEnd, 1000)
        for (let i = 0; i < 200 && list.currentIndex > 0; i++)
            keyClick(Qt.Key_PageUp)
        compare(list.currentIndex, 0)
        wait(500)
        verify(list.atYBeginning, "the count in view after Page Up (" + list.contentY + ", " + list.originY + ")")
        // Another filter starts at the top.
        list.positionViewAtEnd()
        page.filter = "aikido"
        tryVerify(() => list.atYBeginning, 1000, "another filter starts at the top")
        page.filter = ""
        // A remembered discipline that no longer exists falls back to all.
        page.filter = "kendo"
        tryCompare(page, "filter", "")
        // An empty filter says so (a discipline without notes, if one is left).
        const everything = page.shown
        const empty = Programme.disciplines.find(d => !everything.some(n => n.discipline === d.id))
        if (empty) {
            list.forceActiveFocus()
            list.currentIndex = 3
            page.filter = empty.id
            compare(findChild(page, "count").text, qsTr("No notes in this discipline."))
            tryCompare(list, "count", 0)
            compare(list.currentIndex, -1, "an empty list has no current note")
            keyClick(Qt.Key_Home)
            keyClick(Qt.Key_End)
            compare(list.currentIndex, -1, "an empty list has no current note")
            page.filter = ""
        }
        // The orphan is named as such.
        const orphan = everything.find(n => n.entry === "not-in-the-programme")
        compare(orphan.title, qsTr("Technique no longer in the programme"))
        // Notes → All notes → Notes → All notes does not pile up: the action goes back.
        const depth = window.pageStack.depth
        page.open(page.shown.find(n => n.kind === "technique" && n.entry !== "not-in-the-programme"))
        tryVerify(() => window.pageStack.depth === depth + 1)
        window.pageStack.currentItem.actions[0].trigger()
        tryVerify(() => window.pageStack.depth === depth, 2000, "back to the list instead of a new one")
        compare(window.pageStack.currentItem, page)
        // The filter is kept for the next time.
        page.filter = "daitoryu"
        popPage()
        const again = push("AllNotesPage")
        compare(again.filter, "daitoryu")
        again.filter = ""

        // A course notebook's entries join the list: their own filter, a tap opens the notebook,
        // the editor changes them through Courses.
        const course = Courses.create("Gastlehrer", "2026-05-01", "", "", "")
        verify(Courses.addEntry(course, "Irimi früher"))
        // In all notes a course entry says when it was written.
        const allNotes = push("AllNotesPage")
        allNotes.filter = "courses"
        tryVerify(() => findChild(allNotes, "noteTitle") !== null)
        verify(findChild(allNotes, "noteTitle").text.indexOf(" · ") > 0, findChild(allNotes, "noteTitle").text)
        popPage()
        tryVerify(() => again.shown[0].kind === "course")
        compare(again.shown[0].title, "Gastlehrer")
        wait(800)
        mouseClick(findChild(again, "filter_courses"))
        tryVerify(() => again.filter === "courses")
        tryVerify(() => again.shown.length === 1)
        shot("8e-all-notes-courses")
        const entry = findChild(again, "note")
        mouseClick(entry, 20, entry.height - 10)
        tryVerify(() => window.pageStack.currentItem.uid === course, 2000)
        popPage()
        tryVerify(() => window.pageStack.currentItem === again)
        again.edit(again.shown[0])
        const courseEditor = findChild(again, "noteEditor")
        tryVerify(() => courseEditor.opened)
        verify(courseEditor.save(again.shown[0].uid, "Irimi noch früher"))
        courseEditor.close()
        tryVerify(() => again.shown[0].text === "Irimi noch früher")
        compare(Courses.entries(course)[0].text, "Irimi noch früher")
        verify(Courses.remove(course))
        tryVerify(() => again.shown.length === 0)
        compare(findChild(again, "count").text, qsTr("No entries in course notebooks yet."))
        again.filter = ""
        popPage()
    }

    // Exam mode: settings, a round with samples first (marked), rating at the end; "Apply" sets
    // the ratings and the statistics show the round.
    function test_9e_exam() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k4")
        Exam.count = 8
        Exam.shuffled = false
        Exam.samples = true
        const tile = findChild(window.pageStack.items[0], "examTile")
        tryVerify(() => tile.hint.indexOf("4. Kyu") >= 0, 5000, tile.hint)

        const page = push("ExamPage")
        compare(page.grade, "k4")
        compare(page.size, Exam.material("aikido", "k4").length)
        compare(page.counts[page.countIndex], 8)
        tryVerify(() => findChild(page, "samplesSwitch").enabled, 2000, "samples from 5. Kyu possible")
        verify(findChild(page, "grade_k5"), "a chip per grade")
        shot("11-exam")

        mouseClick(findChild(page, "startRound"))
        tryVerify(() => window.pageStack.currentItem !== page && window.pageStack.currentItem.points !== undefined)
        const round = window.pageStack.currentItem
        const n = round.points.length
        const samples = round.points.filter(p => p.sample).length
        verify(samples >= 2 && samples <= 5, "samples: " + samples)
        compare(n, 8 + samples)
        verify(round.points.slice(0, samples).every(p => p.sample && p.gradeName === "5. Kyu"), "samples first")
        const mark = findChild(round, "sampleMark")
        verify(mark.visible)
        verify(mark.text.indexOf("5. Kyu") >= 0, mark.text)
        compare(findChild(round, "counter").text, "1 / " + n)
        const board = findChild(round, "examBoard")
        compare(findChild(board, "boardAttack").visible, !!round.current.attack)
        verify(findChild(board, "boardTechnique").text.indexOf(round.current.title) >= 0)
        shot("12-exam-round")

        // Space and Enter move on; past the samples the mark goes.
        keyClick(Qt.Key_Space)
        compare(round.index, 1)
        keyClick(Qt.Key_Return)
        compare(round.index, 2)
        round.index = samples
        verify(!mark.visible, "own grade: no mark")
        const withAttack = round.points.findIndex(p => !p.sample && !!p.attack)
        if (withAttack >= 0) {
            round.index = withAttack
            verify(findChild(board, "boardAttack").visible)
            verify(findChild(board, "boardGroup").visible)
        }
        round.index = n - 1
        mouseClick(findChild(round, "nextButton"))
        tryVerify(() => window.pageStack.currentItem !== round && window.pageStack.currentItem.levels !== undefined)
        const end = window.pageStack.currentItem
        compare(window.pageStack.depth, 3, "the round page was replaced")

        // "Apply" only once every point is rated.
        const apply = findChild(end, "applyRound")
        wait(500)       // past the page transition, during which no button is enabled anyway
        verify(!apply.enabled)
        verify(!end.complete)
        const pickers = findChildren(end, "pointPicker").sort((a, b) => a.parent.index - b.parent.index)
        compare(pickers.length, n)
        let sum = 0
        for (let i = 0; i < n; ++i) {
            const level = i % 4 + 1
            sum += level
            pickers[i].picked(level)
            compare(end.complete, i === n - 1)
        }
        tryVerify(() => apply.enabled)
        compare(pickers[1].value, 2)
        shot("13-exam-end")
        apply.clicked()

        // The ratings are set, the statistics show the round (with the menu behind them).
        tryVerify(() => !!findChild(window.pageStack.currentItem, "examChart"))
        compare(window.pageStack.depth, 2)
        for (let i = 0; i < n; ++i) {
            compare(Practice.level(end.points[i].id), i % 4 + 1)
        }
        const stats = window.pageStack.currentItem
        compare(stats.discipline, "aikido")
        const chart = findChild(stats, "examChart")
        // Under Shinki the bars are muted ink, apart from the level colours of the legend above
        // (owner, 03.11.2026): an average of 2.3 does not read as "sure".
        if (uiShinki) {
            verify(Qt.colorEqual(chart.seriesColor(chart.series), Look.mutedTextColor), String(chart.seriesColor(chart.series)))
        }
        verify(chart.visible)
        compare(chart.values.length, 1)
        fuzzyCompare(chart.values[0], sum / n, 0.001)
        compare(chart.gridLines, 4)
        compare(chart.format(1), "1")
        compare(chart.format(4), "4")
        chart.hoverIndex = 0
        verify(chart.partNames[0].indexOf("4. Kyu") >= 0 && chart.partNames[0].indexOf(String(n)) >= 0, chart.partNames[0])
        wait(1000)
        stats.flickable.contentY = stats.flickable.contentHeight - stats.flickable.height
        shot("14-stats-exam")
        chart.hoverIndex = -1
        // Another discipline without rounds says so.
        stats.discipline = "daitoryu"
        verify(!chart.visible)
        verify(findChild(stats, "examRoundsText").text.length > 0)
        // A round with average 1 (all "seen") still shows a bar; the read-out says 1.
        verify(Practice.saveRound("daitoryu", "k5", [{ id: "exam-test-entry", level: 1 }]))
        verify(chart.visible)
        compare(chart.values.length, 1)
        compare(chart.values[0], 1)
        verify(chart.barHeight(0) >= KanteStyle.unit(3), "a bar at average 1: " + chart.barHeight(0))
        compare(chart.format(chart.values[0]), "1")
        stats.discipline = "aikido"
        popPage()

        // The settings show the last round.
        const again = push("ExamPage")
        verify(findChild(again, "examHint").text.indexOf(again.averageText(sum / n)) >= 0, findChild(again, "examHint").text)
        popPage()
    }

    // Shinki Toho: Shoden asks the Kamae as one point and Ô-dachi 1–11; the board shows only the
    // technique; no samples before the first grade. Cancel goes back to the settings.
    function test_9f_exam_shinkitoho() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        Exam.count = 0
        Exam.samples = true
        const page = push("ExamPage")
        compare(page.size, 12)
        compare(page.counts, [0, 8])
        verify(!findChild(page, "samplesSwitch").enabled, "first grade")
        page.start()
        tryVerify(() => window.pageStack.currentItem !== page && window.pageStack.currentItem.points !== undefined)
        const round = window.pageStack.currentItem
        compare(round.points.length, 12)
        compare(round.points[0].id, "shinkitoho/kamae")
        verify(round.points.every(p => !p.sample))
        const board = findChild(round, "examBoard")
        verify(!findChild(board, "boardAttack").visible)
        verify(!findChild(board, "boardGroup").visible)
        verify(findChild(board, "boardTechnique").visible)
        verify(!findChild(round, "sampleMark").visible)
        round.index = 1
        compare(round.current.id, "shinkitoho/odachi/1")
        verify(!findChild(board, "boardAttack").visible)
        // Only number, name and kanji: the addition (In · Seigan → Hidari-gote) is the answer.
        verify(!!round.current.extra, "the form has an addition")
        verify(!findChild(board, "boardExtra").visible, "the board keeps the addition back")
        verify(findChild(board, "boardKanji").visible)
        shot("12b-exam-round-shinkitoho")
        // A tablet in landscape: the board grows.
        window.width = 1280
        window.height = 800
        tryVerify(() => round.tablet)
        compare(board.zoom, 1.6)
        shot("12c-exam-round-tablet")
        round.actions[0].trigger()
        if (round.index > 0) {
            const asked = findChild(round, "cancelRoundDialog")
            tryVerify(() => asked.opened)
            asked.accept()
        }
        tryVerify(() => window.pageStack.currentItem === page)
        popPage()
    }

    // Back from the rating asks once something is rated; without a rating it just goes back.
    function test_9g_exam_discard() {
        failOnWarning(/ReferenceError|TypeError/)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        Exam.count = 8
        Exam.samples = false
        const settings = push("ExamPage")
        const depth = window.pageStack.depth
        settings.start()
        tryVerify(() => window.pageStack.currentItem.points !== undefined && window.pageStack.currentItem !== settings)
        const round = window.pageStack.currentItem
        round.index = round.points.length - 1
        round.next()
        tryVerify(() => window.pageStack.currentItem.levels !== undefined)
        let end = window.pageStack.currentItem
        const dialog = findChild(end, "discardDialog")
        verify(dialog)

        // Nothing rated: straight back.
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem === settings)
        wait(300)       // the question would come a moment later (Qt.callLater)
        verify(window.pageStack.currentItem === settings, "stays back")
        verify(!dialog.opened)

        // Rated: the dialog asks, Cancel stays, Discard goes back without saving.
        settings.start()
        tryVerify(() => window.pageStack.currentItem.points !== undefined && window.pageStack.currentItem !== settings)
        window.pageStack.currentItem.index = window.pageStack.currentItem.points.length - 1
        window.pageStack.currentItem.next()
        tryVerify(() => window.pageStack.currentItem.levels !== undefined)
        end = window.pageStack.currentItem
        const asked = findChild(end, "discardDialog")
        const before = Practice.rounds("aikido", 8).length
        end.rate(0, 4)
        if (uiShinki) {
            mouseClick(findChild(window, "headBack"))      // Shinki's head asks the page as well
        } else {
            window.pageStack.goBack()
        }
        tryVerify(() => asked.opened)
        verify(window.pageStack.currentItem === end, "still rating")
        shot("13b-exam-discard", true)
        // The text readable on the dialog's ground (it hangs on the overlay, outside the page's
        // scope; a dark platform scheme gave white on white), Cancel before the main button on
        // every platform.
        const question = findChild(asked.contentItem, "discardText")
        const ratio = contrast(question.color, asked.background.color)
        verify(ratio >= 4.5, question.color + " on " + asked.background.color + ": " + ratio.toFixed(1) + ":1")
        const cancel = asked.standardButton(QQC2.Dialog.Cancel)
        const discard = asked.standardButton(QQC2.Dialog.Ok)
        verify(cancel.mapToItem(null, 0, 0).x < discard.mapToItem(null, 0, 0).x, "Cancel first")
        compare(cancel.text, qsTr("Keep the round"), "its way out says where it goes")
        asked.reject()
        tryVerify(() => !asked.opened)
        verify(window.pageStack.currentItem === end, "still rating")
        window.pageStack.goBack()
        tryVerify(() => asked.opened)
        asked.accept()
        tryVerify(() => window.pageStack.currentItem === settings)
        compare(window.pageStack.depth, depth)
        compare(Practice.rounds("aikido", 8).length, before)
        popPage()
    }

    // The Kamae player: its 26 positions come last, so the rating stays where it is for a technique
    // without positions (in view without scrolling), and a large tablet keeps the picture as large.
    // Sideways there is only the rail (test_4_player).
    function test_9y_kamae_player() {
        failOnWarning(/ReferenceError|TypeError/)
        const kamae = Programme.entry("shinkitoho/kamae")
        const suburi = Programme.entry("shinkitoho/suburi/1")
        if (!kamae.video || !Videos.available(kamae.video.video)) {
            skip("no video for the Kamae exercise (set MITORI_VIDEOS)")
        }
        // [width, height, training, the item that must be in view]
        for (const c of [[420, 800, true, "kinoRating"]]) {
            window.width = c[0]
            window.height = c[1]
            const at = entry => {
                const page = push("PlayerPage", { playlist: [entry], index: 0, training: c[2] })
                wait(500)
                // With a picture the ratings stand in the thumb zone (Kino), the positions in the middle;
                // without one the controls scroll and the positions come last.
                const view = page.kino ? page : findChild(page, "controlsView")
                if (!page.kino) {
                    compare(view.contentY, 0)
                }
                const item = findChild(page, page.kino ? c[3] : "ratingRow")
                verify(item.visible, c[3])
                const y = item.mapToItem(view, 0, 0).y
                const result = { y: y, bottom: y + item.height, height: view.height, steps: findChild(page, "stepList").count }
                popPage()
                return result
            }
            const k = at(kamae)
            const s = at(suburi)
            compare(k.steps, 26)
            compare(s.steps, 0)
            verify(Math.abs(k.y - s.y) < 1, c[3] + " at " + c + ": " + k.y + " with the positions, " + s.y + " without")
            // The rating stands before them: in view upright.
            verify(k.bottom <= k.height, c[3] + " in view at " + c + " (" + k.bottom + " of " + k.height + ")")
        }
        // A large tablet beside the list: the picture as large as for a technique without positions.
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        window.width = 1920
        window.height = 1080
        const programme = push("ProgrammePage")
        tryVerify(() => programme.split)
        const pane = findChild(programme, "playerPane")
        programme.open(programme.rows.find(r => r.id === suburi.id))
        tryCompare(pane.item.current, "id", suburi.id, 3000)
        const stage = findChild(pane.item, "stage")
        wait(300)
        const without = stage.height
        verify(without > stage.width / stage.ratio / 2 + 1, "more than half the picture: " + without)
        programme.open(programme.rows.find(r => r.id === kamae.id))
        tryCompare(pane.item.current, "id", kamae.id, 3000)
        tryCompare(findChild(pane.item, "stepList"), "count", 26)
        wait(300)       // laid out with the positions
        verify(Math.abs(stage.height - without) < 1, "picture " + stage.width + "×" + stage.height + ", without positions " + without)
        window.width = 420
        window.height = 800
        popPage()
        Programme.discipline = "aikido"
    }

    function test_9z_stats() {
        // A rating today makes today a practice day (Shinki Toho: the other cases leave it alone;
        // the cases run in name order, this one last).
        const grade = Programme.grades("shinkitoho")[0].id
        const rows = Programme.entries("shinkitoho", grade).filter(r => r.kind === "entry")
        verify(Practice.rate(rows[0].id, 2))
        const page = push("StatsPage")
        compare(page.last30.days, 1)
        compare(findChild(page, "practiceDays").value, "1")
        // The open page follows new ratings; a technique counts once a day.
        const before = page.last30.techniques
        verify(Practice.rate(rows[0].id, 3))
        verify(Practice.rate(rows[1].id, 1))
        verify(Practice.rate(rows[1].id, 2))
        compare(page.last30.techniques, before + 1)
        compare(findChild(page, "techniquesPractised").value, String(before + 1))
        const heat = findChild(page, "practiceHeatmap")
        verify(heat.weeks >= 4 && heat.weeks <= 26)
        const today = heat.isoDay(new Date())
        verify(heat.levels[today] >= 1, "today coloured")
        verify(heat.tipOf(new Date()).indexOf(String(page.perDay[today])) >= 0, heat.tipOf(new Date()))
        // A day without practice says so.
        const yesterday = new Date()
        yesterday.setDate(yesterday.getDate() - 1)
        verify(heat.tipOf(yesterday).indexOf(qsTr("no practice")) > 0, heat.tipOf(yesterday))
        // Each grade shows its figures without hovering: exam-ready of all.
        const stands = findChildren(page, "statsGradeStand")
        verify(stands.length > 3, "a bar per grade")
        const figures = findChildren(page, "gradeFigure")
        verify(figures.length > 3)
        verify(/\d+.*\d+/.test(figures[0].text), figures[0].text)
        shot("10-stats")
        // My grades of the discipline.
        verify(Courses.addGrade("daitoryu", "k5", "2025-05-01", "Bonn"))
        page.discipline = "daitoryu"
        tryVerify(() => findChildren(page, "statsGrade").length === 1)
        verify(findChild(page, "editGrades").visible)
        popPage()

        // All years: this year's calendar first, with the day; one discipline only.
        const years = push("YearsPage")
        const year = new Date().getFullYear()
        const block = findChild(years, "year_" + year)
        verify(block, "this year")
        verify(findChild(block, "yearHeading").text.indexOf(qsTr("%n practice day(s)", "", 1)) > 0,
               findChild(block, "yearHeading").text)
        // Every day says what it was, also one without practice.
        const dayBefore = new Date()
        dayBefore.setDate(dayBefore.getDate() - 1)
        // On a phone the year stands in two halves: the one that holds the day.
        const yearHeat = findChildren(block, "yearHeatmap")
            .find(h => h.cells.some(c => c.shown && c.iso === h.isoDay(dayBefore)))
        if (dayBefore.getFullYear() === year) {
            verify(yearHeat.tipOf(dayBefore).indexOf(qsTr("no practice")) > 0, yearHeat.tipOf(dayBefore))
        }
        years.discipline = "shinkitoho"
        verify(findChild(findChild(years, "year_" + year), "yearHeading").text.indexOf(qsTr("%n practice day(s)", "", 1)) > 0)
        shot("10b-years")
        popPage()
        Courses.removeGrade(Courses.grades.find(g => g.discipline === "daitoryu").uid)
        // The start tile counts the practice days.
        const tile = findChild(window.pageStack.items[0], "statsTile")
        tryCompare(tile, "days", 1)
    }

    // Another video folder for this case; cleanup() brings the real one back.
    function useFolder(folder) {
        if (realFolder === null) {
            realFolder = Videos.folder
        }
        Videos.folder = folder
    }

    // The first small player of a run compiles PlayerView and starts the media backend: 1 s alone,
    // 8.7 s in a debug build beside 30 busy processes.
    readonly property int paneLoads: 20000
    // A clip or a bundle loads in a thread that needs its share of the machine: 2 s beside 30 busy
    // processes, past 10 s beside 100. The limit only tells a hang from a slow machine.
    readonly property int mediaLoads: 30000

    // The programme on a tablet, with stand-ins for the videos: nothing plays, but what would is
    // the player's autoPlay.
    function tabletProgramme(folder, discipline, grade) {
        useFolder(folder || standInVideos)
        Programme.discipline = discipline || "aikido"
        PracticeGrade.setGrade(Programme.discipline, grade || "k5")
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.split && page.player, paneLoads)
        return page
    }

    // Clips that really play under the catalog's names (tst_ui.cpp).
    function clipFolder(name) {
        return uiDataDir + "/played-" + name
    }
    function chapterLoaded(page) {
        tryVerify(() => page.player && page.player.duration > 0 && Math.abs(page.player.position - page.player.from) < 1000, mediaLoads)
    }
    // The row plays beside the list, past its chapter's start.
    function rowPlays(page, row) {
        page.open(page.playlist[row])
        compare(page.player.current.id, page.playlist[row].id)
        tryVerify(() => page.player.playing && page.player.position > page.player.from + 300, mediaLoads)
    }
    // Paused well inside the chapter: its start would not pass for the same place.
    function pausedInside(player) {
        player.pause()
        tryVerify(() => !player.playing)
        const place = player.from + 5000
        player.seek(place)
        tryVerify(() => Math.abs(player.position - place) < 300, 5000)
        return player.position
    }
    function staysStanding(player, why) {
        wait(500)
        verify(!player.playing, why)
    }
    function remakePane(page, width, height) {
        window.width = width || 800
        window.height = height || 1280
        tryVerify(() => !page.split)
        window.width = 1280
        window.height = 800
        tryVerify(() => page.split && page.player, paneLoads)
    }
    function chooseGrade(page, id) {
        // On a tablet the chips scroll with the rows: back to them, as the user would.
        if (page.wide) {
            findChild(page, "programmeList").positionViewAtBeginning()
            wait(50)
        }
        const chips = findChild(page, "gradeChips")
        clickUntil(chips.itemAt(page.grades.findIndex(g => g.id === id)), () => page.grade === id)
    }

    // A shelf save makes the list anew, with new objects: only another technique restarts.
    function test_2u_a_save_leaves_player_alone() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        page.player.setSpeed(0.5)
        const running = page.player.position

        Videos.folderChanged()
        wait(300)
        verify(page.player.playing, "still playing")
        verify(page.player.position >= running, page.player.position + " after " + running)
        compare(page.player.rate, 0.5)

        page.player.pause()
        tryVerify(() => !page.player.playing)
        const paused = page.player.position
        Videos.folderChanged()
        staysStanding(page.player, "paused stays paused")
        verify(Math.abs(page.player.position - paused) < 100, page.player.position + " after " + paused)
    }

    // What waits for a tap ends with its technique: another one plays as usual.
    function test_2u_b_hold_ends_with_technique_data() {
        return [ { tag: "file gone", folder: "gone" }, { tag: "failed load", folder: "broken" } ]
    }
    function test_2u_b_hold_ends_with_technique(data) {
        useFolder(clipFolder("long"))
        const chapter = { von: 1, bis: 60 }
        const rows = [{ id: "a", title: "A", video: Object.assign({ video: "aikido/k5" }, chapter) },
                      { id: "b", title: "B", video: Object.assign({ video: "aikido/k4" }, chapter) }]
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        tryVerify(() => player.playing, mediaLoads)

        Videos.folder = clipFolder(data.folder)
        wait(300)
        player.go(1)
        tryVerify(() => player.playing && player.position > 1000, mediaLoads, "the next technique plays")
    }

    // A save while the player first loads is no file changed under it.
    function test_2u_b_save_during_first_load() {
        useFolder(clipFolder("long"))
        const rows = [{ id: "a", title: "A", video: { video: "aikido/k5", von: 1, bis: 60 } }]
        const player = window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/PlayerPage.qml"), { playlist: rows, index: 0 })
        Videos.folderChanged()
        tryVerify(() => player.playing, mediaLoads, "plays as if opened alone")
    }

    // A pane made anew keeps the state: playing plays on, standing stands, in the same place.
    function test_2u_c_new_pane_keeps_state_data() {
        return [
            { tag: "paused", prepare: page => pausedInside(page.player), plays: false },
            { tag: "waiting after a file change", prepare: page => {
                Videos.folder = clipFolder("long2")
                // The pane may go for a moment with the old folder's list.
                tryVerify(() => page.player && page.player.source.toString().indexOf("played-long2") > 0, mediaLoads)
                tryVerify(() => page.player && page.player.duration > 0 && !page.player.playing, mediaLoads)
                wait(300)
              }, plays: false },
            { tag: "playing", prepare: () => {}, plays: true }
        ]
    }
    function test_2u_c_new_pane_keeps_state(data) {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        data.prepare(page)
        tryCompare(page.player, "playing", data.plays)
        const at = page.player.position

        remakePane(page)
        tryVerify(() => page.player.duration > 0, mediaLoads)
        compare(page.player.current.id, page.playlist[1].id)
        if (data.plays) {
            tryVerify(() => page.player.playing, mediaLoads, "plays on")
            verify(page.player.position >= at - 300, page.player.position + " after " + at)
            return
        }
        staysStanding(page.player, "stands, no sound by itself")
        verify(Math.abs(page.player.position - at) < 500, page.player.position + " after " + at)
    }

    // A pane made anew takes the state full screen left, at its place. By hand: offscreen the page
    // under full screen does not change its size, so the pane does not go on the real way.
    function test_2u_c_new_pane_after_full_screen_data() {
        return [ { tag: "played there", playing: true }, { tag: "paused there", playing: false } ]
    }
    function test_2u_c_new_pane_after_full_screen(data) {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        const place = page.player.from + 2000
        page.started = true     // as openBig
        window.width = 700
        tryVerify(() => !page.split)
        page.bigResume = { position: place, rate: 1, looping: true, playing: data.playing }
        window.width = 1280
        tryVerify(() => page.player && page.player.duration > 0, mediaLoads)
        if (data.playing) {
            tryVerify(() => page.player.playing, mediaLoads, "plays on")
            verify(page.player.position >= place - 300, page.player.position)
            return
        }
        staysStanding(page.player, "paused there stays paused")
        verify(Math.abs(page.player.position - place) < 500, page.player.position)
    }

    // The real way, the pane alive: its state follows full screen, also through a turn after it.
    function test_2u_c_full_screen_state_follows_data() {
        return [ { tag: "played there", playing: true }, { tag: "paused there", playing: false } ]
    }
    function test_2u_c_full_screen_state_follows(data) {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        const place = page.player.from + 100000
        page.player.seek(place)
        tryVerify(() => Math.abs(page.player.position - place) < 500, 5000)
        page.openBig()
        const big = window.pageStack.currentItem
        tryVerify(() => big.big && big.playing, mediaLoads)
        tryVerify(() => Math.abs(big.position - place) < 3000, 3000, big.position + ", small player at " + place)
        if (!data.playing) {
            big.togglePlay()
            tryVerify(() => !big.playing)
        }
        const left = big.position
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem === page)
        tryVerify(() => page.player !== null)
        const check = () => {
            if (data.playing) {
                tryVerify(() => page.player.playing, mediaLoads, "plays on")
            } else {
                staysStanding(page.player, "paused there stays paused")
            }
            verify(page.player.position >= left - 500, page.player.position + " after " + left)
        }
        check()

        remakePane(page)
        tryVerify(() => page.player.duration > 0, mediaLoads)
        check()
    }

    // Left before its file loaded: full screen played nothing, so the small player stays as it was,
    // at its place (far inside the chapter: a run from the start cannot reach it in time).
    function test_2u_c_full_screen_left_while_loading_data() {
        const back = () => window.pageStack.goBack()
        const button = big => findChild(big, "railBack").clicked()
        return [ { tag: "playing, back", playing: true, leave: back },
                 { tag: "playing, button", playing: true, leave: button },
                 { tag: "standing, back", playing: false, leave: back },
                 { tag: "standing, button", playing: false, leave: button } ]
    }
    function test_2u_c_full_screen_left_while_loading(data) {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 0)
        const place = page.player.from + 100000
        page.player.seek(place)
        tryVerify(() => Math.abs(page.player.position - place) < 1000, 5000)
        if (!data.playing) {
            page.player.pause()
            tryVerify(() => !page.player.playing)
        }

        page.openBig()
        data.leave(window.pageStack.currentItem)
        tryVerify(() => window.pageStack.currentItem === page)
        if (data.playing) {
            tryVerify(() => page.player.playing, 5000, "plays on")
        } else {
            staysStanding(page.player, "stood, stays standing")
        }
        tryVerify(() => Math.abs(page.player.position - place) < 3000, 3000, page.player.position + ", was at " + place)
    }

    // Full screen from a pane still loading: the place that pane is going to.
    function test_2u_c_full_screen_from_loading_pane() {
        const page = tabletProgramme()
        const place = page.player.from + 100000
        page.player.startAt = place
        page.openBig()
        compare(window.pageStack.currentItem.startAt, place)
    }

    // Saved while the file loads: the place a pane still has to go to, not the file's start.
    // Stand-ins never finish loading, so the second turn always falls into it.
    function test_2u_c_turned_twice_while_loading() {
        const page = tabletProgramme()
        const place = page.player.from + 5000
        page.player.startAt = place
        remakePane(page)
        compare(page.player.startAt, place, "once")
        remakePane(page)
        compare(page.player.startAt, place, "twice")
    }

    // A place belongs to its technique: chosen while the pane loads, the next starts at its chapter.
    function test_2u_c_place_ends_with_technique() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        page.player.seek(100000)
        tryVerify(() => Math.abs(page.player.position - 100000) < 1000, 5000)
        remakePane(page)
        page.grade = "k4"
        tryVerify(() => page.player.video === "aikido/k4" && page.player.duration > 0, mediaLoads)
        wait(300)
        verify(page.player.position < page.player.from + 1000, page.player.position + ", chapter at " + page.player.from)
    }

    // A file changed while no pane stood: the pane waits at the chapter's start, as an open player.
    function test_2u_c_new_file_waits_data() {
        return [ { tag: "from the pane", big: false }, { tag: "from full screen", big: true } ]
    }
    function test_2u_c_new_file_waits(data) {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        Videos.folder = clipFolder("long2")
        if (data.big) {
            page.bigResume = { position: 210000, rate: 1, looping: true, playing: true }
        }
        window.width = 1280
        window.height = 800
        tryVerify(() => page.split && page.player && page.player.duration > 0, mediaLoads)
        staysStanding(page.player, "waits for a tap")
        verify(Math.abs(page.player.position - page.player.from) < 500, page.player.position)
    }

    // The loop stays as it was set on a pane made anew.
    function test_2u_c_new_pane_keeps_loop() {
        const page = tabletProgramme()
        page.player.looping = false
        remakePane(page)
        compare(page.player.looping, false)

        // Another technique chosen while no pane stood: as in a live pane.
        window.width = 700
        tryVerify(() => !page.split)
        page.grade = "k4"
        window.width = 1280
        tryVerify(() => page.split && page.player, paneLoads)
        compare(page.player.video, "aikido/k4")
        compare(page.player.looping, false, "another technique")
    }

    // A save while another technique's file loads is no file changed under it either.
    function test_2u_b_save_while_next_loads() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        page.grade = "k4"
        Videos.folderChanged()
        tryVerify(() => page.player.video === "aikido/k4" && page.player.playing, mediaLoads, "plays on")
    }

    // The chosen row, tapped when it stands: it plays.
    function test_2u_d_chosen_row_plays() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        page.player.pause()
        tryVerify(() => !page.player.playing)
        page.open(page.playlist[1])
        tryVerify(() => page.player.playing, 5000, "the tap plays it")
        page.open(page.playlist[1])
        wait(100)
        verify(page.player.playing, "playing: the tap leaves it")
    }

    // After the first tap a standing video stands through chips and cards until a technique is
    // chosen; a playing one plays on.
    function test_2u_e_grades_keep_standing_data() {
        return [ { tag: "another grade", discipline: "aikido", from: "k5", to: "k4", card: false },
                 { tag: "the grade card", discipline: "shinkitoho", from: "chuden", to: "kaiden", card: true } ]
    }
    function test_2u_e_grades_keep_standing(data) {
        const page = tabletProgramme(clipFolder("long"), data.discipline, data.from)
        chapterLoaded(page)
        rowPlays(page, 1)
        const chosen = page.player.current.id
        const at = pausedInside(page.player)

        chooseGrade(page, data.to)
        if (data.card) {
            tryVerify(() => !page.split)
            chooseGrade(page, data.from)
            tryVerify(() => page.split && page.player, paneLoads)
            compare(page.player.current.id, chosen)
        } else {
            tryVerify(() => page.player.current.id !== chosen)
        }
        tryVerify(() => page.player.duration > 0, mediaLoads)
        staysStanding(page.player, "stands until a technique is chosen")
        if (data.card) {
            verify(Math.abs(page.player.position - at) < 500, page.player.position + " after " + at)
        }

        // Chosen: it plays, and playing it stays playing through the same way.
        rowPlays(page, page.playlist.findIndex(r => r.id === page.player.current.id))
        chooseGrade(page, data.card ? data.to : data.from)
        if (data.card) {
            tryVerify(() => !page.split)
            chooseGrade(page, data.from)
            tryVerify(() => page.split && page.player, paneLoads)
        }
        tryVerify(() => page.player.playing, mediaLoads, "playing plays on")
        Programme.discipline = "aikido"
    }

    // Row 3 at 0.5×, the card, back: row 3 at 0.5×.
    function test_2u_f_card_keeps_technique() {
        const page = tabletProgramme(standInVideos, "shinkitoho", "chuden")
        page.open(page.playlist[2])
        const chosen = page.player.current.id
        page.player.setSpeed(0.5)

        chooseGrade(page, "kaiden")
        tryVerify(() => !page.split)
        compare(page.lastId, chosen)
        chooseGrade(page, "chuden")
        tryVerify(() => page.split && page.player, paneLoads)
        compare(page.player.current.id, chosen)
        compare(page.lastId, chosen)
        compare(page.player.rate, 0.5)
        Programme.discipline = "aikido"
    }

    // Another list in the pane: the technique shown last if it is in it, else the first; no row
    // of the new list at the old place on the way (it would become the chosen one).
    function test_2u_f_grade_starts_at_its_first() {
        const page = tabletProgramme(standInVideos)
        page.open(page.playlist[2])
        const seen = []
        const see = id => seen.push(id)
        page.player.shown.connect(see)
        chooseGrade(page, "k4")
        page.player.shown.disconnect(see)
        compare(page.player.index, 0)
        compare(page.lastId, page.playlist[0].id)
        compare(seen, [page.playlist[0].id])
    }

    // A tempo left on a technique does not come back after another was shown.
    function test_2u_g_old_tempo_stays_gone() {
        const page = tabletProgramme(standInVideos, "shinkitoho", "chuden")
        const first = page.playlist[0].id
        page.player.setSpeed(0.25)

        chooseGrade(page, "kaiden")
        tryVerify(() => !page.split)
        chooseGrade(page, "shoden")
        tryVerify(() => page.split && page.player, paneLoads)
        compare(page.player.rate, 1)
        chooseGrade(page, "chuden")
        compare(page.player.current.id, first)
        compare(page.player.rate, 1)

        remakePane(page, 700, 800)
        compare(page.player.current.id, first)
        compare(page.player.rate, 1, "not the tempo left before")
        Programme.discipline = "aikido"
    }

    // Without a video in the grade the sheet stands beside the list, no dialog: the first technique,
    // then the row chosen. Turned, the chosen sheet stays open, as a dialog upright.
    function test_2v_a_sheet_beside_the_list() {
        useFolder(clipFolder("gone"))
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.twoPanes)
        verify(!page.split, "no player without a video")

        const entries = page.rows.filter(r => r.kind === "entry")
        compare(page.paneEntry.id, entries[0].id)
        tryVerify(() => findChild(page, "paneSheet"))
        const body = findChild(page, "paneSheet")
        compare(body.entry.id, entries[0].id)
        verify(findChild(body, "sheetTitle").visible, "the name stands in every style")
        verify(findChild(body, "sheetNoVideo").visible)
        verify(!findChild(body, "sheetClose").visible, "nothing to close beside the list")
        verify(!findChild(page, "playerPane").visible)
        shot("2v-sheet-beside-the-list")

        const dialog = findChild(page, "techniqueSheet")
        page.open(entries[1])
        compare(page.paneEntry.id, entries[1].id)
        compare(body.entry.id, entries[1].id)
        verify(!dialog.visible, "no dialog over the list")

        window.width = 800
        window.height = 1280
        tryVerify(() => dialog.opened)
        compare(dialog.entry.id, entries[1].id)
        compare(page.paneEntry, null)

        window.width = 1280
        window.height = 800
        tryVerify(() => !dialog.visible)
        compare(page.paneEntry.id, entries[1].id)
    }

    // A row without a video among rows with one: the sheet takes the pane, the player waits under
    // it without a sound, its place and tempo kept; its row brings it back. Another grade drops
    // the sheet.
    function test_2v_b_sheet_over_the_player() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 1)
        page.player.setSpeed(0.5)

        const withoutVideo = Object.assign({}, page.playlist[3], { video: null })
        page.open(withoutVideo)
        compare(page.paneEntry.id, withoutVideo.id)
        tryVerify(() => !page.player.playing)
        verify(!findChild(page, "playerPane").visible)
        verify(!page.player.autoPlay, "nothing starts under the sheet")
        staysStanding(page.player, "hidden, no sound")
        const place = page.player.position

        page.open(page.playlist[1])
        compare(page.paneEntry, null)
        verify(findChild(page, "playerPane").visible)
        tryVerify(() => page.player.playing && page.player.position >= place, mediaLoads)
        compare(page.player.rate, 0.5)

        page.open(withoutVideo)
        tryVerify(() => !page.player.playing)
        chooseGrade(page, "k4")
        chooseGrade(page, "k5")
        tryVerify(() => page.split && page.player, paneLoads)
        compare(page.paneEntry, null)
        compare(page.sheetId, "")
        staysStanding(page.player, "a chip starts nothing")
    }

    // The tablet sizes: discipline and grades with the rows, the player's parts as in the
    // clickdummy, all of it inside the pane without scrolling.
    function test_2v_c_tablet_layout_data() {
        // 1920×1080: under Shinki the controls once scrolled 7 px there (Review #64).
        return [ { tag: "1920x1080", width: 1920, height: 1080 }, { tag: "1280x800", width: 1280, height: 800 },
                 { tag: "1024x768", width: 1024, height: 768 } ]
    }
    function test_2v_c_tablet_layout(data) {
        const page = tabletProgramme()
        window.width = data.width
        window.height = data.height
        tryVerify(() => page.split && page.player, paneLoads)
        verify(!page.header.visible, "no head above both panes")
        verify(page.inside(findChild(page, "gradeChips"), findChild(page, "programmeList")), "the grades scroll with the rows")

        const view = page.player
        tryVerify(() => view.paneColumns)
        wait(100)
        const edges = name => {
            const item = findChild(view, name)
            verify(item && item.visible, name)
            const at = item.mapToItem(null, 0, 0)
            return { left: at.x, top: at.y, right: at.x + item.width, bottom: at.y + item.height }
        }
        const bar = edges("transportBar")
        verify(edges("panePrevious").right <= bar.left + 0.5, "previous before the bar")
        verify(edges("paneNext").left >= bar.right - 0.5, "next after the bar")
        const sound = edges("soundSwitch")
        verify(sound.left >= edges("paneNext").right - 0.5, "the switches after them")
        verify(sound.right <= data.width + 0.5, "inside the window: " + sound.right)
        verify(edges("awakeSwitch").top >= sound.bottom - 0.5, "one below the other")

        const rating = edges("ratingRow")
        const note = edges("noteField")
        verify(rating.right <= note.left + 0.5, "two columns")
        verify(note.right <= data.width + 0.5, "inside the window: " + note.right)
        verify(rating.top >= bar.bottom - 0.5, "below the bar")
        verify(edges("paneTitle").bottom <= rating.top + 0.5, "the name above the rating")
        verify(edges("railTitle").top >= edges("stage").top, "the name on the picture")
        verify(!findChild(view, "neighbourRow").visible, "neighbours only once")
        verify(!findChild(view, "compactTitle").visible, "the name once below the picture")

        const controls = findChild(view, "controlsView")
        verify(controls.contentHeight <= controls.height + 0.5, controls.contentHeight + " in " + controls.height)
        const stage = findChild(view, "stage")
        verify(stage.height >= Math.min(view.height / 2, stage.width / stage.ratio) - 0.5, "the picture at least half, or all of it")
        shot("2v-tablet-" + data.tag)

        // The longest word on the switches: still inside, still no scrolling.
        view.setSpeed(0.5)
        wait(100)
        verify(edges("soundSwitch").right <= data.width + 0.5, "slow motion: " + edges("soundSwitch").right)
        verify(controls.contentHeight <= controls.height + 0.5, controls.contentHeight + " in " + controls.height)
    }

    // A pane too narrow for columns (a small tablet window) keeps the one column.
    function test_2v_d_narrow_pane() {
        const page = tabletProgramme()
        window.width = 760
        window.height = 560
        tryVerify(() => page.split && page.player && !page.player.paneColumns)
        verify(findChild(page.player, "compactTitle").visible)
        verify(!findChild(page.player, "railTitle").visible, "the name once")
        verify(!findChild(page.player, "panePrevious").visible)
        verify(findChild(page.player, "neighbourRow").visible)
    }

    // Upright a tablet has the phone's layout: grades above the list, the sheet as a dialog.
    function test_2v_e_tablet_upright() {
        const page = tabletProgramme()
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.twoPanes)
        tryVerify(() => page.header.visible && page.header.implicitHeight > 0)
        verify(!page.inside(findChild(page, "gradeChips"), findChild(page, "programmeList")))
        const scroll = findChild(page, "programmeScroll")
        tryCompare(scroll, "width", page.width)
        page.open(page.rows.find(r => r.kind === "entry"))
        const dialog = findChild(page, "techniqueSheet")
        tryVerify(() => dialog.opened)
        compare(page.sheetId, "")
        shot("2v-tablet-upright", true)
        dialog.close()
        tryVerify(() => !dialog.visible)
    }

    // The chips scroll with the rows: opening the page or tapping a chip leaves them in view, even
    // when the technique shown stands further down (it failed so under Shinki, list 192 px down).
    function test_2v_g_chips_stay_in_view() {
        const page = tabletProgramme(standInVideos, "shinkitoho", "chuden")
        const list = findChild(page, "programmeList")
        wait(300)
        compare(list.contentY, list.originY, "opened at the top")
        chooseGrade(page, "shoden")
        wait(300)
        compare(list.contentY, list.originY, "a chip stays at the top")
        Programme.discipline = "aikido"
    }

    // By keyboard the chips are in reach and in view: Shift+Tab from the first row reaches them,
    // and focus coming to them from above takes the scrolled list back to its top.
    function test_2v_i_chips_by_keyboard() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k3")
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.wide)
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 5000)
        wait(800)
        const list = findChild(page, "programmeList")
        const inHead = item => {
            for (let p = item; p; p = p.parent) {
                if (p === list.headerItem) {
                    return true
                }
            }
            return false
        }
        list.positionViewAtBeginning()
        wait(100)
        let first = 0
        while (!(list.itemAtIndex(first) && list.itemAtIndex(first).entry)) {
            first++
        }
        list.itemAtIndex(first).forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Backtab)
        verify(inHead(window.activeFocusItem), "Shift+Tab on the first row: " + window.activeFocusItem)
        // Past what else the head holds (the hint about the DVD's code), back to a chip.
        for (let n = 0; n < 5 && !window.activeFocusItem.checkable; n++) {
            keyClick(Qt.Key_Backtab)
        }
        const chip = window.activeFocusItem
        verify(inHead(chip) && chip.checkable, "a chip: " + chip)

        // Scrolled down, the focus comes to a chip from outside the list.
        list.positionViewAtEnd()
        wait(200)
        verify(chip.mapToItem(list, 0, 0).y < 0, "scrolled past the chips")
        const head = list.headerItem
        head.nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
        verify(!inHead(window.activeFocusItem))
        keyClick(Qt.Key_Tab)
        const entered = window.activeFocusItem
        verify(inHead(entered), "Tab from above: " + entered)
        tryVerify(() => {
            const top = entered.mapToItem(list, 0, 0).y
            return top >= 0 && top + entered.height <= list.height
        }, 2000, "the head in view")

        // Focus that only comes back moves nothing: a page over it, then gone.
        chip.forceActiveFocus(Qt.TabFocusReason)
        list.positionViewAtEnd()
        wait(200)
        const scrolled = list.contentY
        verify(scrolled > list.originY + 100, "scrolled " + scrolled)
        push("AllNotesPage")
        wait(800)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        wait(500)
        verify(inHead(window.activeFocusItem), "the focus is back on the chip: " + window.activeFocusItem)
        compare(list.contentY, scrolled, "the list stays where it was")
        PracticeGrade.setGrade("aikido", "k5")
        popPage()
    }

    // A sheet left beside the list, turned under another page: the dialog of a technique with a
    // video, turned back, shows the player, not the old sheet over it.
    function test_2v_h_old_sheet_stays_gone() {
        const page = tabletProgramme()
        page.open(Object.assign({}, page.playlist[3], { video: null }))
        compare(page.paneEntry.id, page.playlist[3].id)
        push("SearchPage")
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.wide)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)

        const dialog = findChild(page, "techniqueSheet")
        const chosen = page.playlist[1]
        page.open(chosen)
        tryVerify(() => dialog.opened)
        window.width = 1280
        window.height = 800
        tryVerify(() => !dialog.visible && page.split && page.player)
        compare(page.lastId, chosen.id)
        compare(page.paneEntry, null, "the old sheet does not cover the player")
        verify(findChild(page, "playerPane").visible)
    }

    // The dialog of the last technique, turned sideways: the list shows its row, with a video in
    // the player and without one as the sheet.
    function test_2v_i_turned_row_in_view_data() {
        return [ { tag: "with video", folder: standInVideos, inPane: false }, { tag: "without video", folder: clipFolder("gone"), inPane: true } ]
    }
    function test_2v_i_turned_row_in_view(data) {
        useFolder(data.folder)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        window.width = 800
        window.height = 1280
        const page = push("ProgrammePage")
        const list = findChild(page, "programmeList")
        tryVerify(() => list.count > 0)
        wait(700)       // the head has settled: nothing holds the list at its top
        list.positionViewAtEnd()
        const entries = page.rows.filter(r => r.kind === "entry")
        const chosen = entries[entries.length - 1]
        page.open(chosen)
        const dialog = findChild(page, "techniqueSheet")
        tryVerify(() => dialog.opened)

        window.width = 1280
        window.height = 800
        tryVerify(() => !dialog.visible && page.twoPanes)
        compare(!!page.paneEntry, data.inPane)
        const row = page.rows.findIndex(r => r.id === chosen.id)
        tryVerify(() => {
            const item = list.itemAtIndex(row)
            if (!item) {
                return false
            }
            const at = item.mapToItem(list, 0, 0)
            return at.y >= -0.5 && at.y + item.height <= list.height + 0.5
        }, 3000, "row " + row + " in view")
    }

    // The on-screen keyboard shrinks the window below a tablet's height: from the moment a note is
    // typed the small player and its field stay until the window is high again, also when a tap
    // takes the focus from the field while the keyboard is still open. Afterwards a low window is
    // no tablet again. The keyboard itself is only a lower window here, not a device's.
    function lowWithNote(page) {
        const field = findChild(page.player, "noteField")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        window.height = 400
        tryVerify(() => page.height < 460)
        wait(100)
        return field
    }
    function test_2v_j_keyboard_keeps_note_field() {
        const page = tabletProgramme()
        const player = page.player
        const field = lowWithNote(page)
        verify(page.split, "the pane stays")
        compare(page.player, player, "not made anew")
        verify(field.activeFocus, "the keyboard stays open")

        window.height = 800
        tryVerify(() => page.height >= 460)
        verify(field.activeFocus)
    }
    function test_2v_j_keyboard_add_note() {
        const page = tabletProgramme()
        const player = page.player
        const field = lowWithNote(page)
        const entry = player.current.id
        const before = Practice.notes(entry).length
        field.text = "am Mattenrand"
        const add = findChild(player, "addNote")
        tryVerify(() => add.enabled)
        mouseClick(add)
        tryCompare(field, "text", "")
        compare(Practice.notes(entry).length, before + 1)
        wait(100)
        verify(page.split, "the pane stays with the keyboard open")
        compare(page.player, player, "not made anew")
        Practice.notes(entry).forEach(n => Practice.deleteNote(n.uid))  // later cases count from none

        // The keyboard closes, the hold ends: a low window is no tablet.
        page.forceActiveFocus()
        window.height = 800
        tryVerify(() => page.height >= 460)
        window.height = 400
        tryVerify(() => !page.split, 2000)
    }
    function test_2v_j_keyboard_other_row_plays() {
        const page = tabletProgramme(clipFolder("long"))
        chapterLoaded(page)
        rowPlays(page, 0)       // the first tap
        const player = page.player
        lowWithNote(page)

        const chosen = page.playlist[1]
        const row = page.rows.findIndex(r => r.id === chosen.id)
        const list = findChild(page, "programmeList")
        list.positionViewAtIndex(row, ListView.Contain)
        tryVerify(() => list.itemAtIndex(row))
        wait(100)
        mouseClick(list.itemAtIndex(row), 20, 10)

        verify(!findChild(page, "techniqueSheet").visible, "no dialog")
        verify(page.split)
        compare(page.player, player, "not made anew")
        compare(player.current.id, chosen.id)
        tryVerify(() => player.playing && player.position > player.from + 300, mediaLoads, "it plays right away")
    }

    // The hold ends with the player: no field, no pane, no hold.
    function test_2v_k_hold_ends_with_player_data() {
        return [
            { tag: "turned upright", away: page => {
                window.width = 800
                window.height = 1280
                tryVerify(() => !page.player)
                window.width = 1280
                window.height = 800
            } },
            { tag: "grade card", away: page => {
                page.grade = "kaiden"
                tryVerify(() => !page.player)
                tryVerify(() => !page.wide, 2000, "no player, no hold: still the low window")
                window.height = 800
                page.grade = "chuden"
            } }
        ]
    }
    function test_2v_k_hold_ends_with_player(data) {
        const page = tabletProgramme(standInVideos, "shinkitoho", "chuden")
        lowWithNote(page)
        data.away(page)
        tryVerify(() => page.height >= 460 && page.split && page.player)

        page.forceActiveFocus()
        window.height = 400
        tryVerify(() => !page.split, 2000, "no field in focus: a low window is no tablet")
        Programme.discipline = "aikido"
    }

    // The dialog of a technique with a video, open when the tablet turns sideways: its technique
    // stands in the player, also after the first tap; turning starts nothing.
    function test_2v_f_dialog_turned_sideways() {
        const page = tabletProgramme(clipFolder("long"))
        page.open(page.playlist[0])     // the first tap
        tryVerify(() => page.player.playing, mediaLoads)
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        const dialog = findChild(page, "techniqueSheet")
        const chosen = page.playlist[2]
        page.open(chosen)
        tryVerify(() => dialog.opened)

        window.width = 1280
        window.height = 800
        tryVerify(() => !dialog.visible && page.split && page.player)
        compare(page.paneEntry, null)
        compare(page.lastId, chosen.id)
        compare(page.player.current.id, chosen.id)
        tryVerify(() => page.player.duration > 0, mediaLoads)
        staysStanding(page.player, "turned, no sound by itself")
    }

    // Opening the programme is silent: the first tap starts, and from then on a row plays at once.
    function test_2t_a_stands_until_first_tap_data() {
        return [
            { tag: "play control", tap: page => findChild(page.player, "transportBar").playToggled(), at: 0 },
            { tag: "picture or key", tap: page => page.player.togglePlay(), at: 0 },
            { tag: "row", tap: page => page.open(page.playlist[1]), at: 1 },
            { tag: "the row standing there", tap: page => page.open(page.playlist[0]), at: 0 },
            { tag: "row's play button", tap: page => page.play(page.playlist[1]), at: 1 }
        ]
    }
    function test_2t_a_stands_until_first_tap(data) {
        const page = tabletProgramme()
        compare(page.player.index, 0)
        verify(!page.player.autoPlay, "opening the page starts nothing")

        data.tap(page)
        verify(page.player.autoPlay, "the first tap starts")
        compare(page.player.current.id, page.playlist[data.at].id)
        compare(window.pageStack.currentItem, page)

        // Under another page it rests, and the started state outlives that.
        push("SearchPage")
        tryVerify(() => !page.player.autoPlay)
        popPage()
        tryVerify(() => page.player.autoPlay)
        popPage()

        // The next opening stands again.
        const again = tabletProgramme()
        verify(!again.player.autoPlay)
    }

    // Moving on is no first tap (only the list and the play control are); pausing takes nothing back.
    function test_2t_b_next_stays_standing() {
        const page = tabletProgramme()
        page.player.go(1)
        compare(page.player.current.id, page.playlist[1].id)
        verify(!page.player.autoPlay)
        page.open(page.playlist[2])
        verify(page.player.autoPlay)
        page.player.pause()
        verify(page.player.autoPlay)
    }

    // Turning the tablet makes the pane anew: standing stays standing, started stays started.
    function test_2t_c_turning_keeps_the_start() {
        const page = tabletProgramme()
        const turn = () => {
            window.width = 800
            window.height = 1280
            tryVerify(() => !page.split)
            window.width = 1280
            window.height = 800
            tryVerify(() => page.split && page.player, paneLoads)
        }
        turn()
        verify(!page.player.autoPlay)
        page.open(page.playlist[1])
        turn()
        verify(page.player.autoPlay)
        compare(page.player.current.id, page.playlist[1].id)
    }

    // Upright no pane stands: a technique opens the player page at once.
    function test_2t_d_upright_opens_the_player() {
        const page = tabletProgramme()
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        page.play(page.playlist[0])
        tryVerify(() => window.pageStack.currentItem !== page)
        compare(window.pageStack.currentItem.current.id, page.playlist[0].id)
    }

    // With a video to play: it stands at the chapter start, and the first tap makes it run.
    function test_2t_e_first_tap_plays() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length < 2 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        window.width = 1280
        window.height = 800
        let page = push("ProgrammePage")
        tryVerify(() => page.player && page.player.duration > 0, 5000)
        wait(500)
        verify(!page.player.playing, "opening makes no sound")
        verify(Math.abs(page.player.position - page.player.from) < 500, page.player.position)
        findChild(page.player, "transportBar").playToggled()
        tryVerify(() => page.player.playing, 5000)
        page.open(page.playlist[1])
        tryCompare(page.player.current, "id", page.playlist[1].id, 3000)
        tryVerify(() => page.player.playing && page.player.position >= page.player.from, 5000)
        popPage()

        // The row standing there.
        page = push("ProgrammePage")
        tryVerify(() => page.player && page.player.duration > 0, 5000)
        verify(!page.player.playing)
        page.open(page.playlist[0])
        tryVerify(() => page.player.playing, 5000)
        popPage()
    }

    // Tablet in landscape: list and small player on one page; a row with a video plays beside the
    // list, the player moving on marks its row.
    function test_2t_tablet() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length < 2 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.split, 2000, "list and player side by side")
        const pane = findChild(page, "playerPane")
        tryVerify(() => pane.item && pane.item.duration > 0, mediaLoads)
        page.open(rows[0])      // the first tap
        tryVerify(() => pane.item.playing, mediaLoads)
        compare(pane.item.compact, true)
        // A row with a video plays beside the list, the page stays.
        page.open(rows[1])
        tryCompare(pane.item.current, "id", rows[1].id, 3000)
        compare(window.pageStack.currentItem, page)
        compare(page.lastId, rows[1].id)
        // The player moves on: its row is marked, and the list shows it.
        pane.item.go(1)
        tryCompare(page, "lastId", page.playlist[pane.item.index].id)
        const list = findChild(page, "programmeList")
        pane.item.index = page.playlist.length - 1
        tryCompare(page, "lastId", page.playlist[page.playlist.length - 1].id)
        const row = page.rows.findIndex(r => r.id === page.lastId)
        tryVerify(() => {
            const first = list.indexAt(10, list.contentY + 5), last = list.indexAt(10, list.contentY + list.height - 5)
            return first >= 0 && first <= row && (last < 0 || last >= row)
        }, 2000, "the list scrolled to the playing row")
        shot("2t-tablet")
        // Turned to portrait and back: the chosen technique stays.
        page.open(page.playlist[3])
        tryCompare(pane.item.current, "id", page.playlist[3].id, 3000)
        const chosen = page.playlist[3].id
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        window.width = 1280
        window.height = 800
        tryVerify(() => pane.item && pane.item.current.id === chosen, 3000, "still " + chosen)
        compare(page.lastId, chosen)
        // Another grade: its first technique plays, not the same place in another list.
        PracticeGrade.setGrade("aikido", "k4")
        page.grade = "k4"
        tryVerify(() => pane.item && pane.item.current.id === page.playlist[0].id, 3000)
        compare(page.lastId, page.playlist[0].id)
        // A phone in landscape is no tablet: no split, ▶ opens the player page.
        window.width = 915
        window.height = 412
        tryVerify(() => !page.split, 2000, "phone landscape")
        window.width = 420
        window.height = 800
        tryVerify(() => !page.split)
        PracticeGrade.setGrade("aikido", "k5")
        popPage()
    }

    // Tablet: a technique with a comment (Shinki Toho) shows the way to it beside the player.
    function test_2u_tablet_comment() {
        const grade = Programme.grades("shinkitoho")[0].id
        const rows = Programme.entries("shinkitoho", grade).filter(r => r.kind === "entry" && r.video && r.comment)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Shinki Toho (set MITORI_VIDEOS)")
        }
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", grade)
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.split)
        page.open(rows[0])
        const pane = findChild(page, "playerPane")
        tryCompare(pane.item.current, "id", rows[0].id, 3000)
        const button = findChild(pane.item, "commentButton")
        verify(button && button.visible, "comment beside the player")
        button.clicked()
        tryVerify(() => window.pageStack.currentItem !== page, 2000)
        compare(window.pageStack.currentItem.entry.id, rows[0].id)
        tryVerify(() => !pane.item.playing, 2000, "the player pauses under another page")
        // Turned under the comment: the player made anew stays quiet.
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        window.width = 1280
        window.height = 800
        tryVerify(() => pane.item && pane.item.duration > 0, mediaLoads)
        wait(500)
        verify(!pane.item.playing, "no sound under the comment page")
        popPage()
        window.width = 420
        window.height = 800
        popPage()
        Programme.discipline = "aikido"
    }

    // Tablet: the Kamae exercise plays beside the list, with its 26 positions under the player.
    function test_2u_tablet_kamae() {
        failOnWarning(/ReferenceError|TypeError/)
        const kamae = Programme.entry("shinkitoho/kamae")
        if (!kamae.video || !Videos.available(kamae.video.video)) {
            skip("no video for the Kamae exercise (set MITORI_VIDEOS)")
        }
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        window.width = 1280
        window.height = 800
        const page = push("ProgrammePage")
        tryVerify(() => page.split)
        page.open(page.rows.find(r => r.id === "shinkitoho/kamae"))
        const pane = findChild(page, "playerPane")
        tryCompare(pane.item.current, "id", "shinkitoho/kamae", 3000)
        const list = findChild(pane.item, "stepList")
        verify(list && list.visible, "the positions beside the player")
        tryCompare(list, "count", 26)
        shot("2u-tablet-kamae")
        // A form has none.
        page.open(page.playlist.find(r => r.id.startsWith("shinkitoho/odachi/")))
        tryVerify(() => pane.item.current.id.startsWith("shinkitoho/odachi/"), 3000)
        verify(!findChild(pane.item, "stepList").visible)
        window.width = 420
        window.height = 800
        popPage()
        Programme.discipline = "aikido"
    }

    // Tablet in landscape: the start menu as a bento of four columns. The programme tile takes two
    // columns and two rows at the top left, today's practice two columns beside it, the exam and the
    // statistics below that; then four to a row.
    function test_1b_start_tablet() {
        const start = window.pageStack.items[0]
        window.width = 1280
        window.height = 800
        const tiles = findChild(start, "tiles")
        tryCompare(tiles, "columns", 4)
        wait(200)
        const at = n => findChild(start, n).mapToItem(tiles, 0, 0)
        const programme = findChild(start, "programmeTile")
        const small = findChild(start, "examTile")
        compare(at("programmeTile").x, 0)
        compare(at("programmeTile").y, 0)
        verify(Math.abs(at("todayTile").y) < 1, "today beside the programme tile")
        verify(Math.abs(at("todayTile").x - (programme.width + tiles.columnSpacing)) < 1, "today right of it")
        const row2 = ["examTile", "statsTile"].map(at)
        verify(row2[0].y > 0 && Math.abs(row2[0].y - row2[1].y) < 1, "exam and statistics in a row")
        verify(Math.abs(row2[0].x - at("todayTile").x) < 1 && row2[1].x > row2[0].x, "under today's practice")
        const row3 = ["coursesTile", "mapTile", "glossaryTile", "notesTile"].map(at)
        for (let i = 0; i < 4; ++i) {
            verify(Math.abs(row3[i].y - row3[0].y) < 1, "tile " + i + " in the last row")
            verify(row3[i].y >= programme.height - 1, "below the programme tile")
            if (i)
                verify(row3[i].x > row3[i - 1].x, "tile " + i + " right of the one before")
        }
        compare(findChild(start, "notesTile").width, small.width)
        shot("1b-start-tablet")
        window.width = 420
        window.height = 800
        tryCompare(tiles, "columns", 2)      // two columns on the phone (the clickdummy)
    }

    // "Continue with" on the programme tile is a control: it takes the focus (Tab), Enter opens the
    // technique, a screen reader hears what it leads to.
    function test_1b_continue_is_a_control() {
        const start = window.pageStack.items[0]
        const next = findChild(start, "nextTechnique")
        tryVerify(() => next.visible)
        compare(next.focusPolicy, Qt.StrongFocus)
        verify(next.Accessible.name.indexOf(qsTr("Continue with")) === 0, next.Accessible.name)
        verify(next.Accessible.name.length > qsTr("Continue with").length + 2, next.Accessible.name)
        next.forceActiveFocus(Qt.TabFocusReason)
        verify(next.visualFocus)
        keyClick(Qt.Key_Return)
        tryCompare(window.pageStack, "depth", 2)
        popPage()
    }

    // The programme tile is always twice as wide and twice as high as the others (plus the gap
    // between two cells), at every width; each tile's value is there.
    function test_1b_bento_sizes_data() {
        return [ { tag: "1280x800", width: 1280, height: 800 }, { tag: "800x1280", width: 800, height: 1280 },
                 { tag: "420x860", width: 420, height: 860 }, { tag: "360x640", width: 360, height: 640 } ]
    }
    function test_1b_bento_sizes(data) {
        window.width = data.width
        window.height = data.height
        const start = window.pageStack.items[0]
        const tiles = findChild(start, "tiles")
        const names = ["programmeTile", "todayTile", "examTile", "statsTile", "coursesTile", "mapTile", "glossaryTile", "notesTile"]
        tryVerify(() => names.every(n => findChild(start, n).filled), 5000, "every tile has its value")
        wait(100)
        const gap = tiles.columnSpacing
        const programme = findChild(start, "programmeTile")
        const where = data.tag + ": "
        for (const n of names.slice(2)) {
            const t = findChild(start, n)
            verify(Math.abs(programme.width - (2 * t.width + gap)) <= 1, where + n + " is half as wide: " + t.width + " of " + programme.width)
            verify(Math.abs(programme.height - (2 * t.height + gap)) <= 1, where + n + " is half as high: " + t.height + " of " + programme.height)
        }
        const today = findChild(start, "todayTile")
        verify(Math.abs(today.width - programme.width) <= 1, where + "today's practice as wide as the programme tile")
        verify(Math.abs(2 * today.height + gap - programme.height) <= 1, where + "today's practice is a row high")
        shot("1b-bento-" + data.tag)
    }

    // The keyboard scrolls the programme list (Down, Page Down).
    function test_2v_programme_keys() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k3")
        const page = push("ProgrammePage")
        const list = findChild(page, "programmeList")
        // Kirigami slides the page in (longer under load); a key during that is lost.
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 5000)
        wait(1500)
        page.forceActiveFocus()
        const before = list.contentY
        keyClick(Qt.Key_PageDown)
        tryVerify(() => list.contentY > before + 100, 2000, "Page Down")
        const after = list.contentY
        keyClick(Qt.Key_Down)
        tryVerify(() => list.contentY > after, 2000, "Down")
        wait(300)
        compare(Math.round(list.contentY - after), Kirigami.Units.gridUnit * 2, "Down scrolls two lines")
        keyClick(Qt.Key_Home)
        tryVerify(() => list.contentY <= list.originY + 1, 2000, "Home")
        // Also with a row in focus (after a click or Tab): the list scrolls, not a current index.
        let i = 0
        while (i < list.count && !(list.itemAtIndex(i) && list.itemAtIndex(i).entry))
            i++
        verify(i < list.count, "a technique row in view")
        list.itemAtIndex(i).forceActiveFocus()
        const y = list.contentY
        keyClick(Qt.Key_Down)
        tryVerify(() => list.contentY > y, 2000, "Down on a focused row")
        wait(300)
        compare(Math.round(list.contentY - y), Kirigami.Units.gridUnit * 2, "Down on a row scrolls two lines")
        // Tab goes from row to row down the whole list, each in view (a virtual list: the rows
        // below are made as it scrolls).
        list.positionViewAtBeginning()
        wait(100)
        let first = 0
        while (!(list.itemAtIndex(first) && list.itemAtIndex(first).entry))
            first++
        list.itemAtIndex(first).forceActiveFocus(Qt.TabFocusReason)
        const rowOf = item => {
            for (let p = item; p; p = p.parent)
                if (p.entry !== undefined && p.modelData !== undefined)
                    return p
            return null
        }
        const tabbable = page.rows.filter(r => r.kind === "entry" || r.kind === "info").map(r => r.id)
        let seen = [list.itemAtIndex(first).entry.id]
        for (let n = 0; n < tabbable.length + 5; n++) {
            keyClick(Qt.Key_Tab)
            wait(20)
            const row = rowOf(window.activeFocusItem)
            if (!row)
                break                                   // past the last row: out of the list
            const top = row.mapToItem(list, 0, 0).y
            verify(top >= -1 && top + row.height <= list.height + 1, "the row in view after Tab " + (n + 1) + " (" + top + ")")
            seen.push(row.entry.id)
        }
        compare(seen, tabbable, "Tab reaches every row once, in order, then leaves the list")
        // Shift+Tab from the last row goes back up.
        list.positionViewAtEnd()
        wait(100)
        const lastRow = list.itemAtIndex(page.rows.findIndex(r => r.id === tabbable[tabbable.length - 1]))
        lastRow.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_Backtab)
        compare(rowOf(window.activeFocusItem).entry.id, tabbable[tabbable.length - 2])
        // End reaches the end at the first press (rows of different heights: the list estimates
        // its height until it made the last ones; it stopped 6 px short).
        keyClick(Qt.Key_End)
        wait(300)
        verify(list.atYEnd, "End at the first press (" + list.contentY + ")")
        PracticeGrade.setGrade("aikido", "k5")
        popPage()
    }

    // Tablet: keys in the small player stay there (End does not scroll the list), and on a small
    // tablet the player's controls fit under the picture.
    function test_2w_tablet_player_keys() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length < 2 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        window.width = 1024
        window.height = 560
        const page = push("ProgrammePage")
        tryVerify(() => page.split, 2000, "a small tablet splits too")
        const pane = findChild(page, "playerPane")
        tryVerify(() => pane.item && pane.item.duration > 0, mediaLoads)
        const list = findChild(page, "programmeList")
        pane.item.forceActiveFocus()
        const y = list.contentY
        keyClick(Qt.Key_End)
        keyClick(Qt.Key_PageDown)
        wait(100)
        compare(list.contentY, y, "keys in the player leave the list alone")
        const controls = findChild(pane.item, "controlsView")
        const bar = findChild(pane.item, "transportBar")
        const bottom = bar.mapToItem(controls, 0, bar.height).y
        verify(bottom <= controls.height, "the transport bar in view (" + bottom + " of " + controls.height + ")")
        // Tab through the controls: the focused one stays in view.
        bar.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
        verify(controls.contentHeight > controls.height, "the controls scroll on a small tablet")
        for (let n = 0; n < 25; n++) {
            keyClick(Qt.Key_Tab)
            const f = window.activeFocusItem
            let inside = false
            for (let p = f; p; p = p.parent)
                inside = inside || p === controls
            if (!inside)
                break
            const top = f.mapToItem(controls, 0, 0).y
            verify(top >= -1 && top + Math.min(f.height, controls.height) <= controls.height + 1,
                   "focus in view after " + (n + 1) + " Tab (" + top + ", " + f.height + " of " + controls.height + ")")
        }
        // A large tablet keeps the whole picture: only as little height as the controls need
        // (16:10; at 1080 Shinki's taller head and controls leave them just over half).
        window.width = 1920
        window.height = 1200
        tryVerify(() => pane.item && pane.item.height > 900, 2000)
        const stage = findChild(pane.item, "stage")
        const controls2 = findChild(pane.item, "controlsView")
        tryVerify(() => Math.abs(stage.height - stage.width / stage.ratio) < 1
                         || Math.abs(controls2.contentHeight - controls2.height) < 1, 2000,
                  "picture " + stage.width + "×" + stage.height + ", controls " + controls2.contentHeight + " of " + controls2.height)
        verify(controls2.contentHeight <= controls2.height + 1, "the controls fit")
        popPage()
    }

    function findChildren(item, name) {
        let found = []
        if (item.objectName === name) {
            found.push(item)
        }
        for (let i = 0; i < item.children.length; i++) {
            found = found.concat(findChildren(item.children[i], name))
        }
        return found
    }

    // Photos and voice notes: a picked picture becomes a note with the text typed so far, shown
    // in the notes, the notebook and All notes; a voice note plays; the camera page says when
    // there is no camera (offscreen). Deleting a note deletes its file.
    MediaDevices {
        id: devices
    }

    function test_8f_photo_and_voice() {
        failOnWarning(/ReferenceError|TypeError|Binding loop/)
        const entry = Programme.entries("aikido", "k4").find(r => r.kind === "entry")
        const page = push("NotesPage", { entry: entry })
        const compose = findChild(page, "compose")
        compose.text = "Fußstellung"
        const name = Media.importPhoto("file://" + testMediaDir + "/foto.png")
        verify(name.endsWith(".jpg"), name)
        const media = findChild(page.footer, "noteMedia")
        media.attached(name)
        tryVerify(() => Practice.notes(entry.id).some(n => n.media === name))
        // A file that is no picture says so (and makes no note).
        const before = Practice.notes(entry.id).length
        media.importPicture("file://" + testMediaDir + "/README.md")
        tryVerify(() => media.problem.shown, 2000, "a message for an unreadable picture")
        compare(Practice.notes(entry.id).length, before)
        compare(compose.text, "", "the text went with the photo")
        tryVerify(() => findChildren(page, "notePhoto").some(i => i.visible && i.status === Image.Ready), 3000)
        shot("8f-note-photo")

        // A voice note without text: named as such, it plays.
        verify(Practice.addNote(entry.id, "", "test-stimme.m4a"))
        tryVerify(() => findChildren(page, "note").some(n => n.text === qsTr("Voice note")))
        const play = findChildren(page, "playVoice").find(b => b.visible)
        verify(play)
        wait(800)
        mouseClick(play)
        // Loaded, it shows its length ("Voice note 0:02"); playing, the button stops it.
        tryVerify(() => findChildren(page, "voiceLength").some(l => l.visible && /\d:\d\d$/.test(l.text)), 5000,
                  findChildren(page, "voiceLength").map(l => l.text).join(", "))

        // Without a camera the camera page says so (a machine with a webcam does not switch it on
        // for a test).
        if (devices.videoInputs.length === 0) {
            const camera = push("CameraPage")
            tryVerify(() => findChild(camera, "cameraError").visible, 3000)
            verify(!findChild(camera, "shutter").enabled)
            popPage()
        }

        // A file that is gone (a cloud backup leaves the media out) says so instead of an empty picture.
        verify(Practice.addNote(entry.id, "", "fehlt-" + name))
        tryVerify(() => findChildren(page, "mediaMissing").some(l => l.visible && l.text === qsTr("The photo is not on this device.")),
                  3000, "a missing photo is named")
        verify(Practice.deleteNote(Practice.notes(entry.id).find(n => n.media === "fehlt-" + name).uid))

        // All notes shows the photo too.
        const all = push("AllNotesPage")
        all.filter = ""
        tryVerify(() => findChildren(all, "notePhoto").some(i => i.visible))
        popPage()

        // Deleted, the photo's file goes.
        const photoNote = Practice.notes(entry.id).find(n => n.media === name)
        verify(Practice.deleteNote(photoNote.uid))
        const voiceNote = Practice.notes(entry.id).find(n => n.media === "test-stimme.m4a")
        verify(Practice.changeNote(voiceNote.uid, ""), "a voice note needs no text")
        popPage()

        // The sheet's "last note" names a voice note without text as such.
        Programme.discipline = "aikido"         // earlier cases leave another one chosen
        PracticeGrade.setGrade("aikido", "k4")
        const programme = push("ProgrammePage")
        programme.open(programme.rows.find(r => r.id === entry.id))
        const sheet = findChild(programme, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const last = findChild(sheet.contentItem, "sheetLastNote")
        verify(last.visible, "a voice note is a last note too")
        verify(last.text.endsWith(": " + qsTr("Voice note")), last.text)
        sheet.close()
        tryVerify(() => !sheet.opened)
        popPage()

        // A notebook entry with a photo.
        const course = Courses.create("Fotolehrgang", "2026-05-01", "", "", "")
        const book = push("CoursePage", { uid: course })
        findChild(book, "courseCompose").text = "Tafel"
        findChild(book, "courseMedia").attached(Media.importPhoto("file://" + testMediaDir + "/foto.png"))
        tryVerify(() => Courses.entries(course).length === 1 && Courses.entries(course)[0].media.endsWith(".jpg"))
        tryVerify(() => findChildren(book, "notePhoto").some(i => i.visible))
        // Exported as a ZIP (the file dialog is the platform's; the page's step after it).
        const target = "file://" + uiShotsDir + "/" + Courses.exportName(course)
        book.exportTo(target)
        tryVerify(() => findChild(book, "exportedTo").visible)
        verify(findChild(book, "exportedTo").text.indexOf(uiShotsDir) > 0, "says where: " + findChild(book, "exportedTo").text)
        verify(findChild(book, "exportedTo").text.indexOf("Fotolehrgang") > 0, findChild(book, "exportedTo").text)
        shot("14d-course-exported")
        popPage()
        verify(Courses.remove(course))
    }

    // The export sheet (owner, 6 Nov 2026): what goes out, the actions; at 360 px nothing past the
    // edge, not with a long name or a long word in the text. The desktop has no share dialog.
    function test_8e_export_sheet() {
        const w = window.width
        window.width = 360
        wait(100)
        const course = Courses.create("Sommerlehrgang mit einem sehr langen Namen, der umbrechen muss", "2026-05-01", "", "", "")
        verify(Courses.addEntry(course, "<b>Tenkan</b> https://example.org/" + "x".repeat(120)))
        verify(Courses.addEntry(course, "Tafel", Media.importPhoto("file://" + testMediaDir + "/foto.png")))
        const book = push("CoursePage", { uid: course })
        book.actions.find(a => a.objectName === "exportCourse").trigger()
        const sheet = findChild(book, "exportSheet")
        tryVerify(() => sheet.opened)

        compare(findChild(sheet, "exportFile").text, Courses.exportName(course))
        const counts = findChild(sheet, "exportCounts").text
        verify(counts.indexOf("1 photo") === 0 && counts.indexOf("0 voice note") > 0, counts)
        verify(/\d (bytes|kB|MB)/.test(counts), counts)
        verify(!findChild(sheet, "exportMissing").visible)

        // Markup in a note stays text: the file holds it so.
        const text = findChild(sheet, "exportText")
        compare(text.textFormat, Text.PlainText)
        verify(text.text.indexOf("<b>Tenkan</b>") > 0, text.text)
        verify(text.text.indexOf("](bilder/02-foto.jpg)") > 0, text.text)

        // No promise about where notes stay: sync and Android's backup carry them off.
        compare(findChild(sheet, "exportAbout").text, qsTr("A small archive: Markdown, photos and voice notes."))
        verify(!findChild(sheet, "exportShare").visible, "no share dialog on the desktop")
        verify(findChild(sheet, "exportSave").visible)
        wait(200)
        compare(overflowing(sheet.contentItem, 360), [])
        verify(sheet.width <= sheet.parent.width + 0.5, "the sheet is " + sheet.width)
        shot("14e-export-sheet", true)

        // With a share dialog (Android) both buttons fit.
        sheet.shareable = true
        wait(100)
        verify(findChild(sheet, "exportShare").visible)
        compare(overflowing(sheet.contentItem, 360), [])
        shot("14f-export-sheet-share", true)
        sheet.shareable = Qt.binding(() => Courses.canShare)

        // Save: the sheet goes, the file dialog comes.
        mouseClick(findChild(sheet, "exportSave"))
        tryVerify(() => !sheet.visible)
        const dialog = findChild(book, "exportDialog")
        // Only for Qt's own dialog: it would rename a portal's answer "…/doc/ab12/y" to "y.zip".
        verify(SavePlace.asksItself)
        compare(dialog.defaultSuffix, "zip")
        uiCatalog.setFlatpak("io.github.shrippen.Mitori")
        const portal = Qt.createComponent("Mitori", "SaveFileDialog", Component.PreferSynchronous)
            .createObject(book, { anchor: book })
        compare(portal.defaultSuffix, "")
        portal.destroy()
        uiCatalog.setFlatpak("")
        tryVerify(() => dialog.visible)
        dialog.close()
        tryVerify(() => !dialog.visible)

        // The dialog's answer reaches the export (in the test's folder, not the real Documents).
        const accepted = "export-accepted-" + Date.now() + ".zip"
        dialog.currentFolder = "file://" + uiShotsDir
        dialog.ask(accepted)
        tryVerify(() => dialog.visible)
        dialog.accept()
        tryVerify(() => findChild(book, "exportedTo").visible)
        verify(findChild(book, "exportedTo").text.indexOf(uiShotsDir + "/" + accepted) > 0, findChild(book, "exportedTo").text)
        book.exported = ""

        // No suffix typed: the file gets it, whatever Qt did (it adds none with a dot in the path).
        const bare = "export-bare-" + Date.now()
        dialog.take(dialog.currentFolder + "/" + bare)
        tryVerify(() => findChild(book, "exportedTo").visible)
        verify(findChild(book, "exportedTo").text.indexOf(uiShotsDir + "/" + bare + ".zip") > 0, findChild(book, "exportedTo").text)
        book.exported = ""

        // A typed path goes where it says, and what is there is not replaced unasked.
        const target = uiShotsDir + "/export-typed-" + Date.now() + ".zip"
        dialog.take(dialog.currentFolder + "/" + target)
        tryVerify(() => findChild(book, "exportedTo").visible)
        verify(findChild(book, "exportedTo").text.indexOf(target) > 0, findChild(book, "exportedTo").text)
        book.exported = ""
        dialog.take("file://" + target)
        const replace = findChild(dialog, "replaceFile")
        tryVerify(() => replace.opened)
        verify(!findChild(book, "exportedTo").visible, "not before the answer")
        replace.accept()
        tryVerify(() => findChild(book, "exportedTo").visible)

        // Qt's dialog was a window of its own; offscreen nothing hands the focus back to this one.
        window.requestActivate()
        tryVerify(() => window.active)

        popPage()
        verify(Courses.remove(course))
        window.width = w
        wait(100)
    }

    // ⌗: an entry linked to a technique by choice, shown in its notes, back to the entry; a deleted
    // entry or notebook leaves the notes.
    function test_8f_note_techniques() {
        const course = Courses.create("Technik-Lehrgang", "2026-05-01", "2026-05-02", "", "")
        for (let i = 0; i < 40; ++i) {
            verify(Courses.addEntry(course, "Füllzeile " + i))
        }
        verify(Courses.addEntry(course, "Heute Ô-dachi 5 und Shiho-nage aus Katate-dori"))
        const entries = Courses.entries(course)
        const entry = entries[entries.length - 1]
        compare(entry.techniques.length, 0, "a text naming a technique links nothing by itself")

        const book = push("CoursePage", { uid: course })
        const buttons = findChildren(book, "linkTechnique")
        compare(buttons.length, entries.length)
        verify(buttons[buttons.length - 1].Accessible.name !== "")
        buttons[buttons.length - 1].clicked()
        tryVerify(() => window.pageStack.currentItem.objectName === "techniquePicker")
        const picker = window.pageStack.currentItem

        // Suggestions from the text; the search finds others; a tap links.
        const first = () => findChildren(picker, "techniqueChoice")
        tryVerify(() => first().length > 2)
        verify(first().some(r => r.text.indexOf("Gohon-me") === 0), first().map(r => r.text).join())
        const shiho = first().find(r => r.text.indexOf("Shiho-nage") === 0)
        verify(/katate-dori/i.test(shiho.subtitle.split(" · ")[0]), "the attack named comes first: " + shiho.subtitle)
        const shihoId = shiho.modelData.id
        wait(800)       // the page has moved in
        shot("14e-technique-picker")
        mouseClick(shiho)
        tryCompare(picker, "linked", [shihoId])
        tryVerify(() => findChildren(picker, "linkedTechnique").length === 1)
        verify(!first().some(r => r.modelData.id === shihoId))

        const field = findChild(picker, "pickerSearch")
        field.text = "Ikkajo kime"
        tryVerify(() => picker.foundShown.length > 0)
        tryVerify(() => first().some(r => r.text === "Ikkajô-kime-osae"))
        field.text = "gibtesnicht"
        tryVerify(() => findChild(picker, "pickerNotFound").visible)
        field.text = ""

        // Unlink and link again, then back to the notebook: a chip.
        findChildren(picker, "linkedTechnique")[0].clicked()
        tryVerify(() => picker.linked.length === 0)
        verify(Courses.linkTechnique(entry.uid, shihoId))
        popPage()
        tryVerify(() => findChildren(book, "entryTechnique").length === 1)
        verify(findChildren(book, "entryTechnique")[0].text.indexOf("Shiho-nage") > 0)
        verify(findChildren(book, "entryTechnique")[0].Accessible.name.indexOf("Shiho-nage") > 0)
        book.flickable.contentY = book.flickable.contentHeight - book.flickable.height
        wait(800)
        shot("14f-entry-technique-chip")

        // The chip opens the technique's notes; there the entry, course and day; a tap goes to it.
        findChildren(book, "entryTechnique")[0].clicked()
        tryVerify(() => window.pageStack.currentItem !== book && window.pageStack.currentItem.courseNotes !== undefined)
        const notes = window.pageStack.currentItem
        compare(notes.entry.id, shihoId)
        verify(findChild(notes, "fromCourses").visible)
        const row = findChild(notes, "courseNote")
        verify(row)
        compare(row.Accessible.name, entry.text)
        verify(row.Accessible.description.indexOf("Technik-Lehrgang") === 0, row.Accessible.description)
        shot("14g-notes-from-course")
        mouseClick(row)
        tryVerify(() => window.pageStack.currentItem !== notes && window.pageStack.currentItem.uid === course)
        const opened = window.pageStack.currentItem
        const target = findChildren(opened, "courseEntry").find(l => l.modelData.uid === entry.uid)
        tryVerify(() => target.activeFocus, 3000, "the entry has the focus")
        const view = opened.flickable
        const y = target.mapToItem(view.contentItem, 0, 0).y
        verify(view.contentY > 0, "scrolled down")
        verify(y >= view.contentY && y + target.height <= view.contentY + view.height, "in view")
        popPage()

        // Deleted entry, then course: gone from the notes.
        tryVerify(() => window.pageStack.currentItem === notes)
        const page = notes
        verify(Courses.addEntry(course, "noch eine"))
        const more = Courses.entries(course)
        const other = more[more.length - 1]
        verify(Courses.linkTechnique(other.uid, shihoId))
        tryCompare(page.courseNotes, "length", 2)
        verify(Courses.deleteEntry(other.uid))
        tryCompare(page.courseNotes, "length", 1)
        verify(Courses.remove(course))
        tryCompare(page.courseNotes, "length", 0)
        verify(!findChild(page, "fromCourses").visible)
        popPage()
    }

    // Deleting a notebook opened twice (through a technique's notes): no page of it stays behind.
    function test_8f_note_techniques_gone() {
        const course = Courses.create("Zweimal offen", "2026-05-01", "", "", "")
        verify(Courses.addEntry(course, "Ikkyo"))
        const entry = Courses.entries(course)[0]
        const technique = Programme.search("Ikkyo", 1)[0]
        verify(Courses.linkTechnique(entry.uid, technique.id))
        const depth = window.pageStack.depth

        const first = push("CoursePage", { uid: course })
        const notes = push("NotesPage", { entry: technique })
        const second = push("CoursePage", { uid: course, entryUid: entry.uid })
        slidIn()
        compare(window.pageStack.depth, depth + 3)
        const remove = findChild(second, "removeCourse")
        remove.open()
        tryVerify(() => remove.opened)
        remove.accept()
        tryCompare(window.pageStack, "depth", depth + 1)
        verify(window.pageStack.currentItem === notes)
        compare(notes.courseNotes.length, 0)
        popPage()
        compare(window.pageStack.depth, depth)
        verify(window.pageStack.currentItem.uid === undefined, "no dead page")
    }

    // Linked techniques do not use up the suggestions: the list fills up, and "no other technique"
    // is said only when none is left.
    function test_8f_note_techniques_fill() {
        const course = Courses.create("Zehn Namen", "2026-05-01", "", "", "")
        verify(Courses.addEntry(course, "Ikkyo, Nikyo, Sankyo, Yonkyo, Gokyo, Shiho-nage, Irimi-nage, Kote-gaeshi, Kaiten-nage, Tenchi-nage"))
        const entry = Courses.entries(course)[0]
        const picker = push("TechniquePickerPage", { course: course, entryUid: entry.uid })
        compare(picker.named.length, 8)
        for (const t of picker.named) {
            verify(Courses.linkTechnique(entry.uid, t.id))
        }
        tryCompare(picker.linked, "length", 8)
        tryVerify(() => picker.named.length > 0, 2000, "more are named")
        verify(!findChild(picker, "pickerNoneNamed").visible)

        // A search that only finds a linked one did find it.
        verify(Courses.linkTechnique(entry.uid, "shinkitoho/odachi/5"))
        const field = findChild(picker, "pickerSearch")
        field.text = "Gohon-me"
        tryVerify(() => picker.found.length === 1)
        compare(picker.foundShown.length, 0)
        verify(!findChild(picker, "pickerNotFound").visible, "it stands under Linked")
        field.text = ""
        popPage()

        // The technique's sheet counts the linked entries with its notes.
        const component = Qt.createComponent("Mitori", "TechniqueSheet")
        verify(component.status === Component.Ready, component.errorString())
        const technique = Programme.entry(Courses.entries(course)[0].techniques[0])
        const sheet = component.createObject(window.pageStack.currentItem, { entry: technique })
        const before = Practice.notes(sheet.entry.id).length
        compare(sheet.noteCount, before + 1)
        verify(findChild(sheet.contentItem, "sheetNotesButton").text.indexOf("(" + (before + 1) + ")") > 0)
        sheet.destroy()
        verify(Courses.remove(course))
    }

    // Found by the QA round of 5 Nov 2026 (qa/PERSONAS.md).
    // What the data knows and the screen left out: Zanshin, open questions, proposals, a grade's
    // meaning and waiting time, the Suburi texts (QA round P5; the booklet p. 44 f.).
    function test_8p_data_on_the_screen() {
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        const page = push("ProgrammePage")
        const form = page.rows.find(r => r.id === "shinkitoho/odachi/5")
        verify(form.open, "S-02 is an open question")
        page.open(form)
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const facts = findChild(sheet.contentItem, "sheetFacts")
        verify(facts.visible)
        verify(allChildren(facts).some(c => c.text === "Jôdan"), "Zanshin")
        verify(findChild(sheet.contentItem, "sheetOpenQuestion").visible)
        sheet.close()
        tryVerify(() => !sheet.visible)
        const suburi = page.rows.find(r => r.id === "shinkitoho/suburi/1")
        verify(suburi.text.length > 10)
        const info = findChild(page, "gradeInfo")
        verify(info.visible)
        verify(info.text.indexOf("Erste Überlieferung") >= 0, info.text)
        verify(info.text.indexOf("2 Jahre") >= 0, info.text)
        verify(!findChild(page, "kanjiProposal").visible)
        popPage()
        Programme.discipline = "daitoryu"
        const daito = push("ProgrammePage")
        verify(findChild(daito, "kanjiProposal").visible)
        verify(!findChild(daito, "gradeInfo").visible)
        // The lens in the head, as the clickdummy has it.
        verify(daito.actions.some(a => a.icon.name === "search"))
        popPage()
        Programme.discipline = "aikido"
    }

    // Nothing past the window's edge on a small phone and at twice the scale (QA round P3, P4).
    function overflowing(root, right) {
        const found = []
        const walk = item => {
            if (!item.visible || item.opacity === 0) {
                return
            }
            // What scrolls sideways on purpose may be wider (a tab row, a table).
            if (item.contentWidth !== undefined && item.flickableDirection !== undefined
                    && item.contentWidth > item.width + 1) {
                return
            }
            const edge = item.mapToItem(window.contentItem, item.width, 0).x
            const left = item.mapToItem(window.contentItem, 0, 0).x
            // Only what can be seen: not the pages to the left, nor Kirigami's own tricks.
            if (item.width > 0 && item.height > 0 && left >= 0 && edge > right + 1 && !/MouseArea/.test(String(item))
                    && (item.text !== undefined || item.clicked !== undefined || item.source !== undefined)) {
                found.push(String(item).split("_QML")[0].split("(")[0] + " '" + (item.text || item.objectName || "") + "' to " + Math.round(edge))
            }
            for (let i = 0; i < item.children.length; ++i) {
                walk(item.children[i])
            }
        }
        walk(root)
        return found
    }

    // Browsing the programme and the map changes the page's grade only: not the start menu, not
    // today's practice, not the exam; the next visit starts at the practice grade again.
    function test_8p_browsing_keeps_practice() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k4")
        const start = window.pageStack.items[0]
        const tiles = ["programmeTile", "todayTile", "examTile"].map(n => findChild(start, n))
        // The board's run for this grade is in (the exam tile names the grade).
        tryVerify(() => tiles[2].hint.indexOf("4. Kyu") >= 0 && tiles[0].t.gradeName === "4. Kyu", 5000, tiles[2].hint)
        const hints = tiles.map(t => t.hint)
        verify(hints[0].indexOf("4. Kyu") >= 0, hints[0])
        verify(hints[2].indexOf("4. Kyu") >= 0, hints[2])

        const page = push("ProgrammePage")
        compare(page.grade, "k4")
        const chips = findChild(page, "gradeChips")
        const k2 = chips.itemAt(page.grades.findIndex(g => g.id === "k2"))
        clickUntil(k2, () => page.grade === "k2")
        verify(k2.checked)
        compare(PracticeGrade.grade("aikido"), "k4")
        compare(tiles.map(t => t.hint), hints)
        const today = push("TodayPage")
        compare(today.grade, "k4")
        popPage()
        const exam = push("ExamPage")
        compare(exam.grade, "k4")
        popPage()
        compare(page.grade, "k2", "what it browses stays")
        popPage()
        tryCompare(window.pageStack, "depth", 1)
        slidIn()

        const again = push("ProgrammePage")
        compare(again.grade, "k4")
        popPage()

        const map = push("TechniqueMapPage")
        compare(map.grade, "k4")
        map.grade = "k2"
        compare(PracticeGrade.grade("aikido"), "k4")
        compare(tiles.map(t => t.hint), hints)
        popPage()
        PracticeGrade.setGrade("aikido", "k5")
    }

    // The practice grade follows a passed grade on the open pages; Today and the exam change it
    // by hand, each sees the other's; choosing what is suggested follows "My grades" again.
    function test_8p_practice_grade() {
        const discipline = "daitoryu"
        Programme.discipline = discipline
        const removeAll = () => Courses.grades.filter(g => g.discipline === discipline).map(g => g.uid)
                                       .forEach(uid => verify(Courses.removeGrade(uid), Courses.errorString))
        removeAll()
        PracticeGrade.setGrade(discipline, "k5")
        verify(!PracticeGrade.manual(discipline))
        const start = window.pageStack.items[0]
        const examTile = findChild(start, "examTile")

        const today = push("TodayPage")
        const hint = findChild(today, "practiceGradeHint")
        compare(today.grade, "k5")
        compare(hint.text, qsTranslate("TodayPage", "up to %1 (first grade, nothing for this discipline in My grades yet)").arg("5. Kyu"))
        const dueIds = () => today.due.map(r => r.id).join()
        const dueAt = grade => Practice.due(Programme.practiceEntries(discipline, grade)).map(r => r.id).join()

        verify(Courses.addGrade(discipline, "k5", "2025-05-01", ""))
        tryCompare(today, "grade", "k4")
        verify(findChild(today, "practice_k4").checked)
        compare(dueIds(), dueAt("k4"), "what is due follows the grade")
        compare(hint.text, qsTranslate("TodayPage", "up to %1 (from My grades)").arg("4. Kyu"))
        tryVerify(() => examTile.hint.indexOf("4. Kyu") >= 0, 5000, examTile.hint)

        // By hand on Today, further than suggested. 2. Kyu: the training cases, with videos, have
        // used up today's new ones of 5. to 3. Kyu; what is due there may be the same (nothing).
        const dueUpToK4 = dueIds()
        clickUntil(findChild(today, "practice_k2"), () => today.grade === "k2")
        compare(dueIds(), dueAt("k2"))
        verify(dueIds() !== dueUpToK4, "what is due changes with the grade")
        verify(today.manualGrade)
        verify(findChild(today, "practice_k2").checked)
        verify(!findChild(today, "practice_k4").checked)
        compare(hint.text, qsTranslate("TodayPage", "up to %1 (chosen by you)").arg("2. Kyu"))
        tryVerify(() => examTile.hint.indexOf("2. Kyu") >= 0, 5000, examTile.hint)

        // A passed grade behind it leaves it.
        verify(Courses.addGrade(discipline, "k4", "2026-05-01", ""))
        wait(50)
        compare(today.grade, "k2")
        popPage()
        tryCompare(window.pageStack, "depth", 1)
        slidIn()

        // By hand in the exam: Today and the start menu follow.
        const exam = push("ExamPage")
        compare(exam.grade, "k2")
        clickUntil(findChild(exam, "grade_k5"), () => exam.grade === "k5")
        compare(PracticeGrade.grade(discipline), "k5")
        tryVerify(() => examTile.hint.indexOf("5. Kyu") >= 0, 5000, examTile.hint)

        // A grade passed since moves a choice behind it forward.
        verify(Courses.addGrade(discipline, "k3", "2026-06-01", ""))
        tryCompare(exam, "grade", "k2")
        verify(!PracticeGrade.manual(discipline))
        popPage()

        removeAll()
        PracticeGrade.setGrade(discipline, "k5")
    }

    // Hon-Menkyo and Menkyo-Kaiden: a chip with "–" and a card instead of the list; the grade the
    // other pages use stays.
    function test_8p_grade_without_forms() {
        const width = window.width, height = window.height
        window.width = 360
        window.height = 800
        wait(100)
        useFolder(standInVideos)
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "chuden")
        const page = push("ProgrammePage")
        const settled = () => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1
        slidIn()
        const chips = findChild(page, "gradeChips")
        const card = findChild(page, "gradeCard")
        verify(!card.visible)
        verify(page.grades.every(g => g.id !== "hoshu"), "Hôshu has no content")

        const index = page.grades.findIndex(g => g.id === "kaiden")
        const data = page.grades[index]
        const chip = chips.itemAt(index)
        compare(chip.text, data.name + " –")
        compare(chip.Accessible.name, qsTranslate("ProgrammePage", "%1, no forms yet").arg(data.name))

        clickUntil(chip, () => page.grade === "kaiden")
        verify(chip.checked)
        compare(PracticeGrade.grade("shinkitoho"), "chuden", "the other pages keep their grade")
        tryVerify(() => card.visible)
        compare(page.rows.length, 0)

        const texts = allChildren(card).filter(c => c.visible).map(c => c.text)
        for (const expected of [data.bedeutung, data.inhalt, data.abstand]) {
            verify(expected && texts.indexOf(expected) >= 0, expected)
        }
        const head = allChildren(card).find(c => c.japanese !== undefined)
        compare(head.title, data.name)
        compare(head.japanese, data.jp)
        verify(findChild(card, "gradeCardNote").visible)
        verify(!findChild(page, "gradeInfo").visible, "the card says it")
        verify(!findChild(page, "gradeStand").visible)
        verify(!allChildren(page).some(c => c.visible && c.titleText !== undefined), "no video hint")
        tryVerify(settled, 3000, "still in place")
        // Just shown, the card has its implicit width until the layouts' next pass (long lines
        // measured past the edge with a wide font, as in the CI). A card still small sticks out only
        // after that pass: wait for it first. What stays past the edge still fails.
        wait(100)
        for (let i = 0; i < 30 && overflowing(page, window.width).length > 0; i++) {
            wait(100)
        }
        compare(overflowing(page, window.width), [])
        shot("3-programme-grade-without-forms")

        // A tablet sideways: nothing beside the card, no empty player. With videos of another
        // grade the pane stands there first and goes.
        window.width = 1280
        window.height = 800
        wait(100)
        verify(!page.split)
        verify(!findChild(page, "playerPane").active)
        verify(card.width <= Kirigami.Units.gridUnit * 30 + 1, "a card, not a band: " + card.width)
        shot("3-programme-grade-without-forms-wide")

        // Back to a grade with forms: the list, and the pane if there are videos.
        chooseGrade(page, "chuden")
        tryVerify(() => !card.visible)
        verify(page.rows.length > 0)
        verify(page.split)
        verify(findChild(page, "playerPane").active)

        // From beside the player to the card and back: the pane goes and returns.
        chooseGrade(page, "kaiden")
        verify(!page.split)
        verify(!findChild(page, "playerPane").active)
        chooseGrade(page, "chuden")
        verify(page.split)
        verify(findChild(page, "playerPane").active)
        popPage()

        // Opened anew: the grade the other pages use, not the card.
        const again = push("ProgrammePage")
        compare(again.grade, "chuden")
        verify(!findChild(again, "gradeCard").visible)
        popPage()
        window.width = width
        window.height = height
        PracticeGrade.setGrade("shinkitoho", "shoden")
        Programme.discipline = "aikido"
    }

    // The grade chips say how far each grade is; the storage bar has its legend.
    function test_8p_grade_chips_and_storage() {
        const width = window.width, height = window.height
        window.width = 360
        window.height = 800
        wait(100)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        const chips = findChild(page, "gradeChips")
        const k5 = chips.itemAt(page.grades.findIndex(g => g.id === "k5"))
        const ids = Programme.entries("aikido", "k5").filter(r => r.kind === "entry").map(r => r.id)
        compare(k5.text, page.grades.find(g => g.id === "k5").name + " " + Practice.counts(ids)[4] + "/" + ids.length)
        const programmeList = findChild(page, "programmeList")
        tryVerify(() => programmeList.height < 1000)
        wait(800)
        compare(programmeList.contentY, programmeList.originY, "the list opens at its top")
        // Another discipline, another head (the grades' meaning): still at its top.
        const topBefore = programmeList.originY
        Programme.discipline = "shinkitoho"
        page.grade = PracticeGrade.grade("shinkitoho")
        tryVerify(() => findChild(programmeList.headerItem, "gradeInfo").visible)
        // The head grows in steps, the list follows each a moment later (-265, then -337): it has
        // to be grown, and at the top for a while. One second is many steps' worth of polish.
        const kSteadyMs = 1000
        let top = programmeList.originY
        let since = Date.now()
        tryVerify(() => {
            if (programmeList.originY !== top || programmeList.contentY !== top || programmeList.moving) {
                top = programmeList.originY
                since = Date.now()
                return false
            }
            return top < topBefore && Date.now() - since >= kSteadyMs
        }, 15000, "the list stays at its top")
        Programme.discipline = "aikido"
        page.grade = "k5"
        wait(100)
        shot("8p-chips")
        popPage()
        const videos = push("VideosPage")
        verify(findChild(videos, "storageBar").visible)
        compare(findChild(videos, "storageLegend").model.length, 3)
        shot("8p-storage")
        popPage()
        window.width = width
        window.height = height
        wait(100)
    }

    // The head settling just before the list goes to a row (back from the player): the row wins.
    // The list went back to its top, about every second run of test_8p_row_lights_up_on_return.
    function test_8p_row_beats_keep_top() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        const list = findChild(page, "programmeList")
        tryVerify(() => list.count > 0)
        wait(500)
        list.positionViewAtBeginning()
        wait(100)
        verify(!list.moving)
        list.originYChanged()       // the head's new height, at the top: keep the top, a moment later
        list.positionViewAtIndex(page.rows.length - 1, ListView.Contain)
        wait(200)
        verify(list.itemAtIndex(page.rows.length - 1) !== null, "the last row, at " + list.contentY)
        popPage()
    }

    // On a phone the row of the last technique lights up on the way back, then no longer.
    function test_8p_row_lights_up_on_return() {
        const width = window.width, height = window.height
        window.width = 400
        window.height = 800
        wait(100)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        tryVerify(() => !page.split)
        const rows = page.rows.filter(r => r.kind === "entry")
        const last = rows[rows.length - 1]
        const player = push("PlayerPage", { playlist: rows, index: rows.length - 1 })
        page.lastId = last.id
        page.cameFromPlayer = true  // as play() does: this test needs no video
        tryVerify(() => window.pageStack.currentItem === player)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        compare(page.returnedId, last.id)
        const list = findChild(page, "programmeList")
        const row = page.rows.findIndex(r => r.id === last.id)
        tryVerify(() => list.itemAtIndex(row) !== null)
        tryVerify(() => page.returnedId === "", 3000)
        // Back from anything else (the notes) the list stays where the user had it.
        list.positionViewAtBeginning()
        const top = list.contentY
        const notes = push("NotesPage", { entry: rows[0] })
        tryVerify(() => window.pageStack.currentItem === notes)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        compare(page.returnedId, "")
        wait(200)
        compare(list.contentY, top)
        popPage()
        window.width = width
        window.height = height
        wait(100)
    }

    // One breakpoint for all pages: a tablet sideways, not a phone sideways, nor anything upright.
    function test_8q_tablet_breakpoint() {
        compare(Tablet.minHeight, Kirigami.Units.gridUnit * 26)
        verify(Tablet.wide(1280, 800))
        verify(Tablet.wide(1024, 768))
        verify(!Tablet.wide(800, 1280))
        verify(!Tablet.wide(915, 412), "a phone held sideways")
        verify(!Tablet.wide(800, 800))
        verify(!Tablet.wide(530, 520), "nearly square: no room for two columns")
        verify(!Tablet.wide(600, 520))
    }

    // Today, Statistics and My grades on a tablet sideways: two columns in a page of at most 880
    // units, in the middle (the clickdummy's `.tab .page`, `.tab .grid2`). Upright and on a phone
    // one column, nothing past the edge.
    function test_8q_pages_columns_data() {
        const sizes = [ { size: "1280x800", width: 1280, height: 800, two: true }, { size: "1024x768", width: 1024, height: 768, two: true },
                        { size: "800x1280", width: 800, height: 1280, two: false }, { size: "360", width: 360, height: 800, two: false },
                        { size: "320", width: 320, height: 800, two: false },
                        { size: "530x520", width: 530, height: 520, two: false }, { size: "600x520", width: 600, height: 520, two: false } ]
        const pages = [ { name: "TodayPage", pairs: [["dueLeft", "dueRight"]] },
                        { name: "StatsPage", pairs: [["last30Column", "daysColumn"], ["gradesColumn", "examColumn"]] },
                        { name: "GradesPage", pairs: [["grades_aikido", "grades_daitoryu"]] } ]
        const rows = []
        for (const page of pages) {
            for (const size of sizes) {
                rows.push(Object.assign({ tag: page.name + " " + size.size }, page, size))
            }
        }
        return rows
    }
    function test_8q_pages_columns(data) {
        window.width = data.width
        window.height = data.height
        wait(100)
        const page = push(data.name)
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)

        const box = name => {
            const item = findChild(page, name)
            verify(item && item.visible, name)
            const at = item.mapToItem(null, 0, 0)
            return { left: at.x, top: at.y, right: at.x + item.width }
        }
        for (const [first, second] of data.pairs) {
            const a = box(first), b = box(second)
            if (data.two) {
                verify(a.right <= b.left + 0.5, first + " beside " + second + ": " + a.right + " / " + b.left)
            } else {
                verify(b.top > a.top, second + " below " + first)
                verify(Math.abs(a.left - b.left) < Look.unit(16), first + " and " + second + " in one column")
            }
        }
        compare(overflowing(page, data.width), [])

        // Both columns together: at most 880 on a tablet, in the middle.
        if (data.two) {
            const a = box(data.pairs[0][0]), b = box(data.pairs[0][1])
            verify(b.right - a.left <= Look.unit(880) + 0.5, "the page's width: " + (b.right - a.left))
            verify(Math.abs(a.left - (data.width - b.right)) < Look.unit(24), "in the middle: " + a.left + " / " + b.right)
        }
        if (data.width === 1280) {
            shot("8q-" + data.name)
        }
    }

    // ---- Polish pass: reading width, start grid, small-phone wrapping ----

    // Left and right edge of what a page shows (texts, controls, pictures that can be seen).
    function extent(root) {
        let left = Infinity
        let right = -Infinity
        let first = ""
        let last = ""
        const walk = item => {
            if (!item.visible || item.opacity === 0) {
                return
            }
            if (item.width > 0 && item.height > 0 && !/MouseArea/.test(String(item))
                    && (item.text !== undefined || item.clicked !== undefined || item.cellSize !== undefined)) {
                const x = item.mapToItem(window.contentItem, 0, 0).x
                if (x >= 0 && x < window.width) {
                    if (x < left) {
                        first = String(item)
                    }
                    if (x + item.width > right) {
                        last = String(item)
                    }
                    left = Math.min(left, x)
                    right = Math.max(right, x + item.width)
                }
            }
            for (let i = 0; i < item.children.length; ++i) {
                walk(item.children[i])
            }
        }
        walk(root)
        return { left: left, right: right, first: first, last: last }
    }

    // The words that stand elided in what `root` shows.
    function truncated(root) {
        return allChildren(root).filter(c => c.visible && c.truncated === true).map(c => c.text)
    }

    // A course 12 days ahead with an exam planned on it; the caller removes it.
    function plannedCourse(title) {
        const day = Qt.formatDate(new Date(Date.now() + 12 * 24 * 3600 * 1000), "yyyy-MM-dd")
        const uid = Courses.create(title, day, day, "Lüneburg", "Hiroshi Tanabe Sensei")
        verify(uid !== "", "course made")
        verify(Courses.planExam(uid, "aikido", "k3"), "exam planned")
        return uid
    }

    // Single-column pages on a wide window: a page of reading width in the middle, never the whole
    // window (the composer bars of the notes too). Not SearchPage: its glossary has three columns.
    function test_8s_reading_width_data() {
        return ["ExamPage", "CourseNewPage", "NotebooksPage", "AllNotesPage", "NotesPage", "CoursePage",
                "VideosPage", "BackupPage", "AppearancePage", "WelcomePage", "YearsPage", "TechniquePickerPage"]
            .map(name => ({ tag: name, name: name }))
    }
    function test_8s_reading_width(data) {
        window.width = 1280
        window.height = 800
        wait(100)
        const uid = Courses.create("Lesebreite", "2030-01-10", "2030-01-11", "", "")
        const props = data.name === "NotesPage" ? { entry: Programme.entries("aikido", "k5").find(r => r.kind === "entry") }
                    : data.name === "CoursePage" ? { uid: uid }
                    : data.name === "TechniquePickerPage" ? { course: uid, entryUid: "none" } : {}
        const page = push(data.name, props)
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(400)
        const box = extent(page)
        Courses.remove(uid)
        verify(box.right > box.left, "the page shows something")
        verify(box.right - box.left <= Tablet.pageWidth + 1, data.name + " is " + Math.round(box.right - box.left)
               + " wide, at most " + Math.round(Tablet.pageWidth) + " (" + box.first + " to " + box.last + ")")
        verify(Math.abs(box.left - (window.width - box.right)) < Look.unit(40), "in the middle: " + box.left + " / " + box.right)
    }

    // The glossary in a broad window that is no tablet sideways (a desktop window, a tablet upright
    // that is broad): one list, its rows of reading width in the middle.
    function test_8s_search_reading_width() {
        window.width = 1000
        window.height = 1200
        wait(100)
        const page = push("SearchPage")
        slidIn()
        verify(!page.wide, "wide at " + page.width + "x" + page.height + " in " + window.width + "x" + window.height)
        const list = findChild(page, "glossaryList")
        tryCompare(list, "count", Glossary.words.length)
        const rows = findChildren(list, "glossaryRow")
        verify(rows.length > 0)
        const row = rows[0]
        verify(row.width <= Tablet.pageWidth + 1, "a row is " + Math.round(row.width) + " wide, at most " + Math.round(Tablet.pageWidth))
        const left = row.mapToItem(list, 0, 0).x
        verify(Math.abs(left - (list.width - left - row.width)) < 1, "in the middle: " + left)
        popPage()
    }

    // The start menu's tiles use the height of a tablet; a phone keeps its tiles.
    function test_8s_start_fills_tablet_data() {
        return [ { tag: "1280x800", width: 1280, height: 800, fills: true }, { tag: "800x1280", width: 800, height: 1280, fills: true },
                 { tag: "360x640", width: 360, height: 640, fills: false }, { tag: "420x860", width: 420, height: 860, fills: false },
                 { tag: "860x420", width: 860, height: 420, fills: false } ]
    }
    function test_8s_start_fills_tablet(data) {
        window.width = data.width
        window.height = data.height
        wait(300)
        const start = window.pageStack.items[0]
        const tiles = findChild(start, "tiles")
        const bottom = tiles.mapToItem(start, 0, tiles.height).y
        if (data.fills) {
            const tile = findChild(start, "todayTile")
            verify(tile.height > tile.implicitHeight + Look.unit(16), "the tiles grow: " + tile.height + " from " + tile.implicitHeight)
            verify(tile.height <= start.tileMaxHeight + 0.5, "no stretched bar: " + tile.height)
            // The page's height is used, or the tiles stand at their maximum.
            verify(bottom >= start.height - Look.unit(48) || tile.height >= start.tileMaxHeight - 0.5,
                   "the tiles end at " + Math.round(bottom) + " of " + start.height)
        } else {
            compare(tiles.height, tiles.implicitHeight, "the tiles keep their size")
        }
    }

    // The welcome page: the button stands right below the text of the step, at every size.
    function test_8s_welcome_next_below_text_data() {
        return [ { tag: "360x640", width: 360, height: 640 }, { tag: "1280x800", width: 1280, height: 800 },
                 { tag: "800x1280", width: 800, height: 1280 } ]
    }
    function test_8s_welcome_next_below_text(data) {
        window.width = data.width
        window.height = data.height
        wait(100)
        const page = push("WelcomePage")
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)
        const next = findChild(page, "welcomeNext")
        const text = findChild(page, "welcomeSteps").children[page.step]
        const textBottom = text.mapToItem(page, 0, text.height).y
        const nextTop = next.mapToItem(page, 0, 0).y
        verify(nextTop - textBottom < Look.unit(40), "the button is " + Math.round(nextTop - textBottom) + " below the text")
        const content = extent(page)
        verify(Math.abs(next.mapToItem(window.contentItem, next.width, 0).x - content.right) < 1, "right-aligned")
    }

    // A legend that wraps on a small phone leaves no key alone on its last line ("10 and more").
    function test_8s_legend_lines_balanced() {
        window.width = 360
        window.height = 800
        wait(100)
        const page = push("YearsPage")
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        const legend = findChild(page, "yearsLegend")
        const keys = legend.children.filter(c => c.visible && c.modelData !== undefined)
        compare(keys.length, 5)
        const lines = {}
        for (const k of keys) {
            lines[k.y] = (lines[k.y] || 0) + 1
        }
        const counts = Object.keys(lines).sort((a, b) => a - b).map(y => lines[y])
        verify(counts.length === 1 || counts[counts.length - 1] > 1, "keys per line: " + counts)
        popPage()
    }

    // A notebook's title longer than two lines ends in "…" in every style (Shinki cut it off).
    function test_8s_long_title_elides() {
        window.width = 320
        window.height = 568
        wait(100)
        const uid = plannedCourse("Aikido Kyu-Lehrgang mit Prüfung und Dan-Prüfung, Sommerlehrgang am See mit Gastlehrern aus Japan")
        const book = push("CoursePage", { uid: uid })
        wait(300)
        const title = findChild(book, "courseTitle")
        compare(title.lineCount, 2, "two lines")
        verify(title.truncated, "cut after two lines")
        compare(title.elide, Text.ElideRight, "ends in an ellipsis")
        popPage()
        verify(Courses.remove(uid))
    }

    // The notebook's title and the exam hints break their lines instead of eliding, on the smallest phone.
    function test_8s_titles_wrap_small_phone() {
        window.width = 320
        window.height = 568
        wait(100)
        const uid = plannedCourse("Aikido Kyu-Lehrgang mit Prüfung")
        const book = push("CoursePage", { uid: uid })
        wait(300)
        compare(truncated(findChild(book, "courseTitle")), [], "the notebook's title")
        popPage()

        Programme.discipline = "aikido"
        const today = push("TodayPage")
        wait(300)
        compare(truncated(findChild(today, "plannedHint")), [], "the hint on Today")
        popPage()
        const exam = push("ExamPage")
        wait(300)
        compare(truncated(findChild(exam, "plannedHint")), [], "the hint on Exam mode")
        popPage()
        Courses.remove(uid)
    }

    // The planned exam on the notebook: the chip and "Change" in one row, the waiting time below.
    function test_8s_course_exam_row_data() {
        return [ { tag: "360", width: 360 }, { tag: "420", width: 420 } ]
    }
    function test_8s_course_exam_row(data) {
        window.width = data.width
        window.height = 800
        wait(100)
        const uid = plannedCourse("Aikido Lehrgang")
        const book = push("CoursePage", { uid: uid })
        wait(300)
        const chip = findChild(book, "examChip")
        const waiting = findChild(book, "examWait")
        const change = findChild(book, "changeExam")
        verify(chip.visible && waiting.visible && change.visible)
        const at = item => item.mapToItem(book, 0, 0)
        verify(at(waiting).y >= at(chip).y + chip.height - 1, "the text below the chip: " + at(waiting).y + " / " + at(chip).y)
        verify(at(change).y < at(waiting).y, "the button beside the chip")
        verify(waiting.lineCount <= 1 || waiting.width > book.width / 2, "the text has room: " + waiting.lineCount + " lines, " + waiting.width)
        popPage()
        Courses.remove(uid)
    }

    // Small controls (switches) stand right beside their label at every width.
    function test_8s_exam_switches_right_data() {
        return [ { tag: "360", width: 360 }, { tag: "320", width: 320 }, { tag: "420", width: 420 } ]
    }
    function test_8s_exam_switches_right(data) {
        window.width = data.width
        window.height = 800
        wait(100)
        const page = push("ExamPage")
        wait(300)
        for (const name of ["shuffledSwitch", "samplesSwitch"]) {
            const sw = findChild(page, name)
            let row = sw.parent
            while (row && row.narrow === undefined) {
                row = row.parent
            }
            verify(row && !row.narrow, name + " stands below its label")
            const edge = sw.mapToItem(page, sw.width, 0).x
            verify(edge > page.width - Look.unit(48), name + " is at the right: " + edge)
        }
        popPage()
    }

    // The year heatmap: on a phone each year in two halves stacked (cells that read, every weekday
    // and month label in view, nothing to scroll); on a wide window one heatmap fills the page.
    function test_8s_years_heatmap_data() {
        return [ { tag: "360", width: 360, height: 640, wide: false }, { tag: "420", width: 420, height: 860, wide: false },
                 { tag: "1280x800", width: 1280, height: 800, wide: true } ]
    }
    function test_8s_years_heatmap(data) {
        window.width = data.width
        window.height = data.height
        wait(100)
        const page = push("YearsPage")
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)
        const year = page.todayDate.getFullYear()
        const block = findChild(page, "year_" + year)
        verify(block, "this year's block")
        const maps = findChildren(block, "yearHeatmap").filter(h => h.visible)
        verify(maps.length > 0, "a heatmap")
        if (data.wide) {
            compare(maps.length, 1, "one heatmap for the whole year")
            verify(maps[0].width >= block.width * 0.9, "fills the page: " + maps[0].width + " of " + block.width)
            return
        }
        verify(maps.length === 2, "two halves: " + maps.length)
        for (const heat of maps) {
            verify(heat.cellSize >= Look.unit(8), "cells of " + heat.cellSize)
            const left = heat.mapToItem(window.contentItem, 0, 0).x
            verify(left >= 0 && left + heat.width <= data.width + 0.5,
                   "inside the window, labels in view: " + left + " to " + (left + heat.width))
            let flick = heat.parent
            while (flick && flick.contentX === undefined) {
                flick = flick.parent
            }
            verify(!flick || flick.contentWidth <= flick.width + 1, "nothing to scroll sideways")
        }
    }

    // Resizing a window keeps the year's heatmaps (a year's tips take their time to build): they are
    // built anew only between whole and halves.
    function test_8s_years_heatmap_resize() {
        window.width = 420
        window.height = 860
        wait(100)
        const page = push("YearsPage")
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)
        const year = page.todayDate.getFullYear()
        const before = findChildren(findChild(page, "year_" + year), "yearHeatmap")
        compare(before.length, 2, "halves at 420")
        window.width = 400
        tryCompare(page, "width", 400, 3000)
        const after = findChildren(findChild(page, "year_" + year), "yearHeatmap")
        verify(after.length === 2 && after.every((h, i) => h === before[i]), "the same heatmaps at 400")
        window.width = 1280
        window.height = 800
        tryVerify(() => findChildren(findChild(page, "year_" + year), "yearHeatmap").filter(h => h.visible).length === 1,
                  3000, "one heatmap on a wide window")
        popPage()
    }

    // The grade form on a phone: grade and day in one row, place and "Add" in the next, edges flush.
    function test_8s_grades_form_aligned_data() {
        return [ { tag: "360", width: 360, height: 800 }, { tag: "420", width: 420, height: 800 }, { tag: "1280x800", width: 1280, height: 800 } ]
    }
    function test_8s_grades_form_aligned(data) {
        window.width = data.width
        window.height = data.height
        wait(100)
        const page = push("GradesPage")
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(300)
        const block = findChild(page, "grades_aikido")
        const edges = name => {
            const item = findChild(block, name)
            verify(item && item.visible, name)
            const at = item.mapToItem(window.contentItem, 0, 0)
            return { left: at.x, right: at.x + item.width, top: at.y + item.height / 2 }
        }
        const grade = edges("gradeBox"), day = edges("gradeDay"), place = edges("gradePlace"), add = edges("addGrade")
        verify(Math.abs(grade.top - day.top) < 8, "grade and day in a row")
        verify(place.top > grade.top + 8, "the place in the next row")
        verify(Math.abs(place.top - add.top) < 8, "place and button in a row")
        verify(Math.abs(place.left - grade.left) < 1, "left edges: " + place.left + " / " + grade.left)
        verify(Math.abs(add.right - day.right) < 1, "right edges: " + add.right + " / " + day.right)
        verify(Math.abs(place.right + Look.unit(8) - add.left) < Look.unit(8) + 1, "the place field fills up to the button: " + place.right + " / " + add.left)
        popPage()
    }

    // The four rating words in German on the smallest phone: every one in full, none elided.
    function test_8s_rating_words_fit_data() {
        return [ { tag: "360", width: 360 } ]
    }
    function test_8s_rating_words_fit(data) {
        window.width = data.width
        window.height = 640
        wait(100)
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const page = push("PlayerPage", { playlist: rows, index: 0 })
        wait(300)
        const rating = findChild(page, "ratingRow")
        const picker = allChildren(rating).find(c => c.names !== undefined && c.picked !== undefined)
        verify(picker, "the picker")
        picker.names = ["", "gesehen", "mit Hilfe", "sicher", "prüfungsreif"]
        wait(100)
        compare(truncated(picker), [], "picker " + picker.width + " wide")
        popPage()
    }

    // The player's switches upright: sound, screen on and subtitles share their rows; the subtitles'
    // switch does not stand alone in a third row.
    function test_8s_player_switches_flow() {
        const same = Programme.entries("aikido", "k5").find(r => r.kind === "entry").id
        const lesson = "lern/" + lessonId + "/irimi"
        verify(uiCatalog.installLesson(lessonId, same))
        tryCompare(Library.packages, "length", 1)
        window.width = 420
        window.height = 800
        const around = Library.around(lesson)
        const page = push("PlayerPage", { playlist: around.playlist, index: around.index })
        tryVerify(() => page.hasVideo)
        slidIn()
        const button = findChildren(page, "subtitleButton").find(i => i.visible)
        tryVerify(() => !!button)
        const at = name => findChild(page, name).mapToItem(page, 0, 0).y
        const subtitlesY = button.mapToItem(page, 0, 0).y
        if (page.kino) {
            // Kino: the thumb zone's first row holds tempo, loop and subtitles.
            verify(Math.abs(subtitlesY - at("thumbLoop")) < 1, "the subtitles' switch shares the row of the loop: " + subtitlesY + " / " + at("thumbLoop"))
            popPage()
            return
        }
        verify(subtitlesY === at("soundSwitch") || subtitlesY === at("awakeSwitch"),
               "the subtitles' switch shares a row: " + subtitlesY + " / " + at("soundSwitch") + " / " + at("awakeSwitch"))
        popPage()
    }

    // The on-screen keyboard is a lower window (not a device's here): while a field of the page is
    // typed in, and until the page is high again, the live page keeps its columns, both ways.
    function test_8r_typing_holds_columns_data() {
        const place = page => findChild(findChild(page, "grades_daitoryu"), "gradePlace")
        const days = page => allChildren(findChild(page, "intervalDays")).find(c => c.cursorPosition !== undefined)
        return [ { tag: "grades sideways", name: "GradesPage", field: place, width: 1280, high: 800, low: 450, wide: true },
                 { tag: "grades upright", name: "GradesPage", field: place, width: 800, high: 1280, low: 780, wide: false },
                 { tag: "today sideways", name: "TodayPage", field: days, width: 1280, high: 800, low: 450, wide: true },
                 { tag: "today upright", name: "TodayPage", field: days, width: 800, high: 1280, low: 780, wide: false } ]
    }
    function test_8r_typing_holds_columns(data) {
        window.width = data.width
        window.height = data.high
        wait(100)
        const page = push(data.name)
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(200)
        compare(page.wide, data.wide)
        const flick = page.flickable
        flick.contentY = flick.contentHeight - flick.height
        wait(100)

        const field = data.field(page)
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        const fieldY = () => field.mapToItem(flick.contentItem, 0, 0).y
        const before = fieldY()
        const highPage = page.height
        window.height = data.low
        tryVerify(() => page.height < highPage, 5000, "the page got lower")
        wait(200)
        compare(page.wide, data.wide, "the keyboard leaves the columns alone")
        compare(fieldY(), before, "the field stays where it was")
        verify(field.activeFocus)

        // A tap takes the focus while the keyboard is still open: still held.
        window.contentItem.forceActiveFocus()
        tryVerify(() => !field.activeFocus)
        wait(100)
        compare(page.wide, data.wide, "the keyboard is still open")

        // The keyboard closes; afterwards the page follows its size again.
        window.height = data.high
        wait(200)
        compare(page.wide, data.wide)
        window.height = data.low
        tryVerify(() => page.wide === !data.wide, 2000, "released: the low window counts")
    }

    // The glossary on a tablet sideways: typing in the search keeps the three parts when the keyboard
    // shrinks the window.
    function test_8r_typing_holds_glossary() {
        window.width = 1280
        window.height = 800
        wait(100)
        const page = push("SearchPage")
        slidIn()
        tryVerify(() => page.wide)
        const field = findChild(page, "searchField")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        const high = page.height
        window.height = 450
        tryVerify(() => page.height < high, 5000, "the page got lower")
        wait(200)
        verify(page.wide, "the keyboard leaves the three parts alone")
        verify(findChild(page, "glossaryDetail").visible)
        field.text = "kiri"
        tryVerify(() => page.query === "kiri", 2000)
        verify(page.wide, "typing keeps them")
        window.contentItem.forceActiveFocus()
        tryVerify(() => !field.activeFocus)
        window.height = 800
        wait(200)
        verify(page.wide)
        window.height = 450
        tryVerify(() => !page.wide, 2000, "released: the low window counts (holding " + page.hold.holding + ", typing " + page.hold.typing + ", high " + page.hold.high + ", held " + page.hold.heldHeight + " of " + page.height + ", focus " + window.activeFocusItem + ")")
        popPage()
    }

    // Turned with the keyboard open: the tablet's real shape counts, not the low window, also once
    // the keyboard closes with the focus kept.
    function test_8r_turned_with_keyboard_open() {
        window.width = 800
        window.height = 780
        wait(100)
        const page = push("GradesPage")
        const field = findChild(page, "gradePlace")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        turn(1280, 450)
        tryVerify(() => page.width === 1280)
        wait(200)
        verify(page.wide, "sideways: two columns with the keyboard open")
        window.height = 800
        wait(200)
        verify(page.wide)
    }

    // Courses and Settings on a tablet sideways: list and page side by side, the list at most 400
    // wide (the clickdummy's `.split2`), a row chooses the page, the actions of both in the head.
    // Upright and on a phone only the list; a row opens the page.
    function listHost(file, width, height) {
        window.width = width
        window.height = height
        wait(100)
        window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/ListAndPage.qml"), { listSource: file })
        const host = window.pageStack.currentItem
        tryVerify(() => Math.abs(host.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
        wait(200)
        return host
    }
    function test_8s_settings_side_by_side_data() {
        return [ { tag: "1280x800", width: 1280, height: 800 }, { tag: "1024x768", width: 1024, height: 768 }, { tag: "700x560", width: 700, height: 560 } ]
    }
    function test_8s_settings_side_by_side(data) {
        const host = listHost("SettingsPage.qml", data.width, data.height)
        verify(host.wide)
        const list = findChild(host, "listPane")
        const pane = findChild(host, "pagePane")
        verify(list.width <= Look.unit(400) + 0.5, "the list: " + list.width)
        compare(list.width + pane.width + findChild(host, "paneRule").width, host.width)
        tryVerify(() => pane.item && pane.item.title === "Videos")
        verify(findChild(host, "videosButton").selected)

        // A row chooses the page, the stack stays.
        const depth = window.pageStack.depth
        for (const [row, title] of [["backupButton", "Backup and sync"], ["appearanceButton", "Appearance"], ["videosButton", "Videos"]]) {
            mouseClick(findChild(host, row))
            tryVerify(() => pane.item && pane.item.title === title)
            verify(findChild(host, row).selected)
            compare(window.pageStack.depth, depth)
            // Beside the list the page is below the reading width: its margins stay as they are.
            compare(pane.item.leftPadding, pane.item.padding, title + ": margin")
            tryVerify(() => overflowing(host, data.width).length === 0, 3000, title + ": past the edge: " + overflowing(host, data.width))
        }

        // A wish to scan from the page beside the list reaches the window's stack.
        CodeScanner.ready()
        tryVerify(() => window.pageStack.depth === depth + 1, 3000, "the scan page")
        popPage()
        tryCompare(window.pageStack, "depth", depth)

        // What the page offers is in the head too.
        verify(host.actions.length >= pane.item.actions.length && pane.item.actions.length > 0, "the page's actions")
        shot("8s-settings-" + data.tag)
        popPage()
    }
    function test_8s_settings_only_list_data() {
        return [ { tag: "800x1280", width: 800, height: 1280 }, { tag: "360", width: 360, height: 800 }, { tag: "320", width: 320, height: 800 } ]
    }
    function test_8s_settings_only_list(data) {
        const host = listHost("SettingsPage.qml", data.width, data.height)
        verify(!host.wide)
        verify(!findChild(host, "pagePane").visible)
        compare(findChild(host, "listPane").width, host.width)
        compare(host.title, "Settings")
        compare(overflowing(host, data.width), [])
        const row = findChild(host, "backupButton")
        verify(!row.selected)
        const depth = window.pageStack.depth
        mouseClick(row)
        tryCompare(window.pageStack, "depth", depth + 1)
        tryCompare(window.pageStack.currentItem, "title", "Backup and sync")
        popPage()
        popPage()
    }

    // Courses: a notebook beside the list. A date or a planned exam chooses it; what is typed in it
    // stays when the keyboard comes, and when another is chosen it is saved, not lost. Pages pushed
    // from it stand on the window's stack.
    function testCourse(title) {
        const uid = Courses.create(title, "2030-01-05", "2030-01-06", "", "")
        verify(uid)
        return uid
    }
    function test_8s_courses_side_by_side() {
        const first = testCourse("Links")
        const second = testCourse("Rechts")
        const host = listHost("CoursesPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        const list = findChild(host, "listPane")
        verify(list.width <= Look.unit(400) + 0.5)
        list.item.open(first)
        tryVerify(() => pane.item && pane.item.uid === first)
        compare(window.pageStack.currentItem, host)
        compare(overflowing(host, 1280), [])
        shot("8s-courses")

        // The keyboard: the page and the field stay.
        const book = pane.item
        const field = findChild(book, "courseCompose")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = "Halten"
        window.height = 400
        tryVerify(() => host.height < Tablet.minHeight)
        wait(200)
        verify(host.wide, "the keyboard keeps the list beside it")
        compare(pane.item, book)
        verify(field.activeFocus)
        window.height = 800
        tryVerify(() => host.height >= Tablet.minHeight)

        // Another course: the begun entry goes into its notebook.
        list.item.open(second)
        tryVerify(() => pane.item && pane.item.uid === second)
        tryVerify(() => Courses.entries(first).filter(e => e.text === "Halten").length === 1, 2000, "the begun entry is saved")

        // A page from the pane goes on the window's stack.
        verify(pane.item.Kirigami.PageStack.pageStack === window.pageStack)
        const depth = window.pageStack.depth
        const deleteAction = pane.item.actions.find(a => a.objectName === "deleteCourse")
        verify(host.actions.some(a => a === deleteAction), "the notebook's actions in the head")

        // The notebook deleted: the host stays, the next one stands there.
        Courses.remove(second)
        tryVerify(() => !pane.item || pane.item.uid !== second)
        compare(window.pageStack.depth, depth)
        compare(window.pageStack.currentItem, host)
        Courses.remove(first)
        if (Courses.notebooks.length === 0) {
            tryVerify(() => !pane.item, 2000, "no notebook, nothing to show")
            verify(findChild(host, "paneEmpty").visible)
        }
        popPage()
    }
    // A device turns in one geometry change: both sides at once.
    function turn(width, height) {
        window.setGeometry(window.x, window.y, width, height)
    }
    // A notebook beside the list.
    function bookBeside(uid) {
        const host = listHost("CoursesPage.qml", 1280, 800)
        findChild(host, "listPane").item.open(uid)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.uid === uid)
        return host
    }

    // Turned: the same page lives on with what is typed in it. Upright it fills the window, Back
    // leads to the list.
    function test_8s_courses_turned() {
        const uid = testCourse("Gedreht")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const list = findChild(host, "listPane")
        const book = pane.item
        const depth = window.pageStack.depth
        findChild(book, "courseCompose").text = "Beim Drehen"

        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        compare(pane.item, book, "the same page")
        compare(window.pageStack.depth, depth)
        verify(host.showsPage)
        verify(!list.visible)
        verify(pane.visible)
        compare(pane.width, host.width)
        compare(host.title, "Notebook")
        verify(host.actions.some(a => a.objectName === "deleteCourse"), "its actions in the head")
        compare(overflowing(host, 800), [])
        compare(findChild(book, "courseCompose").text, "Beim Drehen")
        compare(Courses.entries(uid).length, 0, "no entry from a turn")

        turn(1280, 800)
        tryVerify(() => host.wide)
        wait(200)
        compare(pane.item, book, "beside the list again")
        verify(list.visible)
        verify(!host.showsPage)

        // Upright, Back goes to the list, on the same page of the stack; a row leads back.
        turn(800, 1280)
        tryVerify(() => !host.wide)
        window.pageStack.goBack()
        tryVerify(() => !host.showsPage)
        tryVerify(() => window.pageStack.currentItem === host)
        compare(window.pageStack.depth, depth)
        verify(list.visible)
        compare(host.title, "Courses")
        list.item.open(uid)
        tryVerify(() => host.showsPage && pane.item && pane.item.uid === uid)
        compare(window.pageStack.depth, depth)
        findChild(pane.item, "courseCompose").text = ""
        window.pageStack.goBack()
        tryVerify(() => !host.showsPage)
        popPage()
        Courses.remove(uid)
    }

    // An open editor (on the window's overlay) holds the columns against the keyboard too.
    function test_8s_editor_holds_columns() {
        const uid = testCourse("Bearbeiten")
        verify(Courses.addEntry(uid, "Erster"))
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const book = pane.item
        const depth = window.pageStack.depth
        const editor = findChild(book, "noteEditor")
        tryVerify(() => book.entries.length === 1)
        editor.edit(book.entries[0])
        tryVerify(() => editor.opened)
        window.height = 400
        tryVerify(() => host.height < Tablet.minHeight)
        wait(200)
        verify(host.wide, "still beside the list")
        compare(pane.item, book, "the same page")
        verify(editor.opened)
        compare(window.pageStack.depth, depth)
        editor.close()
        window.contentItem.forceActiveFocus()
        window.height = 800
        wait(200)
        popPage()
        Courses.remove(uid)
    }

    // A photo with a turn while the camera stands above: the entry gets it, no file left over.
    function test_8s_photo_turned() {
        failOnWarning(/ReferenceError|TypeError/)
        const uid = testCourse("Foto gedreht")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const book = pane.item
        const depth = window.pageStack.depth
        findChild(book, "courseCompose").text = "Griff"
        findChild(book, "courseMedia").takePhoto()
        tryVerify(() => window.pageStack.depth === depth + 1, 3000, "the camera page")
        const camera = window.pageStack.currentItem
        compare(camera.title, "Photo")
        wait(300)

        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        const name = Media.importPhoto("file://" + testMediaDir + "/foto.png")
        camera.done(name)
        popPage()
        tryCompare(window.pageStack, "depth", depth)
        compare(pane.item, book)
        tryVerify(() => Courses.entries(uid).some(e => e.media === name && e.text === "Griff"), 2000, "the photo reached the entry")
        verify(Media.exists(name))
        verify(host.showsPage, "the page it came from")

        turn(1280, 800)
        tryVerify(() => host.wide)
        popPage()
        Courses.remove(uid)
    }

    // The same for a notebook that stood there by itself: back on it, not on the list.
    function test_8s_photo_turned_first() {
        const uid = testCourse("Foto von selbst")
        const host = listHost("CoursesPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.uid !== undefined)
        verify(!host.chosen)
        const book = pane.item
        const depth = window.pageStack.depth
        findChild(book, "courseMedia").takePhoto()
        tryVerify(() => window.pageStack.depth === depth + 1, 3000, "the camera page")
        wait(300)
        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        popPage()
        tryCompare(window.pageStack, "depth", depth)
        verify(host.showsPage, "back on the notebook")
        verify(book.visible)
        window.pageStack.goBack()
        tryVerify(() => !host.showsPage)
        turn(1280, 800)
        tryVerify(() => host.wide)
        popPage()
        Courses.remove(uid)
    }

    // A page that is busy (a recording) finishes before another row takes its place, and before
    // Back leaves it; a turn leaves it running and in sight.
    function test_8s_busy_page_finishes() {
        const host = listHost("SettingsPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        const depth = window.pageStack.depth
        const busyPage = Qt.resolvedUrl("BusyPane.qml")
        verify(host.show(busyPage))
        tryVerify(() => pane.item && pane.item.title === "Busy")
        const busy = pane.item

        // Its own row again: nothing to finish.
        verify(host.show(busyPage))
        wait(100)
        compare(pane.item, busy)
        compare(busy.finishAsked, 0)

        mouseClick(findChild(host, "backupButton"))
        wait(200)
        compare(pane.item, busy, "the row waits")
        compare(busy.finishAsked, 1)
        busy.busy = false
        tryVerify(() => pane.item && pane.item.title === "Backup and sync", 2000, "and then comes")

        // Back beside the list: finishes, stays.
        verify(host.show(busyPage))
        tryVerify(() => pane.item && pane.item.title === "Busy")
        window.pageStack.goBack()
        wait(200)
        compare(window.pageStack.currentIndex, depth - 1)
        compare(pane.item.finishAsked, 1)

        // Turned: on, in sight; Back upright finishes, then the list.
        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        compare(pane.item.title, "Busy")
        verify(host.showsPage)
        window.pageStack.goBack()
        wait(200)
        verify(host.showsPage, "still recording")
        compare(pane.item.finishAsked, 2)
        pane.item.busy = false
        tryVerify(() => !host.showsPage)
        turn(1280, 800)
        tryVerify(() => host.wide)

        // What stood there by itself, busy, comes along too.
        verify(host.show(busyPage))
        tryVerify(() => pane.item && pane.item.title === "Busy")
        host.first = host.chosen
        host.chosen = null
        wait(100)
        verify(pane.item.busy)
        turn(800, 1280)
        tryVerify(() => host.showsPage, 2000, "a recording stays in sight")
        pane.item.busy = false
        host.chosen = null
        host.first = null
        turn(1280, 800)
        tryVerify(() => host.wide)
        popPage()
    }

    // Left in mid-recording, a page leaves no file behind (no microphone here: a file stands in).
    function test_8s_leaving_discards_voice() {
        const uid = testCourse("Stimme")
        const other = testCourse("Andere")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const media = findChild(pane.item, "courseMedia")
        const name = Media.importPhoto("file://" + testMediaDir + "/foto.png")
        verify(Media.exists(name))
        media.voiceName = name
        findChild(host, "listPane").item.open(other)
        tryVerify(() => pane.item && pane.item.uid === other)
        tryVerify(() => !Media.exists(name), 3000, "the unfinished recording goes")
        popPage()
        Courses.remove(uid)
        Courses.remove(other)
    }

    // What stands there by itself stays when a sync brings a notebook that sorts first.
    function test_8s_first_pane_stays() {
        const uid = testCourse("Zuerst")
        const host = listHost("CoursesPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.uid !== undefined)
        const book = pane.item
        const early = Courses.create("Früh", "1999-01-05", "1999-01-06", "", "")
        const late = Courses.create("Spät", "2099-01-05", "2099-01-06", "", "")
        wait(300)
        compare(pane.item, book, "the same page")
        popPage()
        for (const made of [uid, early, late]) {
            Courses.remove(made)
        }
    }

    // New course with the keyboard open: it lands beside the list.
    function test_8s_new_course_with_keyboard() {
        const host = listHost("CoursesPage.qml", 1280, 800)
        const list = findChild(host, "listPane").item
        const depth = window.pageStack.depth
        const made = window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/CourseNewPage.qml"), { paneHost: list.paneHost })
        tryVerify(() => findChild(made, "courseTitleField"))
        const field = findChild(made, "courseTitleField")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = "Mit Tastatur"
        tryVerify(() => made.complete)
        window.height = 400
        tryVerify(() => host.height < Tablet.minHeight)
        wait(200)
        made.make()
        tryCompare(window.pageStack, "depth", depth)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.course.title === "Mit Tastatur", 2000, "beside the list")
        const uid = pane.item.uid
        window.contentItem.forceActiveFocus()
        window.height = 800
        wait(200)
        popPage()
        Courses.remove(uid)
    }

    // Typing on a page above: the window drops, the half sentence below stays a draft.
    function test_8s_half_sentence_stays_draft() {
        const uid = testCourse("Halb")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const book = pane.item
        findChild(book, "courseCompose").text = "Halber Sa"
        const above = window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/CourseNewPage.qml"), { paneHost: host })
        tryVerify(() => findChild(above, "courseTitleField"))
        const field = findChild(above, "courseTitleField")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        window.height = 400
        tryVerify(() => host.height < Tablet.minHeight)
        wait(200)
        compare(pane.item, book, "the same page")
        compare(Courses.entries(uid).length, 0, "no entry")
        compare(findChild(book, "courseCompose").text, "Halber Sa")
        popPage()
        window.contentItem.forceActiveFocus()
        window.height = 800
        wait(200)
        findChild(book, "courseCompose").text = ""
        popPage()
        Courses.remove(uid)
    }

    // A new width alone (a window resized) is no turn: the columns and the page stay.
    function test_8r_width_alone_no_turn() {
        const uid = testCourse("Breite")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        const book = pane.item
        const depth = window.pageStack.depth
        const field = findChild(book, "courseCompose")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = "Halb"
        window.height = 400
        tryVerify(() => host.height < Tablet.minHeight)
        wait(200)
        window.width = 1200
        tryVerify(() => host.width === 1200)
        wait(200)
        verify(host.wide, "still beside the list")
        compare(pane.item, book, "the same page")
        compare(window.pageStack.depth, depth)
        compare(Courses.entries(uid).length, 0, "no entry")
        verify(field.activeFocus)
        field.text = ""
        window.contentItem.forceActiveFocus()
        window.height = 800
        wait(200)
        popPage()
        Courses.remove(uid)
    }

    // A notebook deleted with a draft in it: no error about the entry that could not be saved.
    function test_8s_deleted_with_draft() {
        const uid = testCourse("Weg")
        const host = bookBeside(uid)
        const pane = findChild(host, "pagePane")
        findChild(pane.item, "courseCompose").text = "Entwurf"
        compare(Courses.errorString, "")
        verify(Courses.remove(uid))
        tryVerify(() => !pane.item || pane.item.uid !== uid)
        wait(100)
        compare(Courses.errorString, "")
        popPage()
    }

    // Fields typed beside the list come through a turn: the page stays in sight, the field keeps
    // the focus. A code stays in its field, also behind the row.
    function test_8s_fields_survive_turn() {
        const host = listHost("SettingsPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.title === "Videos")
        const videos = pane.item
        const field = findChild(videos, "codeField")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        field.text = "ABCDE"
        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        compare(pane.item, videos)
        verify(host.showsPage, "in use: in sight")
        verify(field.activeFocus)
        compare(field.text, "ABCDE")
        window.pageStack.goBack()
        tryVerify(() => !host.showsPage)
        mouseClick(findChild(host, "videosButton"))
        tryVerify(() => host.showsPage)
        compare(pane.item, videos, "the row finds the same page")
        compare(findChild(videos, "codeField").text, "ABCDE")
        findChild(videos, "codeField").text = ""
        window.pageStack.goBack()
        tryVerify(() => !host.showsPage)

        // A chosen page, upright and back.
        turn(1280, 800)
        tryVerify(() => host.wide)
        Sync.enabled = true
        mouseClick(findChild(host, "backupButton"))
        tryVerify(() => pane.item && pane.item.title === "Backup and sync")
        const backup = pane.item
        const server = findChild(backup, "syncServer")
        server.text = "https://halb.example.org/"
        turn(800, 1280)
        tryVerify(() => !host.wide)
        wait(200)
        compare(pane.item, backup)
        compare(server.text, "https://halb.example.org/")
        turn(1280, 800)
        tryVerify(() => host.wide)
        wait(200)
        compare(pane.item, backup)
        compare(server.text, "https://halb.example.org/")
        Sync.enabled = false
        popPage()
    }
    function test_8s_courses_only_list_data() {
        return [ { tag: "360", width: 360, height: 800 }, { tag: "320", width: 320, height: 800 } ]
    }
    function test_8s_courses_only_list(data) {
        const uid = testCourse("Telefon")
        const host = listHost("CoursesPage.qml", data.width, data.height)
        compare(host.title, "Courses")
        verify(host.actions.length >= 2, "the list's actions")
        compare(overflowing(host, data.width), [])
        findChild(host, "listPane").item.open(uid)
        tryVerify(() => window.pageStack.currentItem !== host && window.pageStack.currentItem.uid === uid)
        popPage()
        tryVerify(() => window.pageStack.currentItem === host)
        popPage()
        Courses.remove(uid)
    }
    // New course on a tablet: it stands beside the list afterwards.
    function test_8s_new_course_beside_list() {
        const host = listHost("CoursesPage.qml", 1280, 800)
        const list = findChild(host, "listPane").item
        const depth = window.pageStack.depth
        const made = window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/CourseNewPage.qml"), { paneHost: list.paneHost })
        tryVerify(() => findChild(made, "courseTitleField"))
        findChild(made, "courseTitleField").text = "Neu am Tablet"
        tryVerify(() => made.complete)
        made.make()
        tryCompare(window.pageStack, "depth", depth)
        const pane = findChild(host, "pagePane")
        tryVerify(() => pane.item && pane.item.course.title === "Neu am Tablet")
        const uid = pane.item.uid
        popPage()
        Courses.remove(uid)
    }

    // Turned while a field is typed in: the new shape counts, the hold starts anew.
    function test_8r_turned_while_typing() {
        window.width = 1280
        window.height = 800
        wait(100)
        const page = push("GradesPage")
        tryVerify(() => page.wide)
        const field = findChild(page, "gradePlace")
        field.forceActiveFocus()
        tryVerify(() => field.activeFocus)
        turn(800, 1280)
        tryVerify(() => !page.wide, 2000, "upright: one column")
        window.height = 780
        wait(200)
        verify(!page.wide, "the keyboard, upright: still one column")
    }

    function test_8o_nothing_past_the_edge_data() {
        // Twice the scale on a phone (206 px) is not there yet: ROADMAP, QA round of 5 Nov 2026.
        return [{ tag: "360", width: 360, height: 800 }]
    }
    function test_8o_nothing_past_the_edge(data) {
        const w = window.width, h = window.height
        window.width = data.width
        window.height = data.height
        wait(200)
        Programme.discipline = "shinkitoho"
        PracticeGrade.setGrade("shinkitoho", "shoden")
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const report = {}
        const look = (name, item) => {
            // The page has slid in: while it moves everything looks past the edge.
            const onStack = window.pageStack.currentItem === item
            tryVerify(() => !onStack || Math.abs(item.mapToItem(window.contentItem, 0, 0).x) < 1, 3000)
            wait(300)
            // A slow machine (the CI's first player) may still be moving it by a few pixels: what
            // counts is the edge of the page, wherever the page is just now.
            const moved = onStack ? item.mapToItem(window.contentItem, 0, 0).x : 0
            const over = overflowing(item, data.width + moved)
            if (over.length) {
                report[name] = over.slice(0, 6)
            }
        }
        look("start", window.pageStack.currentItem)
        const round = Exam.draw("aikido", "k5", 3, 0)
        for (const [file, props] of [["ProgrammePage", {}], ["TodayPage", {}], ["StatsPage", {}], ["YearsPage", {}], ["AllNotesPage", {}],
                                     ["TechniqueMapPage", {}], ["SearchPage", {}], ["CoursesPage", {}], ["NotebooksPage", {}], ["GradesPage", {}],
                                     ["SettingsPage", {}], ["BackupPage", {}], ["VideosPage", {}], ["ScanPage", {}], ["AppearancePage", {}], ["ExamPage", {}],
                                     ["ExamRoundPage", { points: round, discipline: "aikido", grade: "k5" }],
                                     ["ExamEndPage", { points: round, discipline: "aikido", grade: "k5" }],
                                     ["TrainingEndPage", { count: 12 }],
                                     ["NotesPage", { entry: rows[0] }], ["WelcomePage", {}],
                                     ["TechniquePickerPage", { course: "none", entryUid: "none" }],
                                     ["PlayerPage", { playlist: rows, index: 0 }]]) {
            const page = push(file, props)
            look(file, page)
            if (file === "PlayerPage") {
                // Room to spare: another font (the CI's) needs more than this machine's.
                verify(findChild(page, "neighbourRow").implicitWidth < data.width * 0.75)
            }
            if (file === "ProgrammePage") {
                page.open(page.rows.find(r => r.id === "shinkitoho/odachi/5"))
                const sheet = findChild(page, "techniqueSheet")
                tryVerify(() => sheet.opened)
                look("sheet", sheet.contentItem)
                // The head has the style's colours, as the content (it lies beside it).
                verify(Qt.colorEqual(sheet.header.Kirigami.Theme.textColor, sheet.contentItem.Kirigami.Theme.textColor))
                const sheetClose = findChild(sheet.header, "sheetClose")
                verify(sheetClose && sheetClose.visible !== sheet.shinkiSheet)
                sheet.close()
                tryVerify(() => !sheet.visible)
            }
            popPage()
            wait(50)
        }
        Programme.discipline = "aikido"
        window.width = w
        window.height = h
        wait(200)
        compare(JSON.stringify(report), "{}")
    }

    // From anywhere the player has the whole grade around the technique: previous and next work.
    function test_8n_player_has_the_grade() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length < 2 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const page = push("SearchPage")
        const sheet = findChild(page, "techniqueSheet")
        sheet.entry = rows[1]
        sheet.playRequested(rows[1])
        tryVerify(() => window.pageStack.currentItem.playlist !== undefined)
        const player = window.pageStack.currentItem
        verify(player.playlist.length > 1, player.playlist.length)
        compare(player.playlist[player.index].id, rows[1].id)
        window.back()
        tryVerify(() => window.pageStack.currentItem === page)
        popPage()
    }

    function test_8m_today_has_its_calendar() {
        const page = push("TodayPage")
        const heat = findChild(page, "todayHeatmap")
        verify(heat.visible)
        compare(heat.weeks, 12)
        verify(findChild(page, "todayLegend").visible, "no diagram without a legend")
        popPage()
    }

    // The letter of the rail, as an item to tap.
    function railLetter(rail, letter) {
        return findChildren(rail, "railLetter").find(c => c.modelData === letter)
    }

    function test_8l_glossary_letters_jump() {
        const page = push("SearchPage")
        const list = findChild(page, "glossaryList")
        const rail = findChild(page, "letterRailPhone")
        tryVerify(() => rail.visible)
        verify(!findChild(page, "letterRail").visible, "the left rail is for a wide window")
        wait(500)
        const far = page.usedLetters[Math.floor(page.usedLetters.length * 0.6)]     // the last sections are too short to reach the top
        mouseClick(railLetter(rail, far))
        tryVerify(() => list.contentY > list.height, 1000, "jumped to " + far + ": " + list.contentY)
        tryCompare(list, "currentSection", far)

        // The head changes height after the jump (the window narrows: texts wrap anew): the list
        // stays at the letter.
        window.width = 340
        waitForRendering(list)
        verify(list.contentY > list.height, "stays at " + far + " in the narrow window: " + list.contentY)
        window.width = 420
        waitForRendering(list)
        verify(list.contentY > list.height, "stays at " + far + ": " + list.contentY)

        // The head grows (the hints wrap in a narrower window) while the list stands where the wheel
        // left it (it sets contentY, no flick): it stays there.
        const header = list.headerItem
        const before = header.height
        list.positionViewAtBeginning()
        list.contentY = list.originY + 3 * list.height
        const scrolled = list.contentY
        window.width = 320
        tryVerify(() => header.height > before, 1000, "the head grows: " + header.height)
        waitForRendering(list)
        verify(list.contentY > list.height, "stays where the wheel left it (" + scrolled + "): " + list.contentY)
        window.width = 420
        tryVerify(() => header.height === before, 1000, "the head shrinks: " + header.height)

        // At the top, the list stays at its top while the head grows.
        list.positionViewAtBeginning()
        window.width = 320
        tryVerify(() => header.height > before, 1000, "the head grows at the top: " + header.height)
        tryVerify(() => list.atYBeginning, 1000, "at the top: " + list.contentY + " from " + list.originY)
        window.width = 420
        tryVerify(() => list.atYBeginning, 1000, "at the top again: " + list.contentY + " from " + list.originY)

        // Far down, then a search: its results from the top, no rail.
        mouseClick(railLetter(rail, far))
        verify(list.contentY > list.height, "jumped again: " + list.contentY)
        findChild(page, "searchField").text = "ko"
        tryCompare(page, "searching", true)
        verify(!rail.visible, "words found have no letters")
        tryVerify(() => list.atYBeginning, 1000, "results from the top: " + list.contentY + " from " + list.originY)
        popPage()
    }

    function test_8k_sheet_says_where_the_dvd_is() {
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        page.open(page.rows.find(r => r.kind === "entry" && r.video))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        if (!sheet.hasVideo) {
            verify(findChild(sheet.contentItem, "sheetDvdButton").visible)
        }
        sheet.close()
        tryVerify(() => !sheet.visible)
        popPage()
    }

    function test_8q_search_row_without_attack() {
        const page = push("SearchPage")
        const field = findChild(page, "searchField")
        field.text = "odachi"
        tryVerify(() => findChildren(page, "techniqueResult").length > 0, 3000)
        for (const row of findChildren(page, "techniqueResult")) {
            verify(row.subtitle.indexOf("undefined") < 0, row.subtitle)
        }
        popPage()
    }

    // The main thread held up during a slide, then a pop (a busy machine): see popPage. A guard of
    // that helper only: popPage waits, so this cannot crash while it does. Without the wait it
    // crashed in about 1 of 40 rounds, so 5 rounds will rarely catch it either.
    function test_8q_pop_after_a_stall() {
        const kStallMs = 450
        for (let round = 0; round < 5; ++round) {
            const page = push("SearchPage")
            findChild(page, "searchField").forceActiveFocus()
            const started = Date.now()
            while (Date.now() - started < kStallMs) {
                // Nothing: no event, no animation step.
            }
            popPage()
            tryCompare(window.pageStack, "depth", 1)
        }
        verify(window.pageStack.currentItem !== null)
    }

    // 360 px: the sheet's buttons wrap, nothing runs off the screen.
    function test_8r_sheet_fits_small_phone() {
        const width = window.width
        window.width = 360
        wait(100)
        Programme.discipline = "shinkitoho"
        const page = push("ProgrammePage")
        page.open(page.rows.find(r => r.kind === "entry"))
        const sheet = findChild(page, "techniqueSheet")
        tryVerify(() => sheet.opened)
        const notes = findChild(sheet, "sheetNotesButton")
        const edge = notes.mapToItem(sheet.parent, notes.width, 0).x
        verify(edge <= sheet.parent.width + 0.5, "the button ends at " + edge)
        verify(sheet.width <= sheet.parent.width + 0.5, "the sheet is " + sheet.width)
        sheet.close()
        tryVerify(() => !sheet.visible)
        popPage()
        Programme.discipline = "aikido"
        window.width = width
        wait(100)
    }

    function test_8s_welcome_counts_when_finished() {
        const page = push("WelcomePage")
        const steps = findChild(page, "welcomeSteps")
        page.step = 1
        // The arrow in the head goes one step, not out of the wizard.
        window.back()
        tryCompare(page, "step", 0)
        wait(50)
        verify(window.pageStack.currentItem === page, "still in the wizard")
        page.finish()
        verify(Appearance.welcomed, "without waiting for the page to be destroyed")
        tryCompare(window.pageStack, "depth", 1)
    }

    function test_8t_player_rests_under_the_notes() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video && Videos.available(r.video.video))
        if (rows.length === 0) {
            skip("no videos")
        }
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        tryVerify(() => player.playing, 5000)
        findChild(player, player.kino ? (player.upright ? "kinoNotes" : "kinoNotesButton") : "openNotes").clicked()
        tryVerify(() => !player.playing, 2000)
        popPage()
        popPage()
    }

    // A window turned for full screen is no longer wide: the pane comes back only afterwards, and
    // then takes up the place, tempo and loop; a technique played since then outdates them.
    function test_8t_pane_made_anew_after_full_screen() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length < 2 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const width = window.width, height = window.height
        window.width = 700
        window.height = 800
        wait(100)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        tryVerify(() => !page.split)
        page.lastId = rows[0].id
        // What full screen left while there is no pane.
        const chapter = Programme.entries("aikido", "k5").find(r => r.id === rows[0].id).video
        const place = (chapter.von || 0) * 1000 + 3000
        page.bigResume = { position: place, rate: 0.5, looping: false }
        page.resumeFromBig()
        verify(page.bigResume !== null, "kept until the pane is there")
        window.width = 1280
        tryVerify(() => page.player && page.player.duration > 0, 5000)
        compare(page.player.looping, false)
        compare(page.player.rate, 0.5)
        verify(page.player.position >= page.player.from, page.player.position)
        verify(Math.abs(page.player.position - place) < 1500,
               page.player.position + " from " + page.player.from + " to " + page.player.to)
        verify(page.bigResume === null, "taken up once")

        // Another technique in between: nothing is left to take up.
        window.width = 700
        tryVerify(() => !page.split)
        page.bigResume = { position: 3000, rate: 0.5, looping: false }
        page.lastId = rows[1].id
        verify(page.bigResume === null)
        popPage()
        window.width = width
        window.height = height
        wait(100)
    }

    // Tablet: the small player goes on where full screen ended, with its tempo and loop.
    function test_8t_small_player_keeps_place_after_full_screen() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        if (rows.length === 0 || !Videos.available(rows[0].video.video)) {
            skip("no video for Aikido 5. Kyu (set MITORI_VIDEOS)")
        }
        const width = window.width
        window.width = 1280
        window.height = 800
        wait(200)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        const page = push("ProgrammePage")
        page.play(rows[0])
        tryVerify(() => page.player && page.player.hasVideo && page.player.duration > 0, 5000)
        const small = page.player
        small.looping = false
        small.setSpeed(0.5)
        page.openBig()
        const big = window.pageStack.currentItem
        tryVerify(() => big.big && big.duration > 0, 5000)
        compare(big.rate, 0.5)
        compare(big.looping, false)
        const place = Math.min(big.to - 500, big.from + 3000)
        big.seek(place)
        big.setSpeed(0.25)
        big.togglePlay()
        tryVerify(() => !big.playing, 2000)
        const reached = big.position
        // Back ends it too (the Android key), not only the button.
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem === page)
        // The pane may have been made anew while the window was full screen: its place comes when
        // its clip has loaded.
        tryVerify(() => page.player && Math.abs(page.player.position - reached) < 1500, mediaLoads, "the place of " + reached)
        const after = page.player
        compare(after.rate, 0.25)
        compare(after.looping, false)

        // It stands there, as the big one did; it did not just pass the place.
        staysStanding(after, "the small player stands")
        verify(Math.abs(after.position - reached) < 1500, after.position + " against " + reached)
        popPage()
        window.width = width
        wait(200)
    }

    function test_8u_exam_cancel_at_first_point() {
        const points = Exam.draw("aikido", "k5", 3, 0)
        const page = push("ExamRoundPage", { points: points, discipline: "aikido", grade: "k5" })
        page.cancel()
        tryVerify(() => window.pageStack.currentItem !== page, 2000, "at point 1 there is nothing to lose")
    }

    function test_8u_exam_cancel_asks_after_first_point() {
        const points = Exam.draw("aikido", "k5", 3, 0)
        const page = push("ExamRoundPage", { points: points, discipline: "aikido", grade: "k5" })
        page.next()
        page.cancel()
        const dialog = findChild(page, "cancelRoundDialog")
        tryVerify(() => dialog.opened)
        compare(window.pageStack.currentItem, page)
        compare(dialog.acceptText, qsTr("Discard"), "Cancel in a dialog about cancelling says nothing")
        compare(dialog.standardButton(QQC2.Dialog.Cancel).text, qsTr("Keep the round"), "its way out says where it goes")
        dialog.reject()
        tryVerify(() => !dialog.visible)
        window.back()
        tryVerify(() => dialog.opened, 2000, "Back too")
        dialog.accept()
        tryVerify(() => window.pageStack.currentItem !== page)
        wait(50)
    }

    function test_8v_exam_end_says_what_is_open() {
        const points = Exam.draw("aikido", "k5", 3, 0)
        const page = push("ExamEndPage", { points: points, discipline: "aikido", grade: "k5" })
        const open = findChild(page, "openPoints")
        verify(open.visible)
        verify(open.text.indexOf(String(points.length)) >= 0, open.text)
        points.forEach((p, i) => page.rate(i, 3))
        verify(!open.visible)
        tryVerify(() => findChild(page, "applyRound").enabled)
        popPage()
    }

    function test_8w_voice_hint_only_with_the_glossary() {
        const page = push("SearchPage")
        const hint = findChild(page, "speechHint")
        const shown = hint.visible
        findChild(page, "searchField").text = "ko"
        tryCompare(page, "searching", true)
        verify(!hint.visible, "not above every result")
        popPage()
        verify(shown !== undefined)
    }

    function test_8x_stats_say_it_once() {
        const page = push("StatsPage")
        for (const text of findChildren(page, "readyText")) {
            verify(!text.visible, "the figure stands beside the grade")
        }
        popPage()
    }

    // A technique starts at 1×: next, previous, a jump, a new page. Staying in it keeps the tempo.
    function test_8y_new_technique_starts_at_1x() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const player = push("PlayerPage", { playlist: rows, index: 1 })
        compare(player.rate, 1)
        player.setSpeed(0.5)
        compare(player.tempoText, (0.5).toLocaleString(Qt.locale(), "f", 1) + "\u00D7")
        player.go(1)
        compare(player.rate, 1, "next")
        player.setSpeed(0.5)
        player.go(-1)
        compare(player.rate, 1, "previous")
        player.setSpeed(0.25)
        player.index = 3
        compare(player.rate, 1, "a jump in the list")

        // The same technique in a playlist made anew: no new technique.
        player.setSpeed(0.25)
        player.playlist = rows.map(r => Object.assign({}, r))
        compare(player.current.id, rows[3].id)
        compare(player.rate, 0.25)

        window.back()
        tryVerify(() => window.pageStack.currentItem !== player)
        wait(50)
        const again = push("PlayerPage", { playlist: rows, index: 3 })
        compare(again.rate, 1, "a new page, as a new start of the app")
        window.back()
        wait(50)
    }

    // Small player and full screen hand over tempo and loop; the next technique starts at 1×.
    function test_8y_full_screen_keeps_tempo() {
        const page = tabletProgramme()
        const small = page.player
        small.looping = false
        small.setSpeed(0.5)
        page.openBig()
        const big = window.pageStack.currentItem
        tryVerify(() => big.big)
        compare(big.rate, 0.5)
        compare(big.looping, false)
        big.setSpeed(0.25)
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem === page)
        tryVerify(() => page.player !== null)
        compare(page.player.rate, 0.25)
        compare(page.player.looping, false)

        // Full screen moved on: the small player follows, at that technique's tempo.
        page.openBig()
        const big2 = window.pageStack.currentItem
        tryVerify(() => big2.big)
        compare(big2.rate, 0.25)
        big2.go(1)
        compare(big2.rate, 1)
        const moved = big2.current.id
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem === page)
        tryVerify(() => page.player !== null)
        compare(page.player.current.id, moved)
        compare(page.player.rate, 1)

        // A row chosen after that: 1× again.
        page.player.setSpeed(0.5)
        page.open(page.playlist[0])
        compare(page.player.rate, 1)
    }

    // Turning the tablet or narrowing the window makes the pane anew: still the same technique,
    // so the same tempo. A technique chosen, or a player page opened, in between starts at 1×.
    function test_8y_new_pane_keeps_tempo() {
        const page = tabletProgramme()
        const remake = (width, height) => {
            window.width = width
            window.height = height
            tryVerify(() => !page.split)
            window.width = 1280
            window.height = 800
            tryVerify(() => page.split && page.player, paneLoads)
        }
        const old = page.player
        const chosen = page.player.current.id
        page.player.setSpeed(0.5)
        remake(800, 1280)
        verify(page.player !== old, "a new pane")
        compare(page.player.current.id, chosen)
        compare(page.player.rate, 0.5, "turned")
        remake(700, 800)
        compare(page.player.rate, 0.5, "window narrowed")

        page.player.go(1)
        compare(page.player.rate, 1, "the next technique")
        remake(800, 1280)
        compare(page.player.rate, 1, "its tempo, not the one before")

        // Upright: the same technique on a player page of its own, then turned back.
        page.player.setSpeed(0.25)
        window.width = 800
        window.height = 1280
        tryVerify(() => !page.split)
        page.play(page.rows.find(r => r.id === page.lastId))
        tryVerify(() => window.pageStack.currentItem !== page)
        compare(window.pageStack.currentItem.rate, 1)
        popPage()
        tryVerify(() => window.pageStack.currentItem === page)
        window.width = 1280
        window.height = 800
        tryVerify(() => page.split && page.player, paneLoads)
        compare(page.player.rate, 1, "after a new player page")
    }

    // The pane made anew after full screen takes up the tempo left there, not 1×.
    function test_8y_pane_made_anew_keeps_tempo() {
        const page = tabletProgramme()
        window.width = 700
        tryVerify(() => !page.split)
        page.bigResume = { position: 0, rate: 0.5, looping: false }
        window.width = 1280
        tryVerify(() => page.player !== null)
        compare(page.player.rate, 0.5)
        compare(page.player.looping, false)
    }

    function test_8z_frame_buttons_are_not_the_technique_buttons() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        const player = push("PlayerPage", { playlist: rows, index: 0 })
        for (const name of ["railFrameBack", "railFrameOn"]) {
            const b = findChild(player, name)
            if (b) {
                verify(!/skip/.test(b.symbol), b.symbol)
            }
        }
        window.back()
        wait(50)
    }

    // A note begun in the player belongs to the technique it was typed for, also when the player
    // moves on before it is added (training moves on after a rating).
    // Found by the QA round of 5 Nov 2026 (qa/PERSONAS.md).
    function test_8b_note_draft_stays_with_its_technique() {
        const page = playerAt(1)
        const first = page.current.id
        const field = findChild(page, "noteField")
        field.text = "für die erste Technik"
        page.go(1)
        verify(page.current.id !== first)
        compare(Practice.lastNote(first).text, "für die erste Technik", "saved for the technique it was typed for")
        verify(Practice.lastNote(page.current.id).text !== "für die erste Technik")
        compare(field.text, "", "the field is empty for the next technique")
        // Leaving the player keeps a draft as well.
        const second = page.current.id
        field.text = "beim Verlassen"
        window.back()
        tryVerify(() => Practice.lastNote(second).text === "beim Verlassen", 3000, "saved when the player closes")
        // Saved on the step back; the page goes a moment later (Main.back), not on the next case's.
        tryVerify(() => window.pageStack.currentIndex === window.pageStack.depth - 1)
    }

    // The Back key only steps the stack back and keeps the page (Kirigami's forward arrow), until
    // the next page or the app's end: a draft cannot wait for that, the system may kill the app.
    function test_8b_back_key_keeps_note_data() {
        return [{ tag: "phone", width: 420, height: 800, pane: false }, { tag: "beside the list", width: 1280, height: 800, pane: true }]
    }
    function test_8b_back_key_keeps_note(data) {
        useFolder(standInVideos)
        Programme.discipline = "aikido"
        PracticeGrade.setGrade("aikido", "k5")
        window.width = data.width
        window.height = data.height
        wait(100)
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry" && r.video)
        const list = data.pane ? push("ProgrammePage") : null
        if (list) {
            tryVerify(() => list.split && list.player)
        }
        const page = list ?? push("PlayerPage", { playlist: rows, index: 0 })
        const player = list ? list.player : page
        tryVerify(() => Math.abs(page.mapToItem(window.contentItem, 0, 0).x) < 1, 5000, "slid in")
        const id = player.current.id
        const field = findChild(player, "noteField")
        const text = "Back key " + data.tag
        field.text = text

        window.pageStack.goBack()
        tryVerify(() => Practice.lastNote(id).text === text, 5000, "saved when Back steps away")
    }

    // Beside the list: the entry begun on the right, by the Back key and by a plain pop.
    function test_8s_begun_entry_on_leaving_data() {
        return [{ tag: "Back key", back: () => window.pageStack.goBack() }, { tag: "pop", back: () => popPage() }]
    }
    function test_8s_begun_entry_on_leaving(data) {
        const uid = testCourse("Rechts " + data.tag)
        const host = listHost("CoursesPage.qml", 1280, 800)
        const pane = findChild(host, "pagePane")
        const list = findChild(host, "listPane")
        tryVerify(() => Math.abs(host.mapToItem(window.contentItem, 0, 0).x) < 1, 5000, "slid in")
        list.item.open(uid)
        tryVerify(() => pane.item && pane.item.uid === uid)
        findChild(pane.item, "courseCompose").text = "Halten"

        data.back()
        tryVerify(() => Courses.entries(uid).filter(e => e.text === "Halten").length === 1, 5000, "the begun entry is saved")
        verify(Courses.remove(uid))
    }

    // With the note field focused, the controls scroll it into view when the window shrinks
    // (the on-screen keyboard opens after the focus).
    function test_8c_note_field_above_keyboard() {
        const page = playerAt(0)                       // skips without videos, before the window changes
        // With a picture (Kino) the note field is in the middle of the upright player.
        window.width = page.kino ? 420 : 800
        window.height = page.kino ? 960 : 360
        wait(300)
        const view = findChild(page, page.kino ? "kinoMiddle" : "controlsView")
        const field = findChild(page.kino ? findChild(page, "kinoNote") : page, "noteField")
        field.forceActiveFocus()
        window.height = page.kino ? 560 : 200
        wait(300)
        const at = field.mapToItem(view, 0, 0)
        verify(at.y >= 0 && at.y + field.height <= view.height + 1, "field in view (" + at.y + ", " + view.height + ")")
        window.width = 420
        window.height = 800
        popPage()
    }

    // A text typed on a phone and not added: leaving asks (save, discard, stay). Whitespace does not.
    function test_8g_leaving_asks_data() {
        const goBack = () => window.pageStack.goBack()
        const head = () => window.back()                // Shinki's head, Kirigami's back button
        // What a swipe does (and a click on an earlier page in Kirigami's breadcrumb): the stack steps
        // back without backRequested. A touch swipe offscreen arrives in pieces, late or not at all.
        const step = () => { window.pageStack.currentIndex = window.pageStack.currentIndex - 1 }
        return [
            { tag: "notes, Back key", page: "NotesPage", field: "compose", back: goBack },
            { tag: "notes, head", page: "NotesPage", field: "compose", back: head },
            { tag: "notes, swipe", page: "NotesPage", field: "compose", back: step },
            { tag: "notebook, Back key", page: "CoursePage", field: "courseCompose", back: goBack },
            { tag: "notebook, head", page: "CoursePage", field: "courseCompose", back: head },
            { tag: "notebook, swipe", page: "CoursePage", field: "courseCompose", back: step }
        ]
    }
    function test_8g_leaving_asks(data) {
        // An entry no other case writes to.
        const entry = Programme.entries("aikido", "k5").filter(r => r.kind === "entry").slice(-1)[0]
        const uid = testCourse("Fragen " + data.tag)
        const props = data.page === "NotesPage" ? { entry: entry } : { uid: uid }
        const saved = () => data.page === "NotesPage" ? Practice.notes(entry.id).length : Courses.entries(uid).length
        const before = saved()
        const open = text => {
            const page = push(data.page, props)
            slidIn()
            findChild(page, data.field).text = text
            return page
        }

        // Typed: the page stays and asks; Cancel keeps the text.
        let page = open("Erst halb")
        data.back()
        // Back at once after the Back key; after a swipe once the view stands.
        tryVerify(() => window.pageStack.currentItem === page, 3000, "the page with typed text stays")
        const dialog = page.leaveAsk
        tryVerify(() => dialog.opened, 2000, "it asks")
        shot("8g-leaving-asks-" + data.page, true)
        dialog.reject()
        tryVerify(() => !dialog.visible)
        compare(window.pageStack.currentItem, page)
        compare(findChild(page, data.field).text, "Erst halb")

        // Discard: the page goes, nothing saved. Back in place first: a swipe in the slide is none.
        slidIn()
        data.back()
        tryVerify(() => dialog.opened)
        mouseClick(findChild(dialog.contentItem, "leaveDiscard"))
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "discarded, the page goes")
        compare(saved(), before)

        // Save: the text is kept, the page goes.
        page = open("Ganz gesagt")
        data.back()
        tryVerify(() => page.leaveAsk.opened)
        page.leaveAsk.accept()
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "saved, the page goes")
        compare(saved(), before + 1)

        // Nothing but spaces: no question.
        page = open("   ")
        data.back()
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "nothing to lose")
        wait(300)
        verify(!page.leaveAsk || !page.leaveAsk.opened, "not asked")
        Practice.notes(entry.id).filter(n => n.text === "Ganz gesagt").forEach(n => Practice.deleteNote(n.uid))
        verify(Courses.remove(uid))
    }

    // A new course half typed: Back asks before it is dropped.
    function test_8g_new_course_asks() {
        const count = Courses.notebooks.length
        let page = push("CourseNewPage")
        slidIn()
        findChild(page, "coursePlace").text = "Dojo Nord"
        window.pageStack.goBack()
        wait(300)
        verify(window.pageStack.currentItem === page, "the half typed course stays")
        const dialog = page.leaveAsk
        tryVerify(() => dialog.opened)
        compare(dialog.standardButton(QQC2.Dialog.Ok).text, qsTr("Discard"))
        dialog.reject()
        tryVerify(() => !dialog.visible)
        compare(findChild(page, "coursePlace").text, "Dojo Nord")
        window.back()
        tryVerify(() => dialog.opened)
        dialog.accept()
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "discarded")
        compare(Courses.notebooks.length, count)

        page = push("CourseNewPage")
        slidIn()
        window.pageStack.goBack()
        tryVerify(() => window.pageStack.currentItem !== page, 3000, "nothing typed, no question")
    }

    // A note changed in the editor and closed without saving (Escape, Back, ×, a tap beside it) asks;
    // Cancel opens the editor again with the change.
    function test_8g_editor_asks() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "Alt"))
        const page = push("NotesPage", { entry: entry })
        slidIn()
        const note = page.notes.find(n => n.text === "Alt")
        const editor = findChild(page, "noteEditor")
        const area = findChild(editor, "noteArea")
        const close = () => {
            area.forceActiveFocus()
            keyClick(Qt.Key_Escape)
        }

        // Unchanged: closes without a question.
        editor.edit(note)
        tryVerify(() => editor.opened)
        close()
        tryVerify(() => !editor.visible)
        wait(300)
        verify(!editor.leaveAsk || !editor.leaveAsk.opened, "nothing changed, no question")

        editor.edit(note)
        tryVerify(() => editor.opened)
        area.text = "Neu"
        close()
        tryVerify(() => editor.leaveAsk && editor.leaveAsk.opened, 2000, "the change asks")
        editor.leaveAsk.reject()
        tryVerify(() => editor.opened, 2000, "back to the editor")
        compare(area.text, "Neu")
        close()
        tryVerify(() => editor.leaveAsk.opened)
        mouseClick(findChild(editor.leaveAsk.contentItem, "leaveDiscard"))
        tryVerify(() => !editor.leaveAsk.visible && !editor.visible)
        verify(page.notes.some(n => n.uid === note.uid && n.text === "Alt"), "discarded")

        editor.edit(note)
        tryVerify(() => editor.opened)
        compare(area.text, "Alt")
        area.text = "Neu gesagt"
        close()
        tryVerify(() => editor.leaveAsk.opened)
        editor.leaveAsk.accept()
        tryVerify(() => page.notes.some(n => n.uid === note.uid && n.text === "Neu gesagt"), 2000, "saved")
        verify(Practice.deleteNote(note.uid))
        popPage()
    }

    // The editor's question while the window closes: (1) the editor is already shut (Escape) and its
    // question stands, the change not yet saved; (2) Save fails (a database error, here a save that
    // says false): the window stays, and a later Discard does not close it unasked.
    function test_8g_editor_question_holds_window() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "Fenster alt"))
        const page = push("NotesPage", { entry: entry })
        slidIn()
        const note = page.notes.find(n => n.text === "Fenster alt")
        const editor = findChild(page, "noteEditor")
        const area = findChild(editor, "noteArea")
        const ask = editor.leaveAsk
        const escape = () => {
            area.forceActiveFocus()
            keyClick(Qt.Key_Escape)
        }

        // (1) Escape: the editor shuts, its question stands.
        editor.edit(note)
        tryVerify(() => editor.opened)
        area.text = "Fenster neu"
        escape()
        tryVerify(() => ask.opened && !editor.visible)
        let closed = false
        verify(!window.mayClose(() => { closed = true }), "the standing question holds the window")
        tryVerify(() => ask.opened)
        ask.accept()
        tryVerify(() => closed, 2000, "saved, then the window closes")
        verify(page.notes.some(n => n.uid === note.uid && n.text === "Fenster neu"))
        verify(Practice.deleteNote(note.uid))
        popPage()
    }
    // Right after Escape the question fades in (opened only at its end): it holds the window already.
    function test_8g_question_fading_in_holds_window() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "Blende alt"))
        const page = push("NotesPage", { entry: entry })
        slidIn()
        const note = page.notes.find(n => n.text === "Blende alt")
        const editor = findChild(page, "noteEditor")
        const area = findChild(editor, "noteArea")
        const ask = editor.leaveAsk
        editor.edit(note)
        tryVerify(() => editor.opened)
        area.text = "Blende neu"
        area.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        tryVerify(() => ask.visible)
        let closed = false
        verify(!window.mayClose(() => { closed = true }), "the question fading in holds the window")
        tryVerify(() => ask.opened)
        mouseClick(findChild(ask.contentItem, "leaveDiscard"))
        tryVerify(() => closed && !ask.visible, 2000, "discarded, then the window closes")
        verify(Practice.deleteNote(note.uid))
        popPage()
    }
    // Saved or deleted with the editor's own buttons: while it fades out the window has nothing to ask.
    function test_8g_editor_buttons_leave_nothing() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "Knopf alt"))
        const page = push("NotesPage", { entry: entry })
        slidIn()
        const note = page.notes.find(n => n.text === "Knopf alt")
        const editor = findChild(page, "noteEditor")
        const area = findChild(editor, "noteArea")

        editor.edit(note)
        tryVerify(() => editor.opened)
        area.text = "Knopf neu"
        editor.customFooterActions[1].trigger()         // Save
        verify(window.mayClose(() => {}), "saved: nothing to ask")
        tryVerify(() => !editor.visible)

        editor.edit(page.notes.find(n => n.uid === note.uid))
        tryVerify(() => editor.opened)
        area.text = "Knopf weg"
        editor.customFooterActions[0].trigger()         // Delete
        verify(window.mayClose(() => {}), "deleted: nothing to ask")
        compare(area.text, "Knopf weg", "fading out, the field keeps what it showed")
        tryVerify(() => !editor.visible)
        verify(!page.notes.some(n => n.uid === note.uid))
        popPage()
    }

    // A stand-in for the microphone's MediaRecorder (no microphone here): it stops a moment later,
    // as the real one does once the file is written.
    Component {
        id: fakeRecorder

        QtObject {
            property int recorderState: MediaRecorder.StoppedState
            property real duration: 0
            property url outputLocation
            function record() {
                recorderState = MediaRecorder.RecordingState
                duration = 2000
            }
            function stop() {
                Qt.callLater(() => { recorderState = MediaRecorder.StoppedState })
            }
        }
    }

    // Closing the window during a recording stops it and keeps it, as Back does, then the window
    // closes: on a phone with a text typed (it goes with the recording), beside the list without.
    function test_8g_close_finishes_recording() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        const uid = testCourse("Schließen")
        const voices = []
        const closes = media => {
            media.recorder = fakeRecorder.createObject(media)
            media.record()
            verify(media.recording)
            voices.push(media.voiceName)
            let closed = false
            verify(!window.mayClose(() => { closed = true }), "the recording holds the window")
            tryVerify(() => closed, 2000, "kept, then the window closes")
            verify(!media.recording)
        }

        const page = push("NotesPage", { entry: entry })
        slidIn()
        findChild(page, "compose").text = "Beim Schließen"
        closes(findChild(page.footer, "noteMedia"))
        verify(Practice.notes(entry.id).some(n => n.media === voices[0] && n.text === "Beim Schließen"), "the note")
        verify(!page.leaveAsk.opened, "nothing asked")
        popPage()

        const host = bookBeside(uid)
        const book = findChild(host, "pagePane").item
        closes(findChild(book, "courseMedia"))
        verify(Courses.entries(uid).some(e => e.media === voices[1]), "the entry")
        popPage()

        Practice.notes(entry.id).filter(n => voices.includes(n.media)).forEach(n => Practice.deleteNote(n.uid))
        verify(Courses.remove(uid))
    }

    // On a phone Back during a recording stops it: it becomes a note (or entry) with the text typed
    // so far, as beside the list on a tablet, and the page stays to show it.
    function test_8g_back_finishes_recording() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        const uid = testCourse("Aufnahme")
        const cases = [
            { page: "NotesPage", props: { entry: entry }, media: "noteMedia", field: "compose",
              notes: () => Practice.notes(entry.id) },
            { page: "CoursePage", props: { uid: uid }, media: "courseMedia", field: "courseCompose",
              notes: () => Courses.entries(uid) },
        ]
        // Back key with a text typed, the head's arrow without; NotesPage from "All notes" its action.
        const leaves = [
            { text: "Mit Stimme", go: page => window.pageStack.goBack() },
            { text: "", go: page => window.back() },
        ]
        const fromAll = { page: "NotesPage", props: { entry: entry, fromAllNotes: true }, media: "noteMedia",
                          field: "compose", notes: cases[0].notes }
        const runs = [{ c: fromAll, l: { text: "", go: page => page.leaveAsk.leaveOrAsk() } }]
        for (const c of cases) {
            leaves.forEach(l => runs.push({ c: c, l: l }))
        }
        const voices = []
        for (const run of runs) {
            const c = run.c
            const page = push(c.page, c.props)
            slidIn()
            const media = findChild(page.footer, c.media)
            media.recorder = fakeRecorder.createObject(page)
            findChild(page, c.field).text = run.l.text
            media.record()
            verify(media.recording, c.page)
            const voice = media.voiceName
            voices.push(voice)

            run.l.go(page)
            wait(300)
            compare(window.pageStack.currentItem, page, c.page + ": the page stays")
            tryVerify(() => !media.recording, 2000, c.page + ": the recording stops")
            verify(c.notes().some(n => n.media === voice && n.text === run.l.text), c.page + ": kept")
            verify(!page.leaveAsk.opened, c.page + ": nothing left to ask")
            popPage()
            tryVerify(() => window.pageStack.currentItem !== page)
        }
        Practice.notes(entry.id).filter(n => voices.includes(n.media)).forEach(n => Practice.deleteNote(n.uid))
        verify(Courses.remove(uid))
    }
    function test_8g_failed_save_keeps_window() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        verify(Practice.addNote(entry.id, "Fenster alt"))
        const page = push("NotesPage", { entry: entry })
        slidIn()
        const note = page.notes.find(n => n.text === "Fenster alt")
        const editor = findChild(page, "noteEditor")
        const area = findChild(editor, "noteArea")
        const ask = editor.leaveAsk
        const escape = () => {
            area.forceActiveFocus()
            keyClick(Qt.Key_Escape)
        }

        // (2) Save fails while the window closes.
        const save = editor.save
        editor.save = () => false
        editor.edit(note)
        tryVerify(() => editor.opened)
        area.text = "Fenster kaputt"
        let closed = false
        verify(!window.mayClose(() => { closed = true }))
        tryVerify(() => ask.opened)
        ask.accept()
        tryVerify(() => !ask.visible)
        verify(!closed, "not saved: the window stays")
        verify(editor.opened, "the editor stays with the change")
        escape()
        tryVerify(() => ask.opened && !editor.visible)
        mouseClick(findChild(ask.contentItem, "leaveDiscard"))
        tryVerify(() => !ask.visible)
        wait(100)
        verify(!closed, "a later Discard leaves the window open")
        editor.save = save

        verify(Practice.deleteNote(note.uid))
        popPage()
    }

    // Closing the window (desktop) with a text typed on a page asks first, then closes.
    function test_8g_window_close_asks() {
        const entry = Programme.entries("aikido", "k5").find(r => r.kind === "entry")
        const before = Practice.notes(entry.id).length
        const page = push("NotesPage", { entry: entry })
        slidIn()
        verify(window.mayClose(() => {}), "nothing typed: the window may close")
        findChild(page, "compose").text = "Vor dem Schließen"
        let closed = false
        verify(!window.mayClose(() => { closed = true }), "the window waits for the typed text")
        tryVerify(() => page.leaveAsk.opened)
        page.leaveAsk.reject()
        tryVerify(() => !page.leaveAsk.visible)
        verify(!closed)
        verify(!window.mayClose(() => { closed = true }))
        tryVerify(() => page.leaveAsk.opened)
        page.leaveAsk.accept()
        tryVerify(() => closed, 2000, "closes after saving")
        compare(Practice.notes(entry.id).length, before + 1)
        compare(window.pageStack.currentItem, page, "the page stays for the window to close")

        // A note changed in the open editor asks too, and the editor closes with the choice.
        const note = Practice.notes(entry.id).find(n => n.text === "Vor dem Schließen")
        const editor = findChild(page, "noteEditor")
        editor.edit(note)
        tryVerify(() => editor.opened)
        findChild(editor, "noteArea").text = "Im Editor geändert"
        closed = false
        verify(!window.mayClose(() => { closed = true }), "the window waits for the changed note")
        tryVerify(() => editor.leaveAsk.opened)
        editor.leaveAsk.accept()
        tryVerify(() => closed && !editor.visible, 2000, "saved, the editor closed")
        verify(Practice.notes(entry.id).some(n => n.uid === note.uid && n.text === "Im Editor geändert"))
        verify(window.mayClose(() => {}), "nothing left to ask")
        verify(Practice.deleteNote(note.uid))
        popPage()
    }

    // The last chapter ends with the file; the loop must still start over at the chapter.
    function test_6_loop_at_end_of_file() {
        const page = playerAt(-1)
        // The turning point keeps clear of the end of the file, where the player stops for good.
        verify(page.end <= page.duration - 250)
        page.jump(page.to - page.position - 3000)
        tryVerify(() => page.position > page.to - 2500, 5000)
        tryVerify(() => page.position < page.from + 3000, 8000)
        verify(page.playing)
        popPage()
    }
}
