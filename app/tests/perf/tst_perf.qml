import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import Mitori

// How long the pages take with five years of use (tst_perf.cpp). "PERF <name> <ms> cpu <ms> budget
// <ms>" for the record. Budgets hold CPU time: the time on the wall also counts who else runs (Player
// 5597 ms with 40 busy processes, 1312 ms CPU), and says nothing about the page.
TestCase {
    id: test

    name: "Perf"
    when: windowShown

    // Each case its own budget, ms CPU in a release build: 1.5 times the most measured alone (here
    // and on the GitHub runner), 1.3 times the most with 40 busy processes on 24 threads (35 runs;
    // the cases #104, #105 and the Today page's made faster: 12 busy processes, 5 runs);
    // a frame (16) at least. A debug build has four times as much. A case without a budget fails;
    // one over it runs once more (check()).
    // Snappy is a tap saved within a frame and a page or list drawn within about 200 ms, on the
    // GitHub runner. Above that today, to be made faster, not the budget looser: "slow".
    readonly property var budgets: ({
        "start menu": 1000,                 // slow: cold start, first QML types
        "TodayPage": 360,
        "StatsPage": 300,
        "YearsPage": 550,                   // slow: five years of calendar
        "AllNotesPage": 450,                // slow
        "TechniqueMapPage": 250,
        "SearchPage": 250,
        "CoursesPage": 90,
        "NotebooksPage": 80,
        "GradesPage": 350,
        "SettingsPage": 70,
        "BackupPage": 170,
        "VideosPage": 130,
        "AppearancePage": 600,
        "ExamPage": 180,
        "Programme aikido": 400,
        "Programme daitoryu": 450,
        "Programme shinkitoho": 350,
        "Programme tablet": 750,            // slow: list, page and small player
        "Player first": 500,                // the decoders probed after the start (#105)
        "Programme.entries": 16,
        "Practice.load": 90,                // the start reads the whole log (155 with two queries)
        "Practice.due": 16,
        "Practice.counts": 16,
        "Practice.allNotes": 110,
        "Practice.searchNotes": 16,
        "Practice.practisedPerDay": 16,
        "Practice.practisedInYear": 16,
        "Programme.suggest, 500 words": 110,
        "Search": 400,
        "Search “k”": 160,                  // a query until its list is drawn
        "Search “ko”": 180,
        "Search “kot”": 200,
        "Search “kote”": 100,
        "Programme": 450,
        "Player over programme": 650,
        "Practice.rate": 20,
        "Practice.addNote": 60,             // slow: a tap
        "Stats again": 300,
        "Years over stats": 900,            // slow: see YearsPage
        "Today over years": 390,
        "Player over stats": 550,           // slow
        "Practice.rate under stats": 50     // slow: a tap
    })
    readonly property int debugFactor: perfClock.debugBuild() ? 4 : 1
    // A query until its list is drawn: SearchPage's typing pause (100 ms) is not in it.
    readonly property int listDrawn: 500
    property var window: null
    property var times: []

    function initTestCase() {
        const component = Qt.createComponent("Mitori", "Main")
        verify(component.status === Component.Ready, component.errorString())
        check("start menu", () => {
            window = component.createObject(null, { width: 420, height: 800 })
            window.show()
            tryVerify(() => window.pageStack.currentItem !== null, 10000)
            waitForRendering(window.contentItem)
        })
        // The video decoders, tried in the background after the start: not in a page's time.
        tryVerify(() => Videos.decodersReady, 15000, "the video decoders are tried")
    }

    function cleanupTestCase() {
        console.log("PERF slowest " + times.sort((a, b) => b.ms - a.ms).slice(0, 5).map(t => t.name + " " + t.ms).join(", "))
        window.destroy()
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

    // A failed budget must not leave its page in the stack (it would slow what comes next).
    function cleanup() {
        while (window.pageStack.depth > 1) {
            popPage()
        }
        wait(50)
    }

    // One run of a case: ms CPU and on the wall. A collection of what earlier cases left is not
    // this case's (Stats again: up to 1276 ms CPU without the gc(), 676 with it).
    function measure(run) {
        gc()
        const wall = Date.now()
        const cpu = perfClock.cpuMs()
        run()
        return { wall: Date.now() - wall, cpu: perfClock.cpuMs() - cpu }
    }

    // A case over its budget runs once more after `again` (when given): a busy machine can double
    // one case's CPU time for a moment (Programme aikido 435 ms, median 202), not two in a row.
    function check(name, run, again) {
        const budget = budgets[name] * debugFactor
        verify(!isNaN(budget), "no budget for " + name)
        let took = measure(run)
        if (took.cpu > budget && again) {
            console.log("PERF " + name + " " + took.wall + " cpu " + took.cpu + " budget " + budget + ": once more")
            again()
            took = measure(run)
        }
        console.log("PERF " + name + " " + took.wall + " cpu " + took.cpu + " budget " + budget)
        times.push({ name: name, ms: took.cpu })
        verify(took.cpu <= budget, name + " took " + took.cpu + " ms CPU, budget " + budget)
    }

    // A page from the push until it is drawn; once more after a pop when over budget.
    function page(name, file, properties) {
        check(name, () => push(file, properties), back)
        const shown = window.pageStack.currentItem
        wait(350)   // the slide, not part of the time
        // What a page makes after it is drawn (TodayPage's rows), not in the next case's time.
        tryVerify(() => shown.built !== false, 5000)
        return shown
    }

    // The first player of the run, once: Qt probes the decoders only then (a second is no retry).
    function firstPlayer(name, properties) {
        check(name, () => push("PlayerPage", properties))
        wait(350)
    }

    function push(file, properties) {
        window.pageStack.push(Qt.resolvedUrl("qrc:/qt/qml/Mitori/qml/" + file + ".qml"), properties || {})
        waitForRendering(window.contentItem)
    }

    function back() {
        popPage()
        wait(50)
    }

    function call(name, f) {
        let result
        check(name, () => { result = f() }, () => {})
        return result
    }

    function test_1_pages() {
        for (const name of ["TodayPage", "StatsPage", "YearsPage", "AllNotesPage", "TechniqueMapPage", "SearchPage",
                            "CoursesPage", "NotebooksPage", "GradesPage", "SettingsPage", "BackupPage", "VideosPage", "AppearancePage", "ExamPage"]) {
            page(name, name)
            back()
        }
    }

    function test_2_programmes() {
        for (const discipline of ["aikido", "daitoryu", "shinkitoho"]) {
            Programme.discipline = discipline
            page("Programme " + discipline, "ProgrammePage")
            back()
        }
        Programme.discipline = "aikido"
    }

    // Beside the list on a tablet the page has the small player too.
    function test_3_tablet() {
        window.width = 1280
        window.height = 800
        wait(200)
        page("Programme tablet", "ProgrammePage")
        back()
        window.width = 420
        window.height = 800
        wait(200)
    }

    function test_4_player() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        firstPlayer("Player first", { playlist: rows, index: 0 })
        back()
    }

    function test_5_calls() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        call("Programme.entries", () => Programme.entries("aikido", "k5"))
        call("Practice.load", () => perfClock.loadPractice())
        call("Practice.due", () => Practice.due(rows))
        call("Practice.counts", () => Practice.counts(rows.map(r => r.id)))
        call("Practice.allNotes", () => Practice.allNotes())
        call("Practice.searchNotes", () => Practice.searchNotes("Hüfte"))
        call("Practice.practisedPerDay", () => Practice.practisedPerDay(84))
        call("Practice.practisedInYear", () => Practice.practisedInYear(new Date().getFullYear(), "aikido"))
    }

    // A long note in the technique picker: it asks on the UI thread.
    function test_5b_suggest_long_note() {
        const sentence = "Heute Ikkyo aus Katate-dori geübt, dann die Hüfte tief. Danach Kote-gaeshi, langsam und sauber! "
        const words = sentence.trim().split(" ").length
        const text = sentence.repeat(Math.ceil(500 / words))
        call("Programme.suggest, 500 words", () => Programme.suggest(text))
    }

    // One keystroke in the search, after the typing pause: the query until its list is drawn.
    function test_6_search_typing() {
        const search = page("Search", "SearchPage")
        let previous = ""
        for (const text of ["k", "ko", "kot", "kote"]) {
            const type = shown => () => {
                search.query = shown
                waitForRendering(window.contentItem, listDrawn)   // false when the picture stays
            }
            check("Search “" + text + "”", type(text), type(previous))
            previous = text
        }
        back()
    }

    // The save that everyone does: a rating with the list and the player open (Practice.changed).
    function test_7_rate() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        page("Programme", "ProgrammePage")
        page("Player over programme", "PlayerPage", { playlist: rows, index: 0 })
        call("Practice.rate", () => Practice.rate(rows[0].id, 3))
        call("Practice.addNote", () => Practice.addNote(rows[0].id, "Noch einmal"))
    }

    // The same with the statistics: the pages that count everything, under the player.
    function test_8_rate_over_stats() {
        const rows = Programme.entries("aikido", "k5").filter(r => r.kind === "entry")
        page("Stats again", "StatsPage")
        page("Years over stats", "YearsPage")
        page("Today over years", "TodayPage")
        page("Player over stats", "PlayerPage", { playlist: rows, index: 0 })
        call("Practice.rate under stats", () => Practice.rate(rows[0].id, 2))
    }
}
