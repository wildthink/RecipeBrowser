//
//  ContentView.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/19/24.
//

import SwiftUI
import Foundation

extension RecipeBox: DataDecodable {
    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

struct ContentView: View {
    @Resource var recipeBox: RecipeBox = .init()
    @State var selectedRecipe: Recipe?
    @State var emptyMessage: String = "No recipes were found"
    @State var selectedKey: CacheKey<RecipeBox> = .allRecipes
    
    var body: some View {
        VStack {
            Group {
                if recipeBox.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "fork.knife.circle",
                        description: Text(emptyMessage))
                    
                } else {
                    recipeList
                }
            }
            Spacer()
            controls
                .frame(maxWidth: .infinity)
                .cardStyle(cornerRadius: 4, shadowRadius: 0)
                .background(.regularMaterial)
        }
        .onAppear {
            $recipeBox.qualifier = selectedKey
        }
        .onChange(of: recipeBox) {
            print("Recipe Count", recipeBox.recipes.count)
        }
        .padding()
    }
    
    @ViewBuilder
    var recipeList: some View {
        List(recipeBox.cuisines, id: \.self) { cuisine in
            Section(header: Text("\(cuisine)")) {
                LazyVStack {
                    ForEach(recipeBox.select(for: cuisine)) { recipe in
                        RecipeView(recipe: recipe, presentationStyle: .row)
                            .frame(maxWidth: .infinity, maxHeight: 80, alignment: .leading)
                            .cardStyle()
                            .contentShape(.rect)
                            .onTapGesture {
                                selectedRecipe = recipe
                            }
                    }
                }
            }
        }
        .overlay {
            if let selectedRecipe {
                RecipeView(recipe: selectedRecipe, presentationStyle: .fullpage)
                    .contentShape(.rect)
                    .onTapGesture {
                        self.selectedRecipe = nil
                    }
            }
        }
    }
}

extension ContentView {
    @ViewBuilder
    var controls: some View {
        HStack {
            Button("Clear Cache", systemImage: "trash") {
                ResourceCache.shared.clearCache()
            }
            Button("Refresh", systemImage: "square.and.arrow.down") {
                Task { await refresh() }
            }
            Picker("Endpoint", selection: $selectedKey) {
                Text("All Recipes").tag(CacheKey<RecipeBox>.allRecipes)
                Text("Empty Recipes").tag(CacheKey<RecipeBox>.emptyRecipes)
                Text("Malformed Recipes").tag(CacheKey<RecipeBox>.malformedRecipes)
            }
        }
        .padding()
        .onChange(of: selectedKey) {
            Task { await refresh() }
        }
    }
    
    func refresh() async {
        emptyMessage = "No recipes were found"
        let it = CacheKey<RecipeBox>
            .allCases.first { $0 == selectedKey }
        ?? .allRecipes
        
        $recipeBox.qualifier = it
    }
}

// MARK: Resource Helpers

/*
 You’ll also find test endpoints to simulate various scenarios.
 All Recipes: https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json
 Malformed Data: https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json
 Empty Data: https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json
 */

extension CacheKey<RecipeBox> {
    static var allCases: [CacheKey<RecipeBox>] = [
        .allRecipes, .emptyRecipes, .malformedRecipes
    ]
    
    static let allRecipes: CacheKey<RecipeBox> = .init(
            url: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json")!)
    
    static let emptyRecipes: CacheKey<RecipeBox> = .init(
            url: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json")!)
    
    static let malformedRecipes: CacheKey<RecipeBox> = .init(
            url: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json")!)
}

extension ResourceBox<RecipeBox> {
    static var allCases: [ResourceBox<RecipeBox>] = [
        .allRecipes, .emptyRecipes, .malformedRecipes
    ]
    
    static let allRecipes: ResourceBox<RecipeBox> = try! ResourceCache.shared
        .resource(
            remote: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json")!,
            key: "recipes.json")
    
    static let emptyRecipes: ResourceBox<RecipeBox> = try! ResourceCache.shared
        .resource(
            remote: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json")!,
            key: "recipes-empty.json")

    static let malformedRecipes: ResourceBox<RecipeBox> = try! ResourceCache.shared
        .resource(
            remote: URL(string: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json")!,
            key: "recipes-malformed.json")

}

extension ResourceBox<Image> {
    static func imageResource(for url: URL) throws -> ResourceBox<Image> {
        let key = url.path.replacingOccurrences(of: "/", with: "_")
        return try ResourceCache.shared.resource(remote: url, key: key)
    }
}

#if os(macOS)
public extension Image {
    @Sendable init(data: Data) {
        self = if let it = NSImage(data: data) {
            Self.init(nsImage: it)
        } else {
            Image(systemName: "circle.slash")
        }
    }
}
#endif

#if os(iOS)
public extension Image {
    @Sendable init(data: Data) {
        self = if let it = UIImage(data: data) {
            Self.init(uiImage: it)
        } else {
            Image(systemName: "circle.slash")
        }
    }
}
#endif

#Preview {
    ContentView()
}
