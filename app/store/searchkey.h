#pragma once

#include <QString>
#include <QList>
#include <QStringList>

#include <algorithm>

inline bool isDash(char32_t c)
{
    return c == u'-' || c == u'‐' || c == u'‑' || c == u'‒' || c == u'–' || c == u'—' || c == u'―' || c == u'⸺' || c == u'−';
}

inline bool isApostrophe(char32_t c)
{
    return c == u'\'' || c == u'’' || c == u'‘' || c == u'ʼ' || c == u'ʻ' || c == u'´' || c == u'`';
}

// The form search compares: lower case, without accents (Ô-dachi finds o dachi, größer finds
// grosser; kana keep their dakuten), full-width letters folded, apostrophes and invisible
// characters (soft hyphen) left out (San'nin as sannin), dashes, other punctuation, symbols and
// emoji as spaces ("(Shiho-nage)," starts and ends words) except a point or comma between digits
// (3,5), spaces simplified. `keepHyphens` writes dashes as "-" instead. By code point, so that an
// emoji beyond the BMP counts as a symbol.
inline QString searchKey(const QString &text, bool keepHyphens = false)
{
    // Apostrophes go before the decomposition, which makes ´ a space and an accent.
    QString plain = text;
    plain.removeIf([](QChar c) { return isApostrophe(c.unicode()); });
    const QList<uint> points = plain.normalized(QString::NormalizationForm_KD).toUcs4();
    const auto digit = [&points](qsizetype i) {
        return i >= 0 && i < points.size() && QChar::isDigit(char32_t(points[i]));
    };
    QString key;
    for (qsizetype i = 0; i < points.size(); ++i) {
        const char32_t c = points[i];
        const QChar::Category category = QChar::category(c);
        // Combining marks (accents, variation selectors of emoji) and invisible characters go;
        // the kana voicing marks stay (NFC joins them again: が).
        if ((category == QChar::Mark_NonSpacing && c != 0x3099 && c != 0x309A) || category == QChar::Other_Format
                || isApostrophe(c)) {
            continue;
        }
        if (category == QChar::Mark_Enclosing) {
            key += QChar(u' ');     // a keycap: 1️⃣ is a symbol
            continue;
        }
        const char32_t lower = QChar::toLower(c);
        if (lower == u'ß') {
            key += QStringLiteral("ss");
        } else if (isDash(c)) {
            key += keepHyphens ? QChar(u'-') : QChar(u' ');
        } else if ((c == u'.' || c == u',') && digit(i - 1) && digit(i + 1)) {
            key += QChar(c);
        } else if (QChar::isPunct(c) || QChar::isSymbol(c)) {
            key += QChar(u' ');
        } else {
            key += QString::fromUcs4(&lower, 1);
        }
    }
    return key.simplified().normalized(QString::NormalizationForm_C);   // kana with dakuten as one
}

// The words of a query; a word may keep its hyphens (shiho-nage, see SearchText).
inline QStringList searchWords(const QString &query)
{
    QStringList words;
    for (const QString &w : searchKey(query, true).split(u' ', Qt::SkipEmptyParts)) {
        if (!QString(w).remove(u'-').isEmpty()) {
            words << w;
        }
    }
    return words;
}

// By code point: a kanji beyond the BMP (𠮟) is two UTF-16 units.
inline bool hasKanji(const QString &text)
{
    const QList<uint> points = text.toUcs4();
    return std::any_of(points.cbegin(), points.cend(), [](uint c) { return QChar::script(char32_t(c)) == QChar::Script_Han; });
}

inline QString withoutHiragana(const QString &text)
{
    QList<uint> points = text.toUcs4();
    points.removeIf([](uint c) { return QChar::script(char32_t(c)) == QChar::Script_Hiragana; });
    return QString::fromUcs4(reinterpret_cast<const char32_t *>(points.constData()), points.size());
}

// A text asked whether it names something (a technique in a note): the name's words joined must be
// a run of whole words of the text, so that spaces and hyphens do not matter ("Shihô-nage" in "shiho
// nage aus" and "Shihonage,") but word ends do (not in "Shihonagen"). Punctuation, a line break or a
// dash between spaces part names: "Ikkyo, Shiho-nage" does not name Ikkyo-shiho-nage. Only the same
// punctuation at the same place of a name does not: "Sankajô-kime-osae / -nage" names itself,
// "Sankajô-kime-osae. Nage" does not name it. Digits never join: "Ô-dachi 1-3" does not name form
// 13. With kanji anywhere: Japanese has no spaces, and okurigana may differ.
class NamedIn
{
public:
    explicit NamedIn(const QString &text)
    {
        for (const Clause &clause : clauses(text)) {
            m_words += searchKey(clause.text).split(u' ', Qt::SkipEmptyParts);
            m_ends << m_words.size();
            m_parts << clause.end;
        }
    }

    // Where a name stands: from word `first` to word `last` of the text.
    struct Span {
        qsizetype first = 0;
        qsizetype last = 0;

        bool inside(const Span &other) const
        {
            return other.first <= first && last <= other.last && (other.first < first || last < other.last);
        }
    };

    // Every place of a name; none for a name with kanji (those have no word ends).
    QList<Span> spans(const QString &name) const
    {
        QList<Span> found;
        const QString joined = searchKey(name).remove(u' ');
        if (joined.isEmpty() || hasKanji(joined)) {
            return found;
        }
        for (qsizetype i = 0; i < m_words.size(); ++i) {
            // Word by word along the name, ending at the first that differs: most end at once.
            qsizetype letters = 0;
            qsizetype j = i;
            for (; j < m_words.size() && letters < joined.size(); ++j) {
                const QString &word = m_words.at(j);
                if (!QStringView(joined).sliced(letters).startsWith(word)) {
                    break;
                }
                if (j > i && !joins(joined, letters, j, name)) {
                    break;
                }
                letters += word.size();
            }
            if (letters == joined.size()) {
                found << Span{i, j - 1};
            }
        }
        return found;
    }

    bool names(const QString &name) const
    {
        const QString joined = searchKey(name).remove(u' ');
        if (joined.isEmpty() || !hasKanji(joined)) {
            return !spans(name).isEmpty();
        }
        const QString bare = withoutHiragana(joined);
        return !bare.isEmpty() && withoutHiragana(m_words.join(QString())).contains(bare);
    }

private:
    // A piece of text between what parts names, and the character that ended it (dashes as "-").
    struct Clause {
        QString text;
        QString end;
    };

    static QList<Clause> clauses(const QString &text)
    {
        QList<Clause> result;
        const QList<uint> points = text.toUcs4();
        QString clause;
        for (qsizetype i = 0; i <= points.size(); ++i) {
            if (i < points.size() && !endsClause(points, i)) {
                const char32_t c = points[i];
                clause += QString::fromUcs4(&c, 1);
                continue;
            }
            QString end;
            if (i < points.size()) {
                const char32_t c = isDash(points[i]) ? char32_t(u'-') : char32_t(points[i]);
                end = QString::fromUcs4(&c, 1);
            }
            result << Clause{clause, end};
            clause.clear();
        }
        return result;
    }

    // Whether word `next` may go on the first `letters` of `joined`, the joined `name`.
    bool joins(const QString &joined, qsizetype letters, qsizetype next, const QString &name) const
    {
        if (joined.at(letters - 1).isDigit() && m_words.at(next).front().isDigit()) {
            return false;
        }
        if (!std::binary_search(m_ends.cbegin(), m_ends.cend(), next)) {
            return true;
        }

        // A clause of the text ends here: the name must have the same punctuation there.
        QString inText;
        for (qsizetype k = 0; k < m_ends.size(); ++k) {
            if (m_ends.at(k) == next) {
                inText += m_parts.at(k);
            }
        }
        QString inName;
        qsizetype at = 0;
        for (const Clause &clause : clauses(name)) {
            at += searchKey(clause.text).remove(u' ').size();
            if (at == letters) {
                inName += clause.end;
            }
        }
        return partsAlike(inText) == partsAlike(inName);
    }

    // A dash beside other punctuation counts for nothing ("/ -nage" as "/-nage", where it ends no
    // clause); alone it does, unlike no punctuation at all.
    static QString partsAlike(const QString &parts)
    {
        const QString other = QString(parts).remove(u'-');
        return other.isEmpty() ? parts.left(1) : other;
    }

    // Whether the character parts names. Not a hyphen, an apostrophe, a point or comma in a number,
    // or a point before one ("Nr. 5").
    static bool endsClause(const QList<uint> &points, qsizetype i)
    {
        const char32_t c = points[i];
        const auto space = [&points](qsizetype at) {
            return at >= 0 && at < points.size() && QChar::isSpace(char32_t(points[at]));
        };
        if (c == u'\n' || c == u'\r' || c == 0x2028 || c == 0x2029) {
            return true;
        }
        if (isApostrophe(c)) {
            return false;
        }
        if (isDash(c)) {
            return space(i - 1) || space(i + 1);
        }
        if (c == u'.' || c == u',') {
            qsizetype next = i + 1;
            while (c == u'.' && space(next)) {
                ++next;
            }
            if (next < points.size() && QChar::isDigit(char32_t(points[next]))
                && (c == u'.' || (i > 0 && QChar::isDigit(char32_t(points[i - 1]))))) {
                return false;
            }
        }
        return QChar::isPunct(c) || QChar::isSymbol(c);
    }

    QStringList m_words;
    QList<qsizetype> m_ends;        // where each clause ends in m_words
    QStringList m_parts;            // what ended it (Clause::end)
};

// A text to search (a technique's fields, a note): whether every word of a query occurs in it.
// A word matches inside a word, or joined from the start of a word across the following
// hyphens and spaces: across a hyphen it may end anywhere (shihon finds Shiho-nage while
// typing), across a space only where a word ends (nurein finds "nur ein", mitte not "mit
// Tenkan"). A hyphenated word matches joined, or each part from the start of a word
// (ikkyo-irimi as ikkyo irimi; ai-hanmi not in Kaiten-nage). A word with kanji leaves the
// okurigana out on both sides (切り落とし finds 切り落し).
class SearchText
{
public:
    explicit SearchText(const QString &text)
    {
        const QString key = searchKey(text, true);
        m_key = QString(key).replace(u'-', u' ');
        QChar before = u' ';
        for (const QChar c : key) {
            if (c == u' ' || c == u'-') {
                if (!m_joined.isEmpty()) {
                    m_ends << m_joined.size();
                    if (c == u' ') {
                        m_spaces << m_joined.size();
                    }
                }
            } else {
                if (before == u' ' || before == u'-') {
                    m_starts << m_joined.size();
                }
                m_joined += c;
            }
            before = c;
        }
        m_ends << m_joined.size();
    }

    bool matches(const QStringList &words) const
    {
        return std::all_of(words.cbegin(), words.cend(), [this](const QString &w) { return find(w) >= 0; });
    }

    // Where a word of a query matches, as a letter of the text without spaces and hyphens, or -1;
    // a hyphenated word matched part by part: where its first part does.
    //   SearchText("Dann Shihô-nage").find("shihon")  →  4
    qsizetype find(const QString &w) const
    {
        if (!w.contains(u'-')) {
            const qsizetype at = m_key.indexOf(w);
            if (at >= 0) {
                return at - QStringView(m_key).first(at).count(u' ');
            }
            return fromWordStart(w);
        }
        const qsizetype joined = fromWordStart(QString(w).remove(u'-'));
        if (joined >= 0) {
            return joined;
        }

        qsizetype first = -1;
        for (const QString &part : w.split(u'-', Qt::SkipEmptyParts)) {
            const qsizetype at = fromWordStart(part);
            if (at < 0) {
                return -1;
            }
            first = first < 0 ? at : first;
        }
        return first;
    }

private:
    qsizetype fromWordStart(const QString &w) const
    {
        const QStringView joined(m_joined);
        if (joined.contains(w)) {
            for (const qsizetype at : m_starts) {
                if (!joined.sliced(at).startsWith(w)) {
                    continue;
                }
                const qsizetype end = at + w.size();
                const auto space = std::upper_bound(m_spaces.cbegin(), m_spaces.cend(), at);
                const bool acrossSpace = space != m_spaces.cend() && *space < end;
                if (!acrossSpace || std::binary_search(m_ends.cbegin(), m_ends.cend(), end)) {
                    return at;
                }
            }
        }
        if (!hasKanji(w)) {
            return -1;
        }
        if (m_kanji.isNull()) {
            m_kanji = withoutHiragana(m_joined);
        }
        const QString bare = withoutHiragana(w);
        const qsizetype at = bare.isEmpty() ? -1 : m_kanji.indexOf(bare);
        if (at < 0) {
            return -1;
        }

        // m_kanji is m_joined without hiragana (all in the BMP): count back to m_joined.
        qsizetype kept = 0;
        for (qsizetype i = 0; i < m_joined.size(); ++i) {
            if (QChar::script(m_joined.at(i).unicode()) == QChar::Script_Hiragana) {
                continue;
            }
            if (kept == at) {
                return i;
            }
            ++kept;
        }
        return -1;
    }

    QString m_key;                  // as searchKey gives it
    QString m_joined;               // without spaces and hyphens
    QList<qsizetype> m_starts;      // where words begin in m_joined
    QList<qsizetype> m_ends;        // where words end
    QList<qsizetype> m_spaces;      // where a space (not a hyphen) was
    mutable QString m_kanji;
};

inline constexpr qsizetype kExcerptLength = 140;
inline constexpr qsizetype kExcerptBefore = 40;

// A text's key as SearchText compares it: without spaces and hyphens.
inline QString joinedKey(const QString &text)
{
    return searchKey(text, true).remove(u' ').remove(u'-');
}

// Where letter `at` of a text's joined key stands in the text as written, or -1: the shortest
// start of the text whose key is longer than `at`, found by halving (a key only grows with the
// text; folding makes a letter two (ß) or none (an accent)).
//   textIndex("Die Hüfte führen", 8)  →  10
inline qsizetype textIndex(const QString &text, qsizetype at)
{
    if (joinedKey(text).size() <= at) {
        return -1;
    }
    qsizetype low = 0;
    qsizetype high = text.size();
    while (high - low > 1) {
        const qsizetype mid = (low + high) / 2;
        if (joinedKey(text.left(mid)).size() > at) {
            high = mid;
        } else {
            low = mid;
        }
    }
    const qsizetype i = high - 1;
    return i > 0 && text.at(i).isLowSurrogate() ? i - 1 : i;
}

// The part of a comment to show for a query: the first line that holds every word (else one that
// holds the first word, else the first line), shortened to about kExcerptLength letters around the
// first word found in it, with "…" where it was cut.
//   searchExcerpt("Intro\nDer Hüftwurf folgt …", {"huftwurf"})  →  "Der Hüftwurf folgt …"
inline QString searchExcerpt(const QString &text, const QStringList &words)
{
    const QStringList lines = text.split(u'\n', Qt::SkipEmptyParts);
    QString line;
    for (const QString &l : lines) {
        if (SearchText(l).matches(words)) {
            line = l;
            break;
        }
    }
    for (const QString &l : lines) {
        if (!line.isEmpty()) {
            break;
        }
        if (SearchText(l).matches({words.first()})) {
            line = l;
        }
    }
    if (line.isEmpty() && !lines.isEmpty()) {
        line = lines.first();
    }
    line = line.simplified();
    if (line.size() <= kExcerptLength) {
        return line;
    }

    // Where the first word found stands in the line as written; else the start.
    const SearchText search(line);
    qsizetype at = 0;
    for (const QString &w : words) {
        const qsizetype found = search.find(w);
        if (found >= 0) {
            at = textIndex(line, found);
            break;
        }
    }
    at = std::max<qsizetype>(0, at);
    qsizetype from = std::max<qsizetype>(0, at - kExcerptBefore);
    if (from > 0) {
        // Start at a word, not in the middle of one.
        const qsizetype space = line.indexOf(u' ', from);
        from = space >= 0 && space < at ? space + 1 : from;
    }
    // Cuts between characters, not inside one of two UTF-16 units (𠮟, an emoji).
    if (from > 0 && line.at(from).isLowSurrogate()) {
        --from;
    }
    qsizetype length = kExcerptLength;
    if (from + length < line.size() && line.at(from + length - 1).isHighSurrogate()) {
        ++length;
    }
    QString part = line.mid(from, length);
    const bool cutEnd = from + length < line.size();
    if (cutEnd) {
        const qsizetype space = part.lastIndexOf(u' ');
        part = space > kExcerptLength / 2 ? part.left(space) : part;
    }
    return (from > 0 ? QStringLiteral("…") : QString()) + part + (cutEnd ? QStringLiteral("…") : QString());
}
