import UIKit
import WebKit
import GCDWebServer
import AVFoundation

class ViewController: UIViewController {
    
    private var webView: WKWebView!
    private var webServer: GCDWebServer!
    private let serverPort: UInt = 8080
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupWebServer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopServer()
    }
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupWebServer() {
        webServer = GCDWebServer()
        
        // Setup document directory structure if needed
        checkAndSetupDocumentStructure()
        
        // Setup static file server for web frontend
        setupStaticFileServer()
        
        // Setup API endpoints
        setupAPIEndpoints()
        
        // Start the server
        startServer()
    }
    
    private func startServer() {
        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: serverPort,
                GCDWebServerOption_BindToLocalhost: false,
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
            
            if let serverURL = webServer.serverURL {
                print("Server running at \(serverURL)")
                loadWebView(urlString: "http://localhost:\(serverPort)/")
            }
        } catch {
            print("Error starting server: \(error)")
        }
    }
    
    private func stopServer() {
        if webServer.isRunning {
            webServer.stop()
        }
    }
    
    private func loadWebView(urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // MARK: - Document Structure Setup
    
    private func checkAndSetupDocumentStructure() {
        let fileManager = FileManager.default
        guard let documentsPath = getDocumentsDirectory() else { return }
        
        // Create a placeholder file that indicates this is the app's document directory
        let placeholderFile = documentsPath.appendingPathComponent(".offlinetube")
        if !fileManager.fileExists(atPath: placeholderFile.path) {
            fileManager.createFile(atPath: placeholderFile.path, contents: "OfflineTube App Documents Folder".data(using: .utf8), attributes: nil)
        }
        
        // Copy sample content from the server folder if documents folder is empty
        checkAndPopulateSampleContent()
    }
    
    private func checkAndPopulateSampleContent() {
        let fileManager = FileManager.default
        guard let documentsPath = getDocumentsDirectory() else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            // If there are files other than our placeholder, don't add sample content
            if contents.count > 1 { return }
            
            // Add sample content structure
            let sampleAuthorDirs = ["Sample Author 1", "Sample Author 2"]
            
            for author in sampleAuthorDirs {
                let authorDir = documentsPath.appendingPathComponent(author)
                try? fileManager.createDirectory(at: authorDir, withIntermediateDirectories: true)
                
                // Add a README file explaining how to add content
                let readmePath = authorDir.appendingPathComponent("README.txt")
                let readmeContent = """
                OfflineTube Sample Directory
                
                This is a sample author directory. To add your own content:
                1. Connect your device to your computer
                2. Access the app's document folder via iTunes File Sharing or Finder
                3. Create a folder with the author's name
                4. Add video files inside the author folder
                5. The filename will be used as the video title and ID
                6. Thumbnails will be auto-generated
                """
                
                fileManager.createFile(atPath: readmePath.path, contents: readmeContent.data(using: .utf8), attributes: nil)
            }
        } catch {
            print("Error checking document content: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first
    }
    
    // MARK: - Web Server Configuration
    
    private func setupStaticFileServer() {
        // Serve static web files from the bundle
        let webPath = Bundle.main.path(forResource: "web", ofType: nil)
        if let webPath = webPath {
            webServer.addGETHandler(forBasePath: "/", directoryPath: webPath, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: true)
        } else {
            print("Web directory not found in bundle")
        }
        
        // Serve files from the Documents directory
        if let documentsPath = getDocumentsDirectory()?.path {
            webServer.addGETHandler(forBasePath: "/content/", directoryPath: documentsPath, indexFilename: nil, cacheAge: 0, allowRangeRequests: true)
        }
    }
    
    private func setupAPIEndpoints() {
        // API endpoint to get all videos
        webServer.addHandler(forMethod: "GET", path: "/api/videos", request: GCDWebServerRequest.self) { request in
            return self.handleGetVideosRequest(request)
        }
        
        // API endpoint to get video details
        webServer.addHandler(forMethod: "GET", path: "/api/video", request: GCDWebServerRequest.self) { request in
            return self.handleGetVideoDetailsRequest(request)
        }
        
        // API endpoint to get related videos
        webServer.addHandler(forMethod: "GET", path: "/api/related", request: GCDWebServerRequest.self) { request in
            return self.handleGetRelatedVideosRequest(request)
        }
        
        // API endpoint to search videos
        webServer.addHandler(forMethod: "GET", path: "/api/search", request: GCDWebServerRequest.self) { request in
            return self.handleSearchRequest(request)
        }
    }
    
    // MARK: - API Handlers
    
    private func handleGetVideosRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse {
        do {
            let videos = try getAllVideos()
            return GCDWebServerDataResponse(jsonObject: videos)
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
    }
    
    private func handleGetVideoDetailsRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse {
        guard let videoId = request.query?["id"] else {
            return GCDWebServerResponse(statusCode: 400)
        }
        
        do {
            if let videoDetails = try getVideoDetails(videoId: videoId) {
                return GCDWebServerDataResponse(jsonObject: videoDetails)
            } else {
                return GCDWebServerResponse(statusCode: 404)
            }
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
    }
    
    private func handleGetRelatedVideosRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse {
        guard let videoId = request.query?["id"] else {
            return GCDWebServerResponse(statusCode: 400)
        }
        
        do {
            let relatedVideos = try getRelatedVideos(forVideoId: videoId)
            return GCDWebServerDataResponse(jsonObject: relatedVideos)
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
    }
    
    private func handleSearchRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse {
        guard let query = request.query?["q"] else {
            return GCDWebServerResponse(statusCode: 400)
        }
        
        do {
            let searchResults = try searchVideos(query: query)
            return GCDWebServerDataResponse(jsonObject: searchResults)
        } catch {
            return GCDWebServerResponse(statusCode: 500)
        }
    }
    
    // MARK: - Video Processing Logic
    
    private func getAllVideos() throws -> [[String: Any]] {
        guard let documentsPath = getDocumentsDirectory() else {
            throw NSError(domain: "OfflineTube", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get documents directory"])
        }
        
        var allVideos: [[String: Any]] = []
        let fileManager = FileManager.default
        
        // Get all author directories
        let authorDirs = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            .filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true }
            .filter { !$0.lastPathComponent.starts(with: ".") } // Exclude hidden directories
        
        for authorDir in authorDirs {
            let authorName = authorDir.lastPathComponent
            
            // Get all video files
            let contents = try fileManager.contentsOfDirectory(at: authorDir, includingPropertiesForKeys: nil)
            let videoFiles = contents.filter { 
                let ext = $0.pathExtension.lowercased()
                return ["mp4", "mov", "m4v"].contains(ext)
            }
            
            for videoFile in videoFiles {
                let videoId = videoFile.deletingPathExtension().lastPathComponent
                let videoURL = "/content/\(authorName)/\(videoFile.lastPathComponent)"
                let thumbnailURL = getThumbnailURL(forVideo: videoFile, inAuthorDir: authorName)
                
                let videoInfo: [String: Any] = [
                    "id": videoId,
                    "title": videoId,
                    "author": authorName,
                    "videoUrl": videoURL,
                    "thumbnailUrl": thumbnailURL
                ]
                
                allVideos.append(videoInfo)
                
                // Generate thumbnail if it doesn't exist
                if !thumbnailExists(forVideo: videoFile, inAuthorDir: authorDir) {
                    generateThumbnail(forVideo: videoFile, inAuthorDir: authorDir)
                }
            }
        }
        
        return allVideos
    }
    
    private func getVideoDetails(videoId: String) throws -> [String: Any]? {
        guard let documentsPath = getDocumentsDirectory() else { throw NSError(domain: "OfflineTube", code: 1) }
        let fileManager = FileManager.default
        
        // Search for the video file with the given ID in all author directories
        let authorDirs = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            .filter { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true }
            .filter { !$0.lastPathComponent.starts(with: ".") }
        
        for authorDir in authorDirs {
            let authorName = authorDir.lastPathComponent
            let contents = try fileManager.contentsOfDirectory(at: authorDir, includingPropertiesForKeys: nil)
            
            // Find the video file
            if let videoFile = contents.first(where: { 
                let fileName = $0.deletingPathExtension().lastPathComponent
                let ext = $0.pathExtension.lowercased()
                return fileName == videoId && ["mp4", "mov", "m4v"].contains(ext)
            }) {
                let videoURL = "/content/\(authorName)/\(videoFile.lastPathComponent)"
                let thumbnailURL = getThumbnailURL(forVideo: videoFile, inAuthorDir: authorName)
                
                // Check if subtitles/captions exist
                let subtitleFile = contents.first(where: { 
                    $0.deletingPathExtension().lastPathComponent == videoId && 
                    ["vtt", "srt"].contains($0.pathExtension.lowercased())
                })
                
                let subtitleURL = subtitleFile != nil ? "/content/\(authorName)/\(subtitleFile!.lastPathComponent)" : nil
                
                // Get video duration and other metadata if possible
                let videoAsset = AVAsset(url: videoFile)
                let durationSeconds = CMTimeGetSeconds(videoAsset.duration)
                
                return [
                    "id": videoId,
                    "title": videoId,
                    "author": authorName,
                    "videoUrl": videoURL,
                    "thumbnailUrl": thumbnailURL,
                    "subtitleUrl": subtitleURL as Any,
                    "duration": durationSeconds,
                    "views": Int.random(in: 1000...1000000), // Mock data
                    "likes": Int.random(in: 100...10000),    // Mock data
                    "uploadDate": "2023-01-01"               // Mock data
                ]
            }
        }
        
        return nil
    }
    
    private func getRelatedVideos(forVideoId videoId: String) throws -> [[String: Any]] {
        // Get all videos and filter out the current one
        let allVideos = try getAllVideos()
        return allVideos.filter { ($0["id"] as? String) != videoId }
    }
    
    private func searchVideos(query: String) throws -> [[String: Any]] {
        let allVideos = try getAllVideos()
        let lowercaseQuery = query.lowercased()
        
        // Filter videos by title or author containing the search query
        return allVideos.filter { video in
            if let title = video["title"] as? String, title.lowercased().contains(lowercaseQuery) {
                return true
            }
            if let author = video["author"] as? String, author.lowercased().contains(lowercaseQuery) {
                return true
            }
            return false
        }
    }
    
    // MARK: - Thumbnail Management
    
    private func getThumbnailURL(forVideo videoFile: URL, inAuthorDir authorName: String) -> String {
        let videoId = videoFile.deletingPathExtension().lastPathComponent
        return "/content/\(authorName)/\(videoId).jpg"
    }
    
    private func thumbnailExists(forVideo videoFile: URL, inAuthorDir authorDir: URL) -> Bool {
        let videoId = videoFile.deletingPathExtension().lastPathComponent
        let thumbnailPath = authorDir.appendingPathComponent("\(videoId).jpg")
        return FileManager.default.fileExists(atPath: thumbnailPath.path)
    }
    
    private func generateThumbnail(forVideo videoFile: URL, inAuthorDir authorDir: URL) {
        let videoId = videoFile.deletingPathExtension().lastPathComponent
        let thumbnailPath = authorDir.appendingPathComponent("\(videoId).jpg")
        
        let asset = AVAsset(url: videoFile)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail at 20% of the video duration
        let duration = asset.duration
        let time = CMTimeMultiplyByFloat64(duration, multiplier: 0.2)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            
            if let jpgData = uiImage.jpegData(compressionQuality: 0.8) {
                try? jpgData.write(to: thumbnailPath)
                print("Generated thumbnail for \(videoId)")
            }
        } catch {
            print("Error generating thumbnail: \(error)")
        }
    }
}