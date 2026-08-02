import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "D:/Homepage Dev/staging/design_tables/xlsx/cards.xlsx";
const outputDir = "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
const previewDir = "D:/Homepage Dev/tmp/cards_workbook/after";
await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const cards = workbook.worksheets.getItem("cards");
const used = cards.getUsedRange(true);
const rowCount = used.rowCount;

cards.getRange(`L1:L${rowCount}`).copyFrom(
  cards.getRange(`K1:K${rowCount}`),
  "all",
);
cards.getRange(`M1:M${rowCount}`).copyFrom(
  cards.getRange(`K1:K${rowCount}`),
  "all",
);
cards.getRange("L1:M3").values = [
  ["buy_price", "shop_enabled"],
  ["int", "int"],
  ["商人出售该卡牌的购买价格", "商店上架开关，0关闭，1上架"],
];

const qualityValues = cards.getRange(`E4:E${rowCount}`).values;
const shopRows = qualityValues.map(([qualityRaw]) => {
  const quality = Number(qualityRaw ?? 0);
  const priceByQuality = [100, 250, 500, 1200, 3000];
  const price = priceByQuality[Math.max(0, Math.min(4, quality))];
  return [price, quality >= 2 ? 1 : 0];
});
cards.getRange(`L4:M${rowCount}`).values = shopRows;
cards.getRange(`L4:M${rowCount}`).format.numberFormat = "0";
cards.getRange(`L1:M${rowCount}`).format.wrapText = true;
cards.getRange(`L1:M${rowCount}`).format.borders = {
  preset: "all",
  style: "thin",
  color: "#B8C9BF",
};
cards.getRange("L1:M1").format = {
  fill: "#285943",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#B8C9BF" },
};
cards.getRange("L2:M2").format = {
  fill: "#DCEBE5",
  font: { bold: true, color: "#285943" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  borders: { preset: "all", style: "thin", color: "#B8C9BF" },
};
cards.getRange("L3:M3").format = {
  fill: "#FFF2CC",
  font: { italic: true, color: "#6A5A32" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "all", style: "thin", color: "#B8C9BF" },
};
const sectionFills = new Map([
  [100, "#D9D9D9"],
  [200, "#D9EFD1"],
  [500, "#C9E9F5"],
  [1000, "#EECFEF"],
  [2000, "#F7DDCF"],
]);
const cardIds = cards.getRange(`A4:A${rowCount}`).values;
cardIds.forEach(([idRaw], index) => {
  const fill = sectionFills.get(Number(idRaw));
  if (fill) cards.getRange(`L${index + 4}:M${index + 4}`).format.fill = fill;
});
cards.getRange(`L1:L${rowCount}`).format.columnWidth = 15;
cards.getRange(`M1:M${rowCount}`).format.columnWidth = 16;

const checks = await workbook.inspect({
  kind: "region",
  sheetId: "cards",
  range: `A1:M${Math.min(rowCount, 14)}`,
  include: "values,formulas",
  maxChars: 7000,
});
console.log(checks.ndjson);
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "shop columns formula error scan",
});
console.log(errors.ndjson);

for (const sheetName of ["cards", "card_equality", "deck"]) {
  const sheet = workbook.worksheets.getItem(sheetName);
  const range = sheet.getUsedRange(true).address.split("!").pop();
  const preview = await workbook.render({
    sheetName,
    range,
    scale: sheetName === "cards" ? 0.8 : 1,
    format: "png",
  });
  await fs.writeFile(
    `${previewDir}/${sheetName}.png`,
    new Uint8Array(await preview.arrayBuffer()),
  );
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(`${outputDir}/cards.xlsx`);
