# GridTrackNet → Core ML (Usage Notes)

Concise guide for converting the repo’s GridTrackNet model to a Core ML package and using it from the tennis-trainer iOS app.

## Source & Output
- Source model: `GridTrackNet/GridTrackNet.py` (Keras, channels-first), weights: `GridTrackNet/model_weights.h5`.
- Converter script: `convert_gridtracknet.py` (at repo root).
- Core ML output: `tennis-trainer/Tennis Trainer/Models/GridTrackNet5.mlpackage`.
- Core ML type: `mlprogram`, precision `fp16`, minimum target iOS 16, compute units = ALL.

## Conversion (Reproducible)
1. Create a fresh venv (Python 3.11 recommended on Intel macOS).
2. Install pinned deps:
   - `pip install -r requirements-convert.txt`
3. Run converter from repo root:
   - `python3 convert_gridtracknet.py`
4. Result is saved under tennis-trainer as noted above.

Notes
- Pins satisfy TF 2.13.x + coremltools 7.2 (protobuf/typing-extensions constraints).
- Expect a warning that TF 2.13.1 isn’t the latest tested by coremltools; conversion is validated here.

## Core ML Model I/O
Inputs (five images):
- Names: `f1`, `f2`, `f3`, `f4`, `f5`.
- Type: RGB images, any size (Core ML auto-resizes to 432×768), scale 1/255 applied in-model.
- Recommended: pass BGRA `CVPixelBuffer`s directly; Core ML converts BGRA→RGB internally.

Outputs (three tensors):
- `conf`: confidence grids, shape `[5, 48, 27]` (Float32).
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

## Swift Usage (Core ML directly)
```swift
import CoreML

let cfg = MLModelConfiguration()
cfg.computeUnits = .all
let model = try GridTrackNet5(configuration: cfg)

// Provide five consecutive frames (any size BGRA CVPixelBuffers)
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
let pc = conf.dataPointer.assumingMemoryBound(to: Float32.self)
let px = xOff.dataPointer.assumingMemoryBound(to: Float32.self)
let py = yOff.dataPointer.assumingMemoryBound(to: Float32.self)
func idx(_ t:Int,_ r:Int,_ c:Int)->Int { t*s[0] + r*s[1] + c*s[2] }
var best: Float32 = -1; var br = 0; var bc = 0
for r in 0..<gridH { for c in 0..<gridW {
  let v = pc[idx(2,r,c)]; if v > best { best = v; br = r; bc = c }
}}
if best >= 0.5 {
  let x = (Float32(bc) + px[idx(2,br,bc)]) * 16
  let y = (Float32(br) + py[idx(2,br,bc)]) * 16
  // map (x,y) from 768×432 to your view space as needed
}
```

Why Core ML directly (not Vision)
- Vision’s `VNCoreMLRequest` is optimized for single-image models; multi-input (5 frames) is simpler via `MLModel.prediction` with a keyed dictionary.

## Usage Pattern (recommended)
- Maintain a 5-frame ring buffer of consecutive frames (consistent spacing: e.g., every frame at 60 fps, or every other at 120 fps).
- On each new frame, populate `f1…f5` and run one prediction.
- Use the prediction associated with the middle frame for stable overlays (or all 5 if you prefer).

## Gotchas / Tips
- Do not re-normalize inputs in Swift (model already applies 1/255 scale).
- Keep orientation consistent (landscape). Avoid letterboxing inside the pixel buffer; pre-resize if you need exact framing.
- Temporal alignment matters: the 5 frames should be contiguous and similarly spaced; avoid per-frame recentered crops.
- If you later use an ROI, apply the same crop to all 5 frames of a clip, and map predictions back via the crop’s `(ox, oy, w, h)`.
- Performance: FP16 + `computeUnits = .all` enables Neural Engine/GPU where available. Using a sliding window (reuse 4 frames) reduces memory copies.

## Maintenance
- To update weights, replace `GridTrackNet/model_weights.h5` and re-run `convert_gridtracknet.py`.
- To change I/O names or shapes, edit the converter (stacking, output split) and re-convert.
- Minimum Core ML target is iOS 16; tennis-trainer currently targets iOS 18.5, so it’s supported.

---
Questions or tweaks (e.g., return coordinates directly from the model) can be accommodated by extending the converter wrapper.

