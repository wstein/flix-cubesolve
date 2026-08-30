///
/// Standalone 3D isometric cube icon and image renderer.
///
mod ExampleRender.Icon {

    import java.awt.Color
    import java.awt.Graphics2D
    import java.awt.Polygon
    import java.awt.RenderingHints
    import java.awt.image.BufferedImage
    import java.io.File
    import java.lang.Throwable
    import java.util.Objects
    import javax.imageio.ImageIO

    ///
    /// Render and export the cube state as a standalone 3D isometric PNG icon.
    ///
    pub def writePng(
        path: String,
        n: Int32,
        facelets: Vector[Int32],
        imgSize: Int32,
        transparent: Bool
    ): Result[String, Unit] \ IO =
        try {
            let imgType = if (transparent) 2 else 1;
            let img = new BufferedImage(imgSize, imgSize, imgType);
            let g = img.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            if (not transparent) {
                g.setColor(new Color(15, 23, 42));
                g.fillRect(0, 0, imgSize, imgSize)
            } else ();
            let cx = Int32.toFloat64(imgSize) * 0.5;
            let cy = Int32.toFloat64(imgSize) * 0.5;
            let s = Int32.toFloat64(imgSize) * 0.44;
            let colDark = new Color(15, 23, 42);
            drawCubeBody(g, cx, cy, s, colDark);
            drawTopFace(g, n, facelets, (cx, cy, s));
            drawFrontFace(g, n, facelets, (cx, cy, s));
            drawRightFace(g, n, facelets, (cx, cy, s));
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
            case _ex: Throwable => Result.Err("Failed to write cube icon PNG")
        }

    def toInt(x: Float64): Int32 =
        Float64.tryToInt32(x) |> Option.getWithDefault(0)

    ///
    /// Draw the 3D isometric hexagonal cube silhouette body.
    ///
    pub def drawCubeBody(
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
    /// Convert a face index to its corresponding shaded Color.
    ///
    pub def faceColor(fIdx: Int32, factor: Float64): Color \ IO = {
        let (br, bg, bb) = match fIdx {
            case 0 => (250.0, 250.0, 250.0) // U: White
            case 1 => (220.0, 38.0, 38.0)   // R: Red
            case 2 => (22.0, 163.0, 74.0)   // F: Green
            case 3 => (234.0, 179.0, 8.0)   // D: Yellow
            case 4 => (234.0, 88.0, 12.0)   // L: Orange
            case 5 => (37.0, 99.0, 235.0)   // B: Blue
            case _ => (120.0, 120.0, 120.0)
        };
        let r = toInt(br * factor);
        let g = toInt(bg * factor);
        let b = toInt(bb * factor);
        new Color(r, g, b)
    }

    ///
    /// Draw the top (U) isometric face stickers with lighting.
    ///
    pub def drawTopFace(
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
        let gap = 0.05;
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
    /// Draw the front (F) isometric face stickers with lighting.
    ///
    pub def drawFrontFace(
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
        let gap = 0.05;
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
    /// Draw the right (R) isometric face stickers with lighting.
    ///
    pub def drawRightFace(
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
        let gap = 0.05;
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
                // The right face shares the top diamond's lower point at
                // `(cx, cy)` and rises towards its right point. The former
                // expression started half a face too high, pulling the whole
                // face apart from the top and producing the floating strips
                // visible in PNG exports.
                let rY = (row, col) -> cy - col * stepY + row * stepZ;
                poly.addPoint(toInt(rX(c0)), toInt(rY(r0, c0)));
                poly.addPoint(toInt(rX(c1)), toInt(rY(r0, c1)));
                poly.addPoint(toInt(rX(c1)), toInt(rY(r1, c1)));
                poly.addPoint(toInt(rX(c0)), toInt(rY(r1, c0)));
                g.setColor(faceColor(fIdx, 0.75));
                g.fillPolygon(poly)
            })
        )
    }

}
