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
const ids = [];
let nextId = 10000;
for (const [name] of names) {
  if (name === null || String(name).trim() === "") {
    break;
  }
  ids.push([nextId]);
  nextId += 1;
}

if (ids.length !== 15) {
  throw new Error(`Expected 15 active items, found ${ids.length}`);
}

sheet.getRange(`A4:A${ids.length + 3}`).values = ids;
sheet.getRange(`A4:A${ids.length + 3}`).format.numberFormat = "0";

const inspection = await workbook.inspect({
  kind: "table",
  range: `active_items!A1:L${ids.length + 3}`,
  include: "values,formulas",
  tableMaxRows: ids.length + 3,
  tableMaxCols: 12,
  tableMaxCellChars: 180,
  maxChars: 24000,
});
console.log(inspection.ndjson);

const preview = await workbook.render({
  sheetName: "active_items",
  range: `A1:L${ids.length + 3}`,
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/active_items_renumbered.png`,
  new Uint8Array(await preview.arrayBuffer()),
);

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(output);
console.log(JSON.stringify({ output, firstId: ids[0][0], lastId: ids.at(-1)[0] }));
