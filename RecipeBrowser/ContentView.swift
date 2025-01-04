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
    @State var selectedResourceId: ObjectIdentifier

    init() {
        resource = .allRecipes
        selectedResourceId = ResourceBox<RecipeBox>.allRecipes.id
    }
    
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
            Picker("Endpoint", selection: $selectedResourceId) {
                Text("All Recipes").tag(ResourceBox.allRecipes.id)
                Text("Empty Recipes").tag(ResourceBox.emptyRecipes.id)
                Text("Malformed Recipes").tag(ResourceBox.malformedRecipes.id)
            }
        }
        .padding()
        .onChange(of: selectedResourceId) {
            Task { await refresh() }
        }
    }
    
    func refresh() async {
        emptyMessage = "No recipes were found"
        
        let it = ResourceBox<RecipeBox>
            .allCases.first { $0.id == selectedResourceId }
        ?? .allRecipes
        resource = it

        do {
            if let box = try await resource.awaitValue() {
                recipeBox = box
            }
        } catch {
            emptyMessage = error.localizedDescription
            resource = .emptyRecipes
        }
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
