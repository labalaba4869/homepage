import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbook = await SpreadsheetFile.importXlsx(
  await FileBlob.load(
    "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/levels.xlsx",
  ),
);
workbook.worksheets.getItem("map_islands_01").getRange("B9").values = [[""]];
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save("D:/Homepage Dev/level-converter-work/invalid_levels.xlsx");
