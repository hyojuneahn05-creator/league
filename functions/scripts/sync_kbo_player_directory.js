const fs = require("fs");
const path = require("path");

const sourcePath = path.resolve(
  __dirname,
  "..",
  "..",
  "docs",
  "kbo_players_season_2026.txt",
);
const destinationPath = path.resolve(
  __dirname,
  "..",
  "kbo_players_season_2026.txt",
);

if (!fs.existsSync(sourcePath)) {
  console.error(`KBO directory source not found: ${sourcePath}`);
  process.exit(1);
}

fs.mkdirSync(path.dirname(destinationPath), {recursive: true});
fs.copyFileSync(sourcePath, destinationPath);
console.log(
  `Synced KBO player directory:\n- source: ${sourcePath}\n- destination: ${destinationPath}`,
);
