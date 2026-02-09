//
//  LocalNetworkOnlyMiddleware.swift
//  NylServer
//
//  Created by Jeremy Spradlin on 2/9/26.
//

import Foundation
import Vapor

/// Restricts access to local network and loopback addresses.
struct LocalNetworkOnlyMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let ipAddress = request.remoteAddress?.ipAddress else {
            throw Abort(.forbidden, reason: "Local network access only")
        }
        if !isLocalNetworkAddress(ipAddress) {
            throw Abort(.forbidden, reason: "Local network access only")
        }

        return try await next.respond(to: request)
    }

    private func isLocalNetworkAddress(_ address: String) -> Bool {
        if address == "127.0.0.1" || address == "::1" {
            return true
        }

        if address.hasPrefix("10.") || address.hasPrefix("192.168.") {
            return true
        }

        if address.hasPrefix("172.") {
            let parts = address.split(separator: ".")
            if parts.count > 1, let second = Int(parts[1]) {
                return (16...31).contains(second)
            }
        }

        if address.lowercased().hasPrefix("fc") || address.lowercased().hasPrefix("fd") {
            return true
        }

        if address.lowercased().hasPrefix("fe80:") {
            return true
        }

        return false
    }
}
