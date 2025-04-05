//
//  Resource.swift
//  ShowcasePackage
//
//  Created by Jason Jobe on 1/2/25.
//
// https://www.alihilal.com/blog/zero-copy-swift-mastering-accessor-coroutines.mdx/
import Foundation
import SwiftUI


@propertyWrapper
struct Resource<Value: Sendable>: DynamicProperty
{
    typealias Qualifier = CacheKey<Value>
    @Environment(\.resourceCache) var cache
    @StateObject private var tracker: Tracker<Value> = .init()
    
    public var wrappedValue: Value {
        tracker.value ?? _wrappedValue
    }
    
    var _wrappedValue: Value
    
    init(wrappedValue: Value) {
        self._wrappedValue = wrappedValue
    }
    
    func update() {
        tracker.refresh(cache: cache)
    }
    public var projectedValue: Tracker<Value> {
        tracker
    }
}

extension EnvironmentValues {
    @Entry var resourceCache: ResourceCache = .shared
}

public extension View {
    func resourceCache(_ cache: ResourceCache) -> some View {
        environment(\.resourceCache, cache)
    }
}

extension Resource {
    
    @MainActor
    final class Tracker<BoxValue: Sendable>: ObservableObject, Sendable {
        var cache: ResourceCache?
        var resource: DataLoader<BoxValue>?
        public var value: BoxValue?
        
        public var qualifier: CacheKey<BoxValue>? {
            didSet {
                reload()
            }
        }
        
        func refresh(cache: ResourceCache) {
            self.cache = cache
        }
        
        init(cacheKey: CacheKey<BoxValue>? = nil) {
            if let cacheKey {
                self.qualifier = cacheKey
                // TODO: report exceptions
                resource = try? cache?.resource(key: cacheKey)
            }
        }
        
        func report(error: Error) {
            let url = qualifier?.url.description ?? "<url>"
            print("Error loading \(url)\n\t: \(error.localizedDescription)")
        }
    
        func resetCache(with value: BoxValue) {
            objectWillChange.send()
            self.value = value
        }

        public func reload() {
            if let qualifier {
                do {
                    resource = try cache?.resource(key: qualifier)
                } catch {
                    report(error: error)
                }
            }
            load()
        }
        
        public func load() {
            guard let resource else { return }
            if case let .loaded(_, mod) = resource.check() {
                resetCache(with: mod)
                return
            }

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
