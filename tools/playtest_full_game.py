"""Autonomous live Vulkan playtester for Sunfall via PlaytestBridge TCP JSON protocol."""
from __future__ import annotations

import json
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path(r"D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = Path(r"D:\Program File\ffmpeg\ffmpeg-master-latest-win64-gpl\ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe")
OUT_DIR = ROOT / "assets_ref" / "visual_debug" / "playtest"
PORT = 19840


class BridgeClient:
    def __init__(self, port: int) -> None:
        self.sock: socket.socket | None = None
        for attempt in range(40):
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1.0)
            try:
                s.connect(("127.0.0.1", port))
                s.settimeout(20.0)
                self.sock = s
                break
            except OSError as exc:
                if attempt < 3:
                    print(f"Connect attempt {attempt+1}: {exc}", flush=True)
                s.close()
                time.sleep(0.25)
        if self.sock is None:
            raise RuntimeError("Could not connect to PlaytestBridge")
        self._buf = b""
        self.events: list[dict] = []

    def _req(self, payload: dict) -> dict:
        self.sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        while b"\n" not in self._buf:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise RuntimeError("PlaytestBridge disconnected")
            self._buf += chunk
        line, self._buf = self._buf.split(b"\n", 1)
        resp = json.loads(line.decode("utf-8"))
        if "state" in resp and "events" in resp["state"]:
            self.events.extend(resp["state"]["events"])
        return resp

    def state(self) -> dict:
        return self._req({"cmd": "state"})["state"]

    def inp(self, press=(), release=(), yaw_deg=None, pitch_deg=None, look_at=None) -> None:
        p = {"cmd": "input", "press": list(press), "release": list(release)}
        if yaw_deg is not None:
            p["yaw_deg"] = yaw_deg
        if pitch_deg is not None:
            p["pitch_deg"] = pitch_deg
        if look_at is not None:
            p["look_at"] = list(look_at)
        self._req(p)

    def step(self, frames: int) -> dict:
        return self._req({"cmd": "step", "frames": frames})["state"]

    def click(self, action: str, hold_frames: int = 2) -> dict:
        self.inp(press=[action])
        self.step(hold_frames)
        self.inp(release=[action])
        return self.step(2)

    def rec_start(self, sub_dir: Path, every_n: int = 2) -> None:
        sub_dir.mkdir(parents=True, exist_ok=True)
        for old in sub_dir.glob("*.png"):
            old.unlink()
        self._req({"cmd": "record_start", "dir": sub_dir.as_posix(), "every_n": every_n})

    def rec_stop_mp4(self, sub_dir: Path, mp4_name: str, fps: float = 30.0) -> Path | None:
        res = self._req({"cmd": "record_stop"})
        cnt = int(res.get("frames", 0))
        if cnt < 2 or not FFMPEG.exists():
            return None
        mp4 = OUT_DIR / mp4_name
        cmd = [
            str(FFMPEG), "-y", "-framerate", str(fps), "-i", str(sub_dir / "f_%05d.png"),
            "-vf", "format=yuv420p", "-c:v", "libx264", "-crf", "22", str(mp4),
        ]
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return mp4

    def teleport(self, pos: list[float], yaw_deg: float = 0.0, pitch_deg: float = 0.0) -> None:
        self._req({"cmd": "teleport", "pos": pos, "yaw_deg": yaw_deg, "pitch_deg": pitch_deg})

    def spawn_zombie(self, pos: list[float], active: bool = False, brute: bool = False) -> None:
        self._req({"cmd": "spawn_zombie", "pos": pos, "active": active, "brute": brute})

    def clear_zombies(self) -> None:
        self._req({"cmd": "clear_zombies"})

    def quit(self) -> None:
        try:
            self._req({"cmd": "quit"})
        except Exception:
            pass
        self.sock.close()


def release_all(c: BridgeClient) -> None:
    c.inp(release=[
        "move_forward", "move_back", "move_left", "move_right",
        "jump", "sprint", "crouch", "dodge", "kick",
        "primary_action", "secondary_action", "interact", "grapple", "lookback",
    ])


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    log_fp = (OUT_DIR / "godot_bridge.log").open("w", encoding="utf-8")
    proc = subprocess.Popen(
        [
            str(GODOT), "--path", str(ROOT), "--windowed", "--resolution", "1280x720",
            "--position", "40,40", "--", f"--playtest-port={PORT}",
        ],
        stdout=log_fp, stderr=subprocess.STDOUT, text=True,
    )
    report: dict = {"acts": {}}
    try:
        c = BridgeClient(PORT)
        c.step(10)
        c.clear_zombies()

        # ACT 1: Solid-Surface Wall Bounce + RL/LR/Heavy Melee Combo (recorded at 60 FPS -> 15 FPS = 0.25x slow-mo)
        act1_dir = OUT_DIR / "act1_frames"
        c.teleport([4.5, 0.05, 4.6], yaw_deg=0.0, pitch_deg=-4.0)  # Facing concrete tunnel pillar/wall at z=2.0..3.6
        c.step(4)
        c.rec_start(act1_dir, every_n=1)
        c.inp(press=["move_forward"])
        c.step(18)
        c.inp(release=["move_forward"])
        c.click("primary_action", 2)  # Hit wall -> expect world_bounce
        c.step(28)

        c.teleport([0.0, 0.05, 6.2], yaw_deg=0.0, pitch_deg=-5.0)
        c.spawn_zombie([0.0, 0.05, 4.3], active=False)
        c.step(4)
        c.click("primary_action", 2)  # RL swing
        c.step(34)
        c.click("primary_action", 2)  # LR swing
        c.step(30)
        c.inp(press=["primary_action"])  # Heavy charge + swing
        c.step(36)
        c.inp(release=["primary_action"])
        c.step(42)
        c.rec_stop_mp4(act1_dir, "playtest_melee_slowmo.mp4", fps=15.0)
        st1 = c.state()
        report["acts"]["act1_melee"] = {
            "world_bounces": sum(1 for e in c.events if e["kind"] == "world_bounce"),
            "melee_hits": sum(1 for e in c.events if e["kind"] == "melee_hit"),
            "zombie_hp_left": st1["zombies"][0]["hp"] if st1["zombies"] else 0.0,
        }
        c.clear_zombies()

        # ACT 2: Kick, Dropkick Air Launch + Wall-Slam, Head Stomp (0.25x slow-mo)
        act2_dir = OUT_DIR / "act2_frames"
        # Concrete wall at z=-24.0 (width 6, depth 1.6 -> front face z=-23.2). Spawn zombie at z=-20.5, player at z=-15.5!
        c.teleport([-15.3, 0.05, -18.5], yaw_deg=0.0, pitch_deg=-4.0)
        c.spawn_zombie([-15.3, 0.05, -20.5], active=False)
        c.step(4)
        c.rec_start(act2_dir, every_n=1)
        c.click("kick", 2)  # Grounded Kick
        c.step(34)

        c.teleport([-15.3, 0.05, -15.5], yaw_deg=0.0, pitch_deg=-4.0)
        c.inp(press=["sprint", "move_forward"])
        c.step(28)
        c.click("jump", 3)
        c.click("kick", 2)  # Dropkick toward wall!
        release_all(c)
        c.step(48)
        st2 = c.state()
        if st2["zombies"]:
            zp = st2["zombies"][0]["pos"]
            c.teleport([zp[0], 0.05, zp[2] + 1.1], yaw_deg=0.0, pitch_deg=-35.0)
            c.step(4)
            c.click("kick", 2)  # Head Stomp
            c.step(36)
        c.rec_stop_mp4(act2_dir, "playtest_kick_physics_slowmo.mp4", fps=15.0)
        report["acts"]["act2_kick_physics"] = {
            "wall_slams": sum(1 for e in c.events if e["kind"] == "wall_slam"),
            "stomp_events": sum(1 for e in c.events if e["kind"] == "stomp"),
        }
        c.clear_zombies()

        # ACT 3: Continuous Parkour Run (Sprint -> Low Vault -> Slide -> Dodge -> Grapple) at 30 FPS
        act3_dir = OUT_DIR / "act3_frames"
        c.teleport([-7.5, 0.05, 3.0], yaw_deg=0.0, pitch_deg=-5.0)
        c.step(4)
        c.rec_start(act3_dir, every_n=2)
        c.inp(press=["sprint", "move_forward"])
        c.step(28)
        c.click("jump", 3)  # Low vault over 1.2m block at (-7.5, 0.6, -2.0)
        c.step(28)
        release_all(c)
        c.teleport([0.0, 0.05, 12.0], yaw_deg=0.0, pitch_deg=-5.0)
        c.inp(press=["sprint", "move_forward"])
        c.step(36)
        c.inp(press=["crouch"])
        c.step(34)
        release_all(c)
        c.inp(press=["move_left", "dodge"])
        c.step(18)
        release_all(c)
        c.rec_stop_mp4(act3_dir, "playtest_parkour_30fps.mp4", fps=30.0)
        report["acts"]["act3_parkour"] = {"frames_recorded": True}

        # ACT 4: Core Survival Loop (Loot -> Build Wall -> Upgrade Metal -> Place Turret -> Night Horde)
        act4_dir = OUT_DIR / "act4_frames"
        c.teleport([-6.5, 0.05, 17.5], yaw_deg=0.0, pitch_deg=-15.0)  # Near crash Plane Case at (-6.5, 0, 15.0)
        c.step(6)
        c.rec_start(act4_dir, every_n=2)
        c.inp(press=["interact"])
        c.step(44)
        c.inp(release=["interact"])
        c.teleport([0.0, 0.05, 8.0], yaw_deg=0.0, pitch_deg=-22.0)
        c.click("slot_2", 2)
        c.step(6)
        c.click("primary_action", 2)  # Build Wood Barricade
        c.step(10)
        c.click("secondary_action", 2)  # Upgrade to Metal
        c.step(10)
        c.inp(press=["move_left"])
        c.step(24)
        c.inp(release=["move_left"])
        c.click("slot_3", 2)
        c.step(6)
        c.click("primary_action", 2)  # Build Auto-Turret
        c.step(10)
        c.click("slot_1", 2)
        c.click("skip_phase", 2)  # Enter Night 1 Horde!
        c.step(40)
        c.rec_stop_mp4(act4_dir, "playtest_survival_loop.mp4", fps=30.0)
        st4 = c.state()
        report["acts"]["act4_survival"] = {
            "is_night": st4["is_night"],
            "horde_zombies": len(st4["zombies"]),
            "inv": st4["inv"],
        }

        report["events_total"] = len(c.events)
        (OUT_DIR / "playtest_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        c.quit()
    finally:
        try:
            proc.wait(timeout=6)
        except subprocess.TimeoutExpired:
            proc.terminate()
            proc.wait(timeout=5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
