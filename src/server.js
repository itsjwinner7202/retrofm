const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

const uploadDir = path.join(__dirname, '/public/songs');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Storage configuration
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + file.originalname);
    }
});

const upload = multer({ storage: storage });

app.use(express.static(path.join(__dirname, 'public')));

app.post('/upload', upload.single('myfile'), (req, res) => {
    if (!req.file) {
        console.log('No file received in request');
        return res.status(400).send('No file uploaded.');
    }
    console.log('SUCCESS: File saved to path ->', req.file.path);
    res.json({ message: 'File uploaded successfully', filename: req.file.filename });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});