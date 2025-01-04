//
//  ResourceBox.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/20/24.
//

import Foundation
import Observation

public protocol AnyResourceBox: Identifiable {
    var id: ObjectIdentifier { get }
    var valueType: Any.Type  { get }
}

final public class ResourceBox<Value>: ObservableObject, AnyResourceBox, @unchecked Sendable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
    public var valueType: Any.Type { Value.self }
    public private(set) var isLoading: Bool = false
    
    private let lock = NSRecursiveLock()
    private var value: Value?

    public let remoteURL: URL
    public let fileURL: URL
    private let decode: @Sendable (Data) throws -> Value

    public init?(remote: String, cache: String,
          decode: @escaping @Sendable (Data) throws -> Value
    ) {
        guard let rurl = URL(string: remote)
        else { return nil }
        self.remoteURL = rurl
        self.fileURL = URL(fileURLWithPath: cache)
        self.decode = decode
    }
    
    public init(remote: URL, cache: URL,
          decode: @escaping @Sendable (Data) throws -> Value
    ) {
        self.remoteURL = remote
        self.fileURL = cache
        self.decode = decode
    }

    public init(remote: URL, cache: String,
          decode: @escaping @Sendable (Data) throws -> Value
    ) {
        self.remoteURL = remote
        self.fileURL = URL(fileURLWithPath: cache)
        self.decode = decode
    }

    public var wrappedValue: Value? {
        return lock.withLock { value }
    }

    public func withLock<R>(_ body: (inout Value?) throws -> R) rethrows -> R {
        try lock.withLock { try body(&value) }
    }

    public func awaitValue() async throws -> Value? {
        if let val = load() { return val }
        try await fetch()
        return wrappedValue
    }
    
    func report(_ error: Error) {
        print(error)
    }
    
    // cache to disk
    func save(_ data: Data) throws {
        guard fileURL.isFileURL else {
            throw AnyError()
        }
        try FileManager.default
            .createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }
        
    func fetch() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw AnyError()
        }
        do {
            try save(data)
        } catch {
            report(error)
        }
        let newValue = try decode(data)
        lock.withLock {
            value = newValue
        }
    }
    
    public var isCached: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    @discardableResult
    func load(refresh: Bool = true) -> Value? {
        if let wrappedValue { return wrappedValue }
        if isCached {
            do {
                let cachedValue = try read()
                withLock {
                    $0 = cachedValue
                }
            } catch {
                // Something is wrong w/ the cached file
                // so let's remove it
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        if refresh || wrappedValue == nil {
            Task.detached { [weak self] in
                guard let self = self else { return }
                do {
                    try await fetch()
                } catch {
                    report(error)
                }
            }
        }
        return wrappedValue
    }

    // read Data from cache file
    func read() throws -> Value {
        guard FileManager.default.fileExists(atPath: fileURL.path)
        else { throw AnyError("File NOT found: \(fileURL.path)") }
        let data = try Data(contentsOf: fileURL)
        return try decode(data)
    }

    static public func == (lhs: ResourceBox<Value>, rhs: ResourceBox<Value>) -> Bool {
        lhs === rhs
    }
}

struct AnyError: Error {
    let msg: String
    let file: String
    let line: UInt
    init(_ msg: String = "Some Error", file: String = #fileID, line: UInt = #line) {
        self.msg = msg
        self.file = file
        self.line = line
    }
}
