import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
const workbookPath = `${outputDir}/loot.xlsx`;

const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const sheet = workbook.worksheets.getItem("active_items");

const before = await workbook.inspect({
  kind: "table",
  range: "active_items!A1:L18",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 12,
  maxChars: 16000,
});
await fs.writeFile(`${outputDir}/active_icon_paths_before.ndjson`, before.ndjson);

const beforePreview = await workbook.render({
  sheetName: "active_items",
  range: "A1:L18",
  scale: 1.5,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/active_icon_paths_before.png`,
  new Uint8Array(await beforePreview.arrayBuffer()),
);

const iconPaths = Array.from({ length: 15 }, (_, index) => [
  `res://assets/art/items/icons/active/active_item_${10000 + index}.png`,
]);
sheet.getRange("L4:L18").values = iconPaths;

const after = await workbook.inspect({
  kind: "table",
  range: "active_items!A1:L18",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 12,
  maxChars: 16000,
});
await fs.writeFile(`${outputDir}/active_icon_paths_after.ndjson`, after.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "active item icon path error scan",
});
await fs.writeFile(`${outputDir}/active_icon_paths_errors.ndjson`, errors.ndjson);

const afterPreview = await workbook.render({
  sheetName: "active_items",
  range: "A1:L18",
  scale: 1.5,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/active_icon_paths_after.png`,
  new Uint8Array(await afterPreview.arrayBuffer()),
);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(workbookPath);

console.log("UPDATED_ACTIVE_ICON_PATHS");
console.log(after.ndjson);
