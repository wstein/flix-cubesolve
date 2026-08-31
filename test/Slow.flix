///
/// The switch that makes a local run fast.
///
/// The suite is about seventeen minutes, and almost all of it is twenty tests
/// that build a large table or run the solver over many states. That is the
/// right gate for a merge and the wrong one for the loop you work in, so
/// `CUBESOLVE_FAST=1` leaves those twenty out and the rest finish in about a
/// minute:
///
/// ```sh
/// CUBESOLVE_FAST=1 ./flixw test     # about a minute, for working
/// ./flixw test                      # everything, about seventeen minutes
/// ```
///
/// **A skip is loud.** Each one prints what it left out and how to run it. A
/// gate nobody knows is disabled is worse than no gate, and a fast subset that
/// quietly became the only thing anyone ran would be exactly that.
///
/// This is the opposite switch to `CUBESOLVE_EXHAUSTIVE`, which *adds* the
/// whole pattern collection. Both default to the honest thing: full unless you
/// ask for less, and the largest gate only when you ask for more.
///
mod Slow {

    ///
    /// Whether to leave this test out, saying so if it does.
    ///
    /// `name` is the test, and `why` is what makes it slow -- a table it builds
    /// or a search it runs -- so the message says what coverage was given up
    /// rather than only that something was.
    ///
    pub def skip(name: String, why: String): Bool \ IO =
        match Sys.Env.handle(_ -> Sys.Env.getVar("CUBESOLVE_FAST"))(()) {
            case Some("1") =>
                println("${name}: SKIPPED under CUBESOLVE_FAST -- ${why}. "
                    + "Unset CUBESOLVE_FAST to run it; CI runs it on every "
                    + "release and nightly.");
                true
            case _ => false
        }
}
