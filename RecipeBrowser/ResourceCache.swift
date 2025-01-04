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

public struct CacheKey<Value>: Hashable {
    public let url: URL
    public var valueType: Any.Type { Value.self }
    let decoder: @Sendable (Data) throws -> Value
    
    public init(url: URL, decoder: @escaping @Sendable (Data) -> Value) {
        self.url = url
        self.decoder = decoder
    }

    public var localKey: String { url.DJB2hashValue().description }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static public func == (lhs: CacheKey<Value>, rhs: CacheKey<Value>) -> Bool {
        lhs.url == rhs.url
    }
}

public extension CacheKey {
    
    init(for: Value.Type = Value.self, url: URL)
    where Value: Decodable {
        self.url = url
        self.decoder = {
            try JSONDecoder().decode(Value.self, from: $0)
        }
    }
    
    init(for: Value.Type = Value.self, url: URL)
    where Value == Image {
        self.url = url
        self.decoder = { Image(data: $0) }
    }

}

// MARK: Convenience ResourceBoxes

extension ResourceCache {
    
    func resource<R>(key: CacheKey<R>) throws -> ResourceBox<R> {
        try resource(
            remote: key.url,
            key: key.localKey,
            decode: key.decoder)
    }

//    func resource<R: Decodable>(remote: URL, key: String) throws -> ResourceBox<R> {
//        try resource(remote: remote, key: key, decode: {
//            try JSONDecoder().decode(R.self, from: $0)
//        })
//    }
}

extension CustomStringConvertible {
    func DJB2hashValue(seed: Int = 5381) -> Int {
        description.DJB2hashValue(seed: seed)
    }
}

extension String {
    func DJB2hashValue(seed: Int = 5381) -> Int {
        return unicodeScalars.reduce(seed) { ($0 &* 33) &+ Int($1.value) }
    }
}
