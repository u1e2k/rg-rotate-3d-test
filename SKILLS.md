# Workspace Skills & Architecture Guide

このリポジトリには、**ANBERNIC RG Rotate** 向けのGodot 4 3Dゲーム開発を支援するカスタムスキルが整備されています。

---

## 🛠️ 登録されているスキル

### `rg-rotate-godot`
- **スキル定義ファイル**: [SKILL.md](file:///.agents/skills/rg-rotate-godot/SKILL.md)
- **概要**:
  - RG Rotateのハードウェア仕様（3.5インチ 720×720 正方形画面、Android 12、物理十字キー＆ABXYボタン、アナログスティック非搭載）に特化した開発ガイドライン。
  - スティック非搭載環境における三人称視点（TPS）カメラ制御・旋回チューニング・180°クイックターンの実装指針。
  - Windows上でのローカルテスト実行コマンドおよびAndroid APKエクスポート手順。

---

## 📌 コア実装リファレンス

| 機能 | 実装ファイル | 説明 |
|---|---|---|
| **プレイヤー制御** | [player.gd](file:///scripts/player.gd) | 物理十字キーによる前進・後退・旋回・ジャンプ・180°クイックターンおよびプロシージャル歩行アニメーション |
| **カメラ追従** | [player.tscn](file:///scenes/player.tscn) | スプリングアーム（SpringArm3D）による自動水平追従ダンピング（スティック操作不要） |
| **プロシージャル音源** | [sound_manager.gd](file:///scripts/sound_manager.gd) | 外部音声ファイル不要のAudioStreamWAVリアルタイム合成（ジャンプ音、コイン音、足音等） |
| **テストステージ** | [main.tscn](file:///scenes/main.tscn) | スロープ、階段、飛び石、動くリフト、物理ボックス、クリスタル収集ギミック |
| **画面設定** | [project.godot](file:///project.godot) | 720×720 正方形解像度およびモバイル向けレンダリング設定 |
