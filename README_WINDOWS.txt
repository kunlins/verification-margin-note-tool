Prospectus Local Translator - Windows 安装说明

第一次安装：
1. 解压整个 zip 文件。
2. 双击 install_local_translator.bat。
3. 等待安装完成。第一次安装需要联网下载依赖和英译中模型。
4. 看到 Installation is complete 后关闭窗口。

日常使用：
直接打开网站：
https://kunlins.github.io/verification-margin-note-tool/

打开网站后点击“检查本机翻译”。如果显示“本机翻译：可用”，即可使用自动翻译。

说明：
- 电脑需要 Python 3.10 或 3.11。安装器会先自动检测；如果电脑没有 Python，会尝试通过 Windows Package Manager 自动安装 Python 3.11。
- 如果自动安装失败，请手动安装 Python 3.11，并在安装时勾选 “Add python.exe to PATH”，然后重新运行 install_local_translator.bat。
- 招股书文本只会发送到本机 127.0.0.1 翻译服务，不会发送到云端翻译接口。
- 安装脚本会创建 Windows 登录自启任务 Prospectus Local Translator。
- 如果网页提示本机翻译不可用，请重新运行 install_local_translator.bat。
