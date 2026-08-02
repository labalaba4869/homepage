import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const source =
  "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/cards.xlsx";
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
for (const cell of ["A16", "A23", "A32", "A41", "A45"]) {
  const result = await workbook.inspect({
    kind: "computedStyle",
    sheetId: "cards",
    range: cell,
    maxChars: 3000,
  });
  console.log(result.ndjson);
}
