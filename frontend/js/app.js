/**
 * Viral Video SaaS - Frontend Application
 * Alpine.js based reactive frontend
 */

function app() {
    return {
        // State
        activeTab: 'generate',
        showSettings: false,
        showVideoPlayer: false,

        // API Key
        apiKeyConfigured: false,
        maskedApiKey: '',
        newApiKey: '',
        savingApiKey: false,

        // Models
        imageModels: [],
        videoModels: [],

        // Generate Form
        generateForm: {
            prompt: '',
            imageModel: 'mystic',
            videoModel: 'kling-std'
        },

        // Generation State
        isGenerating: false,
        progress: 0,
        currentStep: '',
        statusMessage: '',
        lastGeneratedVideo: null,
        currentVideoId: null,

        // Batch Form
        batchForm: {
            prompt: '',
            imageModel: 'mystic',
            videoModel: 'kling-std',
            quantity: 10,
            interval: 30
        },

        // Batch State
        batchRunning: false,
        batchCompleted: 0,
        batchTotal: 0,
        batchPercentage: 0,
        batchLogs: [],
        batchJobId: null,

        // History
        historyVideos: [],
        historyPage: 1,
        historyTotalPages: 1,
        historyStats: {},
        searchTerm: '',

        // Video Player
        currentVideo: null,

        // Toasts
        toasts: [],

        // WebSocket
        ws: null,

        // Step order for progress tracking
        stepOrder: [
            'image_generating',
            'image_processing',
            'image_downloading',
            'video_generating',
            'video_processing',
            'video_downloading',
            'finalizing',
            'completed'
        ],

        // Initialize
        async init() {
            await this.loadModels();
            await this.checkApiKey();
            await this.loadHistory();
            await this.checkBatchStatus();
            this.connectWebSocket();
        },

        // WebSocket Connection
        connectWebSocket() {
            const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = `${wsProtocol}//${window.location.host}/ws/progress`;

            this.ws = new WebSocket(wsUrl);

            this.ws.onopen = () => {
                console.log('WebSocket connected');
            };

            this.ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                this.handleWebSocketMessage(data);
            };

            this.ws.onclose = () => {
                console.log('WebSocket disconnected, reconnecting...');
                setTimeout(() => this.connectWebSocket(), 3000);
            };

            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        },

        handleWebSocketMessage(data) {
            switch (data.type) {
                case 'progress':
                    if (data.video_id === this.currentVideoId) {
                        this.progress = data.progress || 0;
                        this.currentStep = data.step || '';
                        this.statusMessage = data.message || '';
                    }
                    break;

                case 'completed':
                    if (data.video_id === this.currentVideoId) {
                        this.isGenerating = false;
                        this.progress = 100;
                        this.currentStep = 'completed';
                        this.lastGeneratedVideo = data.video_path;
                        this.showToast('Video generated successfully!', 'success');
                        this.loadHistory();
                    }
                    break;

                case 'error':
                    if (data.video_id === this.currentVideoId) {
                        this.isGenerating = false;
                        this.progress = 0;
                        this.currentStep = '';
                        this.showToast(data.message || 'An error occurred', 'error');
                    }
                    break;

                case 'batch_progress':
                    if (data.job_id === this.batchJobId) {
                        this.batchCompleted = data.completed || 0;
                        this.batchTotal = data.total || 0;
                        this.batchPercentage = data.percentage || 0;

                        if (data.log_message) {
                            const timestamp = new Date().toLocaleTimeString();
                            this.batchLogs.unshift(`[${timestamp}] ${data.log_message}`);
                            // Keep last 100 logs
                            if (this.batchLogs.length > 100) {
                                this.batchLogs.pop();
                            }
                        }

                        if (data.status === 'completed' || data.status === 'stopped') {
                            this.batchRunning = false;
                            this.showToast(`Batch job ${data.status}`, data.status === 'completed' ? 'success' : 'info');
                            this.loadHistory();
                        }
                    }
                    break;
            }
        },

        // Step completion check
        stepCompleted(step) {
            const currentIndex = this.stepOrder.indexOf(this.currentStep);
            const checkIndex = this.stepOrder.indexOf(step);
            return currentIndex > checkIndex;
        },

        // Load Models
        async loadModels() {
            try {
                const response = await fetch('/api/models');
                const data = await response.json();
                if (data.success) {
                    this.imageModels = data.image_models || [];
                    this.videoModels = data.video_models || [];
                }
            } catch (error) {
                console.error('Failed to load models:', error);
                // Fallback models
                this.imageModels = [
                    { id: 'mystic', name: 'Mystic', description: 'Ultra-realistic images' },
                    { id: 'realism', name: 'Realism', description: 'Realistic photos' },
                    { id: 'flux', name: 'Flux', description: 'Creative images' }
                ];
                this.videoModels = [
                    { id: 'kling-std', name: 'Kling Standard', description: 'Standard quality' },
                    { id: 'kling-pro', name: 'Kling Pro', description: 'High quality' }
                ];
            }
        },

        // Check API Key Status
        async checkApiKey() {
            try {
                const response = await fetch('/api/settings/apikey');
                const data = await response.json();
                this.apiKeyConfigured = data.configured || false;
                this.maskedApiKey = data.masked_key || '';
            } catch (error) {
                console.error('Failed to check API key:', error);
            }
        },

        // Save API Key
        async saveApiKey() {
            if (!this.newApiKey) return;

            this.savingApiKey = true;
            try {
                const response = await fetch('/api/settings/apikey', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ api_key: this.newApiKey })
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    this.apiKeyConfigured = true;
                    this.maskedApiKey = data.masked_key;
                    this.newApiKey = '';
                    this.showToast('API key saved successfully!', 'success');
                } else {
                    this.showToast(data.detail || 'Failed to save API key', 'error');
                }
            } catch (error) {
                this.showToast('Failed to save API key', 'error');
            } finally {
                this.savingApiKey = false;
            }
        },

        // Generate Video
        async generateVideo() {
            if (!this.generateForm.prompt) {
                this.showToast('Please enter a prompt', 'error');
                return;
            }

            if (!this.apiKeyConfigured) {
                this.showToast('Please configure your API key first', 'error');
                this.showSettings = true;
                return;
            }

            this.isGenerating = true;
            this.progress = 0;
            this.currentStep = '';
            this.statusMessage = 'Starting generation...';
            this.lastGeneratedVideo = null;

            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        prompt: this.generateForm.prompt,
                        image_model: this.generateForm.imageModel,
                        video_model: this.generateForm.videoModel
                    })
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    this.currentVideoId = data.video_id;
                    this.showToast('Video generation started', 'info');
                } else {
                    this.isGenerating = false;
                    this.showToast(data.detail || 'Failed to start generation', 'error');
                }
            } catch (error) {
                this.isGenerating = false;
                this.showToast('Failed to start generation', 'error');
            }
        },

        // Start Batch
        async startBatch() {
            if (!this.batchForm.prompt) {
                this.showToast('Please enter a prompt', 'error');
                return;
            }

            if (!this.apiKeyConfigured) {
                this.showToast('Please configure your API key first', 'error');
                this.showSettings = true;
                return;
            }

            try {
                const response = await fetch('/api/batch/start', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        prompt: this.batchForm.prompt,
                        image_model: this.batchForm.imageModel,
                        video_model: this.batchForm.videoModel,
                        quantity: this.batchForm.quantity,
                        interval: this.batchForm.interval
                    })
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    this.batchRunning = true;
                    this.batchJobId = data.job_id;
                    this.batchCompleted = 0;
                    this.batchTotal = this.batchForm.quantity;
                    this.batchPercentage = 0;
                    this.batchLogs = [];
                    this.showToast('Batch production started!', 'success');
                } else {
                    this.showToast(data.detail || 'Failed to start batch', 'error');
                }
            } catch (error) {
                this.showToast('Failed to start batch', 'error');
            }
        },

        // Stop Batch
        async stopBatch() {
            try {
                const response = await fetch('/api/batch/stop', {
                    method: 'POST'
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    this.batchRunning = false;
                    this.showToast('Batch production stopped', 'info');
                } else {
                    this.showToast(data.detail || 'Failed to stop batch', 'error');
                }
            } catch (error) {
                this.showToast('Failed to stop batch', 'error');
            }
        },

        // Check Batch Status
        async checkBatchStatus() {
            try {
                const response = await fetch('/api/batch/status');
                const data = await response.json();

                if (data.running && data.job) {
                    this.batchRunning = true;
                    this.batchJobId = data.job.id;
                    this.batchCompleted = data.job.completed_count || 0;
                    this.batchTotal = data.job.total_quantity || 0;
                    this.batchPercentage = this.batchTotal > 0
                        ? (this.batchCompleted / this.batchTotal) * 100
                        : 0;
                }
            } catch (error) {
                console.error('Failed to check batch status:', error);
            }
        },

        // Load History
        async loadHistory(page = 1) {
            this.historyPage = page;

            try {
                let url = `/api/history?page=${page}&limit=20`;
                if (this.searchTerm) {
                    url += `&search=${encodeURIComponent(this.searchTerm)}`;
                }

                const [historyResponse, statsResponse] = await Promise.all([
                    fetch(url),
                    fetch('/api/history/stats')
                ]);

                const historyData = await historyResponse.json();
                const statsData = await statsResponse.json();

                this.historyVideos = historyData.videos || [];
                this.historyTotalPages = historyData.total_pages || 1;
                this.historyStats = statsData;
            } catch (error) {
                console.error('Failed to load history:', error);
            }
        },

        // Play Video
        playVideo(video) {
            if (video.video_path) {
                this.currentVideo = video;
                this.showVideoPlayer = true;
            }
        },

        // Delete Video
        async deleteVideo(videoId) {
            if (!confirm('Are you sure you want to delete this video?')) return;

            try {
                const response = await fetch(`/api/history/${videoId}`, {
                    method: 'DELETE'
                });

                const data = await response.json();

                if (response.ok && data.success) {
                    this.showToast('Video deleted', 'success');
                    this.loadHistory(this.historyPage);
                } else {
                    this.showToast(data.detail || 'Failed to delete video', 'error');
                }
            } catch (error) {
                this.showToast('Failed to delete video', 'error');
            }
        },

        // Format Date
        formatDate(dateStr) {
            if (!dateStr) return '';
            const date = new Date(dateStr);
            return date.toLocaleDateString('pt-BR', {
                day: '2-digit',
                month: '2-digit',
                year: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            });
        },

        // Show Toast
        showToast(message, type = 'info') {
            const toast = { message, type, show: true };
            this.toasts.push(toast);

            setTimeout(() => {
                toast.show = false;
                setTimeout(() => {
                    const index = this.toasts.indexOf(toast);
                    if (index > -1) {
                        this.toasts.splice(index, 1);
                    }
                }, 300);
            }, 4000);
        }
    };
}
