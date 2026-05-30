import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 첫 실행 창 크기: 화면의 약 1/4(넓이의 절반 × 높이의 절반)을 기준으로,
    // 너무 작지 않게 최소 크기를 보장하고 화면 가운데에 배치한다.
    if let vf = NSScreen.main?.visibleFrame {
      let w = max(1040, vf.width * 0.5)
      let h = max(720, vf.height * 0.62)
      let x = vf.minX + (vf.width - w) / 2
      let y = vf.minY + (vf.height - h) / 2
      self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    } else {
      self.setFrame(self.frame, display: true)
    }
    self.minSize = NSSize(width: 900, height: 600)

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
      case "writeMetadata":
        let a = call.arguments as? [String: Any] ?? [:]
        let path = a["path"] as? String ?? ""
        let dt = a["dateTime"] as? String
        let lat = a["lat"] as? Double
        let lng = a["lng"] as? Double
        DispatchQueue.global(qos: .userInitiated).async {
          let ok = MetaBridge.writeMetadata(path: path, dateTime: dt, lat: lat, lng: lng)
          DispatchQueue.main.async { result(ok) }
        }
      case "getTags":
        let path = (call.arguments as? [String: Any])?["path"] as? String ?? ""
        result(MetaBridge.getTags(path: path))
      case "setTags":
        let a = call.arguments as? [String: Any] ?? [:]
        let path = a["path"] as? String ?? ""
        let tags = a["tags"] as? [String] ?? []
        result(MetaBridge.setTags(path: path, tags: tags))
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
    _ = floats.withUnsafeMutableBytes { raw in
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

/// EXIF 메타데이터 무손실 쓰기 + Finder 태그 (네이티브).
enum MetaBridge {
  /// 촬영일시(EXIF DateTimeOriginal)와 GPS를 무손실로 다시 쓴다(픽셀 재압축 없음).
  static func writeMetadata(path: String, dateTime: String?, lat: Double?, lng: Double?) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(src) else { return false }
    var props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]

    if let dt = dateTime {
      var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
      exif[kCGImagePropertyExifDateTimeOriginal] = dt
      exif[kCGImagePropertyExifDateTimeDigitized] = dt
      props[kCGImagePropertyExifDictionary] = exif
    }
    if let lat = lat, let lng = lng {
      var gps: [CFString: Any] = [:]
      gps[kCGImagePropertyGPSLatitude] = abs(lat)
      gps[kCGImagePropertyGPSLatitudeRef] = lat >= 0 ? "N" : "S"
      gps[kCGImagePropertyGPSLongitude] = abs(lng)
      gps[kCGImagePropertyGPSLongitudeRef] = lng >= 0 ? "E" : "W"
      props[kCGImagePropertyGPSDictionary] = gps
    }

    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, type, 1, nil) else { return false }
    CGImageDestinationAddImageFromSource(dest, src, 0, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return false }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  static func getTags(path: String) -> [String] {
    let url = URL(fileURLWithPath: path)
    return (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
  }

  static func setTags(path: String, tags: [String]) -> Bool {
    // NSURL 키 기반 API는 전 버전 호환.
    do {
      try (URL(fileURLWithPath: path) as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
      return true
    } catch {
      return false
    }
  }
}
