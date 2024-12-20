//
//  CardViewModifier.swift
//  RecipeBrowser
//
//  Created by Jason Jobe on 12/20/24.
//


import SwiftUI

public struct CardViewModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 4
    
    public init(cornerRadius: CGFloat, shadowRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 2)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : .white
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.2)
    }
}

public extension View {
    func cardStyle(cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 4) -> some View {
        self.modifier(CardViewModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}
