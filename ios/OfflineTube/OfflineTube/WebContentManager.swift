import Foundation
import GCDWebServer

class WebContentManager {
    static let shared = WebContentManager()
    
    private var webServer: GCDWebServer?
    private var serverURL: URL?
    
    // Initialize web server
    func startWebServer() {
        if webServer == nil {
            webServer = GCDWebServer()
            
            // Get the path to the web directory in the bundle
            let bundleURL = Bundle.main.bundleURL
            let webDirURL = bundleURL.appendingPathComponent("web")
            
            // First make sure web assets are copied to the bundle
            copyWebContentToBundleIfNeeded()
            
            // Configure the server
            guard let webServer = webServer, FileManager.default.fileExists(atPath: webDirURL.path) else {
                print("Cannot start web server - web directory does not exist")
                return
            }
            
            // Add a handler to serve static files from the web directory
            webServer.addGETHandler(forBasePath: "/", directoryPath: webDirURL.path, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: true)
            
            // Add API endpoint handlers
            addAPIEndpoints(webServer)
            
            // Start the server on a random port
            do {
                try webServer.start(options: [
                    GCDWebServerOption_Port: 8080,
                    GCDWebServerOption_BindToLocalhost: true,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false
                ])
                
                serverURL = URL(string: "http://localhost:\(webServer.port)")
                print("Web server started successfully at \(serverURL?.absoluteString ?? "")")
            } catch {
                print("Error starting web server: \(error)")
            }
        }
    }
    
    func stopWebServer() {
        webServer?.stop()
        webServer = nil
        serverURL = nil
        print("Web server stopped")
    }
    
    func getServerURL() -> URL? {
        return serverURL
    }
    
    // Add API endpoints to handle requests from the web app
    private func addAPIEndpoints(_ webServer: GCDWebServer) {
        // Add endpoint for video details
        webServer.addHandler(forMethod: "GET", path: "/api/video", request: GCDWebServerRequest.self) { request in
            guard let videoId = request.query?["id"] else {
                return GCDWebServerResponse(statusCode: 400)
            }
            
            // Here you would fetch the video details from your local database
            // For now, we'll return a simple JSON response
            let response: [String: Any] = [
                "id": videoId,
                "title": "Sample Video",
                "description": "This is a sample video description"
            ]
            
            return GCDWebServerDataResponse(jsonObject: response)
        }
        
        // Add endpoint for search
        webServer.addHandler(forMethod: "GET", path: "/api/search", request: GCDWebServerRequest.self) { request in
            guard let query = request.query?["q"] else {
                return GCDWebServerResponse(statusCode: 400)
            }
            
            // Here you would search your local database
            // For now, return a sample response
            let response: [String: Any] = [
                "query": query,
                "results": [
                    ["id": "video1", "title": "Sample Video 1"],
                    ["id": "video2", "title": "Sample Video 2"]
                ]
            ]
            
            return GCDWebServerDataResponse(jsonObject: response)
        }
        
        // Add endpoint to serve video files
        let videoPath = Bundle.main.bundlePath + "/server/mockData/videos"
        webServer.addHandler(forMethod: "GET", path: "/videos/", request: GCDWebServerRequest.self) { request in
            guard let fileName = request.url.lastPathComponent.removingPercentEncoding else {
                return GCDWebServerResponse(statusCode: 404)
            }
            
            let filePath = videoPath + "/" + fileName
            if FileManager.default.fileExists(atPath: filePath) {
                return GCDWebServerFileResponse(file: filePath, byteRange: request.byteRange)
            } else {
                return GCDWebServerResponse(statusCode: 404)
            }
        }
    }
    
    func copyWebContentToBundleIfNeeded() {
        // Check if the web directory exists in the bundle
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let webDirURL = bundleURL.appendingPathComponent("web")
        
        if !fileManager.fileExists(atPath: webDirURL.path) {
            do {
                // Create the web directory in the bundle
                try fileManager.createDirectory(at: webDirURL, withIntermediateDirectories: true, attributes: nil)
                
                // Copy the web content from our project's web folder
                if let webProjectPath = getWebProjectPath() {
                    try copyDirectory(at: webProjectPath, to: webDirURL)
                    print("Successfully copied web content to bundle")
                } else {
                    print("Web project path not found")
                }
            } catch {
                print("Error copying web content to bundle: \(error)")
            }
        }
    }
    
    private func getWebProjectPath() -> URL? {
        // Get the path to the web project folder in the app's main bundle
        let mainBundlePath = Bundle.main.bundlePath
        let projectRootPath = URL(fileURLWithPath: mainBundlePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let webProjectPath = projectRootPath.appendingPathComponent("web")
        
        if FileManager.default.fileExists(atPath: webProjectPath.path) {
            return webProjectPath
        }
        
        return nil
    }
    
    private func copyDirectory(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let destURL = destinationURL.appendingPathComponent(fileName)
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true, attributes: nil)
                    try copyDirectory(at: fileURL, to: destURL)
                } else {
                    try fileManager.copyItem(at: fileURL, to: destURL)
                }
            }
        }
    }
}