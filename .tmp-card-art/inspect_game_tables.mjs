import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

for (const filename of ["cards.xlsx", "actors.xlsx"]) {
  const path =
    `D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/${filename}`;
  const input = await FileBlob.load(path);
  const workbook = await SpreadsheetFile.importXlsx(input);
  const overview = await workbook.inspect({
    kind: "sheet,table",
    maxChars: 20000,
    tableMaxRows: 80,
    tableMaxCols: 16,
    tableMaxCellChars: 160,
  });
  console.log(`===== ${filename} =====`);
  console.log(overview.ndjson);
}
