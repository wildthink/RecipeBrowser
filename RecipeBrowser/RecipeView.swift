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
    @Environment(\.openURL) var openURL
    @Resource var image: Image?
    var recipe: Recipe
    var presentationStyle: PresentationStyle
    
    init(recipe: Recipe, presentationStyle: PresentationStyle) {
        self.recipe = recipe
        self.presentationStyle = presentationStyle
    }
    
    func refreshImage() {
        if let imgURL = (presentationStyle == .fullpage)
            ? recipe.photoURLLarge : recipe.photoURLSmall {
            $image.qualifier = CacheKey(url: imgURL, decoder: Image.init)
        }
    }
    
    var body: some View {
        main
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomTrailing) {
            links
                .frame(maxWidth: .infinity)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
        }
        .onAppear {
            refreshImage()
        }
    }
    
    @ViewBuilder
    var main: some View {
        switch presentationStyle {
            case _ where image == nil:
                ProgressView("Loading")
            case .fullpage:
                fullpage
            case .row:
                rowView
        }
    }
    
    @ViewBuilder
    var links: some View {
        HStack {
            Spacer()
            if let sourceURL = recipe.sourceURL {
                Image(systemName: "link")
                    .onTapGesture {
                        openURL(sourceURL)
                    }
            }
            if let youtubeURL = recipe.youtubeURL {
                Image(systemName: "tv")
                    .onTapGesture {
                        openURL(youtubeURL)
                    }
            }
        }
    }
    @ViewBuilder
    var rowView: some View {
        HStack {
            photo
                .cornerRadius(8)
            caption
            Spacer()
        }
    }
    
    @ViewBuilder
    var fullpage: some View {
        ZStack(alignment: .top) {
            photo
            caption
                .padding()
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
            ContentUnavailableView(
                "No Image Available",
                systemImage: "fork.knife.circle")
        }
    }
    
    @ViewBuilder
    var caption: some View {
        VStack(alignment: .leading) {
            Text(recipe.name)
                .font(titleFont)
            Text(recipe.cuisine)
                .font(subtitleFont)
                .foregroundStyle(.secondary)
        }
    }

    // FIXME: Refactor this to a device-sensitive theme and layout
    // module
    var titleFont: Font {
        #if os(iOS)
            let idiom = UIDevice.current.userInterfaceIdiom
        return switch idiom {
        case .mac: .title
        case .phone: .title3
        default:
                .title3
        }
        #else
        return .title
        #endif
    }
    
    var subtitleFont: Font {
        #if os(iOS)
            let idiom = UIDevice.current.userInterfaceIdiom
        return switch idiom {
        case .mac: .title2
        case .phone: .caption
        default:
                .title2
        }
        #else
        return .title
        #endif
    }

}
