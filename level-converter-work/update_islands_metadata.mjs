import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = process.argv[2];
const outputPath = process.argv[3];
const previewPath = process.argv[4];
if (!inputPath || !outputPath || !previewPath) {
  throw new Error(
    "Usage: node update_islands_metadata.mjs <input.xlsx> <output.xlsx> <preview.png>",
  );
}

const workbook = await SpreadsheetFile.importXlsx(
  await FileBlob.load(inputPath),
);
const sheet = workbook.worksheets.getItem("map_islands_01");
const forestSheet = workbook.worksheets.getItem("map_forest_01");

sheet.getRange("A1").values = [["map_islands_01 · 千岛"]];
sheet.getRange("B3").values = [["islands_01"]];
sheet.getRange("D3").values = [["千岛"]];
sheet.getRange("B4").values = [["X -1344～1344"]];
sheet.getRange("D4").values = [["Y -864～864"]];
sheet.getRange("G4").values = [["map_islands_01.tscn"]];
sheet.getRange("BX9:CG10").values = Array.from(
  { length: 2 },
  () => Array(10).fill("X"),
);
forestSheet.getRange("K4:L4").values = [["默认入口", "否"]];
sheet.getRange("K4:L4").values = [["默认入口", "是"]];

const check = await workbook.inspect({
  kind: "table",
  sheetId: "map_islands_01",
  range: "A1:L8",
  include: "values,formulas",
  tableMaxRows: 8,
  tableMaxCols: 12,
  maxChars: 6000,
});
console.log(check.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(`FORMULA_ERRORS ${errors.ndjson || "none"}`);

const preview = await workbook.render({
  sheetName: "map_islands_01",
  range: "A1:L8",
  scale: 1.5,
  format: "png",
});
await fs.mkdir(path.dirname(previewPath), { recursive: true });
await fs.writeFile(
  previewPath,
  new Uint8Array(await preview.arrayBuffer()),
);

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
