# Community Project

# Zig Realm Client

This project is a modern and efficient Private Server Client built using Zig, a robust, optimal, and clear programming language. It is designed specifically to interface with the provided server source, tracking the latest master builds of Zig.

This client is designed to work on Windows, Unix flavours & MacOS. A multi-build script does not currently exist, and `zig build` will only build for your current platform at this time.

This Project is still in active development and may see major changes, both as it changes & Zig changes.

---

## Table of Contents
-  [Prerequisites](#prereqs)
-  [Setup](#setup)
-  [Support](#support)
-  [License](#license)

---

## Prereqs


> **Note** Please note that the project might not work with Zig versions older than the latest one available at the Zig downloads page. 

* This Client currently only works with it's associated source. Found here.
* Zig is still a development lanauge, so the latest master build is required.
* An IDE with a Zig Plugin. Popular options are VSCode, Sublime Text & Emacs/Vim.


## Setup

This client will connect to the associated source, which will need to be running for it to connect.
To setup and run this project, follow the outlined steps:

1. Clone this repository to your local workstation.  
```bash
git clone https://github.com/Slendergo/zig-client
```
2.	Navigate to the ﻿settings.zig file and modify the following line of code based on your server setup:
```zig
pub const app_engine_url = "http://127.0.0.1:8080/";
```
Replace `"http://127.0.0.1:8080/"` with the URL of the server you aim to connect to. If your server is running locally, you might not need to alter this line.

3. The client has a preconfigured build script, this will use the preconfigured `build.zig` file, and create `zig-out/bin`, which will contain the built Client.

```bash
zig build
```


## Support
We offer support via our Discord server. For general discussions, help, or inquiries about this project, join us at https://discord.gg/WCazcBCq on the #zig-help channel.

## License
Please see the included License file for details on our code license.

