//
//  DataLoader.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 1/4/25.
//
import SwiftUI
import Foundation

public actor DataLoader {
    private var status: LoaderStatus
    public let localCacheFile: URL
    
    public init(url: URL, cache: URL) {
        self.status = .ready(URLRequest(url: url))
        self.localCacheFile = cache
    }
    
    public init(request: URLRequest, cache: URL) {
        self.status = .ready(request)
        self.localCacheFile = cache
    }
    
    public func fetch() async throws -> Data {
        var urlRequest: URLRequest
        
        switch status {
        case .ready(let req):
            urlRequest = req
        case .fetched(let data):
            return data
        case .inProgress(let task):
            return try await task.value
        }
        
        if let data = try self.dataFromFileSystem(for: urlRequest) {
            status = .fetched(data)
            return data
        }
        
        let task: Task<Data, Error> = Task {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            try self.persist(data, for: urlRequest)
            return data
        }
        
        status = .inProgress(task)
        let data = try await task.value
        status = .fetched(data)
        return data
    }
    
    
    private func persist(_ data: Data, for urlRequest: URLRequest) throws {
        guard localCacheFile.isFileURL else {
            throw AnyError()
        }
        try FileManager.default
            .createDirectory(at: localCacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: localCacheFile)
    }
    
    private enum LoaderStatus {
        case ready(URLRequest)
        case inProgress(Task<Data, Error>)
        case fetched(Data)
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
