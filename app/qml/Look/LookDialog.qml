import QtQuick
import Kante

// A dialog: `span` Fit, Small, Medium, Large (the width by step), `destructive`, `acceptText` (the
// main button's word), `rejectText` (Cancel's, where Cancel is ambiguous), standardButtons as QQC2.Dialog. Kante: KanteDialog. Under Shinki
// +shinki/LookDialog.qml (ShinkiDialog).
KanteDialog {
    enum Span {
        Fit,
        Small,
        Medium,
        Large
    }
    property int span: LookDialog.Span.Fit

    size: span === LookDialog.Span.Small ? KanteDialog.Size.Small
        : span === LookDialog.Span.Medium ? KanteDialog.Size.Medium
        : span === LookDialog.Span.Large ? KanteDialog.Size.Large : KanteDialog.Size.Fit
}
