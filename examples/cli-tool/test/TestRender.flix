mod TestRender {

    use ExampleRender.Icon
    use ExampleRender.Qr

    /// ZXing receives UTF-8 input and honours the requested raster dimensions.
    @Test
    def zxingGeneratesAUtf8QrImageAtTheRequestedSize(): Unit \ { Assert, IO } =
        match Qr.generateQRCodeImage("cube ✓", 200, 200) {
            case Ok(image) => {
                Assert.assertEq(expected = 200, image.getWidth());
                Assert.assertEq(expected = 200, image.getHeight())
            }
            case Err(e) => Assert.assertEqWithMsg(expected = "", e, "ZXing image generation")
        }

    /// The example owns its PNG image work, including the isometric icon.
    @Test
    def iconWritesARepresentativeFiveByFiveCube(): Unit \ { Assert, IO } =
        let facelets = Vector.range(0, 150) |> Vector.map(i -> i / 25);
        Assert.assertEq(expected = Ok(()),
            Icon.writePng("tmp/test_icon.png", 5, facelets, 256, true))

}
