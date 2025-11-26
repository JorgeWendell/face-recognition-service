module.exports = {
  apps: [
    {
      name: 'face-recognition-service',
      script: 'app.py',
      interpreter: 'python3',
      cwd: '/var/www/face-recognition-service',
      env: {
        API_HOST: '0.0.0.0',
        API_PORT: '9090',
        FACE_MATCH_THRESHOLD: '0.6',
      },
      env_file: '.env',
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      instances: 1,
      exec_mode: 'fork',
    },
  ],
};

