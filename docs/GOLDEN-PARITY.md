# Golden Parity

`Scripts/check-parity.sh` keeps a 1% default fail ratio and only lists
per-preset exceptions after the divergence has been isolated.

Derivative-sensitive exceptions are documented in `DERIVATIVE-PARITY.md`.

`heatmap--sepia` is a separate backend-noise case. The preset sets
`noise: 0.75`, which makes the upstream `fract(sin(dot(uv, ...)))` hash a
large part of the final heat value. The Metal port matches the heatmap shape,
processed image resource, uniforms, colors, and the low-noise default preset,
but the pseudo-random hash is not bit-stable between the SwiftShader WebGL
golden renderer and Metal. Testing `precise::sin` on Metal produced the same
26.62% mismatch, confirming this is not a loose Metal fast-math choice.

The exception is therefore limited to `heatmap--sepia.png` at 27%. It should
not be generalized to other heatmap presets unless their divergence is also
isolated to the high-amplitude sin hash rather than a GLSL-to-MSL translation
error.
