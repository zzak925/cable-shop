const fs = require('fs');
const { parse } = require('pgsql-ast-parser');

const path = process.argv[2] || 'supabase/migrations/001_initial_schema.sql';
const sql = fs.readFileSync(path, 'utf8');
const sanitized = sql.replace(/as \$\$[\s\S]*?\$\$/gi, "as 'body'");

function splitStatements(input) {
  const statements = [];
  let current = '';
  let quote = null;
  for (let i = 0; i < input.length; i += 1) {
    const ch = input[i];
    const next = input[i + 1];

    if (!quote && ch === '-' && next === '-') {
      while (i < input.length && input[i] !== '\n') i += 1;
      current += '\n';
      continue;
    }

    if (!quote && ch === '/' && next === '*') {
      i += 2;
      while (i < input.length && !(input[i] === '*' && input[i + 1] === '/')) i += 1;
      i += 1;
      continue;
    }

    if (quote) {
      current += ch;
      if (ch === quote) {
        if (input[i + 1] === quote) {
          current += input[i + 1];
          i += 1;
        } else {
          quote = null;
        }
      }
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === ';') {
      const trimmed = current.trim();
      if (trimmed) statements.push(trimmed + ';');
      current = '';
      continue;
    }

    current += ch;
  }
  if (current.trim()) statements.push(current.trim());
  return statements;
}

const unsupported = [
  /^create\s+trigger\b/i,
  /^create\s+or\s+replace\s+function\b/i,
  /^begin\b/i,
  /^commit\b/i,
];

const statements = splitStatements(sanitized);
let parsed = 0;
let skipped = 0;
for (const statement of statements) {
  if (unsupported.some((regex) => regex.test(statement))) {
    skipped += 1;
    continue;
  }
  try {
    parse(statement);
    parsed += 1;
  } catch (error) {
    console.error('SQL parse check failed on statement:');
    console.error(statement.slice(0, 500));
    console.error(error.message);
    process.exit(1);
  }
}

console.log(`SQL parse check passed: ${parsed} parsed, ${skipped} skipped unsupported by lightweight parser`);
