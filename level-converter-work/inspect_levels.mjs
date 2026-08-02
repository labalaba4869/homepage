import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
import fs from "node:fs/promises";

const workbookPath = process.argv[2];
if (!workbookPath) {
  throw new Error("Usage: node inspect_levels.mjs <levels.xlsx>");
}

const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const sheets = await workbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 12000,
});
console.log("SHEETS");
console.log(sheets.ndjson);

for (const line of sheets.ndjson.split(/\r?\n/)) {
  if (!line.trim()) continue;
  const entry = JSON.parse(line);
  const sheetName = entry.name ?? entry.sheetName;
  if (typeof sheetName !== "string" || !sheetName.startsWith("map_")) {
    continue;
  }

  const metadata = await workbook.inspect({
    kind: "table",
    sheetId: sheetName,
    range: "A1:L8",
    include: "values,formulas",
    tableMaxRows: 8,
    tableMaxCols: 12,
    maxChars: 8000,
  });
  console.log(`MAP_METADATA ${sheetName}`);
  console.log(metadata.ndjson);

  const sheet = workbook.worksheets.getItem(sheetName);
  const usedRange = sheet.getUsedRange();
  const values = usedRange.values;
  const rowStats = [];
  const tokenCounts = new Map();
  let nonEmptyCount = 0;
  let lastValueRow = -1;
  let lastValueCol = -1;

  for (let row = 0; row < values.length; row += 1) {
    let rowCount = 0;
    for (let col = 0; col < values[row].length; col += 1) {
      const value = values[row][col];
      if (value === null || value === "") continue;
      rowCount += 1;
      nonEmptyCount += 1;
      lastValueRow = Math.max(lastValueRow, row);
      lastValueCol = Math.max(lastValueCol, col);
      if (row >= 8 && col >= 1 && typeof value === "string") {
        tokenCounts.set(value, (tokenCounts.get(value) ?? 0) + 1);
      }
    }
    if (rowCount > 0) rowStats.push([row + 1, rowCount]);
  }

  console.log(`MAP_STATS ${sheetName}`);
  console.log(JSON.stringify({
    usedRows: values.length,
    usedCols: values[0]?.length ?? 0,
    nonEmptyCount,
    lastValueRow: lastValueRow + 1,
    lastValueCol: lastValueCol + 1,
    firstRows: rowStats.slice(0, 15),
    lastRows: rowStats.slice(-15),
    commonGridValues: [...tokenCounts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 30),
  }, null, 2));

  const width = Number(values[2]?.[5] ?? 0);
  const height = Number(values[2]?.[7] ?? 0);
  const gridStartRow = 8;
  const gridStartCol = 1;
  const blanks = [];
  const boundaryIssues = [];
  const playerSpawns = [];
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const value = values[gridStartRow + y]?.[gridStartCol + x];
      const token = typeof value === "string" ? value.trim() : "";
      if (!token) blanks.push([x, y]);
      const base = token.split(";")[0];
      if ((x === 0 || y === 0 || x === width - 1 || y === height - 1) && base !== "X") {
        boundaryIssues.push([x, y, token]);
      }
      if (token.split(";").some((part) => part === "P" || part.startsWith("P:"))) {
        playerSpawns.push([x, y, token]);
      }
    }
  }
  console.log(`MAP_VALIDATION ${sheetName}`);
  console.log(JSON.stringify({
    width,
    height,
    blanks: blanks.slice(0, 100),
    blankCount: blanks.length,
    boundaryIssues: boundaryIssues.slice(0, 100),
    boundaryIssueCount: boundaryIssues.length,
    playerSpawns,
  }, null, 2));

  if (process.argv.includes("--render") && sheetName === "map_islands_01") {
    const preview = await workbook.render({
      sheetName,
      range: "A1:CF368",
      scale: 0.25,
      format: "png",
    });
    await fs.writeFile(
      "map_islands_01_overview.png",
      new Uint8Array(await preview.arrayBuffer()),
    );
  }
}
