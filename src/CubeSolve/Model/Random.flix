///
/// Uniform random cube states, in two flavours that differ in their effect.
///
/// ```
/// sampleDeterministic(seed, n)   pure, reproducible, threads the next seed
/// sampleSecure(n)                \ IO, reads the platform entropy source
/// ```
///
/// That difference is deliberate and is the reason both exist. A fixture, a
/// regression test and a reported bug all need the same state back tomorrow;
/// a scramble handed to a competitor must not be predictable. The type says
/// which one you have.
///
/// The deterministic generator is **SplitMix64, implemented here**, and not the
/// platform's default generator. `java.util.Random`'s output is not guaranteed
/// stable across JDK versions, and a checked-in fixture generated from it would
/// quietly stop matching after an upgrade -- with the failure appearing in
/// whatever code consumed the fixture rather than in the generator.
///
/// This samples a *state*, not a scramble sequence. A scramble is the inverse
/// of a solution to a sampled state, needs a solver, and lives in
/// `CubeSolve.Scramble`.
///
mod CubeSolve.Model.Random {

    import java.security.SecureRandom

    use CubeSolve.Model.Cube
    use CubeSolve.Model.Cube.Cube
    use CubeSolve.Model.Validate
    use Orbit64.Coord.Coord
    use Orbit64.Coord.Coord.{CornerCoord, MidgeCoord}

    ///
    /// The largest `Int64`, and so the top of the range a raw draw covers.
    ///
    def maxInt64(): Int64 = 9223372036854775807i64

    ///
    /// The next 64 bits from `seed`, and the seed after it.
    ///
    /// SplitMix64. The shifts are logical rather than arithmetic, which is what
    /// the masking below is for: Flix's `rightShift` sign-extends, and letting
    /// the sign bit smear would ruin the avalanche.
    ///
    pub def nextInt64(seed: Int64): (Int64, Int64) =
        let advanced = seed + -7046029254386353131i64;   // the golden-ratio odd constant
        let a = mix(advanced, 30, -4658895280553007687i64);
        let b = mix(a, 27, -7723592293110705685i64);
        (xorShift(b, 31), advanced)

    ///
    /// One SplitMix64 round: xor in the high bits, then multiply.
    ///
    def mix(x: Int64, shift: Int32, multiplier: Int64): Int64 =
        xorShift(x, shift) * multiplier

    ///
    /// `x` xored with itself shifted right by `shift`, without sign extension.
    ///
    def xorShift(x: Int64, shift: Int32): Int64 =
        Int64.bitwiseXor(x, unsignedShiftRight(x, shift))

    ///
    /// `x` shifted right by `shift`, filling with zeros rather than the sign.
    ///
    def unsignedShiftRight(x: Int64, shift: Int32): Int64 =
        let keep = Int64.leftShift(1i64, 64 - shift) - 1i64;
        Int64.bitwiseAnd(Int64.rightShift(x, shift), keep)

    ///
    /// A uniform draw from `0 ..< bound`, and the seed after it.
    ///
    /// Rejection rather than a bare remainder. At the bounds this engine uses
    /// the bias would be about one part in `2^60` and no test could ever see
    /// it, but "uniform" is a claim made in the documentation and in a gate, so
    /// it is made true rather than nearly true.
    ///
    pub def nextBelow(bound: Int32, seed: Int64): (Int32, Int64) =
        if (bound <= 1) (0, snd(nextInt64(seed))) else drawBelow(bound, seed)

    ///
    /// The rejection loop behind `nextBelow`.
    ///
    def drawBelow(bound: Int32, seed: Int64): (Int32, Int64) =
        let b = Int32.toInt64(bound);
        // The largest draw that leaves a whole number of complete cycles.
        let overhang = Int64.modulo(Int64.modulo(maxInt64(), b) + 1i64, b);
        let highest = maxInt64() - overhang;
        let (raw, next) = nextInt64(seed);
        let v = Int64.bitwiseAnd(raw, maxInt64());   // drop the sign bit
        if (v <= highest)
            (Int64.modulo(v, b) |> Int64.tryToInt32 |> Option.getWithDefault(0), next)
        else
            drawBelow(bound, next)

    ///
    /// A uniform permutation of `0 ..< k`, and the seed after it.
    ///
    /// Fisher-Yates, in a region: the shuffling is mutation, the function is
    /// pure, and the array cannot escape to make that a lie.
    ///
    pub def permutation(k: Int32, seed: Int64): (Vector[Int32], Int64) = region rc {
        let slots = Array.init(rc, i -> i, k);
        def loop(i, s) =
            if (i <= 0) s
            else {
                let (j, next) = nextBelow(i + 1, s);
                let held = Array.get(i, slots);
                Array.put(Array.get(j, slots), i, slots);
                Array.put(held, j, slots);
                loop(i - 1, next)
            };
        let after = loop(k - 1, seed);
        (Array.toVector(slots), after)
    }

    ///
    /// A uniform orientation vector of `k` entries, each below `modulus`, whose
    /// entries sum to `0 mod modulus`.
    ///
    /// The last entry is forced by the others, so `k - 1` are drawn and the
    /// remainder is computed. Drawing all `k` and rejecting would be uniform
    /// too, and would throw away most of its draws for nothing.
    ///
    pub def orientation(k: Int32, modulus: Int32, seed: Int64): (Vector[Int32], Int64) =
        def loop(i, s, acc) =
            if (i <= 0) (List.reverse(acc), s)
            else {
                let (v, next) = nextBelow(modulus, s);
                loop(i - 1, next, v :: acc)
            };
        let (free, after) = loop(k - 1, seed, Nil);
        let forced = Int32.modulo(modulus - Int32.modulo(List.sum(free), modulus), modulus);
        (List.toVector(List.append(free, forced :: Nil)), after)

    ///
    /// A uniform state of an `n x n x n`, and the seed after it.
    ///
    /// Uniform over the states turning can *reach*, not over the states the
    /// codec can encode -- those differ by a factor of two on a 3x3x3, which is
    /// exactly the half that the coupled permutation parity rules out. Drawing
    /// and rejecting keeps the result uniform over what remains; correcting a
    /// rejected draw in place would be uniform too, and would be harder to
    /// argue.
    ///
    pub def sampleDeterministic(seed: Int64, n: Int32): Result[String, (Cube, Int64)] =
        if (not CubeSolve.supports(n))
            Err("cannot sample a ${n}x${n}x${n}: this engine derives reachability "
                + "invariants for the 2x2x2 and 3x3x3 only, and a sample it cannot "
                + "certify is worse than none")
        else
            Ok(rejectUntilReachable(n, seed))

    ///
    /// Draw until the draw is reachable.
    ///
    /// On a 3x3x3 the parities disagree half the time, so this averages two
    /// draws. On a 2x2x2 nothing is ever rejected.
    ///
    def rejectUntilReachable(n: Int32, seed: Int64): (Cube, Int64) =
        let (orbits, next) = drawOrbits(n, seed);
        match Cube.ofOrbits(n, orbits) {
            case Ok(c) if Validate.isReachable(c) => (c, next)
            case _                                => rejectUntilReachable(n, next)
        }

    ///
    /// One unconstrained draw of every orbit an `n x n x n` has.
    ///
    def drawOrbits(n: Int32, seed: Int64): (List[Coord], Int64) =
        let (corners, afterCorners) = drawCorners(seed);
        if (n == 2)
            (corners :: Nil, afterCorners)
        else
            let (midges, afterMidges) = drawMidges(afterCorners);
            (corners :: midges :: Nil, afterMidges)

    ///
    /// One unconstrained draw of the corner orbit.
    ///
    def drawCorners(seed: Int64): (Coord, Int64) =
        let (cp, afterPerm) = permutation(8, seed);
        let (co, afterTwist) = orientation(8, 3, afterPerm);
        (CornerCoord(cp, co), afterTwist)

    ///
    /// One unconstrained draw of the midge orbit.
    ///
    def drawMidges(seed: Int64): (Coord, Int64) =
        let (ep, afterPerm) = permutation(12, seed);
        let (eo, afterFlip) = orientation(12, 2, afterPerm);
        (MidgeCoord(ep, eo), afterFlip)

    ///
    /// A uniform state of an `n x n x n`, seeded from the platform's entropy.
    ///
    /// Only the seed comes from `SecureRandom`; the state is then drawn by the
    /// same pure generator, so the two samplers cannot drift apart in what they
    /// consider uniform. The `IO` is real and confined to one line.
    ///
    pub def sampleSecure(n: Int32): Result[String, Cube] \ IO =
        let seed = (new SecureRandom()).nextLong();
        sampleDeterministic(seed, n) |> Result.map(fst)

}
