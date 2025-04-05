//
//  DataLoader.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 1/4/25.
//
import SwiftUI
import Foundation

extension NSLock {
    func withLock<T>(_ apply: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try apply()
    }
}

public actor DataLoader<Model> {
    public typealias Transformer = (Data) throws -> Model
//    nonisolated let valuePublisher = CurrentValueSubject<Int, Never>(0)

    nonisolated(unsafe) private var status: LoaderStatus
    private let lock = NSLock()
    nonisolated public func check() -> LoaderStatus {
        lock.withLock {
            self.status
        }
    }
        
    private let transformer: Transformer
    public let localCacheFile: URL
    
    public init(url: URL, cache: URL, transform: @escaping Transformer) {
        self.status = .ready(URLRequest(url: url))
        self.localCacheFile = cache
        self.transformer = transform
    }
    
    public init(request: URLRequest, cache: URL, transform: @escaping Transformer) {
        self.status = .ready(request)
        self.localCacheFile = cache
        self.transformer = transform
    }
    
    public func fetch() async throws -> Model {
        var urlRequest: URLRequest
        
        switch status {
            case .ready(let req):
                urlRequest = req
            case .loaded(_, let model):
                return model
            case .inProgress(let task):
                let data = try await task.value
                let m = try transformer(data)
                self.status = .loaded(data, m)
                return m
            case .failed(let e):
                throw e
        }
        
        if let data = try self.dataFromFileSystem(for: urlRequest) {
            let model = try transformer(data)
            status = .loaded(data, model)
            return model
        }
        
        let task: Task<Data, Error> = Task {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            try self.persist(data, for: urlRequest)
            return data
        }
        
        status = .inProgress(task)
        let data = try await task.value
        let model = try transformer(data)
        status = .loaded(data, model)
        return model
    }
    
    
    private func persist(_ data: Data, for urlRequest: URLRequest) throws {
        guard localCacheFile.isFileURL else {
            throw AnyError()
        }
        try FileManager.default
            .createDirectory(at: localCacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: localCacheFile)
    }
    
    public enum LoaderStatus {
        case ready(URLRequest)
        case inProgress(Task<Data, Error>)
        case loaded(Data, Model)
        case failed(Error)
    }
    
    private func dataFromFileSystem(for urlRequest: URLRequest) throws -> Data? {
        guard FileManager.default.fileExists(at: localCacheFile)
        else { return nil }
        return try Data(contentsOf: localCacheFile)
    }
}

extension FileManager {
    
    func fileExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = self.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDir)
        return exists && isDir.boolValue == false
    }
    
}

struct AnyError: Error {
    let msg: String
    let date = Date()
    let file: String
    let line: UInt
    init(_ msg: String = "Some Error", file: String = #fileID, line: UInt = #line) {
        self.msg = msg
        self.file = file
        self.line = line
    }
}
