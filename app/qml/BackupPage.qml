import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// Backup and sync (clickdummy "Sicherung"): save everything as a file, read one back (merged or
// replacing, see Backup), and the sync between devices over WebDAV / Nextcloud (Sync).
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    title: qsTr("Backup and sync")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    // The settings as rows of its own: the name of the setting as a small caps line above its
    // field (the clickdummy's forms), not the desktop's form layout.
    ColumnLayout {
        spacing: Look.unit(16)

        LookSectionLabel {
            objectName: "backupSection"
            text: qsTr("Backup")
        }
        LookFormRow {
            LookButton {
                objectName: "saveBackup"
                icon.name: "document-save"
                text: qsTr("Save backup …")
                onClicked: saveDialog.ask(Backup.fileName())
            }
        }
        LookButton {
            objectName: "readBackup"
            icon.name: "document-open"
            text: qsTr("Read backup …")
            onClicked: openDialog.open()
        }
        LookLabel {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            wrapMode: Text.Wrap
            color: Look.disabledTextColor
            text: qsTr("One file with your ratings, notes, exam rounds, notebooks, grades, photos and voice notes. Reading one back asks: merge it (the newer state wins, also a newer deletion) or replace this device's data with it. DVD codes are not in it.")
        }
        LookLabel {
            objectName: "backupDone"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: page.done !== ""
            text: page.done
            color: Look.positiveTextColor
            wrapMode: Text.Wrap
        }
        LookLabel {
            objectName: "backupError"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: text !== ""
            text: page.refused !== "" ? page.refused : Backup.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        // Sync over WebDAV / Nextcloud (Sync): account, state, devices, conflicts.
        LookSectionLabel {
            objectName: "syncSection"
            text: qsTr("Sync between devices")
        }
        LookFormRow {
            label: qsTr("WebDAV / Nextcloud")
            LookSwitch {
                objectName: "syncEnabled"
                text: qsTr("Sync")
                checked: Sync.enabled
                onToggled: Sync.enabled = checked
            }
        }
        LookLabel {
            objectName: "syncAfterReplace"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: Sync.afterReplace
            wrapMode: Text.Wrap
            text: qsTr("This device's data was replaced by a backup. If you turn sync on, what your other devices hold comes here, their changes and deletions too: what you restored from the backup can go again.")
        }
        LookFormRow {
            label: qsTr("Folder on the server")
            visible: Sync.enabled
            LookTextField {
                id: serverField

                objectName: "syncServer"
                Layout.fillWidth: true
                text: Sync.server
                placeholderText: "https://cloud.example.org/remote.php/dav/files/ich/Mitori/"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                onEditingFinished: page.saveAccount()
            }
        }
        LookFormRow {
            label: qsTr("User")
            visible: Sync.enabled
            LookTextField {
                id: userField

                Layout.fillWidth: true
                text: Sync.user
                inputMethodHints: Qt.ImhNoAutoUppercase
                onEditingFinished: page.saveAccount()
            }
        }
        LookFormRow {
            label: qsTr("App password")
            visible: Sync.enabled
            LookTextField {
                id: passwordField

                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Sync.passwordSaved ? qsTr("saved") : ""
                onEditingFinished: page.saveAccount()
            }
        }
        // Where the password is when not simply in the key store. With sync off only what lies in
        // the file: it still does, while the field and "Sync now" the others speak of are hidden.
        LookHint {
            readonly property bool android: Qt.platform.os === "android"
            // A test sets what only a failing disk reaches.
            property int note: Sync.passwordNote
            property bool syncOn: Sync.enabled
            property bool inFile: Sync.passwordInFile

            objectName: "syncPasswordNote"
            Layout.fillWidth: true
            visible: note !== Sync.NoNote && (syncOn || inFile)
            importance: note === Sync.MovingToStore && syncOn ? LookHint.Importance.Info
                      : note === Sync.Unreadable || note === Sync.NotSaved ? LookHint.Importance.Error
                      : LookHint.Importance.Important
            titleText: {
                switch (note) {
                case Sync.Unreadable: return qsTr("App password cannot be read")
                case Sync.NotRecorded: return syncOn ? qsTr("App password not on record") : qsTr("App password lies in a file")
                case Sync.NotSaved: return syncOn ? qsTr("App password not saved") : qsTr("App password lies in a file")
                default: return qsTr("App password lies in a file")
                }
            }
            text: {
                if (!syncOn) {
                    if (note === Sync.NotRecorded || note === Sync.NotSaved) {
                        return qsTr("An older app password lies unencrypted in Mitori's sync folder. Switch sync on to see what to do.")
                    }
                    return qsTr("It lies unencrypted in Mitori's sync folder. With sync on, Mitori moves it to the key store.")
                }
                switch (note) {
                case Sync.MovingToStore:
                    return android ? qsTr("Mitori is handing it to the Android key store. Until that is confirmed, it lies unencrypted in Mitori's sync folder.")
                                   : qsTr("Mitori is handing it to the key store. Until that is confirmed, it lies unencrypted in Mitori's sync folder. If the key store asks to be unlocked, unlock it.")
                case Sync.RefusedByStore:
                    return android ? qsTr("The Android key store did not take it, so it lies unencrypted in Mitori's sync folder. Restart Mitori: it tries again by itself. If this note stays, use an app password you can revoke on the server.")
                                   : qsTr("No key store took it, so it lies unencrypted in Mitori's sync folder. Set up and unlock KWallet, GNOME Keyring or another Secret Service (for the Flatpak: with the desktop's secrets portal), then restart Mitori: it moves the password by itself.")
                case Sync.NotRemovedFromFile:
                    return qsTr("The key store holds it, but Mitori could not rewrite the file konto.ini in its sync folder, so it also still lies there unencrypted. Check the free space and the folder's rights, then restart Mitori.")
                case Sync.NotRecorded:
                    return !inFile ? qsTr("The key store holds it, but Mitori could not rewrite the file konto.ini in its sync folder, so the next start would not use it. Check the free space and the folder's rights, then press “Sync now”. Restarting before that loses this password here.")
                                   : qsTr("The key store holds it, but Mitori could not rewrite the file konto.ini in its sync folder, so the next start would not use it. Check the free space and the folder's rights, then press “Sync now”. Restarting before that loses this password here: an older one in the file comes back and replaces it in the key store.")
                case Sync.NotSaved:
                    return qsTr("Neither the key store nor the file konto.ini took it: it is gone when Mitori closes. Check the free space and the sync folder's rights, then press “Sync now”.")
                case Sync.Unreadable:
                    return android ? qsTr("The Android key store does not give it out or no longer holds it, so Mitori cannot sync. Press “Sync now” to ask again, or enter the password again.")
                                   : qsTr("The key store does not give it out or no longer holds it, so Mitori cannot sync. Unlock it and press “Sync now”, or enter the password again.")
                default:
                    return ""
                }
            }
        }
        LookFormRow {
            label: qsTr("This device")
            visible: Sync.enabled
            LookTextField {
                id: nameField

                Layout.fillWidth: true
                text: Sync.deviceName
                onEditingFinished: page.saveAccount()
            }
        }
        LookSwitch {
            visible: Sync.enabled
            text: qsTr("Sync after every change")
            checked: Sync.automatic
            onToggled: Sync.automatic = checked
        }
        LookLabel {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: Sync.enabled
            wrapMode: Text.Wrap
            color: Look.disabledTextColor
            text: qsTr("Otherwise when Mitori starts and once a day. Every rating and note is an entry of its own with a time; changes from several devices are merged. Mitori asks only when the same note was changed on two devices.")
        }
        LookButton {
            objectName: "syncNow"
            visible: Sync.enabled
            enabled: !Sync.busy
            icon.name: "view-refresh"
            text: Sync.busy ? qsTr("Syncing …") : qsTr("Sync now")
            onClicked: {
                page.saveAccount()
                Sync.syncNow()
            }
        }
        LookLabel {
            objectName: "syncState"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: Sync.enabled
            wrapMode: Text.Wrap
            color: Sync.errorString !== "" ? Look.negativeTextColor : Look.textColor
            text: Sync.errorString !== "" ? Sync.errorString
                  : Sync.lastSync.getTime() > 0 ? qsTr("Last synced: %1").arg(Sync.lastSync.toLocaleString(Qt.locale(), Locale.ShortFormat))
                  : qsTr("Not synced yet.")
        }
        Repeater {
            model: Sync.enabled ? Sync.devices : []

            LookLabel {
                required property var modelData

                text: qsTr("%1: %2").arg(modelData.name || qsTr("Device")).arg(modelData.synced.toLocaleString(Qt.locale(), Locale.ShortFormat))
                color: Look.disabledTextColor
            }
        }
        LookButton {
            objectName: "syncConflicts"
            visible: Sync.enabled && Sync.conflicts.length > 0
            icon.name: "dialog-warning"
            text: qsTr("%n conflict(s): solve …", "", Sync.conflicts.length)
            onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ConflictsPage.qml"))
        }
    }

    function saveAccount() {
        Sync.setAccount(serverField.text, userField.text, passwordField.text, nameField.text)
        passwordField.text = ""
    }

    // What the last step did ("" for nothing yet), and what the read backup would change.
    property string done: ""
    property var summary: ({})
    property url source
    property string refused

    SaveFileDialog {
        id: saveDialog

        objectName: "saveBackupDialog"
        anchor: page
        title: qsTr("Save backup")
        onChosen: target => page.saveBackup(target)
    }

    FileDialog {
        id: openDialog

        title: qsTr("Read backup")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("ZIP archives (*.zip)")]
        currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
        onAccepted: page.inspect(selectedFile)
    }

    function saveBackup(url) {
        page.refused = ""
        const ok = Backup.save(url)
        page.done = !ok ? "" : Backup.savedTo() !== "" ? qsTr("Backup saved: %1").arg(Backup.savedTo()) : qsTr("Backup saved.")
        return ok
    }

    function inspect(url) {
        page.done = ""
        page.refused = ""
        page.source = url
        page.summary = Backup.inspect(url)
        if (Object.keys(page.summary).length > 0) {
            mergeDialog.open()
        }
    }

    // A running sync would merge into the new state: refused, and read again later (fresh numbers).
    function replaceData(syncRuns) {
        if (syncRuns) {
            Backup.discard()
            page.refused = qsTr("Not replaced: a sync was running. Read the backup again when it has finished.")
            return
        }
        const syncWasOn = Sync.enabled
        const ok = Backup.replace()
        if (ok) {
            Sync.dataReplaced()
        }
        page.done = !ok ? "" : syncWasOn ? qsTr("This device's data was replaced by the backup. Sync is off now.")
                                         : qsTr("This device's data was replaced by the backup.")
    }

    // A sync brought something while a dialog is open: its numbers anew. Not readable any more: the
    // error shows, nothing to choose.
    function inspectAgain() {
        if (!mergeDialog.visible && !replaceDialog.visible) {
            return
        }
        page.summary = Backup.inspect(page.source)
        if (Object.keys(page.summary).length === 0) {
            mergeDialog.close()
            replaceDialog.close()
        }
    }

    // "Notes: 3 new, 2 changed, 1 deleted" per kind that changes; a line when nothing does.
    function changes(s) {
        const kinds = [["ratings", qsTr("Ratings")], ["notes", qsTr("Notes")], ["rounds", qsTr("Exam rounds")],
                       ["notebooks", qsTr("Notebooks")], ["entries", qsTr("Notebook entries")], ["grades", qsTr("Grades")],
                       ["starts", qsTr("Start of training")], ["links", qsTr("Technique links")]]
        let lines = []
        for (const [key, name] of kinds) {
            const c = s[key] || {}
            let parts = []
            if (c.added > 0) {
                parts.push(qsTr("%n new", "", c.added))
            }
            if (c.edited > 0) {
                parts.push(qsTr("%n changed", "", c.edited))
            }
            if (c.removed > 0) {
                parts.push(qsTr("%n deleted", "", c.removed))
            }
            if (parts.length > 0) {
                lines.push(name + ": " + parts.join(", "))
            }
        }
        if (s.media > 0) {
            lines.push(qsTr("Photos and voice notes: %n new", "", s.media))
        }
        if (s.mediaRemoved > 0) {
            lines.push(qsTr("Photos and voice notes: %n deleted", "", s.mediaRemoved))
        }
        return lines.length > 0 ? qsTr("On this device it changes:") + "\n" + lines.join("\n")
                                : qsTr("Nothing new: this device has everything in the backup.")
    }

    // "Ratings: 12" per kind, by the summary's key for that number; the media's number apart.
    function amounts(s, key, media) {
        const kinds = [["ratings", qsTr("Ratings")], ["notes", qsTr("Notes")], ["rounds", qsTr("Exam rounds")],
                       ["notebooks", qsTr("Notebooks")], ["entries", qsTr("Notebook entries")], ["grades", qsTr("Grades")],
                       ["starts", qsTr("Start of training")], ["links", qsTr("Technique links")]]
        let lines = []
        for (const [kind, name] of kinds) {
            const n = (s[kind] || {})[key] || 0
            if (n > 0) {
                lines.push(name + ": " + n)
            }
        }
        if (media > 0) {
            lines.push(qsTr("Photos and voice notes") + ": " + media)
        }
        return lines
    }

    // How much of the window's height a dialog may take (as Kante's size steps).
    readonly property real dialogRoom: 0.9

    // What a replace means for the sync; "" without an account.
    function syncNote() {
        if (Sync.enabled) {
            return qsTr("Sync is turned off on this device: your other devices keep their data and would bring it here. If you turn sync on again, what they hold comes here, their changes and deletions too: what you restored from the backup can go again.")
        }
        return Sync.server !== "" ? qsTr("If you turn sync on again, what your other devices hold comes here, their changes and deletions too: what you restored from the backup can go again.") : ""
    }

    LookDialog {
        id: mergeDialog

        objectName: "mergeBackup"
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        span: LookDialog.Span.Small
        // Taller than a phone held sideways: the text scrolls, the buttons stay.
        height: Math.min(implicitHeight, (parent ? parent.height : implicitHeight) * page.dialogRoom)
        // From the text and the button, as the second dialog.
        contentHeight: mergeBody.implicitHeight + Look.unit(8) + replaceButton.implicitHeight
        title: qsTr("Read backup")
        acceptText: qsTr("Merge")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onAccepted: page.done = Backup.restore() ? qsTr("Backup merged.") : ""
        onRejected: Backup.discard()

        // The second choice beside the first, right above the buttons: the text scrolls, the choices never
        // do. Not in the footer: three buttons do not fit one row on a phone.
        ColumnLayout {
            anchors.fill: parent
            spacing: Look.unit(8)

            LookScrollView {
                id: mergeScroll

                objectName: "mergeScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                rightPadding: Look.unit(8)      // the bar stands beside the text
                clip: true

                ColumnLayout {
                    id: mergeBody

                    width: mergeScroll.availableWidth
                    spacing: Look.unit(16)

                    LookLabel {
                        objectName: "replaceHint"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: !mergeDialog.visible ? "" : qsTr("Replacing deletes what is on this device and puts the backup's state in its place. It asks once more.")
                    }
                    LookLabel {
                        id: mergeText

                        objectName: "mergeText"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        // Closed it measures nothing: a window turning (full screen) made a page still on its way
                        // out wrap this text anew, a binding loop in the dialog's height.
                        text: !mergeDialog.visible ? "" : (page.summary.created ? qsTr("Backup of %1.").arg(page.summary.created.toLocaleString(Qt.locale(), Locale.ShortFormat)) + "\n\n" : "")
                              + qsTr("It holds: %1").arg(page.amounts(page.summary, "holds", page.summary.mediaHolds).join(", ") || qsTr("nothing"))
                              + "\n\n" + qsTr("Merging: ratings and exam rounds are only added. For everything else the newer state wins: a newer text replaces this device's, a newer deletion deletes here too, with the photo. What the backup lacks stays, except: an entry in a notebook the backup deleted later goes with it; two notebooks of one course become one, the entries move, the younger one's details go; of one grade entered twice the newer stays.")
                              + "\n\n"
                              + page.changes(page.summary)
                    }
                }
            }
            LookButton {
                id: replaceButton

                objectName: "replaceInstead"
                Layout.alignment: Qt.AlignRight
                icon.name: "edit-delete"
                text: qsTr("Replace …")
                onClicked: {
                    mergeDialog.close()
                    replaceDialog.open()
                }
            }
        }
    }

    // The second step of a replace: says what goes. Cancel goes back to the first.
    LookDialog {
        id: replaceDialog

        objectName: "replaceBackup"
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        destructive: true
        span: LookDialog.Span.Small
        height: Math.min(implicitHeight, (parent ? parent.height : implicitHeight) * page.dialogRoom)
        // From the text: under Shinki with the desktop's controls the dialog measured one line of it.
        contentHeight: replaceText.implicitHeight
        title: qsTr("Replace this device's data?")
        acceptText: qsTr("Delete and replace")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onAccepted: page.replaceData(Sync.busy)
        onRejected: mergeDialog.open()

        LookScrollView {
            id: replaceScroll

            objectName: "replaceScroll"
            anchors.fill: parent
            contentWidth: availableWidth
            rightPadding: Look.unit(8)      // the bar stands beside the text
            clip: true

            LookLabel {
                id: replaceText

                objectName: "replaceText"
                width: replaceScroll.availableWidth
                wrapMode: Text.Wrap
                text: {
                    if (!replaceDialog.visible) {
                        return ""
                    }
                    const lost = page.amounts(page.summary, "lost", page.summary.mediaLost)
                    return qsTr("This cannot be undone. The backup's state takes the place of this device's ratings, notes, exam rounds, notebooks, grades, start of training, photos and voice notes.")
                           + "\n\n" + (lost.length > 0 ? qsTr("Deleted, or set back to the backup's older state:") + "\n" + lost.join("\n")
                                                        : qsTr("The backup has all of this device's data, none is lost."))
                           + "\n\n" + qsTr("Downloaded videos, DVD codes and settings stay.")
                           + (page.syncNote() !== "" ? "\n\n" + page.syncNote() : "")
                           + (Sync.busy ? "\n\n" + qsTr("A sync is running: replace when it has finished.") : "")
                }
            }
        }
    }

    Connections {
        target: Sync
        function onMerged() {
            page.inspectAgain()
        }
    }

    // The services read their data anew after a merge or a replace.
    Connections {
        target: Backup
        function onRestored() {
            Practice.refresh()
            Courses.refresh()
        }
    }
}
