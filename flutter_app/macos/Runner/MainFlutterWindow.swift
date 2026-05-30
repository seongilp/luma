import Cocoa
import FlutterMacOS
import ImageIO
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
      case "faces":
        let path = (call.arguments as? [String: Any])?["path"] as? String ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
          let faces = VisionBridge.faces(forPath: path)
          DispatchQueue.main.async { result(faces) }
        }
      case "ocr":
        let path = (call.arguments as? [String: Any])?["path"] as? String ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
          let lines = VisionBridge.ocr(forPath: path)
          DispatchQueue.main.async { result(lines) }
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
    return vectorFromObservation(obs)
  }

  static func vectorFromObservation(_ obs: VNFeaturePrintObservation) -> [Double]? {
    let count = obs.elementCount
    let data = obs.data
    guard data.count >= count * MemoryLayout<Float>.size else { return nil }
    var floats = [Float](repeating: 0, count: count)
    floats.withUnsafeMutableBytes { raw in
      data.copyBytes(to: raw.bindMemory(to: Float.self))
    }
    return floats.map { Double($0) }
  }

  /// 사진에서 얼굴을 검출해, 각 얼굴 영역의 특징벡터와 위치(0~1, 좌상단 기준)를 반환.
  /// 동일인 식별용 임베딩이 공개 API에 없어, 얼굴 크롭의 특징벡터로 근사한다.
  static func faces(forPath path: String) -> [[String: Any]] {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return [] }
    let w = cg.width
    let h = cg.height

    let req = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([req])
    guard let results = req.results else { return [] }

    var out: [[String: Any]] = []
    for face in results {
      let bb = face.boundingBox // 정규화, 좌하단 원점
      let pw = Int(bb.width * CGFloat(w))
      let ph = Int(bb.height * CGFloat(h))
      let px = Int(bb.minX * CGFloat(w))
      let pyTop = Int((1.0 - bb.minY - bb.height) * CGFloat(h))
      if pw < 24 || ph < 24 { continue }
      let rect = CGRect(x: px, y: pyTop, width: pw, height: ph).integral
      guard let crop = cg.cropping(to: rect) else { continue }

      let fp = VNGenerateImageFeaturePrintRequest()
      let h2 = VNImageRequestHandler(cgImage: crop, options: [:])
      try? h2.perform([fp])
      guard let obs = fp.results?.first as? VNFeaturePrintObservation,
            let vec = vectorFromObservation(obs) else { continue }

      out.append([
        "vector": vec,
        "x": Double(bb.minX),
        "y": Double(1.0 - bb.minY - bb.height),
        "w": Double(bb.width),
        "h": Double(bb.height),
      ])
    }
    return out
  }

  /// 온디바이스 OCR: 사진 속 텍스트를 줄 단위로 인식한다 (한국어+영어).
  static func ocr(forPath path: String) -> [String] {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return [] }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    if #available(macOS 13.0, *) {
      req.recognitionLanguages = ["ko-KR", "en-US"]
    }
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([req])
    guard let results = req.results else { return [] }
    return results.compactMap { $0.topCandidates(1).first?.string }
  }
}
