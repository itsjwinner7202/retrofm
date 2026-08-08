const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

app.use(express.json());

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
        cb(null,file.originalname);
    }
});

const upload = multer({ storage: storage });

const { spawn } = require('child_process');

// Playback controller state
let isPlaying = false;
let playbackQueue = [];
let currentIndex = 0;
let currentFrequency = 103.3;
let currentChild = null;
let currentKillTimer = null;

function getWavDurationSync(filePath) {
    try {
        const fd = fs.openSync(filePath, 'r');
        const header = Buffer.alloc(44);
        fs.readSync(fd, header, 0, 44, 0);
        fs.closeSync(fd);
        const byteRate = header.readUInt32LE(28);
        const dataSize = header.readUInt32LE(40);
        if (!byteRate || !dataSize) return null;
        return dataSize / byteRate;
    } catch (e) {
        return null;
    }
}

function playNextInQueue() {
    if (currentKillTimer) {
        clearTimeout(currentKillTimer);
        currentKillTimer = null;
    }

    if (currentIndex >= playbackQueue.length) {
        isPlaying = false;
        currentChild = null;
        console.log('Playback finished (queue end)');
        return;
    }

    const next = playbackQueue[currentIndex];
    const songPath = path.join(uploadDir, next);
    const fmhandler = path.join(__dirname, 'PiFmAdv', 'src', 'pi_fm_adv');

    try {
        const duration = getWavDurationSync(songPath);
        console.log('Starting playback:', next, 'frequency=', currentFrequency, 'expectedSeconds=', duration);
        const child = spawn(fmhandler, ["--audio", songPath, "--freq", currentFrequency.toString(), "--preemph", "eu", "--rds", "--rt", "RETROFM", "--ps", "RETROFM"], {
            cwd: __dirname,
            stdio: ['ignore', process.stdout, process.stderr]
        });

        currentChild = child;

        if (duration && Number.isFinite(duration)) {
            currentKillTimer = setTimeout(() => {
                try {
                    child.kill('SIGTERM');
                    setTimeout(() => { try { child.kill('SIGKILL'); } catch(e){} }, 2000);
                    console.warn('Player exceeded expected duration, killed.');
                } catch(e) {
                    console.error('Failed to kill child after timeout', e);
                }
            }, Math.ceil(duration * 1000) + 5000);
        }

        child.on('exit', (code, signal) => {
            if (currentKillTimer) { clearTimeout(currentKillTimer); currentKillTimer = null; }
            console.log('Player exited for', next, 'code', code, 'signal', signal);
            currentIndex++;
            setTimeout(playNextInQueue, 500);
        });

    } catch (e) {
        console.error('Failed to start player for', next, e);
        currentIndex++;
        setTimeout(playNextInQueue, 500);
    }
}

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/songs', (req, res) => {
    fs.readdir(uploadDir, (err, files) => {
        if (err) {
            console.error('Error reading songs directory:', err);
            return res.status(500).json({ message: 'Failed to read songs', error: err.message });
        }
        const wavFiles = files.filter(f => f.toLowerCase().endsWith('.wav'));
        const songs = wavFiles.map(f => ({ filename: f, url: `/songs/${encodeURIComponent(f)}` }));
        res.json({ songs });
    });
});

app.post('/upload', upload.single('myfile'), (req, res) => {
    if (!req.file) {
        console.log('No file received in request');
        return res.status(400).send('No file uploaded.');
    }
    console.log('File path: ', req.file.path);
    res.json({ message: 'File uploaded successfully', filename: req.file.filename });
});

app.post('/play', (req, res) => {
    if (isPlaying) {
        return res.json({ message: 'Playback already in progress', currentIndex, queueLength: playbackQueue.length });
    }

    const freq = parseFloat(req.body.freq);
    const frequency = Number.isFinite(freq) && freq >= 76.0 && freq <= 108.0 ? freq : 103.3;

    fs.readdir(uploadDir, (err, files) => {
        if (err) {
            console.error('Error reading songs directory:', err);
            return res.status(500).json({ message: 'Failed to read songs', error: err.message });
        }
        const wavFiles = files.filter(f => f.toLowerCase().endsWith('.wav'));
        if (wavFiles.length === 0) {
            return res.status(404).json({ message: 'No songs to play' });
        }
        wavFiles.sort();
        playbackQueue = wavFiles;
        currentIndex = 0;
        currentFrequency = frequency;
        isPlaying = true;
        playNextInQueue();

        return res.json({ message: 'Started playback', queueLength: playbackQueue.length, frequency });
    });
});

app.post('/clear', (req, res) => {
    fs.readdir(uploadDir, (err, files) => {
        if (err) {
            console.error('Error reading songs directory:', err);
            return res.status(500).json({ message: 'Failed to clear songs', error: err.message });
        }
        const wavFiles = files.filter(f => f.toLowerCase().endsWith('.wav'));
        let removed = 0;
        wavFiles.forEach((f) => {
            try {
                fs.unlinkSync(path.join(uploadDir, f));
                removed++;
            } catch (e) {
                console.error('Failed to delete', f, e);
            }
        });
        res.json({ message: `Cleared ${removed} song(s)` });
    });
});


app.listen(PORT, () => {
    console.log(`http://localhost:${PORT}`);
});
