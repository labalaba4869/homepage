import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const source = "D:/Homepage Dev/active-item-work/loot.xlsx";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
const output = `${outputDir}/loot.xlsx`;

await fs.mkdir(outputDir, { recursive: true });
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const sheet = workbook.worksheets.getItem("active_items");

const names = sheet.getRange("B4:B100").values;
const itemIndex = names.findIndex(
  ([name]) => String(name ?? "").trim() === "满溢祝福",
);
if (itemIndex < 0) {
  throw new Error("Could not find 满溢祝福");
}

const row = itemIndex + 4;
sheet.getRange(`I${row}:K${row}`).values = [[3, 1, 1]];
sheet.getRange(`I${row}:K${row}`).format.numberFormat = "0";

const inspection = await workbook.inspect({
  kind: "table",
  range: `active_items!A${row}:L${row}`,
  include: "values,formulas",
  tableMaxRows: 1,
  tableMaxCols: 12,
  maxChars: 4000,
});
console.log(inspection.ndjson);

const preview = await workbook.render({
  sheetName: "active_items",
  range: "A1:L18",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/active_items_completed.png`,
  new Uint8Array(await preview.arrayBuffer()),
);

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(output);
