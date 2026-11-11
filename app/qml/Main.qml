import QtQuick
import org.kde.kirigami as Kirigami
import Kante
import Mitori

Kirigami.ApplicationWindow {
    id: root

    title: "Mitori"
    width: KanteStyle.unit(420)
    height: KanteStyle.unit(800)

    // The style the window is built in (Appearance): Breeze and Material are the platform's
    // colours, Kante dark, Leinen light, Shinki the club newspaper's (paper, ink, one red).
    // Shinki and Kante are two themes of their own: neither takes the other's colours.
    readonly property bool platformStyle: Appearance.running === Appearance.Style.Breeze
                                          || Appearance.running === Appearance.Style.Material
    readonly property bool shinkiStyle: Appearance.running === Appearance.Style.Shinki
    Binding {
        target: KanteStyle
        property: "kind"
        // Under Shinki the Kante components (the few that are left) follow the window's theme,
        // which carries Shinki's roles; Kante's own palette is only for Kante and Leinen.
        value: root.platformStyle || root.shinkiStyle ? KanteStyle.Kind.System : KanteStyle.Kind.Kante
    }
    Binding {
        target: KanteStyle
        property: "preferDark"
        value: Appearance.running === Appearance.Style.Kante
    }
    Binding {
        target: KanteStyle
        property: "preferLight"
        value: Appearance.running === Appearance.Style.Leinen
    }
    // The scope gives the window's controls the colours of the style: Kante's under Kante and
    // Leinen (also on Kirigami's bars), Shinki's under Shinki (LookWindowScope). Never both.
    LookWindowScope { window: root }

    // One page at a time, also in landscape: the tablet gets its own page with list and player
    // (app-entscheidungen.md, "Tablet quer"), not Kirigami's columns.
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn
    // Under Shinki the window carries Shinki's head in place of Kirigami's bar (bible section 5,
    // Kopf); the other styles keep the bar (LookHead is empty there).
    pageStack.globalToolBar.style: root.shinkiStyle ? Kirigami.ApplicationHeaderStyle.None : Kirigami.ApplicationHeaderStyle.Auto
    header: LookHead {
        objectName: "lookHead"
        page: root.pageStack.currentItem as Kirigami.Page
        // The page before the current one (back by key keeps the pages ahead).
        backTitle: root.pageStack.currentIndex > 0 ? root.pageStack.get(root.pageStack.currentIndex - 1).title || "" : ""
        moreText: qsTr("More")
        logo: root.pageLogo(root.pageStack.currentItem)
        onBack: root.back()
    }

    // The mark of the app: the page names it (the start menu has one), the head shows it.
    function pageLogo(page) {
        // The index, not the property: the page is a C++ type, a direct access to a property it
        // does not have would fail.
        const logo = page ? page["headLogo"] : ""
        return logo !== undefined ? logo : ""
    }

    // Back from Shinki's head: as the Back key (goBack, the page may ask first), then the page
    // left is dropped (a player stops at once). A page that asks takes the stack back a moment
    // later (ExamEndPage, Qt.callLater before this one); then it stays.
    function back() {
        const leaving = root.pageStack.currentIndex
        root.pageStack.goBack()
        Qt.callLater(() => {
            if (root.pageStack.currentIndex < leaving) {
                root.pageStack.pop(root.pageStack.currentItem)
            }
        })
    }
    pageStack.initialPage: StartPage {}

    // Escape goes back one page, as the Back key. It gets here only when nothing took it before: an
    // open sheet or dialog (their popup), the player (full screen first), the end pages. A text
    // field passes it on: with text in it, Escape first leaves the field (a typed code or search
    // stays), the next one goes back.
    pageStack.Keys.onEscapePressed: event => {
        const field = root.activeFocusItem
        if (field && field.cursorPosition !== undefined && field.text) {
            field.focus = false
            event.accepted = true
            return
        }
        event.accepted = root.pageStack.depth > 1
        if (event.accepted) {
            root.back()
        }
    }

    // Closing the window (desktop): typed text asks first (LeaveDialog), the top page first, on it
    // an open note editor (`editAsk`) before the page's field (`leaveAsk`); after Save or Discard
    // the window tries again, the next one may ask. A recording (`busy`) asks nothing: it stops and
    // is kept with the text typed, as on Back, then the window tries again.
    onClosing: close => {
        close.accepted = root.mayClose(() => root.close())
    }
    function mayClose(then) {
        for (let i = root.pageStack.depth - 1; i > 0; i--) {
            const page = root.pageStack.get(i)
            if (page && page["busy"]) {
                root.pageStack.currentIndex = i
                root.afterBusy(page, then)
                page.finishBusy()
                return false
            }
            // The index: the page is a C++ type (pageLogo).
            const ask = page ? [page["editAsk"], page["leaveAsk"]].find(a => a && a.asking) : undefined
            if (!ask) {
                continue
            }
            root.pageStack.currentIndex = i
            ask.ask(then)
            return false
        }
        return true
    }
    // A recording stops a moment after finishBusy(); its note is made on that same change, `then`
    // follows it.
    function afterBusy(page, then) {
        const done = () => {
            if (page.busy) {
                return
            }
            page.busyChanged.disconnect(done)
            Qt.callLater(then)
        }
        page.busyChanged.connect(done)
    }

    // Kirigami destroys a popped page when its slide ends. A new height of the view stops the slide
    // without ending it (Shinki's head is lower on the start menu, the keyboard closes, a turn), and
    // the page stays, hidden, until the next slide ends. It goes now: a draft saved on destruction
    // (NoteRow, CoursePage beside a list) must not wait for that, the system may kill the app first.
    property var leavingPages: []
    function dropLeaving() {
        if (root.pageStack.columnView.moving) {
            return
        }
        for (const page of root.leavingPages.splice(0)) {
            root.pageStack.removePage(page)
        }
    }
    Connections {
        target: root.pageStack.columnView

        function onItemRemoved(item) {
            root.leavingPages.push(item)
        }
        function onMovingChanged() {
            // Later: a slide replaced by the next one stops and starts in one go.
            Qt.callLater(root.dropLeaving)
        }
    }

    // After a change of style (Appearance::rebuild) the pages of the old window, as keptPageList gave
    // them. A page names itself with `keptPage` (and `keptState`, its properties); only pages
    // without an unsaved input of their own do, and those are the only ways to the style choice.
    property var keptPages: []
    function keptPageList() {
        // A field in focus saves when it is left.
        root.contentItem.forceActiveFocus()
        const start = root.pageStack.get(0)
        const pages = [{ contentY: start && start.flickable ? start.flickable.contentY : 0 }]
        for (let i = 1; i <= root.pageStack.currentIndex; i++) {
            const page = root.pageStack.get(i)
            const name = page ? page["keptPage"] : undefined
            if (!name) {
                break
            }
            pages.push({ page: name, state: page["keptState"] ?? {}, contentY: page.flickable ? page.flickable.contentY : 0 })
        }
        return pages
    }
    // At once, without the slide: the window opens as it was.
    function restorePages() {
        const duration = root.pageStack.columnView.scrollDuration
        root.pageStack.columnView.scrollDuration = 0
        for (const kept of root.keptPages) {
            // The first entry is the start page, which is there already.
            const page = kept.page ? root.pageStack.push(Qt.resolvedUrl(kept.page), kept.state) : root.pageStack.get(0)
            if (page.flickable && kept.contentY > 0) {
                root.scrollTo(page.flickable, kept.contentY)
            }
        }
        Qt.callLater(() => { root.pageStack.columnView.scrollDuration = duration })
    }

    // The old place, or the page's end where the page is shorter now. A new page gets its size and
    // its previews a moment later: it follows them until it stands, not after that.
    function scrollTo(flickable, y) {
        // A page gone (Back at once, the next change of style) reads undefined.
        const gone = () => flickable.contentHeight === undefined
        const stop = () => {
            if (!gone()) {
                flickable.contentHeightChanged.disconnect(place)
                flickable.heightChanged.disconnect(place)
            }
        }
        const place = () => {
            if (gone()) {
                return
            }
            const end = flickable.contentHeight + flickable.bottomMargin - flickable.height
            flickable.contentY = Math.max(0, Math.min(y, end))
            if (flickable.contentY === y) {
                stop()
            }
        }
        flickable.contentHeightChanged.connect(place)
        flickable.heightChanged.connect(place)
        Qt.callLater(place)
        scrollSettled.stops.push(stop)
        scrollSettled.restart()
    }
    readonly property int scrollSettle: 1000
    Timer {
        id: scrollSettled

        property var stops: []
        interval: root.scrollSettle
        onTriggered: {
            stops.forEach(stop => stop())
            stops = []
        }
    }

    // The window builds up (pages pushed, layouts settling over some frames) without being seen: a
    // cover in the ground of the style lies over it until then. A hidden window would not do, it
    // draws nothing, so there is no telling when it stands. The system's own window before the
    // first frame is the ground too (Android: Theme.Mitori.Launch).
    property bool covered: true
    readonly property int coverZ: 1000
    readonly property int settleFrames: 3
    property int framesDrawn: 0
    Rectangle {
        objectName: "buildCover"
        parent: root.overlay
        anchors.fill: parent
        z: root.coverZ
        color: Look.backgroundColor
        visible: root.covered
    }
    Connections {
        target: root
        enabled: root.covered

        function onFrameSwapped() {
            root.framesDrawn++
            if (root.framesDrawn >= root.settleFrames) {
                root.covered = false
                return
            }
            // A window at rest draws no more: ask for the next one.
            root.update()
        }
    }

    // The first start: the wizard over the start menu (it goes back there).
    Component.onCompleted: {
        Appearance.adopt(root)
        restorePages()
        if (!Appearance.welcomed) {
            pageStack.push(Qt.resolvedUrl("WelcomePage.qml"))
        }
        Videos.prepareDecoders()
        // Frames count from here: the pages exist now.
        root.framesDrawn = 0
    }

    // Android's bars in the window's ground.
    Binding {
        target: Appearance
        property: "barColor"
        value: Look.backgroundColor
    }

    // The sync: after it brought something the services read anew; a change asks for one soon.
    Connections {
        target: Sync
        function onMerged() {
            Practice.refresh()
            Courses.refresh()
        }
    }
    Connections {
        target: Practice
        function onChanged() { Sync.touched() }
        function onNotesChanged() { Sync.touched() }
    }
    Connections {
        target: Courses
        function onChanged() { Sync.touched() }
    }
}
