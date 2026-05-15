#!/usr/bin/env node

const { execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const pkg = require('../package.json');

try {
  const updateNotifier = require('update-notifier');
  updateNotifier({ pkg, updateCheckInterval: 1000 * 60 * 60 * 24 }).notify({
    message:
      'Yeni sürüm mevcut: {currentVersion} → {latestVersion}\n' +
      'Güncellemek için: npm i -g {packageName}',
  });
} catch {}

const projectDir = process.argv[2];

if (!projectDir) {
  console.error('\n  Kullanım: rn-security-audit <proje-dizini>');
  console.error('  Örnek:    rn-security-audit ~/Documents/benim-uygulama\n');
  process.exit(1);
}

const resolvedDir = path.resolve(projectDir);

if (!fs.existsSync(resolvedDir)) {
  console.error(`\n  Hata: "${resolvedDir}" dizini bulunamadı.\n`);
  process.exit(1);
}

if (!fs.existsSync(path.join(resolvedDir, 'package.json'))) {
  console.error(`\n  Hata: "${resolvedDir}" bir React Native projesi değil (package.json bulunamadı).\n`);
  process.exit(1);
}

const auditScript = path.join(__dirname, '..', 'scripts', 'audit.sh');

// Scriptlere çalıştırma izni ver
try {
  execSync(`chmod +x "${auditScript}" "${path.join(__dirname, '..', 'scripts', 'checks')}"/*.sh`);
} catch {}

// Audit'i çalıştır
const result = spawnSync('bash', [auditScript, resolvedDir], {
  stdio: 'inherit',
  env: { ...process.env }
});

process.exit(result.status ?? 1);
