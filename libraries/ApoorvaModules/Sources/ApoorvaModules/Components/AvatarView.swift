//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import Foundation

import SwiftUI

struct AvatarView: View {
    // The optional remote image URL
    let imageURL: URL?
    
    // Configurable size for the avatar component
    var size: CGFloat = 60
    
    // The default/fallback image name (from Assets or SF Symbols)
    var defaultImageName: String = "person.crop.circle.fill"
    
    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // 1. Loading State: Show a loading indicator
                        ProgressView()
                            .frame(width: size, height: size)
                        
                    case .success(let image):
                        // 2. Success State: Display and clip the downloaded image
                        image
                            .resizable()
                            .scaledToFill()
                        
                    case .failure(_):
                        defaultPlaceholderView
                    @unknown default:
                        // 3. Network Error State: Fallback to default asset
                        defaultPlaceholderView
                    }
                }
            } else {
                // 4. Missing/Nil URL State: Fallback directly to default asset
                defaultPlaceholderView
            }
        }
        // Consistent framing and clipping applied across all states
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // Separated view structure to reuse for both invalid URLs and download failures
    @ViewBuilder
    private var defaultPlaceholderView: some View {
        if UIImage(named: defaultImageName) != nil {
            // Checks if a custom Asset Catalog image exists
            Image(defaultImageName)
                .resizable()
                .scaledToFill()
        } else {
            // Default to an SF Symbol if no local asset matches the name
            Image(systemName: defaultImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.gray)
                .padding(size * 0.15) // Scales the symbol beautifully inside the frame
                .background(Color(.systemGray6))
        }
    }
}
