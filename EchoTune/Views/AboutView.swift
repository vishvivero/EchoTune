//
//  AboutView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
            
            // App name and version
            Text("EchoTune")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Version 1.0.0 (Build 1)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Description
            Text("Local AI Voice Dictation for macOS")
                .font(.headline)
            
            Text("EchoTune provides high-quality voice transcription using local AI models, ensuring complete privacy and offline functionality.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            // Credits
            VStack(spacing: 5) {
                Text("Created by Vishnu Raj")
                    .font(.subheadline)
                
                Text("© \(Calendar.current.component(.year, from: Date())) EchoTune Software. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Links
            HStack(spacing: 20) {
                Button("Website") {
                    if let url = URL(string: "https://echotune.app") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Support") {
                    if let url = URL(string: "https://echotune.app/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://echotune.app/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}







