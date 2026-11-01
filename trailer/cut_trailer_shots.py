"""Assemble the trailer's engine shots into one MP4 clip per shot.

tests/trailer_capture.gd run with `-- --frames` writes every frame of every
shot as a 1080p JPEG under <Godot user folder>/trailer/frames/<shot>/. This
script encodes each folder to clips/<shot>.mp4 (H.264, 30 fps) with the
ffmpeg bundled in the imageio-ffmpeg package.
"""
import os
import shutil
import subprocess
import sys

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FFMPEG = "ffmpeg"

OUT = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "Shinrai", "trailer")
FRAMES = os.path.join(OUT, "frames")
CLIPS = os.path.join(OUT, "clips")
FPS = 30


def encode(shot: str, delete_frames: bool) -> bool:
    source = os.path.join(FRAMES, shot)
    count = len([name for name in os.listdir(source) if name.endswith(".jpg")])
    if count == 0:
        print(f"skip {shot}: no frames")
        return False
    target = os.path.join(CLIPS, f"{shot}.mp4")
    if os.path.exists(target) and os.path.getsize(target) > 1024:
        print(f"keep {shot}: already encoded")
        if delete_frames:
            shutil.rmtree(source, ignore_errors=True)
        return True
    command = [
        FFMPEG, "-y", "-loglevel", "error",
        "-framerate", str(FPS), "-i", os.path.join(source, "%05d.jpg"),
        "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", target,
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"FAILED {shot}: {result.stderr.strip()}")
        return False
    print(f"-> {os.path.basename(target)} ({count} frames, {count / FPS:.1f} s)")
    if delete_frames:
        shutil.rmtree(source, ignore_errors=True)
    return True


def main(argv: list[str]) -> int:
    """Usage: cut_trailer_shots.py [--delete-frames] [shot ...]"""
    delete_frames = "--delete-frames" in argv
    selected = [arg for arg in argv if not arg.startswith("--")]
    if not os.path.isdir(FRAMES):
        print("no frames folder at", FRAMES)
        return 1
    os.makedirs(CLIPS, exist_ok=True)
    shots = selected or sorted(os.listdir(FRAMES))
    failures = [shot for shot in shots if not encode(shot, delete_frames)]
    print("clips in", CLIPS)
    if failures:
        print("failed:", ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
