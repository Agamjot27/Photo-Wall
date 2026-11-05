import Flutter
import ImageIO
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
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
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let decoded = try Self.decodeDownsampled(call.arguments)
            DispatchQueue.main.async { result(decoded) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(
                code: "DECODE_FAILED",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func decodeDownsampled(_ arguments: Any?) throws -> [String: Any] {
    guard let args = arguments as? [String: Any],
      let maxWidth = args["maxWidth"] as? Int,
      let maxHeight = args["maxHeight"] as? Int,
      maxWidth > 0,
      maxHeight > 0,
      let format = args["format"] as? String
    else { throw ImageChannelError.invalidArguments }

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

    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw ImageChannelError.invalidImage
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(maxWidth, maxHeight),
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw ImageChannelError.invalidImage }

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
    let compressed: Data?
    switch format.lowercased() {
    case "png": compressed = output.pngData()
    case "jpg", "jpeg": compressed = output.jpegData(compressionQuality: 0.9)
    default: throw ImageChannelError.invalidArguments
    }
    guard let compressed = compressed, !compressed.isEmpty else {
      throw ImageChannelError.invalidImage
    }
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

  var errorDescription: String? {
    switch self {
    case .invalidArguments: return "Invalid image request"
    case .invalidImage: return "Could not decode image"
    }
  }
}
