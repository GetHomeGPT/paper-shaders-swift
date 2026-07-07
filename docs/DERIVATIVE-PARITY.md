# Derivative Parity

Some upstream shaders use `fwidth` for antialiasing or threshold smoothing.
Those derivatives are evaluated from neighboring fragments by the shader
backend, and the exact neighborhood/precision is not portable between the
SwiftShader WebGL golden harness and Metal.

For `halftone-cmyk` and `grain-gradient`, debugging confirmed that the values
feeding `fwidth` match the WebGL reference before the derivative step:

- `halftone-cmyk`: the pre-threshold `C/M/Y/K` mask is byte-identical.
- `grain-gradient`: the combined pre-AA shape value is byte-identical.

To avoid depending on Metal's native derivative implementation for these
known-sensitive steps, those shaders render a mask pass first and then compute
the smoothing width from deterministic 2x2 neighbors in the mask texture. This
keeps the production renderer and parity renderer on the same path while making
the derivative choice explicit.

This does not claim exact WebGL `fwidth` emulation. It documents and contains
the backend variance in the two shaders where the variance is observable.

`halftone-dots--default` has a narrower exception without a mask pass. The
other `halftone-dots` presets are pixel-perfect or near pixel-perfect, while
the default preset combines the `gooey` dot threshold with the hex grid and a
grain mix, making the native `fwidth(totalShape)` smoothing visibly backend
sensitive. The exception is limited to that preset.

`Scripts/check-parity.sh` keeps the default 1% fail ratio for ordinary shaders,
but uses explicit per-preset thresholds for these known derivative-sensitive
renders. Those exceptions are intentionally narrow and should not be expanded
without first isolating the divergence to derivative-sensitive smoothing rather
than a GLSL-to-MSL translation error.
