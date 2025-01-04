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
    typealias Qual = String // Qualifier<Value>
    @StateObject private var tracker: Tracker = .init()
    var qualifier: Qual? {
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
        print(#function, self.qualifier ?? "")
        tracker.qualifier = self.qualifier
    }
    
    public var projectedValue: Self {
        get {
            print(#function)
            return self
        }
    }
}

//extension Resource {
//    init(wrappedValue url: URL?) {
//        fatalError()
////        self._wrappedValue = .blankValue
//    }
//}

import Combine

extension Resource {
    
    /// The object that keeps on observing the database as long as it is alive.

    private final class Tracker: ObservableObject, @unchecked Sendable {
        var resource: ResourceBox<Data>?
        var defaultValue: Value?

        private var subscription: Cancellable?
//        private var database = NXApp.database
        var qualifier: Qual? {
            didSet { load() }
        }

        public var value: Value? {
            if let _cache { return _cache }
            load()
            return _cache
         }
        private var _cache: Value?
        
        init(qualifier: Qual? = nil) {
            let base = URL(string: "https://example.com/")!
            if let qualifier, let url = URL(string: qualifier, relativeTo: base) {
                let key = url.path.replacingOccurrences(of: "/", with: "_")
                self.resource = try? ResourceCache.shared.resource(remote: url, key: key)
            }
        }
        
        deinit {
            subscription?.cancel()
        }
        
        func load() {
            print(#function, resource?.remoteURL)
//            _cache = resource?.load(refresh: false)
            Task {
//                guard let qualifier else { return }
                if let val = try? await resource?.awaitValue() {
                    print("did", #function, val)
//                    _cache = val
                }
            }
        }
    }
}

