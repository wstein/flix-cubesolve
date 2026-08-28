///
/// This project's own module.
///
/// Code declared here is documented under `Hello` and gets its own page from
/// `./flixw doc`. Anything left in the root namespace is instead folded into
/// the standard library's own `Prelude` page, where it is indistinguishable
/// from the library -- which is why only `main` lives out there, and only
/// because Flix requires the entry point at the root.
///
mod Hello {

    ///
    /// Returns the greeting for `name`.
    ///
    /// Kept apart from `main` so there is something to test: `main` is
    /// effectful and writes to the terminal, while this is pure and returns
    /// its result.
    ///
    pub def greeting(name: String): String = "Hello, ${name}!"

}

///
/// The main entry point.
///
def main(): Unit \ IO =
    println(Hello.greeting("World"))
