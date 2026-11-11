import QtQuick
import QtQuick.Controls as QQC2

// Dialog (bible section 5): white, 1 px frame, square, on the scrim; the title in PT Sans bold,
// Cancel and the main button at the bottom right, the main one red and named after what it does.
//   size           Fit (the content's width), Small, Medium, Large: 432, 648, 864 px, at most 90 %
//                  of the window
//   acceptText     the main button's text ("Discard" instead of OK)
//   rejectText     Cancel's text where Cancel is ambiguous ("Keep the round")
//   destructive    the yes removes something; Shinki marks it by the word, not a second colour
// Same interface as KanteDialog for these; standardButtons as QQC2.Dialog.
QQC2.Dialog {
    id: dialog

    enum Size { Fit, Small, Medium, Large }
    property int size: ShinkiDialog.Size.Fit
    property bool destructive: false
    property string acceptText: ""
    property string rejectText: ""

    readonly property real stepWidth: size === ShinkiDialog.Size.Small ? ShinkiStyle.dialogSmallSize
        : size === ShinkiDialog.Size.Medium ? ShinkiStyle.dialogMediumSize
        : size === ShinkiDialog.Size.Large ? ShinkiStyle.dialogLargeSize : 0
    readonly property real maxWidth: parent ? parent.width * 0.9 : stepWidth

    width: stepWidth > 0 ? Math.min(stepWidth, maxWidth) : undefined
    padding: ShinkiStyle.pageSpace
    topPadding: ShinkiStyle.cardSpace

    font.family: ShinkiStyle.uiFamily
    font.pixelSize: ShinkiStyle.uiSize

    background: Rectangle {
        color: ShinkiStyle.paper
        border.width: ShinkiStyle.lineWidth
        border.color: ShinkiStyle.line
    }

    // The dialog hangs on the overlay, outside the page's scope: its content gets Shinki's colours
    // itself (ink on paper, also under a dark platform scheme).
    // A property, not a child: a second child of the content would void its implicit size (Fit).
    property Item scope: ShinkiScope {
        target: dialog.contentItem
    }

    QQC2.Overlay.modal: Rectangle {
        color: Qt.alpha(ShinkiStyle.scrim, ShinkiStyle.scrimOpacity)
    }

    header: QQC2.Label {
        visible: dialog.title !== ""
        text: dialog.title
        color: ShinkiStyle.ink
        font.family: ShinkiStyle.uiFamily
        font.bold: true
        font.pixelSize: ShinkiStyle.tileTitleSize
        wrapMode: Text.Wrap
        leftPadding: ShinkiStyle.pageSpace
        rightPadding: ShinkiStyle.pageSpace
        topPadding: ShinkiStyle.pageSpace
    }

    // Cancel first, the main button last and red; the main one says what it does.
    footer: QQC2.DialogButtonBox {
        visible: count > 0
        alignment: Qt.AlignRight
        // Fixed, not the platform's order (Windows and KDE put OK first).
        buttonLayout: QQC2.DialogButtonBox.GnomeLayout
        spacing: ShinkiStyle.gridSpace * 2
        padding: ShinkiStyle.pageSpace
        topPadding: 0
        background: null

        delegate: ShinkiButton {
            primary: QQC2.DialogButtonBox.buttonRole === QQC2.DialogButtonBox.AcceptRole
        }
    }

    // The buttons' words; standard buttons come after the dialog is complete.
    function nameAccept() {
        const ok = standardButton(QQC2.Dialog.Ok) || standardButton(QQC2.Dialog.Yes)
        if (ok && acceptText !== "") {
            ok.text = acceptText
        }
        const cancel = standardButton(QQC2.Dialog.Cancel) || standardButton(QQC2.Dialog.No)
        if (cancel && rejectText !== "") {
            cancel.text = rejectText
        }
    }
    onAcceptTextChanged: nameAccept()
    onRejectTextChanged: nameAccept()
    onStandardButtonsChanged: Qt.callLater(nameAccept)
    Component.onCompleted: nameAccept()
}
