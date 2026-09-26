import XCTest
import CoreML
import AVFoundation
@testable import Tennis_Trainer

final class GridTrackNetDecoderTests: XCTestCase {
  func testAllTemporalIndices_WhenFP16OutputsHaveIndependentStrides() throws {
    let window = try DecoderFixture.window()
    let outputs = try DecoderFixture.outputs()
    let detector = GridTrackNetDetector(predictor: { _ in outputs })
    let samples = try XCTUnwrap(detector.decode(outputs, window: window))
    for t in 0..<5 {
      XCTAssertEqual(samples[t].tIndex, t)
      XCTAssertEqual(samples[t].metadata.identity, window.frames[t].metadata.identity)
      XCTAssertEqual(try XCTUnwrap(samples[t].position).x, CGFloat(Float(t + 10) + 0.25) / 48, accuracy: 0.00001)
      XCTAssertEqual(try XCTUnwrap(samples[t].position).y, 1 - CGFloat(Float(t + 3) + 0.5) / 27, accuracy: 0.00001)
      XCTAssertEqual(samples[t].confidence, 0.875)
    }
  }

  func testMalformedOutputs_WhenTypeShapeOrValuesAreInvalid() throws {
    let window = try DecoderFixture.window()
    let outputs = try DecoderFixture.outputs()
    let detector = GridTrackNetDetector(predictor: { _ in outputs })
    let wrong = try MLMultiArray(shape: [5, 48, 27], dataType: .float32)
    XCTAssertNil(detector.decode(.init(conf: wrong, xOff: outputs.xOff, yOff: outputs.yOff), window: window))
    outputs.conf[[0, 10, 3]] = NSNumber(value: Float.nan)
    XCTAssertNil(detector.decode(outputs, window: window))
  }

  func testSourceCoordinates_WhenPortraitFitOrNonportraitFill() throws {
    for (width, height, orientation) in [(432, 768, CGImagePropertyOrientation.up),
      (768, 432, .right), (768, 432, .left), (768, 432, .down), (768, 432, .up), (800, 600, .up)] {
      let window = try DecoderFixture.window(width: width, height: height, orientation: orientation)
      let mapping = window.frames[0].metadata.mapping
      XCTAssertEqual(mapping.sourceNormalizedPoint(modelX: 384, modelYFromTop: 216), CGPoint(x: 0.5, y: 0.5))
      if mapping.sourceHeight > mapping.sourceWidth {
        // 432x768 fit: scale .5625, width 243, horizontal padding 262.5.
        XCTAssertEqual(mapping.sourceNormalizedPoint(modelX: 262.5, modelYFromTop: 0), CGPoint(x: 0, y: 1))
        XCTAssertEqual(mapping.sourceNormalizedPoint(modelX: 505.5, modelYFromTop: 432), CGPoint(x: 1, y: 0))
        XCTAssertNil(mapping.sourceNormalizedPoint(modelX: 262, modelYFromTop: 216))
      } else if width == 800 {
        // 800x600 fill: scale .96, vertical crop 72 pixels.
        XCTAssertEqual(try XCTUnwrap(mapping.sourceNormalizedPoint(modelX: 0, modelYFromTop: 0)).y, 0.875, accuracy: 0.00001)
      } else {
        XCTAssertEqual(mapping.sourceNormalizedPoint(modelX: 0, modelYFromTop: 0), CGPoint(x: 0, y: 1))
        XCTAssertEqual(mapping.sourceNormalizedPoint(modelX: 768, modelYFromTop: 432), CGPoint(x: 1, y: 0))
      }
      XCTAssertEqual(Set(window.frames.map { ObjectIdentifier($0.pixels) }).count, 5)
      XCTAssertEqual(window.frames[0].metadata.orientation, orientation)
      let outputs = try DecoderFixture.outputs()
      let decoded = try XCTUnwrap(GridTrackNetDetector(predictor: { _ in outputs }).decode(outputs, window: window))
      if mapping.sourceHeight > mapping.sourceWidth { XCTAssertNil(decoded[0].position) }
    }
  }

  func testBundledModelContract_WhenFiveOwnedFramesAreProvided() throws {
    let model = try GridTrackNet5(configuration: MLModelConfiguration()).model
    let description = model.modelDescription
    XCTAssertEqual(Set(description.inputDescriptionsByName.keys), Set(["f1", "f2", "f3", "f4", "f5"]))
    XCTAssertEqual(Set(description.outputDescriptionsByName.keys), Set(["conf", "x_off", "y_off"]))
    for input in description.inputDescriptionsByName.values {
      XCTAssertEqual(input.imageConstraint?.pixelsWide, 768)
      XCTAssertEqual(input.imageConstraint?.pixelsHigh, 432)
    }
    let window = try DecoderFixture.window()
    let inputs = Dictionary(uniqueKeysWithValues: window.frames.enumerated().map {
      ("f\($0.offset + 1)", MLFeatureValue(pixelBuffer: $0.element.pixels))
    })
    let result = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputs))
    let arrays = try ["conf", "x_off", "y_off"].map { name -> MLMultiArray in
      let tensor = try XCTUnwrap(result.featureValue(for: name)?.multiArrayValue)
      XCTAssertEqual(tensor.dataType, .float16)
      XCTAssertEqual(tensor.shape.map(\.intValue), [5, 48, 27])
      print("MODEL CONTRACT \(name): dtype=\(tensor.dataType.rawValue) shape=\(tensor.shape) strides=\(tensor.strides)")
      return tensor
    }
    let outputs = GridTrackNetDetector.RawOutputs(conf: arrays[0], xOff: arrays[1], yOff: arrays[2])
    XCTAssertEqual(GridTrackNetDetector(predictor: { _ in outputs }).decode(outputs, window: window)?.count, 5)
  }
}

enum DecoderFixture {
  static func tensor(shape: [Int], strides: [Int]) throws -> MLMultiArray {
    let count = zip(shape, strides).reduce(1) { $0 + ($1.0 - 1) * $1.1 }
    let storage = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
    storage.initialize(repeating: 0, count: count)
    return try MLMultiArray(dataPointer: storage, shape: shape.map(NSNumber.init), dataType: .float16,
      strides: strides.map(NSNumber.init), deallocator: { $0.deallocate() })
  }

  static func outputs() throws -> GridTrackNetDetector.RawOutputs {
    let conf = try tensor(shape: [5, 48, 27], strides: [1600, 32, 1])
    let x = try tensor(shape: [5, 27, 48], strides: [1800, 64, 1])
    let y = try tensor(shape: [1, 5, 48, 27], strides: [12000, 2100, 40, 1])
    for t in 0..<5 {
      conf[[NSNumber(value: t), NSNumber(value: t + 10), NSNumber(value: t + 3)]] = 0.875
      x[[NSNumber(value: t), NSNumber(value: t + 3), NSNumber(value: t + 10)]] = 0.25
      y[[0, NSNumber(value: t), NSNumber(value: t + 10), NSNumber(value: t + 3)]] = 0.5
    }
    return .init(conf: conf, xOff: x, yOff: y)
  }

  static func window(width: Int = 768, height: Int = 432,
                     orientation: CGImagePropertyOrientation = .up) throws -> AnalysisFrame.Window {
    let source = UUID(), generation = UUID()
    let frames = try (1...5).map { index -> AnalysisFrame in
      let time = CMTime(value: Int64(index), timescale: 30)
      let identity = BallDetectionManager.FrameIdentity(sourceID: source, generation: generation,
        sequence: UInt64(index), sourceTime: time)
      let input = BallDetectionManager.Input(pixelBuffer: try AnalysisFixture.pixels(width: width, height: height),
        sourceTime: time, orientation: orientation, sourceID: source)
      return try XCTUnwrap(AnalysisFrame.prepare(input: input, identity: identity,
        pose: .init(identity: identity, joints: [:])))
    }
    return try XCTUnwrap(AnalysisFrame.Window(frames))
  }
}
