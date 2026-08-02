import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workDir = "D:/Homepage Dev/staging/spreadsheet_edit";
const inputPath = `${workDir}/loot.xlsx`;
const outputPath = `${workDir}/loot_updated.xlsx`;

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const sheet = workbook.worksheets.getItem("loot_groups");
const initial = await workbook.inspect({
  kind: "table",
  sheetId: "loot_groups",
  range: "A1:L12",
  include: "values,formulas",
  tableMaxRows: 12,
  tableMaxCols: 12,
  maxChars: 6000,
});
console.log(initial.ndjson);

const used = sheet.getUsedRange(true);
const rows = used.values;
const ids = new Set();
for (let row = 3; row < rows.length; row += 1) {
  const id = Number(rows[row]?.[0]);
  if (Number.isFinite(id) && id > 0) ids.add(id);
}
if (ids.has(3) || ids.has(4)) {
  throw new Error("loot_groups already contains ID 3 or 4; stop to avoid overwriting planner data.");
}

const startRow = rows.length + 1;
sheet.getRange(`A4:L4`).copyTo(sheet.getRange(`A${startRow}:L${startRow}`), "all");
sheet.getRange(`A4:L4`).copyTo(sheet.getRange(`A${startRow + 1}:L${startRow + 1}`), "all");
sheet.getRange(`A${startRow}:L${startRow + 1}`).values = [
  [3, "废弃小营地", 4, 75, 65, 25, 8, 1, 1, 60, 20, 20],
  [4, "残破储物箱", 6, 85, 45, 32, 16, 5, 2, 60, 20, 20],
];

const verification = await workbook.inspect({
  kind: "table",
  sheetId: "loot_groups",
  range: `A${startRow}:L${startRow + 1}`,
  include: "values,formulas",
  tableMaxRows: 4,
  tableMaxCols: 12,
  maxChars: 3000,
});
console.log(verification.ndjson);

const preview = await workbook.render({
  sheetName: "loot_groups",
  range: `A1:L${startRow + 1}`,
  scale: 1.4,
  format: "png",
});
await fs.writeFile(`${workDir}/loot_groups_preview.png`, new Uint8Array(await preview.arrayBuffer()));

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
