import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workDir = "D:/Homepage Dev/active-item-work";
const outputDir =
  "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
await fs.mkdir(outputDir, { recursive: true });

const loot = await SpreadsheetFile.importXlsx(
  await FileBlob.load(`${workDir}/loot.xlsx`),
);
const actors = await SpreadsheetFile.importXlsx(
  await FileBlob.load(`${workDir}/actors.xlsx`),
);

const lootPreview = await loot.render({
  sheetName: "loot_groups",
  range: "A1:L12",
  scale: 1.5,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/loot_groups_before.png`,
  new Uint8Array(await lootPreview.arrayBuffer()),
);

const actorPreview = await actors.render({
  sheetName: "player_npc",
  range: "A1:K8",
  scale: 1.5,
  format: "png",
});
await fs.writeFile(
  `${outputDir}/actors_before_active_id.png`,
  new Uint8Array(await actorPreview.arrayBuffer()),
);
