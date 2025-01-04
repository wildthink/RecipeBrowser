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
    typealias Qualifier = String
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

extension ResourceCache {
    
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

public struct AnyDecoable<Value: Decodable>: DataDecodable {
    var valueType: Any.Type { Value.self }
    var value: Value
    
    public init(data: Data) throws {
        value = try JSONDecoder().decode(Value.self, from: data)
    }    
}

//extension Decodable: DataDecodable {
//    
//}
//extension Resource {
//    init(wrappedValue url: URL?) {
//        fatalError()
////        self._wrappedValue = .blankValue
//    }
//}

//import Combine

extension Resource {
    
    final class Tracker<TValue: DataDecodable>: ObservableObject, @unchecked Sendable {
        var resource: ResourceBox<TValue>?

        var qualifier: Qualifier? {
            get { _qualifier }
            set {
                guard newValue != _qualifier
                else { return }
                _qualifier = newValue
                reload()
            }
        }
        
        var _qualifier: Qualifier?

        public var value: TValue? {
            if let _cache { return _cache }
            load()
            return _cache
         }
        private var _cache: TValue?
        
        init(qualifier: Qualifier? = nil) {
            if let qualifier, let url = URL(string: qualifier) {
                resource = try? ResourceCache.shared.resource(TValue.self, remote: url)
            }
        }
                
        func resetCache(to value: TValue) {
            Task { @MainActor in
                objectWillChange.send()
                _cache = value
            }
        }
        
        func reload() {
            if let qualifier, qualifier != resource?.remoteURL.absoluteString,
               let url = URL(string: qualifier) {
                resource = try? ResourceCache.shared.resource(TValue.self, remote: url)
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
