const bytenode = require('bytenode');
const path = require('path');

// 启动单文件字节码
try {
  require(path.join(__dirname, 'index.jsc'));
} catch (err) {
  console.error('Failed to run encrypted bundle:', err);
  process.exit(1);
}
