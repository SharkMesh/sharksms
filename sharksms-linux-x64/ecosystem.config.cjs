module.exports = {
  apps: [
    {
      name: 'sharksms-prod',
      script: './loader.js',
      instances: 'max',
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};