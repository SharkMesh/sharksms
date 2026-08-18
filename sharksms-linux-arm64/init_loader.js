const bytenode = require('bytenode');
const path = require('path');

// 启动数据库初始化字节码
try {
  require(path.join(__dirname, 'init_db.jsc'));
} catch (err) {
  console.error('Failed to run database initialization:', err);
  process.exit(1);
}
