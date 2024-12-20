//
//  ContentView.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/19/24.
//

import SwiftUI

struct ContentView: View {
    @State var resource: ResourceBox<RecipeBox>
    @State var recipeBox: RecipeBox = .init()
    @State var selectedRecipe: Recipe?
    @State var emptyMessage: String = "No recipes were found"
    
    init() {
        resource = .allRecipes
    }
    
    var body: some View {
        VStack {
            Group {
                if recipeBox.isEmpty {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "fork.knife.circle",
                        description: Text(emptyMessage))
                    
                } else {
                    recipeList
                }
            }
            controls
                .frame(maxWidth: .infinity)
                .cardStyle(cornerRadius: 4, shadowRadius: 0)
                .background(.regularMaterial)
        }
        .onAppear {
            if let box = resource.load(refresh: true) {
                recipeBox = box
            }
        }
        .onReceive(resource.wrappedValue.publisher) {
            recipeBox = $0
        }
        .task {
            await refresh()
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
                            .frame(maxWidth: .infinity, maxHeight: 120, alignment: .leading)
                            .cardStyle()
                            .contentShape(.rect)
                            .onTapGesture {
                                selectedRecipe = recipe
                            }
                    }
                }
                .padding()
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
                ImageCache.shared.clearCache()
            }
            Button("Refresh", systemImage: "square.and.arrow.down") {
                Task { await refresh() }
            }
        }
    }
    
    func refresh() async {
        do {
            if let box = try await resource.awaitValue() {
                recipeBox = box
            }
        } catch {
            print(error)
        }
    }
}

struct ImageCache {
    static let shared = ImageCache()
    
    let cacheDirectory = URL(filePath: "/Users/jason/Downloads/cache")
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}

// MARK: Resource Helpers

/*
 You’ll also find test endpoints to simulate various scenarios.
 All Recipes: https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json
 Malformed Data: https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json
 Empty Data: https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json
 */

extension ResourceBox<RecipeBox> {
    static let allRecipes = ResourceBox(
        remote: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes.json",
        cache: "/Users/jason/Downloads/cache/recipes.data",
        decode: {
            try JSONDecoder().decode(RecipeBox.self, from: $0)
        })!
    
    static let emptyRecipes = ResourceBox(
        remote: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-empty.json",
        cache: "/Users/jason/Downloads/cache/recipes-empty.data",
        decode: {
            try JSONDecoder().decode(RecipeBox.self, from: $0)
        })!

    static let malformedRecipes = ResourceBox(
        remote: "https://d3jbb8n5wk0qxi.cloudfront.net/recipes-malformed.json",
        cache: "/Users/jason/Downloads/cache/recipes-malformed.data",
        decode: {
            try JSONDecoder().decode(RecipeBox.self, from: $0)
        })!

}

extension ResourceBox<Image> {
    static func imageResource(for url: URL) -> ResourceBox {
        let key = url.path.replacingOccurrences(of: "/", with: "_")
        return ResourceBox(
            remote: url,
            cache: "/Users/jason/Downloads/cache/\(key).jpg",
            decode: Image.init)
    }
}

#if os(macOS)
extension Image {
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
extension Image {
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

