import Kante

// LookOdometer: KanteOdometer under Breeze, Material, Kante and Leinen; under Shinki +shinki/LookOdometer.qml.
// Pages use the part of its interface that ShinkiOdometer has too: value, digits, font, color.
// A page's counter shows a live value (a download's percent): Kante's Live pace, which keeps up
// with a change every 250 ms (Show restarts its staggered roll on each one).
KanteOdometer {
    pace: KanteOdometer.Pace.Live
}
