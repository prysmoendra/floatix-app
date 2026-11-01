const test = require('node:test'); const assert = require('node:assert');
const { pickVideo, buildOpenMessage } = require('../lib/video.js');
test('tanpa video', () => assert.strictEqual(pickVideo([]), -1));
test('abaikan luas nol', () => assert.strictEqual(pickVideo([{ width: 0, height: 0, paused: false }]), -1));
test('utamakan yang diputar', () => assert.strictEqual(pickVideo([
  { width: 1920, height: 1080, paused: true }, { width: 320, height: 180, paused: false }]), 1));
test('lalu yang terbesar', () => assert.strictEqual(pickVideo([
  { width: 320, height: 180, paused: true }, { width: 640, height: 360, paused: true }]), 1));
test('pesan open', () => assert.deepStrictEqual(
  buildOpenMessage('https://a.b/v', { currentTime: 12.5, width: 400, height: 300 }),
  { type: 'open', url: 'https://a.b/v', time: 12.5, aspect: 400 / 300 }));
test('aspect default', () => assert.strictEqual(
  buildOpenMessage('https://a.b', { currentTime: 0, width: 0, height: 0 }).aspect, 16 / 9));
