import Foundation
import WebKit
import LeaflitCore

final class ResourceHandler: NSObject, WKURLSchemeHandler {
    var revision = 0
    var images: [String: URL] = [:]
    private let root: URL
    init(root: URL) { self.root = root; super.init() }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        do {
            let data: Data, mime: String
            if url.scheme == "leaflit", url.host == "app" {
                let path = String(url.path.dropFirst())
                let file = root.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
                guard file.path.hasPrefix(root.path + "/"), !path.isEmpty else { throw CocoaError(.fileReadNoPermission) }
                data = try Data(contentsOf: file)
                mime = ["html":"text/html", "js":"text/javascript", "css":"text/css", "woff2":"font/woff2", "woff":"font/woff", "ttf":"font/ttf", "txt":"text/plain"][file.pathExtension] ?? "application/octet-stream"
            } else if url.scheme == "leaflit-image", url.host == String(revision) {
                let path = String(url.path.dropFirst()).removingPercentEncoding ?? ""
                guard let file = images[path] else { throw CocoaError(.fileReadNoPermission) }
                data = try Data(contentsOf: file)
                if data.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) { mime = "image/png" }
                else if data.starts(with: [0xff, 0xd8, 0xff]) { mime = "image/jpeg" }
                else { throw CocoaError(.fileReadCorruptFile) }
            } else { throw CocoaError(.fileReadNoPermission) }
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: mime.hasPrefix("text/") ? "utf-8" : nil))
            task.didReceive(data); task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
