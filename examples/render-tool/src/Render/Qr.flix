///
/// QR code generation and UTF-8 graphic rendering powered by ZXing Core.
///
mod ExampleRender.Qr {

    import com.google.zxing.BarcodeFormat
    import com.google.zxing.EncodeHintType
    import com.google.zxing.client.j2se.MatrixToImageWriter
    import com.google.zxing.common.BitMatrix
    import com.google.zxing.qrcode.QRCodeWriter
    import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
    import java.awt.Color
    import java.awt.Graphics2D
    import java.awt.Polygon
    import java.awt.RenderingHints
    import java.awt.image.BufferedImage
    import java.io.File
    import java.lang.Integer
    import java.lang.Object
    import java.lang.Throwable
    import java.util.Hashtable
    import java.util.Map
    import java.util.Objects
    import javax.imageio.ImageIO

    use ExampleRender.Icon

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
    /// Generate a UTF-8 QR `BufferedImage` through ZXing's
    /// `MatrixToImageWriter`.
    ///
    pub def generateQRCodeImage(
        barcodeText: String,
        width: Int32,
        height: Int32
    ): Result[String, BufferedImage] \ IO =
        try {
            let writer = new QRCodeWriter();
            let hints = new Hashtable();
            discard hints.put(EncodeHintType.CHARACTER_SET, unchecked_cast("UTF-8" as Object));
            let matrix = writer.encode(
                barcodeText,
                BarcodeFormat.QR_CODE,
                width,
                height,
                unchecked_cast(hints as Map[EncodeHintType, Object])
            );
            let img = MatrixToImageWriter.toBufferedImage(matrix);
            Result.Ok(img)
        } catch {
            case _ex: Throwable => Result.Err("Failed to generate QR code image")
        }

    ///
    /// Convert a BitMatrix into a standard BufferedImage via ZXing MatrixToImageWriter.
    ///
    pub def toBufferedImage(matrix: BitMatrix): BufferedImage \ IO =
        MatrixToImageWriter.toBufferedImage(matrix)

    ///
    /// Generate a compact UTF-8 QR code string from `text` (default Level L, dark theme).
    ///
    pub def render(text: String): String \ IO =
        renderWith(EcLevel.L, true, text)

    ///
    /// Generate a compact UTF-8 QR code string for light themes.
    ///
    pub def renderLight(text: String): String \ IO =
        renderWith(EcLevel.L, false, text)

    ///
    /// Generate a compact UTF-8 QR code string with the token centered below (default Level L).
    ///
    pub def renderWithToken(token: String): String \ IO =
        renderWithTokenAndEc(EcLevel.L, true, token)

    ///
    /// Generate a compact UTF-8 QR code string with explicit EC level and theme choice.
    ///
    pub def renderWith(ec: EcLevel, darkTheme: Bool, text: String): String \ IO =
        match encodeMatrix(text, ec) {
            case Ok(matrix) => drawBitMatrix(matrix, darkTheme)
            case Err(_)     => ""
        }

    ///
    /// Generate a compact UTF-8 QR code string with explicit EC level and the token centered below.
    ///
    pub def renderWithTokenAndEc(ec: EcLevel, darkTheme: Bool, token: String): String \ IO = {
        let qr = renderWith(ec, darkTheme, token);
        let firstLine = match String.split(regex = "\r?\n", qr) {
            case line :: _ => line
            case Nil       => ""
        };
        let qrWidth = String.length(firstLine);
        let tokenLen = String.length(token);
        if (tokenLen >= qrWidth)
            qr + String.lineSeparator() + token
        else {
            let pad = (qrWidth - tokenLen) / 2;
            let padding = List.repeat(pad, " ") |> List.join("");
            qr + String.lineSeparator() + padding + token
        }
    }

    ///
    /// Write a high-resolution PNG QR code to `path` with optional real 3D cube logo.
    ///
    pub def writeCubePng(
        path: String,
        n: Int32,
        facelets: Vector[Int32],
        token: String,
        withLogo: Bool
    ): Result[String, Unit] \ IO =
        try {
            let len = String.length(token);
            let ec = if (len <= 58) EcLevel.H
                else if (len <= 74) EcLevel.Q
                else if (len <= 106) EcLevel.M
                else EcLevel.L;
            let writer = new QRCodeWriter();
            let hints = makeHints(ec);
            let matrix = writer.encode(token, BarcodeFormat.QR_CODE, 0, 0, hints);
            let size = matrix.getWidth();
            let scale = 14;
            let pad = 4;
            let dim = (size + 2 * pad) * scale;
            let img = new BufferedImage(dim, dim, 1);
            let g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            let colWhite = new Color(255, 255, 255);
            let colDark = new Color(15, 23, 42);
            g.setColor(colWhite);
            g.fillRect(0, 0, dim, dim);
            g.setColor(colDark);
            drawMatrixModules(g, matrix, pad, scale);
            if (withLogo)
                drawObliqueLogo(g, n, facelets, size, scale)
            else ();
            g.dispose();
            let file = new File(path);
            let parent = file.getParentFile();
            if (not Objects.isNull(parent)) {
                let _ = parent.mkdirs();
                ()
            } else ();
            let _ = ImageIO.write(img, "png", file);
            Result.Ok(())
        } catch {
            case ex: Throwable => Result.Err("Failed to write PNG file: ${ex.getMessage()}")
        }

    ///
    /// Write a high-resolution PNG QR code to `path` with optional solved 3x3x3 cube logo.
    ///
    pub def writePng(path: String, text: String, withLogo: Bool): Result[String, Unit] \ IO = {
        let solved = Vector#{
            0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 1, 1, 1, 1, 1, 1, 1, 1,
            2, 2, 2, 2, 2, 2, 2, 2, 2,
            3, 3, 3, 3, 3, 3, 3, 3, 3,
            4, 4, 4, 4, 4, 4, 4, 4, 4,
            5, 5, 5, 5, 5, 5, 5, 5, 5
        };
        writeCubePng(path, 3, solved, text, withLogo)
    }

    def makeHints(ec: EcLevel): Map[EncodeHintType, Object] \ IO = {
        let hints = new Hashtable();
        let zxEc: Object = match ec {
            case EcLevel.L => unchecked_cast(ErrorCorrectionLevel.L as Object)
            case EcLevel.M => unchecked_cast(ErrorCorrectionLevel.M as Object)
            case EcLevel.Q => unchecked_cast(ErrorCorrectionLevel.Q as Object)
            case EcLevel.H => unchecked_cast(ErrorCorrectionLevel.H as Object)
        };
        let margin: Object = unchecked_cast(Integer.valueOf(0) as Object);
        let utf8: Object = unchecked_cast("UTF-8" as Object);
        discard hints.put(EncodeHintType.ERROR_CORRECTION, zxEc);
        discard hints.put(EncodeHintType.MARGIN, margin);
        discard hints.put(EncodeHintType.CHARACTER_SET, utf8);
        unchecked_cast(hints as Map[EncodeHintType, Object])
    }

    def encodeMatrix(text: String, ec: EcLevel): Result[String, BitMatrix] \ IO =
        try {
            let writer = new QRCodeWriter();
            let hints = makeHints(ec);
            let matrix = writer.encode(text, BarcodeFormat.QR_CODE, 0, 0, hints);
            Result.Ok(matrix)
        } catch {
            case _ex: Throwable => Result.Err("Failed to encode QR code")
        }

    def drawBitMatrix(matrix: BitMatrix, darkTheme: Bool): String \ IO = {
        let size = matrix.getWidth();
        let pad = 4;
        let totalSize = size + 2 * pad;
        let rowPairs = List.range(0, (totalSize + 1) / 2);
        rowPairs |> List.map(pair -> {
            let rTop = pair * 2;
            let rBot = rTop + 1;
            List.range(0, totalSize) |> List.map(c -> {
                let mTop = getModule(matrix, size, pad, rTop, c);
                let mBot = if (rBot < totalSize) getModule(matrix, size, pad, rBot, c) else 0;
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

    def getModule(matrix: BitMatrix, size: Int32, pad: Int32, r: Int32, c: Int32): Int32 \ IO =
        if (r < pad or r >= size + pad or c < pad or c >= size + pad)
            0
        else if (matrix.get(c - pad, r - pad))
            1
        else
            0

    def drawMatrixModules(
        g: Graphics2D,
        matrix: BitMatrix,
        pad: Int32,
        scale: Int32
    ): Unit \ IO = {
        let size = matrix.getWidth();
        List.range(0, size) |> List.forEach(r ->
            List.range(0, size) |> List.forEach(c -> {
                if (matrix.get(c, r)) {
                    g.fillRect((c + pad) * scale, (r + pad) * scale, scale, scale)
                } else ()
            })
        )
    }

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
        let totalSpan = Int32.toFloat64(size * scale);
        let s = totalSpan * 0.2444;
        let sCut = s + Int32.toFloat64(scale) * 0.55;
        let colWhite = new Color(255, 255, 255);
        let colDark = new Color(15, 23, 42);

        Icon.drawCubeBody(g, cx, cy, sCut, colWhite);
        Icon.drawCubeBody(g, cx, cy, s, colDark);
        Icon.drawTopFace(g, n, facelets, (cx, cy, s));
        Icon.drawFrontFace(g, n, facelets, (cx, cy, s));
        Icon.drawRightFace(g, n, facelets, (cx, cy, s))
    }

}
