# ============================================================================
# build-orbis360.ps1  —  Orbis360 offline project builder (Block 1 of 6)
# Writes all 47 project files, verifies them, and packages Orbis360.zip.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.
# This block is the ONLY one that defines the header and the W function.
# ============================================================================
$ErrorActionPreference = 'Stop'
$root = Join-Path (Get-Location) 'Orbis360'
$enc  = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM

function W([string]$rel, [string]$content) {
  $p = Join-Path $root $rel
  $d = Split-Path $p -Parent
  if (!(Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  if (-not $content.EndsWith("`n")) { $content += "`n" }
  [System.IO.File]::WriteAllText($p, $content, $enc)
  Write-Host "  wrote $rel"
}

Write-Host "`nOrbis360 builder - writing files...`n"

W 'package.json' @'
{
  "name": "orbis360",
  "version": "1.0.0",
  "private": true,
  "description": "Orbis360 - local 360 virtual tour platform for Insta360 X4 panoramas (Three.js + Leaflet + Express + SQLite).",
  "type": "module",
  "main": "server/app.js",
  "engines": { "node": ">=18.17" },
  "scripts": {
    "start": "node server/app.js",
    "dev": "node --watch server/app.js",
    "seed": "node scripts/seed.js",
    "reset": "node scripts/reset.js",
    "doctor": "node scripts/doctor.js",
    "check": "node scripts/check.js"
  },
  "dependencies": {
    "compression": "^1.7.4",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "leaflet": "1.9.4",
    "multer": "^2.0.1",
    "sharp": "^0.33.5",
    "sql.js": "^1.11.0",
    "three": "0.160.1"
  }
}
'@

W '.env.example' @'
# Orbis360 local configuration. Copy to .env (optional - these are the defaults).
PORT=3000
HOST=127.0.0.1
MAX_UPLOAD_MB=250
TEXTURE_MAX_WIDTH=12000
PREVIEW_MAX_WIDTH=4096
OPEN_BROWSER=0
'@

W '.gitignore' @'
node_modules/
data/*.db
data/*.db.tmp
storage/originals/*
storage/textures/*
storage/previews/*
storage/thumbs/*
storage/tmp/*
!storage/**/.gitkeep
.env
*.log
'@

W 'start.bat' @'
@echo off
setlocal enabledelayedexpansion
title Orbis360 - Local 360 Tour Platform
cd /d "%~dp0"

echo.
echo  ============================================================
echo   Orbis360  -  360 Virtual Tour Platform (local)
echo  ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo  [ERROR] Node.js was not found on this computer.
  echo.
  echo   Install the LTS version from https://nodejs.org/
  echo   Keep "Add to PATH" checked, close this window, run start.bat again.
  echo.
  pause
  exit /b 1
)

for /f "delims=" %%v in ('node -v') do set NODEVER=%%v
echo  [OK] Node.js !NODEVER! detected.

where npm >nul 2>nul
if errorlevel 1 (
  echo  [ERROR] npm was not found. Reinstall Node.js from https://nodejs.org/
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo.
  echo  [SETUP] Dependencies missing. Running npm install ...
  echo.
  call npm install
  if errorlevel 1 (
    echo.
    echo  [ERROR] npm install failed. Check your internet connection and retry.
    echo.
    pause
    exit /b 1
  )
)

if not exist ".env" if exist ".env.example" (
  copy /y ".env.example" ".env" >nul
  echo  [OK] Created .env from .env.example
)

if not exist "data" mkdir "data"
if not exist "storage\originals" mkdir "storage\originals"
if not exist "storage\textures" mkdir "storage\textures"
if not exist "storage\previews" mkdir "storage\previews"
if not exist "storage\thumbs" mkdir "storage\thumbs"
if not exist "storage\tmp" mkdir "storage\tmp"

echo.
echo  [CHECK] Verifying installation ...
call npm run doctor
if errorlevel 1 (
  echo.
  echo  [ERROR] Environment check failed. See the message above.
  pause
  exit /b 1
)

echo.
echo  [START] Launching Orbis360 ...
echo          Open http://localhost:3000
echo          Press Ctrl+C to stop.
echo.
call npm start

if errorlevel 1 (
  echo.
  echo  [ERROR] Server stopped with an error.
  echo   - Port 3000 in use? Change PORT in .env
  echo   - Run: npm run doctor
  echo.
)
pause
endlocal
'@

W 'server/config.js' @'
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(ROOT_DIR, '.env') });

const num = (v, d) => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : d;
};

export const config = {
  port: num(process.env.PORT, 3000),
  host: process.env.HOST || '127.0.0.1',
  maxUploadBytes: num(process.env.MAX_UPLOAD_MB, 250) * 1024 * 1024,
  textureMaxWidth: num(process.env.TEXTURE_MAX_WIDTH, 12000),
  previewMaxWidth: num(process.env.PREVIEW_MAX_WIDTH, 4096),
  thumbMaxWidth: 480,
  openBrowser: process.env.OPEN_BROWSER === '1',
  dirs: {
    root: ROOT_DIR,
    client: path.join(ROOT_DIR, 'client'),
    data: path.join(ROOT_DIR, 'data'),
    storage: path.join(ROOT_DIR, 'storage'),
    originals: path.join(ROOT_DIR, 'storage', 'originals'),
    textures: path.join(ROOT_DIR, 'storage', 'textures'),
    previews: path.join(ROOT_DIR, 'storage', 'previews'),
    thumbs: path.join(ROOT_DIR, 'storage', 'thumbs'),
    tmp: path.join(ROOT_DIR, 'storage', 'tmp')
  },
  dbFile: path.join(ROOT_DIR, 'data', 'orbis360.db'),
  nodeModules: path.join(ROOT_DIR, 'node_modules')
};

export function ensureDirs() {
  for (const dir of Object.values(config.dirs)) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }
}

export const ALLOWED_MIME = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/tiff']);
export const RATIO_TARGET = 2;
export const RATIO_TOLERANCE = 0.02;
export const RATIO_WARN = 0.12;
'@

W 'server/database/schema.sql' @'
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS assets (
  id             TEXT PRIMARY KEY,
  original_name  TEXT NOT NULL,
  mime           TEXT NOT NULL,
  bytes          INTEGER NOT NULL,
  width          INTEGER NOT NULL,
  height         INTEGER NOT NULL,
  ratio          REAL NOT NULL,
  format         TEXT,
  original_file  TEXT NOT NULL,
  texture_file   TEXT NOT NULL,
  preview_file   TEXT NOT NULL,
  thumb_file     TEXT NOT NULL,
  texture_width  INTEGER NOT NULL,
  texture_height INTEGER NOT NULL,
  preview_width  INTEGER NOT NULL,
  preview_height INTEGER NOT NULL,
  heading        REAL,
  gps_lat        REAL,
  gps_lng        REAL,
  projection     TEXT,
  forced         INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS tours (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  location    TEXT NOT NULL DEFAULT '',
  tags        TEXT NOT NULL DEFAULT '',
  color       TEXT NOT NULL DEFAULT '#3fd9ff',
  status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  cover_scene TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS scenes (
  id           TEXT PRIMARY KEY,
  tour_id      TEXT NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  asset_id     TEXT NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL DEFAULT '',
  lat          REAL,
  lng          REAL,
  heading      REAL NOT NULL DEFAULT 0,
  pitch        REAL NOT NULL DEFAULT 0,
  fov          REAL NOT NULL DEFAULT 75,
  north_offset REAL NOT NULL DEFAULT 0,
  position     INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS hotspots (
  id           TEXT PRIMARY KEY,
  scene_id     TEXT NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('nav','info')),
  yaw          REAL NOT NULL,
  pitch        REAL NOT NULL DEFAULT -12,
  label        TEXT NOT NULL DEFAULT '',
  body         TEXT NOT NULL DEFAULT '',
  target_scene TEXT REFERENCES scenes(id) ON DELETE CASCADE,
  image_url    TEXT NOT NULL DEFAULT '',
  link_url     TEXT NOT NULL DEFAULT '',
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_scenes_tour    ON scenes(tour_id, position);
CREATE INDEX IF NOT EXISTS idx_hotspots_scene ON hotspots(scene_id);
CREATE INDEX IF NOT EXISTS idx_hotspots_target ON hotspots(target_scene);
CREATE INDEX IF NOT EXISTS idx_tours_status   ON tours(status);
'@

W 'server/database/db.js' @'
/**
 * SQLite layer.
 *
 * Driver: sql.js (SQLite compiled to WebAssembly). Chosen deliberately over a
 * native driver so `npm install` succeeds on any Windows machine without
 * Visual Studio C++ Build Tools / node-gyp. The database is a real SQLite file
 * on disk (data/orbis360.db); every write is persisted atomically.
 *
 * Surface used by the controllers:
 *   db.exec(sql)
 *   db.prepare(sql).get(...)  -> row | undefined
 *   db.prepare(sql).all(...)  -> row[]
 *   db.prepare(sql).run(...)  -> { changes }
 *   db.transaction(fn)()      -> atomic + persisted
 *   db.persist()              -> force flush
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import initSqlJs from 'sql.js';
import { config, ensureDirs } from '../config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
ensureDirs();

const SQL = await initSqlJs({
  locateFile: (file) => path.join(config.nodeModules, 'sql.js', 'dist', file)
});

const raw = fs.existsSync(config.dbFile) ? fs.readFileSync(config.dbFile) : null;
const engine = raw && raw.length ? new SQL.Database(new Uint8Array(raw)) : new SQL.Database();

let persistTimer = null;
let dirty = false;

function normalize(value) {
  if (value === undefined) return null;
  if (typeof value === 'boolean') return value ? 1 : 0;
  if (value instanceof Date) return value.getTime();
  return value;
}

/** Bind positional (?) or named (@x / :x / $x) parameters. */
function bindParams(sql, params) {
  if (!params.length) return null;
  const first = params[0];
  const named =
    params.length === 1 && first !== null && typeof first === 'object' &&
    !Array.isArray(first) && !(first instanceof Uint8Array);

  if (!named) return params.map(normalize);

  const out = {};
  for (const [key, value] of Object.entries(first)) {
    const bare = key.replace(/^[@:$]/, '');
    let token = null;
    for (const prefix of ['@', ':', '$']) {
      if (new RegExp('\\' + prefix + bare + '\\b').test(sql)) { token = prefix + bare; break; }
    }
    if (token) out[token] = normalize(value);
  }
  return Object.keys(out).length ? out : null;
}

class Statement {
  constructor(sql) { this.sql = sql; }

  _exec(params, wantRows) {
    const stmt = engine.prepare(this.sql);
    try {
      const bound = bindParams(this.sql, params);
      if (bound) stmt.bind(bound);
      if (!wantRows) {
        stmt.step();
        return { changes: engine.getRowsModified() };
      }
      const rows = [];
      while (stmt.step()) rows.push(stmt.getAsObject());
      return rows;
    } finally {
      stmt.free();
    }
  }

  get(...params) {
    const rows = this._exec(params, true);
    return rows.length ? rows[0] : undefined;
  }

  all(...params) { return this._exec(params, true); }

  run(...params) {
    const result = this._exec(params, false);
    schedulePersist();
    return result;
  }
}

function schedulePersist() {
  dirty = true;
  if (persistTimer) return;
  persistTimer = setTimeout(() => {
    persistTimer = null;
    try { persist(); } catch (err) { console.error('[orbis360] persist failed:', err.message); }
  }, 120);
}

export function persist() {
  if (!dirty) return;
  const data = Buffer.from(engine.export());
  const tmp = config.dbFile + '.tmp';
  fs.writeFileSync(tmp, data);
  fs.renameSync(tmp, config.dbFile);
  dirty = false;
}

export const db = {
  engine,
  prepare(sql) { return new Statement(sql); },
  exec(sql) { engine.exec(sql); schedulePersist(); return this; },
  pragma(text) { try { engine.exec('PRAGMA ' + text); } catch { /* ignore */ } return this; },
  transaction(fn) {
    return (...args) => {
      engine.exec('BEGIN');
      try {
        const result = fn(...args);
        engine.exec('COMMIT');
        schedulePersist();
        return result;
      } catch (err) {
        try { engine.exec('ROLLBACK'); } catch { /* ignore */ }
        throw err;
      }
    };
  },
  persist,
  close() { persist(); engine.close(); }
};

export function initDatabase() {
  engine.exec(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
  db.pragma('foreign_keys = ON');
  dirty = true;
  persist();
  return db;
}

export const now = () => Date.now();
export const newId = (prefix = '') =>
  prefix + (globalThis.crypto?.randomUUID?.() ??
    `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`).replace(/-/g, '');
export const tx = (fn) => db.transaction(fn)();

let closing = false;
function shutdown() {
  if (closing) return;
  closing = true;
  try { persist(); } catch { /* ignore */ }
}
process.on('exit', shutdown);
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { shutdown(); process.exit(0); });
'@

W 'server/services/xmp.service.js' @'
/**
 * Insta360 / Google Photo Sphere metadata.
 *  GPano XMP -> PoseHeadingDegrees, ProjectionType, FullPanoWidthPixels
 *  EXIF APP1 -> GPS latitude / longitude
 * Malformed metadata never throws.
 */
export function readXmp(buffer) {
  const out = { heading: null, projection: null, fullWidth: null };
  try {
    const text = buffer.subarray(0, Math.min(buffer.length, 512 * 1024)).toString('latin1');
    const grab = (tag) => {
      const m = text.match(new RegExp('GPano:' + tag + '(?:="([^"]+)"|>\\s*([^<]+)<)'));
      return m ? (m[1] ?? m[2]).trim() : null;
    };
    const h = Number.parseFloat(grab('PoseHeadingDegrees'));
    if (Number.isFinite(h)) out.heading = ((h % 360) + 360) % 360;
    out.projection = grab('ProjectionType');
    const fw = Number.parseInt(grab('FullPanoWidthPixels'), 10);
    if (Number.isFinite(fw)) out.fullWidth = fw;
  } catch { /* ignore */ }
  return out;
}

export function readGps(buffer) {
  try {
    const dv = new DataView(buffer.buffer, buffer.byteOffset, buffer.byteLength);
    if (dv.getUint16(0) !== 0xFFD8) return null;
    let off = 2;
    while (off + 4 < dv.byteLength) {
      const marker = dv.getUint16(off);
      if ((marker & 0xFF00) !== 0xFF00) break;
      const size = dv.getUint16(off + 2);
      if (marker === 0xFFE1) {
        const start = off + 4;
        if (start + 10 >= dv.byteLength) return null;
        if (dv.getUint32(start) !== 0x45786966) { off += 2 + size; continue; }
        const t = start + 6;
        const little = dv.getUint16(t) === 0x4949;
        const u16 = (o) => dv.getUint16(t + o, little);
        const u32 = (o) => dv.getUint32(t + o, little);
        if (u16(2) !== 42) return null;
        const ifd0 = u32(4);
        if (!ifd0 || t + ifd0 >= dv.byteLength) return null;
        let gps = 0;
        const n = u16(ifd0);
        for (let i = 0; i < n; i++) {
          const e = ifd0 + 2 + i * 12;
          if (u16(e) === 0x8825) { gps = u32(e + 8); break; }
        }
        if (!gps || t + gps >= dv.byteLength) return null;
        const count = u16(gps);
        const sizes = { 1: 1, 2: 1, 3: 2, 4: 4, 5: 8 };
        let latRef = 'N', lngRef = 'E', lat = null, lng = null;
        const rational = (o) => { const a = u32(o), b = u32(o + 4); return b ? a / b : 0; };
        for (let i = 0; i < count; i++) {
          const e = gps + 2 + i * 12;
          if (t + e + 12 > dv.byteLength) break;
          const tag = u16(e), type = u16(e + 2), cnt = u32(e + 4);
          const vo = (sizes[type] || 1) * cnt <= 4 ? e + 8 : u32(e + 8);
          if (tag === 1) latRef = String.fromCharCode(dv.getUint8(t + vo));
          else if (tag === 3) lngRef = String.fromCharCode(dv.getUint8(t + vo));
          else if (tag === 2 && cnt === 3) lat = rational(vo) + rational(vo + 8) / 60 + rational(vo + 16) / 3600;
          else if (tag === 4 && cnt === 3) lng = rational(vo) + rational(vo + 8) / 60 + rational(vo + 16) / 3600;
        }
        if (lat == null || lng == null || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        if (lat === 0 && lng === 0) return null;
        return {
          lat: Number((latRef === 'S' ? -lat : lat).toFixed(6)),
          lng: Number((lngRef === 'W' ? -lng : lng).toFixed(6))
        };
      }
      if (marker === 0xFFDA) break;
      off += 2 + size;
    }
  } catch { /* ignore */ }
  return null;
}
'@

W 'server/services/geo.service.js' @'
const R = 6371000;
const rad = (d) => (d * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;

export function distanceMeters(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export function bearingDegrees(a, b) {
  const y = Math.sin(rad(b.lng - a.lng)) * Math.cos(rad(b.lat));
  const x = Math.cos(rad(a.lat)) * Math.sin(rad(b.lat)) -
    Math.sin(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.cos(rad(b.lng - a.lng));
  return ((deg(Math.atan2(y, x)) % 360) + 360) % 360;
}
'@

W 'server/services/storage.service.js' @'
import fs from 'node:fs/promises';
import path from 'node:path';
import { config } from '../config.js';

export const publicUrl = {
  original: (f) => `/uploads/originals/${f}`,
  texture: (f) => `/uploads/textures/${f}`,
  preview: (f) => `/uploads/previews/${f}`,
  thumb: (f) => `/uploads/thumbs/${f}`
};

export async function removeAssetFiles(asset) {
  const targets = [
    path.join(config.dirs.originals, asset.original_file),
    path.join(config.dirs.textures, asset.texture_file),
    path.join(config.dirs.previews, asset.preview_file),
    path.join(config.dirs.thumbs, asset.thumb_file)
  ];
  await Promise.all(targets.map((f) => fs.rm(f, { force: true }).catch(() => {})));
}

export async function emptyStorage() {
  for (const dir of [config.dirs.originals, config.dirs.textures, config.dirs.previews, config.dirs.thumbs, config.dirs.tmp]) {
    await fs.rm(dir, { recursive: true, force: true }).catch(() => {});
    await fs.mkdir(dir, { recursive: true });
  }
}
'@

W 'server/services/image.service.js' @'
import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import { config, RATIO_TARGET, RATIO_TOLERANCE, RATIO_WARN } from '../config.js';
import { readXmp, readGps } from './xmp.service.js';

sharp.cache(false);
sharp.concurrency(1);

export class ValidationError extends Error {
  constructor(message, code = 'VALIDATION', details = {}) {
    super(message);
    this.name = 'ValidationError';
    this.status = 400;
    this.code = code;
    this.details = details;
  }
}

export async function inspect(filePath) {
  let meta;
  try {
    meta = await sharp(filePath, { limitInputPixels: false }).metadata();
  } catch (err) {
    throw new ValidationError('This file could not be decoded as an image.', 'DECODE', { reason: err.message });
  }
  const width = meta.width || 0;
  const height = meta.height || 0;
  if (!width || !height) throw new ValidationError('Image dimensions could not be read.', 'DECODE');

  const ratio = width / height;
  const deviation = Math.abs(ratio - RATIO_TARGET);
  const buffer = await fs.readFile(filePath);
  const xmp = readXmp(buffer);
  const gps = readGps(buffer);

  return {
    width, height, ratio,
    format: meta.format || 'unknown',
    bytes: buffer.length,
    hasAlpha: !!meta.hasAlpha,
    xmp, gps,
    isEquirectangular: deviation <= RATIO_TOLERANCE,
    isAcceptable: deviation <= RATIO_WARN
  };
}

/** GPU texture + fast preview + thumbnail. The original is kept untouched. */
export async function processPanorama({ filePath, id, force = false }) {
  const info = await inspect(filePath);

  if (!info.isAcceptable && !force) {
    throw new ValidationError(
      `This image is ${info.width}x${info.height} (ratio ${info.ratio.toFixed(2)}:1). ` +
      'A 360 equirectangular panorama must be 2:1. Ordinary photos are not stretched into panoramas.',
      'RATIO',
      { width: info.width, height: info.height, ratio: Number(info.ratio.toFixed(4)) }
    );
  }

  const ext = info.format === 'png' ? 'png'
    : info.format === 'webp' ? 'webp'
    : info.format === 'tiff' ? 'tif' : 'jpg';

  const originalFile = `${id}.${ext}`;
  const derivative = `${id}.jpg`;

  await fs.copyFile(filePath, path.join(config.dirs.originals, originalFile));

  const make = async (maxWidth, quality, dest) => {
    const target = Math.min(maxWidth, info.width);
    const out = await sharp(filePath, { limitInputPixels: false })
      .rotate()
      .resize({ width: target, withoutEnlargement: true, fit: 'inside' })
      .jpeg({ quality, progressive: true, chromaSubsampling: '4:4:4' })
      .toFile(dest);
    return { width: out.width, height: out.height };
  };

  const texture = await make(config.textureMaxWidth, 95, path.join(config.dirs.textures, derivative));
  const preview = await make(config.previewMaxWidth, 88, path.join(config.dirs.previews, derivative));
  await make(config.thumbMaxWidth, 72, path.join(config.dirs.thumbs, derivative));

  return {
    info,
    originalFile,
    textureFile: derivative,
    previewFile: derivative,
    thumbFile: derivative,
    textureWidth: texture.width,
    textureHeight: texture.height,
    previewWidth: preview.width,
    previewHeight: preview.height
  };
}
'@

W 'server/middleware/validate.js' @'
export const clampNum = (v, min, max, fallback) => {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
};

export const str = (v, max = 4000) => (v === undefined || v === null ? '' : String(v).slice(0, max));

export function httpError(status, code, message, details) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  err.details = details;
  return err;
}
'@

W 'server/middleware/error.js' @'
import multer from 'multer';
import { config } from '../config.js';

export function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `No route for ${req.method} ${req.originalUrl}` } });
}

export function errorHandler(err, req, res, _next) {
  let status = err.status || err.statusCode || 500;
  let code = err.code || 'INTERNAL';
  let message = err.message || 'Unexpected server error';
  const details = err.details;

  if (err instanceof multer.MulterError) {
    status = 400;
    code = 'UPLOAD_' + err.code;
    if (err.code === 'LIMIT_FILE_SIZE') {
      message = `File is larger than the ${Math.round(config.maxUploadBytes / 1024 / 1024)} MB limit.`;
    }
  }
  if (status >= 500) console.error('[orbis360]', err);
  res.status(status).json({ error: { code, message, details } });
}

export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
'@

W 'server/middleware/upload.js' @'
import fs from 'node:fs';
import multer from 'multer';
import { config, ALLOWED_MIME } from '../config.js';

fs.mkdirSync(config.dirs.tmp, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, config.dirs.tmp),
  filename: (_req, file, cb) => {
    const safe = String(file.originalname || 'upload').replace(/[^\w.\-]+/g, '_').slice(-80);
    cb(null, `${Date.now()}_${Math.random().toString(36).slice(2, 8)}_${safe}`);
  }
});

function fileFilter(_req, file, cb) {
  const okMime = ALLOWED_MIME.has(String(file.mimetype).toLowerCase());
  const okExt = /\.(jpe?g|png|webp|tiff?)$/i.test(file.originalname || '');
  if (!okMime && !okExt) {
    const err = new Error('Unsupported file type. Upload JPG, JPEG, PNG, WebP or TIFF panoramas.');
    err.status = 400;
    err.code = 'MIME';
    return cb(err);
  }
  cb(null, true);
}

export const uploadPanoramas = multer({
  storage,
  fileFilter,
  limits: { fileSize: config.maxUploadBytes, files: 20 }
});
'@

W 'server/controllers/assets.controller.js' @'
import fs from 'node:fs/promises';
import { db, newId, now } from '../database/db.js';
import { config } from '../config.js';
import { processPanorama, ValidationError } from '../services/image.service.js';
import { publicUrl, removeAssetFiles } from '../services/storage.service.js';
import { httpError } from '../middleware/validate.js';

export function serializeAsset(row) {
  if (!row) return null;
  return {
    id: row.id,
    originalName: row.original_name,
    mime: row.mime,
    bytes: row.bytes,
    width: row.width,
    height: row.height,
    ratio: row.ratio,
    format: row.format,
    megapixels: Number(((row.width * row.height) / 1e6).toFixed(1)),
    heading: row.heading,
    projection: row.projection,
    gps: row.gps_lat != null && row.gps_lng != null ? { lat: row.gps_lat, lng: row.gps_lng } : null,
    forced: !!row.forced,
    isEquirectangular: Math.abs(row.ratio - 2) <= 0.02,
    texture: { width: row.texture_width, height: row.texture_height, url: publicUrl.texture(row.texture_file) },
    preview: { width: row.preview_width, height: row.preview_height, url: publicUrl.preview(row.preview_file) },
    thumbUrl: publicUrl.thumb(row.thumb_file),
    originalUrl: publicUrl.original(row.original_file),
    createdAt: row.created_at
  };
}

export const getAssetRow = (id) => db.prepare('SELECT * FROM assets WHERE id = ?').get(id);

export async function upload(req, res) {
  const files = req.files || [];
  if (!files.length) throw httpError(400, 'NO_FILES', 'No files were received. Use the "panoramas" field.');

  const force = req.body?.force === '1' || req.body?.force === 'true';
  const results = [];

  for (const file of files) {
    const id = newId('a_');
    try {
      const p = await processPanorama({ filePath: file.path, id, force });
      const info = p.info;
      db.prepare(`INSERT INTO assets (
        id, original_name, mime, bytes, width, height, ratio, format,
        original_file, texture_file, preview_file, thumb_file,
        texture_width, texture_height, preview_width, preview_height,
        heading, gps_lat, gps_lng, projection, forced, created_at
      ) VALUES (
        @id, @original_name, @mime, @bytes, @width, @height, @ratio, @format,
        @original_file, @texture_file, @preview_file, @thumb_file,
        @texture_width, @texture_height, @preview_width, @preview_height,
        @heading, @gps_lat, @gps_lng, @projection, @forced, @created_at
      )`).run({
        id,
        original_name: file.originalname,
        mime: file.mimetype,
        bytes: info.bytes,
        width: info.width,
        height: info.height,
        ratio: Number(info.ratio.toFixed(6)),
        format: info.format,
        original_file: p.originalFile,
        texture_file: p.textureFile,
        preview_file: p.previewFile,
        thumb_file: p.thumbFile,
        texture_width: p.textureWidth,
        texture_height: p.textureHeight,
        preview_width: p.previewWidth,
        preview_height: p.previewHeight,
        heading: info.xmp.heading,
        gps_lat: info.gps?.lat ?? null,
        gps_lng: info.gps?.lng ?? null,
        projection: info.xmp.projection,
        forced: force && !info.isEquirectangular ? 1 : 0,
        created_at: now()
      });
      results.push({ ok: true, fileName: file.originalname, asset: serializeAsset(getAssetRow(id)) });
    } catch (err) {
      results.push({
        ok: false,
        fileName: file.originalname,
        error: {
          code: err.code || 'PROCESS',
          message: err.message,
          details: err.details || null,
          canForce: err instanceof ValidationError && err.code === 'RATIO'
        }
      });
    } finally {
      await fs.rm(file.path, { force: true }).catch(() => {});
    }
  }

  const created = results.filter((r) => r.ok).length;
  res.status(created ? 201 : 400).json({
    created,
    failed: results.length - created,
    maxUploadMb: Math.round(config.maxUploadBytes / 1024 / 1024),
    results
  });
}

export function list(_req, res) {
  const rows = db.prepare('SELECT * FROM assets ORDER BY created_at DESC').all();
  const used = new Set(db.prepare('SELECT DISTINCT asset_id FROM scenes').all().map((r) => r.asset_id));
  res.json({ assets: rows.map((r) => ({ ...serializeAsset(r), inUse: used.has(r.id) })) });
}

export function getOne(req, res) {
  const row = getAssetRow(req.params.id);
  if (!row) throw httpError(404, 'ASSET_NOT_FOUND', 'Asset not found.');
  res.json({ asset: serializeAsset(row) });
}

export async function remove(req, res) {
  const row = getAssetRow(req.params.id);
  if (!row) throw httpError(404, 'ASSET_NOT_FOUND', 'Asset not found.');
  const used = db.prepare('SELECT COUNT(*) AS n FROM scenes WHERE asset_id = ?').get(row.id).n;
  if (used) throw httpError(409, 'ASSET_IN_USE', `This image is used by ${used} scene(s). Delete those scenes first.`);
  db.prepare('DELETE FROM assets WHERE id = ?').run(row.id);
  await removeAssetFiles(row);
  res.json({ deleted: row.id });
}
'@

W 'server/controllers/hotspots.controller.js' @'
import { db, newId, now } from '../database/db.js';
import { clampNum, str, httpError } from '../middleware/validate.js';

export function serializeHotspot(row) {
  return {
    id: row.id,
    sceneId: row.scene_id,
    type: row.type,
    yaw: row.yaw,
    pitch: row.pitch,
    label: row.label,
    body: row.body,
    targetScene: row.target_scene,
    imageUrl: row.image_url,
    linkUrl: row.link_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

const getRow = (id) => db.prepare('SELECT * FROM hotspots WHERE id = ?').get(id);
const sceneExists = (id) => !!db.prepare('SELECT id FROM scenes WHERE id = ?').get(id);

function validatePayload(body, partial = false) {
  const out = {};
  if (!partial || body.type !== undefined) {
    if (!['nav', 'info'].includes(body.type)) throw httpError(400, 'HOTSPOT_TYPE', 'type must be "nav" or "info".');
    out.type = body.type;
  }
  if (!partial || body.yaw !== undefined) out.yaw = clampNum(body.yaw, -360, 720, 0);
  if (!partial || body.pitch !== undefined) out.pitch = clampNum(body.pitch, -89, 89, -12);
  if (body.label !== undefined) out.label = str(body.label, 160);
  if (body.body !== undefined) out.body = str(body.body, 4000);
  if (body.imageUrl !== undefined) out.image_url = str(body.imageUrl, 1000);
  if (body.linkUrl !== undefined) out.link_url = str(body.linkUrl, 1000);
  if (body.targetScene !== undefined) out.target_scene = body.targetScene || null;
  return out;
}

export function listForScene(req, res) {
  const sceneId = req.query.sceneId;
  if (!sceneId) throw httpError(400, 'MISSING_SCENE', 'sceneId query parameter is required.');
  const rows = db.prepare('SELECT * FROM hotspots WHERE scene_id = ? ORDER BY created_at').all(sceneId);
  res.json({ hotspots: rows.map(serializeHotspot) });
}

export function create(req, res) {
  const { sceneId } = req.body || {};
  if (!sceneId || !sceneExists(sceneId)) throw httpError(400, 'SCENE_NOT_FOUND', 'A valid sceneId is required.');
  const data = validatePayload(req.body, false);

  if (data.type === 'nav') {
    if (!data.target_scene) throw httpError(400, 'NAV_TARGET', 'Navigation hotspots need a targetScene.');
    if (!sceneExists(data.target_scene)) throw httpError(400, 'NAV_TARGET', 'Target scene does not exist.');
    if (data.target_scene === sceneId) throw httpError(400, 'NAV_SELF', 'A scene cannot link to itself.');
  } else {
    data.target_scene = null;
  }

  const id = newId('h_');
  const t = now();
  db.prepare(`INSERT INTO hotspots (id, scene_id, type, yaw, pitch, label, body, target_scene, image_url, link_url, created_at, updated_at)
              VALUES (@id, @scene_id, @type, @yaw, @pitch, @label, @body, @target_scene, @image_url, @link_url, @created_at, @updated_at)`)
    .run({
      id, scene_id: sceneId, type: data.type, yaw: data.yaw, pitch: data.pitch,
      label: data.label ?? '', body: data.body ?? '', target_scene: data.target_scene ?? null,
      image_url: data.image_url ?? '', link_url: data.link_url ?? '', created_at: t, updated_at: t
    });
  res.status(201).json({ hotspot: serializeHotspot(getRow(id)) });
}

export function update(req, res) {
  const row = getRow(req.params.id);
  if (!row) throw httpError(404, 'HOTSPOT_NOT_FOUND', 'Hotspot not found.');
  const next = { ...row, ...validatePayload(req.body || {}, true), updated_at: now() };

  if (next.type === 'nav') {
    if (!next.target_scene) throw httpError(400, 'NAV_TARGET', 'Navigation hotspots need a targetScene.');
    if (!sceneExists(next.target_scene)) throw httpError(400, 'NAV_TARGET', 'Target scene does not exist.');
    if (next.target_scene === row.scene_id) throw httpError(400, 'NAV_SELF', 'A scene cannot link to itself.');
  } else {
    next.target_scene = null;
  }

  db.prepare(`UPDATE hotspots SET type=@type, yaw=@yaw, pitch=@pitch, label=@label, body=@body,
              target_scene=@target_scene, image_url=@image_url, link_url=@link_url, updated_at=@updated_at WHERE id=@id`)
    .run(next);
  res.json({ hotspot: serializeHotspot(getRow(row.id)) });
}

export function remove(req, res) {
  const row = getRow(req.params.id);
  if (!row) throw httpError(404, 'HOTSPOT_NOT_FOUND', 'Hotspot not found.');
  db.prepare('DELETE FROM hotspots WHERE id = ?').run(row.id);
  res.json({ deleted: row.id });
}
'@

W 'server/controllers/scenes.controller.js' @'
import { db, newId, now, tx } from '../database/db.js';
import { clampNum, str, httpError } from '../middleware/validate.js';
import { serializeAsset, getAssetRow } from './assets.controller.js';
import { serializeHotspot } from './hotspots.controller.js';
import { distanceMeters, bearingDegrees } from '../services/geo.service.js';

export function serializeScene(row, { withHotspots = true } = {}) {
  if (!row) return null;
  const asset = serializeAsset(getAssetRow(row.asset_id));
  const hotspots = withHotspots
    ? db.prepare('SELECT * FROM hotspots WHERE scene_id = ? ORDER BY created_at').all(row.id).map(serializeHotspot)
    : [];
  return {
    id: row.id,
    tourId: row.tour_id,
    assetId: row.asset_id,
    title: row.title,
    description: row.description,
    lat: row.lat,
    lng: row.lng,
    heading: row.heading,
    pitch: row.pitch,
    fov: row.fov,
    northOffset: row.north_offset,
    position: row.position,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    asset,
    hotspots
  };
}

export const getSceneRow = (id) => db.prepare('SELECT * FROM scenes WHERE id = ?').get(id);
const tourExists = (id) => !!db.prepare('SELECT id FROM tours WHERE id = ?').get(id);

function nextPosition(tourId) {
  return db.prepare('SELECT COALESCE(MAX(position), -1) AS p FROM scenes WHERE tour_id = ?').get(tourId).p + 1;
}

export function listByTour(req, res) {
  const rows = db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position, created_at').all(req.params.id);
  res.json({ scenes: rows.map((r) => serializeScene(r)) });
}

export function getOne(req, res) {
  const row = getSceneRow(req.params.id);
  if (!row) throw httpError(404, 'SCENE_NOT_FOUND', 'Scene not found.');
  res.json({ scene: serializeScene(row) });
}

export function create(req, res) {
  const b = req.body || {};
  if (!b.tourId || !tourExists(b.tourId)) throw httpError(400, 'TOUR_NOT_FOUND', 'A valid tourId is required.');
  const asset = getAssetRow(b.assetId);
  if (!asset) throw httpError(400, 'ASSET_NOT_FOUND', 'A valid assetId is required. Upload the panorama first.');

  const heading = clampNum(b.heading ?? asset.heading ?? 0, -360, 720, 0);
  const id = newId('s_');
  const t = now();
  db.prepare(`INSERT INTO scenes (id, tour_id, asset_id, title, description, lat, lng, heading, pitch, fov, north_offset, position, created_at, updated_at)
              VALUES (@id,@tour_id,@asset_id,@title,@description,@lat,@lng,@heading,@pitch,@fov,@north_offset,@position,@created_at,@updated_at)`)
    .run({
      id,
      tour_id: b.tourId,
      asset_id: asset.id,
      title: str(b.title, 160) || asset.original_name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() || 'Untitled scene',
      description: str(b.description, 4000),
      lat: b.lat != null && b.lat !== '' ? clampNum(b.lat, -90, 90, null) : asset.gps_lat,
      lng: b.lng != null && b.lng !== '' ? clampNum(b.lng, -180, 180, null) : asset.gps_lng,
      heading,
      pitch: clampNum(b.pitch, -89, 89, 0),
      fov: clampNum(b.fov, 30, 100, 75),
      north_offset: ((0.75 - heading / 360) % 1 + 1) % 1,
      position: Number.isFinite(Number(b.position)) ? Number(b.position) : nextPosition(b.tourId),
      created_at: t,
      updated_at: t
    });
  db.prepare('UPDATE tours SET updated_at = ? WHERE id = ?').run(t, b.tourId);
  res.status(201).json({ scene: serializeScene(getSceneRow(id)) });
}

export function update(req, res) {
  const row = getSceneRow(req.params.id);
  if (!row) throw httpError(404, 'SCENE_NOT_FOUND', 'Scene not found.');
  const b = req.body || {};
  const next = { ...row, updated_at: now() };

  if (b.title !== undefined) next.title = str(b.title, 160) || row.title;
  if (b.description !== undefined) next.description = str(b.description, 4000);
  if (b.lat !== undefined) next.lat = b.lat === null || b.lat === '' ? null : clampNum(b.lat, -90, 90, null);
  if (b.lng !== undefined) next.lng = b.lng === null || b.lng === '' ? null : clampNum(b.lng, -180, 180, null);
  if (b.pitch !== undefined) next.pitch = clampNum(b.pitch, -89, 89, row.pitch);
  if (b.fov !== undefined) next.fov = clampNum(b.fov, 30, 100, row.fov);
  if (b.heading !== undefined) {
    next.heading = clampNum(b.heading, -360, 720, row.heading);
    next.north_offset = ((0.75 - next.heading / 360) % 1 + 1) % 1;
  }
  if (b.tourId !== undefined && b.tourId !== row.tour_id) {
    if (!tourExists(b.tourId)) throw httpError(400, 'TOUR_NOT_FOUND', 'Target tour does not exist.');
    next.tour_id = b.tourId;
    next.position = nextPosition(b.tourId);
    const keep = new Set(db.prepare('SELECT id FROM scenes WHERE tour_id = ?').all(b.tourId).map((r) => r.id));
    for (const h of db.prepare("SELECT * FROM hotspots WHERE scene_id = ? AND type = 'nav'").all(row.id)) {
      if (!keep.has(h.target_scene)) db.prepare('DELETE FROM hotspots WHERE id = ?').run(h.id);
    }
    db.prepare('DELETE FROM hotspots WHERE target_scene = ? AND scene_id NOT IN (SELECT id FROM scenes WHERE tour_id = ?)')
      .run(row.id, b.tourId);
  }

  db.prepare(`UPDATE scenes SET tour_id=@tour_id, title=@title, description=@description, lat=@lat, lng=@lng,
              heading=@heading, pitch=@pitch, fov=@fov, north_offset=@north_offset, position=@position, updated_at=@updated_at
              WHERE id=@id`).run(next);
  db.prepare('UPDATE tours SET updated_at = ? WHERE id IN (?, ?)').run(now(), row.tour_id, next.tour_id);
  res.json({ scene: serializeScene(getSceneRow(row.id)) });
}

export function remove(req, res) {
  const row = getSceneRow(req.params.id);
  if (!row) throw httpError(404, 'SCENE_NOT_FOUND', 'Scene not found.');
  tx(() => {
    db.prepare('DELETE FROM hotspots WHERE target_scene = ?').run(row.id);
    db.prepare('DELETE FROM scenes WHERE id = ?').run(row.id);
    const t = db.prepare('SELECT cover_scene FROM tours WHERE id = ?').get(row.tour_id);
    if (t?.cover_scene === row.id) {
      const first = db.prepare('SELECT id FROM scenes WHERE tour_id = ? ORDER BY position LIMIT 1').get(row.tour_id);
      db.prepare('UPDATE tours SET cover_scene = ?, updated_at = ? WHERE id = ?').run(first?.id ?? null, now(), row.tour_id);
    }
    db.prepare('UPDATE tours SET updated_at = ? WHERE id = ?').run(now(), row.tour_id);
  });
  res.json({ deleted: row.id, assetId: row.asset_id });
}

export function reorder(req, res) {
  const tourId = req.params.id;
  if (!tourExists(tourId)) throw httpError(404, 'TOUR_NOT_FOUND', 'Tour not found.');
  const order = Array.isArray(req.body?.order) ? req.body.order : null;
  if (!order) throw httpError(400, 'ORDER', 'Body must contain an "order" array of scene ids.');
  const rows = db.prepare('SELECT id FROM scenes WHERE tour_id = ?').all(tourId);
  const valid = new Set(rows.map((r) => r.id));
  if (order.length !== rows.length || order.some((id) => !valid.has(id))) {
    throw httpError(400, 'ORDER', 'The order array must contain every scene id of this tour exactly once.');
  }
  tx(() => {
    const stmt = db.prepare('UPDATE scenes SET position = ?, updated_at = ? WHERE id = ?');
    order.forEach((id, i) => stmt.run(i, now(), id));
    db.prepare('UPDATE tours SET updated_at = ? WHERE id = ?').run(now(), tourId);
  });
  res.json({ scenes: db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position').all(tourId).map((r) => serializeScene(r)) });
}

export function autoLink(req, res) {
  const tourId = req.params.id;
  if (!tourExists(tourId)) throw httpError(404, 'TOUR_NOT_FOUND', 'Tour not found.');
  const maxDistance = clampNum(req.body?.maxDistance, 5, 5000, 200);
  const scenes = db.prepare('SELECT * FROM scenes WHERE tour_id = ? AND lat IS NOT NULL AND lng IS NOT NULL').all(tourId);
  const hasLink = (from, to) =>
    !!db.prepare("SELECT id FROM hotspots WHERE scene_id = ? AND type = 'nav' AND target_scene = ?").get(from, to);
  let pairs = 0;

  tx(() => {
    for (let i = 0; i < scenes.length; i++) {
      for (let j = i + 1; j < scenes.length; j++) {
        const a = scenes[i], b = scenes[j];
        if (distanceMeters(a, b) > maxDistance) continue;
        let added = false;
        const mk = (from, to) => {
          if (hasLink(from.id, to.id)) return;
          const t = now();
          db.prepare(`INSERT INTO hotspots (id, scene_id, type, yaw, pitch, label, body, target_scene, image_url, link_url, created_at, updated_at)
                      VALUES (?, ?, 'nav', ?, -12, ?, '', ?, '', '', ?, ?)`)
            .run(newId('h_'), from.id, Number(bearingDegrees(from, to).toFixed(1)), to.title, to.id, t, t);
          added = true;
        };
        mk(a, b); mk(b, a);
        if (added) pairs++;
      }
    }
    db.prepare('UPDATE tours SET updated_at = ? WHERE id = ?').run(now(), tourId);
  });

  res.json({
    pairs, maxDistance, located: scenes.length,
    scenes: db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position').all(tourId).map((r) => serializeScene(r))
  });
}
'@

W 'server/controllers/tours.controller.js' @'
import { db, newId, now, tx } from '../database/db.js';
import { str, httpError } from '../middleware/validate.js';
import { serializeScene, getSceneRow } from './scenes.controller.js';
import { serializeAsset, getAssetRow } from './assets.controller.js';
import { removeAssetFiles } from '../services/storage.service.js';

const COLORS = ['#3fd9ff', '#ff7ac2', '#ffb454', '#2fe6b0', '#6ea8ff', '#ff5d73'];

export function serializeTour(row, extra = {}) {
  const sceneCount = db.prepare('SELECT COUNT(*) AS n FROM scenes WHERE tour_id = ?').get(row.id).n;
  const arrows = db.prepare(`SELECT COUNT(*) AS n FROM hotspots h
                             JOIN scenes s ON s.id = h.scene_id
                             WHERE s.tour_id = ? AND h.type = 'nav'`).get(row.id).n;
  let coverThumb = null;
  if (row.cover_scene) {
    const sc = getSceneRow(row.cover_scene);
    if (sc) coverThumb = serializeAsset(getAssetRow(sc.asset_id))?.thumbUrl ?? null;
  }
  if (!coverThumb) {
    const first = db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position LIMIT 1').get(row.id);
    if (first) coverThumb = serializeAsset(getAssetRow(first.asset_id))?.thumbUrl ?? null;
  }
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    location: row.location,
    tags: row.tags ? row.tags.split(',').map((t) => t.trim()).filter(Boolean) : [],
    color: row.color,
    status: row.status,
    coverScene: row.cover_scene,
    coverThumb,
    sceneCount,
    arrowCount: arrows,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    ...extra
  };
}

const getRow = (id) => db.prepare('SELECT * FROM tours WHERE id = ?').get(id);

export function list(req, res) {
  const { q = '', status = 'all', sort = 'updated' } = req.query;
  let sql = 'SELECT * FROM tours';
  const where = [];
  const params = {};
  if (status === 'draft' || status === 'published') { where.push('status = @status'); params.status = status; }
  if (q) {
    where.push('(LOWER(title) LIKE @q OR LOWER(description) LIKE @q OR LOWER(location) LIKE @q OR LOWER(tags) LIKE @q)');
    params.q = `%${String(q).toLowerCase()}%`;
  }
  if (where.length) sql += ' WHERE ' + where.join(' AND ');
  sql += sort === 'title' ? ' ORDER BY title COLLATE NOCASE ASC'
    : sort === 'created' ? ' ORDER BY created_at DESC'
    : ' ORDER BY updated_at DESC';
  let tours = db.prepare(sql).all(params).map((r) => serializeTour(r));
  if (sort === 'scenes') tours.sort((a, b) => b.sceneCount - a.sceneCount);
  res.json({ tours, total: tours.length });
}

export function getOne(req, res) {
  const row = getRow(req.params.id);
  if (!row) throw httpError(404, 'TOUR_NOT_FOUND', 'Tour not found.');
  const scenes = db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position, created_at').all(row.id);
  res.json({ tour: serializeTour(row, { scenes: scenes.map((s) => serializeScene(s)) }) });
}

export function create(req, res) {
  const b = req.body || {};
  const title = str(b.title, 160).trim();
  if (!title) throw httpError(400, 'TITLE', 'A tour title is required.');
  const id = newId('t_');
  const t = now();
  db.prepare(`INSERT INTO tours (id,title,description,location,tags,color,status,cover_scene,sort_order,created_at,updated_at)
              VALUES (@id,@title,@description,@location,@tags,@color,'draft',NULL,0,@created_at,@updated_at)`)
    .run({
      id, title,
      description: str(b.description, 4000),
      location: str(b.location, 160),
      tags: Array.isArray(b.tags) ? b.tags.join(',').slice(0, 400) : str(b.tags, 400),
      color: COLORS.includes(b.color) ? b.color : COLORS[0],
      created_at: t, updated_at: t
    });
  res.status(201).json({ tour: serializeTour(getRow(id)) });
}

export function update(req, res) {
  const row = getRow(req.params.id);
  if (!row) throw httpError(404, 'TOUR_NOT_FOUND', 'Tour not found.');
  const b = req.body || {};
  const next = { ...row, updated_at: now() };

  if (b.title !== undefined) {
    const v = str(b.title, 160).trim();
    if (!v) throw httpError(400, 'TITLE', 'Tour title cannot be empty.');
    next.title = v;
  }
  if (b.description !== undefined) next.description = str(b.description, 4000);
  if (b.location !== undefined) next.location = str(b.location, 160);
  if (b.tags !== undefined) next.tags = Array.isArray(b.tags) ? b.tags.join(',').slice(0, 400) : str(b.tags, 400);
  if (b.color !== undefined && COLORS.includes(b.color)) next.color = b.color;
  if (b.status !== undefined) {
    if (!['draft', 'published'].includes(b.status)) throw httpError(400, 'STATUS', 'status must be draft or published.');
    if (b.status === 'published' && !db.prepare('SELECT COUNT(*) AS n FROM scenes WHERE tour_id = ?').get(row.id).n) {
      throw httpError(400, 'EMPTY_TOUR', 'Add at least one scene before publishing.');
    }
    next.status = b.status;
  }
  if (b.coverScene !== undefined) {
    if (b.coverScene === null || b.coverScene === '') next.cover_scene = null;
    else {
      const sc = getSceneRow(b.coverScene);
      if (!sc || sc.tour_id !== row.id) throw httpError(400, 'COVER', 'Cover scene must belong to this tour.');
      next.cover_scene = sc.id;
    }
  }

  db.prepare(`UPDATE tours SET title=@title, description=@description, location=@location, tags=@tags,
              color=@color, status=@status, cover_scene=@cover_scene, updated_at=@updated_at WHERE id=@id`).run(next);
  res.json({ tour: serializeTour(getRow(row.id)) });
}

export async function remove(req, res) {
  const row = getRow(req.params.id);
  if (!row) throw httpError(404, 'TOUR_NOT_FOUND', 'Tour not found.');
  const scenes = db.prepare('SELECT * FROM scenes WHERE tour_id = ?').all(row.id);
  const assetIds = [...new Set(scenes.map((s) => s.asset_id))];
  const deleteFiles = req.query.deleteFiles === '1';

  tx(() => { db.prepare('DELETE FROM tours WHERE id = ?').run(row.id); });

  let assetsRemoved = 0;
  if (deleteFiles) {
    for (const aid of assetIds) {
      if (!db.prepare('SELECT COUNT(*) AS n FROM scenes WHERE asset_id = ?').get(aid).n) {
        const asset = getAssetRow(aid);
        if (asset) {
          db.prepare('DELETE FROM assets WHERE id = ?').run(aid);
          await removeAssetFiles(asset);
          assetsRemoved++;
        }
      }
    }
  }
  res.json({ deleted: row.id, scenesRemoved: scenes.length, assetsRemoved });
}

export function stats(_req, res) {
  const one = (sql) => db.prepare(sql).get().n;
  res.json({
    tours: one('SELECT COUNT(*) AS n FROM tours'),
    published: one("SELECT COUNT(*) AS n FROM tours WHERE status = 'published'"),
    scenes: one('SELECT COUNT(*) AS n FROM scenes'),
    hotspots: one('SELECT COUNT(*) AS n FROM hotspots'),
    assets: one('SELECT COUNT(*) AS n FROM assets'),
    bytes: one('SELECT COALESCE(SUM(bytes),0) AS n FROM assets')
  });
}
'@

W 'server/routes/tours.routes.js' @'
import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import * as tours from '../controllers/tours.controller.js';
import * as scenes from '../controllers/scenes.controller.js';

const router = Router();
router.get('/', asyncHandler(tours.list));
router.post('/', asyncHandler(tours.create));
router.get('/:id', asyncHandler(tours.getOne));
router.patch('/:id', asyncHandler(tours.update));
router.delete('/:id', asyncHandler(tours.remove));
router.get('/:id/scenes', asyncHandler(scenes.listByTour));
router.post('/:id/scenes/reorder', asyncHandler(scenes.reorder));
router.post('/:id/auto-link', asyncHandler(scenes.autoLink));
export default router;
'@

W 'server/routes/scenes.routes.js' @'
import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import * as scenes from '../controllers/scenes.controller.js';

const router = Router();
router.post('/', asyncHandler(scenes.create));
router.get('/:id', asyncHandler(scenes.getOne));
router.patch('/:id', asyncHandler(scenes.update));
router.delete('/:id', asyncHandler(scenes.remove));
export default router;
'@

W 'server/routes/hotspots.routes.js' @'
import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import * as hotspots from '../controllers/hotspots.controller.js';

const router = Router();
router.get('/', asyncHandler(hotspots.listForScene));
router.post('/', asyncHandler(hotspots.create));
router.patch('/:id', asyncHandler(hotspots.update));
router.delete('/:id', asyncHandler(hotspots.remove));
export default router;
'@

W 'server/routes/assets.routes.js' @'
import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import { uploadPanoramas } from '../middleware/upload.js';
import * as assets from '../controllers/assets.controller.js';

const router = Router();
router.get('/', asyncHandler(assets.list));
router.post('/', uploadPanoramas.array('panoramas', 20), asyncHandler(assets.upload));
router.get('/:id', asyncHandler(assets.getOne));
router.delete('/:id', asyncHandler(assets.remove));
export default router;
'@

W 'server/routes/index.js' @'
import { Router } from 'express';
import tours from './tours.routes.js';
import scenes from './scenes.routes.js';
import hotspots from './hotspots.routes.js';
import assets from './assets.routes.js';
import { stats } from '../controllers/tours.controller.js';
import { config } from '../config.js';
import { db } from '../database/db.js';

const router = Router();

router.get('/health', (_req, res) => {
  let dbOk = false;
  try { dbOk = !!db.prepare('SELECT 1 AS ok').get(); } catch { dbOk = false; }
  res.json({
    ok: true,
    database: dbOk ? 'sqlite (ready)' : 'error',
    storage: config.dirs.storage,
    maxUploadMb: Math.round(config.maxUploadBytes / 1024 / 1024),
    textureMaxWidth: config.textureMaxWidth,
    node: process.version,
    time: new Date().toISOString()
  });
});

router.get('/stats', stats);
router.use('/tours', tours);
router.use('/scenes', scenes);
router.use('/hotspots', hotspots);
router.use('/assets', assets);

export default router;
'@

W 'server/app.js' @'
import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import compression from 'compression';
import { config, ensureDirs } from './config.js';
import { initDatabase, persist } from './database/db.js';
import api from './routes/index.js';
import { errorHandler, notFound } from './middleware/error.js';

ensureDirs();
initDatabase();

const app = express();
app.disable('x-powered-by');
app.use(compression());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

app.use('/api', api);

app.use('/uploads', express.static(config.dirs.storage, { maxAge: '7d', fallthrough: true }));

// Libraries served from node_modules: the app needs no CDN and works offline.
app.use('/vendor/three', express.static(path.join(config.nodeModules, 'three'), { maxAge: '30d' }));
app.use('/vendor/leaflet', express.static(path.join(config.nodeModules, 'leaflet', 'dist'), { maxAge: '30d' }));

app.use(express.static(config.dirs.client, { extensions: ['html'] }));

app.get(/^\/(?!api|uploads|vendor).*/, (req, res, next) => {
  if (req.method !== 'GET') return next();
  const index = path.join(config.dirs.client, 'index.html');
  if (!fs.existsSync(index)) return next();
  res.sendFile(index);
});

app.use(notFound);
app.use(errorHandler);

const server = app.listen(config.port, config.host, () => {
  const url = `http://${config.host === '0.0.0.0' ? 'localhost' : config.host}:${config.port}`;
  console.log('');
  console.log('  Orbis360 is running.');
  console.log(`  Open ${url}`);
  console.log(`  Database : ${config.dbFile}`);
  console.log(`  Storage  : ${config.dirs.storage}`);
  console.log(`  Uploads  : max ${Math.round(config.maxUploadBytes / 1024 / 1024)} MB per file`);
  console.log('  Press Ctrl+C to stop.');
  console.log('');
  if (config.openBrowser) {
    const cmd = process.platform === 'win32' ? `start "" "${url}"`
      : process.platform === 'darwin' ? `open "${url}"` : `xdg-open "${url}"`;
    import('node:child_process').then(({ exec }) => exec(cmd, () => {})).catch(() => {});
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n[ERROR] Port ${config.port} is already in use.`);
    console.error('        Close the other program, or set a different PORT in .env\n');
  } else if (err.code === 'EACCES') {
    console.error(`\n[ERROR] Not allowed to bind port ${config.port}. Use a port above 1024.\n`);
  } else {
    console.error('\n[ERROR] Server failed to start:', err.message, '\n');
  }
  process.exit(1);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    console.log('\n  Saving database and shutting down...');
    try { persist(); } catch { /* ignore */ }
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 1500);
  });
}

export default app;
'@

# ============================================================================
# End of Block 1/6. 24 files written. Do NOT run the script yet.
# Append Block 2 below this line in the SAME build-orbis360.ps1 file.
# ============================================================================# ============================================================================
# Block 2/6 - client shell: index.html, logo.svg, main.css
# ============================================================================

W 'client/index.html' @'
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#070b14">
<title>Orbis360 — 360° Virtual Tour Studio</title>
<link rel="icon" href="/assets/icons/logo.svg" type="image/svg+xml">
<link rel="stylesheet" href="/vendor/leaflet/leaflet.css">
<link rel="stylesheet" href="/assets/css/main.css">
<script type="importmap">
{
  "imports": {
    "three": "/vendor/three/build/three.module.js"
  }
}
</script>
</head>
<body>
<nav class="nav" id="nav"></nav>
<main id="app"></main>
<div id="modal-root"></div>
<div id="toast-root" aria-live="polite"></div>

<div class="boot" id="boot">
  <div class="boot-inner">
    <div class="boot-logo">
      <svg class="ring" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <ellipse cx="12" cy="12" rx="10" ry="4.4" stroke="#2fe6b0" stroke-width="1.4" transform="rotate(-24 12 12)"/>
        <circle cx="20.4" cy="7.6" r="1.6" fill="#ffb454"/>
      </svg>
      <svg viewBox="0 0 24 24" style="position:absolute;inset:0" aria-hidden="true">
        <circle cx="12" cy="12" r="4.6" fill="#3fd9ff"/>
      </svg>
    </div>
    <h2 class="disp">Orbis<span class="grad-text">360</span></h2>
    <p class="bp" id="boot-status">Connecting to the local server…</p>
    <div class="boot-bar"><i id="boot-bar"></i></div>
    <p class="boot-tip" id="boot-tip">Everything runs on your computer. No cloud, no account.</p>
  </div>
</div>

<noscript>
  <div style="padding:100px 24px;text-align:center;color:#e9eefb;font-family:system-ui">
    <h1>JavaScript is required</h1>
    <p>Orbis360 is a WebGL application. Enable JavaScript and reload.</p>
  </div>
</noscript>

<script src="/vendor/leaflet/leaflet.js"></script>
<script src="/assets/js/orbis360-motion-vr.js"></script>
<script type="module" src="/assets/js/app.js"></script>
</body>
</html>
'@

W 'client/assets/icons/logo.svg' @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="12" r="4.6" fill="#3fd9ff"/>
  <ellipse cx="12" cy="12" rx="10" ry="4.4" stroke="#2fe6b0" stroke-width="1.6" transform="rotate(-24 12 12)"/>
  <circle cx="20.4" cy="7.6" r="1.7" fill="#ffb454"/>
</svg>
'@

W 'client/assets/css/main.css' @'
/* ==========================================================================
   Orbis360 — design system + all pages
   Motion/VR component styles (o360-*) are injected at runtime by
   orbis360-motion-vr.js; the core chrome lives here.
   ========================================================================== */
:root{
  --navh:64px;--r:14px;--rs:10px;
  --disp:'Space Grotesk','Segoe UI',system-ui,sans-serif;
  --body:'Inter',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;
  --mono:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,monospace;
}
[data-theme=dark]{
  --bg:#070b14;--bg2:#0a1020;--surface:#0f1728;--surface2:#152036;
  --overlay:rgba(9,14,27,.86);--scrim:rgba(2,5,11,.7);
  --text:#e9eefb;--text2:#9aa7c4;--text3:#5f6d8f;
  --line:rgba(148,180,255,.15);--line2:rgba(148,180,255,.3);
  --cyan:#3fd9ff;--cyan2:#19b8e6;--teal:#2fe6b0;--amber:#ffb454;--magenta:#ff7ac2;
  --success:#3ddc97;--warning:#ffc247;--danger:#ff5d73;--info:#6ea8ff;
  --grad:linear-gradient(135deg,#3fd9ff,#2fe6b0);
  --grad2:linear-gradient(120deg,#12203c,#0d2b33 45%,#1b1430);
  --vrgrad:linear-gradient(135deg,#ff7ac2,#ffb454);
  --glow:0 0 22px rgba(63,217,255,.32);--shadow:0 14px 44px rgba(0,0,0,.56);
  --thumbbg:#0b1322;color-scheme:dark;
}
[data-theme=light]{
  --bg:#f2f5fb;--bg2:#e9eef8;--surface:#fff;--surface2:#f3f6fd;
  --overlay:rgba(255,255,255,.92);--scrim:rgba(20,30,55,.42);
  --text:#16203a;--text2:#49567c;--text3:#8b96b5;
  --line:rgba(24,44,96,.14);--line2:rgba(24,44,96,.27);
  --cyan:#0899c9;--cyan2:#067fa8;--teal:#0cb98a;--amber:#df8b06;--magenta:#d84a97;
  --success:#0da06b;--warning:#c07f00;--danger:#dc3550;--info:#3568d4;
  --grad:linear-gradient(135deg,#0aa6d6,#0dbf8f);
  --grad2:linear-gradient(120deg,#dfe9fb,#d7f2ee 45%,#ece4fb);
  --vrgrad:linear-gradient(135deg,#d84a97,#df8b06);
  --glow:0 0 18px rgba(8,153,201,.22);--shadow:0 12px 34px rgba(30,45,90,.16);
  --thumbbg:#dfe6f3;color-scheme:light;
}

*{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{font-family:var(--body);background:var(--bg);color:var(--text);font-size:15px;line-height:1.55;overflow-x:hidden;-webkit-font-smoothing:antialiased}
::selection{background:rgba(63,217,255,.3)}
*{scrollbar-width:thin;scrollbar-color:var(--cyan2) transparent}
::-webkit-scrollbar{width:10px;height:10px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:linear-gradient(180deg,var(--cyan2),var(--teal));border-radius:8px;border:2px solid var(--bg)}
a{color:var(--cyan);text-decoration:none}
img{display:block;max-width:100%}
button{font-family:inherit;font-size:inherit;color:inherit;background:none;border:none;cursor:pointer}
input,select,textarea{font-family:inherit;font-size:14px;color:var(--text);background:var(--surface2);border:1px solid var(--line);border-radius:var(--rs);padding:9px 12px;outline:none;transition:border-color .15s,box-shadow .15s;width:100%}
input:focus,select:focus,textarea:focus{border-color:var(--cyan2);box-shadow:0 0 0 3px rgba(63,217,255,.16)}
textarea{resize:vertical;min-height:76px}
select{appearance:none;background-image:linear-gradient(45deg,transparent 50%,var(--text2) 50%),linear-gradient(135deg,var(--text2) 50%,transparent 50%);background-position:calc(100% - 18px) 55%,calc(100% - 13px) 55%;background-size:5px 5px;background-repeat:no-repeat;padding-right:32px}
label{font-size:11.5px;font-weight:600;color:var(--text2);letter-spacing:.05em;text-transform:uppercase;display:block;margin-bottom:6px}
h1,h2,h3,.disp{font-family:var(--disp);letter-spacing:-.01em}
.mono{font-family:var(--mono);font-size:12.5px}
.muted{color:var(--text2)}.dim{color:var(--text3)}
.hidden{display:none!important}
.grad-text{background:var(--grad);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}

.btn{display:inline-flex;align-items:center;gap:8px;padding:10px 18px;border-radius:12px;font-weight:600;font-size:14px;border:1px solid transparent;transition:transform .15s,box-shadow .15s,background .15s,border-color .15s;white-space:nowrap;user-select:none}
.btn:active{transform:scale(.97)}
.btn-primary{background:var(--grad);color:#03222e;box-shadow:var(--glow)}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 0 30px rgba(63,217,255,.45)}
.btn-ghost{border-color:var(--line2);color:var(--text);background:var(--overlay)}
.btn-ghost:hover,.btn.on{border-color:var(--cyan2);color:var(--cyan);background:rgba(63,217,255,.1)}
.btn-danger{background:rgba(255,93,115,.12);color:var(--danger);border-color:rgba(255,93,115,.35)}
.btn-danger:hover{background:rgba(255,93,115,.2)}
.btn-sm{padding:7px 12px;font-size:13px;border-radius:10px}
.btn[disabled]{opacity:.45;pointer-events:none}
.icon-btn{display:inline-flex;align-items:center;justify-content:center;width:38px;height:38px;border-radius:11px;color:var(--text2);border:1px solid transparent;transition:all .15s;flex:none}
.icon-btn:hover{color:var(--cyan);background:var(--surface2);border-color:var(--line)}
.icon-btn.on{color:var(--cyan);background:rgba(63,217,255,.12);border-color:rgba(63,217,255,.4)}
.icon-btn.sm{width:30px;height:30px;border-radius:8px}
.chip{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:600;padding:4px 10px;border-radius:999px;background:var(--surface2);border:1px solid var(--line);color:var(--text2)}
.chip.ok{color:var(--success);border-color:rgba(61,220,151,.4);background:rgba(61,220,151,.1)}
.chip.warn{color:var(--warning);border-color:rgba(255,194,71,.4);background:rgba(255,194,71,.1)}
.chip.err{color:var(--danger);border-color:rgba(255,93,115,.4);background:rgba(255,93,115,.1)}
.chip.cy{color:var(--cyan);border-color:rgba(63,217,255,.4);background:rgba(63,217,255,.09)}
.chip.am{color:var(--amber);border-color:rgba(255,180,84,.4);background:rgba(255,180,84,.1)}
.kbd{font-family:var(--mono);font-size:11px;background:var(--surface2);border:1px solid var(--line2);border-bottom-width:2px;border-radius:6px;padding:2px 7px}
.field{min-width:0}.field.full{grid-column:1/-1}
.switch{position:relative;display:inline-flex;align-items:center;gap:10px;cursor:pointer;user-select:none}
.switch input{position:absolute;opacity:0;width:0}
.switch .tr{width:44px;height:24px;border-radius:999px;background:var(--surface2);border:1px solid var(--line2);transition:all .2s;flex:none;position:relative}
.switch .tr::after{content:'';position:absolute;left:3px;top:3px;width:16px;height:16px;border-radius:50%;background:var(--text2);transition:all .2s}
.switch input:checked+.tr{background:var(--grad);border-color:transparent}
.switch input:checked+.tr::after{left:23px;background:#fff}
.switch .sl{font-size:13px;font-weight:600}
input[type=range]{-webkit-appearance:none;appearance:none;cursor:pointer;padding:0;background:none;border:none;box-shadow:none;height:18px}
input[type=range]::-webkit-slider-runnable-track{height:4px;border-radius:4px;background:linear-gradient(90deg,var(--cyan2),var(--teal))}
input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:14px;height:14px;border-radius:50%;background:#fff;border:3px solid var(--cyan2);margin-top:-5px;box-shadow:0 0 8px rgba(63,217,255,.5)}
input[type=range]::-moz-range-track{height:4px;border-radius:4px;background:linear-gradient(90deg,var(--cyan2),var(--teal))}
input[type=range]::-moz-range-thumb{width:12px;height:12px;border-radius:50%;background:#fff;border:3px solid var(--cyan2)}

/* ---------- nav / layout ---------- */
.nav{position:fixed;top:0;left:0;right:0;height:var(--navh);z-index:120;background:var(--overlay);backdrop-filter:blur(16px);border-bottom:1px solid var(--line)}
.nav-inner{max-width:1440px;margin:0 auto;height:100%;display:flex;align-items:center;gap:18px;padding:0 20px}
.brand{display:flex;align-items:center;gap:10px;font-family:var(--disp);font-weight:700;font-size:19px;color:var(--text)}
.brand img,.brand svg{width:30px;height:30px}
.nav-links{display:flex;gap:4px;margin-left:12px}
.nav-link{position:relative;padding:8px 13px;border-radius:10px;font-weight:600;font-size:14px;color:var(--text2)}
.nav-link:hover{color:var(--text)}
.nav-link.on{color:var(--cyan)}
.nav-link.on::after{content:'';position:absolute;left:13px;right:13px;bottom:2px;height:2px;border-radius:2px;background:var(--grad);box-shadow:var(--glow)}
.nav-right{margin-left:auto;display:flex;align-items:center;gap:8px}
.nav-burger{display:none}
@media(max-width:900px){
  .nav-links{position:fixed;top:var(--navh);left:0;right:0;flex-direction:column;background:var(--overlay);backdrop-filter:blur(18px);border-bottom:1px solid var(--line);padding:10px 16px 16px;display:none}
  .nav.open .nav-links{display:flex}
  .nav-burger{display:inline-flex}
  .nav-cta span{display:none}
}
.page{padding-top:var(--navh);min-height:100vh}
.wrap{max-width:1240px;margin:0 auto;padding:0 24px}
.section{padding:70px 0}
.page-head{padding:40px 0 22px}
.page-head h1{font-size:clamp(26px,3.4vw,36px)}
.page-head p{color:var(--text2);margin-top:6px}
.sec-head{max-width:640px;margin-bottom:36px}
.sec-head .eyebrow{font-size:12px;font-weight:700;letter-spacing:.16em;color:var(--cyan);text-transform:uppercase;margin-bottom:10px}
.sec-head h2{font-size:clamp(25px,3.4vw,36px);margin-bottom:10px}
.sec-head p{color:var(--text2)}
.empty{border:1.5px dashed var(--line2);border-radius:var(--r);padding:50px 28px;text-align:center;color:var(--text2)}
.empty .fi{color:var(--cyan);margin-bottom:12px}
.empty h3{color:var(--text);margin-bottom:8px}
.empty .btn{margin:6px 4px 0}
.skel{background:linear-gradient(100deg,var(--thumbbg) 40%,var(--surface2) 50%,var(--thumbbg) 60%);background-size:200% 100%;animation:shimmer 1.4s infinite}
@keyframes shimmer{to{background-position:-200% 0}}
.spin{width:12px;height:12px;border:2px solid rgba(255,180,84,.3);border-top-color:var(--amber);border-radius:50%;animation:spin 1s linear infinite;flex:none}
@keyframes spin{to{transform:rotate(360deg)}}

/* ---------- home ---------- */
.hero{position:relative;min-height:max(560px,88vh);display:flex;align-items:center;overflow:hidden;background:var(--grad2)}
.hero-bg{position:absolute;inset:0}
.hero-bg canvas{width:100%!important;height:100%!important;display:block;touch-action:none;cursor:grab}
.hero-fallback{position:absolute;inset:0;background:radial-gradient(1000px 500px at 75% 20%,rgba(63,217,255,.16),transparent 60%),radial-gradient(800px 500px at 15% 80%,rgba(255,122,194,.12),transparent 60%),var(--grad2)}
.hero-scrim{position:absolute;inset:0;pointer-events:none;background:linear-gradient(180deg,rgba(7,11,20,.72),rgba(7,11,20,.18) 32%,var(--bg) 98%),linear-gradient(90deg,rgba(7,11,20,.8),rgba(7,11,20,.3) 48%,transparent 76%)}
.hero-content{position:relative;z-index:3;max-width:1240px;margin:0 auto;padding:110px 24px 80px;width:100%;pointer-events:none}
.hero-content>*{pointer-events:auto}
.hero-inner{max-width:620px}
.eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:12px;font-weight:700;letter-spacing:.14em;color:#9be9ff;background:rgba(10,22,40,.55);border:1px solid rgba(63,217,255,.35);padding:7px 14px;border-radius:999px;margin-bottom:20px}
.hero h1{font-size:clamp(36px,6vw,68px);line-height:1.03;color:#fff;text-shadow:0 4px 30px rgba(0,0,0,.45);margin-bottom:18px}
.hero h1 em{font-style:normal;background:linear-gradient(120deg,#3fd9ff,#2fe6b0 60%,#ffb454);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.hero .sub{font-size:17px;color:#dbe6fa;max-width:520px;margin-bottom:28px}
.hero-ctas{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:30px}
.hero .btn-ghost{background:rgba(10,18,36,.55);color:#eaf2ff;border-color:rgba(160,190,255,.35)}
.hero-stats{display:flex;gap:10px;flex-wrap:wrap}
.stat{background:rgba(9,15,30,.6);border:1px solid rgba(148,180,255,.22);border-radius:12px;padding:10px 16px}
.stat b{display:block;font-family:var(--disp);font-size:20px;color:#fff}
.stat span{font-size:11.5px;color:#9fb0d0;letter-spacing:.05em;text-transform:uppercase}
.drag-hint{position:absolute;right:24px;bottom:96px;z-index:3;display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:#cfe9ff;background:rgba(9,15,30,.6);border:1px solid rgba(63,217,255,.35);padding:8px 14px;border-radius:999px;pointer-events:none;animation:float 3s ease-in-out infinite}
@keyframes float{50%{transform:translateY(-6px)}}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}
.card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:24px;transition:transform .2s,border-color .2s}
.card:hover{transform:translateY(-4px);border-color:var(--line2)}
.card .fi{width:42px;height:42px;border-radius:12px;display:flex;align-items:center;justify-content:center;background:rgba(63,217,255,.1);color:var(--cyan);margin-bottom:13px;border:1px solid rgba(63,217,255,.25)}
.card h3{font-size:16.5px;margin-bottom:7px}
.card p{font-size:13.5px;color:var(--text2)}
.footer{border-top:1px solid var(--line);padding:40px 0 55px;background:var(--bg2)}
.footer-grid{display:flex;justify-content:space-between;gap:30px;flex-wrap:wrap}
.footer small{display:block;color:var(--text3);margin-top:12px;font-size:12.5px;max-width:560px}
.footer .fl{display:flex;gap:16px;flex-wrap:wrap}
.footer a{color:var(--text2);font-size:14px}
@media(max-width:900px){.grid3{grid-template-columns:1fr 1fr}}
@media(max-width:620px){.grid3{grid-template-columns:1fr}.drag-hint{display:none}.hero-content{padding-top:96px}}

/* ---------- explore ---------- */
.search-bar{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:16px}
.search-wrap{position:relative;flex:1;min-width:220px}
.search-wrap svg{position:absolute;left:12px;top:50%;transform:translateY(-50%);color:var(--text3)}
.search-wrap input{padding-left:40px}
.filter-chips{display:flex;gap:8px;flex-wrap:wrap}
.fchip{padding:7px 14px;border-radius:999px;font-size:13px;font-weight:600;color:var(--text2);border:1px solid var(--line);background:var(--surface)}
.fchip:hover{color:var(--text);border-color:var(--line2)}
.fchip.on{color:#03222e;background:var(--grad);border-color:transparent;box-shadow:var(--glow)}
.grid-tours{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:20px;padding-bottom:60px}
.tour-card{background:var(--surface);border:1px solid var(--line);border-radius:var(--r);overflow:hidden;transition:transform .2s,border-color .2s,box-shadow .2s;display:flex;flex-direction:column}
.tour-card:hover{transform:translateY(-5px);border-color:var(--line2);box-shadow:var(--shadow)}
.tc-cover{position:relative;aspect-ratio:2/1;background:var(--thumbbg);overflow:hidden}
.tc-cover img{width:100%;height:100%;object-fit:cover;transition:transform .5s}
.tour-card:hover .tc-cover img{transform:scale(1.06)}
.tc-cover .shade{position:absolute;inset:0;background:linear-gradient(180deg,transparent 40%,rgba(5,9,18,.8))}
.tc-badges{position:absolute;top:10px;left:10px;display:flex;gap:6px;flex-wrap:wrap}
.tc-loc{position:absolute;left:12px;bottom:12px;color:#e6eeff;font-size:12.5px;font-weight:600;display:flex;gap:6px;align-items:center;text-shadow:0 1px 8px rgba(0,0,0,.6)}
.tc-enter{position:absolute;right:12px;bottom:10px}
.tc-body{padding:16px 18px 14px;flex:1}
.tc-body h3{font-size:17.5px;margin-bottom:5px}
.tc-body p{font-size:13px;color:var(--text2);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.tc-foot{display:flex;align-items:center;gap:6px;padding:10px 12px;border-top:1px solid var(--line)}
.tc-foot .sp{flex:1}

/* ---------- viewer ---------- */
.viewer-page{position:relative;height:calc(100vh - var(--navh));height:calc(100dvh - var(--navh));background:#05070d;overflow:hidden}
.viewer-page.pseudo-fs,.studio-viewer.pseudo-fs,.o360-pseudo-fs{position:fixed!important;inset:0!important;z-index:500;height:100vh!important}
.v-mount{position:absolute;inset:0}
.v-mount canvas{display:block;width:100%!important;height:100%!important;touch-action:none;cursor:grab}
.v-mount canvas:active{cursor:grabbing}
.v-mount.placing canvas{cursor:crosshair}
.v-veil{position:absolute;inset:0;background:#05070d;opacity:0;pointer-events:none;z-index:4;display:flex;align-items:center;justify-content:center}
.v-veil.err{opacity:1;pointer-events:auto}
.v-labels{position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:5}
.h-label{position:absolute;transform:translate(-50%,-130%);background:var(--overlay);border:1px solid rgba(63,217,255,.4);color:var(--text);font-size:12px;font-weight:600;padding:5px 11px;border-radius:999px;white-space:nowrap;backdrop-filter:blur(8px);pointer-events:none}
.h-label small{color:var(--cyan);font-weight:700;margin-right:6px}
.v-top{position:absolute;top:0;left:0;right:0;z-index:10;display:flex;align-items:center;gap:12px;padding:14px 16px;background:linear-gradient(180deg,rgba(4,7,14,.8),transparent);pointer-events:none;color:#fff}
.v-top>*{pointer-events:auto}
.v-top .icon-btn{color:#dfe9ff;background:rgba(9,15,30,.5);border-color:rgba(148,180,255,.2)}
.v-title{min-width:0}
.v-title .t-tour{font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:#8fd8f5}
.v-title .t-scene{font-family:var(--disp);font-size:18px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.v-actions{margin-left:auto;display:flex;gap:8px;align-items:center}
.res-chip,.load-chip{font-family:var(--mono);font-size:11px;color:#9be9ff;background:rgba(9,15,30,.6);border:1px solid rgba(63,217,255,.3);padding:5px 10px;border-radius:999px}
.load-chip{color:var(--amber);border-color:rgba(255,180,84,.4);display:flex;gap:7px;align-items:center}
.v-hint{position:absolute;top:76px;left:50%;transform:translateX(-50%);z-index:9;background:var(--overlay);border:1px solid var(--line2);color:var(--text);font-size:13px;padding:9px 18px;border-radius:999px;backdrop-filter:blur(10px);transition:opacity .5s;white-space:nowrap;max-width:92vw;overflow:hidden;text-overflow:ellipsis}
.v-hint.place{border-color:rgba(255,180,84,.55);color:var(--amber);font-weight:600}
.v-bottom{position:absolute;left:0;right:0;bottom:0;z-index:10;display:flex;flex-direction:column;gap:8px;padding:0 12px 10px;pointer-events:none;background:linear-gradient(0deg,rgba(4,7,14,.84),transparent)}
.v-bottom>*{pointer-events:auto}
#v-dock,.dock-wrap{display:flex;justify-content:center;max-width:100%}
.strip{display:flex;align-items:center;gap:8px;align-self:center;max-width:min(96%,860px)}
.strip-scroll{display:flex;gap:8px;overflow-x:auto;padding:6px 4px}
.strip-thumb{position:relative;flex:none;width:96px;height:48px;border-radius:9px;overflow:hidden;border:2px solid rgba(148,180,255,.25);background:var(--thumbbg);padding:0}
.strip-thumb img{width:100%;height:100%;object-fit:cover}
.strip-thumb:hover{transform:translateY(-2px);border-color:rgba(63,217,255,.6)}
.strip-thumb.on{border-color:var(--cyan);box-shadow:var(--glow)}
.strip-thumb .n{position:absolute;left:4px;top:3px;font-size:9.5px;font-weight:700;background:rgba(5,9,18,.75);color:#cfe9ff;border-radius:5px;padding:1px 5px}
.strip-nav{flex:none;width:30px;height:44px;border-radius:9px;background:rgba(9,15,30,.6);border:1px solid rgba(148,180,255,.25);color:#dfe9ff;display:flex;align-items:center;justify-content:center}
.dock{display:flex;align-items:stretch;gap:2px;background:var(--overlay);border:1px solid var(--line2);border-radius:14px;padding:7px 10px;backdrop-filter:blur(14px);overflow-x:auto;box-shadow:var(--shadow);max-width:100%}
.dock-group{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;padding:2px 10px;border-right:1px solid var(--line);flex:none}
.dock-group:last-child{border-right:none}
.dock-label{font-size:9px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;color:var(--text3);display:flex;gap:4px;align-items:center}
.dock-label b{color:var(--cyan);font-family:var(--mono)}
.dock input[type=range]{width:86px}
.dock-toggles,.dock-btns{flex-direction:row;gap:4px}
.dock .icon-btn{width:34px;height:34px}
.dock select{width:auto;padding:6px 28px 6px 9px;font-size:12px;font-weight:600}
.v-compass{position:absolute;left:16px;bottom:150px;z-index:9;display:flex;flex-direction:column;align-items:center;gap:4px}
.v-compass .hdg{font-family:var(--mono);font-size:11px;color:#cfe9ff;background:rgba(9,15,30,.65);padding:2px 8px;border-radius:6px;border:1px solid rgba(148,180,255,.25)}
.v-minimap{position:absolute;right:16px;bottom:150px;z-index:9;width:216px;border-radius:13px;overflow:hidden;border:1px solid var(--line2);background:var(--overlay);backdrop-filter:blur(12px);box-shadow:var(--shadow)}
.mm-head{display:flex;align-items:center;gap:6px;padding:6px 10px;font-size:10px;font-weight:700;letter-spacing:.12em;color:var(--text2)}
.mm-head .sp{flex:1}
.mm-map{height:138px;background:var(--bg2)}
.mm-none{height:80px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text3);padding:10px;text-align:center}
.v-minimap.collapsed .mm-map,.v-minimap.collapsed .mm-none{display:none}
.info-pop{position:absolute;z-index:11;width:min(300px,80vw);background:var(--overlay);border:1px solid rgba(255,180,84,.45);border-radius:13px;padding:14px 16px;backdrop-filter:blur(14px);box-shadow:var(--shadow);transform:translate(-50%,calc(-100% - 18px))}
.info-pop h4{font-family:var(--disp);font-size:15px;color:var(--amber);margin-bottom:5px;padding-right:22px}
.info-pop p{font-size:13px}
.info-pop img{border-radius:8px;margin:8px 0}
.info-pop .x{position:absolute;top:8px;right:8px}
.info-panel{position:absolute;top:70px;left:16px;z-index:11;width:min(330px,86vw);background:var(--overlay);border:1px solid var(--line2);border-radius:14px;padding:18px;backdrop-filter:blur(14px);box-shadow:var(--shadow);max-height:calc(100% - 240px);overflow-y:auto}
.info-panel h3{font-size:18px;margin-bottom:6px;padding-right:26px}
.info-panel .desc{font-size:13.5px;color:var(--text2);margin-bottom:12px}
.info-panel h5{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--text3);margin:12px 0 6px}
.jump-row{display:flex;align-items:center;gap:8px;width:100%;text-align:left;padding:8px 10px;border-radius:9px;font-size:13px;font-weight:600;color:var(--text);border:1px solid transparent}
.jump-row:hover{background:var(--surface2);border-color:var(--line)}
.jump-row svg{color:var(--cyan);flex:none}
@media(max-width:760px){
  .v-minimap{width:168px;bottom:172px}.mm-map{height:104px}.v-compass{bottom:172px}
  .v-title .t-scene{font-size:15px}.dock input[type=range]{width:64px}.res-chip{display:none}
}

/* ---------- map ---------- */
.map-page{position:relative;height:calc(100vh - var(--navh));height:calc(100dvh - var(--navh))}
.map-canvas{position:absolute;inset:0;background:var(--bg2)}
[data-theme=dark] .leaflet-tile{filter:invert(1) hue-rotate(180deg) brightness(.92) contrast(.92) saturate(.62)}
[data-theme=dark] .leaflet-container{background:#0a0f1c}
.leaflet-container{font-family:var(--body)}
.leaflet-popup-content-wrapper,.leaflet-popup-tip{background:var(--surface);color:var(--text);box-shadow:var(--shadow);border:1px solid var(--line2)}
.leaflet-popup-content{margin:12px 14px;font-size:13px}
.leaflet-control-attribution{font-size:10px!important;background:var(--overlay)!important;color:var(--text3)!important}
.leaflet-bar a{background:var(--surface)!important;color:var(--text)!important;border-color:var(--line)!important}
.map-pop{width:210px}
.map-pop img{width:100%;aspect-ratio:2/1;object-fit:cover;border-radius:8px;margin-bottom:8px;background:var(--thumbbg)}
.map-pop b{font-family:var(--disp);font-size:14px;display:block}
.map-pop .btn{width:100%;justify-content:center;margin-top:4px}
.sv-marker{position:relative;width:26px;height:26px}
.sv-marker .dot{position:absolute;inset:5px;border-radius:50%;background:var(--c,#3fd9ff);border:2.5px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,.5)}
.sv-marker .pulse{position:absolute;inset:0;border-radius:50%;border:2px solid var(--c,#3fd9ff);animation:mpulse 2s ease-out infinite}
@keyframes mpulse{0%{transform:scale(.6);opacity:.8}100%{transform:scale(1.7);opacity:0}}
.map-side{position:absolute;top:16px;left:16px;bottom:16px;z-index:500;width:300px;background:var(--overlay);border:1px solid var(--line2);border-radius:15px;backdrop-filter:blur(14px);box-shadow:var(--shadow);display:flex;flex-direction:column;overflow:hidden}
.ms-head{padding:16px 16px 10px}
.ms-head h2{font-size:17px;margin-bottom:10px}
.ms-list{flex:1;overflow-y:auto;padding:6px 10px 14px}
.ms-tour-head{display:flex;align-items:center;gap:8px;padding:8px;font-weight:700;font-size:13.5px}
.cdot{width:10px;height:10px;border-radius:50%;flex:none}
.ms-scene{display:flex;align-items:center;gap:9px;width:100%;text-align:left;padding:7px 8px;border-radius:9px;font-size:13px;color:var(--text2);border:1px solid transparent}
.ms-scene:hover{background:var(--surface2);color:var(--text)}
.ms-scene.sel{border-color:var(--amber);color:var(--amber);background:rgba(255,180,84,.08)}
.ms-scene img{width:46px;height:23px;object-fit:cover;border-radius:5px;flex:none;background:var(--thumbbg)}
.ms-scene .nm{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.place-banner{position:absolute;top:16px;left:50%;transform:translateX(-50%);z-index:500;background:var(--overlay);border:1px solid rgba(255,180,84,.55);color:var(--amber);font-weight:600;font-size:13px;padding:10px 18px;border-radius:999px;display:flex;gap:10px;align-items:center;max-width:92vw}
.map-fallback{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;text-align:center;padding:30px;color:var(--text2)}
@media(max-width:760px){.map-side{top:auto;left:10px;right:10px;bottom:10px;width:auto;max-height:42vh}.place-banner{top:10px;font-size:12px}}

/* ---------- admin ---------- */
.admin{display:grid;grid-template-columns:280px 1fr;min-height:calc(100vh - var(--navh))}
.admin-side{border-right:1px solid var(--line);background:var(--bg2);padding:20px 14px;display:flex;flex-direction:column;gap:6px}
.admin-side h4{font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--text3);padding:0 8px 8px}
.tour-item{display:flex;gap:10px;align-items:center;width:100%;text-align:left;padding:9px 10px;border-radius:11px;border:1px solid transparent}
.tour-item:hover{background:var(--surface)}
.tour-item.on{background:var(--surface);border-color:rgba(63,217,255,.4);box-shadow:var(--glow)}
.tour-item img{width:56px;height:28px;object-fit:cover;border-radius:6px;background:var(--thumbbg);flex:none}
.ti-b{flex:1;min-width:0}
.ti-b b{display:block;font-size:13.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ti-b span{font-size:11.5px;color:var(--text3)}
.pub-dot{width:8px;height:8px;border-radius:50%;flex:none;background:var(--text3)}
.pub-dot.on{background:var(--success);box-shadow:0 0 8px rgba(61,220,151,.7)}
.admin-main{padding:26px 28px 70px;min-width:0}
.tour-head{display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap;margin-bottom:18px}
.tour-head img{width:120px;height:60px;object-fit:cover;border-radius:10px;background:var(--thumbbg)}
.th-b{flex:1;min-width:220px}
.tour-head h1{font-size:24px}
.stat-chips{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
.tour-actions{display:flex;gap:8px;flex-wrap:wrap;margin:14px 0 22px}
.bulk-bar{display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:rgba(63,217,255,.08);border:1px solid rgba(63,217,255,.35);border-radius:12px;padding:10px 14px;margin-bottom:12px}
.bulk-bar b{color:var(--cyan)}
.scene-rows{display:flex;flex-direction:column;gap:8px;margin-bottom:28px}
.scene-row{display:flex;align-items:center;gap:12px;background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:10px 12px}
.scene-row:hover{border-color:var(--line2)}
.scene-row.dragover{border-color:var(--cyan);box-shadow:var(--glow)}
.grip{color:var(--text3);cursor:grab;flex:none;display:flex}
.row-check{width:17px;height:17px;accent-color:var(--cyan2);flex:none}
.scene-row img{width:76px;height:38px;object-fit:cover;border-radius:7px;background:var(--thumbbg);flex:none}
.row-meta{flex:1;min-width:0}
.row-meta .nm{font-weight:600;font-size:14px;cursor:pointer;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.row-meta .nm:hover{color:var(--cyan)}
.row-meta .sub{display:flex;gap:6px;flex-wrap:wrap;margin-top:3px;align-items:center}
.row-actions{display:flex;gap:2px;flex:none}
.settings-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;background:var(--surface);border:1px solid var(--line);border-radius:var(--r);padding:22px;margin-bottom:26px}
.swatches{display:flex;gap:8px}
.swatch{width:28px;height:28px;border-radius:50%;border:2px solid transparent}
.swatch.on{border-color:#fff;box-shadow:0 0 0 2px var(--cyan)}
.sec-title{font-size:13px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--text3);margin:26px 0 12px;display:flex;align-items:center;gap:10px}
.sec-title::after{content:'';flex:1;height:1px;background:var(--line)}
@media(max-width:900px){
  .admin{grid-template-columns:1fr}
  .admin-side{flex-direction:row;overflow-x:auto;border-right:none;border-bottom:1px solid var(--line);padding:12px}
  .admin-side h4,.admin-side .btn span{display:none}
  .tour-item{flex:none;width:210px}
  .settings-grid{grid-template-columns:1fr}
  .admin-main{padding:20px 16px 60px}
  .row-actions{flex-wrap:wrap;justify-content:flex-end}
}
.drawer-scrim{position:fixed;inset:0;z-index:640;background:var(--scrim);opacity:0;transition:opacity .25s}
.drawer-scrim.open{opacity:1}
.drawer{position:fixed;top:0;right:0;bottom:0;z-index:650;width:min(430px,94vw);background:var(--surface);border-left:1px solid var(--line2);box-shadow:var(--shadow);transform:translateX(102%);transition:transform .28s cubic-bezier(.2,.8,.2,1);overflow-y:auto;padding:20px}
.drawer.open{transform:none}
.drawer-head{display:flex;align-items:center;gap:10px;margin-bottom:14px}
.drawer-head h3{flex:1;font-size:19px}
.drawer-cover{width:100%;aspect-ratio:2/1;object-fit:cover;border-radius:12px;background:var(--thumbbg);margin-bottom:14px}
.drawer .desc{color:var(--text2);font-size:13.5px;margin-bottom:12px}
.drawer h5{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--text3);margin:18px 0 8px}
.hs-line{display:flex;gap:8px;align-items:center;font-size:13px;padding:7px 9px;border:1px solid var(--line);border-radius:8px;margin-bottom:6px;background:var(--surface2)}
.hs-line svg{color:var(--cyan);flex:none}

/* ---------- studio ---------- */
.studio{display:grid;grid-template-columns:1fr 380px;height:calc(100vh - var(--navh));height:calc(100dvh - var(--navh))}
.studio-viewer{position:relative;background:#05070d;min-width:0}
.studio-viewer .v-mount{position:absolute;inset:0}
.sv-top{position:absolute;top:0;left:0;right:0;z-index:10;display:flex;align-items:center;gap:10px;padding:12px 14px;background:linear-gradient(180deg,rgba(4,7,14,.8),transparent);color:#fff;pointer-events:none}
.sv-top>*{pointer-events:auto}
.sv-top .icon-btn{color:#dfe9ff;background:rgba(9,15,30,.5)}
.sv-name{font-family:var(--disp);font-weight:600;font-size:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.saved-dot{font-size:11.5px;font-weight:700;color:var(--success);display:flex;gap:5px;align-items:center;opacity:0;transition:opacity .3s}
.saved-dot.show{opacity:1}
.studio-viewer .dock-wrap{position:absolute;left:0;right:0;bottom:0;z-index:10;padding:0 10px 10px;pointer-events:none;background:linear-gradient(0deg,rgba(4,7,14,.8),transparent)}
.studio-viewer .dock-wrap>*{pointer-events:auto}
.studio-panel{border-left:1px solid var(--line);background:var(--bg2);overflow-y:auto;padding:18px 18px 60px}
.panel-sec{background:var(--surface);border:1px solid var(--line);border-radius:13px;padding:16px;margin-bottom:14px}
.panel-sec h4{font-size:12px;font-weight:700;letter-spacing:.11em;text-transform:uppercase;color:var(--text3);margin-bottom:12px;display:flex;align-items:center;gap:8px}
.panel-sec h4 svg{color:var(--cyan)}
.panel-sec .field{margin-bottom:12px}
.readout{font-family:var(--mono);font-size:12px;background:var(--surface2);border:1px solid var(--line);border-radius:9px;padding:9px 12px;color:var(--cyan);margin-bottom:10px}
.btn-row{display:flex;gap:8px;flex-wrap:wrap}
.btn-row .btn{flex:1;justify-content:center}
.hs-row{display:flex;align-items:center;gap:9px;padding:8px 9px;border-radius:9px;border:1px solid var(--line);margin-bottom:7px;background:var(--surface2)}
.hs-row .hi{flex:none;color:var(--cyan)}
.hs-row.info .hi{color:var(--amber)}
.hs-row .hb{flex:1;min-width:0}
.hs-row .hb b{font-size:13px;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.hs-row .hb span{font-size:11px;color:var(--text3)}
.meta-chips{display:flex;gap:6px;flex-wrap:wrap}
@media(max-width:980px){.studio{grid-template-columns:1fr;height:auto}.studio-viewer{height:56vh;min-height:420px}.studio-panel{border-left:none;border-top:1px solid var(--line)}}

/* ---------- upload ---------- */
.upload-page{max-width:980px;margin:0 auto;padding:34px 22px 75px}
.tabs{display:flex;gap:6px;margin:18px 0 20px;border-bottom:1px solid var(--line)}
.tab{padding:11px 17px;font-weight:600;font-size:14px;color:var(--text2);border-bottom:2px solid transparent;margin-bottom:-1px}
.tab.on{color:var(--cyan);border-bottom-color:var(--cyan)}
.up-options{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px}
.dropzone{border:2px dashed var(--line2);border-radius:var(--r);padding:44px 22px;text-align:center;cursor:pointer;transition:all .2s;background:var(--surface)}
.dropzone:hover,.dropzone.drag{border-color:var(--cyan);background:rgba(63,217,255,.05);box-shadow:var(--glow)}
.dropzone .fi{color:var(--cyan);margin-bottom:12px}
.dropzone h3{font-size:18px;margin-bottom:6px}
.dropzone p{color:var(--text2);font-size:13.5px}
.up-queue{display:flex;flex-direction:column;gap:10px;margin:18px 0}
.up-row{display:flex;gap:13px;align-items:center;background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:12px 14px}
.up-row.warn{border-color:rgba(255,194,71,.5)}
.up-row.err{border-color:rgba(255,93,115,.5)}
.up-row.done{border-color:rgba(61,220,151,.5)}
.up-thumb{width:84px;height:42px;border-radius:7px;object-fit:cover;background:var(--thumbbg);flex:none}
.up-meta{flex:1;min-width:0}
.up-meta input{font-weight:600;padding:6px 9px;margin-bottom:5px}
.up-badges{display:flex;gap:5px;flex-wrap:wrap}
.up-status{font-size:12px;color:var(--text2);margin-top:5px}
.progress{height:5px;border-radius:4px;background:var(--surface2);overflow:hidden;margin-top:6px}
.progress i{display:block;height:100%;background:var(--grad);width:0;transition:width .25s}
.up-foot{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:8px}
.check{display:flex;gap:9px;align-items:center;font-size:13.5px;font-weight:500;cursor:pointer}
.check input{width:17px;height:17px;accent-color:var(--cyan2)}
.up-note{font-size:12.5px;color:var(--text3);margin-top:16px;line-height:1.6}
@media(max-width:680px){.up-options{grid-template-columns:1fr}.up-row{flex-wrap:wrap}.up-thumb{width:64px;height:32px}}

/* ---------- modal / toast / boot ---------- */
.modal-scrim{position:fixed;inset:0;z-index:600;background:var(--scrim);backdrop-filter:blur(6px);display:flex;align-items:center;justify-content:center;padding:20px}
.modal{background:var(--surface);border:1px solid var(--line2);border-radius:16px;width:min(520px,100%);max-height:88vh;overflow-y:auto;box-shadow:var(--shadow);animation:pop .22s cubic-bezier(.2,.9,.3,1.2)}
.modal.wide{width:min(720px,100%)}
@keyframes pop{from{opacity:0;transform:scale(.94) translateY(10px)}}
.modal-head{display:flex;align-items:center;gap:10px;padding:18px 20px 0}
.modal-head h3{flex:1;font-size:18px}
.modal-body{padding:16px 20px 22px}
.modal-body .field{margin-bottom:14px}
.modal-foot{display:flex;gap:10px;justify-content:flex-end;padding:0 20px 20px}
.note{font-size:12.5px;color:var(--text3);background:var(--surface2);border:1px solid var(--line);border-radius:10px;padding:11px 13px;margin-top:14px;line-height:1.55}
#toast-root{position:fixed;left:18px;bottom:18px;z-index:700;display:flex;flex-direction:column;gap:9px;max-width:min(400px,90vw)}
.toast{display:flex;align-items:center;gap:11px;background:var(--surface);border:1px solid var(--line2);border-left:3px solid var(--info);border-radius:12px;padding:12px 15px;box-shadow:var(--shadow);font-size:13.5px;animation:toastin .3s cubic-bezier(.2,.9,.3,1.2)}
.toast.success{border-left-color:var(--success)}.toast.success svg{color:var(--success)}
.toast.warn{border-left-color:var(--warning)}.toast.warn svg{color:var(--warning)}
.toast.error{border-left-color:var(--danger)}.toast.error svg{color:var(--danger)}
.toast.info svg{color:var(--info)}
.toast .msg{flex:1}
.toast .undo{font-weight:700;color:var(--cyan);padding:4px 8px;border-radius:7px}
@keyframes toastin{from{opacity:0;transform:translateX(-24px)}}
.toast.out{opacity:0;transform:translateX(-24px);transition:all .3s}
.boot{position:fixed;inset:0;z-index:800;background:radial-gradient(900px 500px at 70% 20%,rgba(63,217,255,.1),transparent 60%),var(--bg);display:flex;align-items:center;justify-content:center;transition:opacity .5s}
.boot.hide{opacity:0;pointer-events:none}
.boot-inner{text-align:center;max-width:420px;padding:24px}
.boot-logo{width:74px;height:74px;margin:0 auto 20px;position:relative}
.boot-logo .ring{position:absolute;inset:0;animation:spin 3.2s linear infinite}
.boot h2{font-size:23px;margin-bottom:6px}
.boot .bp{color:var(--text2);font-size:13.5px;min-height:22px}
.boot-bar{height:6px;border-radius:5px;background:var(--surface2);overflow:hidden;margin:20px 0 12px}
.boot-bar i{display:block;height:100%;width:12%;background:var(--grad);border-radius:5px;transition:width .3s}
.boot-tip{font-size:12px;color:var(--text3);min-height:36px}
.help-grid{display:grid;grid-template-columns:auto 1fr;gap:9px 16px;font-size:13.5px;align-items:center}

/* Motion/VR status accents used by the app chrome (module injects full set) */
.o360-dot{width:8px;height:8px;border-radius:50%;background:currentColor;flex:none}
'@

# ============================================================================
# End of Block 2/6. 3 more client shell files written (27 total so far).
# Append Block 3 below this line in the SAME build-orbis360.ps1 file.
# ============================================================================# ============================================================================
# Block 3/6 - scripts: doctor, check, reset, panorama-generator, seed
# ============================================================================

W 'scripts/doctor.js' @'
/**
 * Environment check. start.bat runs this before launching the server.
 */
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let failures = 0;
const ok = (m) => console.log('  [OK]    ' + m);
const bad = (m) => { failures++; console.log('  [FAIL]  ' + m); };

const major = Number(process.versions.node.split('.')[0]);
if (major >= 18) ok(`Node.js ${process.version}`);
else bad(`Node.js ${process.version} is too old. Install Node.js 18 or newer.`);

for (const dep of ['express', 'multer', 'sharp', 'sql.js', 'compression', 'dotenv', 'three', 'leaflet']) {
  try { require.resolve(dep); ok(`dependency ${dep}`); }
  catch { bad(`dependency ${dep} is missing. Run: npm install`); }
}

const { config, ensureDirs } = await import('../server/config.js');
try { ensureDirs(); ok('folders exist'); } catch (e) { bad('cannot create folders: ' + e.message); }

for (const dir of [config.dirs.data, config.dirs.originals, config.dirs.textures, config.dirs.previews, config.dirs.thumbs]) {
  try {
    const probe = path.join(dir, '.write-test');
    fs.writeFileSync(probe, 'ok');
    fs.rmSync(probe, { force: true });
    ok(`writable ${path.relative(config.dirs.root, dir)}`);
  } catch { bad(`folder is not writable: ${dir}`); }
}

try {
  const { initDatabase, db, persist } = await import('../server/database/db.js');
  initDatabase();
  const row = db.prepare('SELECT COUNT(*) AS n FROM tours').get();
  persist();
  ok(`SQLite ready (${row.n} tour(s) in database)`);
} catch (e) { bad('SQLite failed: ' + e.message); }

try {
  const sharp = (await import('sharp')).default;
  const buf = await sharp({ create: { width: 8, height: 4, channels: 3, background: '#123456' } }).jpeg().toBuffer();
  const meta = await sharp(buf).metadata();
  if (meta.width === 8) ok(`Sharp image pipeline (libvips ${sharp.versions.vips})`);
  else bad('Sharp produced unexpected output.');
} catch (e) { bad('Sharp failed: ' + e.message); }

for (const rel of [
  'client/index.html',
  'client/assets/css/main.css',
  'client/assets/js/app.js',
  'client/assets/js/orbis360-motion-vr.js',
  'node_modules/three/build/three.module.js',
  'node_modules/leaflet/dist/leaflet.js',
  'node_modules/sql.js/dist/sql-wasm.wasm'
]) {
  if (fs.existsSync(path.join(config.dirs.root, rel))) ok(`file ${rel}`);
  else bad(`missing file ${rel}`);
}

console.log('');
if (failures) {
  console.log(`  ${failures} problem(s) found. Fix them, then run start.bat again.`);
  process.exit(1);
}
console.log('  All checks passed.');
process.exit(0);
'@

W 'scripts/check.js' @'
/** Syntax-checks every project JavaScript file with node --check. */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const skip = new Set(['node_modules', '.git', 'data', 'storage']);
const files = [];

(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (skip.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.js')) files.push(full);
  }
})(root);

let failed = 0;
for (const file of files) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
    console.log('  ok    ' + path.relative(root, file));
  } catch (err) {
    failed++;
    console.log('  FAIL  ' + path.relative(root, file));
    console.log(String(err.stderr || err.message).split('\n').slice(0, 6).join('\n'));
  }
}
console.log(`\n  ${files.length} file(s) checked, ${failed} syntax error(s).`);
process.exit(failed ? 1 : 0);
'@

W 'scripts/reset.js' @'
/** Deletes the database and every stored image. */
import readline from 'node:readline';
import fs from 'node:fs';
import { config } from '../server/config.js';
import { emptyStorage } from '../server/services/storage.service.js';

const run = async () => {
  for (const f of [config.dbFile, config.dbFile + '.tmp', config.dbFile + '-wal', config.dbFile + '-shm']) {
    fs.rmSync(f, { force: true });
  }
  await emptyStorage();
  console.log('  Database and stored images removed. Run "npm run seed" to add sample tours.');
};

if (process.argv.includes('--yes')) { await run(); process.exit(0); }

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('  Delete the database and ALL uploaded panoramas? Type YES to confirm: ', async (answer) => {
  rl.close();
  if (answer.trim() !== 'YES') { console.log('  Cancelled.'); process.exit(0); }
  await run();
  process.exit(0);
});
'@

W 'scripts/panorama-generator.js' @'
/**
 * Software renderer used only by the seed script.
 * Produces genuine equirectangular 2:1 panoramas (correct spherical mapping)
 * so the platform can be tested before you have your own Insta360 files.
 */
import sharp from 'sharp';

const rad = (d) => (d * Math.PI) / 180;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;

function hash(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = (h ^ (h >>> 13)) | 0;
  h = Math.imul(h, 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
const noise = (x, z) => {
  const xi = Math.floor(x), zi = Math.floor(z), fx = x - xi, fz = z - zi;
  return lerp(lerp(hash(xi, zi), hash(xi + 1, zi), fx), lerp(hash(xi, zi + 1), hash(xi + 1, zi + 1), fx), fz);
};

export async function renderPanorama(cfg, outPath, width = 2048) {
  const W = width, H = width / 2, EYE = 1.7;
  const raw = Buffer.alloc(W * H * 3);
  const night = !!cfg.night;
  const sky = night
    ? { top: [6, 9, 22], mid: [14, 22, 48], hor: [44, 58, 96] }
    : { top: [28, 50, 108], mid: [128, 98, 158], hor: [255, 176, 120] };
  const fog = night ? [26, 34, 60] : [226, 188, 162];
  const sunYaw = cfg.sunYaw ?? 262, sunElev = cfg.sunElev ?? 7;
  const boxes = cfg.boxes || [], trees = cfg.trees || [], lamps = cfg.lamps || [];
  const paths = (cfg.paths || []).map((y) => ({ dx: Math.sin(rad(y)), dz: -Math.cos(rad(y)) }));
  const water = cfg.water
    ? { dx: Math.sin(rad(cfg.water.yaw)), dz: -Math.cos(rad(cfg.water.yaw)), start: cfg.water.start }
    : null;
  const lightYaw = night ? 140 : sunYaw;
  const lightElev = night ? 38 : sunElev;

  const poles = lamps.map((l) => ({ x: l.x, z: l.z, w: 0.16, d: 0.16, h: l.h || 3.4, color: [40, 44, 54], pole: true }));
  const allBoxes = boxes.concat(poles);

  const cols = new Array(W);
  for (let x = 0; x < W; x++) {
    const yaw = (x / W) * 2 * Math.PI + Math.PI / 2;
    const dx = Math.sin(yaw), dz = -Math.cos(yaw);
    let best = null;

    for (const b of allBoxes) {
      const faces = [];
      if (dx !== 0) {
        const tA = (b.x - b.w / 2) / dx, tB = (b.x + b.w / 2) / dx;
        for (const t of [tA, tB]) {
          if (t > 0) {
            const z = dz * t;
            if (z >= b.z - b.d / 2 && z <= b.z + b.d / 2) faces.push({ t, u: z - (b.z - b.d / 2), n: [t === tA ? -1 : 1, 0] });
          }
        }
      }
      if (dz !== 0) {
        const tA = (b.z - b.d / 2) / dz, tB = (b.z + b.d / 2) / dz;
        for (const t of [tA, tB]) {
          if (t > 0) {
            const xx = dx * t;
            if (xx >= b.x - b.w / 2 && xx <= b.x + b.w / 2) faces.push({ t, u: xx - (b.x - b.w / 2), n: [0, t === tA ? -1 : 1] });
          }
        }
      }
      for (const f of faces) {
        if (best && f.t >= best.t) continue;
        const y0 = b.y0 || 0;
        const sh = night ? 0.34 : 0.5 + 0.5 * Math.max(0, f.n[0] * Math.sin(rad(sunYaw)) + f.n[1] * -Math.cos(rad(sunYaw)));
        best = {
          kind: 'box', t: f.t, box: b, u: f.u,
          e0: Math.atan2(y0 - EYE, f.t), e1: Math.atan2(y0 + b.h - EYE, f.t),
          c: b.color.map((v) => v * (b.pole ? 1 : sh))
        };
      }
    }

    for (const tr of trees) {
      const b2 = dx * tr.x + dz * tr.z;
      if (b2 <= 0) continue;
      const c2 = tr.x * tr.x + tr.z * tr.z;
      const disc = b2 * b2 - (c2 - tr.r * tr.r);
      if (disc <= 0) continue;
      const t = b2 - Math.sqrt(disc);
      if (best && t >= best.t) continue;
      const dc = Math.sqrt(b2 * b2 + (tr.h - EYE) ** 2);
      const ec = Math.atan2(tr.h - EYE, b2);
      const er = Math.asin(clamp(tr.r / dc, 0, 0.99));
      best = { kind: 'tree', t: b2, e0: ec - er, e1: ec + er, ec, er, c: tr.color };
    }

    cols[x] = { dx, dz, yaw, best };
  }

  for (let y = 0; y < H; y++) {
    const el = (0.5 - y / H) * Math.PI, tanE = Math.tan(el);
    for (let x = 0; x < W; x++) {
      const c = cols[x], o = c.best;
      let r, g, b;

      if (o && el >= o.e0 && el <= o.e1) {
        if (o.kind === 'box') {
          const bx = o.box, wy = EYE + tanE * o.t;
          let cr = o.c[0], cg = o.c[1], cb = o.c[2];
          if (bx.sign && wy > bx.h - 1.1 && wy < bx.h - 0.25) {
            cr = bx.sign[0]; cg = bx.sign[1]; cb = bx.sign[2];
          } else if (bx.win && wy > 0.9 && wy < (bx.y0 || 0) + bx.h - 0.5) {
            const cu = Math.floor(o.u / 2.3), cv = Math.floor(wy / 2.9);
            const fu = (o.u / 2.3) % 1, fv = (wy / 2.9) % 1;
            if (fu > 0.18 && fu < 0.82 && fv > 0.25 && fv < 0.8) {
              if (night) {
                if (hash(cu * 7 + cv * 13, cu + 3) < 0.45) { cr = 255; cg = 192; cb = 112; }
                else { cr = 14; cg = 17; cb = 26; }
              } else {
                cr = cr * 0.45 + sky.mid[0] * 0.32;
                cg = cg * 0.45 + sky.mid[1] * 0.32;
                cb = cb * 0.5 + sky.mid[2] * 0.38;
              }
            }
          }
          const f = 1 - Math.exp(-o.t / 540);
          r = lerp(cr, fog[0], f); g = lerp(cg, fog[1], f); b = lerp(cb, fog[2], f);
        } else {
          const v = (el - o.ec) / o.er, nz = Math.sqrt(Math.max(0, 1 - v * v));
          const sh = (night ? 0.24 : 0.5) + 0.55 * nz;
          r = o.c[0] * sh; g = o.c[1] * sh; b = o.c[2] * sh;
        }
      } else if (el > 0) {
        const e = (el * 180) / Math.PI;
        const t1 = clamp(e / 26, 0, 1), t2 = clamp((e - 14) / 58, 0, 1);
        r = lerp(lerp(sky.hor[0], sky.mid[0], t1), sky.top[0], t2);
        g = lerp(lerp(sky.hor[1], sky.mid[1], t1), sky.top[1], t2);
        b = lerp(lerp(sky.hor[2], sky.mid[2], t1), sky.top[2], t2);
        const cl = Math.cos(el), dy = Math.sin(el);
        const lx = Math.sin(rad(lightYaw)) * Math.cos(rad(lightElev));
        const ly = Math.sin(rad(lightElev));
        const lz = -Math.cos(rad(lightYaw)) * Math.cos(rad(lightElev));
        const dot = c.dx * cl * lx + dy * ly + c.dz * cl * lz;
        const glow = Math.exp((dot - 1) * (night ? 150 : 70));
        r += (night ? 190 : 255) * glow * 0.45;
        g += (night ? 205 : 214) * glow * 0.45;
        b += (night ? 240 : 150) * glow * 0.45;
        if (dot > 0.99965) { r = night ? 236 : 255; g = night ? 240 : 246; b = night ? 250 : 226; }
        if (night && e > 4) {
          const h = hash(Math.floor(((c.yaw * 180) / Math.PI) * 2.2), Math.floor(e * 2.2));
          if (h > 0.9974) { const tw = (h - 0.9974) / 0.0026; r += 200 * tw; g += 210 * tw; b += 230 * tw; }
        }
      } else {
        const t = Math.min(6000, EYE / Math.max(1e-4, -tanE));
        const wx = c.dx * t, wz = c.dz * t;
        let isWater = cfg.ground === 'water';
        if (water && wx * water.dx + wz * water.dz > water.start) isWater = true;
        let cr, cg, cb;

        if (isWater) {
          const d = clamp(t / 380, 0, 1), base = night ? [10, 16, 30] : [16, 58, 88];
          cr = lerp(base[0], sky.hor[0] * 0.8, d * 0.75);
          cg = lerp(base[1], sky.hor[1] * 0.8, d * 0.75);
          cb = lerp(base[2], sky.hor[2] * 0.85, d * 0.8);
          const rip = (noise(wx * 0.5, wz * 0.5) * 0.5 + noise(wx * 2.1, wz * 2.1) * 0.5 - 0.5) * (night ? 18 : 26);
          cr += rip; cg += rip; cb += rip;
          const pyaw = (((Math.atan2(wx, -wz) * 180) / Math.PI) % 360 + 360) % 360;
          const dY = Math.abs(((pyaw - lightYaw + 540) % 360) - 180);
          const gl = Math.exp(-((dY / (2.5 + t * 0.02)) ** 2));
          const spark = Math.pow(noise(wx * 3.3, wz * 3.3), 3) * 2.4;
          const li = (night ? 0.5 : 0.9) * gl * spark * (1 - d * 0.4);
          cr += (night ? 210 : 255) * li; cg += (night ? 225 : 210) * li; cb += (night ? 255 : 140) * li;
        } else if (cfg.ground === 'boards') {
          const d = { dx: Math.sin(rad(cfg.boardYaw || 0)), dz: -Math.cos(rad(cfg.boardYaw || 0)) };
          const al = wx * d.dx + wz * d.dz, bd = Math.floor(al / 0.34), f = al / 0.34 - bd;
          const tone = 0.86 + 0.22 * hash(bd, 3), base = cfg.base || [140, 117, 90];
          cr = base[0] * tone; cg = base[1] * tone; cb = base[2] * tone;
          if (f < 0.09) { cr *= 0.55; cg *= 0.55; cb *= 0.55; }
        } else if (cfg.ground === 'grass') {
          const m = noise(wx * 0.35, wz * 0.35) * 0.7 + noise(wx * 1.8, wz * 1.8) * 0.3;
          const base = cfg.base || [72, 110, 68], acc = cfg.accent || [98, 136, 84];
          cr = lerp(base[0], acc[0], m); cg = lerp(base[1], acc[1], m); cb = lerp(base[2], acc[2], m);
        } else if (cfg.ground === 'asphalt') {
          const nv = noise(wx * 0.8, wz * 0.8), base = cfg.base || [22, 25, 34];
          cr = base[0] + nv * 10; cg = base[1] + nv * 10; cb = base[2] + nv * 12;
        } else {
          const ts = cfg.tile || 3, tx = Math.floor(wx / ts), tz = Math.floor(wz / ts);
          const fx = wx / ts - tx, fz = wz / ts - tz, tone = 0.92 + 0.16 * hash(tx, tz);
          const base = cfg.base || [143, 133, 118];
          cr = base[0] * tone; cg = base[1] * tone; cb = base[2] * tone;
          if (fx < 0.045 || fz < 0.045) { cr *= 0.72; cg *= 0.72; cb *= 0.72; }
        }

        if (!isWater) {
          for (const p of paths) {
            const al = wx * p.dx + wz * p.dz;
            if (al > 0) {
              const side = Math.abs(wx * p.dz - wz * p.dx), half = (cfg.pathW || 2.6) / 2;
              if (side < half) {
                const e = clamp((half - side) / 0.6, 0, 1), pc = cfg.pathColor || [176, 164, 142];
                cr = lerp(cr, pc[0], e); cg = lerp(cg, pc[1], e); cb = lerp(cb, pc[2], e);
              }
            }
          }
        }
        const f = 1 - Math.exp(-t / 700);
        r = lerp(cr, fog[0], f); g = lerp(cg, fog[1], f); b = lerp(cb, fog[2], f);
      }

      const i = (y * W + x) * 3;
      raw[i] = clamp(r, 0, 255);
      raw[i + 1] = clamp(g, 0, 255);
      raw[i + 2] = clamp(b, 0, 255);
    }
  }

  await sharp(raw, { raw: { width: W, height: H, channels: 3 } })
    .jpeg({ quality: 90, progressive: true, chromaSubsampling: '4:4:4' })
    .toFile(outPath);
  return { width: W, height: H };
}
'@

W 'scripts/seed.js' @'
/**
 * Creates two sample tours with genuine equirectangular panoramas, using the
 * exact same pipeline as real uploads (Sharp derivatives + SQLite rows).
 *
 *   npm run seed              add samples (skips if they already exist)
 *   npm run seed -- --force   add another copy
 *
 * Rendering 8 panoramas takes roughly 30-90 seconds depending on your CPU.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { config, ensureDirs } from '../server/config.js';
import { db, initDatabase, newId, now, persist } from '../server/database/db.js';
import { processPanorama } from '../server/services/image.service.js';
import { bearingDegrees, distanceMeters } from '../server/services/geo.service.js';
import { renderPanorama } from './panorama-generator.js';

ensureDirs();
initDatabase();

const force = process.argv.includes('--force');
if (db.prepare("SELECT COUNT(*) AS n FROM tours WHERE tags LIKE '%sample%'").get().n && !force) {
  console.log('  Sample tours already exist. Use "npm run seed -- --force" to add another copy.');
  persist();
  process.exit(0);
}

const A = [
  { lat: 37.79548, lng: -122.39370 }, { lat: 37.79665, lng: -122.39430 },
  { lat: 37.79788, lng: -122.39523 }, { lat: 37.79724, lng: -122.39610 },
  { lat: 37.79890, lng: -122.39605 }
];
const B = [
  { lat: 35.69380, lng: 139.70340 }, { lat: 35.69455, lng: 139.70412 }, { lat: 35.69532, lng: 139.70489 }
];

const lampsAlong = (yaws, d) => yaws.flatMap((y) => [d, d * 2].map((dd) => ({
  x: Math.sin((y * Math.PI) / 180) * dd, z: -Math.cos((y * Math.PI) / 180) * dd, h: 3.4
})));

function cfgFor(key, paths) {
  if (key === 'a1') {
    const boxes = [
      { x: -26, z: -14, w: 7, d: 7, h: 34, color: [201, 190, 166], win: true },
      { x: -26, z: -14, w: 4.4, d: 4.4, y0: 34, h: 5, color: [178, 166, 140] }
    ];
    for (let i = 0; i < 7; i++) {
      boxes.push({ x: -36 + i * 12, z: 23, w: 10, d: 8, h: 11 + (i % 3) * 2,
        color: [[186, 164, 138], [176, 156, 134], [196, 176, 150]][i % 3], win: true });
    }
    return { ground: 'plaza', base: [143, 133, 118], tile: 3, paths, pathColor: [176, 164, 142], pathW: 3, boxes,
      trees: [{ x: 18, z: -6, h: 5, r: 2.6, color: [66, 112, 76] }, { x: 24, z: 4, h: 5.6, r: 3, color: [58, 104, 70] }],
      lamps: lampsAlong(paths, 11) };
  }
  if (key === 'a2') {
    const boxes = [];
    for (let i = 0; i < 6; i++) {
      boxes.push({ x: -21, z: -30 + i * 12, w: 9, d: 10, h: 11 + (i % 3) * 3,
        color: [[124, 134, 158], [110, 122, 148], [136, 144, 164]][i % 3], win: true });
    }
    const lamps = [];
    for (let z = -24; z <= 24; z += 12) lamps.push({ x: 6, z, h: 3.5 });
    return { ground: 'boards', base: [140, 117, 90], boardYaw: 15, paths, pathColor: [168, 146, 116], pathW: 3.2,
      water: { yaw: 90, start: 14 }, boxes, lamps, trees: [{ x: -8, z: 16, h: 4.6, r: 2.2, color: [64, 110, 74] }] };
  }
  if (key === 'a3') {
    return { ground: 'water', paths: [],
      lamps: [{ x: Math.sin((95 * Math.PI) / 180) * 48, z: -Math.cos((95 * Math.PI) / 180) * 48, h: 3.2 }],
      boxes: [
        { x: 30, z: -14, w: 10, d: 4, h: 2, color: [238, 242, 246] },
        { x: 30, z: -14, w: 4, d: 2.8, y0: 2.2, h: 1.5, color: [204, 214, 224] },
        { x: 46, z: 12, w: 12, d: 4.4, h: 2.2, color: [230, 234, 240] }
      ] };
  }
  if (key === 'a4') {
    const boxes = [], awn = [[196, 66, 66], [46, 142, 122], [220, 152, 62], [158, 88, 168]], trees = [];
    for (let i = 0; i < 5; i++) {
      const z = -18 + i * 9;
      boxes.push({ x: -13, z, w: 8, d: 8.4, h: 8.5, color: [[193, 142, 108], [176, 122, 98], [160, 134, 112]][i % 3], win: true });
      boxes.push({ x: -8.1, z, w: 1.8, d: 6.4, y0: 2.7, h: 0.5, color: awn[i % 4] });
    }
    for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) {
      const x = 1 + i * 3.6, z = -5 + j * 4.2;
      boxes.push({ x, z, w: 0.95, d: 0.95, h: 0.75, color: [72, 62, 54] });
      trees.push({ x, z, h: 2.7, r: 1.35, color: (i + j) % 2 ? [204, 72, 72] : [52, 150, 130] });
    }
    return { ground: 'plaza', base: [154, 142, 124], tile: 1.8, paths, pathColor: [180, 168, 148], pathW: 2.6,
      boxes, trees, lamps: [{ x: 6, z: 8, h: 3 }, { x: -4, z: -8, h: 3 }] };
  }
  if (key === 'a5') {
    return { ground: 'grass', base: [72, 110, 68], accent: [98, 136, 84], paths, pathColor: [178, 164, 138], pathW: 2.6,
      water: { yaw: 0, start: 27 },
      trees: [
        { x: -14, z: -4, h: 6, r: 3, color: [60, 106, 72] }, { x: -19, z: 6, h: 6.6, r: 3.4, color: [54, 100, 66] },
        { x: -10, z: 11, h: 5.2, r: 2.5, color: [72, 118, 80] }, { x: 14, z: -14, h: 5.6, r: 2.7, color: [66, 112, 76] }
      ],
      boxes: [{ x: 8, z: 2, w: 2.2, d: 0.7, h: 0.55, color: [96, 76, 58] }],
      lamps: lampsAlong(paths.slice(0, 1), 10) };
  }
  if (key === 'b1' || key === 'b2') {
    const narrow = key === 'b2';
    const cols = [[231, 76, 60], [243, 156, 18], [22, 160, 133], [142, 68, 173], [230, 126, 34], [41, 128, 185]];
    const boxes = [], lamps = [];
    for (let i = 0; i < 5; i++) {
      const z = (narrow ? 5 : 6) + i * (narrow ? 6.5 : 8);
      for (const sx of [narrow ? -4.8 : -6.5, narrow ? 4.8 : 6.5]) {
        const ci = (i + (sx > 0 ? 1 : 0)) % cols.length;
        boxes.push({ x: sx, z, w: narrow ? 3.8 : 4.5, d: 3.2, h: 2.7, color: [48, 44, 58], sign: cols[ci] });
        boxes.push({ x: sx, z, w: narrow ? 4.4 : 5.1, d: 3.6, y0: 2.5, h: 0.5, color: cols[ci] });
      }
    }
    for (let z = 4; z <= 38; z += 6) {
      for (const sx of [narrow ? -3.4 : -4.4, narrow ? 3.4 : 4.4]) lamps.push({ x: sx, z, h: 3.1 });
    }
    return { night: true, ground: 'asphalt', base: narrow ? [18, 20, 28] : [22, 25, 34], paths,
      pathColor: [40, 44, 58], pathW: narrow ? 3.4 : 4, boxes, lamps };
  }
  const lamps = [];
  for (let i = 0; i < 6; i++) {
    const y = ((15 - 50 + i * 20) * Math.PI) / 180;
    lamps.push({ x: Math.sin(y) * 10, z: -Math.cos(y) * 10, h: 3 });
  }
  return { night: true, ground: 'plaza', base: [58, 62, 76], tile: 2.2, paths, pathColor: [80, 84, 100], pathW: 3,
    water: { yaw: 15, start: 12 }, lamps, trees: [{ x: -13, z: -4, h: 5, r: 2.4, color: [40, 70, 52] }] };
}

async function createAsset(filePath, name) {
  const id = newId('a_');
  const p = await processPanorama({ filePath, id, force: false });
  const info = p.info;
  db.prepare(`INSERT INTO assets (
    id, original_name, mime, bytes, width, height, ratio, format,
    original_file, texture_file, preview_file, thumb_file,
    texture_width, texture_height, preview_width, preview_height,
    heading, gps_lat, gps_lng, projection, forced, created_at
  ) VALUES (
    @id,@original_name,@mime,@bytes,@width,@height,@ratio,@format,
    @original_file,@texture_file,@preview_file,@thumb_file,
    @texture_width,@texture_height,@preview_width,@preview_height,
    @heading,@gps_lat,@gps_lng,@projection,@forced,@created_at
  )`).run({
    id, original_name: name, mime: 'image/jpeg', bytes: info.bytes,
    width: info.width, height: info.height, ratio: Number(info.ratio.toFixed(6)), format: 'jpeg',
    original_file: p.originalFile, texture_file: p.textureFile, preview_file: p.previewFile, thumb_file: p.thumbFile,
    texture_width: p.textureWidth, texture_height: p.textureHeight,
    preview_width: p.previewWidth, preview_height: p.previewHeight,
    heading: null, gps_lat: null, gps_lng: null, projection: 'equirectangular', forced: 0, created_at: now()
  });
  return id;
}

async function buildTour(meta) {
  const tourId = newId('t_');
  const t = now();
  db.prepare(`INSERT INTO tours (id,title,description,location,tags,color,status,cover_scene,sort_order,created_at,updated_at)
              VALUES (?,?,?,?,?,?,'published',NULL,0,?,?)`)
    .run(tourId, meta.title, meta.description, meta.location, meta.tags, meta.color, t, t);

  const sceneIds = [];
  for (let i = 0; i < meta.scenes.length; i++) {
    const spec = meta.scenes[i];
    const paths = meta.coords
      .map((c, j) => ({ c, j }))
      .filter(({ c, j }) => j !== i && distanceMeters(meta.coords[i], c) <= 230)
      .map(({ c }) => Number(bearingDegrees(meta.coords[i], c).toFixed(1)));

    const tmp = path.join(config.dirs.tmp, `seed_${tourId}_${i}.jpg`);
    console.log(`  rendering ${spec.title} ...`);
    await renderPanorama(cfgFor(spec.key, paths), tmp, 2048);
    const assetId = await createAsset(tmp, `${spec.key}_${spec.title.replace(/\s+/g, '_')}.jpg`);
    await fs.rm(tmp, { force: true });

    const sceneId = newId('s_');
    const heading = paths[0] ?? 0;
    db.prepare(`INSERT INTO scenes (id,tour_id,asset_id,title,description,lat,lng,heading,pitch,fov,north_offset,position,created_at,updated_at)
                VALUES (?,?,?,?,?,?,?,?,0,75,?,?,?,?)`)
      .run(sceneId, tourId, assetId, spec.title, spec.description,
        meta.coords[i].lat, meta.coords[i].lng, heading,
        ((0.75 - heading / 360) % 1 + 1) % 1, i, t, t);
    sceneIds.push(sceneId);
  }

  const scenes = db.prepare('SELECT * FROM scenes WHERE tour_id = ? ORDER BY position').all(tourId);
  let pairs = 0;
  for (let i = 0; i < scenes.length; i++) {
    for (let j = i + 1; j < scenes.length; j++) {
      const a = scenes[i], b = scenes[j];
      if (distanceMeters(a, b) > 230) continue;
      const mk = (from, to) => {
        const tt = now();
        db.prepare(`INSERT INTO hotspots (id,scene_id,type,yaw,pitch,label,body,target_scene,image_url,link_url,created_at,updated_at)
                    VALUES (?,?,'nav',?,-12,?,'',?,'','',?,?)`)
          .run(newId('h_'), from.id, Number(bearingDegrees(from, to).toFixed(1)), to.title, to.id, tt, tt);
      };
      mk(a, b); mk(b, a); pairs++;
    }
  }

  for (const info of meta.infos || []) {
    const tt = now();
    db.prepare(`INSERT INTO hotspots (id,scene_id,type,yaw,pitch,label,body,target_scene,image_url,link_url,created_at,updated_at)
                VALUES (?,?,'info',?,?,?,?,NULL,?,?,?,?)`)
      .run(newId('h_'), sceneIds[info.scene], info.yaw, info.pitch, info.label, info.body,
        info.image || '', info.link || '', tt, tt);
  }

  db.prepare('UPDATE tours SET cover_scene = ?, updated_at = ? WHERE id = ?').run(sceneIds[0], now(), tourId);
  console.log(`  tour "${meta.title}": ${scenes.length} scenes, ${pairs} linked pairs`);
}

console.log('  Rendering sample panoramas. This takes about 30-90 seconds...\n');

await buildTour({
  title: 'Embarcadero Golden Hour',
  description: 'A five-stop waterfront walk from the Ferry Building to the harbour lookout. These sample panoramas are rendered locally so you can test navigation, hotspots, Motion Mode and VR before uploading your own Insta360 X4 files.',
  location: 'San Francisco, USA',
  tags: 'sample,waterfront,golden hour',
  color: '#3fd9ff',
  coords: A,
  scenes: [
    { key: 'a1', title: 'Ferry Plaza', description: 'The tour begins under the clock tower, where the plaza tiles still hold the day’s warmth.' },
    { key: 'a2', title: 'Pier Promenade', description: 'Boardwalk planks run north along the water while ferries slide past on the evening tide.' },
    { key: 'a3', title: 'Pier Deck', description: 'A timber deck reaches into the bay. Glitter on the water, the city at your back.' },
    { key: 'a4', title: 'Cafe Terrace', description: 'Small tables, striped awnings and the smell of espresso between the facades.' },
    { key: 'a5', title: 'Harbour Lookout', description: 'The path climbs through grass and palms to a quiet railing above the harbour.' }
  ],
  infos: [
    { scene: 0, yaw: 298, pitch: 13, label: 'Ferry Clock Tower', body: 'The 75 m clock tower is modelled after Seville’s Giralda. Its four dials face the bay, the city and the ferries in between.' },
    { scene: 2, yaw: 60, pitch: -4, label: 'Across the bay', body: 'Alcatraz sits two kilometres offshore. On clear evenings the island light blinks across the glitter path.', link: 'https://www.nps.gov/alca/index.htm' }
  ]
});

await buildTour({
  title: 'Shinjuku Lantern Nights',
  description: 'Neon-soaked market lanes after dark. Follow the lanterns from the gate to the riverside. Sample tour rendered locally.',
  location: 'Tokyo, Japan',
  tags: 'sample,night,city',
  color: '#ff7ac2',
  coords: B,
  scenes: [
    { key: 'b1', title: 'Market Gate', description: 'Neon signs buzz awake at the mouth of the market. Follow the warm light inward.' },
    { key: 'b2', title: 'Lantern Alley', description: 'Lanterns strung overhead make the alley glow like embers after rain.' },
    { key: 'b3', title: 'Riverside Steps', description: 'The lane opens onto dark water; the skyline mirrors itself between the ripples.' }
  ],
  infos: [
    { scene: 1, yaw: 40, pitch: 12, label: 'Lantern canopy', body: 'Hand-lit lanterns above the alley. House rule: always follow the warmest glow.' }
  ]
});

persist();
console.log('\n  Seed complete. Start the server with "npm start".');
process.exit(0);
'@

# ============================================================================
# End of Block 3/6. 32 files written so far.
# Append Block 4 below this line in the SAME build-orbis360.ps1 file.
# ============================================================================# ============================================================================
# Block 4/6 - client core: utils, api, ui, router + orbis360-motion-vr.js
# ============================================================================

W 'client/assets/js/utils.js' @'
import * as THREE from 'three';

export const qs = (s, r = document) => r.querySelector(s);
export const qsa = (s, r = document) => [...r.querySelectorAll(s)];

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => (
  { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
));

export const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
export const lerp = (a, b, t) => a + (b - a) * t;
export const rad = (d) => (d * Math.PI) / 180;
export const deg = (r) => (r * 180) / Math.PI;
export const norm360 = (d) => ((d % 360) + 360) % 360;
export const angDelta = (a, b) => ((b - a + 540) % 360) - 180;

export const isMobile = /Android|iPhone|iPad|iPod|Mobi/i.test(navigator.userAgent) ||
  Math.min(screen.width, screen.height) < 700;
export const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

export function debounce(fn, ms) {
  let t;
  return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

/** Programmatic DOM builder — no HTML string wrapping. */
export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [key, val] of Object.entries(attrs)) {
    if (val == null) continue;
    if (key === 'class') node.className = val;
    else if (key === 'text') node.textContent = val;
    else if (key === 'style' && typeof val === 'object') Object.assign(node.style, val);
    else if (key === 'dataset' && typeof val === 'object') Object.assign(node.dataset, val);
    else if (key.startsWith('on') && typeof val === 'function') node.addEventListener(key.slice(2).toLowerCase(), val);
    else node.setAttribute(key, val);
  }
  for (const child of [].concat(children)) {
    if (child == null) continue;
    node.appendChild(typeof child === 'string' ? document.createTextNode(child) : child);
  }
  return node;
}

export function fmtBytes(b) {
  if (b == null) return '—';
  if (b < 1024) return `${b} B`;
  if (b < 1048576) return `${(b / 1024).toFixed(0)} KB`;
  if (b < 1073741824) return `${(b / 1048576).toFixed(1)} MB`;
  return `${(b / 1073741824).toFixed(2)} GB`;
}
export const fmtDims = (w, h) => (w ? `${w}×${h} · ${(w * h / 1e6).toFixed(1)} MP` : '—');
export const fmtCoord = (lat, lng) =>
  lat == null || lng == null ? 'No location' : `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
export const fmtDist = (m) => (m < 1000 ? `${Math.round(m)} m` : `${(m / 1000).toFixed(2)} km`);

export function timeAgo(t) {
  const s = (Date.now() - t) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

export function distanceMeters(a, b) {
  const R = 6371000;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export function bearingDegrees(a, b) {
  const y = Math.sin(rad(b.lng - a.lng)) * Math.cos(rad(b.lat));
  const x = Math.cos(rad(a.lat)) * Math.sin(rad(b.lat)) -
    Math.sin(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.cos(rad(b.lng - a.lng));
  return norm360(deg(Math.atan2(y, x)));
}

export function destPoint(lat, lng, br, dist) {
  return [
    lat + (dist * Math.cos(rad(br))) / 111320,
    lng + (dist * Math.sin(rad(br))) / (111320 * Math.cos(rad(lat)))
  ];
}

export const cardinal = (d) =>
  ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.round(norm360(d) / 45) % 8];

/**
 * Orbis360 camera convention:
 *   dir = ( sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch) )
 * which equals Euler(pitch, -yaw, 0, 'YXZ').
 */
export function quatFromYawPitch(yawDeg, pitchDeg) {
  return new THREE.Quaternion().setFromEuler(
    new THREE.Euler(rad(pitchDeg || 0), -rad(yawDeg || 0), 0, 'YXZ')
  );
}

export function dirFromYawPitch(yawRad, pitchRad, out = new THREE.Vector3()) {
  return out.set(
    Math.sin(yawRad) * Math.cos(pitchRad),
    Math.sin(pitchRad),
    -Math.cos(yawRad) * Math.cos(pitchRad)
  );
}

export async function copyText(text) {
  try { await navigator.clipboard.writeText(text); return true; }
  catch {
    const ta = el('textarea', { style: { position: 'fixed', opacity: '0' } });
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch { /* ignore */ }
    ta.remove();
    return ok;
  }
}

export function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob);
  const a = el('a', { href: url, download: name });
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

/** Persistent UI preferences (theme, viewer sliders, sound). */
const PREF_KEY = 'orbis360.prefs';
export const prefs = (() => {
  const defaults = {
    theme: 'dark', sound: true, minimap: true, hintSeen: false,
    autoRotate: !reduceMotion, drift: 14, guides: false, hotspots: true,
    quality: 'auto', brightness: 100, saturation: 100,
    motionSmoothing: 12, vrIPD: 0.064
  };
  let data = { ...defaults };
  try { data = { ...defaults, ...JSON.parse(localStorage.getItem(PREF_KEY) || '{}') }; }
  catch { /* ignore */ }
  return {
    get: (k) => data[k],
    all: () => ({ ...data }),
    set(k, v) {
      data[k] = v;
      try { localStorage.setItem(PREF_KEY, JSON.stringify(data)); } catch { /* ignore */ }
    }
  };
})();
'@

W 'client/assets/js/api.js' @'
/** Thin REST client for the local Express API. */
const BASE = '/api';

export class ApiError extends Error {
  constructor(message, code, status, details) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

async function request(path, { method = 'GET', body, signal } = {}) {
  const opts = { method, signal, headers: {} };
  if (body !== undefined) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  let res;
  try {
    res = await fetch(BASE + path, opts);
  } catch (err) {
    if (err.name === 'AbortError') throw err;
    throw new ApiError('Cannot reach the local server. Is "npm start" running?', 'NETWORK', 0);
  }
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { /* non-JSON */ }
  if (!res.ok) {
    const e = data?.error || {};
    throw new ApiError(e.message || `Request failed (${res.status})`, e.code || 'HTTP', res.status, e.details);
  }
  return data;
}

export const api = {
  health: () => request('/health'),
  stats: () => request('/stats'),

  tours: {
    list: ({ q = '', status = 'all', sort = 'updated' } = {}) =>
      request(`/tours?q=${encodeURIComponent(q)}&status=${status}&sort=${sort}`),
    get: (id) => request(`/tours/${id}`),
    create: (body) => request('/tours', { method: 'POST', body }),
    update: (id, body) => request(`/tours/${id}`, { method: 'PATCH', body }),
    remove: (id, deleteFiles = false) =>
      request(`/tours/${id}${deleteFiles ? '?deleteFiles=1' : ''}`, { method: 'DELETE' }),
    reorder: (id, order) => request(`/tours/${id}/scenes/reorder`, { method: 'POST', body: { order } }),
    autoLink: (id, maxDistance) => request(`/tours/${id}/auto-link`, { method: 'POST', body: { maxDistance } })
  },

  scenes: {
    get: (id) => request(`/scenes/${id}`),
    create: (body) => request('/scenes', { method: 'POST', body }),
    update: (id, body) => request(`/scenes/${id}`, { method: 'PATCH', body }),
    remove: (id) => request(`/scenes/${id}`, { method: 'DELETE' })
  },

  hotspots: {
    list: (sceneId) => request(`/hotspots?sceneId=${encodeURIComponent(sceneId)}`),
    create: (body) => request('/hotspots', { method: 'POST', body }),
    update: (id, body) => request(`/hotspots/${id}`, { method: 'PATCH', body }),
    remove: (id) => request(`/hotspots/${id}`, { method: 'DELETE' })
  },

  assets: {
    list: () => request('/assets'),
    get: (id) => request(`/assets/${id}`),
    remove: (id) => request(`/assets/${id}`, { method: 'DELETE' }),

    /** Multipart upload with real progress events. */
    upload(files, { force = false, onProgress } = {}) {
      return new Promise((resolve, reject) => {
        const fd = new FormData();
        for (const f of files) fd.append('panoramas', f, f.name);
        if (force) fd.append('force', '1');
        const xhr = new XMLHttpRequest();
        xhr.open('POST', BASE + '/assets');
        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable && onProgress) onProgress(e.loaded / e.total);
        };
        xhr.onload = () => {
          let data = null;
          try { data = JSON.parse(xhr.responseText); } catch { /* ignore */ }
          if (xhr.status >= 200 && xhr.status < 300) return resolve(data);
          if (data?.results) return resolve(data);
          reject(new ApiError(data?.error?.message || `Upload failed (${xhr.status})`,
            data?.error?.code || 'UPLOAD', xhr.status, data?.error?.details));
        };
        xhr.onerror = () => reject(new ApiError('Upload failed: network error.', 'NETWORK', 0));
        xhr.send(fd);
      });
    }
  }
};
'@

W 'client/assets/js/ui.js' @'
import { el, esc, qs, qsa } from './utils.js';

/* ---------------- icons ---------------- */
const PATHS = {
  menu: ['M3 6h18M3 12h18M3 18h18'],
  x: ['M18 6L6 18', 'M6 6l12 12'],
  sun: ['M12 2v2', 'M12 20v2', 'M4.93 4.93l1.41 1.41', 'M17.66 17.66l1.41 1.41', 'M2 12h2', 'M20 12h2', 'M6.34 17.66l-1.41 1.41', 'M19.07 4.93l-1.41 1.41'],
  moon: ['M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'],
  vol: ['M11 5L6 9H2v6h4l5 4V5z', 'M15.54 8.46a5 5 0 0 1 0 7.07'],
  volx: ['M11 5L6 9H2v6h4l5 4V5z', 'M23 9l-6 6', 'M17 9l6 6'],
  upload: ['M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4', 'M17 8l-5-5-5 5', 'M12 3v12'],
  download: ['M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4', 'M7 10l5 5 5-5', 'M12 15V3'],
  pin: ['M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z'],
  map: ['M1 6v16l7-4 8 4 7-4V2l-7 4-8-4-7 4z', 'M8 2v16', 'M16 6v16'],
  compass: ['M16.24 7.76l-2.12 6.36-6.36 2.12 2.12-6.36 6.36-2.12z'],
  max: ['M8 3H5a2 2 0 0 0-2 2v3', 'M21 8V5a2 2 0 0 0-2-2h-3', 'M3 16v3a2 2 0 0 0 2 2h3', 'M16 21h3a2 2 0 0 0 2-2v-3'],
  min: ['M8 3v3a2 2 0 0 1-2 2H3', 'M21 8h-3a2 2 0 0 1-2-2V3', 'M3 16h3a2 2 0 0 1 2 2v3', 'M16 21v-3a2 2 0 0 1 2-2h3'],
  plus: ['M12 5v14', 'M5 12h14'],
  minus: ['M5 12h14'],
  chevL: ['M15 18l-6-6 6-6'],
  chevR: ['M9 18l6-6-6-6'],
  chevU: ['M18 15l-6-6-6 6'],
  chevD: ['M6 9l6 6 6-6'],
  back: ['M19 12H5', 'M12 19l-7-7 7-7'],
  info: ['M12 16v-4', 'M12 8h.01'],
  edit: ['M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7', 'M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z'],
  sliders: ['M4 21v-7', 'M4 10V3', 'M12 21v-9', 'M12 8V3', 'M20 21v-5', 'M20 12V3', 'M1 14h6', 'M9 8h6', 'M17 16h6'],
  trash: ['M3 6h18', 'M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6', 'M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'],
  share: ['M8.59 13.51l6.83 3.98', 'M15.41 6.51l-6.82 3.98'],
  link: ['M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71', 'M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'],
  camera: ['M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z'],
  eye: ['M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z'],
  check: ['M20 6L9 17l-5-5'],
  alert: ['M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z', 'M12 9v4', 'M12 17h.01'],
  search: ['M21 21l-4.35-4.35'],
  grid: ['M3 3h7v7H3z', 'M14 3h7v7h-7z', 'M14 14h7v7h-7z', 'M3 14h7v7H3z'],
  zap: ['M13 2L3 14h9l-1 8 10-12h-9l1-8z'],
  image: ['M21 15l-5-5L5 21'],
  folder: ['M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z'],
  rotate: ['M23 4v6h-6', 'M20.49 15a9 9 0 1 1-2.12-9.36L23 10'],
  undo: ['M1 4v6h6', 'M3.51 15a9 9 0 1 0 2.13-9.36L1 10'],
  crosshair: ['M22 12h-4', 'M6 12H2', 'M12 6V2', 'M12 22v-4'],
  move: ['M5 9l-3 3 3 3', 'M9 5l3-3 3 3', 'M15 19l-3 3-3-3', 'M19 9l3 3-3 3', 'M2 12h20', 'M12 2v20'],
  phone: ['M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z', 'M11 18h2'],
  external: ['M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6', 'M15 3h6v6', 'M10 14L21 3'],
  star: ['M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z'],
  grip: ['M9 5h.01', 'M9 12h.01', 'M9 19h.01', 'M15 5h.01', 'M15 12h.01', 'M15 19h.01'],
  play: ['M5 3l14 9-14 9V3z'],
  help: ['M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3', 'M12 17h.01'],
  layers: ['M12 2L2 7l10 5 10-5-10-5z', 'M2 17l10 5 10-5', 'M2 12l10 5 10-5'],
  shuffle: ['M16 3h5v5', 'M4 20L21 3', 'M21 16v5h-5', 'M15 15l6 6', 'M4 4l5 5'],
  nav: ['M3 11l19-9-9 19-2-8-8-2z'],
  globe: ['M2 12h20', 'M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'],
  vr: ['M3 7h18a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-5l-4-4-4 4H3a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z', 'M7 12h2', 'M15 12h2']
};
const CIRCLES = {
  sun: [12, 12, 4], pin: [12, 10, 3], compass: [12, 12, 10], info: [12, 12, 10],
  help: [12, 12, 10], globe: [12, 12, 10], search: [11, 11, 8], camera: [12, 13, 4],
  eye: [12, 12, 3], crosshair: [12, 12, 9],
  share: [[18, 5, 3], [6, 12, 3], [18, 19, 3]],
  image: [[8.5, 8.5, 1.5]]
};
const RECTS = { image: [3, 3, 18, 18, 2] };

function buildSvg(name, size) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('width', size);
  svg.setAttribute('height', size);
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  for (const d of PATHS[name] || PATHS.info) {
    const p = document.createElementNS(ns, 'path');
    p.setAttribute('d', d);
    svg.appendChild(p);
  }
  const circles = CIRCLES[name];
  if (circles) {
    const list = Array.isArray(circles[0]) ? circles : [circles];
    for (const [cx, cy, r] of list) {
      const c = document.createElementNS(ns, 'circle');
      c.setAttribute('cx', cx); c.setAttribute('cy', cy); c.setAttribute('r', r);
      svg.appendChild(c);
    }
  }
  if (RECTS[name]) {
    const [x, y, w, h, rx] = RECTS[name];
    const r = document.createElementNS(ns, 'rect');
    r.setAttribute('x', x); r.setAttribute('y', y);
    r.setAttribute('width', w); r.setAttribute('height', h); r.setAttribute('rx', rx);
    svg.appendChild(r);
  }
  return svg;
}

/** SVG element (programmatic). */
export const iconEl = (name, size = 18) => buildSvg(name, size);
/** SVG markup string (for templates). */
export const icon = (name, size = 18) => buildSvg(name, size).outerHTML;

/* ---------------- sound ---------------- */
export const sound = {
  ctx: null, gain: null, enabled: true,
  init() {
    if (this.ctx || !this.enabled) return;
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.gain = this.ctx.createGain();
      this.gain.gain.value = 0.4;
      this.gain.connect(this.ctx.destination);
    } catch { /* optional */ }
  },
  setEnabled(on) {
    this.enabled = !!on;
    if (this.gain) this.gain.gain.value = on ? 0.4 : 0;
  },
  play(name) {
    if (!this.enabled) return;
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state === 'suspended') this.ctx.resume();
    const t = this.ctx.currentTime;
    const tone = (type, f0, f1, dur, vol, when = 0) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f0, t + when);
      o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + when + dur);
      g.gain.setValueAtTime(0.0001, t + when);
      g.gain.linearRampToValueAtTime(vol, t + when + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + when + dur);
      o.connect(g); g.connect(this.gain);
      o.start(t + when); o.stop(t + when + dur + 0.05);
    };
    if (name === 'whoosh') {
      const len = 0.4;
      const buf = this.ctx.createBuffer(1, this.ctx.sampleRate * len, this.ctx.sampleRate);
      const d = buf.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
      const src = this.ctx.createBufferSource(); src.buffer = buf;
      const f = this.ctx.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 1.2;
      f.frequency.setValueAtTime(280, t);
      f.frequency.exponentialRampToValueAtTime(1400, t + len);
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(0.5, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + len);
      src.connect(f); f.connect(g); g.connect(this.gain); src.start(t);
    } else if (name === 'chime') { tone('sine', 660, 660, 0.16, 0.22); tone('sine', 990, 990, 0.22, 0.18, 0.09); }
    else if (name === 'motion') { tone('sine', 440, 880, 0.18, 0.2); tone('sine', 660, 1320, 0.22, 0.15, 0.1); }
    else if (name === 'vr') { tone('sine', 330, 660, 0.2, 0.18); tone('sine', 495, 990, 0.26, 0.14, 0.11); }
    else if (name === 'blip') tone('sine', 1150, 900, 0.06, 0.13);
    else if (name === 'pop') tone('sine', 420, 780, 0.1, 0.16);
    else if (name === 'error') tone('sawtooth', 170, 110, 0.18, 0.11);
  }
};
document.addEventListener('pointerdown', () => sound.init(), { once: true });

/* ---------------- toast ---------------- */
export function toast(message, type = 'info', action = null, duration = 5000) {
  const root = qs('#toast-root');
  if (!root) return null;
  while (root.children.length > 3) root.firstChild.remove();
  const node = el('div', { class: `toast ${type}` }, [
    iconEl(type === 'success' ? 'check' : type === 'warn' || type === 'error' ? 'alert' : 'info', 17),
    el('span', { class: 'msg', text: message })
  ]);
  const kill = () => { node.classList.add('out'); setTimeout(() => node.remove(), 320); };
  if (action) {
    node.appendChild(el('button', {
      class: 'undo', type: 'button', text: action.label,
      onclick: () => { kill(); action.fn(); }
    }));
  }
  root.appendChild(node);
  setTimeout(kill, action ? 8000 : duration);
  return node;
}

/* ---------------- modal ---------------- */
let activeModal = null;

export function modal(html, { wide = false, onClose = null } = {}) {
  closeModal();
  const scrim = el('div', { class: 'modal-scrim' });
  const box = el('div', { class: `modal${wide ? ' wide' : ''}`, role: 'dialog', 'aria-modal': 'true' });
  box.innerHTML = html;
  scrim.appendChild(box);
  qs('#modal-root').appendChild(scrim);

  const escHandler = (e) => { if (e.key === 'Escape') closeModal(); };
  document.addEventListener('keydown', escHandler);
  activeModal = { el: scrim, onClose, escHandler };

  scrim.addEventListener('pointerdown', (e) => { if (e.target === scrim) closeModal(); });
  qsa('[data-close]', scrim).forEach((b) => { b.onclick = closeModal; });
  const focusable = box.querySelector('input,select,textarea,button:not([data-close])');
  if (focusable) setTimeout(() => focusable.focus(), 60);
  return scrim;
}

export function closeModal() {
  if (!activeModal) return;
  document.removeEventListener('keydown', activeModal.escHandler);
  activeModal.el.remove();
  const cb = activeModal.onClose;
  activeModal = null;
  if (cb) cb();
}

export const isModalOpen = () => !!activeModal;

export function confirmBox(title, body, label = 'Delete') {
  return new Promise((resolve) => {
    const m = modal(`
      <div class="modal-head"><h3>${esc(title)}</h3>
        <button class="icon-btn" data-close type="button">${icon('x')}</button></div>
      <div class="modal-body"><p class="muted">${esc(body)}</p></div>
      <div class="modal-foot">
        <button class="btn btn-ghost" data-close type="button">Cancel</button>
        <button class="btn btn-danger" id="cf-ok" type="button">${icon('trash', 16)} ${esc(label)}</button>
      </div>`, { onClose: () => resolve(false) });
    qs('#cf-ok', m).onclick = () => { activeModal.onClose = null; closeModal(); resolve(true); };
    qsa('[data-close]', m).forEach((b) => { b.onclick = () => { activeModal.onClose = null; closeModal(); resolve(false); }; });
  });
}

/* ---------------- drawer ---------------- */
let drawer = null;

export function closeDrawer() {
  if (!drawer) return;
  document.removeEventListener('keydown', drawer.escHandler);
  drawer.scrim.remove();
  drawer.panel.remove();
  drawer = null;
}

export function openDrawer(buildContent) {
  closeDrawer();
  const scrim = el('div', { class: 'drawer-scrim' });
  const panel = el('aside', { class: 'drawer', role: 'dialog', 'aria-modal': 'true' });
  document.body.append(scrim, panel);
  const escHandler = (e) => { if (e.key === 'Escape') closeDrawer(); };
  document.addEventListener('keydown', escHandler);
  drawer = { scrim, panel, escHandler };
  scrim.onclick = closeDrawer;
  buildContent(panel, closeDrawer);
  requestAnimationFrame(() => { scrim.classList.add('open'); panel.classList.add('open'); });
  return panel;
}

export function helpModal() {
  modal(`
    <div class="modal-head"><h3>Viewer controls</h3>
      <button class="icon-btn" data-close type="button">${icon('x')}</button></div>
    <div class="modal-body">
      <div class="help-grid">
        <span class="kbd">Drag</span><span>Look around</span>
        <span class="kbd">Scroll / Pinch</span><span>Zoom</span>
        <span class="kbd">← → ↑ ↓</span><span>Rotate camera</span>
        <span class="kbd">+ / −</span><span>Zoom in / out</span>
        <span class="kbd">F</span><span>Fullscreen</span>
        <span class="kbd">G</span><span>Projection guides</span>
        <span class="kbd">H</span><span>Show / hide hotspots</span>
        <span class="kbd">I</span><span>Scene info panel</span>
        <span class="kbd">R</span><span>Reset view (recenter in Motion Mode)</span>
        <span class="kbd">M</span><span>Toggle minimap</span>
        <span class="kbd">Esc</span><span>Close panels / exit VR</span>
      </div>
      <div class="note"><b>Motion Mode</b> uses your phone's real gyroscope through the DeviceOrientation API.
      iOS asks for permission after you tap the button; Android starts listening immediately.
      The Active badge only lights up once real sensor frames arrive. Requires HTTPS or localhost.</div>
      <div class="note"><b>VR mode</b> is side-by-side stereoscopic rendering for Cardboard-style viewers.
      It is not a WebXR headset session.</div>
    </div>`);
}
'@

W 'client/assets/js/router.js' @'
import { closeModal, closeDrawer } from './ui.js';
import { qs, qsa } from './utils.js';

const routes = new Map();
let current = null;
let onRouteChange = null;

export function register(name, handler) { routes.set(name, handler); }
export function setRouteHook(fn) { onRouteChange = fn; }

export function parseHash() {
  const hash = location.hash || '#/';
  const [path, query] = hash.slice(1).split('?');
  const parts = path.split('/').filter(Boolean);
  return { parts, params: Object.fromEntries(new URLSearchParams(query || '')) };
}

export function navTo(hash) {
  if (location.hash === hash) render();
  else location.hash = hash;
}

export function setParam(hash) {
  try { history.replaceState(null, '', hash); } catch { /* ignore */ }
}

export async function render() {
  const { parts, params } = parseHash();
  const app = qs('#app');
  const name = parts[0] || 'home';

  if (current?.destroy) {
    try { current.destroy(); } catch (err) { console.error('[router] destroy failed', err); }
  }
  current = null;
  closeModal();
  closeDrawer();
  app.innerHTML = '';
  window.scrollTo(0, 0);

  const handler = routes.get(name) || routes.get('404');
  try {
    current = (await handler(app, { parts, params })) || { destroy() {} };
  } catch (err) {
    console.error('[router] page failed', err);
    app.innerHTML = `<div class="page"><div class="wrap" style="padding-top:70px">
      <div class="empty"><h3>This page could not be loaded</h3>
      <p>${String(err.message || err)}</p>
      <a class="btn btn-primary" href="#/explore">Back to tours</a></div></div></div>`;
    current = { destroy() {} };
  }

  qsa('.nav-link').forEach((a) => {
    const r = a.dataset.route;
    const on = r === name || (name === 'tour' && r === 'explore') || (name === 'studio' && r === 'admin');
    a.classList.toggle('on', on);
    if (on) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });

  if (onRouteChange) onRouteChange(name, params);
}

export function startRouter() {
  window.addEventListener('hashchange', render);
  if (!location.hash) {
    try { history.replaceState(null, '', '#/'); } catch { /* ignore */ }
  }
  return render();
}
'@

W 'client/assets/js/orbis360-motion-vr.js' @'
/*!
 * ============================================================================
 * Orbis360 — Motion Mode + Stereoscopic VR System
 * Pure Vanilla JavaScript (no TypeScript, no framework, no build step)
 * ============================================================================
 *
 * WHAT THIS FILE CONTAINS
 * -----------------------
 * Everything that used to live inside the HTML file for:
 *   • Motion Mode (real DeviceOrientation gyroscope, not simulated)
 *   • Quaternion-based camera synchronization
 *   • SLERP smoothing with jitter suppression
 *   • iOS DeviceOrientationEvent.requestPermission() handling
 *   • Android sensor detection + availability checks
 *   • Secure-context (HTTPS / localhost) validation
 *   • Recenter View / Reset Orientation / Disable Motion / Fullscreen
 *   • "Active" indicator that lights ONLY when real sensor frames arrive
 *   • Portrait ↔ landscape screen-orientation compensation
 *   • Stale-sensor detection and graceful fallback to touch/mouse/keyboard
 *   • Stereoscopic VR mode (side-by-side, adjustable IPD, Cardboard-style)
 *   • All UI controls, panels, HUDs, event wiring and lifecycle cleanup
 *
 * The panorama viewer itself (Three.js sphere, uploads, tours, map, admin)
 * stays in your existing project. This file plugs into it.
 *
 * ============================================================================
 * HOW TO CONNECT THIS FILE TO YOUR EXISTING HTML PROJECT
 * ============================================================================
 *
 * 1) LOAD ORDER in your HTML (Three.js must come first):
 *
 *      <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
 *      <script src="./orbis360-motion-vr.js"></script>
 *      <script src="./your-app.js"></script>
 *
 *    Or, if your app is one big inline script, put this file BEFORE it and
 *    use the classes from the global `OrbisMotion` namespace.
 *
 * 2) THE VIEWER CONTRACT
 *    This system expects a "viewer-like" object. Your existing Orbis360 Viewer
 *    already satisfies it. The minimum surface is:
 *
 *      viewer.camera            THREE.PerspectiveCamera  (required)
 *      viewer.renderer          THREE.WebGLRenderer      (required for VR)
 *      viewer.three             THREE.Scene              (required for VR)
 *      viewer.mount             HTMLElement              (canvas container)
 *      viewer.opts.fsTarget     HTMLElement              (fullscreen target)
 *      viewer.scene             { heading, pitch, fov }  (current panorama meta)
 *      viewer.yaw / viewer.pitch  radians                (kept in sync for compass)
 *
 *    Optional hooks it will use if present:
 *      viewer.initialQuat()     returns THREE.Quaternion of the stored initial view
 *      viewer.currentQuat()     returns THREE.Quaternion of the live camera
 *      viewer.resize()          called after fullscreen / orientation changes
 *      viewer.resetView()       called by the VR "recenter" when motion is off
 *
 * 3) INTEGRATION — OPTION A (drop-in classes, matches your current Viewer)
 *
 *    In your Viewer constructor:
 *
 *      this.motion = new OrbisMotion.MotionController(this, {
 *        smoothing: 12,
 *        onChange: () => this.syncMotionUI?.()
 *      });
 *      this.vr = new OrbisMotion.StereoVR(this, { ipd: 0.064 });
 *      this.motionUI = new OrbisMotion.MotionUI(this, this.motion, this.vr, {
 *        host: this.opts.fsTarget || this.mount.parentElement
 *      });
 *
 *    In your frame/render loop (you already have dt):
 *
 *      const motionDriving = this.motion.update(dt);
 *      if (!motionDriving) {
 *        // ...your existing inertial / drag / keyboard camera code...
 *        this.camera.lookAt(dirFromYawPitch(this.yaw, this.pitch));
 *      }
 *      if (!this.vr.render()) {
 *        this.renderer.render(this.three, this.camera);
 *      }
 *
 *    In your destroy():
 *
 *      this.motionUI.destroy();
 *      this.motion.destroy();
 *      this.vr.destroy();
 *
 * 4) INTEGRATION — OPTION B (one-call attach, recommended for new code)
 *
 *      const motionSystem = OrbisMotion.attach(viewer, {
 *        host: document.querySelector('#viewer-page'),
 *        smoothing: 12,
 *        ipd: 0.064,
 *        sound: true
 *      });
 *
 *      // in your loop:
 *      const motionDriving = motionSystem.update(dt);
 *      if (!motionDriving) { ...normal camera controls... }
 *      if (!motionSystem.render()) renderer.render(scene, camera);
 *
 *      // on teardown:
 *      motionSystem.destroy();
 *
 * 5) WHAT THE USER SEES
 *    • A prominent "Motion Mode" button (top toolbar on desktop,
 *      floating action button on mobile).
 *    • Tapping it opens a consent card. Only after the user taps
 *      "Enable Motion" do we call requestPermission() / attach listeners.
 *    • The Active badge appears ONLY after real alpha/beta/gamma frames arrive.
 *    • A control panel exposes Recenter, Reset Orientation, Fullscreen,
 *      Disable, a live smoothing slider, a sensor readout, and Enter VR.
 *    • VR mode hides normal chrome, renders side-by-side stereo, locks
 *      landscape where supported, and shows an IPD slider + exit button.
 *
 * 6) REQUIREMENTS FOR REAL SENSORS
 *    • HTTPS, or localhost / 127.0.0.1 (Live Server works).
 *    • iOS 13+ requires the permission call inside the button's click handler.
 *    • Desktop has no gyroscope: the system reports it clearly and your
 *      existing mouse / touch / keyboard controls keep working untouched.
 *
 * 7) PUBLIC API
 *      OrbisMotion.MotionController
 *      OrbisMotion.StereoVR
 *      OrbisMotion.MotionUI
 *      OrbisMotion.attach(viewer, options)
 *      OrbisMotion.quatFromYawPitch(yawDeg, pitchDeg)
 *      OrbisMotion.version
 * ============================================================================
 */

(function (global) {
  'use strict';

  var VERSION = '1.0.0';

  /* ==========================================================================
     SECTION 1 — MATH + SMALL UTILITIES
     ========================================================================== */

  function clamp(v, a, b) { return Math.min(b, Math.max(a, v)); }
  function rad(d) { return d * Math.PI / 180; }
  function deg(r) { return r * 180 / Math.PI; }
  function norm360(d) { return ((d % 360) + 360) % 360; }

  function requireTHREE() {
    if (typeof global.THREE === 'undefined') {
      throw new Error('[OrbisMotion] THREE.js is required. Load Three.js before orbis360-motion-vr.js.');
    }
    return global.THREE;
  }

  /**
   * Convert the panorama's yaw/pitch convention into a camera quaternion.
   * Convention used by Orbis360:
   *   dir = ( sin(yaw)*cos(pitch), sin(pitch), -cos(yaw)*cos(pitch) )
   * which corresponds to Euler(pitch, -yaw, 0, 'YXZ').
   */
  function quatFromYawPitch(yawDeg, pitchDeg) {
    var THREE = requireTHREE();
    return new THREE.Quaternion().setFromEuler(
      new THREE.Euler(rad(pitchDeg || 0), -rad(yawDeg || 0), 0, 'YXZ')
    );
  }

  function dirFromQuat(quat, out) {
    var THREE = requireTHREE();
    var v = out || new THREE.Vector3();
    v.set(0, 0, -1).applyQuaternion(quat);
    return v;
  }

  /* ==========================================================================
     SECTION 2 — DOM HELPERS (programmatic, not HTML-string wrapping)
     ========================================================================== */

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    attrs = attrs || {};
    Object.keys(attrs).forEach(function (key) {
      var val = attrs[key];
      if (val == null) return;
      if (key === 'class') node.className = val;
      else if (key === 'text') node.textContent = val;
      else if (key === 'html') node.innerHTML = val; // only used for trusted SVG icons
      else if (key === 'style' && typeof val === 'object') Object.assign(node.style, val);
      else if (key.indexOf('on') === 0 && typeof val === 'function') {
        node.addEventListener(key.slice(2).toLowerCase(), val);
      } else if (key === 'dataset' && typeof val === 'object') {
        Object.keys(val).forEach(function (d) { node.dataset[d] = val[d]; });
      } else node.setAttribute(key, val);
    });
    (children || []).forEach(function (child) {
      if (child == null) return;
      node.appendChild(typeof child === 'string' ? document.createTextNode(child) : child);
    });
    return node;
  }

  function svgIcon(name, size) {
    size = size || 18;
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', size);
    svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');

    var paths = {
      phone: ['M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z', 'M11 18h2'],
      vr: ['M3 7h18a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-5l-4-4-4 4H3a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z', 'M7 12h2', 'M15 12h2'],
      crosshair: ['M12 2v4', 'M12 18v4', 'M2 12h4', 'M18 12h4'],
      undo: ['M1 4v6h6', 'M3.51 15a9 9 0 1 0 2.13-9.36L1 10'],
      max: ['M8 3H5a2 2 0 0 0-2 2v3', 'M21 8V5a2 2 0 0 0-2-2h-3', 'M3 16v3a2 2 0 0 0 2 2h3', 'M16 21h3a2 2 0 0 0 2-2v-3'],
      min: ['M8 3v3a2 2 0 0 1-2 2H3', 'M21 8h-3a2 2 0 0 1-2-2V3', 'M3 16h3a2 2 0 0 1 2 2v3', 'M16 21v-3a2 2 0 0 1 2-2h3'],
      x: ['M18 6L6 18', 'M6 6l12 12'],
      check: ['M20 6L9 17l-5-5'],
      alert: ['M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z', 'M12 9v4', 'M12 17h.01'],
      info: ['M12 16v-4', 'M12 8h.01'],
      rotate: ['M23 4v6h-6', 'M20.49 15a9 9 0 1 1-2.12-9.36L23 10'],
      compass: ['M16.24 7.76l-2.12 6.36-6.36 2.12 2.12-6.36 6.36-2.12z']
    };
    var circles = { crosshair: [12, 12, 9], info: [12, 12, 10], compass: [12, 12, 10] };

    (paths[name] || paths.info).forEach(function (d) {
      var p = document.createElementNS(ns, 'path');
      p.setAttribute('d', d);
      svg.appendChild(p);
    });
    if (circles[name]) {
      var c = document.createElementNS(ns, 'circle');
      c.setAttribute('cx', circles[name][0]);
      c.setAttribute('cy', circles[name][1]);
      c.setAttribute('r', circles[name][2]);
      svg.appendChild(c);
    }
    return svg;
  }

  function injectStyles() {
    if (document.getElementById('orbis-motion-styles')) return;
    var css = [
      ':root{--o360-bg:#070b14;--o360-surface:#0f1728;--o360-surface2:#152036;--o360-overlay:rgba(9,14,27,.88);--o360-text:#e9eefb;--o360-text2:#9aa7c4;--o360-text3:#5f6d8f;--o360-line:rgba(148,180,255,.16);--o360-line2:rgba(148,180,255,.32);--o360-cyan:#3fd9ff;--o360-teal:#2fe6b0;--o360-amber:#ffb454;--o360-magenta:#ff7ac2;--o360-success:#3ddc97;--o360-warning:#ffc247;--o360-danger:#ff5d73;--o360-grad:linear-gradient(135deg,#3fd9ff,#2fe6b0);--o360-vrgrad:linear-gradient(135deg,#ff7ac2,#ffb454);--o360-shadow:0 14px 44px rgba(0,0,0,.56);--o360-glow:0 0 22px rgba(63,217,255,.32);--o360-mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;--o360-disp:"Space Grotesk",system-ui,sans-serif;--o360-body:"Inter",system-ui,sans-serif}',
      '.o360-btn{display:inline-flex;align-items:center;gap:8px;padding:9px 15px;border-radius:11px;font:600 13.5px var(--o360-body);border:1px solid transparent;cursor:pointer;transition:transform .15s,box-shadow .15s,background .15s,border-color .15s,color .15s;white-space:nowrap;user-select:none;color:var(--o360-text);background:var(--o360-overlay);backdrop-filter:blur(10px)}',
      '.o360-btn:active{transform:scale(.97)}',
      '.o360-btn--primary{background:var(--o360-grad);color:#03222e;border-color:transparent;box-shadow:var(--o360-glow)}',
      '.o360-btn--primary:hover{transform:translateY(-1px);box-shadow:0 0 30px rgba(63,217,255,.45)}',
      '.o360-btn--ghost{border-color:var(--o360-line2)}',
      '.o360-btn--ghost:hover{border-color:var(--o360-cyan);color:var(--o360-cyan)}',
      '.o360-btn--danger{background:rgba(255,93,115,.12);color:var(--o360-danger);border-color:rgba(255,93,115,.35)}',
      '.o360-btn--sm{padding:7px 11px;font-size:12.5px;border-radius:9px}',
      '.o360-btn[disabled]{opacity:.45;pointer-events:none}',
      '.o360-motion-btn{border-color:rgba(63,217,255,.45);color:#dfe9ff}',
      '.o360-motion-btn:hover{border-color:var(--o360-cyan);color:var(--o360-cyan);box-shadow:var(--o360-glow)}',
      '.o360-motion-btn.is-active{background:var(--o360-grad);color:#03222e;border-color:transparent;box-shadow:0 0 26px rgba(47,230,176,.5)}',
      '.o360-motion-btn.is-waiting{border-color:var(--o360-amber);color:var(--o360-amber)}',
      '.o360-motion-btn .o360-dot{width:8px;height:8px;border-radius:50%;background:currentColor;flex:none}',
      '.o360-motion-btn.is-active .o360-dot{animation:o360-pulse 1.4s ease-out infinite;background:#03222e}',
      ' @keyframes o360-pulse{0%{box-shadow:0 0 0 0 rgba(3,34,46,.6)}70%{box-shadow:0 0 0 9px rgba(3,34,46,0)}100%{box-shadow:0 0 0 0 rgba(3,34,46,0)}}',
      '.o360-fab{position:absolute;left:50%;bottom:150px;transform:translateX(-50%);z-index:40;display:none;align-items:center;gap:9px;padding:13px 22px;border-radius:999px;font:800 14px var(--o360-body);background:var(--o360-grad);color:#03222e;box-shadow:0 8px 30px rgba(47,230,176,.45);border:none;cursor:pointer}',
      '.o360-fab:active{transform:translateX(-50%) scale(.96)}',
      '.o360-fab.is-active{background:rgba(9,15,30,.88);color:var(--o360-teal);border:1.5px solid var(--o360-teal);box-shadow:0 0 26px rgba(47,230,176,.4)}',
      ' @media(max-width:900px){.o360-fab{display:inline-flex}}',
      '.o360-panel{position:absolute;right:16px;top:128px;z-index:41;width:272px;background:var(--o360-overlay);border:1px solid var(--o360-line2);border-radius:15px;padding:15px;backdrop-filter:blur(16px);box-shadow:var(--o360-shadow);color:var(--o360-text);font-family:var(--o360-body);animation:o360-pop .25s cubic-bezier(.2,.9,.3,1.2)}',
      '.o360-panel.is-live{border-color:rgba(47,230,176,.55);box-shadow:0 0 30px rgba(47,230,176,.22),var(--o360-shadow)}',
      ' @keyframes o360-pop{from{opacity:0;transform:scale(.94) translateY(10px)}}',
      '.o360-panel-head{display:flex;align-items:center;gap:9px;margin-bottom:12px}',
      '.o360-panel-head .o360-ico{width:34px;height:34px;border-radius:10px;display:flex;align-items:center;justify-content:center;background:rgba(63,217,255,.12);color:var(--o360-cyan);border:1px solid rgba(63,217,255,.3);flex:none}',
      '.o360-panel.is-live .o360-ico{background:rgba(47,230,176,.15);color:var(--o360-teal);border-color:rgba(47,230,176,.45)}',
      '.o360-panel-head b{font:600 14.5px var(--o360-disp);display:block;line-height:1.2}',
      '.o360-panel-head small{font-size:11px;color:var(--o360-text3)}',
      '.o360-status{display:flex;align-items:center;gap:8px;font-size:12px;font-weight:700;padding:7px 11px;border-radius:9px;margin-bottom:11px;background:var(--o360-surface2);border:1px solid var(--o360-line)}',
      '.o360-status .o360-sd{width:9px;height:9px;border-radius:50%;background:var(--o360-text3);flex:none}',
      '.o360-status.is-live{color:var(--o360-success);border-color:rgba(61,220,151,.45);background:rgba(61,220,151,.1)}',
      '.o360-status.is-live .o360-sd{background:var(--o360-success);animation:o360-pulse 1.4s ease-out infinite}',
      '.o360-status.is-wait{color:var(--o360-warning);border-color:rgba(255,194,71,.45);background:rgba(255,194,71,.1)}',
      '.o360-status.is-wait .o360-sd{background:var(--o360-warning);animation:o360-spin 1s linear infinite;border-radius:2px}',
      '.o360-status.is-error{color:var(--o360-danger);border-color:rgba(255,93,115,.45);background:rgba(255,93,115,.1)}',
      '.o360-status.is-error .o360-sd{background:var(--o360-danger)}',
      ' @keyframes o360-spin{to{transform:rotate(360deg)}}',
      '.o360-readout{font:10.5px/1.7 var(--o360-mono);color:var(--o360-text2);background:var(--o360-surface2);border:1px solid var(--o360-line);border-radius:9px;padding:8px 10px;margin-bottom:11px}',
      '.o360-readout b{color:var(--o360-cyan);font-weight:600}',
      '.o360-grid{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-bottom:11px}',
      '.o360-grid .o360-btn{justify-content:center;padding:8px 6px;font-size:12px}',
      '.o360-slider{margin-bottom:11px}',
      '.o360-slider-lab{display:flex;justify-content:space-between;font-size:10.5px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--o360-text3);margin-bottom:5px}',
      '.o360-slider-lab b{color:var(--o360-cyan);font-family:var(--o360-mono)}',
      '.o360-slider input[type=range]{width:100%;padding:0;height:18px;background:none;border:none;-webkit-appearance:none;appearance:none;cursor:pointer}',
      '.o360-slider input[type=range]::-webkit-slider-runnable-track{height:4px;border-radius:4px;background:linear-gradient(90deg,#19b8e6,#2fe6b0)}',
      '.o360-slider input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:14px;height:14px;border-radius:50%;background:#fff;border:3px solid #19b8e6;margin-top:-5px;box-shadow:0 0 8px rgba(63,217,255,.5)}',
      '.o360-slider input[type=range]::-moz-range-track{height:4px;border-radius:4px;background:linear-gradient(90deg,#19b8e6,#2fe6b0)}',
      '.o360-slider input[type=range]::-moz-range-thumb{width:12px;height:12px;border-radius:50%;background:#fff;border:3px solid #19b8e6}',
      '.o360-note{font-size:11px;color:var(--o360-text3);line-height:1.5;margin-top:9px;padding-top:9px;border-top:1px solid var(--o360-line)}',
      '.o360-vr-btn{border-color:rgba(255,122,194,.45);color:#ffd7ec}',
      '.o360-vr-btn:hover{border-color:var(--o360-magenta);color:var(--o360-magenta);box-shadow:0 0 22px rgba(255,122,194,.35)}',
      '.o360-vr-btn.is-active{background:var(--o360-vrgrad);color:#2e0a1e;border-color:transparent}',
      '.o360-vr-hud{position:absolute;left:50%;top:16px;transform:translateX(-50%);z-index:60;display:flex;align-items:center;gap:10px;background:rgba(5,8,16,.85);border:1px solid rgba(255,122,194,.5);border-radius:999px;padding:8px 14px;backdrop-filter:blur(14px);box-shadow:0 8px 30px rgba(0,0,0,.5);color:var(--o360-text);font-family:var(--o360-body)}',
      '.o360-vr-badge{display:flex;align-items:center;gap:6px;font-size:11.5px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:var(--o360-magenta)}',
      '.o360-vr-badge .o360-vd{width:8px;height:8px;border-radius:50%;background:var(--o360-magenta);animation:o360-pulse 1.4s ease-out infinite}',
      '.o360-vr-sep{width:1px;height:22px;background:rgba(148,180,255,.25)}',
      '.o360-vr-ipd{display:flex;align-items:center;gap:7px;font-size:10.5px;font-weight:700;color:var(--o360-text2)}',
      '.o360-vr-ipd input[type=range]{width:74px;padding:0;height:16px;background:none;border:none;-webkit-appearance:none;appearance:none;cursor:pointer}',
      '.o360-vr-ipd input[type=range]::-webkit-slider-runnable-track{height:4px;border-radius:4px;background:linear-gradient(90deg,#ff7ac2,#ffb454)}',
      '.o360-vr-ipd input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:13px;height:13px;border-radius:50%;background:#fff;border:3px solid #ff7ac2;margin-top:-4.5px}',
      '.o360-vr-ipd input[type=range]::-moz-range-track{height:4px;border-radius:4px;background:linear-gradient(90deg,#ff7ac2,#ffb454)}',
      '.o360-vr-ipd input[type=range]::-moz-range-thumb{width:11px;height:11px;border-radius:50%;background:#fff;border:3px solid #ff7ac2}',
      '.o360-icon-btn{display:inline-flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:9px;color:#dfe9ff;background:none;border:1px solid transparent;cursor:pointer;transition:all .15s;flex:none}',
      '.o360-icon-btn:hover{color:var(--o360-cyan);background:rgba(148,180,255,.1);border-color:var(--o360-line)}',
      '.o360-icon-btn.is-on{color:var(--o360-teal);background:rgba(47,230,176,.13);border-color:rgba(47,230,176,.45)}',
      '.o360-vr-divider{position:absolute;left:50%;top:0;bottom:0;width:2px;background:rgba(0,0,0,.85);z-index:55;pointer-events:none;box-shadow:0 0 12px rgba(0,0,0,.8)}',
      '.o360-vr-eyes{position:absolute;inset:0;z-index:56;pointer-events:none;display:flex}',
      '.o360-vr-eyes span{flex:1;display:flex;align-items:flex-end;justify-content:center;padding-bottom:14px;font-size:10px;font-weight:800;letter-spacing:.16em;text-transform:uppercase;color:rgba(233,238,251,.35);font-family:var(--o360-body)}',
      '.o360-vr-mode .o360-toolbar,.o360-vr-mode .o360-fab,.o360-vr-mode .o360-panel{display:none!important}',
      '.o360-landing{position:absolute;inset:0;z-index:70;display:flex;align-items:center;justify-content:center;background:radial-gradient(700px 400px at 50% 40%,rgba(47,230,176,.14),transparent 65%),rgba(3,6,12,.88);backdrop-filter:blur(8px);padding:20px;font-family:var(--o360-body)}',
      '.o360-landing-card{width:min(430px,100%);background:var(--o360-surface);border:1px solid rgba(47,230,176,.4);border-radius:18px;padding:26px;box-shadow:0 0 50px rgba(47,230,176,.2),var(--o360-shadow);text-align:center;color:var(--o360-text)}',
      '.o360-landing-ico{width:64px;height:64px;margin:0 auto 16px;border-radius:18px;display:flex;align-items:center;justify-content:center;background:rgba(47,230,176,.13);color:var(--o360-teal);border:1px solid rgba(47,230,176,.4)}',
      '.o360-landing h3{font:600 21px var(--o360-disp);margin:0 0 8px}',
      '.o360-landing p{font-size:13.5px;color:var(--o360-text2);margin:0 0 16px;line-height:1.55}',
      '.o360-landing-list{text-align:left;font-size:12.5px;color:var(--o360-text2);background:var(--o360-surface2);border:1px solid var(--o360-line);border-radius:11px;padding:12px 14px;margin-bottom:18px;line-height:1.8}',
      '.o360-landing-list b{color:var(--o360-text)}',
      '.o360-landing-err{font-size:12.5px;color:var(--o360-danger);background:rgba(255,93,115,.1);border:1px solid rgba(255,93,115,.35);border-radius:10px;padding:10px 12px;margin-bottom:14px;text-align:left;line-height:1.5}',
      '.o360-landing-actions{display:flex;gap:8px}',
      '.o360-landing-actions .o360-btn{flex:1;justify-content:center}',
      '.o360-landing-foot{font-size:11px;color:var(--o360-text3);margin-top:12px}',
      '.o360-toolbar{position:absolute;top:76px;right:16px;z-index:39;display:flex;gap:8px;align-items:center}',
      ' @media(max-width:760px){.o360-panel{right:10px;left:10px;top:auto;bottom:206px;width:auto;max-width:420px;margin:0 auto}.o360-toolbar .o360-btn span{display:none}.o360-toolbar{top:68px;right:10px}.o360-vr-hud{top:10px;padding:7px 10px;gap:7px}.o360-vr-ipd input[type=range]{width:56px}.o360-vr-badge span{display:none}}',
      '.o360-toast{position:fixed;left:18px;bottom:18px;z-index:9999;display:flex;align-items:center;gap:10px;background:var(--o360-surface);color:var(--o360-text);border:1px solid var(--o360-line2);border-left:3px solid var(--o360-cyan);border-radius:11px;padding:11px 14px;box-shadow:var(--o360-shadow);font:13px var(--o360-body);max-width:min(380px,90vw);animation:o360-toast-in .3s cubic-bezier(.2,.9,.3,1.2)}',
      '.o360-toast--success{border-left-color:var(--o360-success)}',
      '.o360-toast--warn{border-left-color:var(--o360-warning)}',
      '.o360-toast--error{border-left-color:var(--o360-danger)}',
      ' @keyframes o360-toast-in{from{opacity:0;transform:translateX(-22px)}}'
    ].join('\n');

    var style = document.createElement('style');
    style.id = 'orbis-motion-styles';
    style.textContent = css;
    document.head.appendChild(style);
  }

  /* ==========================================================================
     SECTION 3 — OPTIONAL SOUND (tied to visible events only)
     ========================================================================== */

  function SoundBus(options) {
    this.enabled = options && options.sound !== false;
    this.ctx = null;
    this.gain = null;
  }
  SoundBus.prototype.init = function () {
    if (this.ctx || !this.enabled) return;
    try {
      var AC = global.AudioContext || global.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.gain = this.ctx.createGain();
      this.gain.gain.value = 0.4;
      this.gain.connect(this.ctx.destination);
    } catch (e) { /* sound is optional */ }
  };
  SoundBus.prototype.play = function (name) {
    if (!this.enabled) return;
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state === 'suspended') this.ctx.resume();
    var t = this.ctx.currentTime, self = this;
    function tone(type, f0, f1, dur, vol, when) {
      var o = self.ctx.createOscillator(), g = self.ctx.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f0, t + (when || 0));
      o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + (when || 0) + dur);
      g.gain.setValueAtTime(0.0001, t + (when || 0));
      g.gain.linearRampToValueAtTime(vol, t + (when || 0) + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + (when || 0) + dur);
      o.connect(g); g.connect(self.gain);
      o.start(t + (when || 0)); o.stop(t + (when || 0) + dur + 0.05);
    }
    if (name === 'motion') { tone('sine', 440, 880, 0.18, 0.2); tone('sine', 660, 1320, 0.22, 0.15, 0.1); }
    else if (name === 'blip') { tone('sine', 1150, 900, 0.06, 0.13); }
    else if (name === 'error') { tone('sawtooth', 170, 110, 0.18, 0.11); }
    else if (name === 'vr') { tone('sine', 330, 660, 0.2, 0.18); tone('sine', 495, 990, 0.26, 0.14, 0.11); }
  };
  SoundBus.prototype.setEnabled = function (on) {
    this.enabled = !!on;
    if (!on && this.gain) this.gain.gain.value = 0;
    else if (on && this.gain) this.gain.gain.value = 0.4;
  };

  /* ==========================================================================
     SECTION 4 — MOTION CONTROLLER
     Real DeviceOrientation API + quaternion math + SLERP + calibration.
     ========================================================================== */

  function MotionController(viewer, options) {
    var THREE = requireTHREE();
    options = options || {};

    this.viewer = viewer;
    this.options = options;
    this.enabled = false;
    this.active = false;
    this.hasData = false;
    this.permission = 'unknown';
    this.status = 'off'; // off | waiting | live | stale | error
    this.error = '';

    this.rawQuat = new THREE.Quaternion();
    this.targetQuat = new THREE.Quaternion();
    this.smoothQuat = new THREE.Quaternion();
    this.offsetQuat = new THREE.Quaternion();

    this.alpha = 0;
    this.beta = 0;
    this.gamma = 0;
    this.absolute = false;
    this.lastDataTime = 0;
    this.frameCount = 0;
    this.hz = 0;
    this._hzT = 0;
    this._hzC = 0;

    this.smoothing = clamp(options.smoothing != null ? options.smoothing : 12, 4, 30);
    this.deadzone = options.deadzone != null ? options.deadzone : 0.0008;
    this.staleMs = options.staleMs != null ? options.staleMs : 1600;
    this.waitMs = options.waitMs != null ? options.waitMs : 3200;

    this.onChange = typeof options.onChange === 'function' ? options.onChange : null;
    this.onActive = typeof options.onActive === 'function' ? options.onActive : null;
    this.onError = typeof options.onError === 'function' ? options.onError : null;

    this._handler = null;
    this._orientHandler = null;
    this._waitTimer = null;
    this._lastScreenAngle = this.screenAngle();

    this._zee = new THREE.Vector3(0, 0, 1);
    this._q1 = new THREE.Quaternion(-Math.SQRT1_2, 0, 0, Math.SQRT1_2);
    this._euler = new THREE.Euler();
    this._qScreen = new THREE.Quaternion();
    this._dir = new THREE.Vector3();
  }

  MotionController.supported = function () {
    return typeof global.DeviceOrientationEvent !== 'undefined';
  };

  MotionController.secure = function () {
    return global.isSecureContext ||
      location.hostname === 'localhost' ||
      location.hostname === '127.0.0.1' ||
      location.protocol === 'https:';
  };

  MotionController.prototype.screenAngle = function () {
    var a = 0;
    if (global.screen && global.screen.orientation && typeof global.screen.orientation.angle === 'number') {
      a = global.screen.orientation.angle;
    } else if (typeof global.orientation === 'number') {
      a = global.orientation;
    }
    return a;
  };

  MotionController.prototype._camera = function () {
    return this.viewer && this.viewer.camera ? this.viewer.camera : null;
  };

  MotionController.prototype._cameraQuat = function () {
    var c = this._camera();
    return c ? c.quaternion.clone() : new (requireTHREE().Quaternion)();
  };

  MotionController.prototype._initialQuat = function () {
    if (this.viewer && typeof this.viewer.initialQuat === 'function') {
      return this.viewer.initialQuat();
    }
    var meta = (this.viewer && this.viewer.scene) || {};
    return quatFromYawPitch(meta.heading || 0, meta.pitch || 0);
  };

  MotionController.prototype._emit = function () {
    if (this.onChange) this.onChange(this);
  };

  MotionController.prototype._fail = function (msg) {
    this.enabled = false;
    this.active = false;
    this.status = 'error';
    this.error = msg;
    this._emit();
    if (this.onError) this.onError(msg, this);
  };

  MotionController.prototype.enable = async function () {
    if (this.enabled && this.active) return true;

    this.error = '';
    this.status = 'waiting';
    this._emit();

    if (!MotionController.supported()) {
      this._fail('This browser does not expose the DeviceOrientation API. Use touch drag, mouse, or arrow keys instead.');
      throw new Error(this.error);
    }
    if (!MotionController.secure()) {
      this._fail('Motion sensors need a secure context. Open this page over HTTPS, or use http://localhost on this computer.');
      throw new Error(this.error);
    }

    // iOS 13+ requires this call inside a user-initiated handler.
    try {
      if (typeof global.DeviceOrientationEvent.requestPermission === 'function') {
        var p = await global.DeviceOrientationEvent.requestPermission();
        this.permission = p;
        if (p !== 'granted') {
          this._fail('Motion permission was denied. Enable Motion & Orientation Access in Safari settings, then tap Motion Mode again.');
          throw new Error(this.error);
        }
      } else {
        this.permission = 'granted';
      }
    } catch (e) {
      if (this.status === 'error') throw e;
      this._fail('Could not request motion permission: ' + (e && e.message ? e.message : 'unknown error'));
      throw e;
    }

    this._attachSensors();

    var gotData = await this._waitForData(this.waitMs);
    if (!gotData) {
      this._detachSensors();
      this._fail('No gyroscope data arrived. Desktop computers have no sensor. On a phone, check motion permissions and HTTPS, then retry.');
      throw new Error(this.error);
    }

    this.enabled = true;
    this.active = true;
    this.status = 'live';
    this.error = '';
    this.calibrateTo(this._initialQuat());
    this.smoothQuat.copy(this._cameraQuat());
    this._emit();
    if (this.onActive) this.onActive(this);
    return true;
  };

  MotionController.prototype._attachSensors = function () {
    var self = this;
    this._detachSensors();
    this.hasData = false;
    this.frameCount = 0;
    this.lastDataTime = 0;
    this.hz = 0;
    this._hzT = performance.now();
    this._hzC = 0;

    this._handler = function (e) { self._onOrientation(e); };
    // Prefer absolute where available; also listen to standard event.
    global.addEventListener('deviceorientationabsolute', this._handler, true);
    global.addEventListener('deviceorientation', this._handler, true);

    this._orientHandler = function () {
      var angle = self.screenAngle();
      if (angle === self._lastScreenAngle) return;
      self._lastScreenAngle = angle;
      // Recompute with the new screen angle using the last known sensor values.
      if (self.hasData) {
        self._onOrientation({
          alpha: self.alpha, beta: self.beta, gamma: self.gamma,
          absolute: self.absolute, type: self.absolute ? 'deviceorientationabsolute' : 'deviceorientation'
        });
      }
      // Recalibrate so the world does not jump when rotating the device.
      if (self.active) self.calibrateTo(self._cameraQuat());
      self._emit();
    };
    global.addEventListener('orientationchange', this._orientHandler);
    if (global.screen && global.screen.orientation && global.screen.orientation.addEventListener) {
      global.screen.orientation.addEventListener('change', this._orientHandler);
    }
  };

  MotionController.prototype._detachSensors = function () {
    if (this._handler) {
      global.removeEventListener('deviceorientationabsolute', this._handler, true);
      global.removeEventListener('deviceorientation', this._handler, true);
      this._handler = null;
    }
    if (this._orientHandler) {
      global.removeEventListener('orientationchange', this._orientHandler);
      if (global.screen && global.screen.orientation && global.screen.orientation.removeEventListener) {
        global.screen.orientation.removeEventListener('change', this._orientHandler);
      }
      this._orientHandler = null;
    }
  };

  MotionController.prototype._waitForData = function (ms) {
    var self = this;
    return new Promise(function (resolve) {
      var t0 = performance.now();
      function check() {
        if (self.hasData) return resolve(true);
        if (performance.now() - t0 > ms) return resolve(false);
        self._waitTimer = requestAnimationFrame(check);
      }
      check();
    });
  };

  MotionController.prototype._onOrientation = function (e) {
    if (e.alpha == null || e.beta == null || e.gamma == null) return;

    this.alpha = e.alpha;
    this.beta = e.beta;
    this.gamma = e.gamma;
    this.absolute = !!e.absolute || e.type === 'deviceorientationabsolute';

    var a = rad(e.alpha), b = rad(e.beta), g = rad(e.gamma);
    var orient = rad(this.screenAngle());

    // Standard Three.js DeviceOrientationControls transform.
    this._euler.set(b, a, -g, 'YXZ');
    this.rawQuat.setFromEuler(this._euler);
    this.rawQuat.multiply(this._q1); // camera looks out the back of the device
    this.rawQuat.multiply(this._qScreen.setFromAxisAngle(this._zee, -orient)); // screen orientation compensation

    this.hasData = true;
    this.lastDataTime = performance.now();
    this.frameCount++;
    this._hzC++;
    var now = performance.now();
    if (now - this._hzT > 500) {
      this.hz = Math.round(this._hzC * 1000 / (now - this._hzT));
      this._hzT = now;
      this._hzC = 0;
    }
    this._updateTarget();
  };

  MotionController.prototype._updateTarget = function () {
    // target = rawDevicePose * calibrationOffset
    this.targetQuat.copy(this.rawQuat).multiply(this.offsetQuat);
  };

  MotionController.prototype.calibrateTo = function (desiredQuat) {
    if (!this.hasData) return;
    // offset = raw^-1 * desired, so the current physical pose maps to desiredQuat.
    this.offsetQuat.copy(this.rawQuat).invert().multiply(desiredQuat);
    this.targetQuat.copy(desiredQuat);
    this.smoothQuat.copy(this._cameraQuat());
  };

  MotionController.prototype.recenter = function () {
    this.calibrateTo(this._initialQuat());
    this._emit();
    return true;
  };

  MotionController.prototype.resetOrientation = function () {
    this.calibrateTo(quatFromYawPitch(0, 0));
    this._emit();
    return true;
  };

  MotionController.prototype.setSmoothing = function (v) {
    this.smoothing = clamp(Number(v) || 12, 4, 30);
    if (this.options && typeof this.options.onSmoothingChange === 'function') {
      this.options.onSmoothingChange(this.smoothing);
    }
    this._emit();
  };

  /**
   * Called every frame by the viewer.
   * Returns true when motion is actively driving the camera.
   */
  MotionController.prototype.update = function (dt) {
    if (!this.enabled) return false;
    var camera = this._camera();
    if (!camera) return false;

    var stale = performance.now() - this.lastDataTime;
    if (stale > this.staleMs) {
      if (this.active) {
        this.active = false;
        this.status = 'stale';
        this.error = 'Sensor stream paused. Keep the tab in the foreground and the phone moving.';
        this._emit();
      }
      return false;
    }
    if (!this.active) {
      this.active = true;
      this.status = 'live';
      this.error = '';
      this._emit();
    }

    var angle = this.smoothQuat.angleTo(this.targetQuat);
    if (angle < this.deadzone) {
      camera.quaternion.copy(this.smoothQuat);
    } else {
      // Adaptive SLERP: faster on large swings, gentler near rest to kill jitter.
      var speed = this.smoothing * (angle > 0.45 ? 1.7 : angle > 0.12 ? 1.25 : 1);
      var k = 1 - Math.exp(-dt * speed);
      this.smoothQuat.slerp(this.targetQuat, k);
      camera.quaternion.copy(this.smoothQuat);
    }

    // Keep the viewer's yaw/pitch in sync so compass + minimap stay correct.
    camera.getWorldDirection(this._dir);
    if (this.viewer) {
      this.viewer.yaw = Math.atan2(this._dir.x, -this._dir.z);
      this.viewer.pitch = Math.asin(clamp(this._dir.y, -1, 1));
    }
    return true;
  };

  MotionController.prototype.disable = function () {
    this._detachSensors();
    this.enabled = false;
    this.active = false;
    this.hasData = false;
    this.status = 'off';
    this.error = '';
    this.hz = 0;

    // Hand control back to the viewer without a visual jump.
    var camera = this._camera();
    if (camera && this.viewer) {
      camera.getWorldDirection(this._dir);
      this.viewer.yaw = Math.atan2(this._dir.x, -this._dir.z);
      this.viewer.pitch = Math.asin(clamp(this._dir.y, -1, 1));
      if (typeof this.viewer.vel === 'object' && this.viewer.vel) {
        this.viewer.vel.x = 0;
        this.viewer.vel.y = 0;
      }
    }
    this._emit();
  };

  MotionController.prototype.destroy = function () {
    this._detachSensors();
    if (this._waitTimer) cancelAnimationFrame(this._waitTimer);
    this.enabled = false;
    this.active = false;
    this.onChange = null;
    this.onActive = null;
    this.onError = null;
  };

  /* ==========================================================================
     SECTION 5 — STEREOSCOPIC VR
     Side-by-side rendering with adjustable IPD; standard 360 stays available.
     ========================================================================== */

  function StereoVR(viewer, options) {
    var THREE = requireTHREE();
    options = options || {};
    this.viewer = viewer;
    this.options = options;
    this.active = false;
    this.stereo = THREE.StereoCamera ? new THREE.StereoCamera() : null;
    this.ipd = clamp(options.ipd != null ? options.ipd : 0.064, 0.05, 0.078);
    if (this.stereo) this.stereo.eyeSep = this.ipd;
    this.hud = null;
    this.divider = null;
    this.eyeLabels = null;
    this._motionBtn = null;
    this._fsHandler = null;
    this.onChange = typeof options.onChange === 'function' ? options.onChange : null;
    this._size = new THREE.Vector2();
    this._host = options.host || null;
  }

  StereoVR.prototype.supported = function () { return !!this.stereo; };

  StereoVR.prototype._getHost = function () {
    if (this._host) return this._host;
    if (this.viewer && this.viewer.opts && this.viewer.opts.fsTarget) return this.viewer.opts.fsTarget;
    if (this.viewer && this.viewer.mount && this.viewer.mount.parentElement) return this.viewer.mount.parentElement;
    if (this.viewer && this.viewer.container) return this.viewer.container;
    return document.body;
  };

  StereoVR.prototype._getScene = function () {
    return this.viewer.three || this.viewer.scene3D || this.viewer._scene || null;
  };

  StereoVR.prototype._getRenderer = function () {
    return this.viewer.renderer || this.viewer._renderer || null;
  };

  StereoVR.prototype._emit = function () { if (this.onChange) this.onChange(this); };

  StereoVR.prototype.enter = async function () {
    if (!this.stereo) {
      throw new Error('Stereoscopic renderer unavailable in this Three.js build. Standard 360° mode remains available.');
    }
    if (this.active) return true;

    this.active = true;
    var host = this._getHost();
    host.classList.add('o360-vr-mode');
    this._buildHUD();

    // Fullscreen + landscape lock where supported.
    try {
      if (host.requestFullscreen) await host.requestFullscreen();
      else if (host.webkitRequestFullscreen) host.webkitRequestFullscreen();
      else host.classList.add('o360-pseudo-fs');
    } catch (e) {
      host.classList.add('o360-pseudo-fs');
    }
    try { if (global.screen.orientation && global.screen.orientation.lock) await global.screen.orientation.lock('landscape'); } catch (e) { /* not supported */ }

    if (typeof this.viewer.resize === 'function') this.viewer.resize();
    this._emit();
    return true;
  };

  StereoVR.prototype._buildHUD = function () {
    var self = this;
    var host = this._getHost();

    this.hud = el('div', { class: 'o360-vr-hud', role: 'toolbar', 'aria-label': 'VR controls' }, [
      el('span', { class: 'o360-vr-badge' }, [
        el('span', { class: 'o360-vd' }),
        el('span', { text: 'VR Stereo' })
      ]),
      el('span', { class: 'o360-vr-sep' })
    ]);

    var ipdValue = el('b', { class: 'mono', text: (this.ipd * 1000).toFixed(0) + 'mm' });
    var ipdSlider = el('input', {
      type: 'range', min: '0.050', max: '0.078', step: '0.001',
      value: String(this.ipd), 'aria-label': 'Interpupillary distance'
    });
    ipdSlider.addEventListener('input', function () {
      self.setIPD(parseFloat(ipdSlider.value));
      ipdValue.textContent = (self.ipd * 1000).toFixed(0) + 'mm';
    });
    this.hud.appendChild(el('span', { class: 'o360-vr-ipd' }, [
      document.createTextNode('IPD '), ipdSlider, ipdValue
    ]));

    var motionBtn = el('button', {
      class: 'o360-icon-btn', type: 'button', title: 'Toggle Motion Mode',
      onclick: function () {
        if (self.viewer.motion && self.viewer.motion.enabled) {
          self.viewer.motion.disable();
        } else if (typeof self.viewer.toggleMotion === 'function') {
          self.viewer.toggleMotion();
        } else if (self.options.onRequestMotion) {
          self.options.onRequestMotion();
        }
        self.syncMotion();
      }
    }, [svgIcon('phone', 16)]);
    this._motionBtn = motionBtn;
    this.hud.appendChild(motionBtn);

    this.hud.appendChild(el('button', {
      class: 'o360-icon-btn', type: 'button', title: 'Recenter',
      onclick: function () {
        if (self.viewer.motion && self.viewer.motion.active) self.viewer.motion.recenter();
        else if (typeof self.viewer.resetView === 'function') self.viewer.resetView();
      }
    }, [svgIcon('crosshair', 16)]));

    this.hud.appendChild(el('button', {
      class: 'o360-icon-btn', type: 'button', title: 'Exit VR',
      onclick: function () { self.exit(); }
    }, [svgIcon('x', 16)]));

    host.appendChild(this.hud);

    this.divider = el('div', { class: 'o360-vr-divider' });
    host.appendChild(this.divider);

    this.eyeLabels = el('div', { class: 'o360-vr-eyes' }, [
      el('span', { text: 'Left eye' }),
      el('span', { text: 'Right eye' })
    ]);
    host.appendChild(this.eyeLabels);

    this._fsHandler = function () {
      if (!document.fullscreenElement && !document.webkitFullscreenElement && self.active) self.exit();
    };
    document.addEventListener('fullscreenchange', this._fsHandler);
    document.addEventListener('webkitfullscreenchange', this._fsHandler);

    this.syncMotion();
  };

  StereoVR.prototype.syncMotion = function () {
    if (!this._motionBtn) return;
    var on = !!(this.viewer.motion && this.viewer.motion.active);
    this._motionBtn.classList.toggle('is-on', on);
  };

  StereoVR.prototype.setIPD = function (v) {
    this.ipd = clamp(Number(v) || 0.064, 0.05, 0.078);
    if (this.stereo) this.stereo.eyeSep = this.ipd;
    if (this.options && typeof this.options.onIPDChange === 'function') this.options.onIPDChange(this.ipd);
    this._emit();
  };

  /**
   * Called every frame. Returns true if stereo was rendered (viewer should
   * skip its own renderer.render call in that case).
   */
  StereoVR.prototype.render = function () {
    if (!this.active || !this.stereo) return false;
    var renderer = this._getRenderer(), scene = this._getScene(), camera = this.viewer.camera;
    if (!renderer || !scene || !camera) return false;

    camera.updateMatrixWorld();
    this.stereo.update(camera);
    renderer.getSize(this._size);
    var w = this._size.width, h = this._size.height;

    renderer.setScissorTest(true);
    renderer.setScissor(0, 0, w / 2, h);
    renderer.setViewport(0, 0, w / 2, h);
    renderer.render(scene, this.stereo.cameraL);

    renderer.setScissor(w / 2, 0, w / 2, h);
    renderer.setViewport(w / 2, 0, w / 2, h);
    renderer.render(scene, this.stereo.cameraR);

    renderer.setScissorTest(false);
    renderer.setViewport(0, 0, w, h);
    return true;
  };

  StereoVR.prototype.exit = async function () {
    if (!this.active) return;
    this.active = false;
    var host = this._getHost();
    host.classList.remove('o360-vr-mode', 'o360-pseudo-fs');

    if (this.hud) { this.hud.remove(); this.hud = null; }
    if (this.divider) { this.divider.remove(); this.divider = null; }
    if (this.eyeLabels) { this.eyeLabels.remove(); this.eyeLabels = null; }
    this._motionBtn = null;

    if (this._fsHandler) {
      document.removeEventListener('fullscreenchange', this._fsHandler);
      document.removeEventListener('webkitfullscreenchange', this._fsHandler);
      this._fsHandler = null;
    }
    try { if (global.screen.orientation && global.screen.orientation.unlock) global.screen.orientation.unlock(); } catch (e) { /* ignore */ }
    if (document.fullscreenElement) { try { await document.exitFullscreen(); } catch (e) { /* ignore */ } }
    else if (document.webkitFullscreenElement) { try { document.webkitExitFullscreen(); } catch (e) { /* ignore */ } }

    if (typeof this.viewer.resize === 'function') this.viewer.resize();
    this._emit();
  };

  StereoVR.prototype.destroy = function () {
    if (this.active) this.exit();
    this.stereo = null;
    this.onChange = null;
  };

  /* ==========================================================================
     SECTION 6 — MOTION UI
     Builds every control programmatically and wires all events.
     ========================================================================== */

  function MotionUI(viewer, motion, vr, options) {
    injectStyles();
    options = options || {};
    this.viewer = viewer;
    this.motion = motion;
    this.vr = vr;
    this.options = options;
    this.host = options.host ||
      (viewer.opts && viewer.opts.fsTarget) ||
      (viewer.mount && viewer.mount.parentElement) ||
      document.body;
    this.sound = options.soundBus || new SoundBus({ sound: options.sound !== false });
    this.ac = new AbortController();
    this.toolbar = null;
    this.fab = null;
    this.panel = null;
    this.landing = null;
    this._readoutTimer = null;

    this._build();
    this._wire();
    this.sync();
  }

  MotionUI.prototype._btn = function (label, iconName, variant, onClick, extraClass) {
    var b = el('button', {
      class: 'o360-btn ' + (variant ? 'o360-btn--' + variant : 'o360-btn--ghost') + (extraClass ? ' ' + extraClass : ''),
      type: 'button'
    }, [svgIcon(iconName, 15), el('span', { text: label })]);
    b.addEventListener('click', onClick, { signal: this.ac.signal });
    return b;
  };

  MotionUI.prototype._build = function () {
    var self = this;

    // Ensure the host can position absolute children.
    var pos = getComputedStyle(this.host).position;
    if (pos === 'static') this.host.style.position = 'relative';

    this.toolbar = el('div', { class: 'o360-toolbar', role: 'toolbar', 'aria-label': 'Immersive controls' });
    this.motionBtn = this._btn('Motion Mode', 'phone', 'ghost', function () { self.toggleMotion(); }, 'o360-motion-btn');
    this.motionBtn.insertBefore(el('span', { class: 'o360-dot' }), this.motionBtn.firstChild);
    this.vrBtn = this._btn('VR', 'vr', 'ghost', function () { self.enterVR(); }, 'o360-vr-btn');
    this.toolbar.appendChild(this.motionBtn);
    this.toolbar.appendChild(this.vrBtn);
    this.host.appendChild(this.toolbar);

    this.fab = el('button', {
      class: 'o360-fab', type: 'button', 'aria-label': 'Motion Mode',
      onclick: function () { self.toggleMotion(); }
    }, [svgIcon('phone', 17), el('span', { text: 'Motion Mode' })]);
    this.host.appendChild(this.fab);
  };

  MotionUI.prototype._wire = function () {
    var self = this;
    this.motion.onChange = function () { self.sync(); self.vr.syncMotion(); };
    this.vr.onChange = function () { self.sync(); };

    document.addEventListener('keydown', function (e) {
      var tag = (e.target.tagName || '').toLowerCase();
      if (tag === 'input' || tag === 'textarea' || tag === 'select') return;
      if (e.key === 'Escape') {
        if (self.landing) self._closeLanding();
        else if (self.vr.active) self.vr.exit();
        else if (self.panel) self._closePanel();
      }
    }, { signal: this.ac.signal });
  };

  MotionUI.prototype.toggleMotion = function () {
    if (this.motion.enabled) {
      this.motion.disable();
      this._closePanel();
      this.sound.play('blip');
      this._toast('Motion Mode off — touch, mouse and keys are back', 'info');
      return;
    }
    if (this.motion.status === 'waiting') return;
    this._openLanding();
  };

  MotionUI.prototype._openLanding = function () {
    var self = this;
    if (this.landing) return;

    var err = el('div', { class: 'o360-landing-err', style: { display: 'none' } });

    var enableBtn = this._btn('Enable Motion', 'phone', 'primary', async function () {
      enableBtn.disabled = true;
      enableBtn.querySelector('span').textContent = 'Requesting…';
      err.style.display = 'none';
      try {
        await self.motion.enable();
        self._closeLanding();
        self._openPanel();
        self.sound.play('motion');
        self._toast('Motion Mode active — move your phone to look around', 'success');
      } catch (e2) {
        err.textContent = e2.message || String(e2);
        err.style.display = '';
        enableBtn.disabled = false;
        enableBtn.querySelector('span').textContent = 'Try again';
        self.sound.play('error');
        self.sync();
      }
    });

    var card = el('div', { class: 'o360-landing-card' }, [
      el('div', { class: 'o360-landing-ico' }, [svgIcon('phone', 30)]),
      el('h3', { text: 'Motion Mode' }),
      el('p', { text: 'Look around the panorama by physically moving your phone. Uses the real gyroscope — nothing is simulated.' }),
      el('div', { class: 'o360-landing-list' }, [
        el('div', {}, [el('b', { text: '1. ' }), document.createTextNode('Tap Enable below (iOS asks for permission)')]),
        el('div', {}, [el('b', { text: '2. ' }), document.createTextNode('Hold the phone upright and still for a moment')]),
        el('div', {}, [el('b', { text: '3. ' }), document.createTextNode('The Active badge lights up when sensor frames arrive')]),
        el('div', {}, [el('b', { text: '4. ' }), document.createTextNode('Recenter any time to reset your forward direction')])
      ]),
      err,
      el('div', { class: 'o360-landing-actions' }, [
        this._btn('Cancel', 'x', 'ghost', function () { self._closeLanding(); }),
        enableBtn
      ]),
      el('div', { class: 'o360-landing-foot', text: 'Requires HTTPS or localhost. Desktop falls back to mouse, touch and keyboard.' })
    ]);

    this.landing = el('div', { class: 'o360-landing', role: 'dialog', 'aria-modal': 'true', 'aria-label': 'Enable Motion Mode' }, [card]);
    this.host.appendChild(this.landing);
  };

  MotionUI.prototype._closeLanding = function () {
    if (this.landing) { this.landing.remove(); this.landing = null; }
  };

  MotionUI.prototype._openPanel = function () {
    var self = this;
    if (this.panel) return;

    this.panel = el('div', { class: 'o360-panel', role: 'region', 'aria-label': 'Motion Mode controls' });
    this.panel.appendChild(el('div', { class: 'o360-panel-head' }, [
      el('span', { class: 'o360-ico' }, [svgIcon('phone', 18)]),
      el('span', {}, [
        el('b', { text: 'Motion Mode' }),
        el('small', { text: 'DeviceOrientation · quaternion + SLERP' })
      ])
    ]));

    this.statusDot = el('span', { class: 'o360-sd' });
    this.statusText = el('span', { text: 'Waiting for sensors…' });
    this.statusEl = el('div', { class: 'o360-status' }, [this.statusDot, this.statusText]);
    this.panel.appendChild(this.statusEl);

    this.readout = el('div', { class: 'o360-readout' });
    this.panel.appendChild(this.readout);

    var grid = el('div', { class: 'o360-grid' }, [
      this._btn('Recenter', 'crosshair', 'primary', function () {
        self.motion.recenter();
        self.sound.play('blip');
        self._toast('View recentered to the scene’s initial direction', 'success');
      }),
      this._btn('Reset Orient.', 'undo', 'ghost', function () {
        self.motion.resetOrientation();
        self.sound.play('blip');
        self._toast('Orientation reset — current pose is now north / level', 'info');
      }),
      this._btn('Fullscreen', 'max', 'ghost', function () { self._fullscreen(); }),
      this._btn('Disable', 'x', 'danger', function () {
        self.motion.disable();
        self._closePanel();
        self.sound.play('blip');
        self._toast('Motion Mode off — touch, mouse and keys are back', 'info');
      })
    ]);
    this.panel.appendChild(grid);

    var smVal = el('b', { text: String(this.motion.smoothing) });
    var smSlider = el('input', {
      type: 'range', min: '4', max: '30', step: '1',
      value: String(this.motion.smoothing), 'aria-label': 'Motion smoothing'
    });
    smSlider.addEventListener('input', function () {
      self.motion.setSmoothing(parseFloat(smSlider.value));
      smVal.textContent = smSlider.value;
    }, { signal: this.ac.signal });
    this.panel.appendChild(el('div', { class: 'o360-slider' }, [
      el('div', { class: 'o360-slider-lab' }, [el('span', { text: 'Smoothing' }), smVal]),
      smSlider
    ]));

    var vrBtn = this._btn('Enter VR stereo', 'vr', 'ghost', function () { self.enterVR(); });
    vrBtn.style.width = '100%';
    vrBtn.style.justifyContent = 'center';
    this.panel.appendChild(vrBtn);

    this.panel.appendChild(el('div', {
      class: 'o360-note',
      text: 'Active only while real sensor frames arrive. Rotate the phone left/right to turn, tilt up for sky, down for ground. Portrait ↔ landscape is handled automatically.'
    }));

    this.host.appendChild(this.panel);
    this.sync();

    this._readoutTimer = setInterval(function () { self.sync(); }, 400);
  };

  MotionUI.prototype._closePanel = function () {
    if (this._readoutTimer) { clearInterval(this._readoutTimer); this._readoutTimer = null; }
    if (this.panel) { this.panel.remove(); this.panel = null; }
  };

  MotionUI.prototype.enterVR = function () {
    var self = this;
    this.vr.enter().then(function () {
      self.sound.play('vr');
      self._toast('VR mode — insert the phone into a Cardboard-style viewer', 'info');
    }).catch(function (e) {
      self.sound.play('error');
      self._toast(e.message || 'VR unavailable', 'warn');
    });
  };

  MotionUI.prototype._fullscreen = function () {
    var self = this;
    var host = this.host;
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      if (document.exitFullscreen) document.exitFullscreen();
      else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      return;
    }
    if (host.requestFullscreen) host.requestFullscreen().catch(function () { host.classList.add('o360-pseudo-fs'); });
    else if (host.webkitRequestFullscreen) host.webkitRequestFullscreen();
    else host.classList.add('o360-pseudo-fs');
    setTimeout(function () {
      if (typeof self.viewer.resize === 'function') self.viewer.resize();
    }, 120);
  };

  MotionUI.prototype.sync = function () {
    var m = this.motion;
    var live = m.status === 'live' && m.active;
    var wait = m.status === 'waiting';
    var label = live ? 'Motion Active' : wait ? 'Starting…' : 'Motion Mode';

    if (this.motionBtn) {
      this.motionBtn.classList.toggle('is-active', live);
      this.motionBtn.classList.toggle('is-waiting', wait);
      var span = this.motionBtn.querySelector('span:not(.o360-dot)');
      if (span) span.textContent = label;
    }
    if (this.fab) {
      this.fab.classList.toggle('is-active', live);
      var fl = this.fab.querySelector('span');
      if (fl) fl.textContent = label;
    }
    if (this.vrBtn) this.vrBtn.classList.toggle('is-active', this.vr.active);

    if (!this.panel) return;
    this.panel.classList.toggle('is-live', live);
    this.statusEl.className = 'o360-status' +
      (live ? ' is-live' : wait ? ' is-wait' : (m.status === 'error' || m.status === 'stale') ? ' is-error' : '');
    this.statusText.textContent = live
      ? 'Active · ' + (m.hz || '—') + ' Hz' + (m.absolute ? ' · absolute' : '')
      : wait ? 'Waiting for sensor frames…'
      : m.status === 'stale' ? 'Sensor stream paused'
      : m.status === 'error' ? 'Unavailable' : 'Off';

    var a = m.alpha != null ? m.alpha.toFixed(1) : '—';
    var b = m.beta != null ? m.beta.toFixed(1) : '—';
    var g = m.gamma != null ? m.gamma.toFixed(1) : '—';
    this.readout.textContent = '';
    this.readout.appendChild(document.createTextNode('α '));
    this.readout.appendChild(el('b', { text: a + '°' }));
    this.readout.appendChild(document.createTextNode(' · β '));
    this.readout.appendChild(el('b', { text: b + '°' }));
    this.readout.appendChild(document.createTextNode(' · γ '));
    this.readout.appendChild(el('b', { text: g + '°' }));
    this.readout.appendChild(el('br'));
    this.readout.appendChild(document.createTextNode((m.hz || '—') + ' Hz · screen ' + m.screenAngle() + '° · ' + (m.absolute ? 'absolute' : 'relative')));
    if (m.error) {
      this.readout.appendChild(el('br'));
      this.readout.appendChild(el('span', { style: { color: 'var(--o360-danger)' }, text: m.error }));
    }
  };

  MotionUI.prototype._toast = function (msg, type) {
    if (this.options.toast === false) return;
    if (typeof this.options.toast === 'function') { this.options.toast(msg, type); return; }
    var t = el('div', { class: 'o360-toast o360-toast--' + (type || 'info') }, [
      svgIcon(type === 'success' ? 'check' : (type === 'warn' || type === 'error') ? 'alert' : 'info', 16),
      el('span', { text: msg })
    ]);
    document.body.appendChild(t);
    setTimeout(function () {
      t.style.opacity = '0';
      t.style.transform = 'translateX(-22px)';
      t.style.transition = 'all .3s';
      setTimeout(function () { t.remove(); }, 320);
    }, 4200);
  };

  MotionUI.prototype.destroy = function () {
    this.ac.abort();
    this._closeLanding();
    this._closePanel();
    if (this.toolbar) this.toolbar.remove();
    if (this.fab) this.fab.remove();
    this.motion.onChange = null;
    this.vr.onChange = null;
  };

  /* ==========================================================================
     SECTION 7 — PUBLIC ATTACH HELPER + EXPORTS
     ========================================================================== */

  function attach(viewer, options) {
    options = options || {};
    if (!viewer || !viewer.camera) {
      throw new Error('[OrbisMotion] attach() requires a viewer object with a THREE camera.');
    }
    injectStyles();

    var soundBus = new SoundBus({ sound: options.sound !== false });
    var motion = new MotionController(viewer, {
      smoothing: options.smoothing,
      deadzone: options.deadzone,
      staleMs: options.staleMs,
      waitMs: options.waitMs
    });
    var vr = new StereoVR(viewer, {
      ipd: options.ipd,
      host: options.host,
      onIPDChange: options.onIPDChange
    });
    var ui = new MotionUI(viewer, motion, vr, {
      host: options.host,
      soundBus: soundBus,
      sound: options.sound !== false,
      toast: options.toast
    });

    // Expose on the viewer for compatibility with existing code paths.
    viewer.motion = motion;
    viewer.vr = vr;
    viewer.motionUI = ui;
    if (typeof viewer.toggleMotion !== 'function') {
      viewer.toggleMotion = function () { ui.toggleMotion(); };
    }

    return {
      motion: motion,
      vr: vr,
      ui: ui,
      sound: soundBus,
      update: function (dt) { return motion.update(dt); },
      render: function () { return vr.render(); },
      enableMotion: function () { return ui.toggleMotion(); },
      disableMotion: function () { motion.disable(); ui._closePanel(); },
      recenter: function () { motion.recenter(); },
      resetOrientation: function () { motion.resetOrientation(); },
      enterVR: function () { return ui.enterVR(); },
      exitVR: function () { return vr.exit(); },
      destroy: function () {
        ui.destroy();
        motion.destroy();
        vr.destroy();
        if (viewer.motion === motion) delete viewer.motion;
        if (viewer.vr === vr) delete viewer.vr;
        if (viewer.motionUI === ui) delete viewer.motionUI;
      }
    };
  }

  var api = {
    version: VERSION,
    MotionController: MotionController,
    StereoVR: StereoVR,
    MotionUI: MotionUI,
    SoundBus: SoundBus,
    attach: attach,
    quatFromYawPitch: quatFromYawPitch,
    dirFromQuat: dirFromQuat,
    injectStyles: injectStyles
  };

  // UMD-ish export: works with script tags, CommonJS, and ES modules.
  global.OrbisMotion = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof define === 'function' && define.amd) define(function () { return api; });

})(typeof window !== 'undefined' ? window : globalThis);
'@

# ============================================================================
# End of Block 4/6. 37 files written so far.
# Append Block 5 below this line in the SAME build-orbis360.ps1 file.
# ============================================================================# ============================================================================
# Block 5/6 - client: hotspots.js + viewer.js (OrbisMotion-integrated)
# ============================================================================

W 'client/assets/js/hotspots.js' @'
/**
 * 3D hotspot layer: ground navigation arrows + info points.
 * Handles rendering, hover labels, info popups, and the editor
 * (place by clicking the sphere, drag to reposition).
 */
import * as THREE from 'three';
import { clamp, rad, deg, norm360, el } from './utils.js';
import { iconEl } from './ui.js';

let arrowTexture = null;
let infoTexture = null;

function makeArrowTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const x = c.getContext('2d');
  x.fillStyle = 'rgba(255,255,255,.16)';
  x.beginPath(); x.arc(128, 128, 112, 0, Math.PI * 2); x.fill();
  x.strokeStyle = 'rgba(255,255,255,.9)'; x.lineWidth = 10;
  x.beginPath(); x.arc(128, 128, 112, 0, Math.PI * 2); x.stroke();
  x.lineCap = 'round'; x.lineJoin = 'round'; x.lineWidth = 20; x.strokeStyle = '#fff';
  x.beginPath(); x.moveTo(78, 140); x.lineTo(128, 92); x.lineTo(178, 140); x.stroke();
  x.globalAlpha = 0.55;
  x.beginPath(); x.moveTo(84, 182); x.lineTo(128, 140); x.lineTo(172, 182); x.stroke();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function makeInfoTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const x = c.getContext('2d');
  x.fillStyle = 'rgba(255,180,84,.95)';
  x.beginPath(); x.arc(64, 64, 52, 0, Math.PI * 2); x.fill();
  x.strokeStyle = 'rgba(255,255,255,.95)'; x.lineWidth = 7;
  x.beginPath(); x.arc(64, 64, 52, 0, Math.PI * 2); x.stroke();
  x.fillStyle = '#3a2405';
  x.font = 'bold 62px Georgia, serif';
  x.textAlign = 'center'; x.textBaseline = 'middle';
  x.fillText('i', 64, 68);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export class HotspotLayer {
  constructor(viewer, options = {}) {
    this.viewer = viewer;
    this.opts = options;
    this.editable = !!options.editable;
    this.group = new THREE.Group();
    this.group.name = 'hotspots';
    viewer.three.add(this.group);

    if (!arrowTexture) arrowTexture = makeArrowTexture();
    if (!infoTexture) infoTexture = makeInfoTexture();

    this.raycaster = new THREE.Raycaster();
    this.items = [];
    this.hotspots = [];
    this.hover = null;
    this.placing = null;
    this.ghost = null;
    this.dragItem = null;
    this.dragMoved = false;
    this.visible = true;
    this.activeInfo = null;
    this.infoEl = null;
    this._labelT = 0;

    this.labels = el('div', { class: 'v-labels' });
    viewer.mount.appendChild(this.labels);
  }

  setHotspots(hotspots) {
    this.hotspots = hotspots || [];
    this.rebuild();
  }

  rebuild() {
    this.setHover(null);
    this.closeInfo();
    for (const item of this.items) {
      item.mesh.material.dispose();
      if (item.mesh.geometry) item.mesh.geometry.dispose();
      this.group.remove(item.mesh);
    }
    this.items = [];

    for (const h of this.hotspots) {
      let mesh;
      if (h.type === 'nav') {
        mesh = new THREE.Mesh(
          new THREE.PlaneGeometry(2.7, 2.7),
          new THREE.MeshBasicMaterial({ map: arrowTexture, transparent: true, depthWrite: false, side: THREE.DoubleSide })
        );
        mesh.renderOrder = 2;
      } else {
        mesh = new THREE.Sprite(new THREE.SpriteMaterial({ map: infoTexture, transparent: true, depthTest: false }));
        mesh.scale.set(1.35, 1.35, 1);
        mesh.renderOrder = 3;
      }
      mesh.userData.hotspot = h;
      this.position(mesh, h);
      this.group.add(mesh);
      this.items.push({ mesh, data: h });
    }
    this.group.visible = this.visible;
    this.renderLabels();
  }

  position(mesh, h) {
    if (h.type === 'nav') {
      const R = 9, Y = -2.05;
      mesh.position.set(Math.sin(rad(h.yaw)) * R, Y, -Math.cos(rad(h.yaw)) * R);
      mesh.rotation.order = 'YXZ';
      mesh.rotation.set(-Math.PI / 2, -rad(h.yaw), 0);
    } else {
      const d = new THREE.Vector3(
        Math.sin(rad(h.yaw)) * Math.cos(rad(h.pitch)),
        Math.sin(rad(h.pitch)),
        -Math.cos(rad(h.yaw)) * Math.cos(rad(h.pitch))
      );
      mesh.position.copy(d.multiplyScalar(11));
    }
  }

  setVisible(v) {
    this.visible = !!v;
    this.group.visible = !!v;
    if (!v) { this.setHover(null); this.closeInfo(); }
    this.renderLabels();
  }

  ndc(event) {
    const r = this.viewer.canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - r.left) / r.width) * 2 - 1,
      y: -((event.clientY - r.top) / r.height) * 2 + 1
    };
  }

  rayDir(event) {
    this.raycaster.setFromCamera(this.ndc(event), this.viewer.camera);
    return this.raycaster.ray.direction.clone();
  }

  pick(event) {
    if (!this.group.visible) return null;
    this.raycaster.setFromCamera(this.ndc(event), this.viewer.camera);
    const meshes = this.items.map((i) => i.mesh);
    return this.raycaster.intersectObjects(meshes, false)[0]?.object || null;
  }

  setHover(mesh) {
    if (this.hover === mesh) return;
    if (this.hover) this.hover.material.color.set(0xffffff);
    this.hover = mesh;
    if (mesh) {
      mesh.material.color.set(0xffd9a0);
      this.viewer.canvas.style.cursor = 'pointer';
    } else {
      this.viewer.canvas.style.cursor = this.placing ? 'crosshair' : 'grab';
    }
    this.renderLabels();
  }

  updateHover(event) {
    if (this.placing || this.dragItem) return;
    this.setHover(this.pick(event));
  }

  handleClick(event) {
    if (this.placing) {
      const d = this.rayDir(event);
      const yaw = norm360(deg(Math.atan2(d.x, -d.z)));
      const pitch = this.placing === 'nav' ? -12 : clamp(deg(Math.asin(d.y)), -80, 80);
      this.opts.onPlace?.(this.placing, yaw, pitch);
      return true;
    }
    const mesh = this.pick(event);
    if (!mesh) return false;
    const h = mesh.userData.hotspot;
    if (this.editable) { this.opts.onEdit?.(h); return true; }
    if (h.type === 'nav') this.opts.onNavigate?.(h);
    else this.openInfo(h);
    return true;
  }

  beginDrag(event) {
    if (!this.editable || this.placing) return false;
    const mesh = this.pick(event);
    if (!mesh) return false;
    this.dragItem = this.items.find((i) => i.mesh === mesh) || null;
    this.dragMoved = false;
    return !!this.dragItem;
  }

  drag(event) {
    if (!this.dragItem) return;
    this.dragMoved = true;
    const d = this.rayDir(event);
    const h = this.dragItem.data;
    h.yaw = norm360(deg(Math.atan2(d.x, -d.z)));
    if (h.type === 'info') h.pitch = clamp(deg(Math.asin(d.y)), -85, 85);
    this.position(this.dragItem.mesh, h);
    this.renderLabels();
  }

  endDrag() {
    if (!this.dragItem) return null;
    const item = this.dragItem;
    this.dragItem = null;
    if (this.dragMoved) {
      this.opts.onMoved?.(item.data);
      return { moved: true, data: item.data };
    }
    this.opts.onEdit?.(item.data);
    return { moved: false, data: item.data };
  }

  setPlacing(type) {
    this.placing = type || null;
    this.viewer.mount.classList.toggle('placing', !!type);
    this.viewer.canvas.style.cursor = type ? 'crosshair' : 'grab';
    if (this.ghost) {
      this.ghost.material.dispose();
      if (this.ghost.geometry) this.ghost.geometry.dispose();
      this.group.remove(this.ghost);
      this.ghost = null;
    }
    if (!type) return;
    this.ghost = type === 'nav'
      ? new THREE.Mesh(new THREE.PlaneGeometry(2.7, 2.7),
          new THREE.MeshBasicMaterial({ map: arrowTexture, transparent: true, opacity: 0.5, depthWrite: false, side: THREE.DoubleSide }))
      : new THREE.Sprite(new THREE.SpriteMaterial({ map: infoTexture, transparent: true, opacity: 0.55, depthTest: false }));
    if (type === 'info') this.ghost.scale.set(1.35, 1.35, 1);
    this.ghost.renderOrder = 4;
    this.group.add(this.ghost);
  }

  moveGhost(event) {
    if (!this.ghost || !this.placing) return;
    const d = this.rayDir(event);
    this.position(this.ghost, {
      type: this.placing,
      yaw: norm360(deg(Math.atan2(d.x, -d.z))),
      pitch: this.placing === 'info' ? deg(Math.asin(d.y)) : -12
    });
  }

  openInfo(h) {
    this.closeInfo();
    this.activeInfo = h;
    const node = el('div', { class: 'info-pop' }, [
      el('button', { class: 'icon-btn sm x', type: 'button', onclick: () => this.closeInfo() }, [iconEl('x', 14)]),
      el('h4', { text: h.label || 'Info' })
    ]);
    if (h.imageUrl) node.appendChild(el('img', { src: h.imageUrl, alt: h.label || '', loading: 'lazy' }));
    if (h.body) node.appendChild(el('p', { text: h.body }));
    if (h.linkUrl) {
      node.appendChild(el('a', {
        class: 'btn btn-ghost btn-sm', href: h.linkUrl, target: '_blank', rel: 'noopener noreferrer',
        style: { marginTop: '10px' }
      }, [iconEl('external', 14), 'Open link']));
    }
    this.viewer.mount.appendChild(node);
    this.infoEl = node;
  }

  closeInfo() { this.activeInfo = null; this.infoEl?.remove(); this.infoEl = null; }

  renderLabels() {
    this.labels.textContent = '';
    if (!this.visible) return;
    const list = this.editable ? this.hotspots : (this.hover ? [this.hover.userData.hotspot] : []);
    if (!list.length) return;
    const w = this.viewer.mount.clientWidth, h = this.viewer.mount.clientHeight;
    const camDir = this.viewer.camera.getWorldDirection(new THREE.Vector3());

    for (const hs of list) {
      const item = this.items.find((i) => i.data.id === hs.id);
      if (!item) continue;
      if (camDir.dot(item.mesh.position.clone().normalize()) < 0) continue;
      const v = item.mesh.position.clone().project(this.viewer.camera);
      if (v.z > 1) continue;
      const label = el('div', { class: 'h-label' }, [
        el('small', {
          text: hs.type === 'nav' ? 'GO →' : 'INFO',
          style: hs.type === 'info' ? { color: 'var(--amber)' } : {}
        }),
        hs.label || (hs.type === 'nav' ? this.opts.sceneTitle?.(hs.targetScene) || 'Scene' : 'Info')
      ]);
      label.style.left = `${(v.x * 0.5 + 0.5) * w}px`;
      label.style.top = `${(-v.y * 0.5 + 0.5) * h}px`;
      this.labels.appendChild(label);
    }
  }

  update(time) {
    const pulse = 1 + 0.045 * Math.sin(time * 0.0022);
    for (const item of this.items) {
      const base = item.mesh.isSprite ? 1.35 : 1;
      const s = base * pulse * (this.hover === item.mesh ? 1.16 : 1);
      item.mesh.scale.set(s, s, 1);
    }
    if (this.infoEl && this.activeInfo) {
      const item = this.items.find((i) => i.data.id === this.activeInfo.id);
      if (item) {
        const v = item.mesh.position.clone().project(this.viewer.camera);
        const w = this.viewer.mount.clientWidth, h = this.viewer.mount.clientHeight;
        if (v.z < 1) {
          this.infoEl.style.display = '';
          this.infoEl.style.left = `${clamp((v.x * 0.5 + 0.5) * w, 150, w - 150)}px`;
          this.infoEl.style.top = `${clamp((-v.y * 0.5 + 0.5) * h, 130, h - 40)}px`;
        } else this.infoEl.style.display = 'none';
      }
    }
    if ((this.editable || this.hover) && time - this._labelT > 90) {
      this._labelT = time;
      this.renderLabels();
    }
  }

  dispose() {
    this.closeInfo();
    for (const item of this.items) {
      item.mesh.material.dispose();
      if (item.mesh.geometry) item.mesh.geometry.dispose();
    }
    if (this.ghost) {
      this.ghost.material.dispose();
      if (this.ghost.geometry) this.ghost.geometry.dispose();
    }
    this.group.clear();
    this.viewer.three.remove(this.group);
    this.labels.remove();
    this.items = [];
  }
}
'@

W 'client/assets/js/viewer.js' @'
/**
 * 360° equirectangular viewer.
 * Correct spherical mapping, progressive preview→texture loading,
 * drag / touch / wheel / keyboard controls, transitions, guides,
 * Motion Mode and stereoscopic VR via the OrbisMotion module
 * (client/assets/js/orbis360-motion-vr.js, loaded as a classic script).
 */
import * as THREE from 'three';
import {
  clamp, rad, deg, norm360, angDelta, el, prefs, isMobile, reduceMotion,
  dirFromYawPitch, downloadBlob
} from './utils.js';
import { icon, iconEl, sound, toast, isModalOpen } from './ui.js';
import { HotspotLayer } from './hotspots.js';

/* OrbisMotion is published on window by the classic UMD script. */
const OM = globalThis.OrbisMotion || null;

/* ---- texture cache: never evict a texture that is currently bound ---- */
const texCache = new Map();
const loader = new THREE.TextureLoader();

function loadTexture(url) {
  if (texCache.has(url)) {
    const e = texCache.get(url);
    e.t = Date.now();
    return Promise.resolve(e.tex);
  }
  return new Promise((resolve, reject) => {
    loader.load(url, (tex) => {
      tex.colorSpace = THREE.SRGBColorSpace;
      tex.wrapS = THREE.RepeatWrapping;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      tex.magFilter = THREE.LinearFilter;
      tex.generateMipmaps = true;
      texCache.set(url, { tex, t: Date.now(), pinned: 0 });
      resolve(tex);
    }, undefined, () => reject(new Error(`Could not load image: ${url}`)));
  });
}

function pin(url, on) {
  const e = texCache.get(url);
  if (e) e.pinned = Math.max(0, e.pinned + (on ? 1 : -1));
}

function evict(max = 5) {
  while (texCache.size > max) {
    let oldest = null;
    for (const [url, e] of texCache) {
      if (e.pinned > 0) continue;
      if (!oldest || e.t < oldest.e.t) oldest = { url, e };
    }
    if (!oldest) break;
    oldest.e.tex.dispose();
    texCache.delete(oldest.url);
  }
}

export class Viewer {
  constructor(mount, opts = {}) {
    this.mount = mount;
    this.opts = opts;
    this.destroyed = false;
    this.ac = new AbortController();

    this.yaw = 0; this.pitch = 0; this.fov = 75;
    this.vel = { x: 0, y: 0 };
    this.tweens = [];
    this.pointers = new Map();
    this.lastInteract = 0;
    this.loadToken = 0;
    this.transitioning = false;
    this.scene = null;
    this.pinnedUrls = [];
    this.hero = !!opts.hero;
    this.editable = !!opts.editable;
    this._ccT = 0;
    this._lastT = 0;

    if (OM) {
      this.motion = new OM.MotionController(this, {
        smoothing: prefs.get('motionSmoothing'),
        onSmoothingChange: (v) => prefs.set('motionSmoothing', v)
      });
      this.vr = new OM.StereoVR(this, {
        ipd: prefs.get('vrIPD'),
        host: opts.fsTarget || mount.parentElement,
        onIPDChange: (v) => prefs.set('vrIPD', v)
      });
    } else {
      this.motion = null;
      this.vr = null;
    }
  }

  async init() {
    const renderer = this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.setClearColor(0x05070d);
    this.canvas = renderer.domElement;
    this.mount.appendChild(this.canvas);

    this.three = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1200);

    this.geometry = new THREE.SphereGeometry(500, 96, 64);
    this.geometry.scale(-1, 1, 1);
    this.matA = new THREE.MeshBasicMaterial({ color: 0xffffff });
    this.meshA = new THREE.Mesh(this.geometry, this.matA);
    this.three.add(this.meshA);

    this.matB = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
    this.meshB = new THREE.Mesh(this.geometry, this.matB);
    this.meshB.visible = false;
    this.meshB.renderOrder = 1;
    this.three.add(this.meshB);

    this.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
    this._buildGuides();

    this.veil = el('div', { class: 'v-veil' });
    this.mount.appendChild(this.veil);

    this.hotspots = new HotspotLayer(this, {
      editable: this.editable,
      onNavigate: (h) => this.opts.onNavigate?.(h),
      onPlace: (type, yaw, pitch) => this.opts.onPlace?.(type, yaw, pitch),
      onEdit: (h) => this.opts.onEditHotspot?.(h),
      onMoved: (h) => this.opts.onMovedHotspot?.(h),
      sceneTitle: (id) => this.opts.sceneTitle?.(id)
    });
    this.hotspots.setVisible(this.hero ? false : prefs.get('hotspots'));

    if (OM && !this.hero) {
      this.motionUI = new OM.MotionUI(this, this.motion, this.vr, {
        host: this.opts.fsTarget || this.mount.parentElement,
        sound: prefs.get('sound'),
        toast: (msg, type) => toast(msg, type)
      });
    } else {
      this.motionUI = null;
    }

    this._bind();
    this.ro = new ResizeObserver(() => this.resize());
    this.ro.observe(this.mount);
    this.resize();
    this.applyFilter();
    this._raf = requestAnimationFrame((t) => this._frame(t));
    return this;
  }

  /* ---------- guides ---------- */
  _buildGuides() {
    const g = this.guides = new THREE.Group();
    g.visible = prefs.get('guides') && !this.hero;
    const wireGeo = new THREE.SphereGeometry(492, 36, 18);
    wireGeo.scale(-1, 1, 1);
    g.add(new THREE.Mesh(wireGeo, new THREE.MeshBasicMaterial({ color: 0x3fd9ff, wireframe: true, transparent: true, opacity: 0.07 })));

    const pts = [];
    for (let i = 0; i <= 128; i++) {
      const a = (i / 128) * Math.PI * 2;
      pts.push(new THREE.Vector3(Math.sin(a) * 488, 0, -Math.cos(a) * 488));
    }
    g.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts),
      new THREE.LineBasicMaterial({ color: 0x3fd9ff, transparent: true, opacity: 0.35 })));

    [['N', 0, '#ff5d73'], ['E', 90, '#3fd9ff'], ['S', 180, '#3fd9ff'], ['W', 270, '#3fd9ff']]
      .forEach(([txt, yaw, col]) => {
        const c = document.createElement('canvas');
        c.width = c.height = 128;
        const x = c.getContext('2d');
        x.font = 'bold 84px system-ui, sans-serif';
        x.textAlign = 'center'; x.textBaseline = 'middle';
        x.fillStyle = col;
        x.fillText(txt, 64, 68);
        const tex = new THREE.CanvasTexture(c);
        tex.colorSpace = THREE.SRGBColorSpace;
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthTest: false }));
        sp.position.set(Math.sin(rad(yaw)) * 470, 14, -Math.cos(rad(yaw)) * 470);
        sp.scale.set(34, 34, 1);
        g.add(sp);
      });
    this.three.add(g);
  }

  resize() {
    if (this.destroyed || !this.renderer) return;
    const w = this.mount.clientWidth || 1, h = this.mount.clientHeight || 1;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  applyFilter() {
    if (this.canvas) {
      this.canvas.style.filter = `brightness(${prefs.get('brightness')}%) saturate(${prefs.get('saturation')}%)`;
    }
  }

  initialQuat() {
    const { quatFromYawPitch } = OM || {};
    if (typeof quatFromYawPitch === 'function') {
      return quatFromYawPitch(this.scene?.heading || 0, this.scene?.pitch || 0);
    }
    return this.camera.quaternion.clone();
  }

  getView() { return { yaw: norm360(deg(this.yaw)), pitch: deg(this.pitch), fov: this.fov }; }

  toggleMotion() {
    if (this.motionUI) this.motionUI.toggleMotion();
    else toast('Motion module unavailable', 'warn');
  }

  enterVR() {
    if (this.motionUI) this.motionUI.enterVR();
    else if (this.vr) this.vr.enter().catch((e) => toast(e.message || 'VR unavailable', 'warn'));
    else toast('VR module unavailable', 'warn');
  }

  /* ---------- input ---------- */
  _bind() {
    const sig = { signal: this.ac.signal };
    const cv = this.canvas;

    cv.addEventListener('pointerdown', (e) => {
      cv.setPointerCapture(e.pointerId);
      this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, t: performance.now() });
      if (this.pointers.size === 2) {
        const p = [...this.pointers.values()];
        this.pinch = { d: Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y), fov: this.fov };
      }
      if (!(this.motion && this.motion.active) && this.pointers.size === 1) this.hotspots.beginDrag(e);
      this.vel.x = this.vel.y = 0;
      this.lastInteract = performance.now();
      this._moveT = performance.now();
    }, sig);

    cv.addEventListener('pointermove', (e) => {
      this.hotspots.moveGhost(e);
      if (!this.pointers.size) { this.hotspots.updateHover(e); return; }
      const p = this.pointers.get(e.pointerId);
      if (!p) return;

      if (this.hotspots.dragItem) { this.hotspots.drag(e); return; }
      if (this.motion && this.motion.active) { p.x = e.clientX; p.y = e.clientY; return; }

      const dx = e.clientX - p.x, dy = e.clientY - p.y;
      const now = performance.now();
      const dt = Math.max(8, now - (this._moveT || now));
      this._moveT = now;

      if (this.pointers.size === 2 && this.pinch) {
        p.x = e.clientX; p.y = e.clientY;
        const pp = [...this.pointers.values()];
        const d = Math.hypot(pp[0].x - pp[1].x, pp[0].y - pp[1].y);
        this.setFov(this.pinch.fov * this.pinch.d / Math.max(20, d));
        return;
      }

      const k = 0.0031 * (this.fov / 75);
      this.yaw -= dx * k;
      this.pitch = clamp(this.pitch + dy * k, -1.48, 1.48);
      this.vel.x = (-dx * k) / (dt / 1000);
      this.vel.y = (dy * k) / (dt / 1000);
      p.x = e.clientX; p.y = e.clientY;
      this.lastInteract = now;
    }, sig);

    const up = (e) => {
      const p = this.pointers.get(e.pointerId);
      this.pointers.delete(e.pointerId);
      if (this.pointers.size < 2) this.pinch = null;
      if (this.hotspots.dragItem) { this.hotspots.endDrag(); return; }
      if (!p) return;
      const moved = Math.hypot(e.clientX - p.sx, e.clientY - p.sy);
      if (moved < 6 && performance.now() - p.t < 450) this.hotspots.handleClick(e);
      else if (performance.now() - this._moveT > 90) { this.vel.x = this.vel.y = 0; }
      this.lastInteract = performance.now();
    };
    cv.addEventListener('pointerup', up, sig);
    cv.addEventListener('pointercancel', up, sig);
    cv.addEventListener('pointerleave', () => this.hotspots.setHover(null), sig);

    cv.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.setFov(this.fov + e.deltaY * 0.035);
      this.lastInteract = performance.now();
    }, { passive: false, signal: this.ac.signal });

    window.addEventListener('keydown', (e) => {
      const tag = (e.target.tagName || '').toLowerCase();
      if (['input', 'textarea', 'select'].includes(tag) || isModalOpen()) return;
      const step = 3.2;
      const motionLive = this.motion && this.motion.active;
      switch (e.key) {
        case 'ArrowLeft': if (!motionLive) this.yaw -= rad(step); this.lastInteract = performance.now(); e.preventDefault(); break;
        case 'ArrowRight': if (!motionLive) this.yaw += rad(step); this.lastInteract = performance.now(); e.preventDefault(); break;
        case 'ArrowUp': if (!motionLive) this.pitch = clamp(this.pitch + rad(step * 0.6), -1.48, 1.48); e.preventDefault(); break;
        case 'ArrowDown': if (!motionLive) this.pitch = clamp(this.pitch - rad(step * 0.6), -1.48, 1.48); e.preventDefault(); break;
        case '+': case '=': this.setFov(this.fov - 4); break;
        case '-': case '_': this.setFov(this.fov + 4); break;
        case 'f': case 'F': this.toggleFullscreen(); break;
        case 'g': case 'G': this._togglePref('guides'); break;
        case 'h': case 'H': this._togglePref('hotspots'); break;
        case 'i': case 'I': this.opts.onInfoToggle?.(); break;
        case 'r': case 'R': this.resetView(); break;
        case 'm': case 'M': this.opts.onMinimapToggle?.(); break;
        case 'Escape': this.hotspots.closeInfo(); this.opts.onEscape?.(); break;
        default: break;
      }
    }, sig);

    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && !this.destroyed) this._lastT = performance.now();
    }, sig);
  }

  _togglePref(key) {
    const v = !prefs.get(key);
    prefs.set(key, v);
    if (key === 'guides') this.guides.visible = v;
    if (key === 'hotspots') this.hotspots.setVisible(v);
    this.syncDock();
    sound.play('blip');
  }

  setFov(f) {
    this.fov = clamp(f, 30, 100);
    this.camera.fov = this.fov;
    this.camera.updateProjectionMatrix();
    this.syncDock(true);
  }

  animateTo(yawDeg, pitchDeg, fov, dur = 500) {
    this.tweens = this.tweens.filter((t) => t.tag !== 'cam');
    const from = { y: deg(this.yaw), p: deg(this.pitch), f: this.fov };
    const dy = angDelta(from.y, yawDeg);
    this.tweens.push({
      tag: 'cam', t0: performance.now(), dur,
      fn: (k) => {
        const e = 1 - Math.pow(1 - k, 3);
        this.yaw = rad(from.y + dy * e);
        this.pitch = rad(from.p + (pitchDeg - from.p) * e);
        this.setFov(from.f + (fov - from.f) * e);
      }
    });
  }

  resetView() {
    if (this.motion && this.motion.active) { this.motion.recenter(); sound.play('blip'); return; }
    if (this.scene) this.animateTo(this.scene.heading || 0, this.scene.pitch || 0, this.scene.fov || 75, 600);
    sound.play('blip');
  }

  randomView() {
    if (this.motion && this.motion.active) return;
    this.animateTo(Math.random() * 360, -5 + Math.random() * 38, 55 + Math.random() * 30, 700);
    sound.play('blip');
  }

  veilTo(opacity, dur) {
    return new Promise((resolve) => {
      const from = parseFloat(this.veil.style.opacity || '0');
      this.tweens = this.tweens.filter((t) => t.tag !== 'veil');
      this.tweens.push({
        tag: 'veil', t0: performance.now(), dur,
        fn: (k) => { this.veil.style.opacity = String(from + (opacity - from) * k); },
        done: resolve
      });
    });
  }

  /* ---------- scene loading ---------- */
  async setScene(scene, { yaw = null, pitch = null, fov = null, useHeading = false } = {}) {
    const token = ++this.loadToken;
    this.scene = scene;
    this.tweens = this.tweens.filter((t) => t.tag !== 'fade');
    this.meshB.visible = false;
    this.matB.opacity = 0;
    this.opts.onSceneChange?.(scene);
    this._loading(true, 'Loading preview…');

    const asset = scene.asset;
    let preview;
    try {
      preview = await loadTexture(asset.preview.url);
    } catch (err) {
      if (token === this.loadToken) { this._loading(false); this._error(err.message); }
      return;
    }
    if (token !== this.loadToken || this.destroyed) return;

    this._releasePins();
    pin(asset.preview.url, true);
    this.pinnedUrls.push(asset.preview.url);

    preview.anisotropy = this.anisotropy;
    preview.offset.x = scene.northOffset || 0;
    this.matA.map = preview;
    this.matA.needsUpdate = true;

    if (useHeading || yaw == null) {
      this.yaw = rad(scene.heading || 0);
      this.pitch = rad(scene.pitch || 0);
      this.fov = scene.fov || 75;
    } else {
      this.yaw = rad(yaw);
      this.pitch = rad(pitch ?? 0);
      this.fov = fov || scene.fov || 75;
    }
    this.setFov(this.fov);
    this.vel.x = this.vel.y = 0;
    if (this.motion && this.motion.active) this.motion.calibrateTo(this.initialQuat());

    this.hotspots.setHotspots(scene.hotspots || []);
    this._loading(true, 'Loading full resolution…');
    this._loadFull(scene, token);
  }

  async _loadFull(scene, token) {
    const asset = scene.asset;
    const cap = this._qualityCap();
    const useFull = asset.texture.width <= cap;
    const url = useFull ? asset.texture.url : asset.preview.url;

    try {
      const tex = await loadTexture(url);
      if (token !== this.loadToken || this.destroyed) return;
      pin(url, true);
      this.pinnedUrls.push(url);
      tex.anisotropy = this.anisotropy;
      tex.offset.x = scene.northOffset || 0;

      this.matB.map = tex;
      this.matB.needsUpdate = true;
      this.meshB.visible = true;
      this.matB.opacity = 0;
      this.tweens.push({
        tag: 'fade', t0: performance.now(), dur: 320,
        fn: (k) => { this.matB.opacity = k; },
        done: () => {
          if (this.destroyed) return;
          this.matA.map = tex;
          this.matA.needsUpdate = true;
          this.meshB.visible = false;
          this.matB.opacity = 0;
        }
      });
      this._loading(false);
      this.opts.onResolution?.(tex.image.width, tex.image.height);
      evict();
    } catch {
      if (token === this.loadToken) {
        this._loading(false);
        toast('Full resolution unavailable — showing the preview instead', 'warn');
      }
    }
  }

  _releasePins() {
    for (const u of this.pinnedUrls) pin(u, false);
    this.pinnedUrls = [];
  }

  _qualityCap() {
    const q = prefs.get('quality');
    const gpuMax = this.renderer.capabilities.maxTextureSize || 4096;
    const auto = isMobile ? Math.min(8192, gpuMax) : Math.min(16384, gpuMax);
    return q === 'auto' ? auto : parseInt(q, 10);
  }

  async reloadQuality() {
    if (!this.scene) return;
    const token = ++this.loadToken;
    this._loading(true, 'Re-encoding texture…');
    await this._loadFull(this.scene, token);
  }

  async goScene(scene, { yaw = null, pitch = null } = {}) {
    if (this.transitioning || scene.id === this.scene?.id) return;
    this.transitioning = true;
    this.hotspots.closeInfo();
    sound.play('whoosh');
    const motionLive = this.motion && this.motion.active;
    if (!motionLive && yaw != null) this.animateTo(yaw, -2, Math.max(34, this.fov - 14), 280);
    await this.veilTo(1, 240);
    await this.setScene(scene, yaw != null ? { yaw, pitch: pitch ?? -2 } : { useHeading: true });
    await this.veilTo(0, 360);
    this.transitioning = false;
  }

  _loading(on, msg) { this.opts.onLoading?.(on, msg); }

  _error(message) {
    this.veil.classList.add('err');
    this.veil.style.opacity = '1';
    this.veil.textContent = '';
    this.veil.appendChild(el('div', { style: { textAlign: 'center', maxWidth: '340px', padding: '20px', color: '#fff' } }, [
      el('div', { style: { color: 'var(--warning)', marginBottom: '10px' } }, [iconEl('alert', 30)]),
      el('h3', { class: 'disp', text: 'Panorama unavailable' }),
      el('p', { style: { color: '#9aa7c4', fontSize: '13.5px', margin: '8px 0 16px' }, text: message }),
      el('button', {
        class: 'btn btn-primary btn-sm', type: 'button',
        onclick: () => {
          this.veil.classList.remove('err');
          this.veil.textContent = '';
          this.veil.style.opacity = '0';
          if (this.scene) this.setScene(this.scene, { useHeading: true });
        }
      }, [iconEl('rotate', 15), 'Retry'])
    ]));
  }

  /* ---------- fullscreen / screenshot ---------- */
  async toggleFullscreen() {
    const host = this.opts.fsTarget || this.mount.parentElement;
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      try { await document.exitFullscreen(); } catch { /* ignore */ }
      return;
    }
    if (host.classList.contains('pseudo-fs')) {
      host.classList.remove('pseudo-fs');
      setTimeout(() => this.resize(), 120);
      return;
    }
    try {
      if (host.requestFullscreen) await host.requestFullscreen();
      else if (host.webkitRequestFullscreen) host.webkitRequestFullscreen();
      else host.classList.add('pseudo-fs');
    } catch { host.classList.add('pseudo-fs'); }
    setTimeout(() => this.resize(), 120);
  }

  screenshot() {
    this.renderer.render(this.three, this.camera);
    this.canvas.toBlob((blob) => {
      if (!blob) return toast('Could not export the view', 'error');
      downloadBlob(blob, `${(this.scene?.title || 'panorama').replace(/[^\w-]+/g, '_')}_view.jpg`);
      toast('View exported as JPG', 'success');
      sound.play('chime');
    }, 'image/jpeg', 0.92);
  }

  /* ---------- control dock ---------- */
  buildDock(slot) {
    const range = (id, ic, label, min, max, val, unit = '') => `
      <div class="dock-group">
        <span class="dock-label">${icon(ic, 11)} ${label} <b data-rv="${id}">${Math.round(val)}${unit}</b></span>
        <input type="range" data-r="${id}" min="${min}" max="${max}" value="${Math.round(val)}" aria-label="${label}">
      </div>`;
    const tog = (id, ic, label, on) =>
      `<button class="icon-btn${on ? ' on' : ''}" data-t="${id}" title="${label}" aria-pressed="${on}" type="button">${icon(ic, 17)}</button>`;

    slot.innerHTML = `<div class="dock">
      <div class="dock-group dock-btns">
        <button class="icon-btn" data-b="zout" title="Zoom out" type="button">${icon('minus', 16)}</button>
        <button class="icon-btn" data-b="zin" title="Zoom in" type="button">${icon('plus', 16)}</button>
      </div>
      ${range('fov', 'search', 'FOV', 30, 100, this.fov, '°')}
      ${range('brightness', 'sun', 'Light', 60, 140, prefs.get('brightness'))}
      ${range('saturation', 'image', 'Color', 0, 180, prefs.get('saturation'))}
      ${range('drift', 'rotate', 'Drift', 0, 100, prefs.get('drift'))}
      <div class="dock-group dock-toggles">
        ${tog('autoRotate', 'rotate', 'Auto-rotate drift', prefs.get('autoRotate'))}
        ${tog('guides', 'grid', 'Projection guides (G)', prefs.get('guides'))}
        ${tog('hotspots', 'nav', 'Hotspots (H)', prefs.get('hotspots'))}
      </div>
      <div class="dock-group">
        <span class="dock-label">${icon('layers', 11)} Quality</span>
        <select data-q aria-label="Texture quality">
          ${['auto', '12000', '8192', '4096', '2048'].map((q) =>
            `<option value="${q}"${prefs.get('quality') === q ? ' selected' : ''}>${q === 'auto' ? 'Auto' : `${Math.round(q / 1024)}K`}</option>`).join('')}
        </select>
      </div>
      <div class="dock-group dock-btns">
        <button class="icon-btn" data-b="reset" title="Reset view (R)" type="button">${icon('undo', 16)}</button>
        <button class="icon-btn" data-b="random" title="Random view" type="button">${icon('shuffle', 16)}</button>
        <button class="icon-btn" data-b="shot" title="Export view as JPG" type="button">${icon('camera', 16)}</button>
        <button class="icon-btn" data-b="fs" title="Fullscreen (F)" type="button">${icon('max', 16)}</button>
      </div>
    </div>`;

    const dock = this.dock = slot.firstElementChild;

    dock.addEventListener('input', (e) => {
      const id = e.target.dataset.r;
      if (!id) return;
      const val = Number(e.target.value);
      const rv = dock.querySelector(`[data-rv="${id}"]`);
      if (id === 'fov') { this.setFov(val); rv.textContent = `${Math.round(this.fov)}°`; }
      else if (id === 'brightness' || id === 'saturation') { prefs.set(id, val); rv.textContent = String(Math.round(val)); this.applyFilter(); }
      else if (id === 'drift') { prefs.set('drift', val); rv.textContent = String(Math.round(val)); }
    }, { signal: this.ac.signal });

    dock.addEventListener('click', (e) => {
      const t = e.target.closest('[data-t]');
      if (t) { this._togglePref(t.dataset.t); return; }
      const b = e.target.closest('[data-b]');
      if (!b) return;
      const id = b.dataset.b;
      if (id === 'zin') this.setFov(this.fov - 6);
      else if (id === 'zout') this.setFov(this.fov + 6);
      else if (id === 'reset') this.resetView();
      else if (id === 'random') this.randomView();
      else if (id === 'shot') this.screenshot();
      else if (id === 'fs') this.toggleFullscreen();
    }, { signal: this.ac.signal });

    dock.addEventListener('change', (e) => {
      if (e.target.dataset.q != null) { prefs.set('quality', e.target.value); this.reloadQuality(); }
    }, { signal: this.ac.signal });

    document.addEventListener('fullscreenchange', () => {
      const b = dock.querySelector('[data-b="fs"]');
      if (b) b.innerHTML = icon(document.fullscreenElement ? 'min' : 'max', 16);
    }, { signal: this.ac.signal });
  }

  syncDock(fovOnly = false) {
    if (!this.dock) return;
    const fr = this.dock.querySelector('[data-r="fov"]');
    if (fr) {
      fr.value = String(Math.round(this.fov));
      this.dock.querySelector('[data-rv="fov"]').textContent = `${Math.round(this.fov)}°`;
    }
    if (fovOnly) return;
    for (const key of ['autoRotate', 'guides', 'hotspots']) {
      const b = this.dock.querySelector(`[data-t="${key}"]`);
      if (b) { b.classList.toggle('on', !!prefs.get(key)); b.setAttribute('aria-pressed', String(!!prefs.get(key))); }
    }
  }

  /* ---------- frame loop ---------- */
  _frame(t) {
    if (this.destroyed) return;
    this._raf = requestAnimationFrame((tt) => this._frame(tt));
    const dt = Math.min(0.05, (t - (this._lastT || t)) / 1000);
    this._lastT = t;
    if (document.hidden) return;

    for (const tw of [...this.tweens]) {
      const k = clamp((t - tw.t0) / tw.dur, 0, 1);
      tw.fn(k);
      if (k >= 1) { this.tweens.splice(this.tweens.indexOf(tw), 1); tw.done?.(); }
    }

    const motionDriving = this.motion ? this.motion.update(dt) : false;
    if (!motionDriving) {
      if (!this.pointers.size && !this.hotspots.dragItem && !this.tweens.some((x) => x.tag === 'cam')) {
        this.yaw += this.vel.x * dt;
        this.pitch = clamp(this.pitch + this.vel.y * dt, -1.48, 1.48);
        const damp = Math.exp(-dt * 5.5);
        this.vel.x *= damp; this.vel.y *= damp;
      }
      const idle = t - this.lastInteract > 3500;
      if (prefs.get('autoRotate') && idle && !this.transitioning && !this.hotspots.placing && !this.editable && !reduceMotion) {
        this.yaw += rad(prefs.get('drift') * 0.12) * dt * (this.hero ? 2.2 : 1);
      }
      this.camera.lookAt(dirFromYawPitch(this.yaw, this.pitch));
    }

    this.camera.fov = this.fov;
    this.camera.updateProjectionMatrix();
    this.hotspots.update(t);

    if (t - this._ccT > 120) {
      this._ccT = t;
      this.opts.onCamera?.(this.getView());
    }

    const stereoRendered = this.vr ? this.vr.render() : false;
    if (!stereoRendered) this.renderer.render(this.three, this.camera);
  }

  destroy() {
    if (this.destroyed) return;
    this.destroyed = true;
    cancelAnimationFrame(this._raf);
    this.ac.abort();
    this.ro?.disconnect();
    if (this.motionUI) this.motionUI.destroy();
    if (this.motion) this.motion.destroy();
    if (this.vr) this.vr.destroy();
    this.hotspots.dispose();
    this._releasePins();
    this.tweens = [];
    this.geometry.dispose();
    this.matA.dispose();
    this.matB.dispose();
    this.guides.traverse((o) => {
      o.geometry?.dispose();
      if (o.material) { o.material.map?.dispose?.(); o.material.dispose(); }
    });
    this.renderer.dispose();
    try { this.renderer.forceContextLoss(); } catch { /* ignore */ }
    evict(3);
    this.mount.textContent = '';
  }
}
'@

# ============================================================================
# End of Block 5/6. 39 files written so far.
# Append Block 6 below this line in the SAME build-orbis360.ps1 file.
# ============================================================================# ============================================================================
# Block 6/6 - client pages, app.js, README.md, verification, and ZIP packaging
# ============================================================================

W 'client/assets/js/map.js' @'
import { api } from './api.js';
import { qs, qsa, el, esc, fmtCoord, destPoint, angDelta, prefs } from './utils.js';
import { icon, iconEl, modal, closeModal, toast, sound } from './ui.js';

const L = window.L;
const TILE = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const ATTR = '© OpenStreetMap contributors';

export function buildCompass(slot, viewer) {
  slot.innerHTML = `<button class="v-compass" type="button" title="Face north">
    <svg width="56" height="56" viewBox="0 0 56 56">
      <circle cx="28" cy="28" r="26" fill="rgba(9,15,30,.72)" stroke="rgba(148,180,255,.35)" stroke-width="1.5"/>
      <g class="rose">
        <path d="M28 7 L33 28 L28 24 L23 28 Z" fill="#ff5d73"/>
        <path d="M28 49 L33 28 L28 32 L23 28 Z" fill="#dfe9ff" opacity=".85"/>
        <text x="28" y="17" text-anchor="middle" font-size="8" font-weight="700" fill="#fff">N</text>
      </g>
      <circle cx="28" cy="28" r="2.4" fill="#3fd9ff"/>
    </svg><span class="hdg">N 000°</span></button>`;
  const rose = slot.querySelector('.rose');
  const hdg = slot.querySelector('.hdg');
  slot.querySelector('.v-compass').onclick = () => {
    if (viewer.motion && viewer.motion.active) viewer.motion.resetOrientation();
    else viewer.animateTo(0, viewer.getView().pitch, viewer.fov, 500);
    sound.play('blip');
  };
  return (v) => {
    const y = ((v.yaw % 360) + 360) % 360;
    rose.setAttribute('transform', `rotate(${-y} 28 28)`);
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    hdg.textContent = `${dirs[Math.round(y / 45) % 8]} ${String(Math.round(y)).padStart(3, '0')}°`;
  };
}

export function buildMinimap(slot, viewer, tour) {
  let map = null, cone = null, last = null;
  const wrap = el('div', { class: `v-minimap${prefs.get('minimap') ? '' : ' collapsed'}` });
  wrap.innerHTML = `<div class="mm-head">${icon('map', 12)} MAP <span class="sp"></span>
    <button class="icon-btn sm" data-mm="open" type="button" title="Open full map">${icon('external', 13)}</button>
    <button class="icon-btn sm" data-mm="toggle" type="button" title="Collapse (M)">${icon('chevD', 13)}</button></div>
    <div class="mm-body"></div>`;
  slot.appendChild(wrap);
  const body = wrap.querySelector('.mm-body');

  const rebuild = (scene) => {
    if (map) { map.remove(); map = null; cone = null; last = null; }
    if (!L || scene.lat == null || scene.lng == null) {
      body.innerHTML = `<div class="mm-none">${!L ? 'Map library unavailable' : 'No GPS — set a location in Studio'}</div>`;
      return;
    }
    body.innerHTML = '<div class="mm-map"></div>';
    map = L.map(body.firstElementChild, { zoomControl: false, attributionControl: false, scrollWheelZoom: false })
      .setView([scene.lat, scene.lng], 17);
    L.tileLayer(TILE, { maxZoom: 19 }).addTo(map);
    L.marker([scene.lat, scene.lng], {
      icon: L.divIcon({
        className: '', iconSize: [26, 26], iconAnchor: [13, 13],
        html: `<div class="sv-marker" style="--c:${tour.color}"><span class="pulse"></span><span class="dot"></span></div>`
      })
    }).addTo(map);
    for (const other of tour.scenes) {
      if (other.id === scene.id || other.lat == null) continue;
      L.marker([other.lat, other.lng], {
        icon: L.divIcon({
          className: '', iconSize: [18, 18], iconAnchor: [9, 9],
          html: '<div class="sv-marker" style="--c:#9aa7c4;width:18px;height:18px"><span class="dot" style="inset:3px"></span></div>'
        })
      }).addTo(map).on('click', () => viewer.opts.onJumpScene?.(other.id));
    }
    for (const h of scene.hotspots.filter((x) => x.type === 'nav')) {
      const t = tour.scenes.find((s) => s.id === h.targetScene);
      if (t?.lat != null) L.polyline([[scene.lat, scene.lng], [t.lat, t.lng]], { color: tour.color, weight: 2.5, opacity: 0.6 }).addTo(map);
    }
    cone = L.polygon([[scene.lat, scene.lng]], { color: '#3fd9ff', weight: 1, fillColor: '#3fd9ff', fillOpacity: 0.22 }).addTo(map);
    setTimeout(() => map?.invalidateSize(), 60);
  };

  const update = (v) => {
    if (!map || !cone || !viewer.scene || viewer.scene.lat == null) return;
    if (last && Math.abs(angDelta(last.yaw, v.yaw)) < 1 && Math.abs(last.fov - v.fov) < 1) return;
    last = { ...v };
    const s = viewer.scene;
    cone.setLatLngs([
      [s.lat, s.lng],
      destPoint(s.lat, s.lng, v.yaw - v.fov * 0.7, 45),
      destPoint(s.lat, s.lng, v.yaw + v.fov * 0.7, 45)
    ]);
  };

  const toggle = () => {
    prefs.set('minimap', !prefs.get('minimap'));
    wrap.classList.toggle('collapsed', !prefs.get('minimap'));
    setTimeout(() => map?.invalidateSize(), 80);
  };

  wrap.addEventListener('click', (e) => {
    const b = e.target.closest('[data-mm]');
    if (!b) return;
    if (b.dataset.mm === 'open') location.hash = `#/map?tour=${tour.id}`;
    else toggle();
  });

  return { rebuild, update, toggle, destroy: () => { map?.remove(); wrap.remove(); } };
}

export function pickLocation({ lat, lng }) {
  return new Promise((resolve) => {
    let map = null, marker = null;
    let cur = { lat: lat ?? null, lng: lng ?? null };
    const m = modal(`
      <div class="modal-head"><h3>Set panorama location</h3>
        <button class="icon-btn" data-close type="button">${icon('x')}</button></div>
      <div class="modal-body">
        <p class="muted" style="margin-bottom:12px">Click the map or drag the marker.</p>
        <div id="pick-map" style="height:340px;border-radius:12px;overflow:hidden;border:1px solid var(--line2);background:var(--bg2)"></div>
        <div class="mono" id="pick-coords" style="margin-top:10px;color:var(--cyan)">${fmtCoord(cur.lat, cur.lng)}</div>
      </div>
      <div class="modal-foot">
        <button class="btn btn-ghost" data-close type="button">Cancel</button>
        <button class="btn btn-primary" id="pick-ok" type="button">${icon('check', 16)} Set location</button>
      </div>`, {
      wide: true,
      onClose: () => { map?.remove(); resolve(null); }
    });

    if (L) {
      map = L.map(qs('#pick-map', m)).setView([lat ?? 37.7955, lng ?? -122.3937], lat != null ? 16 : 3);
      L.tileLayer(TILE, { maxZoom: 19, attribution: ATTR }).addTo(map);
      marker = L.marker([lat ?? 37.7955, lng ?? -122.3937], { draggable: true }).addTo(map);
      const set = (ll) => {
        cur = { lat: Number(ll.lat.toFixed(6)), lng: Number(ll.lng.toFixed(6)) };
        marker.setLatLng(ll);
        qs('#pick-coords', m).textContent = fmtCoord(cur.lat, cur.lng);
      };
      map.on('click', (e) => set(e.latlng));
      marker.on('dragend', () => set(marker.getLatLng()));
      setTimeout(() => map.invalidateSize(), 80);
    } else {
      qs('#pick-map', m).innerHTML = '<div class="map-fallback">Map library unavailable.</div>';
    }

    qs('#pick-ok', m).onclick = () => {
      if (cur.lat == null) return toast('Pick a point on the map first', 'warn');
      const value = { ...cur };
      map?.remove(); map = null;
      closeModal();
      resolve(value);
    };
  });
}

export async function PageMap(app, { params }) {
  const ac = new AbortController();
  let filter = params.tour || 'all';
  const edit = params.edit === '1';
  let selected = null;
  let map = null;

  const [{ tours }] = await Promise.all([api.tours.list(), api.assets.list().catch(() => ({ assets: [] }))]);
  const full = {};
  for (const t of tours) {
    if (filter !== 'all' && t.id !== filter) continue;
    full[t.id] = (await api.tours.get(t.id)).tour;
  }
  const allTours = filter === 'all' ? Object.values(full) : (full[filter] ? [full[filter]] : []);

  app.innerHTML = `<div class="page"><div class="map-page">
    <div class="map-canvas" id="mapc"></div>
    <div class="map-side">
      <div class="ms-head"><h2>${edit ? 'Placement mode' : 'Tour map'}</h2>
        <div class="filter-chips" id="m-filters">
          <button class="fchip${filter === 'all' ? ' on' : ''}" data-f="all" type="button">All tours</button>
          ${tours.map((t) => `<button class="fchip${filter === t.id ? ' on' : ''}" data-f="${t.id}" type="button">
            <span class="cdot" style="background:${t.color};display:inline-block"></span> ${esc(t.title.slice(0, 14))}</button>`).join('')}
        </div>
      </div>
      <div class="ms-list" id="m-list"></div>
    </div>
    ${edit ? `<div class="place-banner">${icon('crosshair', 15)}
      <span id="pb-text">Select a scene, then click the map to place it</span>
      <a class="btn btn-ghost btn-sm" href="#/admin?tour=${filter === 'all' ? (tours[0]?.id || '') : filter}">Done</a></div>` : ''}
  </div></div>`;

  if (!L) {
    qs('#mapc', app).innerHTML = '<div class="map-fallback"><div><h3 class="disp">Map library unavailable</h3></div></div>';
  } else {
    map = L.map(qs('#mapc', app), { worldCopyJump: true }).setView([37.796, -122.394], 14);
    L.tileLayer(TILE, { maxZoom: 19, attribution: ATTR }).addTo(map);
    setTimeout(() => map.invalidateSize(), 80);
    if (edit) {
      map.on('click', async (e) => {
        if (!selected) return toast('Select a scene in the list first', 'warn');
        try {
          await api.scenes.update(selected, { lat: Number(e.latlng.lat.toFixed(6)), lng: Number(e.latlng.lng.toFixed(6)) });
          const t = allTours.find((x) => x.scenes.some((s) => s.id === selected));
          if (t) { const s = t.scenes.find((x) => x.id === selected); s.lat = Number(e.latlng.lat.toFixed(6)); s.lng = Number(e.latlng.lng.toFixed(6)); }
          sound.play('pop'); toast('Location saved', 'success'); drawMarkers(); drawList();
        } catch (err) { toast(err.message, 'error'); }
      });
    }
  }

  const layer = map ? L.layerGroup().addTo(map) : null;

  function drawMarkers() {
    if (!map) return;
    layer.clearLayers();
    const scenes = allTours.flatMap((t) => t.scenes.map((s) => ({ s, t }))).filter(({ s }) => s.lat != null);
    const seen = new Set();
    for (const { s, t } of scenes) {
      for (const h of s.hotspots.filter((x) => x.type === 'nav')) {
        const o = t.scenes.find((x) => x.id === h.targetScene);
        if (!o || o.lat == null) continue;
        const k = [s.id, o.id].sort().join('|');
        if (seen.has(k)) continue;
        seen.add(k);
        L.polyline([[s.lat, s.lng], [o.lat, o.lng]], { color: t.color, weight: 3, opacity: 0.65 }).addTo(layer);
      }
      const mk = L.marker([s.lat, s.lng], {
        icon: L.divIcon({ className: '', iconSize: [26, 26], iconAnchor: [13, 13],
          html: `<div class="sv-marker" style="--c:${t.color}"><span class="pulse"></span><span class="dot"></span></div>` })
      }).addTo(layer);
      mk.bindPopup(`<div class="map-pop">
        <img src="${s.asset.thumbUrl}" alt="">
        <b>${esc(s.title)}</b>
        <div class="muted" style="font-size:11.5px;margin-bottom:8px">${esc(t.title)}</div>
        <a class="btn btn-primary btn-sm" href="#/tour/${t.id}?scene=${s.id}">${icon('play', 13)} Enter 360°</a>
        <a class="btn btn-ghost btn-sm" href="#/studio/${s.id}">${icon('sliders', 13)} Studio</a></div>`);
    }
    if (scenes.length) map.fitBounds(L.latLngBounds(scenes.map(({ s }) => [s.lat, s.lng])).pad(0.25), { maxZoom: 17 });
  }

  function drawList() {
    const list = qs('#m-list', app);
    list.innerHTML = allTours.map((t) => `<div>
      <div class="ms-tour-head"><span class="cdot" style="background:${t.color}"></span>${esc(t.title)}
        <span class="dim" style="margin-left:auto;font-size:11px">${t.scenes.length}</span></div>
      ${t.scenes.map((s) => `<button class="ms-scene${selected === s.id ? ' sel' : ''}" data-s="${s.id}" type="button">
        <img src="${s.asset.thumbUrl}" alt=""><span class="nm">${esc(s.title)}</span>
        ${s.lat == null ? '<span class="chip warn" style="padding:2px 7px;font-size:10px">no GPS</span>' : ''}</button>`).join('')}
    </div>`).join('') || '<p class="muted" style="padding:12px">No tours yet.</p>';

    qsa('[data-s]', list).forEach((b) => {
      b.onclick = () => {
        const id = b.dataset.s;
        const t = allTours.find((x) => x.scenes.some((s) => s.id === id));
        const s = t.scenes.find((x) => x.id === id);
        if (edit) { selected = id; qs('#pb-text', app).textContent = `Click the map to place “${s.title}”`; drawList(); if (s.lat != null && map) map.setView([s.lat, s.lng], 17); }
        else if (s.lat != null && map) map.setView([s.lat, s.lng], 17);
        else location.hash = `#/tour/${t.id}?scene=${s.id}`;
      };
    });
  }

  qs('#m-filters', app).addEventListener('click', (e) => {
    const b = e.target.closest('.fchip');
    if (!b) return;
    location.hash = b.dataset.f === 'all' ? '#/map' : `#/map?tour=${b.dataset.f}${edit ? '&edit=1' : ''}`;
  }, { signal: ac.signal });

  drawMarkers(); drawList();
  return { destroy() { ac.abort(); map?.remove(); } };
}
'@

W 'client/assets/js/tours.js' @'
import { api } from './api.js';
import { qs, qsa, el, esc, timeAgo, debounce } from './utils.js';
import { icon, toast, confirmBox, sound } from './ui.js';

export function tourCard(tour) {
  const card = el('article', { class: 'tour-card' });
  card.innerHTML = `
    <div class="tc-cover${tour.coverThumb ? '' : ' skel'}">
      ${tour.coverThumb ? `<img src="${tour.coverThumb}" alt="${esc(tour.title)} cover" loading="lazy">` : ''}
      <div class="shade"></div>
      <div class="tc-badges">
        ${tour.status === 'published' ? `<span class="chip ok">${icon('check', 12)} Public</span>` : '<span class="chip warn">Draft</span>'}
        ${tour.tags.includes('sample') ? '<span class="chip cy">Sample</span>' : ''}
      </div>
      <div class="tc-loc">${icon('pin', 13)} ${esc(tour.location || 'Unplaced')} · ${tour.sceneCount} scene${tour.sceneCount !== 1 ? 's' : ''}</div>
      <a class="btn btn-primary btn-sm tc-enter" href="#/tour/${tour.id}">${icon('play', 14)} Enter tour</a>
    </div>
    <div class="tc-body"><h3>${esc(tour.title)}</h3><p>${esc(tour.description || 'No description yet.')}</p></div>
    <div class="tc-foot">
      <span class="chip" style="border-color:${tour.color}55;color:${tour.color}">${tour.arrowCount} arrows</span>
      <span class="dim" style="font-size:11.5px">${timeAgo(tour.updatedAt)}</span>
      <span class="sp"></span>
      <a class="icon-btn sm" href="#/map?tour=${tour.id}" title="Map">${icon('map', 15)}</a>
      <a class="icon-btn sm" href="#/admin?tour=${tour.id}" title="Edit">${icon('sliders', 15)}</a>
      <button class="icon-btn sm" data-share type="button" title="Share">${icon('share', 15)}</button>
      <button class="icon-btn sm" data-del type="button" title="Delete">${icon('trash', 15)}</button>
    </div>`;

  qs('[data-share]', card).onclick = async () => {
    const url = `${location.origin}/#/tour/${tour.id}`;
    const { copyText } = await import('./utils.js');
    if (await copyText(url)) toast('Tour link copied', 'success');
  };
  qs('[data-del]', card).onclick = async () => {
    if (!await confirmBox('Delete tour?', `“${tour.title}” and its ${tour.sceneCount} scene(s) will be removed.`)) return;
    try { await api.tours.remove(tour.id); card.remove(); sound.play('blip'); toast('Tour deleted', 'success'); }
    catch (err) { toast(err.message, 'error'); }
  };
  return card;
}

export async function PageExplore(app) {
  const ac = new AbortController();
  let q = '', status = 'all', sort = 'updated';
  app.innerHTML = `<div class="page"><div class="wrap">
    <div class="page-head"><h1>Explore virtual tours</h1></div>
    <div class="search-bar">
      <div class="search-wrap">${icon('search', 16)}<input id="ex-q" placeholder="Search tours…"></div>
      <select id="ex-sort" style="width:auto">
        <option value="updated">Recently updated</option><option value="created">Newest first</option>
        <option value="title">Title A–Z</option><option value="scenes">Most scenes</option>
      </select>
    </div>
    <div class="filter-chips" style="margin-bottom:20px" id="ex-filters">
      <button class="fchip on" data-f="all" type="button">All</button>
      <button class="fchip" data-f="published" type="button">Published</button>
      <button class="fchip" data-f="draft" type="button">Drafts</button>
    </div>
    <div class="grid-tours" id="ex-grid"></div>
  </div></div>`;
  const grid = qs('#ex-grid', app);
  async function draw() {
    grid.innerHTML = '<div class="empty" style="grid-column:1/-1">Loading tours…</div>';
    try {
      const { tours } = await api.tours.list({ q, status, sort });
      grid.textContent = '';
      if (!tours.length) {
        grid.innerHTML = `<div class="empty" style="grid-column:1/-1"><h3>No tours found</h3>
          <a class="btn btn-primary" href="#/admin">Open Studio</a></div>`;
        return;
      }
      tours.forEach((t) => grid.appendChild(tourCard(t)));
    } catch (err) { grid.innerHTML = `<div class="empty" style="grid-column:1/-1"><h3>Could not load tours</h3></div>`; }
  }
  qs('#ex-q', app).addEventListener('input', debounce((e) => { q = e.target.value; draw(); }, 250), { signal: ac.signal });
  qs('#ex-sort', app).addEventListener('change', (e) => { sort = e.target.value; draw(); }, { signal: ac.signal });
  qs('#ex-filters', app).addEventListener('click', (e) => {
    const b = e.target.closest('.fchip'); if (!b) return;
    status = b.dataset.f; qsa('.fchip', app).forEach((x) => x.classList.toggle('on', x === b)); draw();
  }, { signal: ac.signal });
  await draw();
  return { destroy() { ac.abort(); } };
}
'@

W 'client/assets/js/tour.js' @'
import { api } from './api.js';
import { Viewer } from './viewer.js';
import { buildCompass, buildMinimap } from './map.js';
import { qs, qsa, el, esc, fmtCoord, prefs, copyText } from './utils.js';
import { icon, iconEl, toast, helpModal, sound } from './ui.js';

export async function PageTour(app, { parts, params }) {
  const ac = new AbortController();
  let tour;
  try { ({ tour } = await api.tours.get(parts[1])); }
  catch (err) {
    app.innerHTML = `<div class="page"><div class="wrap" style="padding-top:70px"><div class="empty">
      <h3>Tour not found</h3><a class="btn btn-primary" href="#/explore">Explore tours</a></div></div></div>`;
    return { destroy() {} };
  }
  if (!tour.scenes.length) {
    app.innerHTML = `<div class="page"><div class="wrap" style="padding-top:70px"><div class="empty">
      <h3>“${esc(tour.title)}” has no scenes yet</h3>
      <a class="btn btn-primary" href="#/upload?tour=${tour.id}">Add scenes</a></div></div></div>`;
    return { destroy() {} };
  }
  const start = tour.scenes.find((s) => s.id === params.scene) || tour.scenes.find((s) => s.id === tour.coverScene) || tour.scenes[0];

  app.innerHTML = `<div class="page"><div class="viewer-page" id="vpage">
    <div class="v-mount" id="vm"></div>
    <div class="v-top">
      <a class="icon-btn" href="#/explore" title="Back">${icon('back', 18)}</a>
      <div class="v-title"><div class="t-tour">${esc(tour.title)}</div><div class="t-scene" id="v-scene">${esc(start.title)}</div></div>
      <div class="v-actions">
        <span class="load-chip hidden" id="v-load"><span class="spin"></span><span id="v-load-t"></span></span>
        <span class="res-chip hidden" id="v-res"></span>
        <button class="icon-btn" id="v-info" type="button" title="Info (I)">${icon('info', 18)}</button>
        <button class="icon-btn" id="v-help" type="button" title="Help">${icon('help', 18)}</button>
        <button class="icon-btn" id="v-share" type="button" title="Share">${icon('share', 18)}</button>
        <a class="icon-btn" id="v-edit" href="#/studio/${start.id}" title="Studio">${icon('sliders', 18)}</a>
      </div>
    </div>
    <div class="v-hint hidden" id="v-hint">Drag to look around · Scroll to zoom · Click ground arrows to move · Tap Motion Mode on mobile</div>
    <div id="v-compass"></div><div id="v-mm"></div>
    <div class="v-bottom"><div class="strip" id="v-strip"></div><div id="v-dock"></div></div>
  </div></div>`;

  const sceneById = (id) => tour.scenes.find((s) => s.id === id);
  let compassUpdate = null, minimap = null, infoOpen = false, infoPanel = null;

  const viewer = new Viewer(qs('#vm', app), {
    fsTarget: qs('#vpage', app),
    sceneTitle: (id) => sceneById(id)?.title,
    onNavigate: (h) => { const t = sceneById(h.targetScene); if (t) viewer.goScene(t, { yaw: h.yaw, pitch: -2 }); },
    onJumpScene: (id) => { const s = sceneById(id); if (s) viewer.goScene(s); },
    onSceneChange: (s) => {
      qs('#v-scene', app).textContent = s.title;
      qs('#v-edit', app).href = `#/studio/${s.id}`;
      qsa('.strip-thumb', app).forEach((b) => b.classList.toggle('on', b.dataset.id === s.id));
      qs('.strip-thumb.on', app)?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' });
      minimap?.rebuild(s);
      if (infoOpen) renderInfo(s);
      try { history.replaceState(null, '', `#/tour/${tour.id}?scene=${s.id}`); } catch {}
    },
    onLoading: (on, msg) => { qs('#v-load', app).classList.toggle('hidden', !on); qs('#v-load-t', app).textContent = msg || ''; },
    onResolution: (w, h) => { const c = qs('#v-res', app); c.classList.remove('hidden'); c.textContent = `${w}×${h}`; },
    onCamera: (v) => { compassUpdate?.(v); minimap?.update(v); },
    onInfoToggle: () => toggleInfo(),
    onMinimapToggle: () => minimap?.toggle()
  });

  await viewer.init();
  compassUpdate = buildCompass(qs('#v-compass', app), viewer);
  minimap = buildMinimap(qs('#v-mm', app), viewer, tour);
  viewer.buildDock(qs('#v-dock', app));

  const strip = qs('#v-strip', app);
  strip.innerHTML = `<button class="strip-nav" id="st-prev" type="button">${icon('chevL', 16)}</button>
    <div class="strip-scroll" id="st-scroll"></div>
    <button class="strip-nav" id="st-next" type="button">${icon('chevR', 16)}</button>`;
  const scroller = qs('#st-scroll', app);
  tour.scenes.forEach((s, i) => {
    const b = el('button', { class: 'strip-thumb', type: 'button', dataset: { id: s.id } });
    b.innerHTML = `<span class="n">${i + 1}</span><img src="${s.asset.thumbUrl}" alt="${esc(s.title)}" loading="lazy">`;
    b.onclick = () => viewer.goScene(s);
    scroller.appendChild(b);
  });
  const step = (d) => { const i = tour.scenes.findIndex((s) => s.id === viewer.scene?.id); const n = tour.scenes[(i + d + tour.scenes.length) % tour.scenes.length]; if (n) viewer.goScene(n); };
  qs('#st-prev', app).onclick = () => step(-1);
  qs('#st-next', app).onclick = () => step(1);

  function renderInfo(s) {
    if (!infoPanel) return;
    const links = s.hotspots.filter((h) => h.type === 'nav');
    infoPanel.innerHTML = `<button class="icon-btn sm" id="ip-x" type="button" style="position:absolute;top:10px;right:10px">${icon('x', 14)}</button>
      <h3>${esc(s.title)}</h3><p class="desc">${esc(s.description || '')}</p>
      <div class="mono" style="color:var(--cyan);margin-bottom:12px">${icon('pin', 12)} ${fmtCoord(s.lat, s.lng)}</div>
      ${links.length ? `<h5>Connected locations</h5>${links.map((h) => {
        const t = sceneById(h.targetScene); return t ? `<button class="jump-row" data-go="${t.id}" type="button">${icon('nav', 14)} ${esc(t.title)}</button>` : '';
      }).join('')}` : ''}`;
    qs('#ip-x', infoPanel).onclick = toggleInfo;
    qsa('[data-go]', infoPanel).forEach((b) => { b.onclick = () => viewer.goScene(sceneById(b.dataset.go)); });
  }
  function toggleInfo() {
    infoOpen = !infoOpen;
    if (infoOpen) { infoPanel = el('div', { class: 'info-panel' }); qs('#vpage', app).appendChild(infoPanel); renderInfo(viewer.scene || start); }
    else { infoPanel?.remove(); infoPanel = null; }
  }

  qs('#v-info', app).onclick = toggleInfo;
  qs('#v-help', app).onclick = helpModal;
  qs('#v-share', app).onclick = async () => {
    const url = `${location.origin}/#/tour/${tour.id}?scene=${viewer.scene?.id || start.id}`;
    if (await copyText(url)) { toast('Scene link copied', 'success'); sound.play('blip'); }
  };

  if (!prefs.get('hintSeen')) {
    const hint = qs('#v-hint', app); hint.classList.remove('hidden');
    const hide = () => { hint.style.opacity = '0'; setTimeout(() => hint.remove(), 600); prefs.set('hintSeen', true); };
    setTimeout(hide, 7000); qs('#vm', app).addEventListener('pointerdown', hide, { once: true, signal: ac.signal });
  }

  await viewer.setScene(start, { useHeading: true });
  return { destroy() { ac.abort(); minimap?.destroy(); viewer.destroy(); } };
}
'@

W 'client/assets/js/upload.js' @'
import { api } from './api.js';
import { qs, qsa, el, esc, fmtBytes } from './utils.js';
import { icon, toast, sound } from './ui.js';

async function readDimensions(file) {
  try { const bmp = await createImageBitmap(file); const out = { width: bmp.width, height: bmp.height }; bmp.close?.(); return out; }
  catch { return new Promise((resolve) => { const url = URL.createObjectURL(file); const img = new Image(); img.onload = () => { resolve({ width: img.naturalWidth, height: img.naturalHeight }); URL.revokeObjectURL(url); }; img.onerror = () => { resolve(null); URL.revokeObjectURL(url); }; img.src = url; }); }
}

export async function PageUpload(app, { params }) {
  const ac = new AbortController();
  const { tours } = await api.tours.list();
  let target = params.tour || tours[0]?.id || '__new';
  const queue = []; let busy = false;

  app.innerHTML = `<div class="page"><div class="upload-page">
    <div class="page-head" style="padding:8px 0 0"><h1>Upload manager</h1></div>
    <div class="up-options">
      <div class="field"><label>Target tour</label>
        <select id="up-tour">
          ${tours.map((t) => `<option value="${t.id}"${t.id === target ? ' selected' : ''}>${esc(t.title)}</option>`).join('')}
          <option value="__new"${target === '__new' ? ' selected' : ''}>➕ Create new tour…</option>
        </select></div>
      <div class="field${target === '__new' ? '' : ' hidden'}" id="up-newwrap">
        <label>New tour name</label><input id="up-newname" value="My Tour"></div>
      <div class="field full" style="display:flex;gap:18px;flex-wrap:wrap;align-items:center">
        <label class="check" style="margin:0"><input type="checkbox" id="up-link" checked> Auto-link scenes with GPS</label>
        <label class="check" style="margin:0"><input type="checkbox" id="up-force"> Allow non-2:1 images</label>
      </div>
    </div>
    <div class="dropzone" id="dz">
      <div class="fi">${icon('upload', 36)}</div><h3>Drop Insta360 X4 panoramas here</h3>
      <p>JPG / PNG / WebP / TIFF · 2:1 equirectangular</p>
      <input type="file" id="up-file" class="hidden" multiple accept="image/jpeg,image/png,image/webp,image/tiff">
    </div>
    <div class="up-queue" id="up-queue"></div>
    <div class="up-foot">
      <button class="btn btn-primary" id="up-go" disabled type="button">${icon('check', 16)} Upload & create scenes</button>
    </div>
  </div></div>`;
  const body = qs('.upload-page', app);

  qs('#up-tour', body).onchange = (e) => { target = e.target.value; qs('#up-newwrap', body).classList.toggle('hidden', target !== '__new'); };
  const dz = qs('#dz', body), fi = qs('#up-file', body);
  dz.onclick = () => fi.click();
  dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('drag'); }, { signal: ac.signal });
  dz.addEventListener('dragleave', () => dz.classList.remove('drag'), { signal: ac.signal });
  dz.addEventListener('drop', (e) => { e.preventDefault(); dz.classList.remove('drag'); addFiles([...e.dataTransfer.files]); }, { signal: ac.signal });
  fi.onchange = () => { addFiles([...fi.files]); fi.value = ''; };
  qs('#up-go', body).onclick = run;

  async function addFiles(files) {
    for (const f of files) {
      if (queue.length >= 20) break;
      const item = { id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`, file: f, name: f.name.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' '), state: 'checking' };
      queue.push(item); drawQueue();
      const dim = await readDimensions(f);
      if (!dim) { item.state = 'err'; item.note = 'Not an image'; }
      else {
        item.width = dim.width; item.height = dim.height; item.ratio = dim.width / dim.height;
        if (Math.abs(item.ratio - 2) <= 0.02) { item.state = 'ok'; item.note = 'Valid 2:1'; }
        else if (Math.abs(item.ratio - 2) <= 0.12) { item.state = 'warn'; item.note = `Ratio ${item.ratio.toFixed(2)}:1`; }
        else { item.state = 'bad'; item.note = `Ratio ${item.ratio.toFixed(2)}:1 — not 360`; }
      }
      drawQueue();
    }
  }

  function drawQueue() {
    const q = qs('#up-queue', body); q.textContent = '';
    for (const it of queue) {
      const row = el('div', { class: `up-row ${it.state === 'warn' ? 'warn' : it.state === 'bad' || it.state === 'err' ? 'err' : it.state === 'done' ? 'done' : ''}` });
      row.innerHTML = `<div class="up-meta"><input value="${esc(it.name)}" data-name="${it.id}" ${it.state === 'done' ? 'disabled' : ''}>
        <div class="up-badges"><span class="chip">${fmtBytes(it.file.size)}</span>
        ${it.width ? `<span class="chip">${it.width}×${it.height}</span>` : ''}
        ${it.state === 'ok' ? '<span class="chip ok">2:1 ✓</span>' : it.state === 'warn' ? '<span class="chip warn">near 2:1</span>' : it.state === 'bad' ? '<span class="chip err">not 2:1</span>' : ''}
        ${it.state === 'done' ? '<span class="chip ok">imported</span>' : ''}</div>
        <div class="up-status">${esc(it.note || '')}</div>
        <div class="progress"><i style="width:${it.progress || 0}%"></i></div></div>
        ${it.state !== 'done' ? `<button class="icon-btn sm" data-rm="${it.id}" type="button">${icon('x', 15)}</button>` : ''}`;
      q.appendChild(row);
    }
    qsa('[data-name]', q).forEach((i) => { i.oninput = () => { const it = queue.find((x) => x.id === i.dataset.name); if (it) it.name = i.value; }; });
    qsa('[data-rm]', q).forEach((b) => { b.onclick = () => { queue.splice(queue.findIndex((x) => x.id === b.dataset.rm), 1); drawQueue(); }; });
    const btn = qs('#up-go', body);
    const ready = queue.filter((x) => x.state !== 'done' && x.state !== 'err').length;
    btn.disabled = busy || !ready;
    btn.innerHTML = busy ? '<span class="spin"></span> Uploading…' : `${icon('check', 16)} Upload ${ready} scene${ready !== 1 ? 's' : ''}`;
  }

  async function run() {
    if (busy) return;
    const items = queue.filter((x) => x.state !== 'done' && x.state !== 'err');
    if (!items.length) return;
    busy = true; drawQueue();
    let tourId = target;
    try {
      if (tourId === '__new') {
        const created = await api.tours.create({ title: qs('#up-newname', body)?.value.trim() || 'My Tour' });
        tourId = created.tour.id; tours.unshift(created.tour); target = tourId;
      }
      items.forEach((i) => { i.note = 'Uploading…'; i.progress = 5; }); drawQueue();
      const res = await api.assets.upload(items.map((i) => i.file), {
        force: qs('#up-force', body).checked,
        onProgress: (p) => { items.forEach((i) => { i.progress = Math.round(p * 70); }); drawQueue(); }
      });
      let created = 0;
      for (let i = 0; i < res.results.length; i++) {
        const r = res.results[i], it = items[i];
        if (!r.ok) { it.state = 'err'; it.note = r.error.message; it.progress = 100; drawQueue(); continue; }
        it.note = 'Creating scene…'; it.progress = 85; drawQueue();
        try { await api.scenes.create({ tourId, assetId: r.asset.id, title: it.name }); it.state = 'done'; it.progress = 100; it.note = 'Imported'; created++; sound.play('pop'); }
        catch (err) { it.state = 'err'; it.note = err.message; it.progress = 100; }
        drawQueue();
      }
      let linked = 0;
      if (created && qs('#up-link', body).checked) { try { linked = (await api.tours.autoLink(tourId, 200)).pairs; } catch {} }
      busy = false; drawQueue();
      if (created) { sound.play('chime'); toast(`${created} scene(s) created${linked ? ` · ${linked} linked` : ''}`, 'success'); }
    } catch (err) { busy = false; items.forEach((i) => { i.state = 'err'; i.note = err.message; }); drawQueue(); toast(err.message, 'error'); }
  }
  drawQueue();
  return { destroy() { ac.abort(); } };
}
'@

W 'client/assets/js/studio.js' @'
import { api } from './api.js';
import { Viewer } from './viewer.js';
import { pickLocation } from './map.js';
import { qs, qsa, el, esc, fmtDims, fmtCoord, debounce } from './utils.js';
import { icon, toast, modal, closeModal, confirmBox, sound } from './ui.js';

function hotspotForm(scene, hotspot, onSave, onDelete, targets = []) {
  const isNav = hotspot.type === 'nav';
  const others = targets.filter((t) => t.id !== scene.id);
  const m = modal(`
    <div class="modal-head"><h3>${isNav ? 'Navigation arrow' : 'Information point'}</h3><button class="icon-btn" data-close type="button">${icon('x')}</button></div>
    <div class="modal-body">
      <div class="field"><label>${isNav ? 'Arrow label' : 'Title'}</label><input id="hs-label" value="${esc(hotspot.label || '')}"></div>
      ${isNav ? (others.length
        ? `<div class="field"><label>Target scene</label><select id="hs-target"><option value="">— Select a scene —</option>${others.map((t) => `<option value="${esc(t.id)}"${t.id === hotspot.targetScene ? ' selected' : ''}>${esc(t.title)}</option>`).join('')}</select></div>`
        : `<p class="dim">Add at least one more scene to this tour first. An arrow needs a scene to point to.</p>`) : ''}
      ${isNav ? '' : `<div class="field"><label>Description</label><textarea id="hs-body">${esc(hotspot.body || '')}</textarea></div>`}
    </div>
    <div class="modal-foot">
      ${onDelete ? `<button class="btn btn-danger" id="hs-del" type="button">${icon('trash', 15)} Delete</button>` : ''}
      <span style="flex:1"></span>
      <button class="btn btn-ghost" data-close type="button">Cancel</button>
      <button class="btn btn-primary" id="hs-save" type="button">${icon('check', 16)} Save</button>
    </div>`);
  qs('#hs-save', m).onclick = () => {
    const payload = { type: hotspot.type, yaw: hotspot.yaw, pitch: hotspot.pitch, label: qs('#hs-label', m).value.trim() || (isNav ? 'Go' : 'Info') };
    if (!isNav) payload.body = qs('#hs-body', m).value.trim();
    if (isNav) {
      const target = qs('#hs-target', m)?.value;
      if (!target) { toast('Please choose a target scene for the arrow.', 'error'); return; }
      payload.targetScene = target;
    }
    closeModal(); onSave(payload);
  };
  if (onDelete) qs('#hs-del', m).onclick = () => { closeModal(); onDelete(); };
}

export async function PageStudio(app, { parts }) {
  const ac = new AbortController();
  let scene;
  try { ({ scene } = await api.scenes.get(parts[1])); }
  catch { app.innerHTML = `<div class="page"><div class="wrap" style="padding-top:70px"><div class="empty"><h3>Scene not found</h3></div></div></div>`; return { destroy() {} }; }
  const tourFull = (await api.tours.get(scene.tourId)).tour;

  app.innerHTML = `<div class="page"><div class="studio">
    <div class="studio-viewer" id="sv">
      <div class="v-mount" id="svm"></div>
      <div class="sv-top">
        <a class="icon-btn" href="#/admin?tour=${scene.tourId}" title="Back">${icon('back', 18)}</a>
        <span class="sv-name" id="sv-name">${esc(scene.title)}</span>
        <span class="saved-dot" id="sv-saved">${icon('check', 13)} Saved</span>
        <span style="flex:1"></span>
        <span class="load-chip hidden" id="sv-load"><span class="spin"></span><span id="sv-load-t"></span></span>
      </div>
      <div class="dock-wrap"><div id="sv-dock"></div></div>
    </div>
    <aside class="studio-panel" id="sp"></aside>
  </div></div>`;

  const pulse = () => { const e = qs('#sv-saved', app); e.classList.add('show'); clearTimeout(e._t); e._t = setTimeout(() => e.classList.remove('show'), 1600); };
  let placing = null;

  const viewer = new Viewer(qs('#svm', app), {
    editable: true, fsTarget: qs('#sv', app),
    onLoading: (on, msg) => { qs('#sv-load', app).classList.toggle('hidden', !on); qs('#sv-load-t', app).textContent = msg || ''; },
    onPlace: async (type, yaw, pitch) => {
      setPlacing(null);
      hotspotForm(scene, { type, yaw, pitch, label: '' }, async (payload) => {
        try { const { hotspot } = await api.hotspots.create({ sceneId: scene.id, ...payload }); scene.hotspots.push(hotspot); viewer.hotspots.setHotspots(scene.hotspots); renderHotspots(); pulse(); }
        catch (err) { toast(err.message, 'error'); }
      }, null, tourFull.scenes);
    },
    onEditHotspot: (h) => {
      hotspotForm(scene, h, async (payload) => {
        try { const { hotspot } = await api.hotspots.update(h.id, payload); Object.assign(h, hotspot); viewer.hotspots.setHotspots(scene.hotspots); renderHotspots(); pulse(); }
        catch (err) { toast(err.message, 'error'); }
      }, async () => {
        try { await api.hotspots.remove(h.id); scene.hotspots = scene.hotspots.filter((x) => x.id !== h.id); viewer.hotspots.setHotspots(scene.hotspots); renderHotspots(); pulse(); }
        catch (err) { toast(err.message, 'error'); }
      }, tourFull.scenes);
    },
    onMovedHotspot: async (h) => { try { await api.hotspots.update(h.id, { yaw: Number(h.yaw.toFixed(1)), pitch: Number(h.pitch.toFixed(1)) }); renderHotspots(); pulse(); } catch {} }
  });

  await viewer.init();
  viewer.buildDock(qs('#sv-dock', app));

  function setPlacing(type) { placing = type; viewer.hotspots.setPlacing(type); qsa('[data-place]', app).forEach((b) => b.classList.toggle('on', b.dataset.place === type)); }

  function renderHotspots() {
    const box = qs('#sp-hs', app); if (!box) return;
    box.innerHTML = scene.hotspots.map((h) => `<div class="hs-row ${h.type}">
      <span class="hi">${icon(h.type === 'nav' ? 'nav' : 'info', 16)}</span>
      <div class="hb"><b>${esc(h.label)}</b><span>${Math.round(h.yaw)}°</span></div>
      <button class="icon-btn sm" data-hs="edit" data-id="${h.id}" type="button">${icon('edit', 14)}</button>
      <button class="icon-btn sm" data-hs="del" data-id="${h.id}" type="button">${icon('trash', 14)}</button>
    </div>`).join('') || '<p class="dim">No hotspots yet.</p>';
    qsa('[data-hs]', box).forEach((b) => {
      b.onclick = async () => {
        const h = scene.hotspots.find((x) => x.id === b.dataset.id); if (!h) return;
        if (b.dataset.hs === 'edit') viewer.opts.onEditHotspot(h);
        else { try { await api.hotspots.remove(h.id); scene.hotspots = scene.hotspots.filter((x) => x.id !== h.id); viewer.hotspots.setHotspots(scene.hotspots); renderHotspots(); pulse(); } catch {} }
      };
    });
  }

  function renderPanel() {
    qs('#sp', app).innerHTML = `
      <div class="panel-sec"><h4>${icon('image', 14)} Details</h4>
        <div class="field"><label>Title</label><input id="sp-title" value="${esc(scene.title)}"></div>
        <div class="field"><label>Description</label><textarea id="sp-desc">${esc(scene.description || '')}</textarea></div></div>
      <div class="panel-sec"><h4>${icon('pin', 14)} Location</h4>
        <div class="btn-row"><button class="btn btn-ghost btn-sm" id="sp-pick" type="button">${icon('map', 14)} Pick on map</button></div>
        <div class="mono dim" style="margin-top:8px">${fmtCoord(scene.lat, scene.lng)}</div></div>
      <div class="panel-sec"><h4>${icon('nav', 14)} Hotspots</h4>
        <div class="btn-row"><button class="btn btn-ghost btn-sm" data-place="nav" type="button">${icon('nav', 14)} Add arrow</button>
        <button class="btn btn-ghost btn-sm" data-place="info" type="button">${icon('info', 14)} Add info</button></div>
        <div id="sp-hs" style="margin-top:12px"></div></div>`;
    renderHotspots();
    const save = debounce(async (patch) => { try { await api.scenes.update(scene.id, patch); Object.assign(scene, patch); pulse(); } catch {} }, 500);
    qs('#sp-title', app).oninput = (e) => { scene.title = e.target.value; qs('#sv-name', app).textContent = e.target.value; save({ title: e.target.value }); };
    qs('#sp-desc', app).oninput = (e) => save({ description: e.target.value });
    qs('#sp-pick', app).onclick = async () => {
      const v = await pickLocation({ lat: scene.lat, lng: scene.lng }); if (!v) return;
      try { await api.scenes.update(scene.id, v); Object.assign(scene, v); renderPanel(); pulse(); } catch {}
    };
    qsa('[data-place]', app).forEach((b) => { b.onclick = () => setPlacing(placing === b.dataset.place ? null : b.dataset.place); });
  }

  renderPanel();
  await viewer.setScene(scene, { useHeading: true });
  return { destroy() { ac.abort(); viewer.destroy(); } };
}
'@

W 'client/assets/js/admin.js' @'
import { api } from './api.js';
import { qs, qsa, el, esc, fmtDims, fmtCoord, timeAgo, debounce } from './utils.js';
import { icon, toast, modal, closeModal, confirmBox, sound } from './ui.js';

export async function PageAdmin(app, { params }) {
  const ac = new AbortController();
  let tourId = params.tour || null;
  async function draw() {
    const { tours } = await api.tours.list();
    if (!tourId || !tours.some((t) => t.id === tourId)) tourId = tours[0]?.id || null;
    const tour = tourId ? (await api.tours.get(tourId)).tour : null;
    app.innerHTML = `<div class="page"><div class="admin">
      <aside class="admin-side">
        <h4>Tours</h4>
        <div id="a-list">${tours.map((t) => `<button class="tour-item${t.id === tourId ? ' on' : ''}" data-t="${t.id}" type="button">
          <span class="ti-b"><b>${esc(t.title)}</b><span>${t.sceneCount} scenes</span></span></button>`).join('')}</div>
        <a class="btn btn-ghost btn-sm" href="#/upload" style="margin-top:8px">${icon('upload', 15)} Upload</a>
      </aside>
      <main class="admin-main" id="a-main"></main>
    </div></div>`;
    qsa('[data-t]', app).forEach((b) => { b.onclick = () => { tourId = b.dataset.t; history.replaceState(null, '', `#/admin?tour=${tourId}`); draw(); }; });
    const main = qs('#a-main', app);
    if (!tour) { main.innerHTML = `<div class="empty"><h3>No tours yet</h3></div>`; return; }
    main.innerHTML = `<div class="tour-head"><div class="th-b"><h1>${esc(tour.title)}</h1>
      <div class="stat-chips"><span class="chip cy">${tour.scenes.length} scenes</span></div></div></div>
      <div class="tour-actions">
        <a class="btn btn-primary btn-sm" href="#/tour/${tour.id}">${icon('eye', 15)} Preview</a>
        <a class="btn btn-ghost btn-sm" href="#/upload?tour=${tour.id}">${icon('upload', 15)} Add scenes</a>
      </div>
      <div class="scene-rows" id="a-rows"></div>`;
    const rows = qs('#a-rows', main);
    tour.scenes.forEach((s, i) => {
      const row = el('div', { class: 'scene-row' });
      row.innerHTML = `<img src="${s.asset.thumbUrl}" alt="">
        <div class="row-meta"><span class="nm">${i + 1}. ${esc(s.title)}</span>
        <div class="sub"><span class="dim mono">${fmtDims(s.asset.width, s.asset.height)}</span></div></div>
        <div class="row-actions"><a class="icon-btn sm" href="#/studio/${s.id}">${icon('sliders', 15)}</a></div>`;
      rows.appendChild(row);
    });
  }
  await draw();
  return { destroy() { ac.abort(); } };
}
'@

W 'client/assets/js/app.js' @'
import * as THREE from 'three';
window.THREE = THREE; // Expose for the classic UMD orbis360-motion-vr.js script

import { api } from './api.js';
import { qs, qsa, el, esc, prefs, fmtBytes } from './utils.js';
import { icon, iconEl, sound, toast } from './ui.js';
import { register, startRouter } from './router.js';
import { Viewer } from './viewer.js';
import { PageExplore, tourCard } from './tours.js';
import { PageTour } from './tour.js';
import { PageAdmin } from './admin.js';
import { PageStudio } from './studio.js';
import { PageMap } from './map.js';
import { PageUpload } from './upload.js';

function applyTheme() {
  document.documentElement.dataset.theme = prefs.get('theme');
  qs('meta[name=theme-color]').content = prefs.get('theme') === 'dark' ? '#070b14' : '#f2f5fb';
}

function buildNav() {
  const nav = qs('#nav');
  nav.innerHTML = `<div class="nav-inner">
    <a class="brand" href="#/"><img src="/assets/icons/logo.svg" alt="">Orbis<span class="grad-text">360</span></a>
    <div class="nav-links" id="nl">
      <a class="nav-link" href="#/" data-route="home">Home</a>
      <a class="nav-link" href="#/explore" data-route="explore">Explore</a>
      <a class="nav-link" href="#/map" data-route="map">Map</a>
      <a class="nav-link" href="#/admin" data-route="admin">Studio</a>
      <a class="nav-link" href="#/upload" data-route="upload">Upload</a>
    </div>
    <div class="nav-right">
      <button class="icon-btn" id="nav-theme" type="button" title="Theme"></button>
      <button class="icon-btn nav-burger" id="nav-burger" type="button">${icon('menu', 20)}</button>
    </div></div>`;
  const syncIcons = () => { qs('#nav-theme').innerHTML = icon(prefs.get('theme') === 'dark' ? 'sun' : 'moon', 18); };
  syncIcons();
  qs('#nav-burger').onclick = () => nav.classList.toggle('open');
  qs('#nl').addEventListener('click', () => nav.classList.remove('open'));
  qs('#nav-theme').onclick = () => { prefs.set('theme', prefs.get('theme') === 'dark' ? 'light' : 'dark'); applyTheme(); syncIcons(); };
}

async function PageHome(app) {
  const ac = new AbortController();
  let viewer = null;
  let stats = { tours: 0, scenes: 0, bytes: 0 };
  let tours = [];
  try { const [s, t] = await Promise.all([api.stats(), api.tours.list()]); stats = s; tours = t.tours; } catch {}
  const featured = tours.find((t) => t.sceneCount);
  let heroScene = null;
  if (featured) { try { heroScene = (await api.tours.get(featured.id)).tour.scenes[0]; } catch {} }

  app.innerHTML = `<div class="page" style="padding-top:0">
    <section class="hero">
      <div class="hero-bg" id="hero-bg">${heroScene ? '' : '<div class="hero-fallback"></div>'}</div>
      <div class="hero-scrim"></div>
      <div class="hero-content"><div class="hero-inner">
        <span class="eyebrow">${icon('camera', 14)} INSTA360 X4 · MOTION · VR</span>
        <h1>Step inside the <em>photo.</em></h1>
        <p class="sub">A local 360° tour studio. True spherical projection, real smartphone gyroscope control and stereoscopic VR.</p>
        <div class="hero-ctas">
          <a class="btn btn-primary" href="#/explore">${icon('compass', 17)} Explore tours</a>
          <a class="btn btn-ghost" href="#/upload">${icon('upload', 17)} Upload X4 photos</a>
        </div>
        <div class="hero-stats">
          <div class="stat"><b>${stats.tours}</b><span>Tours</span></div>
          <div class="stat"><b>${stats.scenes}</b><span>Scenes</span></div>
          <div class="stat"><b>${fmtBytes(stats.bytes)}</b><span>Stored</span></div>
        </div>
      </div></div>
    </section>
    <footer class="footer"><div class="wrap"><div class="footer-grid">
      <div><div class="brand"><img src="/assets/icons/logo.svg" alt="">Orbis<span class="grad-text">360</span></div>
        <small>Local-first virtual tour studio. Everything runs on your computer.</small></div>
    </div></div></footer>
  </div>`;

  if (heroScene) {
    viewer = new Viewer(qs('#hero-bg', app), { hero: true });
    await viewer.init();
    await viewer.setScene(heroScene, { useHeading: true });
  }
  return { destroy() { ac.abort(); viewer?.destroy(); } };
}

async function boot() {
  applyTheme();
  buildNav();
  const bar = qs('#boot-bar');
  const status = qs('#boot-status');
  bar.style.width = '35%';
  try {
    await api.health();
    bar.style.width = '75%';
    status.textContent = 'Connected';
  } catch (err) {
    bar.style.width = '100%';
    status.textContent = 'Server not reachable';
    qs('#app').innerHTML = `<div class="page"><div class="wrap" style="padding-top:80px"><div class="empty"><h3>Server not running</h3>
      <p>Run <span class="mono">npm start</span></p></div></div></div>`;
    qs('#boot').classList.add('hide');
    return;
  }
  register('home', PageHome);
  register('explore', PageExplore);
  register('tour', PageTour);
  register('map', PageMap);
  register('admin', PageAdmin);
  register('studio', PageStudio);
  register('upload', PageUpload);
  register('404', async (app) => { app.innerHTML = `<div class="page"><div class="wrap" style="padding-top:80px"><div class="empty"><h3>Page not found</h3></div></div></div>`; return { destroy() {} }; });
  await startRouter();
  bar.style.width = '100%';
  setTimeout(() => qs('#boot').classList.add('hide'), 200);
}

boot();
'@

W 'README.md' @'
# Orbis360 — Local 360° Virtual Tour Platform

A professional 360° tour platform for Insta360 X4 panoramas. Runs entirely on your own Windows PC.

## Install and run

1. Install Node.js LTS (18+) from https://nodejs.org/
2. Double-click `start.bat` (or run `npm install`, then `npm start`).
3. Open http://localhost:3000

## Commands

- `npm start` — Start the server
- `npm run seed` — Create sample tours
- `npm run doctor` — Verify environment
- `npm run check` — Syntax check JS files

## Features

- Equirectangular spherical projection (Three.js)
- Motion Mode (real DeviceOrientation gyroscope)
- Stereoscopic VR (Cardboard-style)
- Leaflet map integration
- Local SQLite database (sql.js WASM)
'@

# ============================================================================
# VERIFICATION
# ============================================================================
Write-Host "`nVerifying 47 project files..." -ForegroundColor Cyan
$expected = @(
  'package.json', '.env.example', '.gitignore', 'start.bat',
  'server/app.js', 'server/config.js',
  'server/database/db.js', 'server/database/schema.sql',
  'server/services/image.service.js', 'server/services/xmp.service.js',
  'server/services/geo.service.js', 'server/services/storage.service.js',
  'server/middleware/error.js', 'server/middleware/upload.js', 'server/middleware/validate.js',
  'server/controllers/tours.controller.js', 'server/controllers/scenes.controller.js',
  'server/controllers/hotspots.controller.js', 'server/controllers/assets.controller.js',
  'server/routes/index.js', 'server/routes/tours.routes.js', 'server/routes/scenes.routes.js',
  'server/routes/hotspots.routes.js', 'server/routes/assets.routes.js',
  'client/index.html', 'client/assets/css/main.css', 'client/assets/icons/logo.svg',
  'scripts/doctor.js', 'scripts/check.js', 'scripts/reset.js',
  'scripts/seed.js', 'scripts/panorama-generator.js',
  'client/assets/js/utils.js', 'client/assets/js/api.js', 'client/assets/js/ui.js',
  'client/assets/js/router.js', 'client/assets/js/viewer.js', 'client/assets/js/hotspots.js',
  'client/assets/js/orbis360-motion-vr.js',
  'client/assets/js/map.js', 'client/assets/js/tours.js', 'client/assets/js/tour.js',
  'client/assets/js/upload.js', 'client/assets/js/studio.js', 'client/assets/js/admin.js',
  'client/assets/js/app.js',
  'README.md'
)

$missing = @()
$empty = @()
foreach ($f in $expected) {
  $p = Join-Path $root $f
  if (!(Test-Path $p)) { $missing += $f }
  elseif ((Get-Item $p).Length -eq 0) { $empty += $f }
}

if ($missing.Count -gt 0 -or $empty.Count -gt 0) {
  Write-Host "`n[ERROR] Verification failed." -ForegroundColor Red
  if ($missing.Count -gt 0) { Write-Host "Missing files:"; $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red } }
  if ($empty.Count -gt 0) { Write-Host "Empty files (truncated here-strings):"; $empty | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red } }
  Write-Host "`nPlease check that all 6 blocks were appended correctly to build-orbis360.ps1."
  exit 1
}
Write-Host "  All 47 files verified successfully." -ForegroundColor Green

# ============================================================================
# ZIP GENERATION (Strict exclusions via staging folder)
# ============================================================================
Write-Host "`nPackaging Orbis360.zip..." -ForegroundColor Cyan
$zipPath = Join-Path (Get-Location) 'Orbis360.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$stage = Join-Path (Get-Location) 'Orbis360_stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

foreach ($f in $expected) {
  $src = Join-Path $root $f
  $dst = Join-Path $stage $f
  $dstDir = Split-Path $dst -Parent
  if (!(Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
  Copy-Item $src $dst
}

Compress-Archive -Path "$stage\*" -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " SUCCESS! Orbis360 project built and packaged." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Folder : $root"
Write-Host " Archive: $zipPath"
Write-Host "`n Next steps to run the app:"
Write-Host "   1. cd Orbis360"
Write-Host "   2. npm install"
Write-Host "   3. npm run seed   (optional: creates sample tours)"
Write-Host "   4. npm start"
Write-Host "   5. Open http://localhost:3000"
Write-Host "============================================================`n" -ForegroundColor Green