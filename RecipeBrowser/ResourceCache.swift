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
    
    let cacheDirectory: URL
    
    init(cacheDirectory: String = NSTemporaryDirectory()) {
        self.cacheDirectory = URL(filePath: cacheDirectory)
            .appending(component: "cache")
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
    
    func resourceCacheURL(key: String) -> URL {
        let key = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent(key)
    }
    
    func resource<R: Decodable>(remote: URL, key: String) -> ResourceBox<R> {
        ResourceBox(
            remote: remote,
            cache: resourceCacheURL(key: key),
            decode: {
                try JSONDecoder().decode(R.self, from: $0)
            })
    }
    
    func resource(remote: URL, key: String) -> ResourceBox<Image> {
        ResourceBox(
            remote: remote,
            cache: resourceCacheURL(key: key),
            decode: Image.init)
    }

}
