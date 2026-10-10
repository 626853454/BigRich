# 骰火商路 · 灰灯夜市

Godot 4.7.2 的单人夜市交易原型。保留逐格探索与双骰判定规则，提供低角度跟随镜头、冷色街道与暖色灯笼的第一版美术样板。角色和建筑仍是占位模型，不是最终美术。

## 启动与操作

使用 `tools/godot/Godot_v4.7.2-stable_win64.exe` 打开本目录的 `project.godot`，按 F6/F5 运行主场景。

- WASD / 方向键：按画面方向逐格移动。
- E：互动或在商会交单。
- Enter：用账房先生开局；互动时首次掷骰、随后确认。
- R：重掷未锁定的骰子，每次互动最多一次。
- Esc：保存当前行程。完成互动和退出时也会保存。
- 鼠标按钮：选择商人、左右锁骰、交易策略、符印和重新开始。

完成茶货商铺、传闻告示、巡夜关口三项委托后，前往商会交单。胜利需要金币至少 18、声望至少 3、热度不超过 7。失败的互动可再次尝试。

茶铺成功获得金币，传闻成功获得声望，巡夜关口成功获得金币及 1 声望。押注支付 3 金币并要求更高骰点，成功奖励也更高；界面在选择前显示具体奖励。三种商人均可完成胜利条件。

首次掷骰免费，重掷消耗 1 个改骰筹码。驿站每局补充一次筹码并减少 1 热度。第二项委托完成后，选择一个符印：

- 巧手：每次互动的一次重掷不消耗筹码。
- 静行：失败不增加热度。
- 守财：至少锁定一颗骰子且互动成功时，额外获得 2 金币。

## 当前样板

主场景接入 Blender 导出的旅行者、茶摊和灯笼。镜头固定朝向，俯角 27°，平滑跟随角色；遮住角色的建筑、窗户及边界墙自动淡出。包含石板路、茶摊木平台、暖光灯笼、冷色月光、窗户、箱子与远景围墙。

可在 `scripts/world/fixed_overhead_camera.gd` 的导出变量中调整距离、水平朝向和俯角。移动会自动按镜头朝向映射为格子方向。

## Blender 资产

`tools/blender/build_assets.py` 可重复生成 `assets/models/` 下三个 GLB。生成参数采用 Godot 的 Y-up 坐标，脚本先转换到 Blender 的 Z-up 再导出，避免角色和灯笼横躺。该脚本会替换三个占位模型；以后手工精修时请另外保存 Blender 源文件。

`tools/.gdignore` 阻止 Godot 把工具目录中的 Blender 内置素材、字体和运行库当成游戏资源导入。最终 GLB 保存在 `assets/models/`，正常参与导入。

```powershell
& tools/blender/runtime/blender-4.5.14-windows-x64/blender.exe --background --factory-startup --python tools/blender/build_assets.py
```

## 验证

```powershell
& tests/run_checks.ps1
```

检查包含编辑器导入、规则与整局路径、锁骰及筹码、三种符印、胜负、无效存档、实际场景加载、输入、角色移动、错误反馈、UI 交单、重新开始和存档恢复。检查脚本将日志中的 `ERROR` / `SCRIPT ERROR` 视为失败，不能只凭进程返回码或一条 PASS 判断。

可选渲染检查（输出目录建议在项目外）：

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --rendering-driver opengl3 --script tests/scene_smoke.gd -- --capture=C:/Temp/DiceFirePreview
```

场景测试将自己的存档写入 `scene-smoke-test.json`，不会覆盖正常行程存档。

角色动画、精细材质、建筑造型、音效、地图扩展及多人玩法尚未实现。
