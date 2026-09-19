# ADI2 Native

讓 Mac 音量鍵與控制中心直接調整 **RME ADI-2 DAC 的硬體音量**。使用 Swift／AppKit 原生介面，提供選單列控制、五段 EQ、Bass／Treble、DAC 預設載入，以及繁體中文／英文切換。

[English / 完整技術說明](README.md)

## 目前狀態

App **0.4.1**、HAL 驅動 **0.2.2**。目前為本機開發版本，尚未 Apple 公證，也尚未宣稱正式 1.0。七組自動測試通過；最新版的最終安裝及實機驗證仍待完成。

需要 Apple Silicon Mac、Xcode Command Line Tools，以及透過 USB 連接的一台 ADI-2 DAC。編譯目標為 macOS 13 以上，實機測試環境為 macOS 27；其他版本尚未完整驗證。Pro／2/4 Pro 不在支援範圍。

## 建置與安裝

```sh
git clone https://github.com/vendyluo/adi2-native.git
cd adi2-native
./Scripts/build.sh
./Scripts/test.sh
./安裝.command
```

安裝前先結束 App。安裝驅動需要在 macOS 視窗完成管理員驗證，會短暫重新啟動音訊服務。之後選擇控制目標並啟用原生音量即可。關閉視窗仍會在選單列執行；可在設定調整 Dock 顯示、登入啟動及語言。

開啟登入啟動後請保留 App 路徑；若移動 App，需重新設定登入啟動。

解除安裝：結束 App 後執行 `./解除安裝.command`，移除驅動但保留專案檔案。

## 使用限制

- 只支援雙聲道 PCM，不支援 DSD／DoP 或獨占播放。
- 音量上限由軟體校正，硬體旋鈕可能短暫超過上限，不是硬體聽力保護。
- 控制目標不會切換 DAC 實體輸出插孔。
- App 失聯後代理音訊會靜音；若無法恢復，可在 macOS 聲音設定選回實體 DAC。
- EQ 曲線為近似示意；套用編輯不會覆寫 DAC 儲存的預設。
- 跨機器長時間播放、拔插及睡眠喚醒仍需更多驗證。

原創程式採 [MIT](LICENSE)，第三方授權見 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本專案與 RME、Apple 無隸屬或背書關係。
