import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "D:/Homepage Dev/staging/design_tables/xlsx/cards.xlsx";
const outputDir = "D:/Homepage Dev/tmp/cards_workbook";
await fs.mkdir(outputDir, { recursive: true });
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const summary = await workbook.inspect({
  kind: "sheet,region,computedStyle",
  sheetId: "cards",
  range: "A1:K12",
  include: "values,formulas",
  maxChars: 8000,
});
console.log(summary.ndjson);
const preview = await workbook.render({
  sheetName: "cards",
  range: "A1:K12",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/cards-before.png`,
  new Uint8Array(await preview.arrayBuffer()),
);
