// Renders views of an exported house in headless Chromium (software WebGL).
//
//   EXPORT=out/world.json EXPORT_ONLY=1 lune run tests/smoke.luau
//   python3 tools/view/textures.py out/world.json out/tex
//   node tools/view/shoot.js <world.json> <tex-dir> <three-dir> <shots.json> <out-dir> [w h]
//
// <three-dir> is an installed `three` package (npm install three). <shots.json> is a list of
// { name, pos: [x,y,z], look: [x,y,z], fov?, lights?, shadows?, exposure?, bloom?, cutY? }.

const fs = require("fs");
const http = require("http");
const path = require("path");

let chromium;
try {
	({ chromium } = require("playwright"));
} catch {
	({ chromium } = require("/opt/node22/lib/node_modules/playwright"));
}

const [worldFile, texDir, threeDir, shotsFile, outDir, w = "1280", h = "720"] = process.argv.slice(2);
const here = __dirname;
const TYPES = { ".js": "text/javascript", ".json": "application/json", ".png": "image/png", ".html": "text/html" };

function serve() {
	const server = http.createServer((req, res) => {
		const url = decodeURIComponent(req.url.split("?")[0]);
		let file;
		if (url === "/" || url === "/viewer.html") file = path.join(here, "viewer.html");
		else if (url === "/viewer.js") file = path.join(here, "viewer.js");
		else if (url === "/world.json") file = worldFile;
		else if (url.startsWith("/tex/")) file = path.join(texDir, url.slice(5));
		else if (url.startsWith("/three/")) file = path.join(threeDir, url.slice(7));
		if (!file || !fs.existsSync(file)) {
			res.writeHead(404);
			res.end();
			return;
		}
		res.writeHead(200, { "Content-Type": TYPES[path.extname(file)] || "application/octet-stream" });
		fs.createReadStream(file).pipe(res);
	});
	return new Promise((resolve) => server.listen(0, () => resolve(server)));
}

(async () => {
	const server = await serve();
	const port = server.address().port;
	const browser = await chromium.launch({
		args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
	});
	const page = await browser.newPage({ viewport: { width: Number(w), height: Number(h) } });
	page.on("console", (m) => {
		if (m.type() === "error" || m.type() === "warning") console.log("page:", m.text().slice(0, 300));
	});
	page.on("pageerror", (e) => console.log("page error:", e.message));
	await page.goto(`http://localhost:${port}/viewer.html?w=${w}&h=${h}`);
	const info = await page.evaluate(() => window.ready);
	console.log("scene:", JSON.stringify(info));
	fs.mkdirSync(outDir, { recursive: true });
	const shots = JSON.parse(fs.readFileSync(shotsFile, "utf8"));
	for (const shot of shots) {
		const t0 = Date.now();
		const data = await page.evaluate((s) => window.shoot(s), shot);
		fs.writeFileSync(path.join(outDir, `${shot.name}.png`), Buffer.from(data.split(",")[1], "base64"));
		console.log(`${shot.name}.png (${Date.now() - t0} ms)`);
	}
	await browser.close();
	server.close();
})();
