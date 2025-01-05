//
//  Resource.swift
//  ShowcasePackage
//
//  Created by Jason Jobe on 1/2/25.
//

import Foundation
import SwiftUI


@MainActor
@propertyWrapper
struct Resource<Value>: @preconcurrency DynamicProperty
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


extension Resource {
    
    final class Tracker<BoxValue>: ObservableObject, @unchecked Sendable {
        var resource: DataLoader?
        
        public var qualifier: CacheKey<BoxValue>? {
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
                // TODO: report exceptions
                resource = try? ResourceCache.shared.resource(key: cacheKey)
            }
        }
        
        func report(error: Error) {
            let url = qualifier?.url.description ?? "<url>"
            print("Error loading \(url)\n\t: \(error.localizedDescription)")
        }
        
        func resetCache(with data: Data) {
            Task { @MainActor in
                let val = try qualifier?.decoder(data)
                objectWillChange.send()
                _cache = val
            }
        }
        
        public func reload() {
            if let qualifier {
                do {
                    resource = try ResourceCache.shared.resource(key: qualifier)
                } catch {
                    report(error: error)
                }
            }
            load()
        }
        
        public func load() {
            guard let resource else { return }
            Task {
                do {
                    let data = try await resource.fetch()
                    resetCache(with: data)
                } catch {
                    report(error: error)
                }
            }
        }
    }
}
