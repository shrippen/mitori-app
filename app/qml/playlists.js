.pragma library

// The player's list around a technique: its grade's techniques with a video on the device, so that
// previous and next work from the search, the map and today too (clickdummy "player"). A Lernpaket's
// technique ("lern/…") has its package's list (library).
const LESSON_PREFIX = "lern/"

function around(programme, videos, library, entry) {
    if (String(entry.id).startsWith(LESSON_PREFIX)) {
        return library.around(entry.id)
    }
    const discipline = String(entry.id).split("/")[0]
    const playable = r => r.kind === "entry" && !!r.video && videos.available(r.video.video)
    for (const grade of programme.grades(discipline)) {
        const rows = programme.entries(discipline, grade.id).filter(playable)
        const index = rows.findIndex(r => r.id === entry.id)
        if (index >= 0) {
            return { playlist: rows, index: index }
        }
    }
    return { playlist: [entry], index: 0 }
}
