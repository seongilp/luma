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

    // Vision 유사 사진 분석 채널
    let visionChannel = FlutterMethodChannel(
      name: "photo_manager/vision",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    visionChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "similarGroups":
        let args = call.arguments as? [String: Any]
        let paths = args?["paths"] as? [String] ?? []
        let threshold = (args?["threshold"] as? Double).map { Float($0) } ?? 0.6
        DispatchQueue.global(qos: .userInitiated).async {
          let groups = VisionBridge.similarGroups(paths: paths, threshold: threshold)
          DispatchQueue.main.async { result(groups) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

/// Apple Vision으로 이미지 특징벡터를 뽑아 의미적으로 유사한 사진을 묶는다.
/// 완전 기기 내 처리(인터넷·서버 안 씀).
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

  /// 경로 목록 → 유사 묶음(인덱스 배열의 배열). 2장 이상 묶음만, 큰 순.
  static func similarGroups(paths: [String], threshold: Float) -> [[Int]] {
    let n = paths.count
    var prints = [VNFeaturePrintObservation?](repeating: nil, count: n)
    for i in 0..<n {
      prints[i] = featurePrint(forPath: paths[i])
    }

    var parent = Array(0..<n)
    func find(_ x: Int) -> Int {
      var x = x
      while parent[x] != x {
        parent[x] = parent[parent[x]]
        x = parent[x]
      }
      return x
    }

    if n > 1 {
      for i in 0..<n {
        guard let a = prints[i] else { continue }
        for j in (i + 1)..<n {
          guard let b = prints[j] else { continue }
          var dist = Float(0)
          do {
            try a.computeDistance(&dist, to: b)
            if dist <= threshold {
              parent[find(i)] = find(j)
            }
          } catch {
            continue
          }
        }
      }
    }

    var groups: [Int: [Int]] = [:]
    for i in 0..<n {
      groups[find(i), default: []].append(i)
    }
    return groups.values.filter { $0.count > 1 }.sorted { $0.count > $1.count }
  }
}
