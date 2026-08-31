///
/// Command line options, described once and parsed by the standard library.
///
/// `Util.GetOpt` does the parsing. Writing it by hand was a steady source of
/// small wrongness: `--help` was accepted and ignored by every command except
/// `help` itself, and each option had its own extractor that had to agree with
/// every other one about what "the rest of the arguments" meant.
///
/// Describing an option here does four things at once -- it is parsed, it is
/// rejected when unknown, it appears in `--help`, and it accepts both
/// `--flag value` and `--flag=value` -- so the description and the behaviour
/// cannot drift apart.
///
/// **Options are per command.** `--budget` means nothing to `show`, and a
/// command line that silently accepts it teaches the wrong thing. Each command
/// names the options it takes, and anything else is an error naming the command.
///
mod Options {

    use Util.GetOpt.{ArgDescr, ArgOrder, OptionDescr}
    use Util.GetOpt.ArgDescr.{NoArg, ReqArg}

    ///
    /// One option, once parsed.
    ///
    pub enum Flag with Eq, ToString {
        /// `--json`: machine-readable output.
        case Json
        /// `--help`: what this command takes.
        case Help
        /// `--size n`: which cube.
        case Size(Int32)
        /// `--budget name`: how hard the search may work.
        case Budget(String)
        /// `--method name`: which solving method.
        case Method(String)
        /// `--profile name`: which algorithm variant to prefer.
        case Profile(String)
        /// `--quiet`, `--verbose`, `--debug`, `--trace`: how much to say.
        case Loudness(Verbosity.Level)
        /// `--scramble`: solve a fresh random scramble rather than an argument.
        case Scramble
    }

    ///
    /// Every option, and the commands that take it.
    ///
    /// `--json`, `--help` and the loudness flags are on every command: the
    /// first two because every command produces output somebody may want as
    /// data or may need explained, and the third because any command can be the
    /// one that takes a surprising length of time.
    ///
    def descriptors(command: String): List[OptionDescr[Flag]] =
        let common =
            { optionIds = 'h' :: Nil, optionNames = "help" :: Nil,
              argDescriptor = NoArg(Flag.Help),
              explanation = "what this command takes" }
            :: { optionIds = Nil, optionNames = "json" :: Nil,
                 argDescriptor = NoArg(Flag.Json),
                 explanation = "machine-readable output" }
            :: { optionIds = 'v' :: Nil, optionNames = "verbose" :: Nil,
                 argDescriptor = NoArg(Flag.Loudness(Verbosity.Level.Verbose)),
                 explanation = "say what is happening, and what it cost" }
            :: { optionIds = Nil, optionNames = "debug" :: Nil,
                 argDescriptor = NoArg(Flag.Loudness(Verbosity.Level.Debug)),
                 explanation = "also say why: cache misses, table sizes" }
            :: { optionIds = Nil, optionNames = "trace" :: Nil,
                 argDescriptor = NoArg(Flag.Loudness(Verbosity.Level.Trace)),
                 explanation = "also say every step as it is taken" }
            :: { optionIds = 'q' :: Nil, optionNames = "quiet" :: Nil,
                 argDescriptor = NoArg(Flag.Loudness(Verbosity.Level.Quiet)),
                 explanation = "the answer and nothing else" }
            :: Nil;
        let size =
            { optionIds = 'n' :: Nil, optionNames = "size" :: Nil,
              argDescriptor = ReqArg(s -> Int32.fromString(s) |> Option.map(Flag.Size), "n"),
              explanation = "the cube: 2, 3, 4 or 5" };
        let budget =
            { optionIds = 'b' :: Nil, optionNames = "budget" :: Nil,
              argDescriptor = ReqArg(s -> Some(Flag.Budget(s)), "name"),
              explanation = "search effort: ${Budgets.names()}" };
        let method =
            { optionIds = 'm' :: Nil, optionNames = "method" :: Nil,
              argDescriptor = ReqArg(s -> Some(Flag.Method(s)), "name"),
              explanation = "how to solve: ${Methods.names()}" };
        let profile =
            { optionIds = 'p' :: Nil, optionNames = "profile" :: Nil,
              argDescriptor = ReqArg(s -> Some(Flag.Profile(s)), "name"),
              explanation = "which algorithm variant: ${Args.profileNames()}" };
        let scramble =
            { optionIds = 's' :: Nil, optionNames = "scramble" :: Nil,
              argDescriptor = NoArg(Flag.Scramble),
              explanation = "solve a fresh random scramble instead of an argument" };
        match command {
            case "solve"    => method :: budget :: size :: scramble :: common
            case "show"     => size :: common
            case "identify" => size :: common
            case "scramble" => size :: common
            case "patterns" => size :: common
            case "oll"      => profile :: common
            case "pll"      => profile :: common
            case _          => common
        }

    ///
    /// Parse `args` for `command`: the options it carried, and what was left.
    ///
    /// An unknown option is an error rather than an operand, so a mistyped
    /// `--budgt` is refused instead of being read as part of a scramble.
    ///
    pub def parse(
        command: String,
        args: List[String]
    ): Result[String, {flags = List[Flag], operands = List[String]}] =
        match Util.GetOpt.getOpt(ArgOrder.Permute, descriptors(command), args) {
            case Validation.Success(r) =>
                Ok({ flags = r#options, operands = r#nonOptions })
            case Validation.Failure(errs) =>
                let reasons = Nec.toList(errs) |> List.map(String.trim) |> List.join("; ");
                Err("${reasons}. Try 'cubesolve ${command} --help'")
        }

    ///
    /// What `command` takes, as text.
    ///
    pub def help(command: String): String =
        Util.GetOpt.usageInfo("cubesolve ${command} takes:", descriptors(command))

    ///
    /// Whether a flag was given.
    ///
    pub def has(flags: List[Flag], f: Flag): Bool = List.memberOf(f, flags)

    ///
    /// The loudest level asked for.
    ///
    ///
    /// The level asked for, or `Normal` if none was.
    ///
    /// The *last* level given wins rather than the loudest, so `--verbose
    /// --quiet` is quiet: a later flag overriding an earlier one is what a
    /// shell alias needs, and "loudest wins" would make `--quiet` impossible to
    /// add to a command line that already had `--verbose` in it.
    ///
    pub def loudness(flags: List[Flag]): Verbosity.Level =
        flags |> List.foldLeft((chosen, f) -> match f {
            case Flag.Loudness(l) => l
            case _                => chosen
        }, Verbosity.Level.Normal)

    ///
    /// The value of a `--size`, if one was given.
    ///
    pub def size(flags: List[Flag]): Option[Int32] =
        flags |> List.findMap(f -> match f {
            case Flag.Size(n) => Some(n)
            case _            => None
        })

    ///
    /// The value of a named string option, if one was given.
    ///
    pub def budget(flags: List[Flag]): Option[String] =
        flags |> List.findMap(f -> match f {
            case Flag.Budget(s) => Some(s)
            case _              => None
        })

    ///
    /// The value of `--method`, if one was given.
    ///
    pub def method(flags: List[Flag]): Option[String] =
        flags |> List.findMap(f -> match f {
            case Flag.Method(s) => Some(s)
            case _              => None
        })

    ///
    /// The value of `--profile`, if one was given.
    ///
    pub def profile(flags: List[Flag]): Option[String] =
        flags |> List.findMap(f -> match f {
            case Flag.Profile(s) => Some(s)
            case _               => None
        })
}
