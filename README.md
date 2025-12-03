# Viral Video SaaS

Generate viral videos using Freepik AI API. A complete SaaS solution with single video generation, batch production, and history management.

## Features

- **Single Video Generation**: Create one video at a time with real-time progress tracking
- **Batch Generation**: Mass produce videos in loop mode (set quantity or run infinitely)
- **Video History**: Browse, search, play, and download all generated videos
- **WebSocket Progress**: Real-time status updates during generation
- **Modern UI**: Dark mode interface with TailwindCSS and Alpine.js

## Tech Stack

- **Backend**: Python FastAPI
- **Frontend**: HTML5 + TailwindCSS + Alpine.js
- **Database**: SQLite (async with aiosqlite)
- **WebSocket**: Real-time progress updates
- **Containerization**: Docker + Docker Compose
- **Web Server**: Nginx (reverse proxy)

## Quick Start

### Option 1: Docker (Recommended)

```bash
# Clone or download the project
cd viral-video-saas

# Run Docker installation
./install-docker.sh
```

### Option 2: Direct Installation (Ubuntu 22.04)

```bash
# Run as root
sudo ./install.sh
```

## Manual Installation

### Prerequisites

- Python 3.11+
- Nginx
- Git

### Steps

```bash
# 1. Install dependencies
apt update
apt install -y nginx python3.11 python3.11-venv python3-pip

# 2. Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# 3. Install Python packages
pip install -r backend/requirements.txt

# 4. Configure Nginx (see nginx.conf)
cp nginx.conf /etc/nginx/sites-available/viral-saas
ln -s /etc/nginx/sites-available/viral-saas /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# 5. Run the backend
cd backend
uvicorn app:app --host 0.0.0.0 --port 8000
```

## Configuration

### Adding Your Freepik API Key

1. Open the application in your browser
2. Click the **Settings** icon (gear) in the header
3. Enter your Freepik API key
4. Click **Save**

### Getting a Freepik API Key

1. Go to [https://www.freepik.com/api](https://www.freepik.com/api)
2. Create an account or log in
3. Access the Developer Dashboard
4. Generate your API key
5. You'll receive **5 EUR in free credits** to start!

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/generate` | Generate single video |
| GET | `/api/generate/{id}` | Get generation status |
| POST | `/api/batch/start` | Start batch generation |
| POST | `/api/batch/stop` | Stop batch generation |
| GET | `/api/batch/status` | Get batch status |
| GET | `/api/history` | List video history |
| GET | `/api/history/{id}` | Get video details |
| DELETE | `/api/history/{id}` | Delete video |
| GET | `/api/models/image` | List image models |
| GET | `/api/models/video` | List video models |
| POST | `/api/settings/apikey` | Save API key |
| GET | `/api/settings/apikey` | Check API key status |
| WS | `/ws/progress` | WebSocket for real-time updates |

## Available Models

### Image Models

| Model | Description |
|-------|-------------|
| mystic | Ultra-realistic high resolution images |
| realism | Realistic photos with natural colors |
| flux | Creative and artistic images |
| zen | Clean and minimalist results |
| flexible | Great for illustrations |
| super_real | Maximum realism priority |
| editorial_portraits | Professional portrait photos |

### Video Models

| Model | Description |
|-------|-------------|
| kling-std | Standard quality video generation |
| kling-pro | High quality professional videos |
| kling-v2 | Latest Kling model |
| minimax-768p | Good for facial expressions |
| minimax-1080p | High definition 1080p |

## Project Structure

```
viral-video-saas/
├── backend/
│   ├── app.py              # Main FastAPI application
│   ├── requirements.txt    # Python dependencies
│   ├── routes/
│   │   ├── generate.py     # Single video generation
│   │   ├── batch.py        # Batch generation
│   │   ├── history.py      # Video history
│   │   ├── models.py       # AI models listing
│   │   └── settings.py     # API key management
│   ├── services/
│   │   ├── freepik_api.py  # Freepik API integration
│   │   └── websocket_manager.py  # WebSocket handler
│   └── database/
│       └── db.py           # SQLite database
├── frontend/
│   ├── index.html          # Main UI
│   ├── js/app.js           # Alpine.js application
│   └── css/styles.css      # Custom styles
├── storage/
│   ├── images/             # Generated images
│   ├── videos/             # Generated videos
│   └── thumbnails/         # Video thumbnails
├── docker-compose.yml      # Docker configuration
├── Dockerfile              # Container build
├── nginx.conf              # Nginx configuration
├── install.sh              # Ubuntu installation script
└── install-docker.sh       # Docker installation script
```

## Usage

### Single Video Generation

1. Select an **Image Model** (e.g., Mystic for realistic images)
2. Select a **Video Model** (e.g., Kling Pro for high quality)
3. Enter your **Prompt** describing the scene
4. Click **Generate Video**
5. Watch the progress in real-time
6. Download or preview the finished video

### Batch Generation

1. Go to the **Batch** tab
2. Configure models and prompt
3. Set **Quantity** (0 = infinite loop)
4. Set **Interval** between generations (in seconds)
5. Click **Start Production**
6. Monitor progress in the log
7. Click **Stop** when done

### History Management

1. Go to the **History** tab
2. Browse generated videos
3. Click to play any video
4. Download or delete videos
5. Use search to filter by prompt

## Service Management

### Systemd (Direct Install)

```bash
# Check status
sudo systemctl status viral-saas

# View logs
sudo journalctl -u viral-saas -f

# Restart
sudo systemctl restart viral-saas
```

### Docker

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f

# Restart
docker compose restart

# Stop
docker compose down
```

## Freepik API Pricing

The Freepik API uses a **pay-as-you-go** model:

- **Free credits**: 5 EUR to start
- Image generation: ~0.02-0.05 EUR per image
- Video generation: ~0.20-0.50 EUR per video
- No monthly commitment

For high-volume usage (>5,000 EUR/month), contact Freepik for custom pricing.

## Troubleshooting

### WebSocket Not Connecting

- Check that Nginx is configured for WebSocket upgrade
- Ensure firewall allows port 80/443
- Check backend is running: `curl http://localhost:8000/api/health`

### Video Generation Fails

- Verify your API key is valid
- Check Freepik API rate limits
- Ensure you have credits in your Freepik account
- Check backend logs for detailed errors

### Storage Issues

- Verify storage directory permissions
- Check available disk space
- Ensure www-data user can write to storage

## License

MIT License - Feel free to use, modify, and distribute.

## Support

- Issues: Create an issue in the repository
- Freepik API Docs: [https://docs.freepik.com](https://docs.freepik.com)
- Freepik Support: [https://www.freepik.com/api#contact](https://www.freepik.com/api#contact)
