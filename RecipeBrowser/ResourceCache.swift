//
//  ResourceCache.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/20/24.
//

import Foundation
import SwiftUI

public final class ResourceCache {
    public static let shared = ResourceCache()
    
    private let lock = NSRecursiveLock()
    private var resources: [URL: DataLoader]
    let cacheDirectory: URL
    
    public init(cacheDirectory: String = NSTemporaryDirectory()) {
        self.cacheDirectory = URL(filePath: cacheDirectory)
            .appending(component: "cache")
        
        resources = [:]
    }
    
    public func clearCache() {
        // TODO: Provide robust cache eviction logic
        lock.withLock {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
    }
    
    func resourceCacheURL(key: String) -> URL {
        let key = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(key)
    }
    
    func resource<R>(key: CacheKey<R>) throws -> DataLoader {
        lock.withLock {
            if let goodbox = resources[key.url] {
                return goodbox
            }
            // Otherwise we create a new ResourceBox to be shared
            let box = DataLoader(url: key.url, cache: resourceCacheURL(key: key.localKey))
            resources[key.url] = box
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
