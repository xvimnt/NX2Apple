import AppKit
import Foundation

enum NetworkUtils {
    static func localIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var addresses: [String: String] = [:]
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let flags = Int32(interface.ifa_flags)
                if (flags & IFF_LOOPBACK) == 0 && (flags & IFF_UP) != 0 {
                    let name = String(cString: interface.ifa_name)
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    addresses[name] = String(cString: hostname)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return addresses["en0"] ?? addresses["en1"] ?? addresses.values.first
    }

    static var webControllerURL: URL? {
        guard let ip = localIPAddress() else { return nil }
        return URL(string: "http://\(ip):2904")
    }

    static func copyWebControllerURL() {
        guard let url = webControllerURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }


    static func generateQRCode(for string: String, scale: CGFloat = 8) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let rep = NSCIImageRep(ciImage: output.transformed(by: CGAffineTransform(scaleX: scale, y: scale)))
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
    static func airDropWebControllerURL() {
        guard let url = webControllerURL else { return }
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        if sharingService?.canPerform(withItems: [url]) == true {
            sharingService?.perform(withItems: [url])
        } else {
            // Fallback: standard share picker
            let picker = NSSharingServicePicker(items: [url])
            if let window = NSApp.keyWindow {
                picker.show(relativeTo: .zero, of: window.contentView ?? NSView(), preferredEdge: .minY)
            }
        }
    }
}
