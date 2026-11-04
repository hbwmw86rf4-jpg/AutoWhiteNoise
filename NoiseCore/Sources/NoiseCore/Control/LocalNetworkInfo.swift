#if canImport(Darwin)
import Foundation
import Darwin

/// Finds this device's Wi-Fi/Ethernet IPv4 address so the Automations screen
/// can show a URL that definitely works, even when `<name>.local` does not
/// resolve on the other device.
public enum LocalNetworkInfo {
    public static func primaryIPv4Address() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        var fallback: String?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }
            guard let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(ifa.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: ifa.pointee.ifa_name)
            let ip = String(cString: host)
            // en0 is Wi-Fi on iPhone/iPad and on most Macs; prefer it.
            if name == "en0" { return ip }
            if name.hasPrefix("en"), fallback == nil { fallback = ip }
        }
        return fallback
    }
}
#endif
