import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const source =
  "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/cards.xlsx";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";

await fs.mkdir(outputDir, { recursive: true });
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const preview = await workbook.render({
  sheetName: "cards",
  range: "A1:J47",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/cards_before_weight.png`,
  new Uint8Array(await preview.arrayBuffer()),
);
