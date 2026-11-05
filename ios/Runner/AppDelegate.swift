import Flutter
import ImageIO
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var cancellations: [Int: CancellationFlag] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.assignment.photowall/image",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "decodeDownsampled":
        guard let requestId = (call.arguments as? [String: Any])?["requestId"] as? Int
        else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing request ID", details: nil))
          return
        }
        let cancellation = CancellationFlag()
        self.cancellations[requestId] = cancellation
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let decoded = try Self.decodeDownsampled(call.arguments) {
              cancellation.isCancelled
            }
            DispatchQueue.main.async {
              self.cancellations.removeValue(forKey: requestId)
              if cancellation.isCancelled {
                result(FlutterError(code: "CANCELLED", message: "Image decode cancelled", details: nil))
              } else {
                result(decoded)
              }
            }
          } catch {
            DispatchQueue.main.async {
              self.cancellations.removeValue(forKey: requestId)
              result(FlutterError(
                code: cancellation.isCancelled ? "CANCELLED" : "DECODE_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      case "cancelDecode":
        guard let requestId = (call.arguments as? [String: Any])?["requestId"] as? Int
        else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing request ID", details: nil))
          return
        }
        self.cancellations[requestId]?.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func decodeDownsampled(
    _ arguments: Any?,
    isCancelled: () -> Bool
  ) throws -> [String: Any] {
    guard let args = arguments as? [String: Any],
      let maxWidth = args["maxWidth"] as? Int,
      let maxHeight = args["maxHeight"] as? Int,
      maxWidth > 0,
      maxHeight > 0,
      let format = args["format"] as? String
    else { throw ImageChannelError.invalidArguments }
    if isCancelled() { throw ImageChannelError.cancelled }

    let path = args["path"] as? String
    let inputBytes = (args["bytes"] as? FlutterStandardTypedData)?.data
    guard (path == nil) != (inputBytes == nil) else {
      throw ImageChannelError.invalidArguments
    }
    let data: Data
    if let path = path, !path.isEmpty {
      data = try Data(contentsOf: URL(fileURLWithPath: path))
    } else if let inputBytes = inputBytes, !inputBytes.isEmpty {
      data = inputBytes
    } else {
      throw ImageChannelError.invalidArguments
    }
    if isCancelled() { throw ImageChannelError.cancelled }

    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw ImageChannelError.invalidImage
    }
    if isCancelled() { throw ImageChannelError.cancelled }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(maxWidth, maxHeight),
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw ImageChannelError.invalidImage }
    if isCancelled() { throw ImageChannelError.cancelled }

    let scale = min(
      1.0,
      CGFloat(maxWidth) / CGFloat(thumbnail.width),
      CGFloat(maxHeight) / CGFloat(thumbnail.height)
    )
    let width = max(1, Int((CGFloat(thumbnail.width) * scale).rounded()))
    let height = max(1, Int((CGFloat(thumbnail.height) * scale).rounded()))
    let image = UIImage(cgImage: thumbnail)
    let output: UIImage
    if width == thumbnail.width && height == thumbnail.height {
      output = image
    } else {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
      output = renderer.image { _ in
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      }
    }
    if isCancelled() { throw ImageChannelError.cancelled }
    let compressed: Data?
    switch format.lowercased() {
    case "png": compressed = output.pngData()
    case "jpg", "jpeg": compressed = output.jpegData(compressionQuality: 0.9)
    default: throw ImageChannelError.invalidArguments
    }
    guard let compressed = compressed, !compressed.isEmpty else {
      throw ImageChannelError.invalidImage
    }
    if isCancelled() { throw ImageChannelError.cancelled }
    return [
      "width": width,
      "height": height,
      "bytes": FlutterStandardTypedData(bytes: compressed),
    ]
  }
}

private enum ImageChannelError: LocalizedError {
  case invalidArguments
  case invalidImage
  case cancelled

  var errorDescription: String? {
    switch self {
    case .invalidArguments: return "Invalid image request"
    case .invalidImage: return "Could not decode image"
    case .cancelled: return "Image decode cancelled"
    }
  }
}

private final class CancellationFlag {
  private let lock = NSLock()
  private var cancelled = false

  func cancel() {
    lock.lock()
    cancelled = true
    lock.unlock()
  }

  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
}
