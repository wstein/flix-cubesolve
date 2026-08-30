# cubesolve-render-tool

Optional graphics helpers for the `cubesolve` examples. This package owns the
ZXing and Java AWT dependencies that generate UTF-8 QR codes and PNG images;
the ordinary [`cli-tool`](../cli-tool/README.md) has no Maven graphics
dependencies and uses `CubeSolve.Render.net` for text output.

`ExampleRender.Qr` generates QR code images through ZXing's `QRCodeWriter` and
`MatrixToImageWriter`. `ExampleRender.Icon` renders an isometric cube icon from
facelets. They are example modules, not part of the published library API.

Run its checks from the repository root:

```sh
./flixw examples check render-tool
./flixw examples test render-tool
```
