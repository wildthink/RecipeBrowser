//
//  Resource.swift
//  ShowcasePackage
//
//  Created by Jason Jobe on 1/2/25.
//

import Foundation
import SwiftUI

public protocol DataDecodable {
    @Sendable init(data: Data) throws
}

@MainActor
@propertyWrapper
struct Resource<Value: DataDecodable>: @preconcurrency DynamicProperty
{
    typealias Qualifier = CacheKey<Value>
    @StateObject private var tracker: Tracker<Value> = .init()
    var qualifier: Qualifier? {
        get { tracker.qualifier }
        nonmutating set { tracker.qualifier = newValue }
    }

    public var wrappedValue: Value {
        tracker.value ?? _wrappedValue
    }
    
    var _wrappedValue: Value

    init(wrappedValue: Value) {
        self._wrappedValue = wrappedValue
    }
    
    mutating func update() {
        tracker.qualifier = self.qualifier
    }
    
    public var projectedValue: Tracker<Value> {
        tracker
    }
}

// MARK: Cache Extension

extension ResourceCache {
    
//    func resource<Value, Key: CacheKey>(
//        _ key: Key
//    ) where Key.Type == Value throws -> ResourceBox<Value> {
//        let key = key.url.absoluteString.DJB2hashValue().description
//        return try resource(remote: remote, key: key, decode: D.init)
//    }

    
    func resource<D: DataDecodable>(
        _ type: D.Type = D.self,
        remote: URL
    ) throws -> ResourceBox<D> {
        let key = remote.absoluteString.DJB2hashValue().description
        return try resource(remote: remote, key: key, decode: D.init)
    }
}

extension Image: DataDecodable {}
extension Optional: DataDecodable where Wrapped: DataDecodable {
    public init(data: Data) throws {
        self = try Wrapped(data: data)
    }
}

extension Image: @retroactive Decodable {
    public init(from decoder: Decoder) throws {
        // Provide a meaningful implementation or throw an error if decoding is unsupported
        throw DecodingError.typeMismatch(
            Image.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Image cannot be directly decoded."
            )
        )
    }
}

extension Resource {
    
    final class Tracker<BoxValue: DataDecodable>: ObservableObject, @unchecked Sendable {
        var resource: ResourceBox<BoxValue>?

        var qualifier: CacheKey<BoxValue>? {
            get { _qualifier }
            set {
                guard newValue != _qualifier
                else { return }
                _qualifier = newValue
                reload()
            }
        }
        
        var _qualifier: CacheKey<BoxValue>?

        public var value: BoxValue? {
            if let _cache { return _cache }
            load()
            return _cache
         }
        private var _cache: BoxValue?
        
        init(cacheKey: CacheKey<BoxValue>? = nil) {
            if let cacheKey {
                self.qualifier = cacheKey
                resource = try? ResourceCache.shared.resource(BoxValue.self, remote: cacheKey.url)
            }
        }
                
        func resetCache(to value: BoxValue) {
            Task { @MainActor in
                objectWillChange.send()
                _cache = value
            }
        }
        
        func reload() {
            if let qualifier {
                resource = try? ResourceCache.shared.resource(key: qualifier)
            }
            load()
        }
        
        func load() {
            guard let resource else { return }
            if let val = resource.load(refresh: false) {
                resetCache(to: val)
            }
            Task {
                if let val = try? await resource.awaitValue() {
                    resetCache(to: val)
                }
            }
        }
    }
}
