//
//  Catalog.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/19/24.
//

import Foundation

// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let catalog = try? JSONDecoder().decode(RecipeBox.self, from: jsonData)

// MARK: - RecipeBox
struct RecipeBox: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case recipes
    }
    
    let recipes: [Recipe]
    var cuisines: [String]
    var isEmpty: Bool { recipes.isEmpty }
    
    init() {
        recipes = []
        cuisines = []
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try container.decode([Recipe].self, forKey: .recipes)
        let set = recipes.reduce(into: Set<String>()) { partialResult, recipe in
            partialResult.insert(recipe.cuisine)
        }
        cuisines = set.sorted()
    }
    
    func select(for cuisine: String) -> [Recipe] {
        recipes.filter({ $0.cuisine == cuisine })
    }
}

// MARK: - Recipe
struct Recipe: Codable, Identifiable, Equatable, Sendable {
    var id: UUID { uuid }
    let cuisine, name: String
    let photoURLLarge, photoURLSmall: URL?
    let sourceURL: URL?
    let uuid: UUID
    let youtubeURL: URL?

    enum CodingKeys: String, CodingKey {
        case cuisine, name
        case photoURLLarge = "photo_url_large"
        case photoURLSmall = "photo_url_small"
        case sourceURL = "source_url"
        case uuid
        case youtubeURL = "youtube_url"
    }
}

// MARK: Preview Data
extension RecipeBox {
    static let preview: RecipeBox = try! JSONDecoder().decode(RecipeBox.self, from: previewData)
}

fileprivate let previewData = """
{
    "recipes": [
        {
            "cuisine": "Malaysian",
            "name": "Apam Balik",
            "photo_url_large": "https://d3jbb8n5wk0qxi.cloudfront.net/photos/b9ab0071-b281-4bee-b361-ec340d405320/large.jpg",
            "photo_url_small": "https://d3jbb8n5wk0qxi.cloudfront.net/photos/b9ab0071-b281-4bee-b361-ec340d405320/small.jpg",
            "source_url": "https://www.nyonyacooking.com/recipes/apam-balik~SJ5WuvsDf9WQ",
            "uuid": "0c6ca6e7-e32a-4053-b824-1dbf749910d8",
            "youtube_url": "https://www.youtube.com/watch?v=6R8ffRRJcrg"
        },
        {
            "cuisine": "British",
            "name": "Apple & Blackberry Crumble",
            "photo_url_large": "https://d3jbb8n5wk0qxi.cloudfront.net/photos/535dfe4e-5d61-4db6-ba8f-7a27b1214f5d/large.jpg",
            "photo_url_small": "https://d3jbb8n5wk0qxi.cloudfront.net/photos/535dfe4e-5d61-4db6-ba8f-7a27b1214f5d/small.jpg",
            "source_url": "https://www.bbcgoodfood.com/recipes/778642/apple-and-blackberry-crumble",
            "uuid": "599344f4-3c5c-4cca-b914-2210e3b3312f",
            "youtube_url": "https://www.youtube.com/watch?v=4vhcOwVBDO4"
        }
    ]
}
""".data(using: .utf8)!

