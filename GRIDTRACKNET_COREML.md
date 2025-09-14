# GridTrackNet → Core ML (Usage Notes)

Concise guide for converting the repo’s GridTrackNet model to a Core ML package and using it from the tennis-trainer iOS app.

## Source & Output
- Source model: `GridTrackNet/GridTrackNet.py` (Keras, channels-first), weights: `GridTrackNet/model_weights.h5`.
- Converter script: `tennis-trainer/convert_gridtracknet.py`.
- Core ML output: `tennis-trainer/Tennis Trainer/Models/GridTrackNet5.mlpackage`.
- Core ML type: `mlprogram`, precision `fp16`, minimum target iOS 16, compute units = ALL.

## Conversion (Reproducible)
1. Create a fresh venv (Python 3.11 recommended on Intel macOS).
2. Install pinned deps:
   - `pip install -r requirements-convert.txt`
3. Run converter from the `tennis-trainer` folder:
   - `cd tennis-trainer && python3 convert_gridtracknet.py`
4. Result is saved under tennis-trainer as noted above.

Notes
- Pins satisfy TF 2.13.x + coremltools 7.2 (protobuf/typing-extensions constraints).
- Expect a warning that TF 2.13.1 isn’t the latest tested by coremltools; conversion is validated here.

## Core ML Model I/O
Inputs (five images):
- Names: `f1`, `f2`, `f3`, `f4`, `f5`.
- Type: RGB images, size must be 768×432 (W×H); you must resize on iOS. Scale 1/255 is applied in‑model.
- Recommended: pass BGRA `CVPixelBuffer`s directly; Core ML converts BGRA→RGB internally.

Outputs (three tensors):
- `conf`: confidence grids, shape `[5, 48, 27]` (Float16 in the shipped mlpackage).
- `x_off`: X offsets (grid units), shape `[5, 48, 27]`.
- `y_off`: Y offsets (grid units), shape `[5, 48, 27]`.

Geometry
- Input spatial size inside the model: 768 (W) × 432 (H).
- Grid size: 48 × 27, so cell size = 16 px (both axes).

Pixel mapping (per frame index `t`):
- Find `(row, col)` of `argmax(conf[t, :, :])`.
- `x_px = (col + x_off[t, row, col]) * 16`
- `y_px = (row + y_off[t, row, col]) * 16`
- Suggested detection threshold: `conf[t, row, col] ≥ 0.5`.
- Normalize if needed: `x_norm = x_px / 768`, `y_norm = y_px / 432`.

Resizing
- Camera frames like 1920×1080 must be resized to 768×432 before prediction (same 16:9 aspect).
- Use Core Image (`CILanczosScaleTransform`) or vImage; avoid letterboxing so behavior matches the repo.

## Swift Usage (Core ML directly)
```swift
import CoreML

let cfg = MLModelConfiguration()
cfg.computeUnits = .all
let model = try GridTrackNet5(configuration: cfg)

// Provide five consecutive frames, each resized to 768×432 BGRA CVPixelBuffers
let provider = try MLDictionaryFeatureProvider(dictionary: [
  "f1": .init(pixelBuffer: pb1),
  "f2": .init(pixelBuffer: pb2),
  "f3": .init(pixelBuffer: pb3),
  "f4": .init(pixelBuffer: pb4),
  "f5": .init(pixelBuffer: pb5),
])
let out = try model.model.prediction(from: provider)

let conf  = out.featureValue(for: "conf")!.multiArrayValue! // shape [5,48,27]
let xOff  = out.featureValue(for: "x_off")!.multiArrayValue!
let yOff  = out.featureValue(for: "y_off")!.multiArrayValue!

// Example: argmax on frame t=2 and map to pixels
let gridW = 48, gridH = 27
let s = conf.strides.map { Int(truncating: $0) }

// Note: outputs are Float16 in the packaged model; read accordingly.
let pcBits = conf.dataPointer.bindMemory(to: UInt16.self, capacity: conf.count)
let pxBits = xOff.dataPointer.bindMemory(to: UInt16.self, capacity: xOff.count)
let pyBits = yOff.dataPointer.bindMemory(to: UInt16.self, capacity: yOff.count)
@inline(__always) func f16(_ u: UInt16) -> Float32 { Float32(Float16(bitPattern: u)) }

func idx(_ t:Int,_ r:Int,_ c:Int)->Int { t*s[0] + r*s[1] + c*s[2] }
var best: Float32 = -1; var br = 0; var bc = 0
for r in 0..<gridH { for c in 0..<gridW {
  let v = f16(pcBits[idx(2,r,c)]); if v > best { best = v; br = r; bc = c }
}}
if best >= 0.5 {
  let x = (Float32(bc) + f16(pxBits[idx(2,br,bc)])) * 16
  let y = (Float32(br) + f16(pyBits[idx(2,br,bc)])) * 16
  // map (x,y) from 768×432 to your view space as needed
}
```

Why Core ML directly (not Vision)
- Vision’s `VNCoreMLRequest` is optimized for single-image models; multi-input (5 frames) is simpler via `MLModel.prediction` with a keyed dictionary.

## Usage Pattern (recommended)
- Maintain a 5-frame ring buffer of consecutive frames (consistent spacing: e.g., every frame at 60 fps, or every other at 120 fps).
- On each new frame, populate `f1…f5` and run one prediction.
- Target frame selection: use the middle frame `t=2` (0-based in `f1…f5`) for accuracy (best for contact/change-of-direction). This leverages two past and two future frames, with ~2-frame latency (~33 ms @60 fps). Controlled by `targetFrameIndex` in `Tennis Trainer/Detectors/GridTrackNetDetector.swift` (default `2`).

## Gotchas / Tips
- Do not re-normalize inputs in Swift (model already applies 1/255 scale).
- Keep orientation consistent (landscape). Avoid letterboxing inside the pixel buffer; pre-resize if you need exact framing.
- Temporal alignment matters: the 5 frames should be contiguous and similarly spaced; avoid per-frame recentered crops.
- Grid is width=48, height=27 (cell size 16 px). Do not swap axes when decoding.
- Outputs are Float16; if you read via pointers, convert from Float16 to Float32. Using each tensor’s own strides is required.
- Performance: FP16 + `computeUnits = .all` enables Neural Engine/GPU where available. Using a sliding window (reuse 4 frames) reduces memory copies.

## Maintenance
- To update weights, replace `GridTrackNet/model_weights.h5` and re-run `convert_gridtracknet.py`.
- To change I/O names or shapes, edit the converter (stacking, output split) and re-convert.
- Minimum Core ML target is iOS 16; tennis-trainer currently targets iOS 18.5, so it’s supported.

---
Questions or tweaks (e.g., return coordinates directly from the model) can be accommodated by extending the converter wrapper.
