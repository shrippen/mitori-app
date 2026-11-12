import QtQuick
import Kante

// A hint card: an importance (info, important, error), a title, a text and actions as children.
// Kante: KanteHintCard. Under Shinki +shinki/LookHint.qml (ShinkiHint).
KanteHintCard {
    id: hint

    enum Importance {
        Info,
        Important,
        Error
    }
    property int importance: LookHint.Importance.Info
    // The title of a compact hint breaks its lines (Kante's elides it); the other hints wrap already.
    property bool wrapTitle: false
    titleItem: wrapTitle ? wrapped : null

    // Not a child: the children are the hint's actions.
    readonly property LookLabel wrapped: LookLabel {
        text: hint.titleText
        wrapMode: Text.Wrap
    }

    tier: importance === LookHint.Importance.Error ? KanteHintCard.Tier.Red
        : importance === LookHint.Importance.Important ? KanteHintCard.Tier.Primary : KanteHintCard.Tier.Blue
}
