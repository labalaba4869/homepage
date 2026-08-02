import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const source =
  "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/loot.xlsx";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";

await fs.mkdir(outputDir, { recursive: true });
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const result = await workbook.inspect({
  kind: "table",
  range: "active_items!A1:L100",
  include: "values,formulas",
  tableMaxRows: 100,
  tableMaxCols: 12,
  tableMaxCellChars: 240,
  maxChars: 50000,
});
console.log(result.ndjson);

const preview = await workbook.render({
  sheetName: "active_items",
  range: "A1:L30",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/active_items_current.png`,
  new Uint8Array(await preview.arrayBuffer()),
);
