import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const workDir = "D:/Homepage Dev/level-editor-work";
const outputDir = "D:/Homepage Dev/outputs/019f3c7c-aeac-7840-9ff6-2c55ff7c97eb";
const projectRoot = "D:/GameDevelop/Godot/card-search-and-attack";
const finalPath = `${outputDir}/levels.xlsx`;

const colors = {
  ink: "#203129",
  muted: "#60736A",
  header: "#315C46",
  headerDark: "#203E31",
  pale: "#EAF2EC",
  line: "#B8C8BE",
  grass: "#73A665",
  road: "#B88455",
  water: "#4D91B0",
  bridge: "#C69A5D",
  boundary: "#773D3D",
  regionBoundary: "#70452F",
  tree: "#356B42",
  bush: "#4B8764",
  grassDetail: "#8ABA72",
  house: "#776757",
  player: "#F0CF5B",
  chest: "#E49B45",
  normal: "#D96D58",
  elite: "#A76CC4",
  boss: "#E2B64A",
};

const workbook = Workbook.create();
buildGuideSheet(workbook.worksheets.add("填写规范"));
await buildLegendSheet(workbook.worksheets.add("图例"));
buildMapSheet(workbook.worksheets.add("map_forest_01"));

await fs.mkdir(outputDir, { recursive: true });
const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(finalPath);

const inspect = await workbook.inspect({
  kind: "workbook,sheet,formula",
  maxChars: 8000,
  tableMaxRows: 8,
  tableMaxCols: 12,
  options: { maxResults: 100 },
});
console.log(inspect.ndjson);

const errorScan = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errorScan.ndjson);

for (const [sheetName, range, fileName, scale] of [
  ["填写规范", "A1:H47", "guide.png", 1.2],
  ["图例", "A1:R22", "legend.png", 1.0],
  ["map_forest_01", "A1:AW40", "map_forest_01.png", 0.8],
]) {
  const preview = await workbook.render({
    sheetName,
    range,
    scale,
    format: "png",
  });
  await fs.writeFile(
    path.join(workDir, "previews", fileName),
    new Uint8Array(await preview.arrayBuffer()),
  );
}

console.log(`LEVELS_WORKBOOK_OK ${finalPath}`);

function buildGuideSheet(sheet) {
  sheet.showGridLines = false;
  sheet.mergeCells("A1:H1");
  sheet.getRange("A1").values = [["Excel 关卡制作规范"]];
  sheet.getRange("A1:H1").format = {
    fill: colors.headerDark,
    font: { bold: true, color: "#FFFFFF", size: 20 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
  };
  sheet.getRange("A1:H1").format.rowHeight = 38;

  sheet.mergeCells("A2:H2");
  sheet.getRange("A2").values = [[
    "每格固定为 32×32 px；填写地图代码后打表工具生成 Godot 4.7 场景。",
  ]];
  sheet.getRange("A2:H2").format = {
    fill: colors.pale,
    font: { color: colors.ink, italic: true },
    horizontalAlignment: "center",
  };

  section(sheet, 4, "1. 工作簿结构");
  rows(sheet, 5, [
    ["工作表", "用途", "是否由转换工具读取", "说明"],
    ["填写规范", "编辑规则", "否", "本页"],
    ["图例", "代码、资源、缩放与占格", "是", "资源变化会触发相关地图重建"],
    ["map_<地图ID>", "一张地图", "是", "复制现有地图子表后修改"],
  ], "A", "D");

  section(sheet, 10, "2. 地图固定配置");
  rows(sheet, 11, [
    ["单元格", "字段", "示例", "规则"],
    ["B3", "map_id", "forest_01", "稳定且唯一，不使用中文或空格"],
    ["D3", "map_name", "苔木渡口", "玩家可见名称"],
    ["F3", "width", 48, "地图宽度，单位为格"],
    ["H3", "height", 32, "地图高度，单位为格"],
    ["J3", "cell_size", 32, "固定为32"],
    ["L3", "default_terrain", "G", "模板内部默认草地"],
    ["B9", "grid_origin", "左上角", "有效网格由width和height确定"],
  ], "A", "D");

  section(sheet, 20, "3. 填写语法");
  rows(sheet, 21, [
    ["示例", "含义", "备注", "像素换算"],
    ["G;P:R", "草地 + 玩家出生，朝右", "全图必须且只能有一个P", "格中心坐标"],
    ["R;C:1", "道路 + 掉落组1宝箱", "C后填写loot_group_id", "1格"],
    ["G;N:1:LR:3:72", "普通怪1，左右巡逻", "方向/半径/速度可省略", "半径3格=96px"],
    ["G;E:1000:DU:2:56", "精英怪，初始向上", "DU表示上下巡逻", "半径2格=64px"],
    ["G;BO:2000:NONE:0:0", "静止Boss", "NONE表示不巡逻", "速度0"],
    ["G;RB", "草地上的区域栅栏", "相邻RB自动连接", "1格"],
  ], "A", "D");

  section(sheet, 30, "4. 多格素材");
  sheet.getRange("A31:D31").values = [["2×2素材", "第1列", "第2列", "说明"]];
  sheet.getRange("A32:D33").values = [
    ["第1行", "G;H1@", "G;H1", "@只放在左上角主格"],
    ["第2行", "G;H1", "G;H1", "其余格使用同代码"],
  ];
  tableStyle(sheet.getRange("A31:D33"));
  sheet.getRange("B32:C33").format = {
    fill: colors.house,
    font: { bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    borders: { preset: "all", style: "thin", color: "#DDD2C7" },
  };

  section(sheet, 36, "5. 边界、刷新与增量");
  const notes = [
    "地图有效范围内不得留空，模板内部预填G，最外圈必须闭合为X。",
    "X是地图外边界；RB是地图内部可见木质栅栏边界。",
    "本次地图停留期间宝箱和死亡敌人不刷新；离开再进入后恢复初始状态。",
    "转换工具按地图子表哈希跳过未变化地图，并报告变化单元格。",
    "变化地图完整重建 generated 场景；外层包装场景和 ManualOverrides 不重写。",
    "手工节点只能放在外层场景的 ManualOverrides 下。",
  ];
  notes.forEach((note, index) => {
    const row = 37 + index;
    sheet.mergeCells(`A${row}:H${row}`);
    sheet.getRange(`A${row}`).values = [[`${index + 1}. ${note}`]];
    sheet.getRange(`A${row}:H${row}`).format = {
      fill: index % 2 === 0 ? "#F4F7F5" : "#FFFFFF",
      font: { color: colors.ink },
      wrapText: true,
      verticalAlignment: "center",
    };
    sheet.getRange(`A${row}:H${row}`).format.rowHeight = 26;
  });

  section(sheet, 44, "6. 输出场景结构");
  sheet.mergeCells("A45:H47");
  sheet.getRange("A45").values = [[
    "自动生成：scenes/maps/generated/map_<map_id>_generated.tscn\n" +
      "首次创建：scenes/maps/map_<map_id>.tscn\n" +
      "外层场景实例化生成地图，并保留 ManualOverrides 节点。",
  ]];
  sheet.getRange("A45:H47").format = {
    fill: "#EEF4F0",
    font: { color: colors.ink },
    wrapText: true,
    verticalAlignment: "center",
    borders: { preset: "outside", style: "medium", color: colors.header },
  };

  sheet.getRange("A1:H47").format.font.name = "Microsoft YaHei";
  sheet.getRange("A1:H47").format.font.size = 10;
  sheet.getRange("A:A").format.columnWidthPx = 120;
  sheet.getRange("B:B").format.columnWidthPx = 170;
  sheet.getRange("C:C").format.columnWidthPx = 150;
  sheet.getRange("D:D").format.columnWidthPx = 250;
  sheet.getRange("E:H").format.columnWidthPx = 82;
  sheet.freezePanes.freezeRows(2);
}

async function buildLegendSheet(sheet) {
  sheet.showGridLines = false;
  sheet.mergeCells("A1:R1");
  sheet.getRange("A1").values = [["关卡图例与素材尺寸"]];
  sheet.getRange("A1:R1").format = {
    fill: colors.headerDark,
    font: { bold: true, color: "#FFFFFF", size: 20 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
  };
  sheet.getRange("A1:R1").format.rowHeight = 38;
  sheet.mergeCells("A2:R2");
  sheet.getRange("A2").values = [[
    "黄色列为策划可编辑项；显示尺寸和最终占格由公式计算。地形会自动铺满32px逻辑格。",
  ]];
  sheet.getRange("A2:R2").format = {
    fill: "#FFF4CC",
    font: { color: "#5A4A1F" },
    horizontalAlignment: "center",
  };

  const headers = [
    "代码", "分类", "名称", "素材预览", "资源路径", "原始宽", "原始高",
    "显示缩放", "显示宽", "显示高", "自动占格宽", "自动占格高",
    "覆盖占格宽", "覆盖占格高", "最终占格宽", "最终占格高", "通行性", "说明",
  ];
  sheet.getRange("A4:R4").values = [headers];
  sheet.getRange("A4:R4").format = {
    fill: colors.header,
    font: { bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: "#B8C8BE" },
  };
  sheet.getRange("A4:R4").format.rowHeight = 32;

  const legend = [
    ["G", "基础地形", "草地", "assets/art/scene/world/grass_background.png", 64, 64, 0.5, null, null, "可通行", "地形自动铺满1格"],
    ["R", "基础地形", "泥土道路", "assets/art/scene/world/dirt_tileset.png", 16, 16, 1, null, null, "可通行", "自动选择道路边缘图块"],
    ["W", "基础地形", "河流", "assets/art/scene/tileset/tileset_spring.png", 32, 32, 1, null, null, "不可通行", "连续水域自动生成碰撞"],
    ["BR", "基础地形", "桥梁", "assets/art/scene/world/road.png", 32, 32, 1, null, null, "可通行", "覆盖河流碰撞"],
    ["X", "基础地形", "地图外边界", "", 32, 32, 1, null, null, "不可通行", "外圈必须闭合"],
    ["RB", "区域边界", "木质栅栏", "assets/art/scene/world/fences.png", 16, 16, 2, null, null, "不可通行", "按相邻RB自动连接"],
    ["T", "环境物件", "树木", "assets/art/scene/world/tree.png", 32, 48, 2, null, null, "不可通行", "最终占2×3格"],
    ["BU", "环境物件", "灌木", "assets/art/scene/world/bush.png", 32, 32, 2, null, null, "可通行", "最终占2×2格"],
    ["GT", "环境物件", "草丛装饰", "assets/art/scene/world/grass.png", 32, 32, 2, null, null, "可通行", "最终占2×2格"],
    ["H1", "环境物件", "西侧房屋", "assets/art/scene/world/house.png", 80, 96, 2, null, null, "不可通行", "最终占5×6格"],
    ["H2", "环境物件", "东侧房屋", "assets/art/scene/world/house.png", 80, 112, 2, null, null, "不可通行", "最终占5×7格"],
    ["P", "玩法对象", "玩家出生点", "assets/art/character/animals/marker.png", 64, 64, 2, 1, 1, "占位1格", "P:U/D/L/R；透明帧使用占格覆盖"],
    ["C", "玩法对象", "宝箱", "assets/art/scene/world/chest.png", 16, 16, 2, null, null, "阻挡24×16px", "C:<loot_group_id>"],
    ["N", "玩法对象", "普通怪（蝙蝠示例）", "assets/art/character/animals/bat.png", 16, 24, 2, null, null, "动态", "实际尺寸由enemy_id对应资源决定"],
    ["E", "玩法对象", "精英怪（公牛示例）", "assets/art/character/animals/male_cow_brown.png", 32, 32, 2, null, null, "动态", "实际尺寸由enemy_id对应资源决定"],
    ["BO", "玩法对象", "Boss（公牛示例）", "assets/art/character/animals/male_cow_brown.png", 32, 32, 2, null, null, "动态", "实际尺寸由enemy_id对应资源决定"],
  ];

  const values = legend.map((row) => [
    row[0], row[1], row[2], "", `res://${row[3]}`, row[4], row[5], row[6],
    null, null, null, null, row[7], row[8], null, null, row[9], row[10],
  ]);
  sheet.getRange(`A5:R${4 + values.length}`).values = values;
  const body = sheet.getRange(`A5:R${4 + values.length}`);
  body.format = {
    font: { color: colors.ink, size: 9 },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: "#D2DDD6" },
  };
  sheet.getRange(`A5:C${4 + values.length}`).format.horizontalAlignment = "center";
  sheet.getRange(`F5:Q${4 + values.length}`).format.horizontalAlignment = "center";
  sheet.getRange(`H5:H${4 + values.length}`).format.fill = "#FFF0B8";
  sheet.getRange(`M5:N${4 + values.length}`).format.fill = "#FFF0B8";
  sheet.getRange(`I5:L${4 + values.length}`).format.fill = "#EDF4EF";
  sheet.getRange(`O5:P${4 + values.length}`).format.fill = "#DDECE2";

  for (let i = 0; i < values.length; i += 1) {
    const row = 5 + i;
    sheet.getRange(`I${row}`).formulas = [[`=F${row}*H${row}`]];
    sheet.getRange(`J${row}`).formulas = [[`=G${row}*H${row}`]];
    sheet.getRange(`K${row}`).formulas = [[`=ROUNDUP(I${row}/32,0)`]];
    sheet.getRange(`L${row}`).formulas = [[`=ROUNDUP(J${row}/32,0)`]];
    sheet.getRange(`O${row}`).formulas = [[`=IF(M${row}="",K${row},M${row})`]];
    sheet.getRange(`P${row}`).formulas = [[`=IF(N${row}="",L${row},N${row})`]];
    sheet.getRange(`A${row}:R${row}`).format.rowHeight = 72;
  }
  sheet.getRange(`F5:P${4 + values.length}`).format.numberFormat = "0.##";

  const codeFills = {
    G: colors.grass, R: colors.road, W: colors.water, BR: colors.bridge,
    X: colors.boundary, RB: colors.regionBoundary, T: colors.tree,
    BU: colors.bush, GT: colors.grassDetail, H1: colors.house, H2: colors.house,
    P: colors.player, C: colors.chest, N: colors.normal, E: colors.elite, BO: colors.boss,
  };
  legend.forEach((row, index) => {
    const excelRow = 5 + index;
    const fill = codeFills[row[0]];
    sheet.getRange(`A${excelRow}:C${excelRow}`).format.fill = fill;
    sheet.getRange(`A${excelRow}:C${excelRow}`).format.font = {
      bold: true,
      color: ["G", "R", "W", "BR", "P", "C", "E", "BO"].includes(row[0]) ? colors.ink : "#FFFFFF",
    };
  });

  for (let i = 0; i < legend.length; i += 1) {
    const assetRel = legend[i][3];
    if (!assetRel) continue;
    const assetPath = `${projectRoot}/${assetRel}`;
    try {
      const bytes = await fs.readFile(assetPath);
      const dataUrl = `data:image/png;base64,${bytes.toString("base64")}`;
      sheet.images.add({
        dataUrl,
        anchor: {
          from: { row: 4 + i, col: 3, rowOffsetPx: 6, colOffsetPx: 8 },
          extent: { widthPx: 58, heightPx: 58 },
        },
      });
    } catch {
      // Procedural or optional preview: the colored code cells remain the visual legend.
    }
  }

  const widths = [46, 74, 118, 78, 280, 58, 58, 68, 62, 62, 72, 72, 72, 72, 72, 72, 92, 250];
  widths.forEach((width, index) => {
    sheet.getRange(`${columnName(index + 1)}:${columnName(index + 1)}`).format.columnWidthPx = width;
  });
  sheet.getRange("A1:R22").format.font.name = "Microsoft YaHei";
  sheet.freezePanes.freezeRows(4);
}

function buildMapSheet(sheet) {
  const width = 48;
  const height = 32;
  const grid = createForestMap(width, height);
  sheet.showGridLines = false;

  sheet.mergeCells("A1:AW1");
  sheet.getRange("A1").values = [["map_forest_01 · 苔木渡口"]];
  sheet.getRange("A1:AW1").format = {
    fill: colors.headerDark,
    font: { bold: true, color: "#FFFFFF", size: 18 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
  };
  sheet.getRange("A1:AW1").format.rowHeight = 36;

  sheet.getRange("A3:L3").values = [[
    "map_id", "forest_01", "map_name", "苔木渡口", "width", width,
    "height", height, "cell_size", 32, "default_terrain", "G",
  ]];
  sheet.getRange("A3:L3").format = {
    borders: { preset: "all", style: "thin", color: colors.line },
    verticalAlignment: "center",
    horizontalAlignment: "center",
  };
  for (const cell of ["A3", "C3", "E3", "G3", "I3", "K3"]) {
    sheet.getRange(cell).format = {
      fill: colors.header,
      font: { bold: true, color: "#FFFFFF" },
      horizontalAlignment: "center",
    };
  }
  for (const cell of ["B3", "D3", "F3", "H3", "J3", "L3"]) {
    sheet.getRange(cell).format.fill = "#FFF0B8";
  }
  sheet.getRange("A4:L4").values = [[
    "Godot范围", "X -768～768", "", "Y -512～512", "", "场景", "map_forest_01.tscn", "", "增量单位", "地图子表", "", "",
  ]];
  sheet.getRange("A4:L4").format = {
    fill: "#EFF5F1",
    font: { color: colors.muted, size: 9 },
    horizontalAlignment: "center",
  };
  sheet.mergeCells("A6:AW6");
  sheet.getRange("A6").values = [[
    "编辑提示：有效范围不得留空；外圈保持X；多格素材左上角代码末尾加@。完整规则见“填写规范”和“图例”。",
  ]];
  sheet.getRange("A6:AW6").format = {
    fill: "#FFF4CC",
    font: { color: "#5A4A1F", italic: true },
    horizontalAlignment: "center",
  };

  const headerValues = [["行/列", ...Array.from({ length: width }, (_, i) => i)]];
  sheet.getRange("A8:AW8").values = headerValues;
  sheet.getRange("A8:AW8").format = {
    fill: colors.header,
    font: { bold: true, color: "#FFFFFF", size: 8 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    borders: { preset: "all", style: "thin", color: "#A9BBAF" },
  };
  const mapValues = grid.map((row, index) => [index, ...row]);
  sheet.getRange("A9:AW40").values = mapValues;
  sheet.getRange("A9:A40").format = {
    fill: colors.header,
    font: { bold: true, color: "#FFFFFF", size: 8 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    borders: { preset: "all", style: "thin", color: "#A9BBAF" },
  };
  const gridRange = sheet.getRange("B9:AW40");
  gridRange.format = {
    fill: colors.grass,
    font: { bold: true, color: "#18331E", size: 7 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: "#C9D7CC" },
  };

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const cell = sheet.getCell(8 + y, 1 + x);
      styleMapCell(cell, grid[y][x]);
    }
  }

  addMapConditionalFormats(gridRange);
  sheet.getRange("A:A").format.columnWidthPx = 44;
  for (let col = 2; col <= 49; col += 1) {
    sheet.getRange(`${columnName(col)}:${columnName(col)}`).format.columnWidthPx = 32;
  }
  sheet.getRange("8:8").format.rowHeightPx = 24;
  sheet.getRange("9:40").format.rowHeightPx = 32;
  sheet.getRange("A1:AW40").format.font.name = "Microsoft YaHei";
  sheet.freezePanes.freezeRows(8);
  sheet.freezePanes.freezeColumns(1);
}

function createForestMap(width, height) {
  const grid = Array.from({ length: height }, () => Array(width).fill("G"));

  for (let x = 0; x < width; x += 1) {
    grid[0][x] = "X";
    grid[height - 1][x] = "X";
  }
  for (let y = 0; y < height; y += 1) {
    grid[y][0] = "X";
    grid[y][width - 1] = "X";
  }

  for (let y = 1; y < height - 1; y += 1) {
    const left = y < 8 ? 27 : y < 16 ? 26 : y < 24 ? 27 : 26;
    for (let x = left; x < left + 6; x += 1) grid[y][x] = "W";
  }
  for (let y = 19; y <= 21; y += 1) {
    for (let x = 1; x < width - 1; x += 1) {
      grid[y][x] = grid[y][x] === "W" ? "BR" : "R";
    }
  }
  for (let y = 7; y <= 18; y += 1) {
    for (let x = 10; x <= 12; x += 1) grid[y][x] = "R";
  }
  for (let y = 8; y <= 18; y += 1) {
    for (let x = 38; x <= 40; x += 1) grid[y][x] = "R";
  }

  placeFootprint(grid, 8, 3, 5, 6, "H1");
  placeFootprint(grid, 36, 3, 5, 7, "H2");

  const trees = [
    [1, 1], [4, 1], [14, 1], [17, 1], [20, 1], [23, 1], [42, 1],
    [1, 5], [1, 9], [1, 13], [44, 5], [44, 10], [44, 14],
    [1, 28], [4, 28], [7, 28], [24, 28], [29, 28], [33, 28], [36, 28], [39, 28],
  ];
  trees.forEach(([x, y]) => placeFootprint(grid, x, y, 2, 3, "T"));

  const bushes = [[5, 11], [15, 7], [21, 14], [34, 12], [42, 17], [3, 24]];
  bushes.forEach(([x, y]) => placeFootprint(grid, x, y, 2, 2, "BU"));
  const grasses = [[7, 16], [17, 12], [22, 23], [33, 16], [42, 22]];
  grasses.forEach(([x, y]) => placeFootprint(grid, x, y, 2, 2, "GT"));

  for (let x = 12; x <= 21; x += 1) {
    appendObject(grid, x, 23, "RB");
    if (x < 16 || x > 17) appendObject(grid, x, 29, "RB");
  }
  for (let y = 24; y <= 28; y += 1) {
    appendObject(grid, 12, y, "RB");
    appendObject(grid, 21, y, "RB");
  }

  appendObject(grid, 5, 20, "P:R");
  appendObject(grid, 14, 10, "C:1");
  appendObject(grid, 42, 26, "C:2");
  placeFootprint(grid, 37, 12, 1, 2, "N:1", "N:1");
  appendObject(grid, 40, 24, "N:2");
  placeFootprint(grid, 15, 24, 2, 2, "BO:1000", "BO:1000");

  return grid;
}

function placeFootprint(grid, x, y, width, height, code, continuation = code) {
  for (let dy = 0; dy < height; dy += 1) {
    for (let dx = 0; dx < width; dx += 1) {
      const token = dx === 0 && dy === 0 ? `${code}@` : continuation;
      appendObject(grid, x + dx, y + dy, token);
    }
  }
}

function appendObject(grid, x, y, token) {
  const base = grid[y][x].split(";")[0];
  grid[y][x] = `${base};${token}`;
}

function styleMapCell(cell, value) {
  const base = value.split(";")[0];
  const fillByBase = {
    G: colors.grass,
    R: colors.road,
    W: colors.water,
    BR: colors.bridge,
    X: colors.boundary,
  };
  let fill = fillByBase[base] ?? "#FFFFFF";
  let fontColor = base === "X" || base === "W" ? "#FFFFFF" : "#18331E";
  let borderColor = "#C9D7CC";
  let borderStyle = "thin";

  if (value.includes(";RB")) {
    fill = colors.regionBoundary;
    fontColor = "#FFFFFF";
    borderColor = "#3E281C";
    borderStyle = "medium";
  } else if (value.includes(";T")) {
    fill = colors.tree;
    fontColor = "#FFFFFF";
  } else if (value.includes(";BU")) {
    fill = colors.bush;
    fontColor = "#FFFFFF";
  } else if (value.includes(";GT")) {
    fill = colors.grassDetail;
  } else if (value.includes(";H1") || value.includes(";H2")) {
    fill = colors.house;
    fontColor = "#FFFFFF";
    borderColor = "#493F35";
  }

  if (value.includes(";P")) {
    borderColor = colors.player;
    borderStyle = "thick";
    fontColor = "#3A2D00";
  } else if (value.includes(";C:")) {
    borderColor = colors.chest;
    borderStyle = "thick";
  } else if (value.includes(";N:")) {
    borderColor = colors.normal;
    borderStyle = "thick";
  } else if (value.includes(";E:")) {
    borderColor = colors.elite;
    borderStyle = "thick";
  } else if (value.includes(";BO:")) {
    borderColor = colors.boss;
    borderStyle = "thick";
  }

  cell.format = {
    fill,
    font: { bold: true, color: fontColor, size: 7 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: borderStyle, color: borderColor },
  };
}

function addMapConditionalFormats(range) {
  const rules = [
    ["beginsWith", "X", { fill: colors.boundary, font: { color: "#FFFFFF", bold: true } }],
    ["beginsWith", "W", { fill: colors.water, font: { color: "#FFFFFF", bold: true } }],
    ["beginsWith", "BR", { fill: colors.bridge, font: { color: colors.ink, bold: true } }],
    ["beginsWith", "R", { fill: colors.road, font: { color: colors.ink, bold: true } }],
    ["beginsWith", "G", { fill: colors.grass, font: { color: colors.ink, bold: true } }],
    ["containsText", ";RB", { fill: colors.regionBoundary, font: { color: "#FFFFFF", bold: true } }],
    ["containsText", ";T", { fill: colors.tree, font: { color: "#FFFFFF", bold: true } }],
    ["containsText", ";BU", { fill: colors.bush, font: { color: "#FFFFFF", bold: true } }],
    ["containsText", ";GT", { fill: colors.grassDetail, font: { color: colors.ink, bold: true } }],
    ["containsText", ";H1", { fill: colors.house, font: { color: "#FFFFFF", bold: true } }],
    ["containsText", ";H2", { fill: colors.house, font: { color: "#FFFFFF", bold: true } }],
  ];
  for (const [type, text, format] of rules) {
    range.conditionalFormats.add(type, { text, format });
  }
}

function section(sheet, row, title) {
  sheet.mergeCells(`A${row}:H${row}`);
  sheet.getRange(`A${row}`).values = [[title]];
  sheet.getRange(`A${row}:H${row}`).format = {
    fill: colors.header,
    font: { bold: true, color: "#FFFFFF", size: 12 },
    verticalAlignment: "center",
  };
  sheet.getRange(`A${row}:H${row}`).format.rowHeight = 26;
}

function rows(sheet, startRow, matrix, startCol, endCol) {
  const endRow = startRow + matrix.length - 1;
  sheet.getRange(`${startCol}${startRow}:${endCol}${endRow}`).values = matrix;
  tableStyle(sheet.getRange(`${startCol}${startRow}:${endCol}${endRow}`));
  sheet.getRange(`${startCol}${startRow}:${endCol}${startRow}`).format = {
    fill: "#DDE9E1",
    font: { bold: true, color: colors.ink },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    borders: { preset: "all", style: "thin", color: colors.line },
  };
}

function tableStyle(range) {
  range.format = {
    font: { color: colors.ink, size: 9 },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: colors.line },
  };
}

function columnName(number) {
  let result = "";
  let value = number;
  while (value > 0) {
    const remainder = (value - 1) % 26;
    result = String.fromCharCode(65 + remainder) + result;
    value = Math.floor((value - 1) / 26);
  }
  return result;
}
