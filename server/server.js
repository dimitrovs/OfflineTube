const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');

// Import mock data
const searchData = require('./mockData/search');
const videoDetailsData = require('./mockData/videoDetails');
const relatedContentsData = require('./mockData/relatedContents');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Welcome to OfflineTube Dummy API Server',
        endpoints: [
            {
                path: '/search/',
                description: 'Search for videos',
                params: 'q (search query string)',
                example: '/search/?q=educational'
            },
            {
                path: '/video/details/',
                description: 'Get video details',
                params: 'id (video ID)',
                example: '/video/details/?id=abc123'
            },
            {
                path: '/video/related-contents/',
                description: 'Get related videos',
                params: 'id (video ID)',
                example: '/video/related-contents/?id=abc123'
            },
            {
                path: '/watch/',
                description: 'Stream a video file',
                params: 'v (video ID)',
                example: '/watch?v=abc123'
            }
        ]
    });
});

// Search endpoint
app.get('/search/', (req, res) => {
    const query = req.query.q || '';

    if (!query) {
        return res.status(400).json({ error: 'Query parameter "q" is required' });
    }

    // Filter search results based on query (case-insensitive)
    const filteredResults = searchData.contents.filter(item =>
        item.video.title.toLowerCase().includes(query.toLowerCase())
    );

    // Create response object with filtered results
    const response = {
        contents: filteredResults.length > 0 ? filteredResults : searchData.contents.slice(0, 5)
    };

    res.json(response);
});

// Video details endpoint
app.get('/video/details/', (req, res) => {
    const videoId = req.query.id;

    if (!videoId) {
        return res.status(400).json({ error: 'Query parameter "id" is required' });
    }

    // Find video by ID or return the first video as default
    const videoDetails = videoDetailsData.find(video => video.videoId === videoId) || videoDetailsData[0];

    res.json(videoDetails);
});

// Related content endpoint
app.get('/video/related-contents/', (req, res) => {
    const videoId = req.query.id;

    if (!videoId) {
        return res.status(400).json({ error: 'Query parameter "id" is required' });
    }

    // Filter related videos based on video ID or return all as default
    const relatedVideos = relatedContentsData;

    res.json(relatedVideos);
});

// Video streaming endpoint
app.get('/watch', (req, res) => {
    const videoId = req.query.v;

    if (!videoId) {
        return res.status(400).json({ error: 'Query parameter "v" is required' });
    }

    const videoDir = path.join(__dirname, 'mockData', 'videos');

    // Read all files from the videos directory
    fs.readdir(videoDir, (err, files) => {
        if (err) {
            console.error(`Error reading video directory: ${err.message}`);
            return res.status(500).json({ error: 'Server error' });
        }

        // Filter for mp4 files only
        const videoFiles = files.filter(file => path.extname(file) === '.mp4');

        if (videoFiles.length === 0) {
            return res.status(404).json({ error: 'No videos available' });
        }

        // Use hash of videoId to consistently map to the same file
        // Simple hashing: sum the char codes and use modulo
        const charSum = videoId.split('').reduce((sum, char) => sum + char.charCodeAt(0), 0);
        const videoIndex = charSum % videoFiles.length;
        const selectedVideo = videoFiles[videoIndex];
        const videoPath = path.join(videoDir, selectedVideo);

        // Check if the video file exists
        fs.access(videoPath, fs.constants.F_OK, (err) => {
            if (err) {
                console.error(`Video file not found: ${videoPath}`);
                return res.status(404).json({ error: 'Video not found' });
            }

            // Get video file stats
            fs.stat(videoPath, (err, stats) => {
                if (err) {
                    console.error(`Error getting video stats: ${err.message}`);
                    return res.status(500).json({ error: 'Server error' });
                }

                // Handle range requests for video streaming
                const range = req.headers.range;
                if (range) {
                    const parts = range.replace(/bytes=/, '').split('-');
                    const start = parseInt(parts[0], 10);
                    const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
                    const chunkSize = (end - start) + 1;
                    const fileStream = fs.createReadStream(videoPath, { start, end });

                    res.writeHead(206, {
                        'Content-Range': `bytes ${start}-${end}/${stats.size}`,
                        'Accept-Ranges': 'bytes',
                        'Content-Length': chunkSize,
                        'Content-Type': 'video/mp4'
                    });

                    fileStream.pipe(res);
                } else {
                    // Send the entire file if no range is specified
                    res.writeHead(200, {
                        'Content-Length': stats.size,
                        'Content-Type': 'video/mp4'
                    });
                    fs.createReadStream(videoPath).pipe(res);
                }
            });
        });
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});