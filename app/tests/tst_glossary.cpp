#include <QSignalSpy>
#include <QTest>

#include "glossary.h"

namespace {

QVariantMap find(const QVariantList &rows, const QString &word)
{
    for (const QVariant &r : rows) {
        if (r.toMap().value(QStringLiteral("word")) == word) {
            return r.toMap();
        }
    }
    return {};
}

QStringList words(const QVariantList &rows)
{
    QStringList result;
    for (const QVariant &r : rows) {
        result << r.toMap().value(QStringLiteral("word")).toString();
    }
    return result;
}

} // namespace

class TstGlossary : public QObject
{
    Q_OBJECT

    static Catalog loaded()
    {
        Catalog c;
        c.load(QStringLiteral(MITORI_DATEN_JSON));
        return c;
    }

private slots:
    void loadsWords()
    {
        const Glossary glossary(loaded(), QStringLiteral("mock"));
        QVERIFY(glossary.words().size() > 219);
        QVERIFY(glossary.source().contains(QLatin1String("shinkiryu.de")));
        const QVariantMap kiri = find(glossary.words(), QStringLiteral("Kiri-otoshi"));
        QCOMPARE(kiri.value(QStringLiteral("letter")).toString(), QStringLiteral("K"));
        QCOMPARE(kiri.value(QStringLiteral("speech")).toString(), QStringLiteral("切り落し"));     // the kanji
        // Without kanji the reading in kana.
        const QVariantMap atemi = find(glossary.words(), QStringLiteral("Atemi"));
        QCOMPARE(atemi.value(QStringLiteral("jp")).toString(), QString());
        QCOMPARE(atemi.value(QStringLiteral("speech")).toString(), QStringLiteral("あてみ"));
        QCOMPARE(atemi.value(QStringLiteral("reading")).toString(), QStringLiteral("あてみ"));
        // Every word has something to say.
        for (const QVariant &w : glossary.words()) {
            QVERIFY(!w.toMap().value(QStringLiteral("speech")).toString().isEmpty());
        }
    }

    // A–Z sections: every word under its first letter, in order.
    void lettersInOrder()
    {
        const Glossary glossary(loaded(), QStringLiteral("mock"));
        QString last;
        for (const QVariant &w : glossary.words()) {
            const QString letter = w.toMap().value(QStringLiteral("letter")).toString();
            QVERIFY2(letter >= last, qPrintable(letter + u" after " + last));
            QCOMPARE(letter.size(), 1);
            last = letter;
        }
        QCOMPARE(last, QStringLiteral("Z"));
    }

    // Romaji with or without hyphens, kanji with other okurigana, kana, German.
    void searchNormalises()
    {
        const Glossary glossary(loaded(), QStringLiteral("mock"));
        const QStringList kiri = words(glossary.search(QStringLiteral("Kiri-otoshi")));
        QVERIFY(kiri.contains(QStringLiteral("Kiri-otoshi")));
        QCOMPARE(words(glossary.search(QStringLiteral("Kiriotoshi"))), kiri);
        QCOMPARE(words(glossary.search(QStringLiteral("KIRI OTOSHI"))), kiri);
        QCOMPARE(words(glossary.search(QStringLiteral("切り落とし"))), kiri);
        QVERIFY(words(glossary.search(QStringLiteral("きりおとし"))).contains(QStringLiteral("Kiri-otoshi")));
        QVERIFY(words(glossary.search(QStringLiteral("hüftwurf"))).contains(QStringLiteral("Koshi-nage")));
        QVERIFY(words(glossary.search(QStringLiteral("HUFTWURF"))).contains(QStringLiteral("Koshi-nage")));
        QVERIFY(words(glossary.search(QStringLiteral("ikkajo"))).contains(QStringLiteral("Ikkajô")));
        QVERIFY(glossary.search(QStringLiteral("  ")).isEmpty());
        QVERIFY(glossary.search(QStringLiteral("xyzzy")).isEmpty());
    }

    // English: the meaning is the lexicon's English (German where it has none), words that carry
    // German read English, the source too; the search finds what is shown, after a LanguageChange
    // also in a glossary built before.
    void english()
    {
        Glossary glossary(loaded(), QStringLiteral("mock"));
        QSignalSpy spy(&glossary, &Glossary::wordsChanged);
        QCOMPARE(find(glossary.words(), QStringLiteral("Koshi-nage")).value(QStringLiteral("meaning")).toString(),
                 QStringLiteral("Hüftwurf"));

        Catalog::setLanguage(Catalog::Language::English);
        QEvent event(QEvent::LanguageChange);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);
        const QVariantList words = glossary.words();
        const QStringList hip = ::words(glossary.search(QStringLiteral("hip throw")));
        const QStringList huft = ::words(glossary.search(QStringLiteral("hüftwurf")));
        const QStringList japanese = ::words(glossary.search(QStringLiteral("切り落とし")));
        const QString source = glossary.source();
        Catalog::setLanguage(Catalog::Language::German);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);

        QCOMPARE(spy.count(), 2);
        QCOMPARE(find(words, QStringLiteral("Koshi-nage")).value(QStringLiteral("meaning")).toString(), QStringLiteral("hip throw"));
        QCOMPARE(find(words, QStringLiteral("Kiri-otoshi")).value(QStringLiteral("meaning")).toString(), QString());
        QVERIFY(!find(words, QStringLiteral("Fuse (verb: fuseru)")).isEmpty());
        QVERIFY(hip.contains(QStringLiteral("Koshi-nage")));
        QVERIFY(huft.isEmpty());
        QVERIFY(japanese.contains(QStringLiteral("Kiri-otoshi")));
        QVERIFY(source.startsWith(QLatin1String("Lexicon")));
        QVERIFY(find(glossary.words(), QStringLiteral("Fuse (verb: fuseru)")).isEmpty());
    }

    // No Japanese voice (the mock engine has none): saying something does nothing.
    void silentWithoutVoice()
    {
        Glossary glossary(loaded(), QStringLiteral("mock"));
        QVERIFY(glossary.speech() != Glossary::Speech::Ready);
        glossary.say(QStringLiteral("合気道"));
        glossary.say(QString());
    }
};

QTEST_GUILESS_MAIN(TstGlossary)
#include "tst_glossary.moc"
