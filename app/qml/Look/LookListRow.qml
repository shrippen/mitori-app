import Kante

// LookListRow: KanteListRow under Breeze, Material, Kante and Leinen; under Shinki +shinki/LookListRow.qml.
// Pages use the part of its interface that ShinkiListRow has too.
KanteListRow {
    // A kanji before the name (Shinki: red, Japanese face); Kante shows it as the leading figure.
    property string glyph: ""
    leadingText: glyph
    // Long names whole, as under Shinki: a technique's name cut with "…" says nothing.
    overflow: KanteListRow.Overflow.Wrap
}
