import Foundation

extension URL {
  var isLocalFileURL: Bool {
    guard isFileURL else {
      return false
    }
    return host == nil || host?.isEmpty == true || host == "localhost"
  }
}
