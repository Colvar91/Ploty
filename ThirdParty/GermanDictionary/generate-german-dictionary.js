'use strict';

const fs = require('fs');
const path = require('path');

const dictionaryPath = process.argv[2];
const affixPath = process.argv[3];
const outputPath = process.argv[4];

if (!dictionaryPath || !affixPath || !outputPath) {
  throw new Error('Usage: node generate-german-dictionary.js <dictionary.dic> <dictionary.aff> <output.lua>');
}

function readLatin1(filePath) {
  return fs.readFileSync(filePath).toString('latin1').replace(/\r\n/g, '\n');
}

function unescapeHunspell(value) {
  return value.replace(/\\\//g, '/').replace(/\\-/g, '-').replace(/\\ /g, ' ');
}

function splitDictionaryEntry(line) {
  const field = line.split(/\s+/u, 1)[0];
  let slash = -1;
  for (let index = 0; index < field.length; index += 1) {
    if (field[index] === '/' && field[index - 1] !== '\\') {
      slash = index;
      break;
    }
  }
  if (slash < 0) {
    return { word: unescapeHunspell(field), flags: '' };
  }
  return {
    word: unescapeHunspell(field.slice(0, slash)),
    flags: field.slice(slash + 1),
  };
}

function parseAffixes(source) {
  const lines = source.split('\n');
  const groups = { PFX: new Map(), SFX: new Map() };
  const specialFlags = {};

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (!line || line.startsWith('#')) continue;
    const fields = line.split(/\s+/u);
    const directive = fields[0];

    if (['NEEDAFFIX', 'ONLYINCOMPOUND', 'FORBIDDENWORD', 'KEEPCASE'].includes(directive)) {
      specialFlags[directive] = fields[1];
      continue;
    }

    if ((directive !== 'PFX' && directive !== 'SFX') || fields.length !== 4 || !/^\d+$/u.test(fields[3])) {
      continue;
    }

    const flag = fields[1];
    const group = { cross: fields[2] === 'Y', rules: [] };
    const expectedRules = Number(fields[3]);
    for (let ruleIndex = 0; ruleIndex < expectedRules; ruleIndex += 1) {
      index += 1;
      const ruleLine = lines[index] ? lines[index].trim() : '';
      if (!ruleLine || ruleLine.startsWith('#')) {
        ruleIndex -= 1;
        continue;
      }
      const ruleFields = ruleLine.split(/\s+/u);
      if (ruleFields[0] !== directive || ruleFields[1] !== flag || ruleFields.length < 5) {
        throw new Error(`Invalid ${directive} rule: ${ruleLine}`);
      }
      const addAndFlags = ruleFields[3].split('/');
      group.rules.push({
        type: directive,
        flag,
        strip: ruleFields[2] === '0' ? '' : ruleFields[2],
        add: addAndFlags[0] === '0' ? '' : addAndFlags[0],
        continuationFlags: addAndFlags[1] || '',
        condition: ruleFields[4],
      });
    }
    groups[directive].set(flag, group);
  }

  return { groups, specialFlags };
}

function conditionMatches(word, rule) {
  if (rule.condition === '.') return true;
  const expression = rule.type === 'PFX' ? `^(?:${rule.condition})` : `(?:${rule.condition})$`;
  return new RegExp(expression, 'u').test(word);
}

function applyRule(word, rule) {
  if (!conditionMatches(word, rule)) return null;
  if (rule.type === 'PFX') {
    if (rule.strip && !word.startsWith(rule.strip)) return null;
    return rule.add + word.slice(rule.strip.length);
  }
  if (rule.strip && !word.endsWith(rule.strip)) return null;
  return word.slice(0, word.length - rule.strip.length) + rule.add;
}

function normalizeWord(word) {
  return word.normalize('NFC').toLocaleLowerCase('de-DE');
}

const affix = parseAffixes(readLatin1(affixPath));
const entries = readLatin1(dictionaryPath).split('\n');
const words = new Set();
const caseMasks = new Map();
let dictionaryEntries = 0;
let generatedForms = 0;

function getInitialCaseMask(word) {
  const first = Array.from(word)[0] || '';
  const lower = first.toLocaleLowerCase('de-DE');
  const upper = first.toLocaleUpperCase('de-DE');
  if (lower === upper) return 0;
  return first === upper ? 2 : 1;
}

function addWord(word, trackCase) {
  if (!word || word.length < 2 || word.length > 80 || /[\s_/]/u.test(word)) return;
  const normalized = normalizeWord(word);
  words.add(normalized);
  if (trackCase) {
    caseMasks.set(normalized, (caseMasks.get(normalized) || 0) | getInitialCaseMask(word));
  }
}

for (const rawLine of entries) {
  const line = rawLine.trim();
  if (!line || line.startsWith('#') || /^\d+$/u.test(line)) continue;
  const entry = splitDictionaryEntry(line);
  if (!entry.word) continue;
  dictionaryEntries += 1;

  const forbiddenFlag = affix.specialFlags.FORBIDDENWORD;
  if (forbiddenFlag && entry.flags.includes(forbiddenFlag)) continue;

  const needAffixFlag = affix.specialFlags.NEEDAFFIX;
  const onlyCompoundFlag = affix.specialFlags.ONLYINCOMPOUND;
  const standaloneRoot = (!needAffixFlag || !entry.flags.includes(needAffixFlag)) &&
    (!onlyCompoundFlag || !entry.flags.includes(onlyCompoundFlag));
  if (standaloneRoot) {
    addWord(entry.word, true);
  }

  const prefixes = [];
  const suffixes = [];
  for (const flag of entry.flags) {
    const prefixGroup = affix.groups.PFX.get(flag);
    if (prefixGroup) {
      for (const rule of prefixGroup.rules) {
        const form = applyRule(entry.word, rule);
        if (form) {
          prefixes.push({ form, group: prefixGroup, rule });
          addWord(form, standaloneRoot &&
            (!onlyCompoundFlag || !rule.continuationFlags.includes(onlyCompoundFlag)));
          generatedForms += 1;
        }
      }
    }

    const suffixGroup = affix.groups.SFX.get(flag);
    if (suffixGroup) {
      for (const rule of suffixGroup.rules) {
        const form = applyRule(entry.word, rule);
        if (form) {
          suffixes.push({ form, group: suffixGroup, rule });
          addWord(form, standaloneRoot &&
            (!onlyCompoundFlag || !rule.continuationFlags.includes(onlyCompoundFlag)));
          generatedForms += 1;
        }
      }
    }
  }

  for (const prefix of prefixes) {
    if (!prefix.group.cross) continue;
    for (const suffix of suffixes) {
      if (!suffix.group.cross) continue;
      const combined = applyRule(prefix.form, suffix.rule);
      if (combined) {
        addWord(combined, standaloneRoot &&
          (!onlyCompoundFlag || (!prefix.rule.continuationFlags.includes(onlyCompoundFlag) &&
            !suffix.rule.continuationFlags.includes(onlyCompoundFlag))));
        generatedForms += 1;
      }
    }
  }
}

function utf8Bytes(value) {
  return Buffer.from(value, 'utf8');
}

function getHashes(value, bitCount) {
  let first = 5381;
  let second = 52711;
  for (const byte of utf8Bytes(value)) {
    first = (first * 33 + byte) % bitCount;
    // Bleibt auch in Lua-Laufzeiten mit 32-Bit-Ganzzahlen überlauffrei.
    second = (second * 131 + byte) % bitCount;
  }
  if (second === 0) second = 97;
  return { first, second };
}

const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const lineLength = 120;

function buildBloom(values, bitsPerWord, hashCount) {
  const bitCount = Math.max(6, Math.ceil((values.length * bitsPerWord) / 6) * 6);
  const encodedLength = bitCount / 6;
  const bloom = new Uint8Array(encodedLength);

  for (const word of values) {
    const hashes = getHashes(word, bitCount);
    for (let index = 0; index < hashCount; index += 1) {
      const bit = (hashes.first + index * hashes.second + index * index) % bitCount;
      bloom[Math.floor(bit / 6)] |= 1 << (bit % 6);
    }
  }

  let encoded = '';
  for (let index = 0; index < bloom.length; index += 1) {
    encoded += alphabet[bloom[index]];
  }
  return {
    bitCount,
    hashCount,
    encodedLength,
    wrapped: encoded.match(new RegExp(`.{1,${lineLength}}`, 'g')).join('\n'),
  };
}

const capitalRequiredWords = [];
const lowerRequiredWords = [];
for (const [word, mask] of caseMasks) {
  if ((mask & 2) !== 0) capitalRequiredWords.push(word);
  if ((mask & 1) !== 0) lowerRequiredWords.push(word);
}

const wordBloom = buildBloom(Array.from(words), 16, 9);
// Case filters use a lower false-positive rate because one stray hit could
// otherwise turn a correct spelling into an incorrect case warning.
const capitalBloom = buildBloom(capitalRequiredWords, 24, 12);
const lowerBloom = buildBloom(lowerRequiredWords, 24, 12);

const lua = `local addonName, Ploty = ...

-- Generated from the German igerman98/frami Hunspell dictionary.
-- Dictionary version: 20161207+frami20170109
-- License: GPL-2.0 or GPL-3.0; see ThirdParty/GermanDictionary.
-- Recognized word forms: ${words.size}
-- Word forms available with an initial capital: ${capitalRequiredWords.length}
-- Word forms available with a lowercase initial: ${lowerRequiredWords.length}
local BLOOM_LINE_LENGTH = ${lineLength}
local BLOOM_ALPHABET = "${alphabet}"
local WORD_BITS = ${wordBloom.bitCount}
local WORD_HASHES = ${wordBloom.hashCount}
local WORD_DATA = [[${wordBloom.wrapped}]]
local CAPITAL_BITS = ${capitalBloom.bitCount}
local CAPITAL_HASHES = ${capitalBloom.hashCount}
local CAPITAL_DATA = [[${capitalBloom.wrapped}]]
local LOWER_BITS = ${lowerBloom.bitCount}
local LOWER_HASHES = ${lowerBloom.hashCount}
local LOWER_DATA = [[${lowerBloom.wrapped}]]

local bloomValues = {}
for index = 1, #BLOOM_ALPHABET do
    bloomValues[BLOOM_ALPHABET:byte(index)] = index - 1
end

local function normalizeGermanWord(value)
    return tostring(value or ""):lower()
        :gsub("Ä", "ä")
        :gsub("Ö", "ö")
        :gsub("Ü", "ü")
        :gsub("ẞ", "ß")
end

local function bloomContainsNormalized(value, bloomData, bloomBits, bloomHashes)
    if value == "" then
        return false
    end

    local first = 5381
    local second = 52711
    for index = 1, #value do
        local byte = value:byte(index)
        first = (first * 33 + byte) % bloomBits
        second = (second * 131 + byte) % bloomBits
    end
    if second == 0 then
        second = 97
    end

    for index = 0, bloomHashes - 1 do
        local bitIndex = (first + index * second + index * index) % bloomBits
        local encodedIndex = math.floor(bitIndex / 6) + 1
        local sourceIndex = encodedIndex + math.floor((encodedIndex - 1) / BLOOM_LINE_LENGTH)
        local valueAtPosition = bloomValues[bloomData:byte(sourceIndex)]
        if not valueAtPosition or math.floor(valueAtPosition / (2 ^ (bitIndex % 6))) % 2 == 0 then
            return false
        end
    end
    return true
end

local function bloomContains(value, bloomData, bloomBits, bloomHashes)
    return bloomContainsNormalized(normalizeGermanWord(value), bloomData, bloomBits, bloomHashes)
end

local function getUtf8CharacterStarts(value)
    local starts = {}
    local position = 1
    while position <= #value do
        starts[#starts + 1] = position
        local byte = value:byte(position)
        if byte < 0x80 then
            position = position + 1
        elseif byte < 0xE0 then
            position = position + 2
        elseif byte < 0xF0 then
            position = position + 3
        else
            position = position + 4
        end
    end
    return starts
end

local function findCompoundLastPart(value, depth)
    depth = tonumber(depth) or 1
    if depth > 4 then
        return nil
    end

    local starts = getUtf8CharacterStarts(value)
    local characterCount = #starts
    if characterCount < 6 then
        return nil
    end

    -- Deutsche Komposita werden von links nach rechts zerlegt. Mindestens
    -- drei Zeichen pro Bestandteil vermeiden zu großzügige Zufallstreffer.
    -- Vom Wortende aus suchen: Der letzte (bedeutungsbestimmende) Bestandteil
    -- ist bei deutschen Komposita meist der kürzere, eindeutige Kopf.
    for splitCharacter = characterCount - 3, 3, -1 do
        local rightStart = starts[splitCharacter + 1]
        local left = value:sub(1, rightStart - 1)
        local right = value:sub(rightStart)
        if bloomContainsNormalized(left, WORD_DATA, WORD_BITS, WORD_HASHES) then
            if bloomContainsNormalized(right, WORD_DATA, WORD_BITS, WORD_HASHES) then
                return right
            end
            local nestedLastPart = findCompoundLastPart(right, depth + 1)
            if nestedLastPart then
                return nestedLastPart
            end
        end
    end
    return nil
end

function Ploty:GermanDictionaryContains(value)
    local normalized = normalizeGermanWord(value)
    return bloomContainsNormalized(normalized, WORD_DATA, WORD_BITS, WORD_HASHES) or
        findCompoundLastPart(normalized) ~= nil
end

function Ploty:GetGermanDictionaryRequiredCase(value)
    local normalized = normalizeGermanWord(value)
    local requiresCapital = bloomContainsNormalized(normalized, CAPITAL_DATA, CAPITAL_BITS, CAPITAL_HASHES)
    local requiresLower = bloomContainsNormalized(normalized, LOWER_DATA, LOWER_BITS, LOWER_HASHES)
    if requiresCapital == requiresLower then
        local lastPart = findCompoundLastPart(normalized)
        if not lastPart then
            return nil
        end
        requiresCapital = bloomContainsNormalized(lastPart, CAPITAL_DATA, CAPITAL_BITS, CAPITAL_HASHES)
        requiresLower = bloomContainsNormalized(lastPart, LOWER_DATA, LOWER_BITS, LOWER_HASHES)
        -- Bei geschlossenen Komposita ist ein vorhandener substantivischer
        -- Kopf maßgeblich, auch wenn dieselbe Form zusätzlich als Verb existiert.
        if requiresCapital then
            return "upper"
        elseif requiresLower then
            return "lower"
        end
        return nil
    end
    return requiresCapital and "upper" or "lower"
end
`;

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, lua, 'utf8');

process.stdout.write(JSON.stringify({
  dictionaryEntries,
  generatedForms,
  recognizedWords: words.size,
  capitalRequiredWords: capitalRequiredWords.length,
  lowerRequiredWords: lowerRequiredWords.length,
  encodedBytes: wordBloom.encodedLength + capitalBloom.encodedLength + lowerBloom.encodedLength,
  luaBytes: Buffer.byteLength(lua),
}, null, 2));
