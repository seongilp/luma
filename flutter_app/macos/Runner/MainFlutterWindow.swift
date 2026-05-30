import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Vision: 이미지 1장의 특징벡터를 반환 (유사도 클러스터링 + 내용 기반 위치추정에 사용)
    let visionChannel = FlutterMethodChannel(
      name: "photo_manager/vision",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    visionChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "featurePrint":
        let path = (call.arguments as? [String: Any])?["path"] as? String ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
          let vec = VisionBridge.featureVector(forPath: path)
          DispatchQueue.main.async { result(vec) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

/// Apple Vision으로 이미지 특징벡터(feature print)를 뽑는다. 완전 기기 내 처리.
enum VisionBridge {
  static func featurePrint(forPath path: String) -> VNFeaturePrintObservation? {
    let url = URL(fileURLWithPath: path)
    let request = VNGenerateImageFeaturePrintRequest()
    let handler = VNImageRequestHandler(url: url, options: [:])
    do {
      try handler.perform([request])
      return request.results?.first as? VNFeaturePrintObservation
    } catch {
      return nil
    }
  }

  /// 특징벡터를 Double 배열로. 실패 시 nil.
  static func featureVector(forPath path: String) -> [Double]? {
    guard let obs = featurePrint(forPath: path) else { return nil }
    let count = obs.elementCount
    let data = obs.data
    guard data.count >= count * MemoryLayout<Float>.size else { return nil }
    var floats = [Float](repeating: 0, count: count)
    floats.withUnsafeMutableBytes { raw in
      data.copyBytes(to: raw.bindMemory(to: Float.self))
    }
    return floats.map { Double($0) }
  }
}
