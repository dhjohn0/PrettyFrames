const fs = require("fs");
const path = require("path");

const addonRoot = path.resolve(__dirname, "..");
const themeNames = process.argv.slice(2).length ? process.argv.slice(2) : ["Verdant", "Moonlight", "Orgrimmar"];
const outputPath = path.join(addonRoot, "Themes", "THEME_GEOMETRY_REFERENCE.md");

function tokenize(source) {
  const tokens = [];
  let i = 0;
  while (i < source.length) {
    if (/\s/.test(source[i])) { i++; continue; }
    if (source.startsWith("--", i)) {
      const end = source.indexOf("\n", i + 2);
      i = end < 0 ? source.length : end + 1;
      continue;
    }
    const ch = source[i];
    if (ch === '"' || ch === "'") {
      const quote = ch;
      let value = "";
      i++;
      while (i < source.length && source[i] !== quote) {
        if (source[i] === "\\" && i + 1 < source.length) {
          const next = source[i + 1];
          const escapes = { n: "\n", r: "\r", t: "\t", "\\": "\\", '"': '"', "'": "'" };
          value += Object.prototype.hasOwnProperty.call(escapes, next) ? escapes[next] : next;
          i += 2;
        } else {
          value += source[i++];
        }
      }
      if (source[i] !== quote) throw new Error("Unterminated Lua string");
      i++;
      tokens.push({ type: "string", value });
      continue;
    }
    const number = source.slice(i).match(/^(?:\d+\.\d*|\.\d+|\d+)/);
    if (number) {
      tokens.push({ type: "number", value: Number(number[0]) });
      i += number[0].length;
      continue;
    }
    const identifier = source.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (identifier) {
      tokens.push({ type: "identifier", value: identifier[0] });
      i += identifier[0].length;
      continue;
    }
    if ("{}()[]=,/:.-".includes(ch)) {
      tokens.push({ type: ch, value: ch });
      i++;
      continue;
    }
    throw new Error(`Unsupported Lua character ${JSON.stringify(ch)} at ${i}`);
  }
  return tokens;
}

function parseThemeLua(source) {
  const tokens = tokenize(source);
  let index = 0;
  const peek = (offset = 0) => tokens[index + offset];
  const take = type => {
    const token = tokens[index++];
    if (!token || token.type !== type) throw new Error(`Expected ${type}, got ${token ? token.type : "EOF"}`);
    return token;
  };
  function expression() {
    let value;
    if (peek()?.type === "-") {
      take("-");
      value = -expression();
    } else if (peek()?.type === "number") {
      value = take("number").value;
    } else if (peek()?.type === "string") {
      value = take("string").value;
    } else if (peek()?.type === "identifier") {
      const word = take("identifier").value;
      if (word === "true") value = true;
      else if (word === "false") value = false;
      else if (word === "nil") value = null;
      else throw new Error(`Unsupported Lua identifier expression ${word}`);
    } else if (peek()?.type === "{") {
      value = table();
    } else {
      throw new Error(`Unsupported Lua expression near ${JSON.stringify(peek())}`);
    }
    while (peek()?.type === "/") {
      take("/");
      value /= expression();
    }
    return value;
  }

  function table() {
    take("{");
    const object = {};
    const array = [];
    let hasNamed = false;
    while (peek() && peek().type !== "}") {
      if ((peek().type === "identifier" || peek().type === "string") && peek(1)?.type === "=") {
        const key = tokens[index++].value;
        take("=");
        object[key] = expression();
        hasNamed = true;
      } else {
        array.push(expression());
      }
      if (peek()?.type === ",") take(",");
    }
    take("}");
    if (hasNamed && array.length) object.__array = array;
    return hasNamed ? object : array;
  }

  function merge(target, source) {
    // Lua's empty table is ambiguous. In a theme fragment it means "no
    // additional fields", so it must not erase data gathered earlier.
    if (Array.isArray(source)) {
      return source.length ? source.map(value => structuredClone(value)) : (target || {});
    }
    if (!source || typeof source !== "object") return source;
    if (!target || typeof target !== "object" || Array.isArray(target)) target = {};
    for (const [key, value] of Object.entries(source)) {
      target[key] = value && typeof value === "object" && !Array.isArray(value)
        ? merge(target[key], value)
        : structuredClone(value);
    }
    return target;
  }

  let id;
  let data = {};
  let registered = false;
  while (index < tokens.length) {
    const token = tokens[index];
    const isThemeCall = token.type === "identifier"
      && (token.value === "ExtendTheme" || token.value === "RegisterTheme")
      && tokens[index + 1]?.type === "(";
    if (!isThemeCall) { index++; continue; }

    const call = token.value;
    index++;
    take("(");
    const callId = take("string").value;
    take(",");
    const fragment = expression();
    if (id && id !== callId) throw new Error(`Mixed theme IDs: ${id} and ${callId}`);
    id = callId;
    data = merge(data, fragment);
    registered ||= call === "RegisterTheme";
    if (peek()?.type === ")") take(")");
  }

  if (!registered) throw new Error("PF:RegisterTheme was not found");
  data.layout ||= {};
  for (const [name, preset] of Object.entries(data.globals?.layout || {})) {
    data.layout[name] ??= structuredClone(preset);
  }
  return { id, data };
}

function readTga(file) {
  const bytes = fs.readFileSync(file);
  const idLength = bytes[0];
  const imageType = bytes[2];
  const width = bytes.readUInt16LE(12);
  const height = bytes.readUInt16LE(14);
  const bits = bytes[16];
  if (imageType !== 2 || bits !== 32) throw new Error(`${file} is not uncompressed 32-bit TGA`);
  const offset = 18 + idLength;
  const alpha = new Uint8Array(width * height);
  const topOrigin = (bytes[17] & 0x20) !== 0;
  let visible = 0;
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let storedY = 0; storedY < height; storedY++) {
    const y = topOrigin ? storedY : height - 1 - storedY;
    for (let x = 0; x < width; x++) {
      const a = bytes[offset + (storedY * width + x) * 4 + 3];
      alpha[y * width + x] = a;
      if (a > 8) {
        visible++;
        minX = Math.min(minX, x); minY = Math.min(minY, y);
        maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
      }
    }
  }
  return {
    file, width, height, alpha,
    visiblePercent: visible * 100 / (width * height),
    bounds: maxX < 0 ? null : { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 }
  };
}

function get(object, dotted) {
  return dotted.split(".").reduce((value, key) => value?.[key], object);
}

function fmt(value, digits = 2) {
  if (value === undefined) return "—";
  if (typeof value === "number") return Number.isInteger(value) ? String(value) : value.toFixed(digits).replace(/0+$/, "").replace(/\.$/, "");
  if (Array.isArray(value)) return `{ ${value.map(v => fmt(v, digits)).join(", ")} }`;
  if (typeof value === "boolean") return value ? "true" : "false";
  if (value === null) return "nil";
  return String(value).replace(/\|/g, "\\|");
}

function rectText(rect) {
  return rect ? `x ${fmt(rect.x)}, y ${fmt(rect.y)}, ${fmt(rect.w)} × ${fmt(rect.h)}` : "—";
}

function anchorFraction(anchor) {
  const horizontal = anchor.includes("LEFT") ? 0 : anchor.includes("RIGHT") ? 1 : 0.5;
  const vertical = anchor.includes("TOP") ? 0 : anchor.includes("BOTTOM") ? 1 : 0.5;
  return { x: horizontal, y: vertical };
}

function targetForPoint(tuple, parent) {
  const relative = anchorFraction(tuple[1]);
  return { x: parent.w * relative.x + tuple[2], y: parent.h * relative.y - tuple[3] };
}

function sizedRect(tuple, size, parent) {
  const target = targetForPoint(tuple, parent);
  const child = anchorFraction(tuple[0]);
  return { x: target.x - size[0] * child.x, y: target.y - size[1] * child.y, w: size[0], h: size[1] };
}

function barRect(left, right, height, parent) {
  const a = targetForPoint(left, parent);
  const b = targetForPoint(right, parent);
  const af = anchorFraction(left[0]);
  const bf = anchorFraction(right[0]);
  const denominator = bf.x - af.x;
  const width = denominator === 0 ? 0 : (b.x - a.x) / denominator;
  return { x: a.x - af.x * width, y: a.y - af.y * height, w: width, h: height };
}

function nameSpan(left, right, parent) {
  const a = targetForPoint(left, parent);
  const b = targetForPoint(right, parent);
  return `x ${fmt(a.x)}..${fmt(b.x)} at y ${fmt(a.y)} (height comes from shared font)`;
}

function addOffset(rect, offset) {
  return { x: rect.x + offset.x, y: rect.y + offset.y, w: rect.w, h: rect.h };
}

function sourceRect(rect, display, crop, image) {
  const [left, right, top, bottom] = crop;
  return {
    x: (left + rect.x / display.w * (right - left)) * image.width,
    y: (top + rect.y / display.h * (bottom - top)) * image.height,
    w: rect.w / display.w * (right - left) * image.width,
    h: rect.h / display.h * (bottom - top) * image.height
  };
}

function alphaCoverage(image, rectangle) {
  if (!image || !rectangle || rectangle.w <= 0 || rectangle.h <= 0) return null;
  const x1 = Math.max(0, Math.floor(rectangle.x));
  const y1 = Math.max(0, Math.floor(rectangle.y));
  const x2 = Math.min(image.width, Math.ceil(rectangle.x + rectangle.w));
  const y2 = Math.min(image.height, Math.ceil(rectangle.y + rectangle.h));
  let count = 0, visible = 0, sum = 0;
  for (let y = y1; y < y2; y++) {
    for (let x = x1; x < x2; x++) {
      const a = image.alpha[y * image.width + x];
      count++; sum += a;
      if (a > 8) visible++;
    }
  }
  return count ? { visible: visible * 100 / count, mean: sum * 100 / (count * 255) } : null;
}

function flatten(value, prefix = "", rows = []) {
  for (const [key, child] of Object.entries(value)) {
    const next = prefix ? `${prefix}.${key}` : key;
    if (Array.isArray(child) || child === null || typeof child !== "object") rows.push([next, child]);
    else flatten(child, next, rows);
  }
  return rows;
}

const themes = themeNames.map(name => {
  const root = path.join(addonRoot, "Themes", name);
  const sources = fs.readdirSync(root)
    .filter(file => file.endsWith(".lua"))
    .sort((a, b) => (a === "Theme.lua") - (b === "Theme.lua") || a.localeCompare(b))
    .map(file => fs.readFileSync(path.join(root, file), "utf8"));
  const parsed = parseThemeLua(sources.join("\n"));
  const images = {};
  for (const [role, filename] of Object.entries(parsed.data.assets)) {
    images[role] = readTga(path.join(root, "Assets", filename));
  }
  return { name, root, id: parsed.id, ...parsed.data, images };
});

function geometryRows(theme) {
  const layout = theme.layout;
  const rows = [];
  function add(composition, region, parentName, rect, assetRole, display, crop, configPath, note = "") {
    const image = assetRole ? theme.images[assetRole] : null;
    const mapped = image && crop ? sourceRect(rect, display, crop, image) : null;
    const coverage = mapped ? alphaCoverage(image, mapped) : null;
    rows.push({ composition, region, parentName, rect, assetRole, mapped, coverage, configPath, note });
  }
  function span(composition, region, parentName, text, configPath, note = "") {
    rows.push({ composition, region, parentName, span: text, configPath, note });
  }

  const party = layout.party;
  const partyParent = { w: party.size[0], h: party.size[1] };
  const partyCrop = party.artCrop;
  add("Party", "Portrait", "Party root", sizedRect(party.points.portrait, [party.portraitSize, party.portraitSize], partyParent), "partyFrame", partyParent, partyCrop, "party.points.portrait + portraitSize", "transparent live opening");
  add("Party", "Health", "Party root", barRect(party.points.healthLeft, party.points.healthRight, party.healthHeight, partyParent), "partyFrame", partyParent, partyCrop, "party.points.health* + healthHeight", "transparent live opening");
  add("Party", "Power", "Party root", barRect(party.points.powerLeft, party.points.powerRight, party.powerHeight, partyParent), "partyFrame", partyParent, partyCrop, "party.points.power* + powerHeight", "transparent live opening");
  add("Party", "Level", "Party root", sizedRect(party.points.level, [party.levelSize, party.levelSize], partyParent), "partyFrame", partyParent, partyCrop, "party.points.level + levelSize", "indicator center clearance");
  add("Party", "Class", "Party root", sizedRect(party.points.class, [party.classSize, party.classSize], partyParent), "partyFrame", partyParent, partyCrop, "party.points.class + classSize", "indicator center clearance");
  add("Party", "Role", "Party root", sizedRect(party.points.role, [party.roleSize, party.roleSize], partyParent), "partyFrame", partyParent, partyCrop, "party.points.role + roleSize", "indicator footprint");
  span("Party", "Name", "Party root", nameSpan(party.points.nameLeft, party.points.nameRight, partyParent), "party.points.nameLeft/nameRight");

  function playerMode(modeName, mode, assetRole, crop, displayHeight) {
    const player = layout.player;
    const parent = { w: player.size[0], h: player.size[1] };
    const display = { w: player.size[0], h: displayHeight };
    const points = mode.points;
    add(modeName, "Portrait", "Player root", sizedRect(points.portrait, [mode.portraitSize, mode.portraitSize], parent), assetRole, display, crop, `${modeName === "Player unified" ? "player.withPet" : "player.standalone"}.points.portrait + portraitSize`, "transparent live opening");
    add(modeName, "Health", "Player root", barRect(points.healthLeft, points.healthRight, mode.healthHeight, parent), assetRole, display, crop, `${modeName === "Player unified" ? "player.withPet" : "player.standalone"}.points.health* + healthHeight`, "transparent live opening");
    add(modeName, "Power", "Player root", barRect(points.powerLeft, points.powerRight, mode.powerHeight, parent), assetRole, display, crop, `${modeName === "Player unified" ? "player.withPet" : "player.standalone"}.points.power* + powerHeight`, "transparent live opening");
    span(modeName, "Name", "Player root", nameSpan(points.nameLeft, points.nameRight, parent), `${modeName === "Player unified" ? "player.withPet" : "player.standalone"}.points.name*`);
    const levelSize = player.levelSize || 40;
    const classSize = player.classSize || 35;
    add(modeName, "Level", "Player root", sizedRect(points.level, [levelSize, levelSize], parent), assetRole, display, crop, "points.level + runtime-derived indicator size", "indicator footprint");
    add(modeName, "Class", "Player root", sizedRect(points.class, [classSize, classSize], parent), assetRole, display, crop, "points.class + runtime-derived indicator size", "indicator footprint");
  }
  playerMode("Player unified", layout.player.withPet, "playerFrameWithPet", layout.player.withPetCrop, layout.player.withPetHeight);
  playerMode("Player standalone", layout.player.standalone, "unitFrame", layout.player.standaloneCrop, layout.player.standaloneHeight || layout.player.size[1]);

  const petMode = layout.player.withPet;
  const playerParent = { w: layout.player.size[0], h: layout.player.size[1] };
  const petSize = layout.player.pet.size;
  const petRoot = sizedRect(petMode.petPoints.frame, petSize, playerParent);
  add("Pet unified", "Pet root", "Player root", petRoot, "playerFrameWithPet", { w: layout.player.size[0], h: layout.player.withPetHeight }, layout.player.withPetCrop, "player.withPet.petPoints.frame + player.pet.size", "secure Pet region");
  const petParent = { w: petSize[0], h: petSize[1] };
  const petDisplay = { w: layout.player.size[0], h: layout.player.withPetHeight };
  const petCrop = layout.player.withPetCrop;
  const globalPet = rect => addOffset(rect, petRoot);
  add("Pet unified", "Portrait", "Pet root", globalPet(sizedRect(petMode.petPoints.portrait, [layout.player.pet.portraitSize, layout.player.pet.portraitSize], petParent)), "playerFrameWithPet", petDisplay, petCrop, "player.withPet.petPoints.portrait + player.pet.portraitSize", "transparent live opening");
  add("Pet unified", "Health", "Pet root", globalPet(barRect(petMode.petPoints.healthLeft, petMode.petPoints.healthRight, layout.player.pet.healthHeight, petParent)), "playerFrameWithPet", petDisplay, petCrop, "player.withPet.petPoints.health* + player.pet.healthHeight", "transparent live opening");
  if (layout.player.pet.powerHeight && petMode.petPoints.powerLeft && petMode.petPoints.powerRight) {
    add("Pet unified", "Power", "Pet root", globalPet(barRect(petMode.petPoints.powerLeft, petMode.petPoints.powerRight, layout.player.pet.powerHeight, petParent)), "playerFrameWithPet", petDisplay, petCrop, "player.withPet.petPoints.power* + player.pet.powerHeight", "transparent live opening");
  }
  span("Pet unified", "Name", "Pet root", nameSpan(petMode.petPoints.nameLeft, petMode.petPoints.nameRight, petParent), "player.withPet.petPoints.name*", `add Pet root offset ${fmt([petRoot.x, petRoot.y])}`);

  function unitFull(name, size, assetRole, points, dimensions, crop) {
    const parent = { w: size[0], h: size[1] };
    const display = parent;
    add(name, "Portrait", `${name} root`, sizedRect(points.portrait, [dimensions.portraitSize, dimensions.portraitSize], parent), assetRole, display, crop, `${dimensions.path}.points.portrait + portrait size`, "transparent live opening");
    add(name, "Health", `${name} root`, barRect(points.healthLeft, points.healthRight, dimensions.healthHeight, parent), assetRole, display, crop, `${dimensions.path}.points.health* + health height`, "transparent live opening");
    add(name, "Power", `${name} root`, barRect(points.powerLeft, points.powerRight, dimensions.powerHeight, parent), assetRole, display, crop, `${dimensions.path}.points.power* + power height`, "transparent live opening");
    span(name, "Name", `${name} root`, nameSpan(points.nameLeft, points.nameRight, parent), `${dimensions.path}.points.name*`);
    add(name, "Level", `${name} root`, sizedRect(points.level, [dimensions.levelSize, dimensions.levelSize], parent), assetRole, display, crop, `${dimensions.path}.points.level`, "indicator footprint");
    add(name, "Class", `${name} root`, sizedRect(points.class, [dimensions.classSize, dimensions.classSize], parent), assetRole, display, crop, `${dimensions.path}.points.class`, "indicator footprint");
  }
  const uf = layout.unitFrames;
  unitFull("Target", uf.targetSize, "unitFrame", uf.full.points, {
    portraitSize: uf.full.portraitSize || Math.floor(uf.targetSize[1] * 0.60), healthHeight: uf.full.healthHeight,
    powerHeight: uf.full.powerHeight, levelSize: uf.full.levelSize || Math.max(30, Math.floor(uf.targetSize[1] * 0.24)),
    classSize: uf.full.classSize || Math.max(28, Math.floor(uf.targetSize[1] * 0.20)), path: "unitFrames.full"
  }, uf.artCrop);
  const targetOfTargetCrop = uf.targetOfTarget.artCrop || uf.artCrop;
  unitFull("Target-of-Target", uf.targetOfTargetSize, "targetOfTargetFrame", uf.targetOfTarget.points, {
    portraitSize: uf.targetOfTarget.portraitSize, healthHeight: uf.targetOfTarget.healthHeight || uf.targetOfTarget.barHeight,
    powerHeight: uf.targetOfTarget.powerHeight || uf.targetOfTarget.barHeight, levelSize: uf.targetOfTarget.levelSize,
    classSize: uf.targetOfTarget.classSize, path: "unitFrames.targetOfTarget"
  }, targetOfTargetCrop);

  const focus = { w: uf.focusSize[0], h: uf.focusSize[1] };
  const scaled = uf.scaled;
  const focusPortrait = scaled.portraitSize || Math.floor(focus.h * 0.60);
  add("Focus", "Portrait", "Focus root", { x: focus.w * scaled.portraitX, y: -focus.h * scaled.portraitY, w: focusPortrait, h: focusPortrait }, "unitFrame", focus, uf.artCrop, "unitFrames.scaled.portraitX/Y + portraitSize", "transparent live opening");
  add("Focus", "Health", "Focus root", { x: focus.w * scaled.healthLeft, y: -focus.h * scaled.healthY, w: focus.w * (1 - scaled.healthLeft - scaled.healthRight), h: scaled.healthHeight || Math.max(10, Math.floor(focus.h * 0.117)) }, "unitFrame", focus, uf.artCrop, "unitFrames.scaled.health*", "transparent live opening");
  add("Focus", "Power", "Focus root", { x: focus.w * scaled.powerLeft, y: -focus.h * scaled.powerY, w: focus.w * (1 - scaled.powerLeft - scaled.powerRight), h: scaled.powerHeight || Math.max(10, Math.floor(focus.h * 0.123)) }, "unitFrame", focus, uf.artCrop, "unitFrames.scaled.power*", "transparent live opening");
  span("Focus", "Name", "Focus root", `x ${fmt(focus.w * scaled.nameLeft + scaled.nameLeftInset)}..${fmt(focus.w - (focus.w * scaled.nameRight + scaled.nameRightInset))} at y ${fmt(-focus.h * scaled.nameY + scaled.nameYOffset)} (height comes from shared font)`, "unitFrames.scaled.name*");
  add("Focus", "Level", "Focus root", { x: focus.w * scaled.levelX - Math.max(30, Math.floor(focus.h * 0.24)) / 2, y: -focus.h * scaled.levelY - Math.max(30, Math.floor(focus.h * 0.24)) / 2, w: Math.max(30, Math.floor(focus.h * 0.24)), h: Math.max(30, Math.floor(focus.h * 0.24)) }, "unitFrame", focus, uf.artCrop, "unitFrames.scaled.levelX/Y", "indicator footprint");
  const focusClassSize = scaled.classSize || Math.max(28, Math.floor(focus.h * 0.20));
  add("Focus", "Class", "Focus root", { x: focus.w * scaled.classX - focusClassSize / 2, y: -focus.h * scaled.classY - focusClassSize / 2, w: focusClassSize, h: focusClassSize }, "unitFrame", focus, uf.artCrop, "unitFrames.scaled.classX/Y", "indicator footprint");

  const np = layout.nameplate;
  const npDisplay = { w: np.artSize[0], h: np.artSize[1] };
  const zeroParent = { w: 0, h: 0 };
  const npArtInParent = sizedRect(np.artPoint, np.artSize, zeroParent);
  const relativeToNameplateArt = rect => {
    const inParent = rect;
    return { x: inParent.x - npArtInParent.x, y: inParent.y - npArtInParent.y, w: inParent.w, h: inParent.h };
  };
  const npHealth = relativeToNameplateArt(sizedRect(np.healthPoint, np.healthSize, zeroParent));
  add("Nameplate", "Health backing", "Blizzard health container; reported in art-local coordinates", npHealth, "nameplateFrame", npDisplay, [0, 1, 0, 1], "nameplate.artPoint + healthPoint + healthSize", "intentionally opaque neutral-black backing");
  add("Nameplate", "Level", "Blizzard health container; reported in art-local coordinates", relativeToNameplateArt(sizedRect(np.levelPoint, [12, 12], zeroParent)), "nameplateFrame", npDisplay, [0, 1, 0, 1], "nameplate.artPoint + levelPoint", "12×12 measurement proxy; live text has shared font metrics");
  add("Nameplate", "Raid marker", "Blizzard health container; reported in art-local coordinates", relativeToNameplateArt(sizedRect(np.marker.point, [np.marker.size, np.marker.size], zeroParent)), "nameplateFrame", npDisplay, [0, 1, 0, 1], "nameplate.artPoint + marker", "live overlay; may sit outside art bounds");

  const raid = layout.raid;
  const raidParent = { w: raid.frameSize[0], h: raid.frameSize[1] };
  add("Raid", "Health", "Raid root", barRect(raid.healthTopLeft, raid.healthBottomRight, raid.frameSize[1] - 22, raidParent), null, raidParent, null, "raid.healthTopLeft/healthBottomRight", "art uses three-slice mapping; source alpha coverage is not linear");
  add("Raid", "Marker", "Raid root", sizedRect(raid.marker.point, [raid.marker.size, raid.marker.size], raidParent), null, raidParent, null, "raid.marker", "live overlay");

  const cast = layout.castBar;
  const castConsumers = [
    ["Player cast", layout.player.pet.castBarSize, layout.player.pet.castBarOrnamentExtraWidth || cast.ornamentExtraWidth, cast.ornamentMinHeight, layout.player.pet.castBarOrnamentExtraWidth || cast.ornamentExtraWidth, cast.ornamentMinHeight, cast.ornamentPoint],
    ["Target cast", uf.full.castBarSize, uf.full.castBarOrnamentExtraWidth, cast.ornamentMinHeight, uf.full.castBarOrnamentExtraWidth, cast.ornamentMinHeight, cast.ornamentPoint],
    ["Focus cast", uf.scaled.castBarSize, uf.scaled.castBarOrnamentExtraWidth, cast.ornamentMinHeight, uf.scaled.castBarOrnamentExtraWidth, cast.ornamentMinHeight, cast.ornamentPoint],
    ["Nameplate cast", [np.healthSize[0], np.castHeight], np.castOrnamentExtraWidth, np.castOrnamentMinHeight, np.castInterruptGlowExtraWidth, np.castInterruptGlowMinHeight, np.castOrnamentPoint]
  ];
  for (const [name, barSize, extra, minHeight, glowExtra, glowMinHeight, ornamentPoint] of castConsumers) {
    const ornamentWidth = barSize[0] + extra;
    const ornamentHeight = Math.max(minHeight, ornamentWidth / cast.ornamentAspect);
    const barParent = { w: barSize[0], h: barSize[1] };
    const ornamentRect = sizedRect(ornamentPoint, [ornamentWidth, ornamentHeight], barParent);
    const barInsideOrnament = { x: -ornamentRect.x, y: -ornamentRect.y, w: barSize[0], h: barSize[1] };
    const castImage = theme.images.castBarFrame;
    const castMapped = sourceRect(barInsideOrnament, { w: ornamentWidth, h: ornamentHeight }, [0, 1, 0, 1], castImage);
    const castCoverage = alphaCoverage(castImage, castMapped);
    rows.push({ composition: name, region: "Live bar", parentName: "owning frame", rect: { x: 0, y: 0, w: barSize[0], h: barSize[1] }, configPath: "consumer castBarSize" });
    rows.push({ composition: name, region: "Spell icon", parentName: "live cast bar", rect: sizedRect(cast.iconPoint, [barSize[1] + cast.iconExtraSize, barSize[1] + cast.iconExtraSize], barParent), configPath: "castBar.iconPoint + iconExtraSize" });
    span(name, "Cast text", "spell icon right edge to live bar right", `left gap ${fmt(cast.textLeft)}, right inset ${fmt(-cast.textRight)}, vertically centered; font size ${Math.max(9, barSize[1] - 3)}`, "castBar.textLeft/textRight + runtime font rule");
    rows.push({ composition: name, region: "Ornament", parentName: "live cast bar", rect: ornamentRect, configPath: "castBar ornament point/extra/aspect/minimum", note: "sibling overlay; dimensions derived at runtime" });
    rows.push({ composition: name, region: "Bar opening in ornament art", parentName: "ornament-local", rect: barInsideOrnament, mapped: castMapped, coverage: castCoverage, configPath: "derived from live bar and ornament geometry", note: "lower alpha means less ornament painted across the live fill" });
    const glowWidth = barSize[0] + glowExtra;
    const glowHeight = Math.max(glowMinHeight, glowWidth / cast.ornamentAspect);
    rows.push({ composition: name, region: "Interrupt glow", parentName: "live cast bar", rect: sizedRect(cast.interruptGlowPoint, [glowWidth, glowHeight], barParent), configPath: "interruptGlowPoint/crop/alpha + consumer glow extra/minimum", note: `UV crop ${fmt(cast.interruptGlowCrop)}, alpha ${fmt(cast.interruptGlowAlpha)}` });
  }
  return rows;
}

function table(headers, rows) {
  const head = `| ${headers.join(" | ")} |\n|${headers.map(() => "---").join("|")}|\n`;
  return head + rows.map(row => `| ${row.map(cell => fmt(cell)).join(" | ")} |`).join("\n") + "\n";
}

const lines = [];
lines.push("# PrettyFrames measured geometry reference", "", "> Generated by `node tools/GenerateThemeGeometryReference.js`. Do not edit measured tables by hand.", "", "This worksheet compares implemented themes as measured examples. It is not a coordinate preset. A future independent theme should create its own composition, then use the same measurements to verify that live widgets align with its art.", "", "## Reading the measurements", "", "- Display rectangles use a top-left origin: positive X moves right and positive Y moves down.", "- Source rectangles are the display rectangles mapped through the configured UV crop into TGA pixels.", "- `visible alpha` is the percentage of mapped source pixels with alpha greater than 8/255. Low coverage is normally desirable for portrait and bar openings; portrait rims and indicator decorations may intentionally overlap the edges of their widget rectangles, so the number is diagnostic rather than a pass/fail threshold.", "- `mean alpha` includes partial transparency. The nameplate health backing is intentionally expected to be opaque.", "- Measurements describe the canonical portrait-left orientation. Mirrored geometry follows the reflection rules in the authoring guide.", "- Text spans do not claim a rectangle height because fonts and metrics remain shared runtime values.", "");

lines.push("## Compared themes", "");
lines.push(table(["Theme", "ID", "Display name", "Description"], themes.map(t => [t.name, t.id, t.name, t.description])));

lines.push("## Runtime art measurements", "", "Alpha bounds describe painted content, not required openings.", "");
const roles = Object.keys(themes[0].assets);
lines.push(table(["Role", ...themes.flatMap(t => [`${t.name} canvas`, `${t.name} alpha bounds`, `${t.name} visible`])], roles.map(role => {
  const cells = [role];
  for (const theme of themes) {
    const image = theme.images[role];
    cells.push(
      image ? `${image.width} × ${image.height}` : "—",
      image ? (image.bounds ? rectText(image.bounds) : "none") : "—",
      image ? `${fmt(image.visiblePercent)}%` : "—"
    );
  }
  return cells;
})));

lines.push("## Complete resolved theme layout comparison", "", "This is a leaf-level inventory. Identical values are still shown because they prove similarity; differences are marked in the last column.", "");
const flatMaps = themes.map(theme => new Map(flatten(theme.layout).map(([k, v]) => [k, v])));
const allPaths = [...new Set(flatMaps.flatMap(map => [...map.keys()]))].sort();
lines.push(table(["Layout path", ...themes.map(t => t.name), "Comparison"], allPaths.map(key => {
  const values = flatMaps.map(map => map.get(key));
  const serialized = values.map(v => JSON.stringify(v));
  return [key, ...values, serialized.every(v => v === serialized[0]) ? "same" : "different"];
})));

for (const theme of themes) {
  lines.push(`## ${theme.name} derived live-region geometry`, "", "Rectangles below combine configured sizes, anchor tuples, runtime-derived dimensions, and art crops. They are measurements of this theme, not recommended defaults.", "");
  const rows = geometryRows(theme);
  lines.push(table(["Composition", "Live region", "Attachment parent", "Display rectangle/span", "Config source", "Mapped source rectangle", "Visible alpha / mean alpha", "Notes"], rows.map(row => [
    row.composition,
    row.region,
    row.parentName,
    row.span || rectText(row.rect),
    row.configPath,
    row.mapped ? rectText(row.mapped) : "—",
    row.coverage ? `${fmt(row.coverage.visible)}% / ${fmt(row.coverage.mean)}%` : "—",
    row.note || ""
  ])));
}

lines.push("## Independent-theme blank worksheet", "", "Copy this section into the new theme's design notes. Fill it from the intended composition before final art generation.", "", table(["Composition", "Root/display size", "Art role and crop", "Live region", "Attachment parent", "Point tuple(s)", "Derived rectangle", "Opening/backing rule", "Mirrored/paired dependency", "Measured alpha coverage"], [
  ["Player unified", "", "playerFrameWithPet", "portrait / health / power / name / level / class / Pet", "Player root or Pet root", "", "", "", "", ""],
  ["Player standalone", "", "unitFrame", "portrait / health / power / name / level / class", "Player root", "", "", "", "unitFrame consumers", ""],
  ["Target", "", "unitFrame + unitFrameOneBar", "portrait / health / power / name / level / class", "Target root", "", "", "", "Focus + one-bar", ""],
  ["Focus", "", "unitFrame + unitFrameOneBar", "portrait / health / power / name / level / class", "Focus root", "", "", "", "Target + scaled layout", ""],
  ["Target-of-Target", "", "targetOfTargetFrame pair", "portrait / health / power / name / level / class", "Target-of-Target root", "", "", "", "one-bar + Target attachment", ""],
  ["Party", "", "partyFrame", "portrait / health / power / name / level / class / role", "Party root", "", "", "", "mirrored + connector", ""],
  ["Raid", "", "raidFrame", "health / name / role / marker / status", "Raid root", "", "", "", "three-slice + 40 frames", ""],
  ["Nameplate", "", "nameplateFrame", "health / name / level / marker / cast", "Blizzard health container", "", "", "opaque health backing", "native nameplate paths", ""],
  ["Cast bars", "", "castBarFrame + interrupt glow", "bar / icon / text / ornament / glow", "live cast bar", "", "", "transparent interior", "all consumers + preview", ""]
]));

fs.writeFileSync(outputPath, lines.join("\n"), "utf8");
console.log(`Wrote ${path.relative(addonRoot, outputPath)} for ${themes.map(t => t.name).join(", ")}`);
