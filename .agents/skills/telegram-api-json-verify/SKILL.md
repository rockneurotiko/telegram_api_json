---
name: telegram-api-json-verify
description: Verify the telegram_api_json export against the official Telegram Bot API. Use this skill whenever the user mentions updating, checking, verifying, or validating the Telegram Bot API JSON export, or when they mention tg_api_pretty.json, telegram_api_json, or the Telegram bot API scraper. Also use when they say things like "I updated the export", "check the new version", "verify the API json", or "make sure the export is correct".
---

# Telegram API JSON Export Verifier

This skill verifies that the `exports/tg_api_pretty.json` (and `tg_api.json`) in the `telegram_api_json` Elixir project correctly captures all types, methods, and generics from the official Telegram Bot API.

## Project Context

The project at `/home/rock/Git/tg/telegram_api_json` is an Elixir scraper that:
- Fetches `https://core.telegram.org/bots/api`
- Parses it into models (types with fields), methods (with params), and generics (union/sum types)
- Exports to `exports/tg_api.json` and `exports/tg_api_pretty.json`

Key source file: `lib/telegram_api_json.ex`
- `@generic_types` list controls which types are treated as generics vs models
- `@skip` list has types to ignore (currently just `InputFile`)

## Export JSON Structure

```json
{
  "models": [{ "name": "TypeName", "description": "...", "params": [{ "name": "field", "type": [...], "optional": bool, "description": "..." }] }],
  "methods": [{ "name": "methodName", "type": "get|post", "return": [...], "description": "...", "params": [...] }],
  "generics": [{ "name": "UnionType", "subtypes": ["SubtypeA", "SubtypeB"] }]
}
```

## Verification Procedure

### Step 1: Fetch the official API and load the export

1. Download the official API HTML to `/tmp/tg_api.html`:
   ```bash
   curl -s 'https://core.telegram.org/bots/api' -o /tmp/tg_api.html
   ```
2. Load the export JSON from `exports/tg_api_pretty.json`

### Step 2: Extract official types and methods from HTML

Parse the HTML to classify all `<h4>` anchored sections:
- **Types**: sections with `<th>Field</th>` tables, or "Currently, it can be one of/either/any of" (generics), or "Currently holds no information" (empty types)
- **Methods**: sections with `<th>Parameter</th>` + `<th>Required</th>` tables
- **Parameter-less methods**: sections with "Requires no parameters" or "Returns the list of..." without a table

### Step 3: Cross-reference completeness

Check for:
- Official types missing from export (neither in models nor generics)
- Official methods missing from export
- Export items that don't exist in the official API (could indicate stale/removed items)

### Step 4: Validate all fields and parameters

For every model in the export, extract the field names from the official HTML table and compare. For every method, do the same with parameter names. Report any mismatches.

### Step 5: Verify generic classification

A type should be a **generic** (not a model) when the official docs say "Currently, it can be one of/either/any of the following types:" and list subtypes without having its own field table.

Common issue: a new union type gets scraped as a model because it's not in the `@generic_types` list in `lib/telegram_api_json.ex`. Symptoms:
- The "model" has fields that actually belong to the next type in the HTML
- Its description contains "Currently, it can be..."

Check that all generics in the export match official subtypes, and that no model has a description indicating it should be a generic.

### Step 6: Spot-check critical types

Always verify these high-churn types have correct field counts:
- `Update` (entry point, gains new fields each version)
- `Message` (largest type, 100+ fields)
- `ChatFullInfo` (frequently extended)
- `User` (gains capability flags)

## Type Normalization Rules

The export normalizes Telegram's native type names to shorter forms. Every occurrence must be consistent — no raw Telegram type names should leak into the export.

| Official API type | Export type |
|---|---|
| `Integer` | `int` |
| `Int` | `int` |
| `String` | `str` |
| `Boolean` | `bool` |
| `True` | `bool` |
| `Float` | `float` |
| `Float number` | `float` |
| `InputFile` | `file` |
| `Array of X` | `["array", ["X"]]` |

Anything else (type names like `Message`, `User`, etc.) stays as-is.

### Checking for type leaks

After regeneration, always verify no raw types leaked through:

```javascript
// Add this to the validation script
const INVALID_TYPES = ['Integer', 'Int', 'String', 'Boolean', 'True', 'Float', 'InputFile'];
let typeLeaks = [];
const checkType = (type, location) => {
  const flat = JSON.stringify(type);
  for (const bad of INVALID_TYPES) {
    if (flat.includes(`"${bad}"`)) typeLeaks.push({ where: location, found: bad, type });
  }
};
for (const model of exportData.models) {
  for (const p of model.params) checkType(p.type, `model ${model.name}.${p.name}`);
}
for (const method of exportData.methods) {
  for (const p of method.params) checkType(p.type, `method ${method.name}.${p.name}`);
  if (method.return) checkType(method.return, `method ${method.name} return`);
}
console.log(`\nType normalization leaks: ${typeLeaks.length}`);
typeLeaks.forEach(l => console.log(`  ${l.where}: found "${l.found}" in ${JSON.stringify(l.type)}`));
```

This catches cases where the scraper's `parse_types_elem` handles field/param types but `good_type` (used for return types) misses a variant. The `good_type/1` function in `lib/telegram_api_json.ex` must cover all the same normalizations.

### Fixing type leaks

If a raw type like `"Integer"` appears in the export, add the missing case to `good_type/1` in `lib/telegram_api_json.ex`:

```elixir
defp good_type(type) when is_binary(type) do
  type = type |> String.trim(".") |> String.trim(",") |> String.trim()
  case type do
    "Int" -> "int"
    "Integer" -> "int"
    "String" -> "str"
    "Boolean" -> "bool"
    "True" -> "true"
    "Float" -> "float"
    other -> other
  end
end
```

Note: `parse_types_elem` handles field/param type parsing (covers `Integer`, `String`, `Boolean`, `True`, `Float`, `Float number`, `InputFile`, `Array of X`). But `extract_return_type` uses `good_type` for normalizing return types extracted via regex — both must stay in sync.

## Fixing Issues

### Missing generic (most common issue)

If a union type was scraped as a model instead of a generic:

1. Add the type name to `@generic_types` in `lib/telegram_api_json.ex`
2. Regenerate:
   ```bash
   cd /home/rock/Git/tg/telegram_api_json
   LOG_LEVEL=error mix compile --force 2>/dev/null
   LOG_LEVEL=error mix run -e "TelegramApiJson.scrape_and_print(true)" > ./exports/tg_api_pretty.json 2>/dev/null
   LOG_LEVEL=error mix run -e "TelegramApiJson.scrape_and_print()" > ./exports/tg_api.json 2>/dev/null
   ```
3. Re-verify the fix

### Missing type or method

If something is completely absent, it likely means the scraper's heuristics failed. Check:
- Is the type name a single capitalized word? (required for model detection)
- Does the method start with a lowercase letter? (required for method detection)
- Is there an unusual HTML structure on the official page?

## Validation Script

Use this JavaScript in ctx_execute to do the full automated check (fetches from /tmp/tg_api.html which must be downloaded first):

```javascript
const fs = require('fs');
const html = fs.readFileSync('/tmp/tg_api.html', 'utf8');
const exportData = JSON.parse(fs.readFileSync('/home/rock/Git/tg/telegram_api_json/exports/tg_api_pretty.json', 'utf8'));

function extractOfficialFields(typeName) {
  const anchor = typeName.toLowerCase();
  const startIdx = html.indexOf(`name="${anchor}"`);
  if (startIdx === -1) return null;
  const nextH4 = html.indexOf('<h4', startIdx + 1);
  const sectionEnd = nextH4 !== -1 ? nextH4 : startIdx + 50000;
  const section = html.slice(startIdx, sectionEnd);
  const tableStart = section.indexOf('<table');
  if (tableStart === -1) return null;
  const tableEnd = section.indexOf('</table>', tableStart);
  if (tableEnd === -1) return null;
  const tableHtml = section.slice(tableStart, tableEnd);
  if (tableHtml.includes('<th>Field</th>')) {
    return { kind: 'type', fields: [...tableHtml.matchAll(/<tr>\s*<td>([^<]+)<\/td>/g)].map(r => r[1].trim()) };
  } else if (tableHtml.includes('<th>Parameter</th>')) {
    return { kind: 'method', fields: [...tableHtml.matchAll(/<tr>\s*<td>([^<]+)<\/td>/g)].map(r => r[1].trim()) };
  }
  return null;
}

// Check all models
let issues = [];
for (const model of exportData.models) {
  const result = extractOfficialFields(model.name);
  if (!result || result.kind !== 'type') continue;
  const exportFields = model.params.map(p => p.name);
  const missing = result.fields.filter(f => !exportFields.includes(f));
  const extra = exportFields.filter(f => !result.fields.includes(f));
  if (missing.length || extra.length) issues.push({ name: model.name, missing, extra, kind: 'model' });
}

// Check all methods
for (const method of exportData.methods) {
  const result = extractOfficialFields(method.name);
  if (!result || result.kind !== 'method') continue;
  const exportParams = method.params.map(p => p.name);
  const missing = result.fields.filter(f => !exportParams.includes(f));
  const extra = exportParams.filter(f => !result.fields.includes(f));
  if (missing.length || extra.length) issues.push({ name: method.name, missing, extra, kind: 'method' });
}

// Check for misclassified generics
const suspectGenerics = exportData.models.filter(m => 
  m.description && m.description.includes('Currently, it can be')
);

// Check for type normalization leaks
const INVALID_TYPES = ['Integer', 'Int', 'String', 'Boolean', 'True', 'Float', 'InputFile'];
let typeLeaks = [];
const checkType = (type, location) => {
  const flat = JSON.stringify(type);
  for (const bad of INVALID_TYPES) {
    if (flat.includes(`"${bad}"`)) typeLeaks.push({ where: location, found: bad, type });
  }
};
for (const model of exportData.models) {
  for (const p of model.params) checkType(p.type, `model ${model.name}.${p.name}`);
}
for (const method of exportData.methods) {
  for (const p of method.params) checkType(p.type, `method ${method.name}.${p.name}`);
  if (method.return) checkType(method.return, `method ${method.name} return`);
}

// Check completeness
const allExportNames = new Set([
  ...exportData.models.map(m => m.name.toLowerCase()),
  ...exportData.generics.map(g => g.name.toLowerCase())
]);
const exportMethodNames = new Set(exportData.methods.map(m => m.name.toLowerCase()));

const sections = [...html.matchAll(/<h4><a class="anchor" name="([^"]+)"/g)].map(m => ({ name: m[1], idx: m.index }));
let missingTypes = [], missingMethods = [];
for (let i = 0; i < sections.length; i++) {
  const start = sections[i].idx;
  const end = i + 1 < sections.length ? sections[i+1].idx : html.length;
  const content = html.slice(start, end);
  if (content.includes('<th>Parameter</th>') && content.includes('<th>Required</th>')) {
    if (!exportMethodNames.has(sections[i].name)) missingMethods.push(sections[i].name);
  } else if (content.includes('<th>Field</th>') || content.includes('Currently, it can be') || content.includes('Currently holds no information')) {
    if (!allExportNames.has(sections[i].name)) missingTypes.push(sections[i].name);
  }
}

console.log(`Models: ${exportData.models.length} | Methods: ${exportData.methods.length} | Generics: ${exportData.generics.length}`);
console.log(`\nField/param mismatches: ${issues.length}`);
issues.forEach(i => console.log(`  ${i.kind} ${i.name}: missing=[${i.missing}] extra=[${i.extra}]`));
console.log(`\nMisclassified as model (should be generic): ${suspectGenerics.length}`);
suspectGenerics.forEach(m => console.log(`  ${m.name}`));
console.log(`\nMissing from export - types: ${missingTypes.length}, methods: ${missingMethods.length}`);
if (missingTypes.length) console.log(`  Types: ${missingTypes.join(', ')}`);
if (missingMethods.length) console.log(`  Methods: ${missingMethods.join(', ')}`);
console.log(`\nType normalization leaks: ${typeLeaks.length}`);
typeLeaks.forEach(l => console.log(`  ${l.where}: found "${l.found}" in ${JSON.stringify(l.type)}`));
console.log(`\n${issues.length === 0 && suspectGenerics.length === 0 && missingTypes.length === 0 && missingMethods.length === 0 && typeLeaks.length === 0 ? '✓ ALL CHECKS PASS' : '✗ ISSUES FOUND'}`);
```

## Recent API Versions Reference

When checking, look at the "Recent changes" section of the official API page to understand what's new. Key areas to verify for each major version:
- New types/classes added
- New methods added
- New fields on existing types (especially Update, Message, ChatFullInfo, User)
- New generic/union types (these are the most error-prone — they need to be in @generic_types)
- New subtypes of existing generics
