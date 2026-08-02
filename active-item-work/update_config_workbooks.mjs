import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workDir = "D:/Homepage Dev/active-item-work";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
await fs.mkdir(outputDir, { recursive: true });

const loot = await SpreadsheetFile.importXlsx(
  await FileBlob.load(`${workDir}/loot.xlsx`),
);
const lootGroups = loot.worksheets.getItem("loot_groups");
for (const column of ["J", "K", "L"]) {
  lootGroups.getRange(`${column}1:${column}5`).copyFrom(
    lootGroups.getRange("I1:I5"),
    "all",
  );
}
lootGroups.getRange("J1:L5").values = [
  ["normal_item_chance", "active_item_chance", "card_chance"],
  ["float", "float", "float"],
  [
    "普通物品类别概率%，三类总和必须为100",
    "主动道具类别概率%，无候选时在其他可用类别中重抽",
    "卡牌类别概率%，英雄卡和功能卡均参与",
  ],
  [60, 20, 20],
  [60, 20, 20],
];
lootGroups.getRange("J1:L1").format = {
  fill: "#16483E",
  font: { bold: true, color: "#FFF0C2" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
lootGroups.getRange("J2:L2").format = {
  fill: "#2A5D70",
  font: { color: "#E8F4EE" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
lootGroups.getRange("J3:L3").format = {
  fill: "#596B3C",
  font: { color: "#F3F1D7" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
};
lootGroups.getRange("J4:L5").format = {
  fill: "#F4F8F6",
  font: { color: "#25332D" },
  horizontalAlignment: "right",
  verticalAlignment: "center",
  numberFormat: "0",
  borders: {
    bottom: { style: "thin", color: "#A9BEB4" },
  },
};
lootGroups.getRange("J1:L5").format.columnWidth = 25;
lootGroups.getRange("J3:L3").format.rowHeight = 42;

const actors = await SpreadsheetFile.importXlsx(
  await FileBlob.load(`${workDir}/actors.xlsx`),
);
const playerNpc = actors.worksheets.getItem("player_npc");
const initialIds = String(playerNpc.getRange("J4").values[0][0] ?? "");
if (initialIds !== "10001;2") {
  throw new Error(`Unexpected player initial_item_ids: ${initialIds}`);
}
playerNpc.getRange("J4").values = [["10000;2"]];

const cards = await SpreadsheetFile.importXlsx(
  await FileBlob.load(`${workDir}/cards.xlsx`),
);
const cardSheet = cards.worksheets.getItem("cards");
const cardHeader = cardSheet.getRange("K1").values[0][0];
if (cardHeader !== "card_drop_weight") {
  throw new Error(`Missing card_drop_weight column, found: ${cardHeader}`);
}

const lootInspect = await loot.inspect({
  kind: "table",
  range: "loot_groups!A1:L5",
  include: "values,formulas",
  tableMaxRows: 5,
  tableMaxCols: 12,
  maxChars: 8000,
});
console.log(lootInspect.ndjson);
const actorInspect = await actors.inspect({
  kind: "table",
  range: "player_npc!A1:K6",
  include: "values,formulas",
  tableMaxRows: 6,
  tableMaxCols: 11,
  maxChars: 6000,
});
console.log(actorInspect.ndjson);

const lootPreview = await loot.render({
  sheetName: "loot_groups",
  range: "A1:L6",
  scale: 1.25,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/loot_groups_after.png`,
  new Uint8Array(await lootPreview.arrayBuffer()),
);
const actorPreview = await actors.render({
  sheetName: "player_npc",
  range: "A1:K7",
  scale: 1.25,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/actors_after_active_id.png`,
  new Uint8Array(await actorPreview.arrayBuffer()),
);

for (const [name, workbook] of [
  ["loot.xlsx", loot],
  ["actors.xlsx", actors],
  ["cards.xlsx", cards],
]) {
  const exported = await SpreadsheetFile.exportXlsx(workbook);
  await exported.save(`${outputDir}/${name}`);
}
