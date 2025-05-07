//
//  ContentView.swift
//  OfflineTube
//
//  Created by Stefan Dimitrov on 5/5/25.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @State private var serverURL: URL?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let url = serverURL {
                WebView(url: url, isLoading: $isLoading)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Starting server...")
            }
            
            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
        .onAppear {
            startWebServer()
        }
    }
    
    private func startWebServer() {
        // Start the web server when the view appears
        WebContentManager.shared.startWebServer()
        
        // Give it a moment to start up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.serverURL = WebContentManager.shared.getServerURL()
        }
    }
}

// SwiftUI wrapper for WKWebView
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
