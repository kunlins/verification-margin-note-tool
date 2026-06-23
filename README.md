# Prospectus Margin Note Tool

招股书验证 margin note 工具，支持 PDF 圈选、自动填充中文翻译草稿、导出带 margin notes 的 PDF 和 Word 验证清单。

## GitHub Pages

部署到 GitHub Pages 后，网站入口可以使用仓库根地址。`index.html` 会自动跳转到主工具页面。

请确保 `status.json` 一起部署。App 启动时会检查同目录下的 `status.json`：

```json
{
  "enabled": true,
  "message": "Service available."
}
```

需要关闭服务时，把线上 `status.json` 改成：

```json
{
  "enabled": false,
  "message": "This service is no longer available."
}
```

## 本机翻译服务

用户第一次运行安装脚本后，本机翻译服务会在后台运行：

- macOS: `install_local_translator.command`
- Windows: `install_local_translator.bat`

安装完成后，用户直接打开 GitHub Pages 网站即可使用自动翻译。

本机翻译服务只监听 `127.0.0.1`。
