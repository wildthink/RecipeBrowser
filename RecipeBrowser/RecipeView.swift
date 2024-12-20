//
//  RecipeView.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/20/24.
//

import SwiftUI


enum PresentationStyle {
    case fullpage, row
}


struct RecipeView: View {
    @State var resource: ResourceBox<Image>
    @State var image: Image?
    var recipe: Recipe
    var presentationStyle: PresentationStyle
    
    init(recipe: Recipe, presentationStyle: PresentationStyle) {
        self.resource = .imageResource(
            for: (presentationStyle == .fullpage)
            ? recipe.photoURLLarge : recipe.photoURLSmall)
        self.recipe = recipe
        self.presentationStyle = presentationStyle
    }
    
    var body: some View {
        Group {
            switch presentationStyle {
            case _ where image == nil:
                ProgressView("Loading")
            case .fullpage:
                fullpage
            case .row:
                rowView
            }
        }
        .onAppear {
            image = resource.load(refresh: false)
        }
        .task {
            guard image == nil else { return }
            if let img = try? await resource.awaitValue() {
                image = img
            }
        }
    }
    
    @ViewBuilder
    var rowView: some View {
        HStack {
            photo
                .cornerRadius(8)
            caption
        }
    }
    
    @ViewBuilder
    var fullpage: some View {
        ZStack(alignment: .top) {
            photo
            caption
                .padding(.leading, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
        }
        .cornerRadius(8)
    }
    
    @ViewBuilder
    var photo: some View {
        if let image {
            image
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "circle")
                .resizable()
        }
    }
    
    @ViewBuilder
    var caption: some View {
        VStack(alignment: .leading) {
            Text(recipe.name)
                .font(.title)
            Text(recipe.cuisine)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
