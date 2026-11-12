import Shinki

ShinkiHint {
    enum Importance {
        Info,
        Important,
        Error
    }
    property int importance: LookHint.Importance.Info
    // Only for the interface of LookHint: the title of a Shinki hint wraps already.
    property bool wrapTitle: false

    kind: importance === LookHint.Importance.Error ? ShinkiHint.Kind.Error
        : importance === LookHint.Importance.Important ? ShinkiHint.Kind.Important : ShinkiHint.Kind.Info
}
