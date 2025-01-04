//
//  ResourceCache.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/20/24.
//

import Foundation
import SwiftUI

final class ResourceCache {
    static let shared = ResourceCache()
    
    private let lock = NSRecursiveLock()
    private var resources: [String: any AnyResourceBox]
    let cacheDirectory: URL
    
    init(cacheDirectory: String = NSTemporaryDirectory()) {
        self.cacheDirectory = URL(filePath: cacheDirectory)
            .appending(component: "cache")
        
        resources = [:]
    }
    
    func clearCache() {
        // TODO: Provide robust cache eviction logic
        lock.withLock {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
    }
    
    func resourceCacheURL(key: String) -> URL {
        let key = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(key)
    }
    
    /// All specializing resource lookup / creation MUST ultimately pass through this method
    func resource<A>(
        remote: URL,
        key: String,
        decode: @escaping @Sendable (Data) throws -> A
    ) throws -> ResourceBox<A> {
        try lock.withLock {
            if let anybox = resources[key] {
                guard let goodbox = anybox as? ResourceBox<A>
                else {
                    throw AnyError("Resource key \(key) has mismatching types," +
                                   "\(anybox.valueType) != \(A.self)")
                }
                return goodbox
            }
            // Otherwise we create a new ResourceBox to be shared
            let box = ResourceBox(
                remote: remote,
                cache: resourceCacheURL(key: key),
                decode: decode)
            resources[key] = box
            return box
        }
    }
}

// MARK: Convenience ResourceBoxes

extension ResourceCache {
    func resource<R: Decodable>(remote: URL, key: String) throws -> ResourceBox<R> {
        try resource(remote: remote, key: key, decode: {
            try JSONDecoder().decode(R.self, from: $0)
        })
    }

    func resource(remote: URL, key: String) throws -> ResourceBox<Image> {
        try resource(remote: remote, key: key, decode: Image.init)
    }
}

extension String {
    func DJB2hashValue(seed: Int) -> Int {
        return unicodeScalars.reduce(seed) { ($0 &* 33) &+ Int($1.value) }
    }
}
