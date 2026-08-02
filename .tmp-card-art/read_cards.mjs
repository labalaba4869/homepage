import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbookPath =
  "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/cards.xlsx";
const outputPath = "D:/Homepage Dev/.tmp-card-art/cards.json";

const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const overview = await workbook.inspect({
  kind: "sheet,table",
  maxChars: 3000,
  tableMaxRows: 4,
  tableMaxCols: 10,
});
const sheet = workbook.worksheets.getItem("cards");
const rows = sheet.getRange("A1:J40").values;

const headers = rows[0];
const data = rows
  .slice(3)
  .filter((row) => row[0] !== null && row[0] !== "")
  .map((row) =>
    Object.fromEntries(headers.map((header, index) => [header, row[index]])),
  );
const characters = data.filter((row) => row.card_type === "battle_hero");

await fs.writeFile(outputPath, JSON.stringify(characters, null, 2), "utf8");
console.log(overview.ndjson);
console.log(JSON.stringify({ count: characters.length, outputPath }));
