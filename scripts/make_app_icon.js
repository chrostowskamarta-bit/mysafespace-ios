// Renders the MySafeSpace app icon (the original "Drop" mood character) to a 1024×1024 PNG.
// No dependencies: rasterises the same blob maths as MoodShapes.swift with 4×4 supersampling.
// Usage: node scripts/make_app_icon.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const SIZE = 1024;
const SS = 4; // supersampling per axis
const out = path.join(__dirname, "..", "MySafeSpace", "Resources", "Assets.xcassets", "AppIcon.appiconset");

const hex = (h) => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
const BG_TOP = hex("8B6FFA"), BG_BOTTOM = hex("5B3FD9");
const BODY = hex("D4F55A"), INK = hex("1E1636"), CHEEK = [255, 255, 255];

// Blob outline (progress 0.9 = bright, lifted cloud), same formula as MoodBodyShape.
const progress = 0.9;
const cx = SIZE / 2, cy = SIZE / 2 + 20, radius = SIZE * 0.36;
const sag = (1 - progress) * 0.16, lobes = 0.02 + progress * 0.05;
const poly = [];
for (let i = 0; i < 360; i++) {
  const t = (i / 360) * 2 * Math.PI;
  const wobble = 1 + lobes * Math.cos(5 * t - Math.PI / 2);
  const settle = 1 + sag * Math.max(0, Math.sin(t)) * 0.9 - sag * Math.max(0, -Math.sin(t)) * 0.5;
  const r = wobble * settle;
  poly.push([cx + Math.cos(t) * r * (1 + sag * 0.25) * radius, cy + Math.sin(t) * r * radius + sag * radius * 0.35]);
}
const inPoly = (x, y) => {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
};
const inEllipse = (x, y, ex, ey, rx, ry) => ((x - ex) / rx) ** 2 + ((y - ey) / ry) ** 2 <= 1;
// Smile: quadratic curve stroke.
const face = { size: radius * 2 / 0.8, cy: cy + (1 - progress) * 0.09 * (radius * 2 / 0.8) };
const s = face.size;
const eyeY = face.cy - s * 0.06, spacing = s * 0.15;
const mouthY = face.cy + s * 0.1, mouthW = s * (0.13 + progress * 0.1), curve = (progress - 0.42) * s * 0.2;
const stroke = s * 0.045;
const mouthPts = [];
for (let i = 0; i <= 200; i++) {
  const t = i / 200;
  const x0 = cx - mouthW / 2, x2 = cx + mouthW / 2;
  const x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t ** 2 * x2;
  const y = (1 - t) ** 2 * mouthY + 2 * (1 - t) * t * (mouthY + curve) + t ** 2 * mouthY;
  mouthPts.push([x, y]);
}
const nearMouth = (x, y) => mouthPts.some(([mx, my]) => (x - mx) ** 2 + (y - my) ** 2 <= (stroke / 2) ** 2);

const colourAt = (x, y) => {
  const k = y / SIZE;
  let c = BG_TOP.map((v, i) => v + (BG_BOTTOM[i] - v) * k);
  if (inPoly(x, y)) {
    c = BODY;
    const eyeW = s * 0.075 / 2, eyeH = s * (0.045 + progress * 0.055) / 2;
    if (inEllipse(x, y, cx - spacing, eyeY, eyeW, eyeH) || inEllipse(x, y, cx + spacing, eyeY, eyeW, eyeH)) return INK;
    const cheekA = Math.max(0, progress - 0.55) * 1.1;
    const cheekX = spacing * 1.45, cheekY = mouthY - s * 0.035 + s * 0.0225;
    if (inEllipse(x, y, cx - cheekX, cheekY, s * 0.04, s * 0.0225) || inEllipse(x, y, cx + cheekX, cheekY, s * 0.04, s * 0.0225)) {
      c = c.map((v, i) => v + (CHEEK[i] - v) * cheekA);
    }
    if (Math.abs(y - mouthY - curve / 2) < Math.abs(curve) + stroke && Math.abs(x - cx) < mouthW / 2 + stroke && nearMouth(x, y)) return INK;
  }
  return c;
};

const raw = Buffer.alloc((SIZE * 3 + 1) * SIZE);
for (let y = 0; y < SIZE; y++) {
  raw[y * (SIZE * 3 + 1)] = 0;
  for (let x = 0; x < SIZE; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const c = colourAt(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS);
      r += c[0]; g += c[1]; b += c[2];
    }
    const n = SS * SS, o = y * (SIZE * 3 + 1) + 1 + x * 3;
    raw[o] = Math.round(r / n); raw[o + 1] = Math.round(g / n); raw[o + 2] = Math.round(b / n);
  }
}

const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc32 = (buf) => { let c = 0xffffffff; for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0); ihdr.writeUInt32BE(SIZE, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0)),
]);

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, "AppIcon.png"), png);
fs.writeFileSync(path.join(out, "Contents.json"), JSON.stringify({
  images: [{ filename: "AppIcon.png", idiom: "universal", platform: "ios", size: "1024x1024" }],
  info: { author: "xcode", version: 1 },
}, null, 2));
console.log("Wrote", path.join(out, "AppIcon.png"));
