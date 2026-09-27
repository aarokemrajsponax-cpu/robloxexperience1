# robloxexperience1

This repo syncs into Roblox Studio with [Rojo](https://rojo.space). You edit
the `.luau` files here and Rojo pushes the changes into Studio as you save.

## Where the files go in Studio

| Folder here   | Shows up in Studio as                                   |
| ------------- | ------------------------------------------------------- |
| `src/server`  | `ServerScriptService.Server`                            |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`             |
| `src/shared`  | `ReplicatedStorage.Shared`                              |

File names decide the script type:

- `name.server.luau` → `Script`
- `name.client.luau` → `LocalScript`
- `name.luau` → `ModuleScript`

## One-time setup (on your computer)

1. **Clone this repo** to your computer.
2. **Install Rokit** (it installs Rojo for you): follow
   https://github.com/rojo-rbx/rokit#installation, then in this folder run:
   ```sh
   rokit install
   ```
3. **Install the Rojo plugin in Studio:** run `rojo plugin install`, or get
   it from the Creator Store (search "Rojo"). Restart Studio.

## Connecting to Studio

1. In this folder, run:
   ```sh
   rojo serve
   ```
   It prints that it is listening on `localhost:34872`. Leave it running.
2. Open your place in Roblox Studio.
3. Open the **Plugins** tab → **Rojo** → click **Connect**.
4. Press **Play**. The Output window should show `Hello, server!` and
   `Hello, <your name>!`.

From then on, saving a file here updates Studio instantly.

## Building a place file without Studio

```sh
rojo build -o robloxexperience1.rbxl
```
