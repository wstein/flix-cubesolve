///
/// Pure QR code generation and UTF-8 graphic rendering.
///
/// Implements ISO/IEC 18004 standard QR Code (Version 1-3, Levels L, M, Q, H)
/// with full 8-mask penalty evaluation, BCH(15, 5) format information,
/// Reed-Solomon GF(256) error correction, and Unicode half-block drawing
/// supporting dark (inverse) and light terminal themes.
///
mod CubeSolve.Render.Qr {

    import java.awt.image.BufferedImage
    import java.awt.Graphics2D
    import java.awt.Color
    import java.awt.Polygon
    import java.awt.RenderingHints
    import java.io.File
    import javax.imageio.ImageIO
    import java.lang.Throwable

    ///
    /// QR Error Correction Level.
    ///
    pub enum EcLevel with Eq, Order, ToString {
        case L
        case M
        case Q
        case H
    }

    ///
    /// Generate a compact UTF-8 QR code string from `text` (default Level L, dark theme).
    ///
    pub def render(text: String): String =
        renderWith(EcLevel.L, true, text)

    ///
    /// Generate a compact UTF-8 QR code string for light themes.
    ///
    pub def renderLight(text: String): String =
        renderWith(EcLevel.L, false, text)

    ///
    /// Generate a compact UTF-8 QR code string with the token centered below (default Level L).
    ///
    pub def renderWithToken(token: String): String =
        renderWithTokenAndEc(EcLevel.L, true, token)

    ///
    /// Generate a compact UTF-8 QR code string with explicit EC level and centered token.
    ///
    pub def renderWithTokenAndEc(ec: EcLevel, darkTheme: Bool, token: String): String = {
        let qr = renderWith(ec, darkTheme, token);
        let lines = String.split(regex = "\r?\n", qr);
        let width = match lines {
            case first :: _ => String.length(first)
            case Nil        => 0
        };
        let tokLen = String.length(token);
        let pad = if (width > tokLen) (width - tokLen) / 2 else 0;
        let padded = String.repeat(pad, " ") + token;
        qr + String.lineSeparator() + padded
    }

    ///
    /// Write a high-resolution PNG QR code to `path` with optional colorful cube logo (Level H).
    ///
    pub def writePng(path: String, text: String, withLogo: Bool): Result[String, Unit] \ IO = {
        let dummy = Vector.range(0, 54) |> Vector.map(i -> i / 9);
        writeCubePng(path, 3, dummy, text, withLogo)
    }

    ///
    /// Write a high-resolution PNG QR code with real 3D isometric cube state in the center.
    ///
    pub def writeCubePng(
        path: String,
        n: Int32,
        facelets: Vector[Int32],
        token: String,
        withLogo: Bool
    ): Result[String, Unit] \ IO =
        try {
            let bytes = String.toList(token) |> List.map(Char.toBmpCodePoint);
            let len = List.length(bytes);
            let (ver, totalData, numBlocks, dataPerBlock, ecPerBlock) =
                versionParams(EcLevel.H, len);
            let codewords = encodeBytes(
                (totalData, numBlocks, dataPerBlock, ecPerBlock),
                bytes
            );
            let matrix = buildOptimalMatrix(ver, EcLevel.H, codewords);
            let size = Vector.length(matrix);
            let scale = 14;
            let pad = 4;
            let dim = (size + 2 * pad) * scale;
            let img = new BufferedImage(dim, dim, 1);
            let g = img.createGraphics();
            g.setRenderingHint(
                RenderingHints.KEY_ANTIALIASING,
                RenderingHints.VALUE_ANTIALIAS_ON
            );
            let colWhite = new Color(255, 255, 255);
            let colDark = new Color(15, 23, 42);
            g.setColor(colWhite);
            g.fillRect(0, 0, dim, dim);
            g.setColor(colDark);
            drawModules(g, matrix, pad, scale);
            if (withLogo)
                drawObliqueLogo(g, n, facelets, size, scale)
            else ();
            g.dispose();
            let _ = ImageIO.write(img, "png", new File(path));
            Result.Ok(())
        } catch {
            case _ex: Throwable => Result.Err("Failed to write PNG file")
        }

    ///
    /// Draw black QR modules onto the Graphics2D context.
    ///
    def drawModules(
        g: Graphics2D,
        matrix: Vector[Vector[Int32]],
        pad: Int32,
        scale: Int32
    ): Unit \ IO = {
        let size = Vector.length(matrix);
        List.range(0, size) |> List.forEach(r ->
            List.range(0, size) |> List.forEach(c -> {
                if (Vector.get(c, Vector.get(r, matrix)) == 1) {
                    g.fillRect((c + pad) * scale, (r + pad) * scale, scale, scale)
                } else ()
            })
        )
    }

    ///
    /// The RGB colour for a face index with directional 3D shading factor.
    ///
    def faceColor(face: Int32, factor: Float64): Color \ IO = {
        let (br, bg, bb) = match face {
            case 0 => (248.0, 250.0, 252.0) // U - Crisp White
            case 1 => (220.0, 38.0, 38.0)   // R - Red
            case 2 => (22.0, 163.0, 74.0)   // F - Green
            case 3 => (234.0, 179.0, 8.0)   // D - Yellow
            case 4 => (234.0, 88.0, 12.0)   // L - Orange
            case 5 => (37.0, 99.0, 235.0)   // B - Blue
            case _ => (120.0, 120.0, 120.0)
        };
        let r = toInt(br * factor);
        let g = toInt(bg * factor);
        let b = toInt(bb * factor);
        new Color(r, g, b)
    }

    ///
    /// Convert Float64 to Int32 with fallback.
    ///
    def toInt(x: Float64): Int32 =
        Float64.tryToInt32(x) |> Option.getWithDefault(0)

    ///
    /// Draw the real 3D isometric cube state cut out as a hexagon (6-Eck) in the QR center.
    ///
    def drawObliqueLogo(
        g: Graphics2D,
        n: Int32,
        facelets: Vector[Int32],
        size: Int32,
        scale: Int32
    ): Unit \ IO = {
        let pad = 4;
        let centerMod = (size / 2) + pad;
        let cx = Int32.toFloat64(centerMod * scale + (scale / 2));
        let cy = Int32.toFloat64(centerMod * scale + (scale / 2));
        let s = Int32.toFloat64(scale) * 5.4;
        let sCut = s + Int32.toFloat64(scale) * 0.55;
        let colWhite = new Color(255, 255, 255);
        let colDark = new Color(15, 23, 42);

        // Hexagonal cutout (6-Eck) clearing the QR modules
        drawCubeBody(g, cx, cy, sCut, colWhite);

        // 3D isometric cube chassis and stickers
        drawCubeBody(g, cx, cy, s, colDark);
        drawTopFace(g, n, facelets, (cx, cy, s));
        drawFrontFace(g, n, facelets, (cx, cy, s));
        drawRightFace(g, n, facelets, (cx, cy, s))
    }

    ///
    /// Fill the solid dark outline of the 3D isometric cube.
    ///
    def drawCubeBody(
        g: Graphics2D,
        cx: Float64,
        cy: Float64,
        s: Float64,
        colDark: Color
    ): Unit \ IO = {
        let lx = s * 0.8660254037844386;
        let ly = s * 0.5;
        let poly = new Polygon();
        poly.addPoint(toInt(cx), toInt(cy - s));
        poly.addPoint(toInt(cx + lx), toInt(cy - ly));
        poly.addPoint(toInt(cx + lx), toInt(cy + ly));
        poly.addPoint(toInt(cx), toInt(cy + s));
        poly.addPoint(toInt(cx - lx), toInt(cy + ly));
        poly.addPoint(toInt(cx - lx), toInt(cy - ly));
        g.setColor(colDark);
        g.fillPolygon(poly)
    }

    ///
    /// Draw the top (U) face stickers in isometric projection (100% light).
    ///
    def drawTopFace(
        g: Graphics2D,
        n: Int32,
        facelets: Vector[Int32],
        geom: (Float64, Float64, Float64)
    ): Unit \ IO = {
        let (cx, cy, s) = geom;
        let lx = s * 0.8660254037844386;
        let stepX = lx / Int32.toFloat64(n);
        let stepY = (s * 0.5) / Int32.toFloat64(n);
        let gap = 0.06;
        List.range(0, n) |> List.forEach(r ->
            List.range(0, n) |> List.forEach(c -> {
                let fIdx = Vector.get(r * n + c, facelets);
                let poly = new Polygon();
                let rf = Int32.toFloat64(r);
                let cf = Int32.toFloat64(c);
                let r0 = rf + gap;
                let r1 = rf + 1.0 - gap;
                let c0 = cf + gap;
                let c1 = cf + 1.0 - gap;
                let uX = (row, col) -> cx - (col - row) * stepX;
                let uY = (row, col) -> (cy - s) + (row + col) * stepY;
                poly.addPoint(toInt(uX(r0, c0)), toInt(uY(r0, c0)));
                poly.addPoint(toInt(uX(r0, c1)), toInt(uY(r0, c1)));
                poly.addPoint(toInt(uX(r1, c1)), toInt(uY(r1, c1)));
                poly.addPoint(toInt(uX(r1, c0)), toInt(uY(r1, c0)));
                g.setColor(faceColor(fIdx, 1.0));
                g.fillPolygon(poly)
            })
        )
    }

    ///
    /// Draw the front-left (F) face stickers in isometric projection (90% light).
    ///
    def drawFrontFace(
        g: Graphics2D,
        n: Int32,
        facelets: Vector[Int32],
        geom: (Float64, Float64, Float64)
    ): Unit \ IO = {
        let (cx, cy, s) = geom;
        let lx = s * 0.8660254037844386;
        let nf = Int32.toFloat64(n);
        let stepX = lx / nf;
        let stepY = (s * 0.5) / nf;
        let stepZ = s / nf;
        let gap = 0.06;
        List.range(0, n) |> List.forEach(r ->
            List.range(0, n) |> List.forEach(c -> {
                let fIdx = Vector.get(2 * n * n + r * n + c, facelets);
                let poly = new Polygon();
                let rf = Int32.toFloat64(r);
                let cf = Int32.toFloat64(c);
                let r0 = rf + gap;
                let r1 = rf + 1.0 - gap;
                let c0 = cf + gap;
                let c1 = cf + 1.0 - gap;
                let fX = col -> cx - (nf - col) * stepX;
                let fY = (row, col) -> cy - (nf - col) * stepY + row * stepZ;
                poly.addPoint(toInt(fX(c0)), toInt(fY(r0, c0)));
                poly.addPoint(toInt(fX(c1)), toInt(fY(r0, c1)));
                poly.addPoint(toInt(fX(c1)), toInt(fY(r1, c1)));
                poly.addPoint(toInt(fX(c0)), toInt(fY(r1, c0)));
                g.setColor(faceColor(fIdx, 0.90));
                g.fillPolygon(poly)
            })
        )
    }

    ///
    /// Draw the front-right (R) face stickers in isometric projection (78% light).
    ///
    def drawRightFace(
        g: Graphics2D,
        n: Int32,
        facelets: Vector[Int32],
        geom: (Float64, Float64, Float64)
    ): Unit \ IO = {
        let (cx, cy, s) = geom;
        let lx = s * 0.8660254037844386;
        let nf = Int32.toFloat64(n);
        let stepX = lx / nf;
        let stepY = (s * 0.5) / nf;
        let stepZ = s / nf;
        let gap = 0.06;
        List.range(0, n) |> List.forEach(r ->
            List.range(0, n) |> List.forEach(c -> {
                let fIdx = Vector.get(n * n + r * n + c, facelets);
                let poly = new Polygon();
                let rf = Int32.toFloat64(r);
                let cf = Int32.toFloat64(c);
                let r0 = rf + gap;
                let r1 = rf + 1.0 - gap;
                let c0 = cf + gap;
                let c1 = cf + 1.0 - gap;
                let rX = col -> cx + col * stepX;
                let rY = (row, col) -> cy - col * stepY + row * stepZ;
                poly.addPoint(toInt(rX(c0)), toInt(rY(r0, c0)));
                poly.addPoint(toInt(rX(c1)), toInt(rY(r0, c1)));
                poly.addPoint(toInt(rX(c1)), toInt(rY(r1, c1)));
                poly.addPoint(toInt(rX(c0)), toInt(rY(r1, c0)));
                g.setColor(faceColor(fIdx, 0.78));
                g.fillPolygon(poly)
            })
        )
    }

    ///
    /// Generate a compact UTF-8 QR code string with explicit EC level and theme.
    ///
    pub def renderWith(ec: EcLevel, darkTheme: Bool, text: String): String =
        let bytes = String.toList(text) |> List.map(Char.toBmpCodePoint);
        let len = List.length(bytes);
        let (ver, totalData, numBlocks, dataPerBlock, ecPerBlock) =
            versionParams(ec, len);
        let codewords = encodeBytes(
            (totalData, numBlocks, dataPerBlock, ecPerBlock),
            bytes
        );
        let matrix = buildOptimalMatrix(ver, ec, codewords);
        drawMatrix(matrix, darkTheme)

    ///
    /// Determine QR version (1-4) and block parameters for a given EC level and byte length.
    /// Returns: (version, totalData, numBlocks, dataPerBlock, ecPerBlock).
    ///
    def versionParams(ec: EcLevel, len: Int32): (Int32, Int32, Int32, Int32, Int32) =
        match ec {
            case EcLevel.L => paramsL(len)
            case EcLevel.M => paramsM(len)
            case EcLevel.Q => paramsQ(len)
            case EcLevel.H => paramsH(len)
        }

    def paramsL(len: Int32): (Int32, Int32, Int32, Int32, Int32) = {
        if (len <= 17)
            (1, 19, 1, 19, 7)
        else if (len <= 32)
            (2, 34, 1, 34, 10)
        else if (len <= 53)
            (3, 55, 1, 55, 15)
        else
            (4, 80, 1, 80, 20)
    }

    def paramsM(len: Int32): (Int32, Int32, Int32, Int32, Int32) = {
        if (len <= 14)
            (1, 16, 1, 16, 10)
        else if (len <= 26)
            (2, 28, 1, 28, 16)
        else if (len <= 42)
            (3, 44, 1, 44, 26)
        else
            (4, 64, 2, 32, 18)
    }

    def paramsQ(len: Int32): (Int32, Int32, Int32, Int32, Int32) = {
        if (len <= 11)
            (1, 13, 1, 13, 13)
        else if (len <= 20)
            (2, 22, 1, 22, 22)
        else if (len <= 32)
            (3, 34, 2, 17, 18)
        else
            (4, 48, 2, 24, 26)
    }

    def paramsH(len: Int32): (Int32, Int32, Int32, Int32, Int32) = {
        if (len <= 7)
            (1, 9, 1, 9, 17)
        else if (len <= 14)
            (2, 16, 1, 16, 28)
        else if (len <= 24)
            (3, 26, 2, 13, 22)
        else
            (4, 36, 4, 9, 16)
    }

    ///
    /// Encode raw bytes into QR data codewords + interleaved Reed-Solomon EC codewords.
    ///
    def encodeBytes(
        params: (Int32, Int32, Int32, Int32),
        bytes: List[Int32]
    ): List[Int32] = {
        let (totalData, numBlocks, dataPerBlock, ecPerBlock) = params;
        let bitBuf = buildBitBuffer(bytes, totalData);
        let dataCodewords = bitBufferToBytes(bitBuf, totalData);
        let dataVector = List.toVector(dataCodewords);
        let dataBlocks = List.range(0, numBlocks) |> List.map(b ->
            List.range(0, dataPerBlock) |> List.map(i ->
                Vector.get(b * dataPerBlock + i, dataVector)
            )
        );
        let ecBlocks = dataBlocks |> List.map(blk -> computeRs(blk, ecPerBlock));
        let dataBlocksVec = List.map(List.toVector, dataBlocks) |> List.toVector;
        let ecBlocksVec = List.map(List.toVector, ecBlocks) |> List.toVector;
        let interleavedData = List.range(0, dataPerBlock) |> List.flatMap(col ->
            List.range(0, numBlocks) |> List.map(b ->
                Vector.get(col, Vector.get(b, dataBlocksVec))
            )
        );
        let interleavedEc = List.range(0, ecPerBlock) |> List.flatMap(col ->
            List.range(0, numBlocks) |> List.map(b ->
                Vector.get(col, Vector.get(b, ecBlocksVec))
            )
        );
        List.append(interleavedData, interleavedEc)
    }

    ///
    /// Build bit buffer: mode indicator (0100) + length + bytes + terminator + pad.
    ///
    def buildBitBuffer(bytes: List[Int32], totalData: Int32): List[Int32] =
        let modeBits = 0 :: 1 :: 0 :: 0 :: Nil;
        let lenBits = intToBits(List.length(bytes), 8);
        let dataBits = bytes |> List.flatMap(b -> intToBits(b, 8));
        let header = List.append(modeBits, List.append(lenBits, dataBits));
        let termLen = Int32.min(4, totalData * 8 - List.length(header));
        let withTerm = List.append(header, List.repeat(termLen, 0));
        let rem = Int32.modulo(List.length(withTerm), 8);
        let padBits = if (rem == 0) 0 else 8 - rem;
        List.append(withTerm, List.repeat(padBits, 0))

    ///
    /// Convert bit buffer to full list of data bytes with 0xEC / 0x11 padding.
    ///
    def bitBufferToBytes(bits: List[Int32], totalData: Int32): List[Int32] =
        let bytes = bitsToBytes(bits);
        let needed = totalData - List.length(bytes);
        let padPatterns = List.range(0, needed) |> List.map(i ->
            if (Int32.modulo(i, 2) == 0) 236 else 17);
        List.append(bytes, padPatterns)

    ///
    /// Group bits into 8-bit bytes.
    ///
    def bitsToBytes(bits: List[Int32]): List[Int32] =
        match bits {
            case b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: rest =>
                let byte = (b0 * 128) + (b1 * 64) + (b2 * 32) + (b3 * 16)
                    + (b4 * 8) + (b5 * 4) + (b6 * 2) + b7;
                byte :: bitsToBytes(rest)
            case _ => Nil
        }

    ///
    /// Integer to N bits (MSB first).
    ///
    def intToBits(val: Int32, count: Int32): List[Int32] =
        List.range(0, count) |> List.map(i ->
            Int32.bitwiseAnd(Int32.rightShift(val, count - 1 - i), 1))

    ///
    /// Galois Field GF(256) tables (primitive poly 0x11D).
    ///
    def expLogTables(): (Vector[Int32], Vector[Int32]) = region rc {
        let exp = Array.repeat(rc, 512, 0);
        let log = Array.repeat(rc, 256, 0);
        let x = Ref.fresh(rc, 1);
        List.range(0, 255) |> List.forEach(i -> {
            let cur = Ref.get(x);
            Array.put(cur, i, exp);
            Array.put(cur, i + 255, exp);
            Array.put(i, cur, log);
            let next = cur * 2;
            let wrapped = if (next >= 256) Int32.bitwiseXor(next, 285) else next;
            Ref.put(wrapped, x)
        });
        (Array.toVector(exp), Array.toVector(log))
    }

    ///
    /// Galois field multiply in GF(256).
    ///
    def gfMul(a: Int32, b: Int32, exp: Vector[Int32], log: Vector[Int32]): Int32 =
        if (a == 0 or b == 0)
            0
        else {
            let logSum = Vector.get(a, log) + Vector.get(b, log);
            Vector.get(logSum, exp)
        }

    ///
    /// Generator polynomial for N error correction codewords.
    ///
    def rsGenerator(n: Int32, exp: Vector[Int32], log: Vector[Int32]): Vector[Int32] =
        List.range(0, n) |> List.foldLeft((g: Vector[Int32], i: Int32) -> {
            let factor = Vector.get(i, exp);
            let gLen = Vector.length(g);
            List.range(0, gLen + 1) |> List.map(j -> {
                let term1 = if (j < gLen) Vector.get(j, g) else 0;
                let term2 = if (j > 0)
                    gfMul(Vector.get(j - 1, g), factor, exp, log)
                else
                    0;
                Int32.bitwiseXor(term1, term2)
            }) |> List.toVector
        }, Vector#{1})

    ///
    /// Compute Reed-Solomon error correction codewords.
    ///
    def computeRs(data: List[Int32], ecCount: Int32): List[Int32] = region rc {
        let (exp, log) = expLogTables();
        let gen = rsGenerator(ecCount, exp, log);
        let genLen = Vector.length(gen);
        let buf = Array.repeat(rc, List.length(data) + ecCount, 0);
        List.zipWithIndex(data) |> List.forEach(match (i, d) -> Array.put(d, i, buf));
        List.range(0, List.length(data)) |> List.forEach(i -> {
            let lead = Array.get(i, buf);
            if (lead != 0) {
                List.range(0, genLen) |> List.forEach(j -> {
                    let cur = Array.get(i + j, buf);
                    let term = gfMul(Vector.get(j, gen), lead, exp, log);
                    Array.put(Int32.bitwiseXor(cur, term), i + j, buf)
                })
            }
        });
        List.range(List.length(data), List.length(data) + ecCount)
            |> List.map(i -> Array.get(i, buf))
    }

    ///
    /// Calculate 15-bit BCH format info for an EC level and mask pattern.
    ///
    def formatInfoCode(ec: EcLevel, mask: Int32): Int32 = region rc {
        let ecBits = match ec {
            case EcLevel.L => 1
            case EcLevel.M => 0
            case EcLevel.Q => 3
            case EcLevel.H => 2
        };
        let val5 = Int32.bitwiseOr(Int32.leftShift(ecBits, 3), mask);
        let poly = 1335;
        let d = Ref.fresh(rc, Int32.leftShift(val5, 10));
        let bitRange = List.range(0, 5) |> List.reverse;
        bitRange |> List.forEach(i -> {
            let cur = Ref.get(d);
            if (Int32.bitwiseAnd(Int32.rightShift(cur, 10 + i), 1) != 0)
                Ref.put(Int32.bitwiseXor(cur, Int32.leftShift(poly, i)), d)
            else ()
        });
        let rem = Ref.get(d);
        Int32.bitwiseXor(Int32.bitwiseXor(Int32.leftShift(val5, 10), rem), 21522)
    }

    ///
    /// ISO/IEC 18004 standard mask conditions (0 to 7).
    ///
    def maskAt(mask: Int32, r: Int32, c: Int32): Int32 =
        let cond = match mask {
            case 0 => Int32.modulo(r + c, 2) == 0
            case 1 => Int32.modulo(r, 2) == 0
            case 2 => Int32.modulo(c, 3) == 0
            case 3 => Int32.modulo(r + c, 3) == 0
            case 4 => Int32.modulo((r / 2) + (c / 3), 2) == 0
            case 5 =>
                (Int32.modulo(r * c, 2) + Int32.modulo(r * c, 3)) == 0
            case 6 =>
                let sum = Int32.modulo(r * c, 2) + Int32.modulo(r * c, 3);
                Int32.modulo(sum, 2) == 0
            case _ =>
                let sum = Int32.modulo(r + c, 2) + Int32.modulo(r * c, 3);
                Int32.modulo(sum, 2) == 0
        };
        if (cond) 1 else 0

    ///
    /// Evaluate all 8 masks and choose the one with lowest ISO penalty score.
    ///
    def buildOptimalMatrix(
        ver: Int32,
        ec: EcLevel,
        codewords: List[Int32]
    ): Vector[Vector[Int32]] =
        let masks = List.range(0, 8);
        let matrices = masks |> List.map(m -> (m, buildMatrix(ver, ec, m, codewords)));
        let scored = matrices |> List.map(match (_, mat) -> (penaltyScore(mat), mat));
        let best = scored |> List.foldLeft((acc, cur) -> {
            let (minP, minMat) = acc;
            let (curP, curMat) = cur;
            if (curP < minP) (curP, curMat) else (minP, minMat)
        }, (1000000000, Vector#{}));
        let (_, bestMat) = best;
        bestMat

    ///
    /// Build QR code boolean matrix for a specific mask pattern.
    ///
    def buildMatrix(
        ver: Int32,
        ec: EcLevel,
        mask: Int32,
        codewords: List[Int32]
    ): Vector[Vector[Int32]] = region rc {
        let size = 4 * ver + 17;
        let grid = Array.repeat(rc, size * size, 0);
        let isFunc = Array.repeat(rc, size * size, 0);

        addFinder(0, 0, size, grid, isFunc);
        addFinder(0, size - 7, size, grid, isFunc);
        addFinder(size - 7, 0, size, grid, isFunc);

        if (ver == 2) addAlignment(18, 18, size, grid, isFunc) else ();
        if (ver == 3) addAlignment(22, 22, size, grid, isFunc) else ();
        if (ver == 4) addAlignment(26, 26, size, grid, isFunc) else ();

        List.range(8, size - 8) |> List.forEach(i -> {
            let val = if (Int32.modulo(i, 2) == 0) 1 else 0;
            if (Array.get(6 * size + i, isFunc) == 0) {
                Array.put(val, 6 * size + i, grid);
                Array.put(1, 6 * size + i, isFunc)
            } else ();
            if (Array.get(i * size + 6, isFunc) == 0) {
                Array.put(val, i * size + 6, grid);
                Array.put(1, i * size + 6, isFunc)
            } else ()
        });

        Array.put(1, (4 * ver + 9) * size + 8, grid);
        Array.put(1, (4 * ver + 9) * size + 8, isFunc);

        addFormatInfo(size, ec, mask, grid, isFunc);

        let bits = codewords |> List.flatMap(b -> intToBits(b, 8));
        placeData(size, mask, bits, grid, isFunc);

        matrixOfArray(size, grid)
    }

    ///
    /// Convert flattened 1D array to 2D vector of rows.
    ///
    def matrixOfArray(size: Int32, grid: Array[Int32, rc]): Vector[Vector[Int32]] \ rc =
        List.range(0, size) |> List.map(r ->
            List.range(0, size)
                |> List.map(c -> Array.get(r * size + c, grid))
                |> List.toVector
        ) |> List.toVector

    ///
    /// Whether offset (dr, dc) in a 7x7 finder pattern is black.
    ///
    def isFinderBlack(dr: Int32, dc: Int32): Bool =
        let outer = dr == 0 or dr == 6 or dc == 0 or dc == 6;
        let inner = dr >= 2 and dr <= 4 and dc >= 2 and dc <= 4;
        outer or inner

    ///
    /// Add 7x7 finder pattern + separator at (r, c).
    ///
    def addFinder(
        r: Int32,
        c: Int32,
        size: Int32,
        grid: Array[Int32, rc],
        isFunc: Array[Int32, rc]
    ): Unit \ rc =
        List.range(-1, 8) |> List.forEach(dr ->
            List.range(-1, 8) |> List.forEach(dc -> {
                let nr = r + dr;
                let nc = c + dc;
                let inBounds = nr >= 0 and nr < size and nc >= 0 and nc < size;
                if (inBounds) {
                    let inFinder = dr >= 0 and dr <= 6 and dc >= 0 and dc <= 6;
                    let val = if (inFinder and isFinderBlack(dr, dc)) 1 else 0;
                    Array.put(val, nr * size + nc, grid);
                    Array.put(1, nr * size + nc, isFunc)
                } else ()
            }))

    ///
    /// Whether offset (dr, dc) in a 5x5 alignment pattern is black.
    ///
    def isAlignmentBlack(dr: Int32, dc: Int32): Bool =
        Int32.abs(dr) == 2 or Int32.abs(dc) == 2 or (dr == 0 and dc == 0)

    ///
    /// Add 5x5 alignment pattern centered at (r, c).
    ///
    def addAlignment(
        r: Int32,
        c: Int32,
        size: Int32,
        grid: Array[Int32, rc],
        isFunc: Array[Int32, rc]
    ): Unit \ rc =
        List.range(-2, 3) |> List.forEach(dr ->
            List.range(-2, 3) |> List.forEach(dc -> {
                let nr = r + dr;
                let nc = c + dc;
                let inBounds = nr >= 0 and nr < size and nc >= 0 and nc < size;
                if (inBounds and Array.get(nr * size + nc, isFunc) == 0) {
                    let val = if (isAlignmentBlack(dr, dc)) 1 else 0;
                    Array.put(val, nr * size + nc, grid);
                    Array.put(1, nr * size + nc, isFunc)
                } else ()
            }))

    ///
    /// Place format information around top-left (LSB..MSB) and split (LSB..MSB).
    ///
    def addFormatInfo(
        size: Int32,
        ec: EcLevel,
        mask: Int32,
        grid: Array[Int32, rc],
        isFunc: Array[Int32, rc]
    ): Unit \ rc =
        let code = formatInfoCode(ec, mask);
        let bitsLsb = List.range(0, 15)
            |> List.map(i -> Int32.bitwiseAnd(Int32.rightShift(code, i), 1));
        let tl1 = (8, 0) :: (8, 1) :: (8, 2) :: (8, 3) :: Nil;
        let tl2 = (8, 4) :: (8, 5) :: (8, 7) :: (8, 8) :: Nil;
        let tl3 = (7, 8) :: (5, 8) :: (4, 8) :: (3, 8) :: Nil;
        let tl4 = (2, 8) :: (1, 8) :: (0, 8) :: Nil;
        let coordsTopLeft = List.append(tl1, List.append(tl2, List.append(tl3, tl4)));
        let sp1 = (size - 1, 8) :: (size - 2, 8) :: Nil;
        let sp2 = (size - 3, 8) :: (size - 4, 8) :: Nil;
        let sp3 = (size - 5, 8) :: (size - 6, 8) :: Nil;
        let sp4 = (size - 7, 8) :: (8, size - 8) :: Nil;
        let sp5 = (8, size - 7) :: (8, size - 6) :: Nil;
        let sp6 = (8, size - 5) :: (8, size - 4) :: Nil;
        let sp7 = (8, size - 3) :: (8, size - 2) :: (8, size - 1) :: Nil;
        let coordsSplit = sp1
            |> List.append(sp2)
            |> List.append(sp3)
            |> List.append(sp4)
            |> List.append(sp5)
            |> List.append(sp6)
            |> List.append(sp7);
        List.zip(bitsLsb, coordsTopLeft) |> List.forEach(match (bit, (r, c)) -> {
            Array.put(bit, r * size + c, grid);
            Array.put(1, r * size + c, isFunc)
        });
        List.zip(bitsLsb, coordsSplit) |> List.forEach(match (bit, (r, c)) -> {
            Array.put(bit, r * size + c, grid);
            Array.put(1, r * size + c, isFunc)
        })

    ///
    /// Column indices pairs for 2-column bands in zig-zag order.
    ///
    def colPairs(size: Int32): List[Int32] =
        def loop(c) =
            if (c <= 0) Nil
            else {
                let actual = if (c == 6) c - 1 else c;
                actual :: loop(actual - 2)
            };
        loop(size - 1)

    ///
    /// Place data bits in zig-zag order with specified mask pattern.
    ///
    def placeData(
        size: Int32,
        mask: Int32,
        bits: List[Int32],
        grid: Array[Int32, rc],
        isFunc: Array[Int32, rc]
    ): Unit \ rc = region local {
        let bitArr = Array.repeat(local, List.length(bits), 0);
        List.zipWithIndex(bits) |> List.forEach(match (i, b) -> Array.put(b, i, bitArr));
        let bitIdx = Ref.fresh(local, 0);
        let bitLen = List.length(bits);
        let upwards = Ref.fresh(local, true);
        colPairs(size) |> List.forEach(col -> {
            let rowOrder = if (Ref.get(upwards))
                List.range(0, size) |> List.reverse
            else
                List.range(0, size);
            rowOrder |> List.forEach(r ->
                (col :: col - 1 :: Nil) |> List.forEach(cc -> {
                    if (Array.get(r * size + cc, isFunc) == 0) {
                        let idx = Ref.get(bitIdx);
                        let bit = if (idx < bitLen) {
                            Ref.put(idx + 1, bitIdx);
                            Array.get(idx, bitArr)
                        } else 0;
                        let m = maskAt(mask, r, cc);
                        Array.put(Int32.bitwiseXor(bit, m), r * size + cc, grid);
                        Array.put(1, r * size + cc, isFunc)
                    } else ()
                })
            );
            Ref.put(not Ref.get(upwards), upwards)
        })
    }

    ///
    /// Calculate standard ISO/IEC 18004 penalty score (N1, N2, N3, N4).
    ///
    def penaltyScore(matrix: Vector[Vector[Int32]]): Int32 =
        let size = Vector.length(matrix);
        let n1Row = List.range(0, size) |> List.map(r -> {
            let row = Vector.get(r, matrix);
            evalRuns(row)
        }) |> List.sum;
        let n1Col = List.range(0, size) |> List.map(c -> {
            let col = List.range(0, size)
                |> List.map(r -> Vector.get(c, Vector.get(r, matrix)))
                |> List.toVector;
            evalRuns(col)
        }) |> List.sum;
        let n2 = List.range(0, size - 1) |> List.map(r ->
            List.range(0, size - 1) |> List.map(c -> {
                let v00 = Vector.get(c, Vector.get(r, matrix));
                let v01 = Vector.get(c + 1, Vector.get(r, matrix));
                let v10 = Vector.get(c, Vector.get(r + 1, matrix));
                let v11 = Vector.get(c + 1, Vector.get(r + 1, matrix));
                if (v00 == v01 and v00 == v10 and v00 == v11) 3 else 0
            }) |> List.sum
        ) |> List.sum;
        let darkCount = List.range(0, size) |> List.map(r ->
            List.range(0, size)
                |> List.map(c -> Vector.get(c, Vector.get(r, matrix)))
                |> List.sum
        ) |> List.sum;
        let pct = (darkCount * 100) / (size * size);
        let prevMult = (pct / 5) * 5;
        let nextMult = prevMult + 5;
        let n4Diff1 = Int32.abs(prevMult - 50) / 5;
        let n4Diff2 = Int32.abs(nextMult - 50) / 5;
        let n4 = Int32.min(n4Diff1, n4Diff2) * 10;
        n1Row + n1Col + n2 + n4

    ///
    /// Evaluate consecutive runs for rule N1.
    ///
    def evalRuns(line: Vector[Int32]): Int32 = region rc {
        let len = Vector.length(line);
        let score = Ref.fresh(rc, 0);
        let runColor = Ref.fresh(rc, -1);
        let runLen = Ref.fresh(rc, 0);
        List.range(0, len) |> List.forEach(i -> {
            let color = Vector.get(i, line);
            if (color == Ref.get(runColor)) {
                Ref.put(Ref.get(runLen) + 1, runLen)
            } else {
                let rLen = Ref.get(runLen);
                if (rLen >= 5) {
                    let pts = 3 + (rLen - 5);
                    Ref.put(Ref.get(score) + pts, score)
                } else ();
                Ref.put(color, runColor);
                Ref.put(1, runLen)
            }
        });
        let lastLen = Ref.get(runLen);
        let finalScore = if (lastLen >= 5)
            Ref.get(score) + 3 + (lastLen - 5)
        else
            Ref.get(score);
        finalScore
    }

    ///
    /// Draw the QR matrix as compact Unicode half-block characters with a quiet zone.
    /// In darkTheme mode (default), 0 is drawn as foreground and 1 as background.
    ///
    def drawMatrix(matrix: Vector[Vector[Int32]], darkTheme: Bool): String =
        let size = Vector.length(matrix);
        let pad = 4;
        let totalSize = size + 2 * pad;
        let getModule = (r: Int32, c: Int32) ->
            if (r < pad or r >= size + pad or c < pad or c >= size + pad)
                0
            else
                Vector.get(c - pad, Vector.get(r - pad, matrix));
        let rowPairs = List.range(0, (totalSize + 1) / 2);
        rowPairs |> List.map(pair -> {
            let rTop = pair * 2;
            let rBot = rTop + 1;
            List.range(0, totalSize) |> List.map(c -> {
                let mTop = getModule(rTop, c);
                let mBot = if (rBot < totalSize) getModule(rBot, c) else 0;
                let (top, bot) = if (darkTheme)
                    (if (mTop == 1) 0 else 1, if (mBot == 1) 0 else 1)
                else
                    (mTop, mBot);
                match (top, bot) {
                    case (1, 1) => "█"
                    case (1, 0) => "▀"
                    case (0, 1) => "▄"
                    case _      => " "
                }
            }) |> List.join("")
        }) |> List.join(String.lineSeparator())

}
