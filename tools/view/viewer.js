// The Maison in a browser: draws an exported house (world.json, from the smoke test's EXPORT) with
// three.js, close enough to Roblox's Future lighting to judge rooms by eye: shapes, materials,
// lamps, Neon glow, and every SurfaceGui (textures drawn by textures.py).
//
// window.shoot({ pos, look, fov, lights, shadows, exposure }) renders one view and returns it as a
// PNG data URL; shoot.js drives it from headless Chromium.

import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

const params = new URLSearchParams(location.search);
const W = Number(params.get("w")) || 1280;
const H = Number(params.get("h")) || 720;

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.setPixelRatio(1);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color().setRGB(8 / 255, 10 / 255, 18 / 255, THREE.SRGBColorSpace);
const camera = new THREE.PerspectiveCamera(70, W / H, 0.1, 2000);

// Roblox materials as PBR settings: [roughness, metalness].
const SURFACE = {
	Marble: [0.22, 0], Metal: [0.32, 0.9], DiamondPlate: [0.4, 0.85], Foil: [0.25, 0.9], CorrodedMetal: [0.7, 0.6],
	Wood: [0.62, 0], WoodPlanks: [0.7, 0], Plaster: [0.92, 0], Fabric: [0.96, 0], Carpet: [1, 0], Leather: [0.55, 0],
	SmoothPlastic: [0.38, 0], Plastic: [0.5, 0], Concrete: [0.9, 0], Brick: [0.92, 0], Granite: [0.6, 0], Limestone: [0.85, 0],
	Slate: [0.75, 0], Asphalt: [0.95, 0], Cobblestone: [0.9, 0], Pebble: [0.9, 0], Sand: [1, 0], Grass: [1, 0], LeafyGrass: [1, 0],
	Ice: [0.08, 0], Glass: [0.05, 0], Neon: [1, 0], ForceField: [1, 0], Basalt: [0.85, 0], Rock: [0.9, 0], Salt: [0.8, 0],
	Mud: [1, 0], Ground: [1, 0], Sandstone: [0.9, 0], CrackedLava: [0.8, 0], Glacier: [0.2, 0], Snow: [0.9, 0], Cardboard: [0.95, 0], Rubber: [0.9, 0], ClayRoofTiles: [0.8, 0], RoofShingles: [0.9, 0], CeramicTiles: [0.3, 0], Pavement: [0.9, 0],
};

const geometries = {
	Block: new THREE.BoxGeometry(1, 1, 1),
	Ball: new THREE.SphereGeometry(0.5, 32, 16),
	Cylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 32).rotateZ(Math.PI / 2),
	Wedge: (() => {
		// Roblox's wedge: full bottom and back (+Z), sloping down to the front edge.
		const g = new THREE.BufferGeometry();
		const v = [
			[-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5, 0.5], [-0.5, -0.5, 0.5],
			[-0.5, 0.5, 0.5], [0.5, 0.5, 0.5],
		];
		const tris = [[0, 2, 1], [0, 3, 2], [3, 5, 2], [3, 4, 5], [0, 1, 5], [0, 5, 4], [0, 4, 3], [1, 2, 5]];
		const pos = [];
		for (const t of tris) for (const i of t) pos.push(...v[i]);
		g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
		g.computeVertexNormals();
		return g;
	})(),
};
geometries.CornerWedge = geometries.Wedge;

const materials = new Map();
function srgb(c) {
	return new THREE.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace);
}
function materialFor(color, matName, transparency, reflectance) {
	const key = `${color}|${matName}|${transparency}|${reflectance}`;
	let m = materials.get(key);
	if (m) return m;
	const col = srgb(color);
	if (matName === "Neon") {
		m = new THREE.MeshBasicMaterial({ color: col.clone().multiplyScalar(2.6) });
	} else if (matName === "Glass") {
		m = new THREE.MeshPhysicalMaterial({ color: col, roughness: 0.04, metalness: 0, envMapIntensity: 0.6 + reflectance * 2 });
	} else if (matName === "ForceField") {
		m = new THREE.MeshBasicMaterial({ color: col.clone().multiplyScalar(1.4) });
		transparency = Math.max(transparency, 0.7);
	} else {
		const s = SURFACE[matName] || [0.6, 0];
		m = new THREE.MeshStandardMaterial({
			color: col,
			roughness: Math.max(0.04, s[0] - reflectance * 0.8),
			metalness: s[1],
			envMapIntensity: 0.18 + reflectance * 1.5,
		});
	}
	if (transparency > 0.001 || matName === "Glass") {
		m.transparent = true;
		m.opacity = matName === "Glass" ? Math.max(0.18, 1 - transparency) * 0.85 : 1 - transparency;
		m.depthWrite = transparency < 0.5;
	}
	materials.set(key, m);
	return m;
}

function cframe(c) {
	return new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
}

const lightObjects = [];
let moon;

function faceNormal(face) {
	return {
		Front: new THREE.Vector3(0, 0, -1), Back: new THREE.Vector3(0, 0, 1), Left: new THREE.Vector3(-1, 0, 0),
		Right: new THREE.Vector3(1, 0, 0), Top: new THREE.Vector3(0, 1, 0), Bottom: new THREE.Vector3(0, -1, 0),
	}[face];
}
// How a SurfaceGui lies on each face: its right and up, in the part's own axes.
const GUI_AXES = {
	Front: [[-1, 0, 0], [0, 1, 0]], Back: [[1, 0, 0], [0, 1, 0]], Left: [[0, 0, 1], [0, 1, 0]],
	Right: [[0, 0, -1], [0, 1, 0]], Top: [[1, 0, 0], [0, 0, -1]], Bottom: [[1, 0, 0], [0, 0, 1]],
};

async function build() {
	const world = await (await fetch("/world.json")).json();
	const L = world.lighting;
	for (const p of world.parts) {
		const [name, shape, size, cf, color, mat, t, refl, castShadow] = p;
		const geo = geometries[shape] || geometries.Block;
		const mesh = new THREE.Mesh(geo, materialFor(color, mat, t, refl));
		const m = cframe(cf);
		let sx = size[0], sy = size[1], sz = size[2];
		if (shape === "Ball") {
			const d = Math.min(sx, sy, sz);
			sx = sy = sz = d;
		} else if (shape === "Cylinder") {
			const d = Math.min(sy, sz);
			sy = sz = d;
		}
		m.multiply(new THREE.Matrix4().makeScale(sx, sy, sz));
		mesh.matrixAutoUpdate = false;
		mesh.matrix.copy(m);
		mesh.castShadow = castShadow && t < 0.5 && mat !== "Neon";
		mesh.receiveShadow = mat !== "Neon";
		mesh.name = name;
		scene.add(mesh);
	}
	const loader = new THREE.TextureLoader();
	const texWork = [];
	world.guis.forEach((g, i) => {
		const [right, up] = GUI_AXES[g.face];
		const n = faceNormal(g.face);
		const s = g.size;
		const depth = Math.abs(n.x) * s[0] + Math.abs(n.y) * s[1] + Math.abs(n.z) * s[2];
		const w = g.face === "Left" || g.face === "Right" ? s[2] : s[0];
		const h = g.face === "Top" || g.face === "Bottom" ? s[2] : s[1];
		const plane = new THREE.PlaneGeometry(w, h);
		const basis = new THREE.Matrix4().makeBasis(new THREE.Vector3(...right), new THREE.Vector3(...up), n.clone());
		basis.setPosition(n.clone().multiplyScalar(depth / 2 + 0.012));
		const m = cframe(g.part).multiply(basis);
		texWork.push(
			loader.loadAsync(`/tex/${i}.png`).then((tex) => {
				tex.colorSpace = THREE.SRGBColorSpace;
				tex.anisotropy = 8;
				const lit = g.lit > 0.01;
				const mat = lit
					? new THREE.MeshStandardMaterial({ map: tex, transparent: true, roughness: 0.6, emissive: new THREE.Color(1, 1, 1), emissiveMap: tex, emissiveIntensity: 0.25 * (g.brightness || 1) })
					: new THREE.MeshBasicMaterial({ map: tex, transparent: true, color: new THREE.Color(1, 1, 1).multiplyScalar(Math.min(1.3, g.brightness || 1)) });
				mat.alphaTest = 0.02;
				mat.depthWrite = false;
				mat.polygonOffset = true;
				mat.polygonOffsetFactor = -2;
				const mesh = new THREE.Mesh(plane, mat);
				mesh.matrixAutoUpdate = false;
				mesh.matrix.copy(m);
				mesh.renderOrder = 2;
				scene.add(mesh);
			}).catch(() => {})
		);
	});
	await Promise.all(texWork);

	for (const l of world.lights) {
		const color = srgb(l.color);
		const m = cframe(l.cf);
		const pos = new THREE.Vector3().setFromMatrixPosition(m);
		let obj;
		if (l.kind === "PointLight") {
			obj = new THREE.PointLight(color, l.brightness * 9, l.range * 1.15, 1.3);
		} else {
			const n = faceNormal(l.face || "Front").transformDirection(m);
			const angle = l.kind === "SurfaceLight" ? Math.min(89, (l.angle || 90) / 2 + 15) : Math.min(89, (l.angle || 90) / 2);
			obj = new THREE.SpotLight(color, l.brightness * (l.kind === "SurfaceLight" ? 14 : 11), l.range * 1.15, THREE.MathUtils.degToRad(angle), 0.45, 1.3);
			obj.target.position.copy(pos.clone().add(n));
			scene.add(obj.target);
		}
		obj.position.copy(pos);
		obj.visible = false;
		obj.userData = { range: l.range, shadows: l.shadows };
		obj.shadow.mapSize.set(1024, 1024);
		obj.shadow.bias = -0.002;
		scene.add(obj);
		lightObjects.push(obj);
	}

	const amb = srgb(L.ambient);
	scene.add(new THREE.AmbientLight(amb, 7.5));
	const outdoor = srgb(L.outdoor);
	scene.add(new THREE.HemisphereLight(outdoor, new THREE.Color(0.02, 0.02, 0.03), 0.9));
	moon = new THREE.DirectionalLight(outdoor, 0.9);
	moon.position.set(-120, 260, -180);
	moon.target.position.set(0, 0, 40);
	moon.castShadow = true;
	moon.shadow.mapSize.set(4096, 4096);
	const sc = moon.shadow.camera;
	sc.left = -200; sc.right = 200; sc.top = 200; sc.bottom = -200; sc.near = 1; sc.far = 800;
	moon.shadow.bias = -0.0006;
	scene.add(moon, moon.target);

	const pmrem = new THREE.PMREMGenerator(renderer);
	scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
	scene.environmentIntensity = 0.35;
	renderer.toneMappingExposure = Math.pow(2, L.exposure || 0) * 1.0;
	return world;
}

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(W, H), 0.55, 0.5, 0.92);
composer.addPass(bloom);
composer.addPass(new OutputPass());

window.ready = build().then((w) => ({ parts: w.parts.length, lights: w.lights.length, guis: w.guis.length }));

window.shoot = async (shot) => {
	camera.fov = shot.fov || 70;
	camera.aspect = W / H;
	camera.near = shot.near || 0.1;
	camera.updateProjectionMatrix();
	camera.position.set(...shot.pos);
	camera.lookAt(new THREE.Vector3(...shot.look));
	camera.updateMatrixWorld();
	// The lamps that light this view: the nearest whose light reaches toward the camera.
	const at = camera.position;
	const ranked = lightObjects
		.map((l) => ({ l, d: l.position.distanceTo(at) - l.userData.range }))
		.sort((a, b) => a.d - b.d);
	const max = shot.lights || 40;
	ranked.forEach((r, i) => {
		r.l.visible = i < max;
		r.l.castShadow = !!shot.shadows && r.l.userData.shadows && i < 6;
	});
	if (shot.exposure !== undefined) renderer.toneMappingExposure = Math.pow(2, shot.exposure);
	bloom.strength = shot.bloom ?? 0.55;
	composer.render();
	return renderer.domElement.toDataURL("image/png");
};
