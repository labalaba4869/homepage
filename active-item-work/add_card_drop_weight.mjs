import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const source =
  "D:/GameDevelop/Godot/card-search-and-attack/design_tables/xlsx/cards.xlsx";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
const outputPath = `${outputDir}/cards.xlsx`;

await fs.mkdir(outputDir, { recursive: true });
const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(source));
const sheet = workbook.worksheets.getItem("cards");

sheet.getRange("K1:K47").copyFrom(sheet.getRange("J1:J47"), "all");
sheet.getRange("K1:K3").values = [
  ["card_drop_weight"],
  ["float"],
  ["同品质卡牌候选池中的相对掉落权重，当前统一为100"],
];
sheet.getRange("K4:K47").values = Array.from({ length: 44 }, () => [100]);
sheet.getRange("K1:K47").format.columnWidth = 24;
sheet.getRange("K1").format = {
  fill: "#285943",
  font: { bold: true, color: "#FFFFFF", fontSize: 11 },
  borders: { preset: "all", style: "thin", color: "#B8C9BF" },
  wrapText: true,
  horizontalAlignment: "center",
};
sheet.getRange("K2").format = {
  fill: "#DCE9E2",
  font: { bold: true, color: "#285943", fontSize: 10 },
  borders: { preset: "all", style: "thin", color: "#B8C9BF" },
  horizontalAlignment: "center",
};
sheet.getRange("K3").format = {
  fill: "#FFF1C7",
  font: { italic: true, color: "#5A4720", fontSize: 10 },
  borders: { preset: "all", style: "thin", color: "#D9CCAA" },
  wrapText: true,
  horizontalAlignment: "center",
};
sheet.getRange("K4:K47").format = {
  fill: "#F7FAF8",
  font: { color: "#1F2D26", fontSize: 11 },
  borders: { preset: "all", style: "thin", color: "#DCE5DF" },
  horizontalAlignment: "center",
};
for (const [row, color] of [
  [16, "#E7E6E6"],
  [23, "#E2F0D9"],
  [32, "#DDEBF7"],
  [41, "#F4D7F0"],
  [45, "#FCE4D6"],
]) {
  sheet.getRange(`K${row}`).format.fill = color;
}

const check = await workbook.inspect({
  kind: "table",
  range: "cards!A1:K47",
  include: "values,formulas",
  tableMaxRows: 47,
  tableMaxCols: 11,
  tableMaxCellChars: 120,
  maxChars: 40000,
});
console.log(check.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const preview = await workbook.render({
  sheetName: "cards",
  range: "A1:K47",
  scale: 1,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/cards_after_weight.png`,
  new Uint8Array(await preview.arrayBuffer()),
);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(`Saved ${outputPath}`);
